function m = fitFOPDT(t, y, du, opts)
%FITFOPDT  Fit a first-order-plus-dead-time step response y = y0 + K*du*(1 - exp(-(t-theta)/tau)).
%
%   m = servolab.ident.fitFOPDT(t, y, du)
%   m = servolab.ident.fitFOPDT(t, y, du, struct('theta', 0))     % fix the dead time
%   m = servolab.ident.fitFOPDT(t, y, du, struct('theta', 0, 'K', 1))   % ... and the gain
%
%   t   time since the input step (s), column; y measured output; du input step size.
%   Returns m.K (output per input unit), m.tau (s), m.theta (s), m.y0, m.yInf,
%   m.rmse, m.fit (model on t), m.r2, and m.t63 (graphical 63 % time, for comparison
%   with the hand method the course asks for).
%
%   Least squares by fminsearch from a graphical start (y0 = first sample, yInf = mean
%   of the last 20 %, t63 = first crossing of 63 %). Base MATLAB only.

    if nargin < 4, opts = struct(); end
    t = t(:); y = y(:);
    ok = isfinite(t) & isfinite(y); t = t(ok); y = y(ok);
    assert(numel(t) >= 5, 'servolab:ident:data', 'need at least 5 samples');
    assert(du ~= 0, 'servolab:ident:du', 'input step must be non-zero');

    n = numel(y);
    y0 = y(1);
    yInf = mean(y(max(1, round(0.8 * n)):end));
    k63 = find(sign(yInf - y0) * (y - (y0 + 0.632 * (yInf - y0))) >= 0, 1);
    if isempty(k63), t63 = t(end) / 2; else, t63 = t(k63); end
    fixTheta = isfield(opts, 'theta');

    model = @(p, tt) p(1) + p(2) * du * (1 - exp(-max(tt - p(4), 0) / max(p(3), 1e-6)));
    if fixTheta && isfield(opts, 'K')
        p0 = max(t63 - opts.theta, 1e-3);
        cost = @(q) sum((y - model([y0, opts.K, q, opts.theta], t)).^2);
    elseif fixTheta
        p0 = [y0, (yInf - y0) / du, max(t63 - opts.theta, 1e-3)];
        cost = @(q) sum((y - model([q, opts.theta], t)).^2);
    else
        p0 = [y0, (yInf - y0) / du, max(0.7 * t63, 1e-3), 0.3 * t63];
        cost = @(q) sum((y - model(q, t)).^2) + 1e6 * (q(4) < 0) * q(4)^2;
    end
    q = fminsearch(cost, p0, optimset('Display', 'off', 'MaxFunEvals', 4000, 'MaxIter', 4000));
    if fixTheta && isfield(opts, 'K'), q = [y0, opts.K, q, opts.theta];
    elseif fixTheta, q = [q, opts.theta]; end

    m.y0 = q(1); m.K = q(2); m.tau = abs(q(3)); m.theta = max(q(4), 0);
    m.yInf = m.y0 + m.K * du;
    m.fit = model([m.y0, m.K, m.tau, m.theta], t);
    m.rmse = sqrt(mean((y - m.fit).^2));
    m.r2 = 1 - sum((y - m.fit).^2) / max(sum((y - mean(y)).^2), eps);
    m.t63 = t63;
    m.du = du;
end
