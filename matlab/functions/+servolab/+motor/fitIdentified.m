function [m, fitInfo] = fitIdentified(runIds, opts)
%FITIDENTIFIED  Fit the identified rig model (servolab.motor.identifiedSim) to open-loop hardware runs.
%
%   [m, info] = servolab.motor.fitIdentified({'MOTOR-02-HW-...', ...})
%   [m, info] = servolab.motor.fitIdentified(ids, struct('fitAcc', false, 'acc', 50))
%
%   Free parameters: K, tau, theta and (unless opts.fitAcc is false) the acceleration
%   limit acc in output rpm/s. Fixed: Modbus latency c.latency (default config), the
%   speed-register quantum (params spd_fb_step_base_rpm), no dead zone.
%   The cost is the sum of squared errors between the measured speed and the model's
%   speed sampled at the telemetry instants, over all runs together.
%
%   info.runs(k): id, tk, meas, sim, rmse;  info.rmse overall.

    if nargin < 2, opts = struct(); end
    if ~isfield(opts, 'fitAcc'), opts.fitAcc = true; end
    P = servolab.motor.params();
    D = cellfun(@prepare, runIds);
    accReg = P.acc_base_rpm_s / P.N;                      % 50 output rpm/s if the units are base rpm/s
    if isfield(opts, 'acc'), accReg = opts.acc; end

    if opts.fitAcc
        p0 = [1, 0.3, 0.15, accReg];
    else
        p0 = [1, 0.3, 0.15];
    end
    cost = @(p) sum(cellfun(@(e) sum(e.^2), arrayfun(@(d) residual(p, d), D, 'UniformOutput', false)));
    p = fminsearch(cost, p0, optimset('Display', 'off', 'MaxFunEvals', 600, 'MaxIter', 600, 'TolX', 1e-4));
    m = toModel(p);
    fitInfo.rmse = sqrt(cost(p) / sum(arrayfun(@(d) numel(d.meas), D)));
    for k = 1:numel(D)
        [res, sim] = residual(p, D(k));
        fitInfo.runs(k) = struct('id', D(k).id, 'tk', D(k).tk, 'meas', D(k).meas, 'sim', sim, ...
                                 'r', D(k).r, 'rmse', sqrt(mean(res.^2)));
    end
    fitInfo.accFitted = opts.fitAcc;

    function mm = toModel(p)
        mm = struct('K', p(1), 'tau', abs(p(2)), 'theta', max(p(3), 0), 'acc', accReg, ...
                    'dz', 0, 'qSpd', P.spd_fb_step_base_rpm / P.N, 'backlash', 0, 'sensorAtLoad', false);
        if numel(p) > 3, mm.acc = abs(p(4)); end
    end

    function [res, sim] = residual(p, d)
        mm = toModel(p);
        c = d.cfg; c.quant = false;                        % smooth cost; data are quantised
        S = servolab.motor.identifiedSim(mm, c, d.profile, d.tk(end) + 1e-9);
        sim = interp1(S.tk, S.meas, d.tk, 'previous', 'extrap');
        res = d.meas - sim;
        res = res(2:end);                                  % sample 1 can hold a stale register value
    end
end

function d = prepare(id)
    R = servolab.motor.loadHardwareRun(id);
    T = R.T;
    c = R.cfg; c.ctrl = 'OL';
    t0 = T.t_ms(1) / 1000;                                 % first telemetry sample = model sample 1
    d.id = id; d.cfg = c;
    d.tk = T.t_ms / 1000 - t0;
    d.meas = T.meas; d.r = T.setpoint;
    ch = [1; find(diff(T.setpoint) ~= 0) + 1];
    d.profile = [d.tk(ch), T.setpoint(ch)];
end
