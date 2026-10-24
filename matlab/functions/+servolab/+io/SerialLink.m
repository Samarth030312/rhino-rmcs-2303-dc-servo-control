classdef SerialLink < handle
%SERIALLINK  Host side of the Arduino serial protocol v1 (any board).
%
%   link = servolab.io.SerialLink('TEL');      % DC motor (use servolab.motor.HardwareLink)
%   link = servolab.io.SerialLink('TTEL');     % temperature board
%   link = servolab.io.SerialLink('LTEL');     % water-level board
%   link.open("/dev/ttyACM0");            % or link.attach(transport) in tests
%   link.send('CFG', ...); link.setpoint(90); link.run();
%   ... call link.poll() periodically (the app does it from a timer) ...
%   link.stop();  link.close();
%
%   STATUS: protocol v1 (docs/architecture/SERIAL_PROTOCOL.md). Unit-tested
%   against a fake transport; the firmware compiles; NOT yet run on a real board.
%
%   Safety design: the firmware is specified to STOP the drive if it hears
%   nothing from the host for 1 s while running. poll() sends a PING every
%   0.25 s while running, so a hung MATLAB stops the motor rather than leaving
%   it under the last command.
%
%   The transport must provide: writeline(line), readline() -> string,
%   NumBytesAvailable, and optionally delete(). serialport does.

    properties (SetAccess = private)
        transport = []
        running = false
        tel                      % struct of column vectors, one row per $TEL
        n = 0                    % telemetry rows received
        eventLog = {}            % {time_s, kind, text} for ACK / ERR / HELLO / debug / invalid
        invalidCount = 0
        seqGaps = 0
        port = ""
        telType = 'TEL'
        hello = {}               % fields of the last $HELLO (firmware name, revision, ...)
        rawTail = {}             % last 300 raw lines, '< ' received / '> ' sent (live serial monitor)
        logFile = ''             % session log: every line in and out, with time stamps
    end
    properties (Access = private)
        lastPing = 0
        lastSeq = NaN
        clock
        logFid = -1
    end
    properties (Constant)
        Baud = 115200
        PingPeriod = 0.25
    end

    methods
        function obj = SerialLink(telType)
            if nargin >= 1, obj.telType = upper(char(telType)); end
            servolab.protocol.schema(obj.telType);         % validates the type
            obj.clock = tic;
            obj.resetData();
        end

        function open(obj, port)
            obj.close();
            sp = serialport(port, obj.Baud, 'Timeout', 0.5);
            configureTerminator(sp, "LF", "LF");
            flush(sp);
            obj.transport = sp;
            obj.port = string(port);
            obj.logEvent('info', sprintf('opened %s at %d baud', port, obj.Baud));
        end

        function ok = bridge(obj)
            %BRIDGE  Ask the motor firmware to pass this port through to the drive (9600 baud), then close.
            n0 = size(obj.eventLog, 1); obj.send('BRIDGE');
            t0 = tic; ok = false;
            while toc(t0) < 2 && ~ok
                obj.poll(); ev = obj.eventLog(n0 + 1:end, :);
                ok = any(contains(string(ev(:, 3)), 'BRIDGE')); pause(0.05);
            end
            obj.close();
        end

        function ok = waitForHello(obj, timeout)
            %WAITFORHELLO  Opening the port resets an Uno; wait for its $HELLO frame.
            if nargin < 2, timeout = 6; end
            t0 = tic; ok = false;
            while toc(t0) < timeout && ~ok
                obj.poll();
                ok = ~isempty(obj.hello);
                if ~ok, pause(0.05); end
            end
        end

        function lines = debugLines(obj, since)
            %DEBUGLINES  '#' lines received after event index SINCE (e.g. the $DIAG dump).
            if nargin < 2, since = 0; end
            ev = obj.eventLog(since + 1:end, :);
            lines = ev(strcmp(ev(:, 2), 'debug'), 3);
        end

        function attach(obj, transport)
            obj.close();
            obj.transport = transport;
            obj.port = "attached";
        end

        function tf = isOpen(obj)
            tf = ~isempty(obj.transport) && isvalid(obj.transport);
        end

        function send(obj, type, varargin)
            assert(obj.isOpen(), 'servolab:link:closed', 'serial link is not open');
            line = servolab.protocol.encode(type, varargin{:});
            writeline(obj.transport, line);
            if ~strcmp(type, 'PING'), obj.record('> ', line); end
        end

        function startLog(obj, file)
            %STARTLOG  Append every line sent and received to FILE (session evidence).
            obj.stopLog();
            obj.logFid = fopen(file, 'a');
            assert(obj.logFid > 0, 'servolab:link:log', 'cannot open log %s', file);
            obj.logFile = file;
            fprintf(obj.logFid, '# session log started %s, port %s\n', char(datetime('now')), obj.port);
        end

        function stopLog(obj)
            if obj.logFid > 0, fclose(obj.logFid); end
            obj.logFid = -1;
        end

        function setpoint(obj, v)
            obj.send('SET', v);
        end

        function run(obj)
            obj.resetData();
            obj.send('RUN');
            obj.running = true;
            obj.lastPing = toc(obj.clock);
        end

        function stop(obj, how)
            % STOP: the firmware ends the run and switches motor power off (register 2 = 0x0700),
            % never 'hold' (0x0701: with a reversed encoder that runs away, incident 2026-10-11).
            % The motor firmware first brings a turning motor to rest on the drive's ramp (soft
            % stop, up to 4 s); stop('now') sends STOP,1,NOW and cuts power at once (ABORT).
            % Firmware without a soft stop treats both the same.
            if nargin < 2, how = ''; end
            if obj.isOpen()
                if strcmpi(how, 'now'), obj.send('STOP', 'NOW'); else, obj.send('STOP'); end
            end
            obj.running = false;
        end

        function estop(obj)
            % ESTOP: drive removes motor power (register 2 = 0x0700); shaft is free.
            if obj.isOpen(), obj.send('ESTOP'); end
            obj.running = false;
        end

        function k = poll(obj)
            %POLL  Read and parse every complete line waiting. Returns rows added.
            k = 0;
            if ~obj.isOpen(), return; end
            now = toc(obj.clock);
            if obj.running && now - obj.lastPing >= obj.PingPeriod
                obj.send('PING'); obj.lastPing = now;
            end
            while obj.transport.NumBytesAvailable > 0
                line = readline(obj.transport);
                if isempty(line) || (isstring(line) && ismissing(line)), break; end
                obj.record('< ', strtrim(char(line)));
                m = servolab.protocol.parse(line);
                switch m.kind
                    case 'frame'
                        if strcmp(m.type, obj.telType)
                            obj.append(m.tel); k = k + 1;
                        else
                            if strcmp(m.type, 'HELLO'), obj.hello = m.fields; end
                            obj.logEvent(m.type, strjoin(m.fields, ','));
                        end
                    case 'debug'
                        obj.logEvent('debug', m.raw);
                    case 'invalid'
                        obj.invalidCount = obj.invalidCount + 1;
                        obj.logEvent('invalid', [m.err ' :: ' m.raw]);
                end
            end
        end

        function T = table(obj)
            %TABLE  Telemetry received so far, as a MATLAB table.
            T = struct2table(structfun(@(v) v(1:obj.n), obj.tel, 'UniformOutput', false));
            T.t_s = T.t_ms / 1000;
        end

        function close(obj)
            if obj.isOpen()
                if obj.running
                    try
                        obj.stop('now');
                    catch err
                        warning('servolab:link:stopFailed', 'STOP not sent on close: %s', err.message);
                    end
                end
                if isa(obj.transport, 'internal.Serialport') || isa(obj.transport, 'serialport')
                    delete(obj.transport);
                end
            end
            obj.transport = []; obj.running = false;
        end

        function delete(obj)
            obj.close();
            obj.stopLog();
        end
    end

    methods (Access = private)
        function resetData(obj)
            s = servolab.protocol.schema(obj.telType);
            obj.tel = struct();
            for k = 1:numel(s.names)
                if iscell(s.kinds{k}), obj.tel.(s.names{k}) = strings(1024, 1);
                else, obj.tel.(s.names{k}) = nan(1024, 1); end
            end
            obj.n = 0; obj.seqGaps = 0; obj.lastSeq = NaN;
        end

        function append(obj, t)
            if obj.n == numel(obj.tel.seq)
                fn = fieldnames(obj.tel);
                for i = 1:numel(fn)
                    v = obj.tel.(fn{i});
                    if isstring(v), pad = strings(size(v)); else, pad = nan(size(v)); end
                    obj.tel.(fn{i}) = [v; pad];
                end
            end
            obj.n = obj.n + 1; i = obj.n;
            fn = fieldnames(t);
            for k = 1:numel(fn), obj.tel.(fn{k})(i) = t.(fn{k}); end
            if ~isnan(obj.lastSeq) && t.seq ~= obj.lastSeq + 1
                obj.seqGaps = obj.seqGaps + 1;
            end
            obj.lastSeq = t.seq;
        end

        function record(obj, dir, line)
            obj.rawTail{end + 1, 1} = [dir line];
            if numel(obj.rawTail) > 300, obj.rawTail(1:end - 300) = []; end
            if obj.logFid > 0
                fprintf(obj.logFid, '%9.3f %s%s\n', toc(obj.clock), dir, line);
            end
        end

        function logEvent(obj, kind, text)
            obj.eventLog(end + 1, :) = {toc(obj.clock), kind, text};
        end
    end

    methods (Static)
        function endBridge(port)
            %ENDBRIDGE  Bring a motor Uno in BRIDGE mode back to its firmware ($ENDBRIDGE at 9600 baud).
            %   Harmless if the board is not bridged (the line is then ignored or answered with an error).
            sp = serialport(port, 9600, 'Timeout', 0.5);
            cl = onCleanup(@() delete(sp));
            pause(2);                                    % opening resets the Uno; it boots back into BRIDGE
            write(sp, uint8(sprintf('$ENDBRIDGE\n')), 'uint8');
            pause(0.3);
        end
    end
end
