function m = stepMetrics(tk, r, y, u, opts)
%STEPMETRICS  The numbers of the mission table, from sampled data (simulation or rig alike).
%
%   m = servolab.motor.stepMetrics(tk, r, y, u)
%   m = servolab.motor.stepMetrics(tk, r, y, u, 'Resolution', 4.6, 'uMax', 50)
%
%   tk, r, y, u   controller samples: time (s), setpoint, measurement, command
%   Resolution    feedback resolution: the settling band is max(2 % of the step, 1.5 x this)
%   uMax          command limit (for the time at the limit)
%
%   The step is the first constant-setpoint segment whose setpoint differs from the previous
%   setpoint (0 before the run); metrics are computed inside that segment only.
%     rise       10-90 % rise time (s)            overshoot  % of the step
%     settling   time to stay in the band (s)     ess        setpoint - mean of the last 20 %
%     peakU      largest |u| in the segment       gain       mean steady y / setpoint
%     ramp       mean slope between 10 and 90 % (units/s)
%   Static map (every segment that is steady over its last second): map.cmd, map.speed, deadzone
%   (largest |cmd| that gives |speed| < 0.5), mapGain (slope below 90 % of the top speed), wmax.
%   Windup (setpoint drop after saturation): satTime (s at the limit), recovery (s from the
%   drop until y first comes within 5 % of the new setpoint), undershoot (largest dip below it).
%   Missing quantities are NaN; nothing here throws on short or empty data.
    arguments
        tk (:,1) double
        r (:,1) double
        y (:,1) double
        u (:,1) double
        opts.Resolution (1,1) double = 1
        opts.uMax (1,1) double = Inf
    end
    keys = {'rise', 'overshoot', 'settling', 'ess', 'peakU', 'gain', 'ramp', 'deadzone', 'wmax', 'mapGain', ...
            'satTime', 'recovery', 'undershoot', 'step', 'band', 'tStep', 'tEnd'};
    for k = keys, m.(k{1}) = NaN; end
    m.map = struct('cmd', [], 'speed', []);
    ok = isfinite(tk) & isfinite(r) & isfinite(y);
    tk = tk(ok); r = r(ok); y = y(ok); u = u(ok);
    if numel(tk) < 3, return; end

    % ---- segments of constant setpoint
    edges = [1; find(abs(diff(r)) > 1e-9) + 1; numel(r) + 1];
    seg = [edges(1:end - 1), edges(2:end) - 1];
    m.peakU = max(abs(u));
    m.satTime = sum(abs(u) >= opts.uMax - 1e-6) * median(diff(tk));

    % ---- static map: steady speed (last second) of every segment
    for s = 1:size(seg, 1)
        i = seg(s, 1):seg(s, 2);
        tail = i(tk(i) >= tk(i(end)) - 1.0);
        steady = max(y(tail)) - min(y(tail)) <= max(4 * opts.Resolution, 0.05 * abs(mean(y(tail))));
        if tk(i(end)) - tk(i(1)) >= 1.5 && steady
            m.map.cmd(end + 1, 1) = r(i(1)); m.map.speed(end + 1, 1) = mean(y(tail));
        end
    end
    [m.map.cmd, o] = sort(m.map.cmd); m.map.speed = m.map.speed(o);
    if numel(m.map.cmd) >= 3
        c = m.map.cmd; w = m.map.speed;
        m.wmax = max(abs(w));
        dead = abs(w) < 0.5 & c ~= 0;
        if any(dead), m.deadzone = max(abs(c(dead))); else, m.deadzone = 0; end
        lin = abs(w) >= 0.5 & abs(w) < 0.9 * m.wmax;
        if numel(unique(c(lin))) >= 3, p = polyfit(c(lin), w(lin), 1); m.mapGain = p(1); end
    end

    % ---- the step segment
    % the step: the first segment whose setpoint differs from the one before it (0 before the
    % run starts). The measurement is NOT used to find it: the first sample of a run can hold a
    % stale reading (seen: 36.9 rpm from the drive register with the motor at rest).
    prevR = [0; r(seg(1:end - 1, 1))];
    s = find(abs(r(seg(:, 1)) - prevR) > 2 * opts.Resolution, 1);
    if isempty(s), return; end
    i = seg(s, 1):seg(s, 2);
    if s == 1, y0 = prevR(1); else, y0 = y(i(1) - 1); end
    R = r(i(1)); A = R - y0;
    t = tk(i) - tk(i(1)); yy = y(i);
    m.step = A; m.tStep = tk(i(1)); m.tEnd = tk(i(end));
    tail = t >= 0.8 * t(end);
    m.band = max(0.02 * abs(A), 1.5 * opts.Resolution);     % a limit cycle is NOT settled
    yn = (yy - y0) / A;
    i10 = find(yn >= 0.1, 1); i90 = find(yn >= 0.9, 1);
    if ~isempty(i10) && ~isempty(i90) && i90 > i10
        m.rise = t(i90) - t(i10);
        m.ramp = 0.8 * abs(A) / m.rise;
    end
    m.overshoot = 100 * max(0, max(yn) - 1);
    m.ess = R - mean(yy(tail));
    if R ~= 0, m.gain = mean(yy(tail)) / R; end
    out = abs(yy - R) > m.band;
    if ~out(end)
        j = find(out, 1, 'last');
        if isempty(j), m.settling = 0; else, m.settling = t(j + 1); end
    end

    % ---- windup: the next segment, if the setpoint drops after a saturated stretch
    if s < size(seg, 1) && any(abs(u(i)) >= opts.uMax - 1e-6)
        k = seg(s + 1, 1):seg(s + 1, 2);
        R2 = r(k(1)); t2 = tk(k) - tk(k(1)); y2 = y(k);
        j = find(abs(y2 - R2) <= max(0.05 * abs(R2), 1.5 * opts.Resolution), 1);
        if ~isempty(j), m.recovery = t2(j); end
        m.undershoot = max(0, max(sign(R - R2) * (R2 - y2)));
    end
end
