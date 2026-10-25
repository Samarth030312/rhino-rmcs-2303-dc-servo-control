function txt = motor_experiment_catalog(outFile)
%MOTOR_EXPERIMENT_CATALOG  Write docs/EXPERIMENTS.md from the code that defines the experiments.
%
%   motor_experiment_catalog()            % writes docs/EXPERIMENTS.md
%   txt = motor_experiment_catalog('')    % returns the text only
%
%   Every mission (servolab.motor.missions), its experiments (servolab.motor.hwExperiments) and
%   presets (servolab.motor.presets), with each run's settings and what the model of its plant
%   predicts (servolab.motor.simulatePlant, scored by servolab.motor.stepMetrics). Nothing is
%   typed by hand, so the page cannot drift from the app; test_experiment_catalog checks it.
    root = servolab.repoRoot();
    if nargin < 1, outFile = fullfile(root, 'docs', 'EXPERIMENTS.md'); end
    M = servolab.motor.missions(); E = servolab.motor.hwExperiments();
    measured = struct('static_map', 'static-map-steady-speed-against-command', ...
        'ol_step', 'open-loop-step-0---60-rpm', 'position_p_small', 'position-p-final-error-of-10-deg-moves', ...
        'speed_i_sweep', 'speed-i-only-damping-against-ki', 'speed_pi_design', 'speed-pi-designed-for-zeta-07-kp-10-ki-29', ...
        'windup', 'saturation-and-windup-command-limited-to-50-rpm-80-asked-then-30');
    L = {};
    say('# Experiments');
    say('');
    say(['Every experiment the app offers, by mission, generated from the code that defines them ' ...
         '(`matlab/scripts/motor_experiment_catalog.m`). Each rig experiment is one or more runs; a run ' ...
         'fixes the loop, the controller and its gains, the feedback path and the command limit, then ' ...
         'plays a setpoint profile (time in s, setpoint in output rpm or output degrees, held between rows). ' ...
         'In the app, choose the mission and the preset; RUN ON RIG plays it on the hardware, and every ' ...
         'preset simulates on any plant and opens in [Simulink](SIMULINK.md).']);
    say('');
    say(['**Predicted** is the identified rig model (`servolab.motor.rigModel`) running the run''s own ' ...
         'settings: rise time 10-90 %%, overshoot, steady-state error (last 20 %% of the step). ' ...
         '**Measured** links to the rig''s answer in the latest session report; every recorded run is ' ...
         'in `data/` ([data](../data/README.md)).']);
    say('');
    say('| Mission | Question | Experiments |');
    say('|---|---|---|');
    for m = 1:numel(M)
        n = numel(M(m).experiments); if n == 0, n = numel(servolab.motor.presets(M(m))); end
        say('| [%s · %s](#%s) | %s | %d |', M(m).tag, M(m).short, anchor([M(m).tag ' · ' M(m).short]), firstSentence(M(m).brief), n);
    end
    say('');
    for m = 1:numel(M)
        say('## %s · %s', M(m).tag, M(m).short);
        say('');
        say('%s', M(m).brief);
        say('');
        if isempty(M(m).experiments)
            presetTable(servolab.motor.presets(M(m)));
            continue
        end
        for e = 1:numel(M(m).experiments)
            x = E(strcmp({E.key}, M(m).experiments{e}));
            say('### %s', x.name);
            say('');
            say('%s', x.purpose);
            say('');
            say('| Run | Loop | Controller | Feedback | Limit | Profile | s | Predicted rise (s) | overshoot (%%) | e_ss |');
            say('|---:|---|---|---|---:|---|---:|---:|---:|---:|');
            for r = 1:numel(x.runs)
                s = x.runs(r);
                spec = struct('loop', s.loop, 'ctrl', s.ctrl, 'Kp', s.Kp, 'Ki', s.Ki, 'Kd', 0, 'profile', s.profile, ...
                    'Tend', s.duration, 'spdFb', s.spdFb, 'uMax', s.uMax, 'experiment', x.id, 'name', x.name, ...
                    'key', x.key, 'plant', 'rigId', 'dist', 0, 'tDist', 3, 'Jf', 1);
                [rise, over, ess] = predict(spec);
                say('| %d | %s | %s | %s | %s | `%s` | %g | %s | %s | %s |', r, s.loop, gains(s), ...
                    fbOf(s), limOf(s), mat2str(s.profile), s.duration, rise, over, ess);
            end
            say('');
            if isfield(measured, x.key)
                say('Measured: [latest session report](../results/reports/dc_motor/2026-10-25/REPORT.md#%s).', measured.(x.key));
                say('');
            end
        end
    end
    txt = strjoin(L, newline);
    if ~isempty(outFile)
        fid = fopen(outFile, 'w'); fprintf(fid, '%s\n', txt); fclose(fid);
        fprintf('catalog -> %s\n', outFile);
    end

    function presetTable(P)
        say('| Preset | Plant | Loop | Controller | Profile | s | Load | Predicted rise (s) | overshoot (%%) | e_ss |');
        say('|---|---|---|---|---|---:|---|---:|---:|---:|');
        for k = 1:numel(P)
            sp = P(k).spec; [rise, over, ess] = predict(sp);
            load = '-'; if sp.dist ~= 0, load = sprintf('%g N·m at %g s', sp.dist, sp.tDist); end
            if sp.Jf ~= 1, load = sprintf('inertia ×%g', sp.Jf); end
            say('| %s | %s | %s | %s | `%s` | %g | %s | %s | %s | %s |', P(k).label, plantName(sp.plant), sp.loop, ...
                gains(sp), mat2str(sp.profile), sp.Tend, load, rise, over, ess);
        end
        say('');
    end

    function say(fmt, varargin), L{end + 1} = sprintf(fmt, varargin{:}); end
