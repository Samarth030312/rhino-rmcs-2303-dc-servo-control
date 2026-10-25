function R = motor_rig_campaign(port, missions)
%MOTOR_RIG_CAMPAIGN  Every hardware experiment of the DC-motor missions on the rig, in the app.
%
%   R = motor_rig_campaign('/dev/ttyUSB0')            % M1-M9, all their experiments
%   R = motor_rig_campaign('COM5', {'M1', 'M5'})
%   R = motor_rig_campaign(port, {'M1', 'all 2 runs: Open-loop step'; 'M6', 'Saturation'})   % N x 2: mission, preset text
%
%   Opens rhino_servo_lab, connects, runs DRIVE CHECK, then for each mission plays each of
%   its hardware experiments (the "all runs" preset when an experiment has several runs)
%   exactly as RUN ON RIG does. Every run is saved and registered by the app. A firmware
%   fault is logged, cleared, and the campaign goes on with the next experiment.
%   Progress: results/evidence/logs/campaign_<time>.log. R: one row per experiment.
%   Needs the operator at the bench: the motor turns both ways at up to 150 rpm.

    if nargin < 2 || isempty(missions), missions = {'M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'M7', 'M8', 'M9'}; end
    logDir = fullfile(servolab.repoRoot(), 'results', 'evidence', 'logs');
    if ~isfolder(logDir), mkdir(logDir); end
    logFile = fullfile(logDir, ['campaign_' char(datetime('now', 'Format', 'yyyyMMdd-HHmmss')) '.log']);
    say(sprintf('campaign on %s, %d step(s)', port, size(missions, 1) * (size(missions, 2) == 2) + numel(missions) * (size(missions, 2) ~= 2)));

    app = rhino_servo_lab(); drawnow;
    assert(app.connect(port), 'servolab:campaign:connect', 'could not connect on %s', port);
    say(['connected: ' app.ui.fw.Text]);
    app.diag(); pause(1.5);
    say(['drive check: ' app.ui.say.Text]);

    M = servolab.motor.missions();
    rows = {};
    steps = missions;
    if size(missions, 2) ~= 2 || ~iscell(missions) || isrow(missions), steps = [missions(:), repmat({''}, numel(missions), 1)]; end
    for m = 1:size(steps, 1)
        mi = find(strcmp({M.tag}, steps{m, 1}), 1);
        app.selectMission(mi); drawnow; pause(0.3);
        items = app.ui.preset.Items;
        if isempty(steps{m, 2}), pick = choosePresets(items);
        else, pick = find(contains(items, steps{m, 2}), 1); assert(~isempty(pick), 'servolab:campaign:preset', 'no preset "%s" in %s', steps{m, 2}, steps{m, 1});
        end
        for p = pick
            app.setPreset(p); drawnow; pause(0.3);
            label = items{p};
            n0 = height(servolab.data.register());
            say(sprintf('%s  RUN  %s', steps{m, 1}, label));
            t0 = tic;
            app.runRig(); pause(1);
            while app.state().on && toc(t0) < 600, pause(0.25); end
            if app.state().on, app.abort(); pause(1); end
            Rg = servolab.data.register();
            ids = Rg.run_id(n0 + 1:end); res = Rg.result(n0 + 1:end);
            fault = app.state().fault;
            say(sprintf('%s  DONE %s  %.0f s  runs: %s  %s', steps{m, 1}, label, toc(t0), ...
                strjoin(strcat(ids, ' [', res, ']'), ', '), ternary(isempty(fault), '', ['FAULT ' fault])));
            rows(end + 1, :) = {steps{m, 1}, label, strjoin(ids, ' '), strjoin(res, ' | '), fault, toc(t0)}; %#ok<AGROW>
            if ~isempty(fault)
                app.clearFault(); pause(1);
                say(['cleared fault, state ' app.ui.stateChip.Text]);
            end
            pause(2);                                  % let the disc stop between experiments
        end
    end
    R = cell2table(rows, 'VariableNames', {'mission', 'preset', 'run_ids', 'results', 'fault', 'seconds'});
    writetable(R, strrep(logFile, '.log', '.csv'));
    say('campaign finished');

    function say(s)
        line = sprintf('%s  %s', char(datetime('now', 'Format', 'HH:mm:ss')), s);
        fprintf('%s\n', line);
        fid = fopen(logFile, 'a'); fprintf(fid, '%s\n', line); fclose(fid);
    end
end

function pick = choosePresets(items)
    % one entry per experiment: its "all runs" preset, or its only run
    pick = [];
    isAll = startsWith(items, '▶▶');
    covered = {};
    for k = find(isAll)
        pick(end + 1) = k; %#ok<AGROW>
        covered{end + 1} = regexprep(items{k}, '^▶▶ all \d+ runs: ', ''); %#ok<AGROW>
    end
    for k = find(~isAll)
        if ~any(cellfun(@(c) startsWith(items{k}, c), covered)), pick(end + 1) = k; end %#ok<AGROW>
    end
    pick = sort(pick);
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
