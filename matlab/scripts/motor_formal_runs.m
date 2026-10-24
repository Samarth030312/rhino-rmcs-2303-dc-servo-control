function T = motor_formal_runs(recordVideos, figuresOnly)
%MOTOR_FORMAL_RUNS  Run, export and summarise every DC-motor simulation preset.
%
%   T = motor_formal_runs()          % evidence + figures + metrics table
%   T = motor_formal_runs(true)      % also record one video per mission
%                                    % with rhino_servo_lab (needs a display)
%   motor_formal_runs(false, true)   % regenerate the comparison figures only
%
%   Writes
%     results/evidence/simulation_runs/dc_motor/<run_id>/   one folder per preset
%     results/tables/dc_motor_simulation_metrics.csv
%     results/figures/dc_motor/*.png                         comparison figures
%
%   Everything written here is SIMULATION output with ESTIMATED parameters.

    if nargin < 1, recordVideos = false; end
    if nargin < 2, figuresOnly = false; end
    root = servolab.repoRoot();
    figDir = fullfile(root, 'results', 'figures', 'dc_motor');
    tabDir = fullfile(root, 'results', 'tables');
    if ~exist(figDir, 'dir'), mkdir(figDir); end
    if ~exist(tabDir, 'dir'), mkdir(tabDir); end

    T = table();
    if ~figuresOnly, T = runAllPresets(tabDir); end
    makeFigures(figDir);
    if recordVideos, recordKeyRuns(); end
end

function T = runAllPresets(tabDir)
    p = servolab.motor.presets();
    rows = cell(numel(p), 1);
    for k = 1:numel(p)
        c = servolab.motor.presetConfig(p(k).name);
        S = servolab.motor.simulate(c);
        out = servolab.motor.exportRun(S, [], struct('preset', p(k).name));
        m = S.metrics;
        rows{k} = {p(k).name, c.experiment, c.plant, c.loop, c.ctrl, c.Kp, c.Ki, c.Kd, c.Ts, c.dist, ...
                   m.verdict, m.rise, m.over, m.settle, m.ess_pct, m.distPeak, m.distFinal, m.peakU, ...
                   100 * m.satFrac, out.runId};
        fprintf('%-45s %-14s -> %s\n', p(k).name, m.verdict, out.runId);
    end
    T = cell2table(vertcat(rows{:}), 'VariableNames', {'preset', 'experiment', 'plant', 'loop', 'ctrl', ...
        'Kp', 'Ki', 'Kd', 'Ts_s', 'load_Nm', 'verdict', 'rise_s', 'overshoot_pct', 'settling_s', ...
        'ss_error_pct', 'load_worst_dev', 'load_final_err', 'peak_u', 'saturated_pct', 'run_id'});
    writetable(T, fullfile(tabDir, 'dc_motor_simulation_metrics.csv'));
end

function makeFigures(figDir)
    compare(figDir, 'rig_speed_P_I_PI', 'Lab rig, speed loop: P vs I vs PI (Arduino outer loop, Ts = 0.1 s)', ...
        {'Rig - speed - P, Kp 0.5', 'Rig - speed - I, Ki 1.0', 'Rig - speed - PI, Kp 0.3 Ki 1.5', 'Rig - speed - P, Kp 1.2 (too high)'});
    compare(figDir, 'rig_position_P_I_PI', 'Lab rig, position loop: P vs I vs PI (Ts = 0.15 s)', ...
        {'Rig - position - P, Kp 0.3', 'Rig - position - I only, Ki 0.1', 'Rig - position - PI, Kp 0.3 Ki 0.03', 'Rig - position - open loop (timed)'});
    compare(figDir, 'bare_speed_disturbance', 'Bare motor (course week 4), speed: open loop vs P vs PI, 0.5 N*m load at 3 s', ...
        {'Bare motor - speed - open loop + load', 'Bare motor - speed - P + load', 'Bare motor - speed - PI + load'});
    compare(figDir, 'bare_position_disturbance', 'Bare motor, position: P vs PID, 0.5 N*m load at 3 s', ...
        {'Bare motor - position - P + load', 'Bare motor - position - PID + load'});
    sweepSpeedP(figDir);
end

function f = newFigure(pos)
    f = figure('Visible', 'off', 'Position', pos, 'Color', 'w');
    if exist('theme', 'file'), theme(f, 'light'); end     % batch MATLAB defaults to dark
end

function compare(figDir, file, ttl, names)
    f = newFigure([100 100 1100 720]);
    tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact');
    title(tl, {ttl, 'SIMULATION - model with ESTIMATED parameters, not measured'}, 'FontWeight', 'bold');
    ax = [nexttile(tl, [2 1]), nexttile(tl)];
    hold(ax(1), 'on'); hold(ax(2), 'on'); grid(ax(1), 'on'); grid(ax(2), 'on');
    cols = lines(numel(names));
    for k = 1:numel(names)
        S = servolab.motor.simulate(servolab.motor.presetConfig(names{k}));
        lbl = sprintf('%s  [%s]', erase(names{k}, {'Rig - ', 'Bare motor - '}), S.metrics.verdict);
        plot(ax(1), S.t, S.y, 'Color', cols(k, :), 'LineWidth', 1.8, 'DisplayName', lbl);
        stairs(ax(2), S.t, S.u, 'Color', cols(k, :), 'LineWidth', 1.2, 'HandleVisibility', 'off');
    end
    plot(ax(1), S.t, S.r, 'k--', 'LineWidth', 1.2, 'DisplayName', 'setpoint');
    if S.cfg.dist ~= 0, xline(ax(1), S.cfg.tDist, ':', 'load applied', 'Color', [0.85 0.52 0.05], 'HandleVisibility', 'off'); end
    ylabel(ax(1), S.units.y); ylabel(ax(2), S.units.u); xlabel(ax(2), 't (s)');
    legend(ax(1), 'Location', 'southeast');
    exportgraphics(f, fullfile(figDir, [file '.png']), 'Resolution', 150);
    close(f);
end

function sweepSpeedP(figDir)
%SWEEPSPEEDP  Steady-state error of outer speed P vs gain, simulation vs r/(1+Kp).
    Kp = 0.1:0.1:0.9; e = nan(size(Kp));
    for k = 1:numel(Kp)
        c = servolab.motor.defaultConfig('rig', 'speed'); c.ctrl = 'P'; c.Kp = Kp(k); c.Ki = 0; c.Tend = 8;
        S = servolab.motor.simulate(c); e(k) = S.metrics.ess_pct;
    end
    f = newFigure([100 100 800 480]);
    ax = axes(f); hold(ax, 'on'); grid(ax, 'on');
    kk = linspace(0.05, 1, 100);
    plot(ax, kk, 100 ./ (1 + kk), 'k-', 'LineWidth', 1.4, 'DisplayName', 'theory  e_{ss} = r / (1 + K_p)');
    plot(ax, Kp, e, 'o', 'MarkerFaceColor', [0.16 0.38 0.78], 'MarkerEdgeColor', 'w', 'MarkerSize', 9, ...
         'DisplayName', 'simulation (Ts 0.1 s, quantised)');
    xline(ax, 1, '--', 'oscillates beyond', 'Color', [0.8 0.18 0.16], 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
    xlabel(ax, 'K_p (command rpm per rpm of error)'); ylabel(ax, 'steady-state error (% of setpoint)');
    title(ax, {'Lab rig, speed loop, P only: why P alone is not enough', 'SIMULATION - not measured'});
    legend(ax, 'Location', 'northeast'); xlim(ax, [0 1.1]);
    exportgraphics(f, fullfile(figDir, 'rig_speed_P_steady_state_error.png'), 'Resolution', 150);
    close(f);
end

function recordKeyRuns()
    % one video per mission (first preset), from the mission-control app
    app = rhino_servo_lab();
    cleanup = onCleanup(@() delete(app.fig));
    M = servolab.motor.missions();
    for k = 1:numel(M) - 1
        app.selectMission(k); app.setPreset(1); drawnow; pause(0.5);
        outDir = fullfile(servolab.repoRoot(), 'results', 'evidence', 'simulation_runs', 'dc_motor', ...
            sprintf('MISSION-%s-SIM-%s', M(k).tag, char(datetime('now', 'Format', 'yyyyMMdd-HHmmss'))));
        v = app.record(outDir, 'sim');
        fprintf('recorded %-4s %-14s -> %s\n', M(k).tag, M(k).short, v);
    end
end
