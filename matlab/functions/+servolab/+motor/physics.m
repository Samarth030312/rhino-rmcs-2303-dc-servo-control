function [P, D] = physics(spec)
%PHYSICS  Motor and drive parameters derived from datasheet values you can change.
%
%   [P, D] = servolab.motor.physics()          % the RMCS-5032 / RMCS-2303 / Pro-Range 3S Li-ion battery
%   [P, D] = servolab.motor.physics(spec)      % spec: any subset of servolab.motor.physics().spec fields
%
%   Datasheet inputs (spec, defaults from SRC-003 / SRC-002 unless marked):
%     V_nom 12 V, w_nl_out 180 rpm, N 100, I_nl 0.8 A, I_stall 7.5 A (the datasheet's "load
%     current up to 7.5 A", taken as stall: ESTIMATED), eta 1 (ASSUMED), J_rotor 1e-6 kg m^2
%     (ESTIMATED), L 0.5 mH (ESTIMATED), lines 13, J_load_out 0 (nothing on the shaft),
%     J_factor 1 (x1.5 for "+50 % inertia"), I_drive 3 A (RMCS-2303 manual: peak 3 A per phase;
%     the Robokits page says 5 A peak, conflict C-M7).
%   Battery (the lab's Pro-Range INR18650 Li-ion 3S2P pack, seller listing): capacity_mAh 4400,
%     C_rate 2 (8.8 A continuous), cells 3 in series, V_cell_full 4.2, V_cell_nom 3.7,
%     V_cell_cut 3.0 V. V_supply 11.1 V (nominal) unless soc (state of charge, %) is given:
%     then V_supply = cells x the Li-ion open-circuit voltage at that charge (typical NMC curve,
%     ESTIMATED; the pack's own curve is not published).
%   Derived (standard permanent-magnet DC motor relations, base-motor side):
%     R  = V_nom / I_stall                         (stall: back-EMF zero)
%     Ke = (V_nom - I_nl R) / w_nl                  w_nl = N * w_nl_out in rad/s
%     Kt = Ke                                       (SI units)
%     b  = Kt I_nl / w_nl                           (no-load friction as viscous)
%     J  = J_factor (J_rotor + J_load_out / N^2)
%     tau_e = L / R,  tau_m = J R / (Kt Ke + R b)
%     w(s)/V(s) = Kt / ((J s + b)(L s + R) + Kt Ke)   (base rad/s per volt)
%   P is servolab.motor.params() with these values in place, ready for servolab.motor.simulate.
%   D holds the derived numbers and the transfer function (num, den; and in output rpm per V).
    def = struct('V_nom', 12, 'w_nl_out', 180, 'N', 100, 'I_nl', 0.8, 'I_stall', 7.5, 'eta', 1, ...
        'J_rotor', 1e-6, 'L', 0.5e-3, 'lines', 13, 'J_load_out', 0, 'J_factor', 1, ...
        'V_supply', 11.1, 'capacity_mAh', 4400, 'I_drive', 3, 'C_rate', 2, 'cells', 3, ...
        'V_cell_full', 4.2, 'V_cell_nom', 3.7, 'V_cell_cut', 3.0, 'soc', NaN);
    if nargin < 1, spec = struct(); end
    for f = fieldnames(def)', if ~isfield(spec, f{1}) || isempty(spec.(f{1})), spec.(f{1}) = def.(f{1}); end, end
    if isfinite(spec.soc), spec.V_supply = spec.cells * ocv(spec.soc, spec); end
    P = servolab.motor.params();
    rpm = 2 * pi / 60;
    w_nl = spec.w_nl_out * spec.N * rpm;
    R = spec.V_nom / spec.I_stall;
    Ke = (spec.V_nom - spec.I_nl * R) / w_nl;
    Kt = Ke; b = Kt * spec.I_nl / w_nl;
    J = spec.J_factor * (spec.J_rotor + spec.J_load_out / spec.N^2);
    P.N = spec.N; P.V_nom = spec.V_nom; P.w_nl_base = w_nl; P.I_nl = spec.I_nl;
    P.R = R; P.Ke = Ke; P.Kt = Kt; P.b = b; P.L = spec.L; P.eta = spec.eta;
    P.J = spec.J_factor * spec.J_rotor; P.J_load_out = spec.J_factor * spec.J_load_out;
    P.V_supply = spec.V_supply; P.I_lim_drive = spec.I_drive;
    P.lines = spec.lines; P.cpr_out = 4 * spec.lines * spec.N; P.deg_per_count = 360 / P.cpr_out;
    st = {'R', 'Ke', 'Kt', 'b'};
    for k = 1:numel(st), P.meta.(st{k}).status = 'ESTIMATED'; P.meta.(st{k}).note = 'derived from the datasheet values in servolab.motor.physics'; end
    num = Kt; den = [J * spec.L, J * R + b * spec.L, b * R + Kt * Ke];
    D = struct('spec', spec, 'R', R, 'Ke', Ke, 'Kt', Kt, 'b', b, 'J', J, 'L', spec.L, ...
        'tau_e', spec.L / R, 'tau_m', J * R / (Kt * Ke + R * b), 'num', num, 'den', den, ...
        'gain_rpm_per_V', Kt / (b * R + Kt * Ke) / rpm / spec.N, ...
        'w_free_out', spec.V_supply * Kt / (b * R + Kt * Ke) / rpm / spec.N, ...
        'T_stall_out', Kt * spec.I_stall * spec.N * spec.eta, 'cpr_out', P.cpr_out);
    D.tf = sprintf('w(s)/V(s) = %.4g / (%.3g s^2 + %.3g s + %.3g)  [base rad/s per V]', num, den);
    % supply chain: what limits the current, and for how long the battery lasts
    D.V_full = spec.cells * spec.V_cell_full; D.V_cut = spec.cells * spec.V_cell_cut;
    D.I_batt_max = spec.C_rate * spec.capacity_mAh / 1000;          % A, continuous
    D.I_stall_at_V = spec.V_supply / R;                               % A, motor at standstill, full voltage
    lim = [D.I_stall_at_V, spec.I_drive, D.I_batt_max];
    names = {'the motor (stall)', 'the drive', 'the battery'};
    [D.I_limit, k] = min(lim); D.I_limit_by = names{k};
    D.T_max_out = Kt * D.I_limit * spec.N * spec.eta;                 % N m at the output shaft
    D.runtime_noload_h = spec.capacity_mAh / 1000 / spec.I_nl;        % free running, ideal
end

function v = ocv(soc, s)
    % typical Li-ion (NMC 18650) open-circuit voltage per cell against state of charge (ESTIMATED)
    q = [0 5 10 20 30 40 50 60 70 80 90 100];
    c = [3.00 3.30 3.45 3.55 3.62 3.68 3.73 3.79 3.86 3.95 4.06 4.20];
    c = s.V_cell_cut + (c - 3.00) * (s.V_cell_full - s.V_cell_cut) / (4.20 - 3.00);
    v = interp1(q, c, min(max(soc, 0), 100));
end
