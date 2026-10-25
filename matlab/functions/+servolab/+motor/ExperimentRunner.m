classdef ExperimentRunner < handle
%EXPERIMENTRUNNER  Plays an servolab.motor.hwExperiments entry on the hardware.
%
%   r = servolab.motor.ExperimentRunner(link, experiment, @onRunStart, @onRunDone)
%   r.start();   then call r.tick() regularly (the app does, every 0.1 s)
%   r.abort();
%
%   For each run: CFG (loop, controller, gains) -> SET (first profile point) -> RUN,
%   then SET at each profile time, STOP at 'duration', onRunDone(spec, telemetry,
%   index), 1.5 s pause, next run. Any $ERR from the firmware (runaway, Modbus
%   loss, watchdog) aborts the whole experiment: nothing is retried automatically.
%
%   clock (optional) is a function handle returning seconds; tests inject one.

    properties (SetAccess = private)
        state = 'idle'          % idle | running | pause | done | aborted
        runIndex = 0
        message = ''
        experiment
    end
    properties (Access = private)
        link; onStart; onDone; clock
        tRun = 0; tPause = 0; profIdx = 1; nEvents = 0
    end
    properties (Constant)
        PauseBetweenRuns = 1.5
    end

    methods
        function obj = ExperimentRunner(link, experiment, onStart, onDone, clock)
            obj.link = link; obj.experiment = experiment;
            obj.onStart = onStart; obj.onDone = onDone;
            if nargin < 5, t0 = tic; clock = @() toc(t0); end
            obj.clock = clock;
        end

        function start(obj)
            obj.runIndex = 1; obj.startRun();
        end

        function tf = isActive(obj)
            tf = any(strcmp(obj.state, {'running', 'pause'}));
        end

        function c = runConfig(obj, k)
            spec = obj.experiment.runs(k);
            c = servolab.motor.defaultConfig('rig', spec.loop);
            c.ctrl = spec.ctrl; c.Kp = spec.Kp; c.Ki = spec.Ki; c.Kd = 0;
            if isfield(spec, 'spdFb'), c.spdFb = spec.spdFb; end
            if isfield(spec, 'uMax') && ~isnan(spec.uMax), c.uMax = spec.uMax; end
            c.setpoint = spec.profile(1, 2); c.Tend = spec.duration;
            c.experiment = obj.experiment.id;
            c.preset = sprintf('%s [run %d/%d]', obj.experiment.name, k, numel(obj.experiment.runs));
        end

        function tick(obj)
            if ~obj.isActive(), return; end
            ev = obj.link.eventLog;
            if size(ev, 1) > obj.nEvents
                newEv = ev(obj.nEvents + 1:end, :); obj.nEvents = size(ev, 1);
                bad = find(strcmp(newEv(:, 2), 'ERR'), 1);
                if ~isempty(bad)
                    obj.abort(sprintf('firmware error: %s', newEv{bad, 3})); return;
                end
            end
            t = obj.clock();
            if strcmp(obj.state, 'running')
                spec = obj.experiment.runs(obj.runIndex);
                tr = t - obj.tRun;
                while obj.profIdx < size(spec.profile, 1) && spec.profile(obj.profIdx + 1, 1) <= tr
                    obj.profIdx = obj.profIdx + 1;
                    obj.link.setpoint(spec.profile(obj.profIdx, 2));
                end
                if tr >= spec.duration
                    obj.link.stop(); obj.link.poll();
                    obj.onDone(spec, obj.link.table(), obj.runIndex);
                    obj.state = 'pause'; obj.tPause = t;
                end
            elseif strcmp(obj.state, 'pause') && t - obj.tPause >= obj.PauseBetweenRuns
                obj.runIndex = obj.runIndex + 1;
                if obj.runIndex > numel(obj.experiment.runs)
                    obj.state = 'done'; obj.message = sprintf('%s: all %d run(s) done.', obj.experiment.name, numel(obj.experiment.runs));
                else
                    obj.startRun();
                end
            end
        end

        function abort(obj, why)
            if nargin < 2, why = 'aborted by the operator'; end
            try
                obj.link.stop('now');                        % abort: motor power off at once
            catch err
                why = [why ' (STOP failed: ' err.message ')'];
            end
            obj.state = 'aborted'; obj.message = why;
        end
    end

    methods (Access = private)
        function startRun(obj)
            c = obj.runConfig(obj.runIndex);
            % the caller's set-up (a simulation, a redraw) first: once RUN is sent, the
            % firmware's 1 s watchdog needs a PING that a busy MATLAB cannot send
            obj.onStart(c, obj.runIndex);
            obj.link.configure(c);
            obj.link.setpoint(c.setpoint);
            obj.link.run();
            obj.nEvents = size(obj.link.eventLog, 1);
            obj.tRun = obj.clock(); obj.profIdx = 1; obj.state = 'running';
            obj.message = sprintf('%s: run %d/%d', obj.experiment.name, obj.runIndex, numel(obj.experiment.runs));
        end
    end
end
