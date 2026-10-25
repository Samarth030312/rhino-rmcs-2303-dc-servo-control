function L = presets(mission)
%PRESETS  The experiments the app offers for a mission, ready to load or simulate.
%
%   L = servolab.motor.presets('M3')     % or a struct from servolab.motor.missions()
%   L = servolab.motor.presets()         % every mission's, with L(k).mission set
%
%   L(k).label   the text in the app's preset menu
%   L(k).spec    loop, ctrl, Kp, Ki, Kd, profile, Tend, spdFb, uMax, plant ('rigId' | 'rigPhys'
%                | 'arm'), dist, tDist, Jf, experiment (id), name, key
%   L(k).series  the whole hardware experiment for an "all runs" entry, else []
%   servolab.motor.specConfig(L(k).spec) turns a spec into a simulation config.
%
%   Rig missions list hardware experiments (servolab.motor.hwExperiments): one entry per run,
%   plus one that plays all its runs. M10 lists the bare motor's; LAB a few starting points.

    M = servolab.motor.missions();
    if nargin < 1
        L = struct('label', {}, 'spec', {}, 'series', {}, 'mission', {});
        for m = 1:numel(M)
            Lm = servolab.motor.presets(M(m));
            [Lm.mission] = deal(M(m).tag);
            L = [L, Lm]; %#ok<AGROW>
        end
        return
    end
    if ischar(mission) || isstring(mission), mission = M(strcmp({M.tag}, mission)); end
    E = servolab.motor.hwExperiments();
    L = struct('label', {}, 'spec', {}, 'series', {});
    for e = 1:numel(mission.experiments)
        j = find(strcmp({E.key}, mission.experiments{e}), 1);
        if isempty(j), continue; end
        x = E(j); n = numel(x.runs);
        for r = 1:n
            L(end + 1) = struct('label', [shortName(x.name), runTag(x.runs(r), n, r)], ...
                'spec', specFrom(x.runs(r), x), 'series', []); %#ok<AGROW>
        end
        if n > 1
            L(end + 1) = struct('label', sprintf('▶▶ all %d runs: %s', n, shortName(x.name)), ...
                'spec', specFrom(x.runs(1), x), 'series', x); %#ok<AGROW>
        end
    end
    if strcmp(mission.kind, 'physics')                   % the bare motor, voltage-driven
        L = struct('label', {'open loop: voltage step (speed and current)', 'speed PID', 'speed PI, load torque step at 1 s', ...
                             'speed PI, inertia x1.5', 'position PID', 'position PID, load torque step at 1.5 s'}, ...
            'spec', {phys('speed', 'OL', 0, 0, 0, [0 0; 0.1 90], 1, 0, 1, 1), ...
                     phys('speed', 'PID', 0.05, 1.0, 0.0002, [0 0; 0.1 100], 1.5, 0, 1, 1), ...
                     phys('speed', 'PI', 0.05, 1.0, 0, [0 0; 0.1 100], 2, 1.0, 1, 1), ...
                     phys('speed', 'PI', 0.05, 1.0, 0, [0 0; 0.1 100], 1.5, 0, 1, 1.5), ...
                     phys('position', 'PID', 0.3, 0.5, 0.01, [0 0; 0.1 90], 2, 0, 1, 1), ...
                     phys('position', 'PID', 0.3, 0.5, 0.01, [0 0; 0.1 90], 3, 1.0, 1.5, 1)}, ...
            'series', {[], [], [], [], [], []});
    end
    if strcmp(mission.kind, 'lab')
        L = struct('label', {'speed PI, 60 rpm', 'speed P, Kp 0.5', 'speed open loop, 40 rpm', ...
                             'position P, 90 deg', 'position PI, 90 deg', 'position P, 1 N*m load at 3 s (drive physics)'}, ...
            'spec', {lab('speed', 'PI', 0.3, 1.5, [0 60], 10, 'rigId', 0), lab('speed', 'P', 0.5, 0, [0 60], 8, 'rigId', 0), ...
                     lab('speed', 'OL', 0, 0, [0 40], 8, 'rigId', 0), lab('position', 'P', 0.3, 0, [0 90], 8, 'rigId', 0), ...
                     lab('position', 'PI', 0.3, 0.03, [0 90], 12, 'rigId', 0), lab('position', 'P', 0.3, 0, [0 90], 8, 'rigPhys', 1)}, ...
            'series', {[], [], [], [], [], []});
    end
end

function s = specFrom(r, x)
    s = struct('loop', r.loop, 'ctrl', r.ctrl, 'Kp', r.Kp, 'Ki', r.Ki, 'Kd', 0, 'profile', r.profile, ...
        'Tend', r.duration, 'spdFb', r.spdFb, 'uMax', r.uMax, 'experiment', x.id, 'name', x.name, 'key', x.key, ...
        'plant', 'rigId', 'dist', 0, 'tDist', 3, 'Jf', 1);
end
function s = lab(loop, ctrl, Kp, Ki, prof, T, plant, dist)
    s = struct('loop', loop, 'ctrl', ctrl, 'Kp', Kp, 'Ki', Ki, 'Kd', 0, 'profile', prof, 'Tend', T, ...
        'spdFb', 'drive', 'uMax', NaN, 'experiment', 'MOTOR-LAB', 'name', 'LAB', 'key', 'lab', ...
        'plant', plant, 'dist', dist, 'tDist', 3, 'Jf', 1);
end
function s = phys(loop, ctrl, Kp, Ki, Kd, prof, T, dist, tDist, Jf)
    s = struct('loop', loop, 'ctrl', ctrl, 'Kp', Kp, 'Ki', Ki, 'Kd', Kd, 'profile', prof, 'Tend', T, ...
        'spdFb', 'encoder', 'uMax', NaN, 'experiment', 'MOTOR-SIM', 'name', 'armature model', 'key', 'armature', ...
        'plant', 'arm', 'dist', dist, 'tDist', tDist, 'Jf', Jf);
end

function s = shortName(n)
    s = regexprep(n, '\s*\(.*\)$', '');
    if numel(s) > 46, s = [s(1:44) '…']; end
end

function s = runTag(r, n, k)
    g = '';
    switch r.ctrl
        case 'P',  g = sprintf('Kp %g', r.Kp);
        case 'I',  g = sprintf('Ki %g', r.Ki);
        case 'PI', g = sprintf('Kp %g Ki %g', r.Kp, r.Ki);
    end
    fb = ''; if strcmp(r.loop, 'speed') && strcmp(r.spdFb, 'encoder'), fb = ', encoder'; end
    if isempty(g), gs = ''; else, gs = [': ' g]; end
    if n > 1, s = sprintf('  · run %d/%d%s%s', k, n, gs, fb);
    elseif isempty(g), s = fb;
    else, s = sprintf('  · %s%s', g, fb); end
end
