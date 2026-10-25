function S = simulatePlant(c, m)
%SIMULATEPLANT  Simulate a config on its plant in MATLAB, in the shape the app draws.
%
%   S = servolab.motor.simulatePlant(c)       % c from specConfig, or the app's panel
%   S = servolab.motor.simulatePlant(c, m)    % m: identified model (default rigModel)
%
%   c.plantKey 'rigId'  -> servolab.motor.identifiedSim(m, c, c.profile, c.Tend)
%              'rigPhys' or 'arm' -> servolab.motor.simulate(c)
%   S.t, S.w (output rpm), S.thOut (deg), S.i (A, physics plants), fine grid; S.iBatt (A, mean
%   battery current, physics plants);
%   S.tk, S.r, S.meas, S.e, S.u at the controller samples; S.diverged.
    if nargin < 2, m = servolab.motor.rigModel(); end
    if strcmp(c.plantKey, 'rigId')
        S = servolab.motor.identifiedSim(m, c, c.profile, c.Tend);
        S.diverged = false;
        return
    end
    Sp = servolab.motor.simulate(c);
    k = min(numel(Sp.t), round(Sp.tk / c.dt) + 1);
    S = struct('t', Sp.t, 'w', Sp.w_rpm, 'thOut', Sp.th_deg, 'i', Sp.i, 'tk', Sp.tk, 'r', Sp.r(k), ...
        'meas', Sp.ym, 'u', Sp.uk, 'e', Sp.e, 'uFine', Sp.u, 'diverged', Sp.diverged, 'cfg', c);
    n = find(isfinite(S.w), 1, 'last'); S.w(n + 1:end) = NaN;
    % electrical power drawn: (back-EMF + R i) i, base side; mean battery current = power / supply voltage
    P = c.P; wB = S.w * P.N * P.rpm; pe = max(0, (P.Ke * wB + P.R * S.i) .* S.i);
    S.iBatt = mean(pe(isfinite(pe))) / P.V_supply;
end
