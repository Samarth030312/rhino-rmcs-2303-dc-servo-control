function mdl = build_drive_physics_simulink(outDir)
%BUILD_DRIVE_PHYSICS_SIMULINK  Generate servo_drive_physics.slx: the rig from datasheet physics.
%
%   mdl = build_drive_physics_simulink()          % writes matlab/models/dc_motor/
%
%   The lab rig built from the motor's datasheet and an ESTIMATED structure of the drive's
%   speed loop (its internals are not published), with the Arduino's sampled loop around it.
%   Block for block the 'rig' plant of servolab.motor.simulate, integrated with the same
%   explicit Euler step (dt = 1 ms), so the two agree to rounding:
%
%     u (output rpm) -> x N -> clip +/- wMax -> ramp (acc) -> wr --(+)-> Kpd --(+)-> i, clipped to
%                                                               ^- w      xi -^      +/- 3 A and to the
%     xi += Kid ed dt unless the clip is pushing the other way                       battery's headroom
%     w += (Kt i - b w - T_load / (N eta)) dt / J ;  angle += w dt                   (V_supply - Ke w) / R
%
%   Unlike servo_identified it has current, a load torque and inertia. Parameters live in the
%   model workspace; run_drive_physics_simulink(c, profile, Tend) sets them.

    if nargin < 1, outDir = fileparts(mfilename('fullpath')); end
    mdl = 'servo_drive_physics';
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl);
    cleanup = onCleanup(@() close_system(mdl, 0));
    set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', 'dt', 'StopTime', 'Tend', ...
              'SaveOutput', 'on', 'SaveFormat', 'Dataset', 'SaveTime', 'on');
    % parameters first: a block's expression (R, J, ...) must never resolve to a variable of the same name in the base workspace
    c = servolab.motor.defaultConfig('rig', 'speed');
    w = drive_physics_simulink_params(c, [0 c.setpoint], 5);
    mws = get_param(mdl, 'ModelWorkspace');
    f = fieldnames(w);
    for i = 1:numel(f), assignin(mws, f{i}, w.(f{i})); end

    B = @(lib, name, pos, varargin) add_block(lib, [mdl '/' name], 'Position', pos, varargin{:});
    UD = @(name, pos) B('simulink/Discrete/Unit Delay', name, pos, 'SampleTime', 'dt', 'InitialCondition', '0');
    % ------------------------------------------------------------ drive: speed ramp
    B('simulink/Math Operations/Gain', 'output rpm to base rad per s', [500 125 550 155], 'Gain', 'kU');
    B('simulink/Discontinuities/Saturation', 'Drive speed limit', [570 125 610 155], 'UpperLimit', 'wMax', 'LowerLimit', '-wMax');
    B('simulink/Math Operations/Sum', 'Ramp error', [630 125 650 155], 'Inputs', '+-');
    B('simulink/Discontinuities/Saturation', 'Acceleration register', [670 125 710 155], 'UpperLimit', 'accDt', 'LowerLimit', '-accDt');
    B('simulink/Math Operations/Sum', 'Ramp', [730 125 750 155], 'Inputs', '++');
    UD('wr', [730 180 760 210]);
    % ------------------------------------------------------------ drive: PI speed loop, current limits
    B('simulink/Math Operations/Sum', 'Speed error', [780 125 800 155], 'Inputs', '+-');
    B('simulink/Math Operations/Gain', 'Kpd', [820 125 860 155], 'Gain', 'Kpd');
    B('simulink/Math Operations/Sum', 'Drive PI', [880 125 900 155], 'Inputs', '++');
    B('simulink/Math Operations/Gain', 'Back-EMF Ke', [780 300 820 330], 'Gain', 'Ke');
    B('simulink/Sources/Constant', 'V_supply', [780 240 820 260], 'Value', 'Vs');
    B('simulink/Math Operations/Sum', 'Headroom up', [840 240 860 270], 'Inputs', '+-');
    B('simulink/Math Operations/Sum', 'Headroom down', [840 300 860 330], 'Inputs', '--');
    B('simulink/Math Operations/Gain', 'up over R', [870 240 900 270], 'Gain', '1/R');
    B('simulink/Math Operations/Gain', 'down over R', [870 300 900 330], 'Gain', '1/R');
    B('simulink/Sources/Constant', 'I limit', [870 200 900 220], 'Value', 'Ilim');
    B('simulink/Sources/Constant', '-I limit', [870 340 900 360], 'Value', '-Ilim');
    B('simulink/Math Operations/MinMax', 'i high', [920 210 950 260], 'Function', 'min', 'Inputs', '2');
    B('simulink/Math Operations/MinMax', 'i low', [920 300 950 350], 'Function', 'max', 'Inputs', '2');
    B('simulink/Discontinuities/Saturation Dynamic', 'Current limit', [980 120 1020 180]);
    % conditional integration: integrate unless the clip pushes against the error
    B('simulink/Logic and Bit Operations/Relational Operator', 'not clipped', [1050 60 1080 90], 'Operator', '==');
    B('simulink/Math Operations/Sum', 'clip amount', [1050 100 1070 120], 'Inputs', '-+');
    B('simulink/Math Operations/Sign', 'sign clip', [1090 100 1110 120]);
    B('simulink/Math Operations/Sign', 'sign ed', [820 60 840 80]);
    B('simulink/Logic and Bit Operations/Relational Operator', 'clip helps', [1130 80 1160 110], 'Operator', '~=');
    B('simulink/Logic and Bit Operations/Logical Operator', 'integrate', [1180 60 1210 100], 'Operator', 'OR');
    B('simulink/Signal Attributes/Data Type Conversion', 'to double', [1230 65 1260 95], 'OutDataTypeStr', 'double');
    B('simulink/Math Operations/Product', 'gate', [1280 60 1310 100]);
    B('simulink/Math Operations/Gain', 'Kid dt', [1330 65 1370 95], 'Gain', 'KidDt');
    B('simulink/Math Operations/Sum', 'xi next', [1390 65 1410 95], 'Inputs', '++');
    UD('xi', [1390 20 1420 50]);
    % ------------------------------------------------------------ motor and load (base shaft)
    B('simulink/Math Operations/Gain', 'Kt', [1050 180 1090 210], 'Gain', 'Kt');
    B('simulink/Math Operations/Gain', 'b', [1050 380 1090 410], 'Gain', 'b');
    B('simulink/Sources/Step', 'Load torque (base)', [1050 420 1090 450], 'Time', 'tDist', 'Before', '0', 'After', 'TLbase', 'SampleTime', 'dt');
    B('simulink/Math Operations/Sum', 'Torque', [1110 180 1130 450], 'Inputs', '+--');
    B('simulink/Math Operations/Gain', 'dt over J', [1150 300 1190 330], 'Gain', 'dt/Jt');
    B('simulink/Math Operations/Sum', 'w next', [1210 300 1230 330], 'Inputs', '++');
    UD('w', [1210 360 1240 390]);
    B('simulink/Math Operations/Gain', 'times dt', [1250 300 1280 330], 'Gain', 'dt');
    B('simulink/Math Operations/Sum', 'angle next', [1300 300 1320 330], 'Inputs', '++');
    UD('angle', [1300 360 1330 390]);
    B('simulink/Math Operations/Gain', 'base rad per s to output rpm', [1260 420 1310 450], 'Gain', '1/kU');
    B('simulink/Math Operations/Gain', 'base rad to output deg', [1350 420 1400 450], 'Gain', '180/(pi*N)');
    B('simulink/Sinks/Out1', 'speed_rpm', [1340 480 1370 495], 'Port', '3');
    B('simulink/Sinks/Out1', 'angle_output_deg', [1430 480 1460 495], 'Port', '4');
    B('simulink/Sinks/Out1', 'current_A', [1050 240 1080 255], 'Port', '5');

    T = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');
    T('output rpm to base rad per s/1', 'Drive speed limit/1'); T('Drive speed limit/1', 'Ramp error/1');
    T('wr/1', 'Ramp error/2'); T('Ramp error/1', 'Acceleration register/1');
    T('Acceleration register/1', 'Ramp/1'); T('wr/1', 'Ramp/2'); T('Ramp/1', 'wr/1');
    T('Ramp/1', 'Speed error/1'); T('w/1', 'Speed error/2');
    T('Speed error/1', 'Kpd/1'); T('Kpd/1', 'Drive PI/1'); T('xi/1', 'Drive PI/2');
    T('w/1', 'Back-EMF Ke/1');
    T('V_supply/1', 'Headroom up/1'); T('Back-EMF Ke/1', 'Headroom up/2');
    T('V_supply/1', 'Headroom down/1'); T('Back-EMF Ke/1', 'Headroom down/2');
    T('Headroom up/1', 'up over R/1'); T('Headroom down/1', 'down over R/1');
    T('I limit/1', 'i high/1'); T('up over R/1', 'i high/2');
    T('-I limit/1', 'i low/1'); T('down over R/1', 'i low/2');
    T('i high/1', 'Current limit/1'); T('Drive PI/1', 'Current limit/2'); T('i low/1', 'Current limit/3');
    T('Current limit/1', 'not clipped/1'); T('Drive PI/1', 'not clipped/2');
    T('Current limit/1', 'clip amount/1'); T('Drive PI/1', 'clip amount/2');
    T('clip amount/1', 'sign clip/1'); T('Speed error/1', 'sign ed/1');
    T('sign ed/1', 'clip helps/1'); T('sign clip/1', 'clip helps/2');
    T('not clipped/1', 'integrate/1'); T('clip helps/1', 'integrate/2');
    T('integrate/1', 'to double/1'); T('to double/1', 'gate/1'); T('Speed error/1', 'gate/2');
    T('gate/1', 'Kid dt/1'); T('Kid dt/1', 'xi next/1'); T('xi/1', 'xi next/2'); T('xi next/1', 'xi/1');
    T('Current limit/1', 'Kt/1'); T('Current limit/1', 'current_A/1');
    T('w/1', 'b/1');
    T('Kt/1', 'Torque/1'); T('b/1', 'Torque/2'); T('Load torque (base)/1', 'Torque/3');
    T('Torque/1', 'dt over J/1'); T('dt over J/1', 'w next/1'); T('w/1', 'w next/2'); T('w next/1', 'w/1');
    T('w next/1', 'times dt/1'); T('times dt/1', 'angle next/1'); T('angle/1', 'angle next/2'); T('angle next/1', 'angle/1');
    T('w/1', 'base rad per s to output rpm/1'); T('angle/1', 'base rad to output deg/1');
    T('base rad per s to output rpm/1', 'speed_rpm/1'); T('base rad to output deg/1', 'angle_output_deg/1');
    % the Arduino and its sensors, shared with servo_identified (the encoder reads the output angle)
    simulink_scope(mdl, 'Scope: current', {{'Current limit/1'}}, {'motor current (A)'}, [1600 300]);
    simulink_name_signal([mdl '/Current limit'], 1, 'current (A)');
    simulink_name_signal([mdl '/w'], 1, 'speed (base rad/s)');
    io = simulink_servo_io(mdl, 'output rpm to base rad per s/1', 'base rad per s to output rpm/1', 'base rad to output deg/1');
    simulink_tidy(mdl, [io; ...
        {'RMCS-2303 drive (structure estimated)', {'output rpm to base rad per s', 'Drive speed limit', 'Ramp error', ...
            'Acceleration register', 'Ramp', 'wr', 'Speed error', 'Kpd', 'Drive PI', 'Back-EMF Ke', 'V_supply', 'Headroom up', ...
            'Headroom down', 'up over R', 'down over R', 'I limit', '-I limit', 'i high', 'i low', 'Current limit', 'not clipped', ...
            'clip amount', 'sign clip', 'sign ed', 'clip helps', 'integrate', 'to double', 'gate', 'Kid dt', 'xi next', 'xi'}; ...
         'Motor and load (datasheet)', {'Kt', 'b', 'Load torque (base)', 'Torque', 'dt over J', 'w next', 'w', 'times dt', ...
            'angle next', 'angle', 'base rad per s to output rpm', 'base rad to output deg'}}]);

    outs = {'measured', 'u_cmd_rpm', 'speed_rpm', 'angle_output_deg', 'current_A'};               % outport order, as run_* read them
    for k = 1:numel(outs), set_param([mdl '/' outs{k}], 'Port', num2str(k)); end

    note = Simulink.Annotation([mdl '/note']);
    note.Text = ['Rhino DC servo - the rig from DATASHEET PHYSICS (RMCS-5032 motor, RMCS-2303 speed loop: ' ...
        'structure ESTIMATED, 3 A limit, battery headroom), load torque and inertia. ' ...
        'Set parameters with run_drive_physics_simulink(c, profile, Tend).'];
    note.Position = simulink_note_position(mdl, 900);

    if ~exist(outDir, 'dir'), mkdir(outDir); end
    simulink_save(mdl, fullfile(outDir, [mdl '.slx']));
end
