function out = exportRun(S, outRoot, extra)
%EXPORTRUN  Write a simulation run to disk as evidence.
%
%   out = servolab.motor.exportRun(S)                 % default location
%   out = servolab.motor.exportRun(S, outRoot, extra)
%
%   Creates <outRoot>/<run_id>/ with
%     trace.csv        fine-grid plant signals (true values, not measured)
%     samples.csv      controller-sample signals (what the Arduino would see/send)
%     run_config.json  every parameter, its status, MATLAB version, git revision
%     summary.md       metrics and the data-class statement
%
%   Default outRoot: results/evidence/simulation_runs/dc_motor
%   extra (struct, optional) is merged into run_config.json (e.g. video file).
%
%   The CSVs are SIMULATION data. They must never be copied into data/raw/.

    if nargin < 2 || isempty(outRoot)
        outRoot = fullfile(servolab.repoRoot(), 'results', 'evidence', 'simulation_runs', 'dc_motor');
    end
    if nargin < 3, extra = struct(); end
    c = S.cfg;
    exp = c.experiment; if isempty(exp), exp = 'MOTOR-XX'; end
    runId = servolab.newRunId(sprintf('%s-SIM', exp), @(id) exist(fullfile(outRoot, id), 'file'));
    dirOut = fullfile(outRoot, runId);
    mkdir(dirOut);

    v = isfinite(S.y);
    T = table(S.t(v), S.r(v), S.y(v), S.u(v), S.i(v), S.w_rpm(v), S.th_deg(v), ...
        'VariableNames', {'t_s', 'setpoint', 'output_true', 'control_applied', ...
                          'current_A', 'speed_out_rpm', 'angle_out_deg'});
    writetable(T, fullfile(dirOut, 'trace.csv'));
    K = table(S.tk, S.ym, S.e, S.uk, double(S.sat), ...
        'VariableNames', {'t_s', 'measurement', 'error', 'control_output', 'saturated'});
    writetable(K, fullfile(dirOut, 'samples.csv'));

    cfg = rmfield(c, 'P');
    meta = struct();
    meta.run_id = runId;
    meta.data_class = 'SIMULATION';
    meta.statement = 'MODEL output. Not measured. Plant parameters are ESTIMATED unless marked otherwise.';
    meta.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssZ', 'TimeZone', 'local'));
    meta.matlab_version = version();
    meta.git = gitInfo();
    meta.config = cfg;
    meta.units = S.units;
    meta.parameters = paramTable(c.P);
    meta.metrics = S.metrics;
    f = fieldnames(extra);
    for i = 1:numel(f), meta.(f{i}) = extra.(f{i}); end
    fid = fopen(fullfile(dirOut, 'run_config.json'), 'w');
    assert(fid > 0, 'servolab:export:open', 'cannot write %s', dirOut);
    fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true));
    fclose(fid);

    writeSummary(fullfile(dirOut, 'summary.md'), meta, S);
    out = struct('runId', runId, 'dir', dirOut);
end

function p = paramTable(P)
    f = fieldnames(P.meta);
    p = struct();
    for i = 1:numel(f)
        m = P.meta.(f{i});
        p.(f{i}) = struct('value', P.(f{i}), 'unit', m.unit, 'status', m.status, 'source', m.source);
    end
end

function g = gitInfo()
    root = servolab.repoRoot();
    [s1, rev] = system(sprintf('git -C "%s" rev-parse --short HEAD', root));
    [s2, st]  = system(sprintf('git -C "%s" status --porcelain', root));
    g = struct('revision', strtrim(rev), 'dirty', s2 == 0 && ~isempty(strtrim(st)));
    if s1 ~= 0, g.revision = 'unknown'; end
end

function writeSummary(file, meta, S)
    c = meta.config; m = S.metrics;
    fid = fopen(file, 'w');
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '# %s\n\n', meta.run_id);
    fprintf(fid, '**Data class: SIMULATION.** %s\n\n', meta.statement);
    fprintf(fid, '| Setting | Value |\n|---|---|\n');
    fprintf(fid, '| Plant | %s |\n| Loop | %s |\n| Controller | %s |\n', c.plant, c.loop, c.ctrl);
    fprintf(fid, '| Kp / Ki / Kd | %g / %g / %g |\n', c.Kp, c.Ki, c.Kd);
    fprintf(fid, '| Ts / latency | %g s / %g s |\n', c.Ts, c.latency);
    fprintf(fid, '| Setpoint | %g %s at t = %g s |\n', c.setpoint, S.units.y, c.tStep);
    fprintf(fid, '| Load step | %g N*m at the output, t = %g s |\n', c.dist, c.tDist);
    fprintf(fid, '| Output limit | +/-%g %s |\n', c.uMax, S.units.u);
    fprintf(fid, '| Quantisation | %d |\n| Duration | %g s |\n', c.quant, c.Tend);
    fprintf(fid, '| MATLAB | %s |\n| Git | %s (dirty: %d) |\n\n', meta.matlab_version, meta.git.revision, meta.git.dirty);
    fprintf(fid, '## Metrics\n\n| Metric | Value |\n|---|---|\n');
    fprintf(fid, '| Verdict | %s |\n| Rise time 10-90 %% | %.3f s |\n| Overshoot | %.1f %% |\n', m.verdict, m.rise, m.over);
    fprintf(fid, '| Settling (band %.3g) | %.2f s |\n| Steady-state error | %.3g (%.2f %%) |\n', m.band, m.settle, m.ess, m.ess_pct);
    fprintf(fid, '| Peak control | %.3g |\n| Time saturated | %.0f %% |\n| IAE | %.3g |\n', m.peakU, 100 * m.satFrac, m.iae);
    fprintf(fid, '| Worst deviation after load | %.3g |\n| Final error under load | %.3g |\n\n', m.distPeak, m.distFinal);
    fprintf(fid, 'NaN means "not applicable" or "did not happen in the window".\n');
end
