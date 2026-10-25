function T = motor_simulate_all(outFile)
%MOTOR_SIMULATE_ALL  Every preset of every mission, in the MATLAB simulator and in Simulink.
%
%   T = motor_simulate_all()                 % writes results/tables/simulation_all_presets.csv
%   T = motor_simulate_all(outFile)
%
%   For each entry of servolab.motor.presets(): its config (servolab.motor.specConfig) is
%   simulated on its plant in MATLAB (servolab.motor.simulatePlant) and scored with
%   servolab.motor.stepMetrics; with Simulink installed it is also run in the plant's Simulink
%   model (servolab.motor.runSimulink) and the largest difference of the measured signal and of
%   the command at the controller samples is reported. An "all runs" entry is covered by its
%   single runs; a rig experiment is also run on the drive physics (plant 'rigPhys'). Errors are
%   recorded per row, not thrown, so one table shows everything.
    if nargin < 1, outFile = fullfile(servolab.repoRoot(), 'results', 'tables', 'simulation_all_presets.csv'); end
    L = servolab.motor.presets();
    L = L(arrayfun(@(x) isempty(x.series), L));
    for k = find(arrayfun(@(x) strcmp(x.spec.plant, 'rigId'), L))   % a rig experiment also on the drive physics
        x = L(k); x.spec.plant = 'rigPhys'; L(end + 1) = x; %#ok<AGROW>
    end
    hasSL = ~isempty(ver('simulink')) && license('test', 'Simulink');
    rows = cell(numel(L), 15);  % sized after the rigPhys copies are added
    for k = 1:numel(L)
        sp = L(k).spec; c = servolab.motor.specConfig(sp);
        rise = NaN; over = NaN; ess = NaN; peakU = NaN; dMeas = NaN; dU = NaN; mdl = ''; err = '';
        try
            S = servolab.motor.simulatePlant(c);
            res = 0; if strcmp(c.loop, 'position'), res = c.P.deg_per_count; end
            m = servolab.motor.stepMetrics(S.tk, S.r, S.meas, S.u, 'Resolution', res, 'uMax', c.uMax);
            rise = m.rise; over = m.overshoot; ess = m.ess; peakU = max(abs(S.u));
            if hasSL
                R = servolab.motor.runSimulink(c); mdl = R.model;
                n = min(numel(R.tk), numel(S.tk));
                dMeas = max(abs(R.meas(1:n) - S.meas(1:n))); dU = max(abs(R.u(1:n) - S.u(1:n)));
            end
        catch e
            err = e.message;
        end
        rows(k, :) = {L(k).mission, L(k).label, sp.plant, c.loop, c.ctrl, c.Kp, c.Ki, rise, over, ess, peakU, mdl, dMeas, dU, err};
        fprintf('%-4s %-60s %-7s %s\n', L(k).mission, L(k).label, sp.plant, ternary(isempty(err), 'ok', ['ERROR ' err]));
    end
    T = cell2table(rows, 'VariableNames', {'mission', 'preset', 'plant', 'loop', 'ctrl', 'Kp', 'Ki', 'rise_s', ...
        'overshoot_pct', 'ess', 'peak_u', 'simulink_model', 'simulink_max_dmeas', 'simulink_max_du', 'error'});
    if ~isfolder(fileparts(outFile)), mkdir(fileparts(outFile)); end
    writetable(T, outFile);
end

function v = ternary(c, a, b), if c, v = a; else, v = b; end, end
