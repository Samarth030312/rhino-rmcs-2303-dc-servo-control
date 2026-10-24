function m = metrics(S)
%METRICS  Step-response and disturbance metrics from a simulated or measured run.
%
%   m = servolab.motor.metrics(S)
%
%   S needs t, r, y, u (fine grid) and cfg (setpoint, tStep, Tend, dist, tDist,
%   uMax, loop). Works on hardware logs too, as long as those fields exist.
%
%   The step window ends at the disturbance (if any) so that load effects do
%   not contaminate rise / overshoot / settling.
%
%   Settling band: 2 % of the step, but never tighter than the feedback
%   resolution (2 encoder counts, or 1 output rpm), because a loop cannot
%   settle closer than it can measure.

    c = S.cfg;
    v = isfinite(S.y);
    tEnd = c.Tend;
    if c.dist ~= 0 && c.tDist < c.Tend, tEnd = c.tDist; end
    w = v & S.t >= c.tStep & S.t < tEnd;
    A = c.setpoint;
    if strcmp(c.loop, 'speed'), res = 1; else, res = 2 * c.P.deg_per_count; end
    m.band = max(0.02 * abs(A), res);

    [m.rise, m.over, m.settle, m.ess, m.ess_pct] = deal(NaN);
    if any(w) && A ~= 0
        tt = S.t(w); yy = S.y(w);
        yn = yy / A;                                % normalised response
        i10 = find(yn >= 0.1, 1); i90 = find(yn >= 0.9, 1);
        if ~isempty(i10) && ~isempty(i90), m.rise = tt(i90) - tt(i10); end
        m.over = 100 * max(0, max(yn) - 1);
        tail = tt >= tt(end) - 0.1 * (tt(end) - tt(1));
        m.ess = A - mean(yy(tail));
        m.ess_pct = 100 * m.ess / A;
        out = abs(yy - A) > m.band;
        if out(end), m.settle = NaN;
        elseif ~any(out), m.settle = 0;
        else, m.settle = tt(find(out, 1, 'last') + 1) - c.tStep;
        end
    end

    m.peakU = max(abs(S.u(v)));
    m.satFrac = mean(abs(S.u(v)) >= c.uMax - 1e-9);
    m.iae = trapz(S.t(v), abs(S.r(v) - S.y(v)));

    % Disturbance: worst deviation from the setpoint after the load step, and
    % where the output ends up.
    [m.distPeak, m.distFinal] = deal(NaN);
    if c.dist ~= 0 && c.tDist < c.Tend
        d = v & S.t >= c.tDist;
        dev = S.r(d) - S.y(d);
        [~, j] = max(abs(dev)); m.distPeak = dev(j);
        dd = S.t(d); m.distFinal = mean(dev(dd >= dd(end) - 0.1 * (dd(end) - dd(1))));
    end

    % Verdict on the last second (or last 20 %) of the run.
    tl = v & S.t >= S.t(find(v, 1, 'last')) - max(1, 0.2 * c.Tend);
    span = max(S.y(tl)) - min(S.y(tl));
    if S.diverged || ~all(v)
        m.verdict = 'DIVERGED';
    elseif span > max(0.05 * abs(A), 4 * m.band)
        m.verdict = 'OSCILLATING';
    elseif isnan(m.settle) && span <= m.band
        m.verdict = 'STEADY, OFFSET';            % at rest, but outside the band
    elseif isnan(m.settle)
        m.verdict = 'NOT SETTLED';
    else
        m.verdict = 'SETTLED';
    end
end
