function ok = e2e_motor_mission_control(simBinary)
%E2E_MOTOR_MISSION_CONTROL  rhino_servo_lab <-> the real motor firmware <-> an emulated RMCS-2303.
%
%   ok = e2e_motor_mission_control('<repo>/firmware/tests/fwsim')     (Linux or macOS, display)
%
%   The firmware (firmware/motor_controller) is compiled for the PC
%   (firmware/tests/firmware_host_test.cpp, --pty mode) and runs in real time on a
%   pseudo-terminal with an emulated drive. The app is driven through its own functions:
%   connect, DRIVE CHECK, a LAB run with live setpoint changes, a latched fault and
%   CLEAR FAULT, a mission's hardware experiment saved as raw data, and ABORT. Data and logs go to a
%   temporary folder. Everything except the physical wiring is exercised.
    tmp = tempname; mkdir(tmp);
    setenv('SERVOLAB_DATA_ROOT', tmp); setenv('SERVOLAB_LOG_DIR', tmp);
    cleanEnv = onCleanup(@() cellfun(@(v) setenv(v, ''), {'SERVOLAB_DATA_ROOT', 'SERVOLAB_LOG_DIR'}));
    ptyFile = fullfile(tmp, 'pty.txt');
    system(sprintf('"%s" --pty > "%s" 2>&1 & echo $! > "%s/sim.pid"', simBinary, ptyFile, tmp));
    cleanSim = onCleanup(@() system(sprintf('kill $(cat "%s/sim.pid") 2>/dev/null', tmp)));
    t0 = tic; pty = '';
    while isempty(pty) && toc(t0) < 5
        pause(0.2); tok = regexp(fileread(ptyFile), 'PTY (\S+)', 'tokens', 'once');
        if ~isempty(tok), pty = tok{1}; end
    end
    assert(~isempty(pty), 'emulator did not start');
    fprintf('emulated board on %s\n', pty);

    app = rhino_servo_lab(); cl = onCleanup(@() delete(app.fig));
    ok = true;

    % ---- connect and drive check
    app.selectMission(find(strcmp({servolab.motor.missions().tag}, 'LAB')));
    app.setPreset(3);                                    % speed, open loop, 40 rpm
    ok = check(app.connect(pty), 'connect: firmware said HELLO') & ok;
    ok = check(contains(app.ui.fw.Text, 'drive id 7'), ['top bar shows the drive: ' app.ui.fw.Text]) & ok;
    ok = check(strcmp(app.ui.stateChip.Text, 'READY'), 'state READY') & ok;
    log = newestLog(tmp);
    app.diag();
    ok = check(contains(fileread(log), 'LPR'), 'DRIVE CHECK: register dump received (LPR)') & ok;

    % ---- LAB run with live setpoint 40 -> 60 rpm
    app.runRig(); pause(2.5);
    ok = check(app.state().on && strcmp(app.ui.stateChip.Text, 'RUNNING'), 'LAB run started, state RUNNING') & ok;
    ok = check(strcmp(app.ui.rec.Visible, 'on'), 'REC indicator on during the run') & ok;
    app.liveSet(60); pause(3);
    L = fileread(log);
    ok = check(contains(L, '> $SET,1,60'), 'live setpoint sent: $SET,1,60') & ok;
    T = app.link().table();
    ok = check(abs(T.meas(end) - 60) < 3, sprintf('motor follows the live setpoint: %.1f rpm', T.meas(end))) & ok;
    D = app.metricsTable();
    ok = check(~isempty(D) && strcmp(app.ui.table.ColumnName{3}, 'RIG LIVE'), 'table scores the live run (RIG LIVE)') & ok;
    t1 = tic; while app.state().on && toc(t1) < 8, pause(0.2); end   % run length 8 s, then saves itself
    ok = check(~app.state().on, sprintf('run ended by itself at its run length (+%.1f s)', toc(t1))) & ok;
    raw = dir(fullfile(tmp, 'data', 'raw', 'dc_motor', '*.csv'));
    ok = check(numel(raw) == 1 && startsWith(raw(1).name, 'MOTOR-R0001_') && endsWith(raw(1).name, '_LAB.csv'), ...
        sprintf('the run was saved as raw data with a register id (%s)', strjoin({raw.name}, ' '))) & ok;
    Rg = servolab.data.register();                         % the app's own reader (quoted fields)
    ok = check(height(Rg) == 1 && strcmp(Rg.result{1}, 'FINISHED') && contains(Rg.rig{1}, 'drive id 7'), ...
        'the run is in RUN_REGISTER.csv with its rig and result') & ok;

    % ---- latched fault: the firmware refuses RUN, the app says why, CLEAR FAULT recovers
    app.link().estop(); pause(0.3);
    app.runRig(); pause(1.0);
    ok = check(strcmp(app.ui.stateChip.Text, 'FAULT') && contains(app.state().fault, 'estopped'), ...
        sprintf('fault shown: chip %s, %s', app.ui.stateChip.Text, app.state().fault)) & ok;
    ok = check(contains(app.ui.say.Text, 'CLEAR FAULT'), ['the message tells the operator to CLEAR FAULT: ' app.ui.say.Text]) & ok;
    app.clearFault(); pause(0.3);
    ok = check(strcmp(app.ui.stateChip.Text, 'READY') && isempty(app.state().fault), 'CLEAR FAULT: READY again') & ok;

    % ---- a hardware experiment from a mission: open-loop reversal (12 s), both directions, no false trip
    app.selectMission(1);
    items = app.ui.preset.Items; k = find(contains(items, 'Open-loop reversal'), 1);
    app.setPreset(k);
    app.runRig(); t1 = tic; pause(1); while app.state().on && toc(t1) < 20, pause(0.2); end
    raw = dir(fullfile(tmp, 'data', 'raw', 'dc_motor', 'MOTOR-R*_M1.csv'));
    ok = check(numel(raw) == 1, sprintf('M1 experiment saved (%d file, %s)', numel(raw), strjoin({raw.name}, ' '))) & ok;
    if ~isempty(raw)
        T = readtable(fullfile(raw(1).folder, raw(1).name));
        ok = check(any(T.meas > 25) && any(T.meas < -25), 'ran both directions (+30 / -30 rpm)') & ok;
    end
    ok = check(~contains(fileread(log), 'runaway'), 'no runaway trip during the commanded reversal') & ok;
    I = app.runs();
    ok = check(height(I) >= 1 && any(strcmp(I.key, 'ol_reversal')), 'RUNS lists the new run') & ok;

    % ---- ABORT during a run
    app.runRig(); pause(1.5);
    nStop = numel(strfind(fileread(log), '> $STOP,1'));
    app.abort(); pause(0.5);
    ok = check(~app.state().on && numel(strfind(fileread(log), '> $STOP,1')) > nStop, ...
        'ABORT sends STOP and ends the run') & ok;
    Rg = servolab.data.register();                         % the app's own reader (quoted fields)
    ok = check(startsWith(Rg.result{end}, 'ABORTED'), ['the aborted run is kept and marked: ' Rg.result{end}]) & ok;

    % ---- BRIDGE for the manufacturer's software: a Modbus frame passes through, END BRIDGE returns
    app.bridge(); pause(0.5);
    ok = check(~app.link().isOpen() && strcmp(app.ui.linkChip.Text, 'BRIDGE'), 'BRIDGE: link handed over') & ok;
    sp = serialport(pty, 9600, 'Timeout', 2); configureTerminator(sp, "CR/LF");
    write(sp, uint8(sprintf(':0703000A0001EB\r\n')), 'uint8'); pause(0.6);
    rep = ''; if sp.NumBytesAvailable > 0, rep = char(read(sp, sp.NumBytesAvailable, 'uint8')); end
    delete(sp);
    ok = check(contains(rep, ':070302000DE7'), sprintf('BRIDGE: Modbus read of LPR through the Uno answered (%s)', strtrim(rep))) & ok;
    app.endBridge(); pause(0.5);
    ok = check(app.link().isOpen() && ~isempty(app.link().hello), 'END BRIDGE: firmware back, HELLO received') & ok;

    fprintf('\nE2E %s (data and logs in %s)\n', ternary(ok, 'PASSED', 'FAILED'), tmp);
end

function f = newestLog(d)
    l = dir(fullfile(d, 'hw_session_*.log')); [~, i] = max([l.datenum]); f = fullfile(d, l(i).name);
end

function ok = check(c, msg)
    ok = logical(c);
    if ok, fprintf('  ok    %s\n', msg); else, fprintf('  FAIL  %s\n', msg); end
end

function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
