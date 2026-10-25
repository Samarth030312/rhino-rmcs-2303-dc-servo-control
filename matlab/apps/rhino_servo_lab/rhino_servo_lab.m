function app = rhino_servo_lab()
%RHINO_SERVO_LAB  Rhino DC servo (RMCS-2303 drive + RMCS-5032 motor): simulate, run on the rig, compare.
%
%   setup open          (from the repository root; or: run('matlab/setup_path.m'); rhino_servo_lab)
%
%   MISSIONS   M1-M9: open loop, static map, speed P / I / PI, windup, position P / I / PI;
%              M10: the bare motor driven by voltage; LAB: free use. Each mission's presets
%              are hardware experiments (servolab.motor.presets, servolab.motor.hwExperiments).
%   PLANT      RIG · identified (servolab.motor.identifiedSim, fitted to the rig's runs),
%              RIG · drive + motor physics (servolab.motor.simulate, datasheet values, load
%              and inertia), MOTOR · armature (the bare motor). servolab.motor.simulatePlant
%              runs any of them; OPEN IN SIMULINK opens the matching model with the same
%              settings. Reruns 0.25 s after any change.
%   RIG        the same settings on the Arduino + RMCS-2303 (protocol v1). Every rig run is
%              saved automatically (data/raw/dc_motor) and listed under RUNS, where any
%              run can be overlaid on the simulation and replayed on the 3-D rig.
%   TABLE      SIM, RIG and REF (first-order theory: K 1, tau 0.72 s, no delay) scored by
%              one function, servolab.motor.stepMetrics.
%
%   Safety: ABORT (button, Esc, Space) switches motor power off; the firmware stops
%   the drive by itself if MATLAB is silent for 2 s, if the motor runs away, or if
%   Modbus is lost. Closing the window stops the motor. Base MATLAB only.
%
%   Returns a struct of handles and functions, so scripts and tests can drive it.

    K = servolab.ui.palette();
    MIS = servolab.motor.missions();
    E = servolab.motor.hwExperiments();
    P0 = servolab.motor.params();
    model = servolab.motor.rigModel(); model0 = model;
    [~, PD0] = servolab.motor.physics(); spec0 = PD0.spec;            % datasheet values (editable)
    link = servolab.motor.HardwareLink();
    mis = 1; presets = struct([]); profile = [0 60]; Tend = 10;
    S = []; Mref = []; replay = []; runsView = table(); pickedRun = '';
    hw = struct('on', false, 'runner', [], 'cfg', [], 'kind', '', 'nErr', 0, 'lastSaved', '', 'fault', '');
    hwTimer = []; playTimer = []; simTimer = []; watchTimer = [];
    play = struct('src', '', 't', 0, 'speed', 1, 'tic', []);
    knownPorts = {}; asking = false; busy = false; lastPort = '';
    tr = struct(); ui = struct();

    % =================================================================== window
    scr = get(groot, 'ScreenSize'); W = min(1800, scr(3) - 40); H = min(1010, scr(4) - 80);
    fig = uifigure('Name', 'Rhino DC Servo Lab', 'Position', [20 40 W H], 'Color', K.bg, ...
                   'CloseRequestFcn', @(~, ~) onClose(), 'WindowKeyPressFcn', @(~, e) onKey(e));
    try, theme(fig, 'dark'); catch, end
    G = uigridlayout(fig, [3 3], 'RowHeight', {52, '1x', 206}, 'ColumnWidth', {318, '1x', '1.15x'}, ...
        'Padding', [10 8 10 10], 'RowSpacing', 8, 'ColumnSpacing', 10, 'BackgroundColor', K.bg);

    % ---- top bar --------------------------------------------------------------------
    top = uigridlayout(G, [1 8], 'ColumnWidth', {230, '1x', 150, 140, 220, 80, 120, 150}, ...
        'Padding', [12 6 6 6], 'ColumnSpacing', 10, 'BackgroundColor', K.panel);
    top.Layout.Row = 1; top.Layout.Column = [1 3];
    lbl(top, 'RHINO DC SERVO LAB', 17, K.text, 'bold');
    ui.mission = lbl(top, '', 15, K.cyan, 'bold');
    ui.linkChip = chip(top, 'OFFLINE');
    ui.stateChip = chip(top, 'SIMULATION');
    ui.fw = lbl(top, 'RMCS-2303 · RMCS-5032 · Uno', 11, K.dim, 'normal');
    ui.rec = chip(top, '● REC'); ui.rec.BackgroundColor = K.red; ui.rec.Visible = 'off';
    ui.clock = lbl(top, '', 12, K.dim, 'normal'); ui.clock.FontName = K.mono;
    ui.abort = uibutton(top, 'Text', 'ABORT', 'FontSize', 16, 'FontWeight', 'bold', ...
        'BackgroundColor', K.red, 'FontColor', 'w', 'ButtonPushedFcn', @(~, ~) doAbort(), ...
        'Tooltip', 'Motor power off. Esc or Space.');

    % ---- left: missions and controls ----------------------------------------------------
    L = uigridlayout(G, [110 2], 'ColumnWidth', {'1x', '1x'}, 'RowSpacing', 4, 'ColumnSpacing', 6, ...
        'Padding', [10 10 10 10], 'BackgroundColor', K.panel, 'Scrollable', 'on');
    L.Layout.Row = 2; L.Layout.Column = 1; L.RowHeight = repmat({0}, 1, 110); row = 0;
    head('MISSION');
    nr = ceil(numel(MIS) / 2);
    mg = uigridlayout(L, [nr 2], 'Padding', [0 0 0 0], 'RowSpacing', 4, 'ColumnSpacing', 4, ...
        'RowHeight', repmat({28}, 1, nr), 'BackgroundColor', K.panel);
    place(mg, next(32 * nr - 4), [1 2]);
    ui.mb = matlab.ui.control.Button.empty;
    for k = 1:numel(MIS)
        ui.mb(k) = uibutton(mg, 'Text', sprintf('%s · %s', MIS(k).tag, MIS(k).short), 'FontWeight', 'bold', ...
            'UserData', k, 'Tooltip', MIS(k).brief, 'HorizontalAlignment', 'left', ...
            'ButtonPushedFcn', @(s, ~) selectMission(s.UserData));
        ui.mb(k).Layout.Row = ceil(k / 2); ui.mb(k).Layout.Column = mod(k - 1, 2) + 1;
    end
    ui.brief = note('', 50);
    ui.preset = uidropdown(L, 'Items', {'-'}, 'ValueChangedFcn', @(~, ~) applyPreset(), ...
        'BackgroundColor', K.field, 'FontColor', K.text);
    place(ui.preset, next(28), [1 2]);
    ui.plant = uidropdown(L, 'Items', {'RIG · identified from its runs', 'RIG · drive + motor physics', ...
        'MOTOR · armature voltage (no drive)'}, 'ItemsData', {'rigId', 'rigPhys', 'arm'}, ...
        'ValueChangedFcn', @(~, ~) plantChanged(), 'BackgroundColor', K.field, 'FontColor', K.text, ...
        'Tooltip', ['identified: the measured black box (K, ramp, latency) · physics: the drive''s speed loop and the ' ...
                    'motor equations from the datasheet panel · armature: the bare motor driven by a voltage, no drive']);
    place(ui.plant, next(28), [1 2]);

    ui.loopGrp = uibuttongroup(L, 'BorderType', 'none', 'BackgroundColor', K.panel, ...
        'SelectionChangedFcn', @(~, ~) structureChanged());
    place(ui.loopGrp, next(30), [1 2]);
    ui.loopSpeed = uitogglebutton(ui.loopGrp, 'Text', 'SPEED', 'Position', [0 2 145 26]);
    ui.loopPos = uitogglebutton(ui.loopGrp, 'Text', 'POSITION', 'Position', [150 2 145 26]);
    ui.fbGrp = uibuttongroup(L, 'BorderType', 'none', 'BackgroundColor', K.panel, ...
        'SelectionChangedFcn', @(~, ~) paramChanged());
    place(ui.fbGrp, next(30), [1 2]);
    ui.fbDrive = uitogglebutton(ui.fbGrp, 'Text', 'DRIVE SPEED', 'Position', [0 2 145 26], ...
        'Tooltip', 'Speed from the drive register: one encoder line per ~10 ms, 4.6 rpm steps');
    ui.fbEnc = uitogglebutton(ui.fbGrp, 'Text', 'ENCODER COUNTS', 'Position', [150 2 145 26], ...
        'Tooltip', 'Speed from encoder counts over Ts: 0.115 rpm resolution at 100 ms, Ts/2 older');

    head('CONTROLLER');
    place(lbl(L, 'law', 11.5, K.dim, 'normal'), next(26), 1);
    ui.ctrl = uidropdown(L, 'Items', {'open loop', 'P', 'I', 'PI', 'PID'}, 'ItemsData', {'OL', 'P', 'I', 'PI', 'PID'}, ...
        'Value', 'PI', 'ValueChangedFcn', @(~, ~) paramChanged(), 'BackgroundColor', K.field, 'FontColor', K.text);
    place(ui.ctrl, row, 2);
    ui.Kp   = field('Kp', [0 5], '%.3f', 0.3);
    ui.Ki   = field('Ki  (1/s)', [0 20], '%.3f', 1.5);
    ui.Kd   = field('Kd  (s)', [0 1], '%.4f', 0);
    ui.uMax = field('command limit (rpm)', [0.5 180], '%.1f', 180);
    ui.Ts   = field('sample time Ts (ms)', [1 300], '%.0f', 100);
    place(lbl(L, 'setpoint profile', 11.5, K.dim, 'normal'), next(26), 1);
    ui.profile = uieditfield(L, 'text', 'Value', '0 60', 'ValueChangedFcn', @(~, ~) paramChanged(), ...
        'BackgroundColor', K.field, 'FontColor', K.cyan, 'FontName', K.mono, 'HorizontalAlignment', 'right', ...
        'Tooltip', 'time value pairs, e.g.  0 30; 8 40; 16 30  (rpm, or deg for position)');
    place(ui.profile, row, 2);
    ui.Tend = field('run length (s)', [1 120], '%.1f', 10);
    ui.awGrp = uibuttongroup(L, 'BorderType', 'none', 'BackgroundColor', K.panel, ...
        'SelectionChangedFcn', @(~, ~) paramChanged());
    place(ui.awGrp, next(30), [1 2]);
    ui.awOn = uitogglebutton(ui.awGrp, 'Text', 'ANTI-WINDUP ON', 'Position', [0 2 145 26], ...
        'Tooltip', 'Clamping, as in the firmware');
    ui.awOff = uitogglebutton(ui.awGrp, 'Text', 'PLAIN INTEGRATOR', 'Position', [150 2 145 26], ...
        'Tooltip', 'Simulation only: what happens without anti-windup (the firmware always clamps)');

    head('DISTURBANCE');
    ui.dist  = field('load torque step (N·m)', [-5 5], '%.2f', 0);
    ui.tDist = field('load applied at t (s)', [0 120], '%.1f', 3);
    ui.Jf    = field('inertia factor (× J)', [0.2 10], '%.2f', 1);

    head('MOTOR · DRIVE · BATTERY  (datasheet → physics)');
    ui.pVnom  = field('rated voltage (V)', [1 48], '%.1f', spec0.V_nom);
    ui.pWnl   = field('no-load speed, output (rpm)', [1 2000], '%.0f', spec0.w_nl_out);
    ui.pN     = field('gear ratio N (: 1)', [1 1000], '%.0f', spec0.N);
    ui.pInl   = field('no-load current (A)', [0.01 10], '%.2f', spec0.I_nl);
    ui.pIst   = field('stall current (A)', [0.1 100], '%.2f', spec0.I_stall);
    ui.pJ     = field('rotor inertia J (×1e-6 kg·m²)', [0.01 100], '%.2f', 1e6 * spec0.J_rotor);
    ui.pL     = field('armature inductance L (mH)', [0.01 50], '%.2f', 1e3 * spec0.L);
    ui.pIdrv  = field('drive current limit (A)', [0.1 30], '%.1f', spec0.I_drive);
    ui.pVs    = field('battery voltage (V)', [1 48], '%.1f', spec0.V_supply);
    ui.pCap   = field('battery capacity (mAh, 0 = unknown)', [0 1e5], '%.0f', spec0.capacity_mAh);
    ui.pC     = field('battery C rating (continuous)', [0.1 100], '%.1f', spec0.C_rate);
    ui.pSoc   = field('battery charge (%, sets the voltage)', [0 100], '%.0f', 45);
    ui.pSoc.ValueChangedFcn = @(~, ~) onSoc();
    ui.pSoc.Tooltip = 'Li-ion 3S: 12.6 V full, 11.1 V nominal (about 45 %), 9.0 V empty (typical curve, ESTIMATED)';
    ui.physTxt = note('', 116); ui.physTxt.FontName = K.mono; ui.physTxt.FontSize = 10.5; ui.physTxt.FontColor = K.dim;
    ui.resetPhys = btn('RESET TO DATASHEET VALUES', @(~, ~) onResetPhysics(), [1 2], 28);
    ui.simulink = btn('OPEN IN SIMULINK', @(~, ~) onSimulink(), [1 2], 28);
    ui.simulink.Tooltip = 'Build the Simulink model with exactly these settings and open it';

    head('RIG MODEL  (identified, MEASURED)');
    ui.mK   = field('gain K', [0.2 2], '%.3f', model.K);
    ui.mAcc = field('drive ramp (rpm/s)', [5 2000], '%.1f', model.acc);
    ui.mLat = field('Modbus latency (ms)', [0 300], '%.0f', 1000 * P0.lat_speed);
    ui.mTau = field('lag tau (s)', [0.001 3], '%.3f', model.tau);
    ui.identify = btn('IDENTIFY FROM SELECTED RUN', @(~, ~) onIdentify(), [1 2], 28);
    ui.identify.Tooltip = 'Fit K, tau, dead time and ramp to the open-loop run picked under RUNS';
    ui.resetModel = btn('RESET TO MEASURED MODEL', @(~, ~) onResetModel(), [1 2], 28);

    % ---- centre: rig, telemetry ------------------------------------------------------
    Cc = uigridlayout(G, [3 1], 'RowHeight', {'1x', 84, 30}, 'Padding', [0 0 0 0], 'RowSpacing', 6, ...
        'BackgroundColor', K.bg);
    Cc.Layout.Row = 2; Cc.Layout.Column = 2;
    axR = uiaxes(Cc); axR.BackgroundColor = K.bg; rig = servolab.ui.motorRig(axR);
    try, axR.Interactions = [rotateInteraction zoomInteraction]; catch, end   % see mkAx
    tg = uigridlayout(Cc, [2 4], 'RowHeight', {20, '1x'}, 'Padding', [12 4 12 4], 'RowSpacing', 0, ...
        'BackgroundColor', K.panel);
    names = {'SPEED  rpm', 'ANGLE  deg', 'COMMAND  rpm', 'ERROR'};
    ui.tLbl = gobjects(1, 4);
    for k = 1:4, ui.tLbl(k) = lbl(tg, names{k}, 10, K.dim, 'bold'); end
    ui.tW = big(tg, K.cyan); ui.tTh = big(tg, K.orange); ui.tU = big(tg, K.text); ui.tE = big(tg, K.text);
    ui.say = lbl(Cc, '', 12.5, K.text, 'normal'); ui.say.HorizontalAlignment = 'center';

    % ---- right: plots ------------------------------------------------------------------
    Pg = uigridlayout(G, [4 1], 'RowHeight', {'1.25x', '1x', 0, 0}, 'Padding', [0 0 0 0], 'RowSpacing', 6, ...
        'BackgroundColor', K.bg);
    Pg.Layout.Row = 2; Pg.Layout.Column = 3;
    axY = mkAx(Pg, 'SPEED  (rpm)'); axU = mkAx(Pg, 'COMMAND  u  (rpm at the output shaft)');
    axI = mkAx(Pg, 'ARMATURE CURRENT  (A)'); axM = mkAx(Pg, 'STATIC MAP');
    tr.ref = stairs(axY, nan, nan, '--', 'Color', K.dim, 'LineWidth', 1.2);
    tr.yS = plot(axY, nan, nan, 'Color', K.ghost, 'LineWidth', 1.8);
    tr.yRef = plot(axY, nan, nan, ':', 'Color', K.amber, 'LineWidth', 1.3);
    tr.yR = plot(axY, nan, nan, 'Color', K.violet, 'LineWidth', 1.5);
    tr.yH = plot(axY, nan, nan, 'Color', K.cyan, 'LineWidth', 2.0);
    tr.uS = stairs(axU, nan, nan, 'Color', K.ghost, 'LineWidth', 1.6);
    tr.uR = stairs(axU, nan, nan, 'Color', K.violet, 'LineWidth', 1.4);
    tr.uH = stairs(axU, nan, nan, 'Color', K.orange, 'LineWidth', 1.9);
    tr.uLim = [yline(axU, 180, '--', 'Color', K.dim) yline(axU, -180, '--', 'Color', K.dim)];
    tr.iS = plot(axI, nan, nan, 'Color', K.ghost, 'LineWidth', 1.6);
    tr.iLim = [yline(axI, 3, '--', 'Color', K.dim) yline(axI, -3, '--', 'Color', K.dim)];
    tr.cur = [xline(axY, nan, 'Color', K.dim) xline(axU, nan, 'Color', K.dim) xline(axI, nan, 'Color', K.dim)];
    tr.mapS = plot(axM, nan, nan, '-', 'Color', K.ghost, 'MarkerFaceColor', K.ghost, 'MarkerSize', 4);
    tr.mapR = plot(axM, nan, nan, 's', 'Color', K.violet, 'MarkerFaceColor', K.violet, 'MarkerSize', 4);
    tr.mapH = plot(axM, nan, nan, 'o', 'Color', K.cyan, 'MarkerFaceColor', K.cyan, 'MarkerSize', 5);
    plot(axM, [-180 180], [-180 180], ':', 'Color', K.dim);
    xlabel(axM, 'command (rpm)'); ylabel(axM, 'steady speed (rpm)');
    legend(axY, [tr.yH tr.yS tr.yR tr.yRef tr.ref], {'rig', 'sim', 'replay', 'first-order theory', 'setpoint'}, ...
        'Location', 'northeast', 'TextColor', K.dim, 'Color', 'none', 'EdgeColor', 'none', ...
        'AutoUpdate', 'off', 'Orientation', 'horizontal');
    xlabel(axU, 't (s)');

    % ---- bottom: rig control, numbers + live setpoint, runs ------------------------------
    B1 = uigridlayout(G, [5 2], 'RowHeight', {26, 34, 34, 34, 26}, 'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [10 6 10 6], 'RowSpacing', 5, 'ColumnSpacing', 6, 'BackgroundColor', K.panel);
    B1.Layout.Row = 3; B1.Layout.Column = 1;
    ui.port = uidropdown(B1, 'Items', {'(no board)'}, 'BackgroundColor', K.field, 'FontColor', K.text);
    ui.connect = uibutton(B1, 'Text', 'CONNECT', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) onConnect());
    ui.flash = uibutton(B1, 'Text', 'FLASH FIRMWARE', 'ButtonPushedFcn', @(~, ~) onFlash(), ...
        'Tooltip', 'Compile and upload firmware/motor_controller (Windows, macOS, Linux)');
    ui.diag = uibutton(B1, 'Text', 'DRIVE CHECK', 'ButtonPushedFcn', @(~, ~) onDiag(), ...
        'Tooltip', 'Register dump of the RMCS-2303 and the measured loop time');
    ui.run = uibutton(B1, 'Text', '▶  RUN ON RIG', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', K.cyanDim, 'FontColor', 'w', 'ButtonPushedFcn', @(~, ~) onRunRig());
    ui.stop = uibutton(B1, 'Text', '■  STOP', 'FontSize', 14, 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~, ~) onStop());
    ui.clear = uibutton(B1, 'Text', 'CLEAR FAULT', 'ButtonPushedFcn', @(~, ~) onClearFault(), ...
        'Tooltip', 'After the firmware stopped the motor: re-home the drive and allow RUN again');
    ui.playSim = uibutton(B1, 'Text', 'PLAY SIMULATION', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~, ~) startPlay('sim'));
    ui.bridge = uibutton(B1, 'Text', 'RHINO SW BRIDGE', 'FontSize', 11, 'ButtonPushedFcn', @(~, ~) onBridge(true), ...
        'Tooltip', 'The Uno passes this USB port through to the drive (9600 baud) for the manufacturer''s configuration software');
    ui.endBridge = uibutton(B1, 'Text', 'END BRIDGE', 'FontSize', 10.5, 'ButtonPushedFcn', @(~, ~) onEndBridge(), ...
        'Tooltip', 'Back to this firmware (sends $ENDBRIDGE at 9600 baud), then CONNECT');

    B2 = uigridlayout(G, [2 1], 'RowHeight', {'1x', 30}, 'Padding', [10 8 10 8], 'RowSpacing', 6, ...
        'BackgroundColor', K.panel);
    B2.Layout.Row = 3; B2.Layout.Column = 2;
    ui.table = uitable(B2, 'ColumnName', {'', 'SIM', 'RIG', 'REF'}, 'RowName', {}, ...
        'ColumnWidth', {'1x', 74, 74, 74}, 'FontSize', 12, 'BackgroundColor', K.panel, 'ForegroundColor', K.text);
    lg = uigridlayout(B2, [1 6], 'ColumnWidth', {110, 80, '1x', 60, 60, '1x'}, 'Padding', [0 0 0 0], ...
        'ColumnSpacing', 6, 'BackgroundColor', K.panel);
    ui.liveLbl = lbl(lg, 'LIVE SETPOINT', 11, K.cyan, 'bold');
    ui.liveSp = uieditfield(lg, 'numeric', 'Value', 60, 'Limits', [-360 360], 'ValueDisplayFormat', '%.0f', ...
        'BackgroundColor', K.field, 'FontColor', K.text, 'ValueChangedFcn', @(~, ~) onLiveSet(0));
    ui.liveSet = uibutton(lg, 'Text', 'SEND', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) onLiveSet(0));
    ui.liveDn = uibutton(lg, 'Text', '− 10', 'ButtonPushedFcn', @(~, ~) onLiveSet(-10));
    ui.liveUp = uibutton(lg, 'Text', '+ 10', 'ButtonPushedFcn', @(~, ~) onLiveSet(10));
    ui.liveZero = uibutton(lg, 'Text', 'ZERO', 'ButtonPushedFcn', @(~, ~) onLiveSet(NaN));

    B3 = uigridlayout(G, [3 4], 'RowHeight', {'1x', 30, 30}, 'ColumnWidth', {'1x', '1x', '1x', '1x'}, ...
        'Padding', [10 8 10 8], 'RowSpacing', 5, 'ColumnSpacing', 6, 'BackgroundColor', K.panel);
    B3.Layout.Row = 3; B3.Layout.Column = 3;
    ui.runs = uitable(B3, 'ColumnName', {'RUN', 'RESULT', 'SETTINGS'}, 'RowName', {}, ...
        'ColumnWidth', {190, 120, 'auto'}, 'FontSize', 11, 'BackgroundColor', K.panel, 'ForegroundColor', K.text, ...
        'SelectionType', 'row', 'Multiselect', 'off', 'SelectionChangedFcn', @(~, e) onPickRun(e));
    ui.runs.Layout.Row = 1; ui.runs.Layout.Column = [1 4];
    ui.runFilter = uidropdown(B3, 'Items', {'this mission', 'all runs'}, 'ValueChangedFcn', @(~, ~) refreshRuns(), ...
        'BackgroundColor', K.field, 'FontColor', K.text);
    ui.overlay = uibutton(B3, 'Text', 'OVERLAY RUN', 'ButtonPushedFcn', @(~, ~) onOverlay(), ...
        'Tooltip', 'Draw the picked run over the simulation of the same settings');
    ui.sync = uibutton(B3, 'Text', 'SYNC DATA ⇅', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) onSync(), ...
        'Tooltip', 'Commit the new rig runs and push them to GitHub (data, logs, reports only)');
    ui.nextBtn = uibutton(B3, 'Text', 'NEXT MISSION ›', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) selectMission(mod(mis, numel(MIS)) + 1));
    ui.play = uibutton(B3, 'Text', '▶  PLAY', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) onPlayButton());
    ui.speed = uidropdown(B3, 'Items', {'0.5x', '1x', '2x', '4x'}, 'Value', '1x', ...
        'BackgroundColor', K.field, 'FontColor', K.text);
    ui.scrub = uislider(B3, 'Limits', [0 10], 'MajorTicks', [], 'MinorTicks', [], ...
        'ValueChangingFcn', @(~, e) onScrub(e.Value), 'ValueChangedFcn', @(s, ~) onScrub(s.Value));
    ui.scrub.Layout.Column = [3 4];

    styleButtons(fig);
    ui.abort.BackgroundColor = K.red; ui.abort.FontColor = 'w';
    ui.run.BackgroundColor = K.cyanDim; ui.run.FontColor = 'w';

    % =================================================================== start
    simTimer = timer('StartDelay', 0.25, 'TimerFcn', @(~, ~) safe(@update), 'BusyMode', 'drop');
    watchTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, 'BusyMode', 'drop', ...
        'TimerFcn', @(~, ~) safe(@watchTick));
    addlistener(fig, 'ObjectBeingDestroyed', @(~, ~) killTimers());
    knownPorts = servolab.io.arduinoPorts(); refreshPorts();
    selectMission(5);
    start(watchTimer);
    setEnabled();
    say('Simulation of the identified rig. Pick a mission; plug in the Uno to run it on the rig.', 'info');

    app = struct('fig', fig, 'ui', ui, 'selectMission', @selectMission, 'setPreset', @setPresetByIndex, ...
        'set', @setField, 'update', @update, 'sim', @getS, 'metricsTable', @getTable, ...
        'overlay', @overlayRun, 'runs', @getRuns, 'play', @startPlay, 'connect', @connectTo, ...
        'runRig', @onRunRig, 'stop', @onStop, 'abort', @doAbort, 'clearFault', @onClearFault, ...
        'diag', @onDiag, 'liveSet', @liveTo, 'state', @getHw, 'link', @getLink, ...
        'mission', @getMission, 'model', @getModel, 'record', @recordVideo, 'simulink', @onSimulink, ...
        'bridge', @() onBridge(false), 'endBridge', @onEndBridge, ...
        'liveTrace', @() [get(tr.yH, 'XData')', get(tr.yH, 'YData')']);

    % =================================================================== missions, presets
    function selectMission(k)
        if hw.on, say('A rig run is active: STOP it before changing mission.', 'warn'); return; end
        mis = k; M = MIS(k);
        for i = 1:numel(ui.mb)
            ui.mb(i).BackgroundColor = K.btn; ui.mb(i).FontColor = K.text;
        end
        ui.mb(k).BackgroundColor = K.cyan; ui.mb(k).FontColor = K.bg;
        ui.mission.Text = sprintf('%s · %s', upper(M.tag), upper(M.short));
        ui.brief.Text = M.brief;
        presets = servolab.motor.presets(M);
        ui.preset.Items = {presets.label}; ui.preset.ItemsData = 1:numel(presets);
        ui.preset.Value = 1;
        layoutPlots();
        ui.awGrp.Visible = strcmp(M.kind, 'windup');
        clearReplay();
        applyPreset();
        refreshRuns();
    end

    function setPresetByIndex(i), ui.preset.Value = i; applyPreset(); end

    function applyPreset()
        p = presets(ui.preset.Value).spec;
        setToggle(ui.loopGrp, strcmp(p.loop, 'speed'), ui.loopSpeed, ui.loopPos);
        setToggle(ui.fbGrp, ~strcmp(p.spdFb, 'encoder'), ui.fbDrive, ui.fbEnc);
        setToggle(ui.awGrp, true, ui.awOn, ui.awOff);
        ui.plant.Value = p.plant;
        ui.ctrl.Value = p.ctrl; ui.Kp.Value = p.Kp; ui.Ki.Value = p.Ki; ui.Kd.Value = p.Kd;
        ui.dist.Value = p.dist; ui.tDist.Value = p.tDist; ui.Jf.Value = p.Jf;
        plantDefaults(p.loop);
        if ~isnan(p.uMax), ui.uMax.Value = p.uMax; end
        ui.profile.Value = profileText(p.profile); ui.Tend.Value = p.Tend;
        structureChanged(true);
    end

    function structureChanged(fromPreset)
        if nargin < 1, fromPreset = false; end
        isSpd = ui.loopSpeed.Value;
        ui.fbGrp.Visible = isSpd;
        if isSpd
            axY.Title.String = 'SPEED  (rpm at the output shaft)';
        else
            axY.Title.String = 'ANGLE  (deg at the output shaft)';
        end
        ui.liveSp.Limits = [-360 360];
        ui.fbGrp.Visible = isSpd && ~strcmp(ui.plant.Value, 'arm');
        if ~fromPreset
            plantDefaults(ternary(isSpd, 'speed', 'position'));
            if ~isSpd && strcmp(ui.ctrl.Value, 'OL'), ui.ctrl.Value = 'P'; end
        end
        layoutPlots();
        paramChanged(true);
    end

    function plantDefaults(loop)
        % sample time, latency and command limit that belong to the chosen plant
        if strcmp(ui.plant.Value, 'arm')
            ui.Ts.Value = 10; ui.mLat.Value = 0; ui.uMax.Value = ui.pVs.Value;
            axU.Title.String = 'COMMAND  u  (armature voltage, V)';
            ui.uMax.UserData.Text = 'command limit (V)'; ui.tLbl(3).Text = 'COMMAND  V';
        else
            c0 = servolab.motor.defaultConfig('rig', loop);
            ui.Ts.Value = 1000 * c0.Ts; ui.mLat.Value = 1000 * c0.latency; ui.uMax.Value = c0.uMax;
            axU.Title.String = 'COMMAND  u  (rpm at the output shaft)';
            ui.uMax.UserData.Text = 'command limit (rpm)'; ui.tLbl(3).Text = 'COMMAND  rpm';
        end
    end

    function plantChanged()
        plantDefaults(ternary(ui.loopSpeed.Value, 'speed', 'position'));
        if strcmp(ui.plant.Value, 'arm') && strcmp(ui.ctrl.Value, 'OL') && ~ui.loopSpeed.Value, ui.ctrl.Value = 'P'; end
        structureChanged(true);
    end

    function layoutPlots()
        isMap = strcmp(MIS(mis).kind, 'map');
        isPhys = ~strcmp(ui.plant.Value, 'rigId');
        Pg.RowHeight = {'1.25x', '1x', ternary(isPhys, '0.85x', 0), ternary(isMap, '1x', 0)};
        axI.Visible = onoff(isPhys); set(axI.Children, 'Visible', onoff(isPhys));
        axM.Visible = onoff(isMap); set(axM.Children, 'Visible', onoff(isMap));   % children too
    end

    % =================================================================== parameters, simulation
    function f = field(label, lims, fmt, v)
        h = lbl(L, label, 11.5, K.dim, 'normal'); place(h, next(26), 1);
        f = uieditfield(L, 'numeric', 'Value', v, 'Limits', lims, 'ValueDisplayFormat', fmt, ...
            'BackgroundColor', K.field, 'FontColor', K.cyan, 'FontName', K.mono, ...
            'HorizontalAlignment', 'right', 'ValueChangedFcn', @(~, ~) paramChanged(), 'UserData', h);
        place(f, row, 2);
    end

    function setField(name, v)
        h = ui.(name);
        if isa(h, 'matlab.ui.control.EditField'), h.Value = char(v); else, h.Value = v; end
        if strcmp(name, 'plant'), plantChanged(); else, paramChanged(true); end   % as the menu does
    end

    function paramChanged(now)
        if nargin < 1, now = false; end
        if isempty(simTimer) || ~isvalid(simTimer), return; end
        model.K = ui.mK.Value; model.acc = ui.mAcc.Value; model.tau = ui.mTau.Value;
        stop(simTimer);
        if now, update(); else, start(simTimer); end
    end

    function sp = specFromUi()
        sp = struct('V_nom', ui.pVnom.Value, 'w_nl_out', ui.pWnl.Value, 'N', ui.pN.Value, 'I_nl', ui.pInl.Value, ...
            'I_stall', ui.pIst.Value, 'J_rotor', ui.pJ.Value * 1e-6, 'L', ui.pL.Value * 1e-3, ...
            'I_drive', ui.pIdrv.Value, 'V_supply', ui.pVs.Value, 'J_factor', ui.Jf.Value, ...
            'capacity_mAh', ternary(ui.pCap.Value > 0, ui.pCap.Value, NaN), 'C_rate', ui.pC.Value);
    end

    function c = readCfg()
        isSpd = ui.loopSpeed.Value; pk = ui.plant.Value;
        c = servolab.motor.defaultConfig(ternary(strcmp(pk, 'arm'), 'bare', 'rig'), ternary(isSpd, 'speed', 'position'));
        c.plantKey = pk;
        c.ctrl = ui.ctrl.Value; c.Kp = ui.Kp.Value; c.Ki = ui.Ki.Value;
        c.Kd = ternary(strcmp(c.ctrl, 'PID'), ui.Kd.Value, 0);
        c.uMax = ui.uMax.Value; c.Ts = max(c.dt, round(ui.Ts.Value) / 1000);
        c.latency = round(min(ui.mLat.Value / 1000, c.Ts) / c.dt) * c.dt;
        c.spdFb = ternary(isSpd && (ui.fbEnc.Value || strcmp(pk, 'arm')), 'encoder', 'drive');
        c.dist = ui.dist.Value; c.tDist = ui.tDist.Value;
        [c.P, PD] = servolab.motor.physics(specFromUi()); c.PD = PD;
        c.profile = profile; c.tStep = 0;
        c.antiWindup = ~ui.awOff.Value;
        c.Tend = ui.Tend.Value;
        c.setpoint = profile(1, 2);
        p = presets(ui.preset.Value).spec;
        c.experiment = p.experiment;
        c.preset = ui.preset.Items{ui.preset.Value};
    end

    function update()
        if busy || ~isvalid(fig), return; end
        pr = parseProfile(ui.profile.Value);
        if isempty(pr)
            say('Profile: write time-value pairs, e.g.  0 30; 8 40; 16 30', 'warn'); return;
        end
        profile = pr; Tend = ui.Tend.Value;
        c = readCfg();
        if ~strcmp(c.loop, 'speed') && strcmp(c.ctrl, 'OL')
            say('Open loop is a speed experiment: choose P, I or PI for position.', 'warn'); return;
        end
        showPhysics(c.PD);
        if strcmp(c.plantKey, 'rigId') && (c.dist ~= 0 || ui.Jf.Value ~= 1)
            say('The identified model has no load torque or inertia: choose RIG · drive + motor physics to see them.', 'warn');
        end
        c.profile = profile; c.Tend = Tend;
        S = servolab.motor.simulatePlant(c, model);
        if S.diverged, say('The simulation diverged: the loop is unstable with these gains.', 'warn'); end
        S.y = yOf(S); S.ang = S.thOut;
        Mref = [];
        if strcmp(c.plantKey, 'rigId') && strcmp(c.loop, 'speed') && any(strcmp(MIS(mis).kind, {'step', 'lab'}))
            m1 = struct('K', 1, 'tau', 0.72, 'theta', 0, 'acc', Inf, 'dz', 0, 'qSpd', 0);
            c1 = c; c1.latency = 0; c1.quant = false;
            Mref = servolab.motor.identifiedSim(m1, c1, profile, Tend);
        end
        drawSim();
        fillTable();
        if ~hw.on, poseAt('sim', Tend); end
    end

    function showPhysics(D)
        ui.physTxt.Text = sprintf(['R %.2f ohm   Kt = Ke %.4f N·m/A\nb %.2e N·m·s   J %.2e kg·m²\n' ...
            'tau_e %.2f ms   tau_m %.1f ms\ngain %.2f rpm/V   free speed %.0f rpm at %.1f V\n' ...
            'battery %.1f-%.1f V, %.1f A max; current limited by %s: %.1f A -> %.2f N·m (output)\n%s'], ...
            D.R, D.Kt, D.b, D.J, 1e3 * D.tau_e, 1e3 * D.tau_m, D.gain_rpm_per_V, D.w_free_out, D.spec.V_supply, ...
            D.V_cut, D.V_full, D.I_batt_max, D.I_limit_by, D.I_limit, D.T_max_out, D.tf);
    end

    function onSoc()
        [~, Dq] = servolab.motor.physics(struct('soc', ui.pSoc.Value));
        ui.pVs.Value = round(Dq.spec.V_supply, 2);
        paramChanged(true);
    end

    function onResetPhysics()
        busy = true;
        ui.pVnom.Value = spec0.V_nom; ui.pWnl.Value = spec0.w_nl_out; ui.pN.Value = spec0.N;
        ui.pInl.Value = spec0.I_nl; ui.pIst.Value = spec0.I_stall; ui.pJ.Value = 1e6 * spec0.J_rotor;
        ui.pL.Value = 1e3 * spec0.L; ui.pIdrv.Value = spec0.I_drive; ui.pVs.Value = spec0.V_supply; ui.pCap.Value = spec0.capacity_mAh;
        ui.pC.Value = spec0.C_rate; ui.pSoc.Value = 45;
        ui.Jf.Value = 1;
        busy = false;
        paramChanged(true);
        say('Datasheet values restored (RMCS-5032, RMCS-2303, Pro-Range 4400 mAh 3S Li-ion at 11.1 V).', 'info');
    end

    function onSimulink()
        if isempty(ver('simulink')) || ~license('test', 'Simulink')
            say('Simulink is not installed on this computer: the app''s own simulation is the same model.', 'warn'); return;
        end
        c = readCfg(); c.Tend = Tend;
        here = fullfile(servolab.repoRoot(), 'matlab', 'models', 'dc_motor');
        try
            switch c.plantKey
                case 'arm'
                    mdl = 'servo_armature';
                    c.setpoint = profile(end, 2); c.tStep = profile(min(2, end), 1) * (size(profile, 1) > 1);
                    if ~isfile(fullfile(here, [mdl '.slx'])), build_dc_motor_simulink(here); end
                    w = dc_motor_simulink_params(c);
                case 'rigId'
                    mdl = 'servo_identified';
                    if ~isfile(fullfile(here, [mdl '.slx'])), build_motor_identified_simulink(here); end
                    w = motor_identified_simulink_params(model, c, profile, Tend);
                case 'rigPhys'
                    mdl = 'servo_drive_physics';
                    if ~isfile(fullfile(here, [mdl '.slx'])), build_drive_physics_simulink(here); end
                    w = drive_physics_simulink_params(c, profile, Tend);
            end
            load_system(fullfile(here, [mdl '.slx']));
            mw = get_param(mdl, 'ModelWorkspace');
            for f = fieldnames(w)', assignin(mw, f{1}, w.(f{1})); end
            open_system(mdl);
            say(sprintf('%s opened with these settings: press Run in Simulink.', mdl), 'ok');
        catch err
            say(['Simulink: ' err.message], 'warn');
        end
    end

    function y = yOf(S)
        if strcmp(S.cfg.loop, 'speed'), y = S.w; else, y = S.thOut; end
    end

    function drawSim()
        c = S.cfg;
        set(tr.ref, 'XData', [profile(:, 1); Tend], 'YData', [profile(:, 2); profile(end, 2)]);
        set(tr.yS, 'XData', S.t, 'YData', S.y);
        set(tr.uS, 'XData', S.tk, 'YData', S.u);
        if isempty(Mref), set(tr.yRef, 'XData', nan, 'YData', nan);
        else, set(tr.yRef, 'XData', Mref.t, 'YData', Mref.w); end
        set(tr.uLim(1), 'Value', c.uMax); set(tr.uLim(2), 'Value', -c.uMax);
        if isfield(S, 'i')
            set(tr.iS, 'XData', S.t, 'YData', S.i);
            iL = ternary(strcmp(c.plantKey, 'arm'), c.PD.spec.I_stall, c.P.I_lim_drive);
            set(tr.iLim(1), 'Value', iL); set(tr.iLim(2), 'Value', -iL);
        else
            set(tr.iS, 'XData', nan, 'YData', nan);
        end
        if strcmp(MIS(mis).kind, 'map')
            ms = metricsOf(S.tk, S.r, S.meas, S.u, c);
            set(tr.mapS, 'XData', ms.map.cmd, 'YData', ms.map.speed);
        end
        ui.scrub.Limits = [0 max(Tend, 0.1)];
        autoAxes();
    end

    function autoAxes()
        xl = [0 Tend];
        if ~isempty(replay), xl(2) = max(xl(2), replay.T.t_s(end)); end
        if hw.on && link.n > 0, xl(2) = max(xl(2), hwT()); end
        xlim(axY, xl); xlim(axU, xl); xlim(axI, xl);
        is = get(tr.iS, 'YData'); is = is(isfinite(is));
        if ~isempty(is), ylim(axI, [min([is 0]) - 0.2, max([is 0]) + 0.2]); end
        ys = [get(tr.yS, 'YData'), get(tr.yR, 'YData'), get(tr.yH, 'YData'), get(tr.ref, 'YData'), 0];
        ys = ys(isfinite(ys));
        lo = min(ys); hi = max(ys); pad = max(5, 0.12 * (hi - lo));
        ylim(axY, [lo - pad, hi + pad]);
        us = [get(tr.uS, 'YData'), get(tr.uR, 'YData'), get(tr.uH, 'YData'), 0];
        us = us(isfinite(us)); lo = min(us); hi = max(us); pad = max(5, 0.12 * (hi - lo));
        ylim(axU, [lo - pad, hi + pad]);
    end

    % =================================================================== numbers
    function m = metricsOf(tk, r, y, u, c)
        if strcmp(c.loop, 'speed')
            if strcmp(c.spdFb, 'encoder'), res = 60 / (c.P.cpr_out * c.Ts); else, res = P0.spd_fb_step_base_rpm / P0.N; end
        else
            res = 2 * P0.deg_per_count;
        end
        m = servolab.motor.stepMetrics(tk, r, y, u, 'Resolution', res, 'uMax', c.uMax);
    end

    function fillTable()
        if isempty(S), return; end
        c = S.cfg; M = MIS(mis);
        ms = metricsOf(S.tk, S.r, S.meas, S.u, c);
        mr = []; rmse = NaN; rigLbl = '';
        src = rigSource();
        if ~isempty(src)
            mr = metricsOf(src.t, src.r, src.y, src.u, c);
            rmse = rmseVs(src);
            rigLbl = src.label;
        end
        mt = [];
        if ~isempty(Mref), mt = metricsOf(Mref.tk, Mref.r, Mref.w(round(Mref.tk / 1e-3) + 1), Mref.u, c); end
        un = ternary(strcmp(c.loop, 'speed'), 'rpm', 'deg');
        D = {};
        for k = 1:numel(M.rows)
            key = M.rows{k};
            [name, f, scale] = rowSpec(key, un);
            if strcmp(key, 'rmse')
                D(end + 1, :) = {name, '—', num(rmse, f), ''}; %#ok<AGROW>
            elseif strcmp(key, 'essTheory')
                A = profile(1, 2); th = A / (1 + model.K * c.Kp);
                D(end + 1, :) = {name, '—', '—', num(th, f)}; %#ok<AGROW>
            else
                D(end + 1, :) = {name, num(scale * ms.(key), f), num(scale * getm(mr, key), f), ...
                                 num(scale * getm(mt, key), f)}; %#ok<AGROW>
            end
        end
        if isfield(S, 'i') && c.dist ~= 0 && c.tDist < Tend      % load torque: dip and recovery
            j = S.t >= c.tDist & isfinite(S.y); tt = S.t(j) - c.tDist; yy = S.y(j);
            ref = profile(find(profile(:, 1) <= c.tDist, 1, 'last'), 2);
            dev = yy - ref; [~, jm] = max(abs(dev));
            band = max(0.02 * abs(ref), 0.5); out = abs(dev) > band;
            rec = NaN; if ~out(end), jl = find(out, 1, 'last'); if isempty(jl), rec = 0; else, rec = tt(jl + 1); end, end
            D(end + 1, :) = {sprintf('worst deviation after the load (%s)', un), num(dev(jm), '%.2f'), '—', ''};
            D(end + 1, :) = {'back within 2 % after the load (s)', num(rec, '%.2f'), '—', ''};
        end
        if isfield(S, 'i')                               % physics plants: current and battery
            if strcmp(c.plantKey, 'arm'), D(strcmp(D(:, 1), 'peak command (rpm)'), 1) = {'peak command (V)'}; end
            D(end + 1, :) = {'peak armature current (A)', num(max(abs(S.i)), '%.2f'), '—', ''};
            cap = c.PD.spec.capacity_mAh;
            if isfinite(cap) && S.iBatt > 0
                D(end + 1, :) = {'battery runtime at this load (h)', num(cap / 1000 / S.iBatt, '%.1f'), '—', ''};
            end
        end
        ui.table.Data = D;
        ui.table.ColumnName = {'', 'SIM', ternary(strcmp(rigLbl, 'LIVE'), 'RIG LIVE', 'RIG'), 'REF'};
        if strcmp(M.kind, 'map') && ~isempty(src)
            set(tr.mapR, 'XData', mr.map.cmd, 'YData', mr.map.speed);
        end
    end

    function [name, f, scale] = rowSpec(key, un)
        scale = 1; f = '%.2f';
        switch key
            case 'rise',       name = 'rise time 10-90 % (s)';
            case 'overshoot',  name = 'overshoot (%)'; f = '%.1f';
            case 'settling',   name = 'settling time (s)';
            case 'ess',        name = sprintf('steady error (%s)', un);
            case 'essTheory',  name = sprintf('P theory: r/(1+K Kp) (%s)', un);
            case 'peakU',      name = 'peak command (rpm)'; f = '%.1f';
            case 'gain',       name = 'gain K (speed / command)'; f = '%.3f';
            case 'mapGain',    name = 'slope (rpm per rpm command)'; f = '%.3f';
            case 'ramp',       name = 'ramp (rpm/s)'; f = '%.1f';
            case 'deadzone',   name = 'dead zone (rpm command)'; f = '%.1f';
            case 'wmax',       name = 'top speed (rpm)'; f = '%.1f';
            case 'satTime',    name = 'time at the limit (s)'; f = '%.1f';
            case 'recovery',   name = 'recovery after the drop (s)';
            case 'undershoot', name = 'dip below new setpoint (rpm)'; f = '%.1f';
            case 'rmse',       name = sprintf('RMSE rig vs sim (%s)', un);
            otherwise,         name = key;
        end
    end

    function s = rigSource()
        s = [];
        if hw.on && link.n > 0
            T = hwTable();
            s = struct('t', T.t_s, 'r', T.setpoint, 'y', T.meas, 'u', T.u, 'label', 'LIVE');
        elseif ~isempty(replay)
            T = replay.T;
            s = struct('t', T.t_s, 'r', T.setpoint, 'y', T.meas, 'u', T.u, 'label', replay.id);
        end
    end

    function e = rmseVs(src)
        e = NaN;
        if isempty(S), return; end
        if strcmp(S.cfg.loop, 'speed'), ys = interp1(S.t, S.w, src.t, 'linear', NaN);
        else, ys = interp1(S.t, S.thOut, src.t, 'linear', NaN); end
        ok = isfinite(ys) & isfinite(src.y);
        if nnz(ok) > 3, e = sqrt(mean((ys(ok) - src.y(ok)).^2)); end
    end

    % =================================================================== 3-D pose, playback
    function poseAt(src, t)
        c = S.cfg; spd = NaN; ang = 0; u = NaN; e = NaN; sp = NaN; trail = 0;
        switch src
            case 'sim'
                k = max(1, min(numel(S.t), round(t / 1e-3) + 1));
                spd = S.w(k); ang = S.thOut(k);
                j = find(S.tk <= t + 1e-9, 1, 'last'); if isempty(j), j = 1; end
                u = S.u(j); e = S.e(j); sp = S.r(j);
                k0 = max(1, k - 80); trail = S.thOut(k) - S.thOut(k0);
            case {'replay', 'live'}
                if strcmp(src, 'live'), T = hwTable(); A = liveAngle(T); else, T = replay.T; A = replay.angle; end
                if isempty(T) || height(T) == 0, return; end
                j = find(T.t_s <= t + 1e-9, 1, 'last'); if isempty(j), j = 1; end
                ang = A(j); u = T.u(j); e = T.err(j); sp = T.setpoint(j);
                if strcmp(c.loop, 'speed') || ~isfinite(T.spd_base_rpm(j)), spd = speedOf(T, j); else, spd = T.spd_base_rpm(j) / P0.N; end
                if j > 1, trail = A(j) - A(j - 1); end
        end
        isSpd = strcmp(c.loop, 'speed');
        servolab.ui.motorRigPose(rig, ang, spd, 'Setpoint', ternary(isSpd, sp, NaN), ...
            'RefAngle', ternary(isSpd, NaN, sp), 'TrailDeg', max(-120, min(120, trail)));
        ui.tW.Text = sprintf('%+7.1f', spd);
        ui.tTh.Text = sprintf('%+7.1f°', mod(ang + 180, 360) - 180);
        ui.tU.Text = sprintf('%+7.1f', u);
        ui.tE.Text = sprintf('%+7.2f', e);
        set(tr.cur, 'Value', t);
        ui.clock.Text = sprintf('t = %6.2f s', t);
    end

    function w = speedOf(T, j)
        if strcmp(S.cfg.loop, 'speed'), w = T.meas(j);
        elseif j > 1, w = (T.pos_counts(j) - T.pos_counts(j - 1)) / P0.cpr_out * 60 / max(1e-3, T.t_s(j) - T.t_s(j - 1));
        else, w = 0; end
    end

    function A = liveAngle(T)
        if all(isfinite(T.pos_counts)), A = T.pos_counts * 360 / P0.cpr_out;
        else, A = cumtrapz(T.t_s, fillmissing(T.meas, 'constant', 0)) * 6; end
    end

    function startPlay(src)
        if hw.on, say('Playback is off while the rig runs.', 'warn'); return; end
        if strcmp(src, 'replay') && isempty(replay), say('Pick a run under RUNS first.', 'warn'); return; end
        stopPlay();
        play.src = src; play.speed = sscanf(ui.speed.Value, '%f'); play.t = 0; play.tic = tic;
        if strcmp(src, 'sim'), play.tEnd = Tend; else, play.tEnd = replay.T.t_s(end); end
        ui.scrub.Limits = [0 max(play.tEnd, 0.1)];
        ui.play.Text = '■  PAUSE';
        playTimer = timer('ExecutionMode', 'fixedRate', 'Period', 0.04, 'BusyMode', 'drop', ...
            'TimerFcn', @(~, ~) safe(@playTick));
        start(playTimer);
    end

    function playTick()
        if ~isvalid(fig), stopPlay(); return; end
        play.t = toc(play.tic) * play.speed;
        if play.t >= play.tEnd, play.t = play.tEnd; end
        poseAt(play.src, play.t); ui.scrub.Value = min(play.t, ui.scrub.Limits(2));
        drawnow limitrate;
        if play.t >= play.tEnd, stopPlay(); end
    end

    function stopPlay()
        if ~isempty(playTimer) && isvalid(playTimer), stop(playTimer); delete(playTimer); end
        playTimer = [];
        if isvalid(fig), ui.play.Text = '▶  PLAY'; end
    end

    function out = recordVideo(outDir, src)
        %RECORDVIDEO  The current simulation (or replay) played into <outDir>/simulation.mp4 at 15 fps,
        %   frame by frame (slower than real time), with run_config.json describing it.
        if nargin < 2, src = ternary(isempty(replay), 'sim', 'replay'); end
        if ~isfolder(outDir), mkdir(outDir); end
        tEnd = ternary(strcmp(src, 'sim'), Tend, ternary(isempty(replay), Tend, replay.T.t_s(end)));
        fps = 15; n = max(2, round(tEnd * fps) + 1);
        cfg = S.cfg; cfg = rmfield(cfg, intersect(fieldnames(cfg), {'P'}));
        meta = struct('data_class', 'SIMULATION', 'mission', MIS(mis).tag, 'preset', ui.preset.Items{ui.preset.Value}, ...
            'profile', profile, 'run_length_s', Tend, 'config', cfg, 'model', model, 'source', src, ...
            'created', char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss')), 'git', servolab.tools.gitRev());
        fid = fopen(fullfile(outDir, 'run_config.json'), 'w'); fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true)); fclose(fid);
        out = servolab.ui.recordFrames(fig, n, @(j) poseAt(src, (j - 1) / fps), outDir, fps);
    end

    function onPlayButton()
        if ~isempty(playTimer), stopPlay(); return; end
        if isempty(replay), startPlay('sim'); else, startPlay('replay'); end
    end

    function onScrub(t)
        if hw.on, return; end
        stopPlay();
        if isempty(replay), poseAt('sim', t); else, poseAt('replay', t); end
    end

    % =================================================================== recorded runs
    function refreshRuns()
        try
            I = servolab.motor.runIndex();
        catch err
            say(['Runs not listed: ' err.message], 'warn'); I = table();
        end
        if ~isempty(I) && strcmp(ui.runFilter.Value, 'this mission')
            M = MIS(mis);
            if strcmp(M.kind, 'lab'), keep = true(height(I), 1);
            else, keep = strcmp(I.mission, M.tag) | ismember(I.name, M.experiments); end
            I = I(keep, :);
        end
        runsView = I;
        if isempty(I), ui.runs.Data = cell(0, 3); return; end
        D = cell(height(I), 3);
        for k = 1:height(I)
            fb = ''; if strcmp(I.fb{k}, 'encoder'), fb = ' enc'; end
            D(k, :) = {shortId(I.id{k}), I.result{k}, sprintf('%s %s%s  Kp %.2g Ki %.2g', I.loop{k}, ...
                ctrlTxt(I.ctrl{k}), fb, I.Kp(k), I.Ki(k))};
        end
        ui.runs.Data = D;
    end

    function onPickRun(e)
        if isempty(e.Selection) || isempty(runsView), return; end
        r = e.Selection(1);
        if r > height(runsView), return; end
        pickedRun = runsView.id{r};
        say(sprintf('%s · %s · %s. OVERLAY RUN draws it over the simulation of the same settings.', ...
            pickedRun, runsView.name{r}, runsView.result{r}), 'info');
    end

    function onOverlay()
        if isempty(pickedRun), say('Pick a run in the RUNS table first.', 'warn'); return; end
        overlayRun(pickedRun);
    end

    function overlayRun(id)
        if hw.on, say('STOP the rig run first.', 'warn'); return; end
        R = servolab.motor.loadHardwareRun(id);
        c = R.cfg;
        % the simulation takes the run's own settings, so SIM and RIG compare like with like
        busy = true;
        ui.plant.Value = 'rigId'; ui.Kd.Value = 0; ui.dist.Value = 0; ui.Jf.Value = 1;
        setToggle(ui.loopGrp, strcmp(c.loop, 'speed'), ui.loopSpeed, ui.loopPos);
        setToggle(ui.fbGrp, ~strcmp(getf(c, 'spdFb', 'drive'), 'encoder'), ui.fbDrive, ui.fbEnc);
        ui.ctrl.Value = c.ctrl; ui.Kp.Value = c.Kp; ui.Ki.Value = c.Ki;
        ui.uMax.Value = min(max(c.uMax, 1), 180); ui.Ts.Value = 1000 * c.Ts;
        ui.Tend.Value = max(1, ceil(R.T.t_s(end)));
        ui.profile.Value = profileText(runProfile(R));
        ui.fbGrp.Visible = strcmp(c.loop, 'speed');
        busy = false;
        replay = struct('id', id, 'T', R.T, 'angle', liveAngle(R.T), 'meta', R.meta);
        set(tr.yR, 'XData', R.T.t_s, 'YData', R.T.meas);
        set(tr.uR, 'XData', R.T.t_s, 'YData', R.T.u);
        update();
        say(sprintf('Replaying %s (violet) over the simulation of its settings (grey). PLAY moves the rig.', id), 'info');
    end

    function p = runProfile(R)
        % the experiment's own profile when the run names it, else read off the telemetry
        pr = getf(R.cfg, 'preset', '');
        tok = regexp(pr, '^(.*) \[run (\d+)/\d+\]$', 'tokens', 'once');
        if ~isempty(tok)
            j = find(strcmp({E.key}, servolab.motor.experimentKey(tok{1})), 1); k = str2double(tok{2});   % any name it ran under
            if ~isempty(j) && k <= numel(E(j).runs), p = E(j).runs(k).profile; return; end
        end
        T = R.T; ch = [1; find(abs(diff(T.setpoint)) > 1e-9) + 1];
        p = [round(10 * (T.t_s(ch) - R.cfg.Ts)) / 10, T.setpoint(ch)];
        p(1, 1) = 0;
    end

    function clearReplay()
        replay = []; set([tr.yR tr.uR], 'XData', nan, 'YData', nan);
        set(tr.mapR, 'XData', nan, 'YData', nan);
    end

    function onIdentify()
        if isempty(pickedRun), say('Pick an OPEN-LOOP speed run under RUNS, then IDENTIFY.', 'warn'); return; end
        R = servolab.motor.loadHardwareRun(pickedRun);
        if ~strcmp(R.cfg.ctrl, 'OL') || ~strcmp(R.cfg.loop, 'speed')
            say('Identification needs an open-loop speed run (M1 or M2).', 'warn'); return;
        end
        d = uiprogressdlg(fig, 'Title', 'Identifying', 'Indeterminate', 'on', ...
            'Message', sprintf('Fitting K, tau, dead time and ramp to %s ...', pickedRun));
        try
            [mf, info] = servolab.motor.fitIdentified({pickedRun});
            close(d);
        catch err
            close(d); say(['Identification failed: ' err.message], 'warn'); return;
        end
        busy = true;
        ui.mK.Value = mf.K; ui.mAcc.Value = min(max(mf.acc, 5), 2000); ui.mTau.Value = min(max(mf.tau, 0.001), 3);
        busy = false;
        model.theta = max(0, mf.theta);
        paramChanged(true);
        say(sprintf('Identified from %s: K %.3f, ramp %.1f rpm/s, tau %.3f s, dead time %.3f s (RMSE %.2f rpm).', ...
            pickedRun, mf.K, mf.acc, mf.tau, mf.theta, info.rmse), 'ok');
    end

    function onResetModel()
        model = model0;
        busy = true;
        ui.mK.Value = model.K; ui.mAcc.Value = model.acc; ui.mTau.Value = model.tau;
        ui.mLat.Value = 1000 * P0.lat_speed;
        busy = false;
        paramChanged(true);
        say('Model reset to the one identified from the rig (K 1.000, ramp 53.4 rpm/s).', 'info');
    end

    % =================================================================== hardware
    function refreshPorts()
        [p, n] = servolab.io.arduinoPorts();
        items = p; for k = 1:numel(p), if ~isempty(n{k}), items{k} = sprintf('%s   %s', p{k}, n{k}); end, end
        cur = ''; if link.isOpen(), cur = char(link.port); end
        if isempty(p), ui.port.Items = {'(no board)'}; ui.port.ItemsData = {''}; return; end
        ui.port.Items = items; ui.port.ItemsData = p;
        if ~isempty(cur) && any(strcmp(p, cur)), ui.port.Value = cur; end
    end

    function onConnect()
        if link.isOpen()
            if hw.on, onStop(); end
            link.close(); setEnabled(); say('Disconnected.', 'info'); return;
        end
        port = ui.port.Value;
        if isempty(port)
            say('No board found. Plug in the Uno (data cable). If no port appears, run setup in MATLAB.', 'warn');
            return;
        end
        connectTo(port);
    end

    function ok = connectTo(port)
        ok = false; lastPort = char(port);
        try
            link.open(port);
        catch err
            msg = err.message;
            if contains(lower(msg), {'in use', 'access', 'denied', 'busy', 'permission'})
                msg = sprintf('%s is in use or not permitted: close the Arduino IDE Serial Monitor or other MATLAB windows. %s', port, ...
                    ternary(isunix && ~ismac, '(Linux: are you in the dialout group?)', ''));
            end
            say(['Connect failed: ' msg], 'warn'); setEnabled(); return;
        end
        logDir = fullfile(servolab.repoRoot(), 'results', 'evidence', 'logs');
        if ~isempty(getenv('SERVOLAB_LOG_DIR')), logDir = getenv('SERVOLAB_LOG_DIR'); end
        if ~isfolder(logDir), mkdir(logDir); end
        link.startLog(fullfile(logDir, ['hw_session_' char(datetime('now', 'Format', 'yyyyMMdd-HHmmss')) '.log']));
        say(sprintf('Opened %s. The Uno restarts when the port opens; waiting for the firmware ...', port), 'info');
        setEnabled(); drawnow;
        if link.waitForHello(6)
            h = link.hello;
            ui.fw.Text = sprintf('fw %s · drive id %s', h{min(2, end)}, h{min(3, end)});
            if numel(h) >= 3 && ~strcmp(h{3}, '0')
                say(sprintf('Connected: firmware %s, RMCS-2303 at slave id %s. RUN ON RIG plays this mission''s settings.', h{2}, h{3}), 'ok');
                ok = true;
            else
                say('Firmware runs, but NO DRIVE answered: switch on the battery, check D9 -> drive pin 2, D8 <- pin 3, GND. Then DRIVE CHECK.', 'warn');
                ok = true;
            end
        elseif any(contains(link.debugLines(0), 'BRIDGE active'))
            say('The board is in BRIDGE mode (Rhino software): ending it ...', 'info'); drawnow;
            link.close(); servolab.io.SerialLink.endBridge(port);
            ok = connectTo(port); return;
        else
            say('Port open, but no reply from the firmware within 6 s: press FLASH FIRMWARE (or END BRIDGE).', 'warn');
        end
        setEnabled();
    end

    function onFlash()
        if hw.on, say('STOP the run before flashing.', 'warn'); return; end
        port = ui.port.Value;
        if isempty(port), say('No board found to flash. Plug in the Uno.', 'warn'); return; end
        if link.isOpen(), link.close(); end
        stop(watchTimer);
        cleanup = onCleanup(@() restartWatch());
        d = uiprogressdlg(fig, 'Title', 'Firmware', 'Indeterminate', 'on', 'Message', 'Checking the Arduino toolchain ...');
        [st, ~] = servolab.tools.cli('version');
        if st ~= 0
            d.Message = 'Installing the Arduino toolchain (once, about 60 MB) ...';
            try
                servolab.tools.install('Progress', @(m) set(d, 'Message', m));
            catch err
                close(d); say(['Toolchain install failed: ' err.message], 'warn'); return;
            end
        end
        d.Message = sprintf('Compiling and uploading the motor firmware to %s (about 20 s) ...', port);
        R = servolab.tools.flash('motor', port);
        close(d);
        pause(1.5);                                         % the Uno restarts after an upload
        knownPorts = servolab.io.arduinoPorts();
        if R.ok
            say(sprintf('Firmware %s flashed to %s. Connecting ...', R.rev, port), 'ok'); drawnow;
            connectTo(port);
        else
            uialert(fig, sprintf('%s\n\nLog: %s', R.hint, R.logFile), 'Upload failed', 'Icon', 'error');
            say(['Upload failed: ' R.hint], 'warn');
        end
    end
    function restartWatch()
        if isvalid(watchTimer) && strcmp(watchTimer.Running, 'off'), start(watchTimer); end
    end

    function onBridge(ask)
        if hw.on, say('STOP the run first.', 'warn'); return; end
        if ~link.isOpen(), say('Connect first: the bridge is started by the motor firmware.', 'warn'); return; end
        if ask
            a = uiconfirm(fig, ['The Uno will pass this USB port straight through to the RMCS-2303 at 9600 baud, so that ' ...
                'the Rhino configuration software (Windows) can talk to the drive on the same COM port. Motor power is switched ' ...
                'off first. While bridged, the Rhino software is in charge and this firmware''s watchdog and runaway guard are ' ...
                'not active. The mode survives resets until END BRIDGE (or the STOP button).'], 'Bridge for the Rhino software', ...
                'Options', {'Start the bridge', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
            if ~strcmp(a, 'Start the bridge'), return; end
        end
        port = char(link.port);
        n0 = size(link.eventLog, 1);
        link.send('BRIDGE');
        t0 = tic; ok = false;
        while toc(t0) < 2 && ~ok
            link.poll(); ev = link.eventLog(n0 + 1:end, :);
            ok = any(contains(string(ev(:, 3)), 'BRIDGE')); pause(0.05);
        end
        link.close(); setEnabled();
        ui.linkChip.Text = 'BRIDGE'; ui.linkChip.BackgroundColor = K.amber; ui.stateChip.Text = 'RHINO SW';
        say(sprintf(['%s now reaches the drive at 9600 baud: open the Rhino software on that port. Compare its register ' ...
            'values with DRIVE CHECK. END BRIDGE returns to this firmware.'], port), ternary(ok, 'ok', 'warn'));
    end

    function onEndBridge()
        port = lastPort; if isempty(port), port = ui.port.Value; end
        if isempty(port) || startsWith(port, '('), say('No board.', 'warn'); return; end
        if link.isOpen(), link.close(); end
        try
            servolab.io.SerialLink.endBridge(port);
        catch err
            say(['END BRIDGE failed: ' err.message ' (close the Rhino software first).'], 'warn'); return;
        end
        connectTo(port);
    end

    function onDiag()
        if ~link.isOpen(), say('Connect first.', 'warn'); return; end
        if hw.on, say('STOP the run first.', 'warn'); return; end
        n0 = size(link.eventLog, 1);
        link.send('DIAG');
        t0 = tic; while toc(t0) < 3, link.poll(); pause(0.05); end
        Ls = link.debugLines(n0);
        if isempty(Ls), say('No reply to DRIVE CHECK: is the motor firmware flashed?', 'warn'); return; end
        txt = strjoin(strrep(Ls, '# ', ''), newline);
        uialert(fig, txt, 'Drive check', 'Icon', 'info');
        say('Drive check done (register dump and loop time in the dialog and the session log).', 'ok');
    end

    function onRunRig()
        if hw.on, say('Already running.', 'warn'); return; end
        if ~link.isOpen(), say('Not connected: plug in the Uno and press CONNECT.', 'warn'); return; end
        if strcmp(ui.plant.Value, 'arm')
            say('The armature model is simulation only: on the rig the RMCS-2303 drives the motor. Choose a RIG plant.', 'warn'); return;
        end
        stopPlay();
        if ~isempty(hw.fault)
            say(sprintf('The firmware stopped the last run (%s). Press CLEAR FAULT first.', hw.fault), 'warn'); return;
        end
        c = readCfg();
        pr = presets(ui.preset.Value);
        clearReplay(); clearLive();
        hw.nErr = countErr();
        hw.cfg = c; hw.on = true; hw.t0 = tic;
        if ~isempty(pr.series)
            x = pr.series; hw.kind = 'series';
        else
            spec = struct('loop', c.loop, 'ctrl', c.ctrl, 'Kp', c.Kp, 'Ki', c.Ki, 'profile', profile, ...
                'duration', Tend, 'spdFb', c.spdFb, 'uMax', c.uMax);
            x = struct('name', presets(ui.preset.Value).spec.name, 'id', c.experiment, ...
                'purpose', '', 'runs', spec);
            if strcmp(MIS(mis).kind, 'lab'), x.name = sprintf('LAB %s %s', c.loop, c.ctrl); end
            hw.kind = 'single';
        end
        hw.runner = servolab.motor.ExperimentRunner(link, x, @onRunStart, @onRunDone);
        % the whole window is redrawn before RUN goes out: a long first render after RUN
        % would starve the firmware's host watchdog (MOTOR-R0129, 2026-10-25)
        ui.rec.Visible = 'on'; ui.stateChip.Text = 'RUNNING'; ui.stateChip.BackgroundColor = K.cyanDim;
        setEnabled();
        say(sprintf('Running on the rig: %s. ABORT (Esc / Space) cuts motor power.', x.name), 'info');
        try
            hw.runner.start();                         % onRunStart, then CFG, SET, RUN
        catch err
            hw.on = false; hw.runner = []; fault(['could not start: ' err.message]); return;
        end
        % last: the first tick may run at once and may already report a fault
        hwTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.1, 'BusyMode', 'drop', ...
            'TimerFcn', @(~, ~) safe(@hwTick));
        start(hwTimer);
    end

    function onRunStart(c, k)
        % called just before RUN is sent: everything slow happens here, then one full render
        hw.cfg = c; hw.runK = k;                       % the link starts a fresh table at every RUN
        clearLive();
        if strcmp(hw.kind, 'series')
            hw.cfg.antiWindup = true;
            S = servolab.motor.identifiedSim(model, c, hw.runner.experiment.runs(k).profile, c.Tend);
            S.y = yOf(S); profile = hw.runner.experiment.runs(k).profile; Tend = c.Tend;
            drawSim();
        end
        drawnow;
    end

    function onSync()
        if hw.on, say('STOP the run before syncing.', 'warn'); return; end
        d = uiprogressdlg(fig, 'Title', 'SYNC DATA', 'Indeterminate', 'on', 'Message', 'Committing and pushing the rig data ...');
        r = servolab.data.sync('MOTOR'); close(d);
        say(r.message, ternary(r.ok, 'ok', 'warn'));
    end

    function onRunDone(spec, T, k) %#ok<INUSL>
        saveRunNow(T, k, 'FINISHED');
    end

    function saveRunNow(T, k, result)
        % every rig run is kept, finished or not: the result says which
        if nargin < 1 || isempty(T), T = hwTable(); end
        if nargin < 2 || isempty(k), k = getf(hw, 'runK', 1); end
        if isempty(T) || height(T) == 0 || ~isfield(hw, 'cfg') || isempty(hw.cfg), return; end
        T = T(T.seq >= 0, :);
        if isempty(T) || height(T) == 0, return; end
        name = ''; if ~isempty(hw.runner), name = hw.runner.experiment.name; end
        info = struct('port', char(link.port), 'invalidCount', link.invalidCount, 'seqGaps', link.seqGaps, ...
            'experiment', name, 'run', k, 'app', 'rhino_servo_lab', 'mission', MIS(mis).tag, ...
            'hello', {link.hello}, 'result', result);
        try
            r = servolab.motor.exportHardwareRun(T, hw.cfg, link.eventLog, info);
            hw.lastSaved = r.runId;
            try, exportapp(fig, fullfile(fileparts(r.meta), [r.runId '.png'])); catch, end
            say(sprintf('Saved %s (raw data, read-only).', r.runId), 'ok');
        catch err
            say(['Saving the run failed: ' err.message], 'warn');
        end
    end

    function hwTick()
        if ~isvalid(fig) || ~link.isOpen(), endRun('link closed'); return; end
        link.poll();
        T = hwTable();
        if ~isempty(T) && height(T) > 0
            set(tr.yH, 'XData', T.t_s, 'YData', T.meas);
            set(tr.uH, 'XData', T.t_s, 'YData', T.u);
            if strcmp(MIS(mis).kind, 'map')
                mm = metricsOf(T.t_s, T.setpoint, T.meas, T.u, hw.cfg);
                set(tr.mapH, 'XData', mm.map.cmd, 'YData', mm.map.speed);
            end
            poseAt('live', T.t_s(end));
            autoAxes();
            drawnow limitrate; link.poll();             % render now, then PING again: a slow frame never starves the 2 s watchdog
        end
        ev = link.eventLog; idx = [];
        if ~isempty(ev), idx = find(strcmp(ev(:, 2), 'ERR') & startsWith(string(ev(:, 3)), ["RUN,", "HOME,"])); end
        if numel(idx) > hw.nErr
            txt = ev{idx(end), 3}; hw.nErr = numel(idx);
            if ~isempty(hw.runner) && hw.runner.isActive(), hw.runner.abort(['firmware: ' txt]); end
            fault(txt); return;
        end
        if ~isempty(hw.runner)
            hw.runner.tick();
            if ~hw.runner.isActive()
                r = hw.runner;
                if strcmp(r.state, 'done'), endRun(''); say([r.message ' Saved under RUNS.'], 'ok');
                else, endRun(r.message); end
            end
        end
        fillTable();
        drawnow limitrate;
    end

    function T = hwTable()
        T = table();
        if link.n == 0, return; end
        T = link.table();                              % this run's frames only (SerialLink.run resets it)
    end
    function t = hwT()
        T = hwTable(); t = 0; if ~isempty(T) && height(T) > 0, t = T.t_s(end); end
    end

    function clearLive()
        set([tr.yH tr.uH tr.mapH], 'XData', nan, 'YData', nan);
    end

    function endRun(why)
        if ~isempty(hwTimer) && isvalid(hwTimer), stop(hwTimer); delete(hwTimer); end
        hwTimer = [];
        hw.on = false; hw.runner = [];
        if isvalid(fig)
            ui.rec.Visible = 'off';
            if isempty(hw.fault), ui.stateChip.Text = 'STOPPED'; ui.stateChip.BackgroundColor = K.btn; end
            if ~isempty(why) && isempty(hw.fault), say(['Run ended: ' why], 'warn'); end
            refreshRuns(); setEnabled();
        end
    end

    function fault(txt)
        p = strsplit(char(txt), ','); reason = strtrim(p{end});
        hw.fault = reason;
        if hw.on, saveRunNow([], [], ['STOPPED: ' reason]); end
        endRun('');
        ui.stateChip.Text = 'FAULT'; ui.stateChip.BackgroundColor = K.red;
        ui.clear.BackgroundColor = K.amber; ui.clear.FontColor = K.bg;
        say(sprintf('The firmware cut motor power: %s. %s Then CLEAR FAULT.', reason, adviceFor(reason)), 'warn');
    end

    function s = adviceFor(reason)
        r = lower(reason);
        if contains(r, 'wrong way'),      s = 'The motor turned against the command: check the encoder wires (pins 10/11) and that the drive restarted cleanly.';
        elseif contains(r, 'too fast'),   s = 'The motor ran faster than commanded: check the encoder and the drive line count (DRIVE CHECK: LPR 13).';
        elseif contains(r, 'modbus'),     s = 'The drive stopped answering: battery on? D8/D9/GND to the drive?';
        elseif contains(r, 'host silent'), s = 'MATLAB was busy for over 2 s; close other heavy work and run again.';
        elseif contains(r, 'estopped'),   s = 'A previous fault is still latched.';
        else,                             s = '';
        end
    end

    function onClearFault()
        if ~link.isOpen(), hw.fault = ''; setEnabled(); return; end
        if hw.on, say('STOP first.', 'warn'); return; end
        try
            link.send('HOME'); pause(0.4); link.poll();
        catch err
            say(['CLEAR FAULT failed: ' err.message], 'warn'); return;
        end
        hw.fault = ''; ui.stateChip.Text = 'READY'; ui.stateChip.BackgroundColor = K.green;
        ui.clear.BackgroundColor = K.btn; ui.clear.FontColor = K.text;
        say('Fault cleared (drive re-homed, angle counter zeroed). RUN is allowed again.', 'ok');
        setEnabled();
    end

    function onStop(now)
        % STOP: the motor comes to rest on the drive's ramp, then power off; ABORT: power off at once
        if nargin < 1, now = false; end
        if ~isempty(hw.runner) && hw.runner.isActive(), hw.runner.abort('stopped by the operator'); end
        try
            if link.isOpen(), link.stop(ternary(now, 'now', '')); end
        catch err
            say(['STOP failed: ' err.message ' -- switch the battery off.'], 'warn');
        end
        if hw.on, saveRunNow([], [], 'ABORTED: by the operator'); endRun('stopped by the operator'); end
    end

    function doAbort()
        stopPlay();
        onStop(true);
        if link.isOpen(), say('ABORT: motor power off.', 'warn'); end
    end

    function onKey(e)
        if any(strcmp(e.Key, {'escape', 'space'})), doAbort(); end
    end

    function onLiveSet(delta)
        if ~hw.on, ui.liveSp.Value = min(max(ui.liveSp.Value, -360), 360); return; end
        if isnan(delta), v = 0; else, v = ui.liveSp.Value + delta; end
        liveTo(v);
    end
    function liveTo(v)
        ui.liveSp.Value = min(max(v, ui.liveSp.Limits(1)), ui.liveSp.Limits(2));
        if ~hw.on || ~link.isOpen(), return; end
        try
            link.setpoint(ui.liveSp.Value);
            say(sprintf('Live setpoint %.0f %s sent.', ui.liveSp.Value, ternary(strcmp(hw.cfg.loop, 'speed'), 'rpm', 'deg')), 'info');
        catch err
            fault(['RUN,0,' err.message]);
        end
    end

    function watchTick()
        if ~isvalid(fig), return; end
        p = servolab.io.arduinoPorts();
        added = setdiff(p, knownPorts); removed = setdiff(knownPorts, p); knownPorts = p;
        if ~isempty(added) || ~isempty(removed), refreshPorts(); end
        if link.isOpen() && any(strcmp(removed, char(link.port)))
            if hw.on, endRun('the board was unplugged'); end
            try, link.close(); catch, end
            setEnabled();
            say('The Uno was unplugged. Without MATLAB the firmware stops the drive within 1 s.', 'warn');
        end
        if ~isempty(added) && ~link.isOpen() && ~asking
            port = added{1}; asking = true;
            ui.port.Value = port;
            uiconfirm(fig, sprintf(['Arduino found on %s.\n\nFlash the motor firmware and connect, or ' ...
                'connect to the firmware already on it?'], port), 'Board connected', ...
                'Options', {'Flash + connect', 'Connect', 'Not now'}, 'DefaultOption', 2, 'CancelOption', 3, ...
                'CloseFcn', @(~, e) onPlugAnswer(e.SelectedOption, port));
        end
        if link.isOpen() && ~hw.on, link.poll(); end              % keep the firmware's watchdog content
    end

    function onPlugAnswer(opt, port)
        asking = false;
        switch opt
            case 'Flash + connect', ui.port.Value = port; onFlash();
            case 'Connect', connectTo(port);
        end
    end

    function setEnabled()
        if ~isvalid(fig), return; end
        on = link.isOpen();
        ui.linkChip.Text = ternary(on, ['RIG  ' char(link.port)], 'OFFLINE');
        ui.linkChip.BackgroundColor = ternary(on, K.green, K.btn);
        ui.connect.Text = ternary(on, 'DISCONNECT', 'CONNECT');
        ui.run.Enable = onoff(on && ~hw.on);
        ui.stop.Enable = onoff(on);
        ui.diag.Enable = onoff(on && ~hw.on);
        ui.bridge.Enable = onoff(on && ~hw.on);
        ui.clear.Enable = onoff(on && ~hw.on);
        ui.flash.Enable = onoff(~hw.on);
        set([ui.liveSp ui.liveSet ui.liveDn ui.liveUp ui.liveZero], 'Enable', onoff(hw.on));
        set([ui.playSim ui.play ui.overlay ui.identify ui.preset], 'Enable', onoff(~hw.on));
        set(ui.mb, 'Enable', onoff(~hw.on));
        if ~on && ~hw.on, ui.stateChip.Text = 'SIMULATION'; ui.stateChip.BackgroundColor = K.btn; end
        if on && ~hw.on && isempty(hw.fault), ui.stateChip.Text = 'READY'; ui.stateChip.BackgroundColor = K.green; end
    end

    function n = countErr()
        ev = link.eventLog; n = 0;
        if ~isempty(ev), n = nnz(strcmp(ev(:, 2), 'ERR') & startsWith(string(ev(:, 3)), ["RUN,", "HOME,"])); end
    end

    function onClose()
        try
            stopPlay();
            if link.isOpen(), try, link.stop(); catch, end, link.close(); end
        catch err
            warning('servolab:app:close', 'closing the link: %s', err.message);
        end
        killTimers();
        delete(fig);
    end

    function killTimers()
        for t = {simTimer, watchTimer, hwTimer, playTimer}
            h = t{1};
            if ~isempty(h) && isvalid(h), stop(h); delete(h); end
        end
    end

    function safe(f)
        try
            f();
        catch err
            if isvalid(fig), say(['Internal error: ' err.message], 'warn'); end
        end
    end

    % =================================================================== read-only access (scripts, tests)
    % (nested functions, not anonymous ones: an anonymous function would freeze the values)
    function r = getS(), r = S; end
    function r = getTable(), r = ui.table.Data; end
    function r = getRuns(), r = runsView; end
    function r = getHw(), r = hw; end
    function r = getLink(), r = link; end
    function r = getMission(), r = MIS(mis); end
    function r = getModel(), r = model; end

    % =================================================================== layout helpers
    function r = next(h), row = row + 1; L.RowHeight{row} = h; r = row; end
    function head(txt)
        h = uilabel(L, 'Text', txt, 'FontSize', 11, 'FontWeight', 'bold', 'FontColor', K.dim, ...
            'VerticalAlignment', 'bottom');
        place(h, next(24), [1 2]);
    end
    function h = note(txt, ht)
        h = uilabel(L, 'Text', txt, 'FontSize', 11.5, 'FontColor', K.text, 'WordWrap', 'on', 'VerticalAlignment', 'top');
        place(h, next(ht), [1 2]);
    end
    function h = btn(txt, fcn, cols, ht)
        h = uibutton(L, 'Text', txt, 'FontWeight', 'bold', 'ButtonPushedFcn', fcn);
        place(h, next(ht), cols);
    end
    function ax = mkAx(parent, ttl)
        ax = uiaxes(parent); hold(ax, 'on');
        ax.Color = K.panel; ax.XColor = K.dim; ax.YColor = K.dim; ax.GridColor = K.line; ax.GridAlpha = 1;
        ax.FontSize = 10; grid(ax, 'on'); box(ax, 'off'); ax.BackgroundColor = K.bg;
        title(ax, ttl, 'Color', K.text, 'FontWeight', 'bold', 'FontSize', 10.5);
        ax.TitleHorizontalAlignment = 'left';
        try, ax.Toolbar.Visible = 'off'; catch, end
        % explicit interactions, set now: MATLAB otherwise builds its default set on the first
        % render after a change, synchronously, which can block a live run for most of a second
        try, ax.Interactions = [panInteraction zoomInteraction dataTipInteraction]; catch, end
    end
    function h = lbl(parent, txt, sz, col, wt)
        h = uilabel(parent, 'Text', txt, 'FontSize', sz, 'FontColor', col, 'FontWeight', wt);
    end
    function h = chip(parent, txt)
        h = uilabel(parent, 'Text', txt, 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', 'w', ...
            'HorizontalAlignment', 'center', 'BackgroundColor', K.btn);
    end
    function h = big(parent, col)
        h = uilabel(parent, 'Text', '—', 'FontSize', 26, 'FontWeight', 'bold', 'FontColor', col, 'FontName', K.mono);
    end
    function styleButtons(f)
        b = findall(f, 'Type', 'uibutton');
        for i = 1:numel(b), b(i).BackgroundColor = K.btn; b(i).FontColor = K.text; end
        t = findall(f, 'Type', 'uitogglebutton');
        for i = 1:numel(t), t(i).BackgroundColor = K.btn; t(i).FontColor = K.text; t(i).FontWeight = 'bold'; end
    end
    function say(txt, kind)
        if ~isvalid(fig), return; end
        ui.say.Text = txt;
        switch kind
            case 'warn', ui.say.FontColor = K.amber;
            case 'ok',   ui.say.FontColor = K.green;
            otherwise,   ui.say.FontColor = K.text;
        end
    end
end

% ======================================================================= helpers
function setToggle(grp, first, a, b)
    if first, grp.SelectedObject = a; else, grp.SelectedObject = b; end
end

function p = parseProfile(txt)
    v = sscanf(strrep(strrep(char(txt), ';', ' '), ',', ' '), '%f');
    p = [];
    if isempty(v) || mod(numel(v), 2) ~= 0, return; end
    p = reshape(v, 2, [])';
    if p(1, 1) ~= 0 || any(diff(p(:, 1)) <= 0), p = []; end
end

function s = profileText(p)
    s = strjoin(arrayfun(@(k) sprintf('%g %g', p(k, 1), p(k, 2)), 1:size(p, 1), 'UniformOutput', false), '; ');
end

function s = shortId(id)
    % MOTOR-R0061_20261023-193103_M6 -> 'R0061  10-23 19:31  M6'
    t = regexp(id, '^[A-Z]+-R(\d+)_\d{4}(\d{2})(\d{2})-(\d{2})(\d{2})\d{2}_(.*)$', 'tokens', 'once');
    if isempty(t), s = id; else, s = sprintf('R%s  %s-%s %s:%s  %s', t{:}); end
end
function s = ctrlTxt(c), if strcmp(c, 'OL'), s = 'open'; else, s = c; end, end
function v = getm(m, k), if isempty(m) || ~isfield(m, k), v = NaN; else, v = m.(k); end, end
function v = getf(s, f, d), if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end, end
function s = num(v, f), if isempty(v) || ~isfinite(v), s = '—'; else, s = sprintf(f, v); end, end
function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
function s = onoff(c), s = matlab.lang.OnOffSwitchState(logical(c)); end
function place(h, r, c), h.Layout.Row = r; h.Layout.Column = c; end
