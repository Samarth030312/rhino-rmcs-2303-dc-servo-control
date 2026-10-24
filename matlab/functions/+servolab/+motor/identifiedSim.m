function S = identifiedSim(m, c, profile, Tend)
%IDENTIFIEDSIM  Lab rig as an IDENTIFIED black-box model, run with the Arduino's loop.
%
%   S = servolab.motor.identifiedSim(m, c, profile, Tend)
%
%   This is the model the course MOTOR handout (S3-4, S3-7) asks for: built from the
%   measured step responses, not from motor constants. Signal path (all output-shaft rpm):
%
%     Arduino (pidStep every c.Ts, command applied c.latency later, |u| <= c.uMax)
%       -> dead zone m.dz            command below which the motor does not turn
%       -> rate limit m.acc          the drive's acceleration register (rpm/s)
%       -> K / (tau s + 1)           drive speed loop + motor + gearbox, lumped
%       -> dead time m.theta         drive-internal delay (not the Modbus latency)
%       -> speed w; motor-side angle = integral of w; output angle after backlash m.backlash
%
%   Measurement each sample: 'speed' + c.spdFb 'drive' = w in steps of m.qSpd (the drive's
%   ~10 ms line count); 'speed' + 'encoder' = encoder counts differenced over the actual Ts;
%   'position' = encoder counts in degrees. The encoder sits on the MOTOR shaft (before the
%   gearbox), so backlash is invisible to the controller unless m.sensorAtLoad = true.
%
%   m: K, tau, theta, acc, dz, qSpd, backlash (deg), sensorAtLoad (logical)
%   c: loop 'speed'|'position', ctrl 'OL'|'P'|'I'|'PI'|'PID', Kp Ki Kd Tf Ts uMax latency,
%      quant (logical), spdFb, antiWindup (default true; false = plain integrator, for S3-12)
%   profile: [t_s, setpoint] (setpoint held between rows); Tend: s
%
%   S.t, S.w, S.thMotor, S.thOut, S.uApplied   fine grid (dt = 1 ms)
%   S.tk, S.r, S.meas, S.e, S.u, S.sat         controller samples (like hardware telemetry)

    dt = 1e-3;
    def = struct('K', 1, 'tau', 0.3, 'theta', 0, 'acc', Inf, 'dz', 0, 'qSpd', 0, ...
                 'backlash', 0, 'sensorAtLoad', false);
    for f = fieldnames(def)', if ~isfield(m, f{1}), m.(f{1}) = def.(f{1}); end, end
    if ~isfield(c, 'antiWindup'), c.antiWindup = true; end
    if ~isfield(c, 'spdFb'), c.spdFb = 'drive'; end
    isSpeed = strcmp(c.loop, 'speed');

    nS = round(Tend / dt) + 1;
    t = (0:nS - 1)' * dt;
    nPer = round(c.Ts / dt); nLat = round(c.latency / dt); nDel = round(m.theta / dt);
    a = exp(-dt / m.tau);

    [w, thM, thO, uA] = deal(zeros(nS, 1));
    delayBuf = zeros(nDel + 1, 1); dIdx = 1;
    wr = 0; x1 = 0; wf = 0; th = 0; thOut = 0;
    uApplied = 0; uPending = 0; kApply = Inf;
    st = servolab.motor.pidInit(); g = struct('Kp', c.Kp, 'Ki', c.Ki, 'Kd', c.Kd, 'Tf', c.Tf, 'Ts', c.Ts, 'uMax', c.uMax);
    nK = floor((nS - 1) / nPer) + 1;
    [tk, rk, ym, ek, uk, sk] = deal(nan(nK, 1)); kk = 0; prevCounts = 0;

    for k = 1:nS
        if mod(k - 1, nPer) == 0
            kk = kk + 1;
            r = profile(find(profile(:, 1) <= t(k) + 1e-9, 1, 'last'), 2);
            if isempty(r), r = 0; end
            thSensor = th; if m.sensorAtLoad, thSensor = thOut; end
            counts = thSensor / 360 * 5200; if c.quant, counts = round(counts); end
            if isSpeed && strcmp(c.spdFb, 'encoder')
                meas = (counts - prevCounts) / 5200 * 60 / c.Ts;
                if kk == 1, meas = 0; end
            elseif isSpeed
                meas = wf;
                if c.quant && m.qSpd > 0, meas = round(meas / m.qSpd) * m.qSpd; end
            else
                meas = counts * 360 / 5200;
            end
            prevCounts = counts;
            e = r - meas; sat = false;
            if strcmp(c.ctrl, 'OL')
                u = min(max(r, -c.uMax), c.uMax);
            elseif c.antiWindup
                [u, st, sat] = servolab.motor.pidStep(st, e, g);
            else
                [u, st, sat] = pidNoAntiWindup(st, e, g);
            end
            tk(kk) = t(k); rk(kk) = r; ym(kk) = meas; ek(kk) = e; uk(kk) = u; sk(kk) = sat;
            uPending = u; kApply = k + nLat;
        end
        if k >= kApply, uApplied = uPending; kApply = Inf; end

        w(k) = wf; thM(k) = th; thO(k) = thOut; uA(k) = uApplied;

        % plant, forward one step
        ud = sign(uApplied) * max(abs(uApplied) - m.dz, 0);           % Simulink Dead Zone semantics
        wr = wr + min(max(ud - wr, -m.acc * dt), m.acc * dt);           % acceleration limit
        x1 = a * x1 + (1 - a) * m.K * wr;                                 % K/(tau s + 1), exact ZOH
        delayBuf(dIdx) = x1; dIdx = mod(dIdx, nDel + 1) + 1;
        wf = delayBuf(dIdx);                                             % theta later
        th = th + wf * 6 * dt;                                           % rpm -> deg/s
        hb = m.backlash / 2;                                              % backlash: dead band on angle
        if th - thOut > hb, thOut = th - hb; elseif thOut - th > hb, thOut = th + hb; end
    end

    S = struct('t', t, 'w', w, 'thMotor', thM, 'thOut', thO, 'uApplied', uA, ...
               'tk', tk(1:kk), 'r', rk(1:kk), 'meas', ym(1:kk), 'e', ek(1:kk), 'u', uk(1:kk), ...
               'sat', sk(1:kk), 'm', m, 'cfg', c);
end

function [u, st, sat] = pidNoAntiWindup(st, e, g)
    % the same law with a plain integrator (what S3-12 warns about)
    if st.first, d = 0; else, d = (g.Tf * st.d + g.Kd * (e - st.e)) / (g.Tf + g.Ts); end
    st.i = st.i + g.Ki * g.Ts * e;
    uRaw = g.Kp * e + st.i + d;
    u = min(max(uRaw, -g.uMax), g.uMax); sat = u ~= uRaw;
    st.d = d; st.e = e; st.first = false;
end
