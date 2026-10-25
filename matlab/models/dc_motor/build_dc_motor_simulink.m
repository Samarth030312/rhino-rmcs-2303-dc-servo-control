function mdl = build_dc_motor_simulink(outDir)
%BUILD_DC_MOTOR_SIMULINK  Generate servo_armature.slx (course week-4 model).
%
%   mdl = build_dc_motor_simulink()            % writes matlab/models/dc_motor/
%   mdl = build_dc_motor_simulink(outDir)
%
%   The model is the BARE motor driven by armature voltage (ED-M1 option C):
%
%     setpoint -> (+)-> Discrete PID (Ts, clamped, limited) -+-> [Switch] -> V
%                  ^-                                          |   open loop: r / Kss
%                  |                                           |
%     measured <- [select speed | position] <- quantise <- DC motor <- load step
%
%     DC motor:  L di/dt = V - R i - Ke w ;  J dw/dt = Kt i - b w - T_L/(N eta)
%
%   The lab rig (RMCS-2303 speed loop + Modbus outer loop) is simulated in
%   MATLAB only (servolab.motor.simulate); its drive internals are undocumented
%   and building a second, equally estimated, Simulink copy adds no evidence.
%
%   Parameters live in the model workspace. run_dc_motor_simulink(cfg) sets
%   them from an servolab.motor config and runs the model, so the Simulink and
%   MATLAB simulations are driven by the same numbers. Requires Simulink.

    if nargin < 1, outDir = fileparts(mfilename('fullpath')); end
    mdl = 'servo_armature';
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl);
    cleanup = onCleanup(@() close_system(mdl, 0));
    set_param(mdl, 'Solver', 'ode45', 'RelTol', '1e-8', 'AbsTol', '1e-10', 'MaxStep', '1e-3', ...
              'StopTime', 'Tend', 'SaveOutput', 'on', 'SaveFormat', 'Dataset', 'SaveTime', 'on');
    % parameters first: a block's expression (R, J, ...) must never resolve to a variable of the same name in the base workspace
    setWorkspace(mdl, servolab.motor.defaultConfig('bare', 'speed'));

    % ------------------------------------------------------------- top level
    B = @(lib, name, pos, varargin) add_block(lib, [mdl '/' name], 'Position', pos, varargin{:});
    B('simulink/Sources/Step', 'Setpoint', [30 95 60 125], 'Time', 'tStep', 'Before', '0', 'After', 'setpoint', 'SampleTime', '0');
    B('simulink/Math Operations/Sum', 'Error', [110 100 130 120], 'Inputs', '|+-', 'IconShape', 'round');
    B('simulink/Discrete/Discrete PID Controller', 'Controller', [170 90 250 130], ...
      'Controller', 'PID', 'Form', 'Parallel', 'P', 'Kp', 'I', 'Ki', 'D', 'Kd', 'N', '1/Tf', ...
      'UseFilter', 'on', 'SampleTime', 'Ts', 'IntegratorMethod', 'Backward Euler', 'FilterMethod', 'Backward Euler', ...
      'LimitOutput', 'on', 'UpperSaturationLimit', 'uMax', 'LowerSaturationLimit', '-uMax', ...
      'AntiWindupMode', 'clamping');
    B('simulink/Math Operations/Gain', 'Open-loop calibration', [170 160 250 190], 'Gain', 'ffGain');
    B('simulink/Discrete/Zero-Order Hold', 'OL sample', [270 160 300 190], 'SampleTime', 'Ts');
    B('simulink/Discontinuities/Saturation', 'OL limit', [320 160 350 190], 'UpperLimit', 'uMax', 'LowerLimit', '-uMax');
    B('simulink/Sources/Constant', 'closedLoop', [270 120 310 140], 'Value', 'closedLoop');
    B('simulink/Signal Routing/Switch', 'CL or OL', [390 90 420 190], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    B('simulink/Sources/Step', 'Load torque (output, N*m)', [390 240 420 270], 'Time', 'tDist', 'Before', '0', 'After', 'dist', 'SampleTime', '0');
    B('simulink/Ports & Subsystems/Subsystem', 'DC motor', [470 110 570 260]);
    B('simulink/Discontinuities/Quantizer', 'Encoder counts', [620 210 660 240], 'QuantizationInterval', 'qInt');
    B('simulink/Discrete/Zero-Order Hold', 'Sample', [690 210 720 240], 'SampleTime', 'Ts');
    B('simulink/Discrete/Difference', 'Count difference', [750 160 790 190]);
    B('simulink/Math Operations/Gain', 'to rpm', [810 160 860 190], 'Gain', '1/(6*Ts)');
    B('simulink/Sources/Constant', 'loopSel', [810 90 850 110], 'Value', 'loopSel');
    B('simulink/Signal Routing/Multiport Switch', 'Measured', [890 90 920 250], 'Inputs', '2');
    B('simulink/Sinks/Out1', 'y_true_speed_rpm', [640 95 670 110]);
    B('simulink/Sinks/Out1', 'y_true_angle_deg', [640 160 670 175], 'Port', '2');
    B('simulink/Sinks/Out1', 'u_volts', [470 40 500 55], 'Port', '3');
    B('simulink/Sinks/Out1', 'current_A', [640 270 670 285], 'Port', '4');
    B('simulink/Sinks/Out1', 'measured', [960 160 990 175], 'Port', '5');

    % ------------------------------------------------------------- motor subsystem
    sub = [mdl '/DC motor'];
    delete_line(sub, 'In1/1', 'Out1/1'); delete_block([sub '/In1']); delete_block([sub '/Out1']);
    S = @(lib, name, pos, varargin) add_block(lib, [sub '/' name], 'Position', pos, varargin{:});
    S('simulink/Sources/In1', 'V', [20 40 50 55]);
    S('simulink/Sources/In1', 'T_load_out', [20 200 50 215], 'Port', '2');
    S('simulink/Math Operations/Sum', 'KVL', [100 35 120 75], 'Inputs', '+--');
    S('simulink/Math Operations/Gain', 'inv L', [150 40 190 70], 'Gain', '1/L');
    S('simulink/Continuous/Integrator', 'i', [220 40 250 70]);
    S('simulink/Math Operations/Gain', 'R', [220 100 250 130], 'Gain', 'R', 'Orientation', 'left');
    S('simulink/Math Operations/Gain', 'Kt', [290 40 330 70], 'Gain', 'Kt');
    S('simulink/Math Operations/Gain', 'reflect load', [100 195 160 225], 'Gain', '1/(N*eta)');
    S('simulink/Math Operations/Sum', 'Torque', [370 35 390 225], 'Inputs', '+--');
    S('simulink/Math Operations/Gain', 'inv J', [420 115 460 145], 'Gain', '1/J');
    S('simulink/Continuous/Integrator', 'w (base, rad per s)', [490 115 520 145]);
    S('simulink/Math Operations/Gain', 'b', [420 170 460 200], 'Gain', 'b', 'Orientation', 'left');
    S('simulink/Math Operations/Gain', 'Ke', [300 140 340 170], 'Gain', 'Ke', 'Orientation', 'left');
    S('simulink/Continuous/Integrator', 'theta (base, rad)', [560 200 590 230]);
    S('simulink/Math Operations/Gain', 'rpm out', [600 115 650 145], 'Gain', '60/(2*pi*N)');
    S('simulink/Math Operations/Gain', 'deg out', [630 200 680 230], 'Gain', '180/(pi*N)');
    S('simulink/Sinks/Out1', 'speed_out_rpm', [700 120 730 135]);
    S('simulink/Sinks/Out1', 'angle_out_deg', [720 205 750 220], 'Port', '2');
    S('simulink/Sinks/Out1', 'i_A', [290 0 320 15], 'Port', '3');
    L = @(a, b) add_line(sub, a, b, 'autorouting', 'smart');
    L('V/1', 'KVL/1'); L('KVL/1', 'inv L/1'); L('inv L/1', 'i/1'); L('i/1', 'Kt/1'); L('i/1', 'R/1'); L('R/1', 'KVL/2');
    L('i/1', 'i_A/1');
    L('Kt/1', 'Torque/1'); L('Torque/1', 'inv J/1'); L('inv J/1', 'w (base, rad per s)/1');
    L('w (base, rad per s)/1', 'b/1'); L('b/1', 'Torque/2'); L('w (base, rad per s)/1', 'Ke/1'); L('Ke/1', 'KVL/3');
    L('T_load_out/1', 'reflect load/1'); L('reflect load/1', 'Torque/3');
    L('w (base, rad per s)/1', 'theta (base, rad)/1'); L('w (base, rad per s)/1', 'rpm out/1'); L('rpm out/1', 'speed_out_rpm/1');
    L('theta (base, rad)/1', 'deg out/1'); L('deg out/1', 'angle_out_deg/1');

    % ------------------------------------------------------------- top-level wiring
    T = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');
    T('Setpoint/1', 'Error/1'); T('Error/1', 'Controller/1');
    T('Controller/1', 'CL or OL/1'); T('closedLoop/1', 'CL or OL/2');
    T('Setpoint/1', 'Open-loop calibration/1'); T('Open-loop calibration/1', 'OL sample/1');
    T('OL sample/1', 'OL limit/1'); T('OL limit/1', 'CL or OL/3');
    T('CL or OL/1', 'DC motor/1'); T('Load torque (output, N*m)/1', 'DC motor/2');
    T('CL or OL/1', 'u_volts/1');
    T('DC motor/1', 'y_true_speed_rpm/1'); T('DC motor/2', 'y_true_angle_deg/1'); T('DC motor/3', 'current_A/1');
    T('DC motor/2', 'Encoder counts/1'); T('Encoder counts/1', 'Sample/1');
    T('Sample/1', 'Count difference/1'); T('Count difference/1', 'to rpm/1');
    T('loopSel/1', 'Measured/1'); T('to rpm/1', 'Measured/2'); T('Sample/1', 'Measured/3');
    T('Measured/1', 'Error/2'); T('Measured/1', 'measured/1');

    note = Simulink.Annotation([mdl '/note']);
    note.Text = ['Rhino DC servo - bare motor, voltage drive (course week 4). ' ...
        'Parameters are ESTIMATED from the RMCS-5032 datasheet (docs/knowledge-base/HARDWARE_REFERENCE.md 1.5). ' ...
        'Set them with run_dc_motor_simulink(cfg); do not edit numbers by hand.'];
    note.Position = [30 390 700 420];

    if ~exist(outDir, 'dir'), mkdir(outDir); end
    save_system(mdl, fullfile(outDir, [mdl '.slx']));
end

function setWorkspace(mdl, c)
    w = dc_motor_simulink_params(c);
    mws = get_param(mdl, 'ModelWorkspace');
    f = fieldnames(w);
    for i = 1:numel(f), assignin(mws, f{i}, w.(f{i})); end
end