end

function [rise, over, ess] = predict(spec)
    c = servolab.motor.specConfig(spec);
    S = servolab.motor.simulatePlant(c);
    res = 0; if strcmp(c.loop, 'position'), res = c.P.deg_per_count; end
    m = servolab.motor.stepMetrics(S.tk, S.r, S.meas, S.u, 'Resolution', res, 'uMax', c.uMax);
    rise = num(m.rise, '%.2f'); over = num(m.overshoot, '%.1f'); ess = num(m.ess, '%.2f');
end

function s = num(v, f), if isempty(v) || ~isfinite(v), s = '-'; else, s = sprintf(f, v); end, end
function s = gains(r)
    switch r.ctrl
        case 'OL', s = 'open loop';
        case 'P', s = sprintf('P, Kp %g', r.Kp);
        case 'I', s = sprintf('I, Ki %g', r.Ki);
        case 'PI', s = sprintf('PI, Kp %g Ki %g', r.Kp, r.Ki);
        otherwise, s = sprintf('%s, Kp %g Ki %g Kd %g', r.ctrl, r.Kp, r.Ki, r.Kd);
    end
end
function s = fbOf(r)
    if strcmp(r.loop, 'position'), s = 'encoder angle'; elseif strcmp(r.spdFb, 'encoder'), s = 'encoder speed'; else, s = 'drive register'; end
end
function s = limOf(r), if isnan(r.uMax), s = '-'; else, s = sprintf('%g rpm', r.uMax); end, end
function s = plantName(p)
    switch p
        case 'rigId', s = 'rig, identified';
        case 'rigPhys', s = 'rig, drive physics';
        otherwise, s = 'bare motor';
    end
end
function s = firstSentence(t), k = strfind(t, '. '); if isempty(k), s = t; else, s = t(1:k(1)); end, end
function a = anchor(h)
    a = lower(h); a = regexprep(a, '[^a-z0-9 \-]', ''); a = strrep(a, ' ', '-');
end
