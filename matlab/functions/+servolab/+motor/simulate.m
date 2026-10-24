function S = simulate(c)
%SIMULATE  Run one DC-motor experiment in simulation.
%
%   S = servolab.motor.simulate(c)      c from servolab.motor.defaultConfig
%
%   WHAT IS SIMULATED, deliberately the loop the Arduino will run:
%     * controller sampled every c.Ts with ZOH output (pidStep.m)
%     * command takes effect c.latency after the sample (Modbus write time)
%     * feedback quantised: encoder counts (5200 / output rev) for position;
%       for speed either the drive's speed register (rig, c.spdFb 'drive': steps of
%       P.spd_fb_step_base_rpm) or encoder counts differenced over Ts (c.spdFb 'encoder', bare)
%     * output clipped to +/- c.uMax with conditional-integration anti-windup
%     * load-torque step c.dist (N*m at the output shaft) at c.tDist
%     * setpoint: a step c.setpoint at c.tStep, or c.profile [t, value] rows (held) if given
%
%   PLANTS
%     'bare'  L di/dt = V - R i - Ke w ;  J w' = Kt i - b w - T_L / (N eta)
%             exact ZOH discretisation at c.dt.
%     'rig'   RMCS-2303 Mode 1 modelled as: setpoint ramp at the acceleration
%             register rate -> PI speed loop of bandwidth wc_drive -> ideal
%             current loop clipped at 3 A and at the supply-voltage headroom
%             -> the same mechanical model. The drive internals are NOT
%             documented; this structure is an ESTIMATE to be replaced by the
%             MOTOR-02 identification.
%
%   Output S: fine-grid traces (t, r, y, u, i, w_rpm, th_deg), controller-sample
%   traces (tk, ym, e, uk, sat), S.metrics, S.cfg, S.diverged.

    P = c.P;
    N = P.N;
    Jt = P.J + P.J_load_out / N^2;
    isRig = strcmp(c.plant, 'rig');
    isSpeed = strcmp(c.loop, 'speed');

    nS   = round(c.Tend / c.dt) + 1;
    t    = (0:nS-1)' * c.dt;
    nPer = round(c.Ts / c.dt);
    nLat = round(c.latency / c.dt);
    assert(abs(nPer * c.dt - c.Ts) < 1e-9 && nPer >= 1, 'servolab:motor:Ts', ...
        'Ts (%g) must be a positive multiple of dt (%g)', c.Ts, c.dt);
    assert(nLat <= nPer, 'servolab:motor:latency', 'latency (%g s) must not exceed Ts (%g s)', c.latency, c.Ts);

    % Steady-state output rpm per volt of the bare motor (open-loop calibration).
    Kss = Kt_over(P) / P.rpm / N;

    g = struct('Kp', c.Kp, 'Ki', c.Ki, 'Kd', c.Kd, 'Tf', c.Tf, 'Ts', c.Ts, 'uMax', c.uMax);
    switch c.ctrl
        case 'P',   g.Ki = 0; g.Kd = 0;
        case 'I',   g.Kp = 0; g.Kd = 0;
        case 'PI',  g.Kd = 0;
        case {'PID', 'OL'}
        otherwise, error('servolab:motor:ctrl', 'unknown controller ''%s''', c.ctrl);
    end

    % Open-loop position: run at half speed for the time the move should take.
    vOL = 0.5 * (isRig * c.uMax + ~isRig * c.uMax * Kss);           % output rpm
    tOL = abs(c.setpoint) / (6 * vOL);                                % s

    if ~isRig
        A = [-P.R/P.L, -P.Ke/P.L, 0; P.Kt/Jt, -P.b/Jt, 0; 0, 1, 0];
        B = [1/P.L, 0; 0, -1/Jt; 0, 0];
        M = expm([A B; zeros(2, 5)] * c.dt);
        Ad = M(1:3, 1:3); Bd = M(1:3, 4:5);
    end
    Kpd = P.J * P.wc_drive / P.Kt;  Kid = Kpd * P.wc_drive / 4;
    acc = P.acc_base_rpm_s * P.rpm;
    wMax = P.spd_max_base_rpm * P.rpm;

    hasProf = isfield(c, 'profile') && ~isempty(c.profile);     % [t, setpoint] rows, held
    if hasProf, prof = c.profile; end

    % state: base-side current, speed, angle; drive ramp + integrator
    x = [0; 0; 0]; wr = 0; xi = 0;
    st = servolab.motor.pidInit();
    uApplied = 0; uPending = 0; kApply = Inf; thPrevCounts = 0;

    nK = floor((nS - 1) / nPer) + 1;
    [tk, ym, ek, uk, sk] = deal(nan(nK, 1));
    [r, y, u, cur, wOut, thOut] = deal(nan(nS, 1));
    diverged = false; kk = 0;

    for k = 1:nS
        if hasProf
            rk = prof(find(prof(:, 1) <= t(k) + 1e-9, 1, 'last'), 2); if isempty(rk), rk = 0; end
        else
            rk = c.setpoint * (t(k) >= c.tStep);
        end
        TL = c.dist * (t(k) >= c.tDist) / (N * P.eta);
        thDeg = x(3) / N * 180 / pi;
        wRpm  = x(2) / P.rpm / N;

        % ------------------------------------------------ controller sample
        if mod(k - 1, nPer) == 0
            kk = kk + 1;
            counts = thDeg / P.deg_per_count;
            if c.quant, counts = round(counts); end
            if isSpeed
                if isRig && ~strcmp(c.spdFb, 'encoder')
                    meas = x(2) / P.rpm;                         % drive reports base rpm,
                    if c.quant                                   % in steps of ~461.5 (10 ms line count)
                        meas = round(meas / P.spd_fb_step_base_rpm) * P.spd_fb_step_base_rpm;
                    end
                    meas = meas / N;
                elseif kk == 1
                    meas = 0;
                else
                    meas = (counts - thPrevCounts) * P.deg_per_count / c.Ts / 6;
                end
            else
                meas = counts * P.deg_per_count;
            end
            thPrevCounts = counts;
            e = rk - meas; sat = false;
            if strcmp(c.ctrl, 'OL')
                if isSpeed
                    cmd = rk * (isRig + ~isRig / Kss);
                else
                    on = t(k) >= c.tStep && t(k) < c.tStep + tOL;
                    cmd = on * sign(c.setpoint) * vOL * (isRig + ~isRig / Kss);
                end
                cmd = min(max(cmd, -c.uMax), c.uMax);
            else
                [cmd, st, sat] = servolab.motor.pidStep(st, e, g);
            end
            tk(kk) = t(k); ym(kk) = meas; ek(kk) = e; uk(kk) = cmd; sk(kk) = sat;
            uPending = cmd; kApply = k + nLat;
        end
        if k >= kApply, uApplied = uPending; kApply = Inf; end

        % ------------------------------------------------------- log
        r(k) = rk; u(k) = uApplied; wOut(k) = wRpm; thOut(k) = thDeg; cur(k) = x(1);
        y(k) = isSpeed * wRpm + ~isSpeed * thDeg;

        % ------------------------------------------------------- plant
        if isRig
            wCmd = min(max(uApplied * N * P.rpm, -wMax), wMax);
            wr = wr + min(max(wCmd - wr, -acc * c.dt), acc * c.dt);
            ed = wr - x(2);
            iu = Kpd * ed + xi;
            iHi = min(P.I_lim_drive,  ( P.V_supply - P.Ke * x(2)) / P.R);
            iLo = max(-P.I_lim_drive, (-P.V_supply - P.Ke * x(2)) / P.R);
            i = min(max(iu, iLo), iHi);
            if i == iu || sign(ed) ~= sign(iu - i)
                xi = xi + Kid * ed * c.dt;
            end
            wNew = x(2) + (P.Kt * i - P.b * x(2) - TL) / Jt * c.dt;
            x = [i; wNew; x(3) + wNew * c.dt];
        else
            x = Ad * x + Bd * [uApplied; TL];
        end
        if ~all(isfinite(x)) || abs(x(2)) > 10 * P.w_nl_base
            diverged = true; break;
        end
    end

    S = struct('t', t, 'r', r, 'y', y, 'u', u, 'i', cur, 'w_rpm', wOut, 'th_deg', thOut, ...
               'tk', tk(1:kk), 'ym', ym(1:kk), 'e', ek(1:kk), 'uk', uk(1:kk), 'sat', sk(1:kk), ...
               'diverged', diverged, 'cfg', c, 'tOL', tOL);
    S.units = units(c);
    S.metrics = servolab.motor.metrics(S);
end

function k = Kt_over(P)
    % Bare-motor steady state: w / V = Kt / (R b + Kt Ke)   [rad/s per V, base]
    k = P.Kt / (P.R * P.b + P.Kt * P.Ke);
end

function s = units(c)
    if strcmp(c.loop, 'speed'), s.y = 'rpm (output shaft)'; else, s.y = 'deg (output shaft)'; end
    if strcmp(c.plant, 'rig'), s.u = 'rpm command (output shaft)'; else, s.u = 'V (armature)'; end
end
