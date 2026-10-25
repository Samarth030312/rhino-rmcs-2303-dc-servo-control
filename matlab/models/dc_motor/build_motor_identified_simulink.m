function mdl = build_motor_identified_simulink(outDir)
%BUILD_MOTOR_IDENTIFIED_SIMULINK  Generate servo_identified.slx (course MOTOR S3-7 / S3-8).
%
%   mdl = build_motor_identified_simulink()       % writes matlab/models/dc_motor/
%
%   The lab rig as an IDENTIFIED model (from measured step responses), with the
%   Arduino's sampled loop around it. Same structure and numbers as the MATLAB
%   reference servolab.motor.identifiedSim; test_simulink_identified checks they agree.
%
%     setpoint profile -> (+)-> Discrete PID (Ts, +/-uMax, clamping) --[CL/OL]--> Modbus latency
%                         ^-                                                         |
%     measured <- [drive speed | encoder speed | encoder angle] <- quantise <- Ts    v
%                                                                         dead zone -> rate limit
%     angle (motor side) <- integrate <- speed <- dead time theta <- K/(tau s + 1) <-+
%     angle (output)     <- backlash  <-+
%
%   Parameters live in the model workspace; run_motor_identified_simulink(m, c, profile, Tend)
%   sets them. Fixed-step solver (dt = 1 ms) so the discrete blocks line up with the MATLAB loop.

    if nargin < 1, outDir = fileparts(mfilename('fullpath')); end
    mdl = 'servo_identified';
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    new_system(mdl);
    cleanup = onCleanup(@() close_system(mdl, 0));
    set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode1', 'FixedStep', 'dt', 'StopTime', 'Tend', ...
              'SaveOutput', 'on', 'SaveFormat', 'Dataset', 'SaveTime', 'on');
    % parameters first: a block's expression (R, J, ...) must never resolve to a variable of the same name in the base workspace
    m = struct('K', 1, 'tau', 0.1, 'theta', 0, 'acc', 50, 'dz', 0, 'qSpd', 4.615, 'backlash', 0, 'sensorAtLoad', false);
    c = servolab.motor.defaultConfig('rig', 'speed');
    w = motor_identified_simulink_params(m, c, [0 c.setpoint], 5);
    mws = get_param(mdl, 'ModelWorkspace');
    f = fieldnames(w);
    for i = 1:numel(f), assignin(mws, f{i}, w.(f{i})); end

    B = @(lib, name, pos, varargin) add_block(lib, [mdl '/' name], 'Position', pos, varargin{:});
    % ------------------------------------------------------------ Arduino (sampled)
    B('simulink/Sources/From Workspace', 'Setpoint profile', [20 95 90 125], 'VariableName', 'spProfile', ...
      'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value', 'SampleTime', 'Ts');
    B('simulink/Math Operations/Sum', 'Error', [130 100 150 120], 'Inputs', '|+-', 'IconShape', 'round');
    B('simulink/Discrete/Discrete PID Controller', 'Arduino PID', [190 90 270 130], ...
      'Controller', 'PID', 'Form', 'Parallel', 'P', 'Kp', 'I', 'Ki', 'D', 'Kd', 'N', '1/Tf', ...
      'UseFilter', 'on', 'SampleTime', 'Ts', 'IntegratorMethod', 'Backward Euler', 'FilterMethod', 'Backward Euler', ...
      'LimitOutput', 'on', 'UpperSaturationLimit', 'uMax', 'LowerSaturationLimit', '-uMax', ...
      'AntiWindupMode', 'clamping');
    B('simulink/Discontinuities/Saturation', 'OL limit', [190 160 230 190], 'UpperLimit', 'uMax', 'LowerLimit', '-uMax');
    B('simulink/Sources/Constant', 'closedLoop', [290 125 330 145], 'Value', 'closedLoop');
    B('simulink/Signal Routing/Switch', 'CL or OL', [360 90 390 190], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    B('simulink/Continuous/Transport Delay', 'Modbus latency', [420 125 470 155], 'DelayTime', 'latency');

    % ------------------------------------------------------------ identified plant
    B('simulink/Discontinuities/Dead Zone', 'Dead zone', [500 125 540 155], 'LowerValue', '-dz', 'UpperValue', 'dz');
    B('simulink/Discontinuities/Rate Limiter', 'Drive acceleration limit', [570 125 620 155], ...
      'RisingSlewLimit', 'acc', 'FallingSlewLimit', '-acc');
    B('simulink/Discrete/Discrete Transfer Fcn', 'K over tau s + 1', [650 120 730 160], ...
      'Numerator', '[(1-aTF)*K]', 'Denominator', '[1 -aTF]', 'SampleTime', 'dt');
    B('simulink/Continuous/Transport Delay', 'Dead time theta', [760 125 810 155], 'DelayTime', 'theta');
    B('simulink/Math Operations/Gain', 'rpm to deg per s', [840 200 880 230], 'Gain', '6');
    B('simulink/Continuous/Integrator', 'Motor-side angle', [900 200 930 230]);
    B('simulink/Discontinuities/Backlash', 'Gearbox backlash', [960 260 1000 290], 'BacklashWidth', 'blWidth');

    % ------------------------------------------------------------ measurement (sampled)
    B('simulink/Discontinuities/Quantizer', 'Drive speed register', [860 60 900 90], 'QuantizationInterval', 'qSpd');
    B('simulink/Discrete/Zero-Order Hold', 'Read speed', [920 60 950 90], 'SampleTime', 'Ts');
    B('simulink/Sources/Constant', 'sensorAtLoad', [960 200 1000 220], 'Value', 'sensorAtLoad');
    B('simulink/Signal Routing/Switch', 'Encoder location', [1030 200 1060 300], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    B('simulink/Math Operations/Gain', 'deg to counts', [1090 235 1130 265], 'Gain', '5200/360');
    B('simulink/Discontinuities/Quantizer', 'Encoder counts', [1150 235 1190 265], 'QuantizationInterval', 'qCnt');
    B('simulink/Discrete/Zero-Order Hold', 'Read counts', [1210 235 1240 265], 'SampleTime', 'Ts');
    B('simulink/Discrete/Difference', 'Counts per sample', [1270 170 1310 200]);
    B('simulink/Math Operations/Gain', 'counts per Ts to rpm', [1330 170 1380 200], 'Gain', '60/(5200*Ts)');
    B('simulink/Math Operations/Gain', 'counts to deg', [1330 235 1380 265], 'Gain', '360/5200');
    B('simulink/Sources/Constant', 'measSel', [1330 20 1370 40], 'Value', 'measSel');
    B('simulink/Signal Routing/Multiport Switch', 'Measured', [1420 20 1450 280], 'Inputs', '3');

    B('simulink/Sinks/Out1', 'measured', [1490 145 1520 160]);
    B('simulink/Sinks/Out1', 'u_cmd_rpm', [420 40 450 55], 'Port', '2');
    B('simulink/Sinks/Out1', 'speed_rpm', [860 135 890 150], 'Port', '3');
    B('simulink/Sinks/Out1', 'angle_motor_side_deg', [960 330 990 345], 'Port', '4');
    B('simulink/Sinks/Out1', 'angle_output_deg', [1030 330 1060 345], 'Port', '5');

    T = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');
    T('Setpoint profile/1', 'Error/1'); T('Error/1', 'Arduino PID/1');
    T('Arduino PID/1', 'CL or OL/1'); T('closedLoop/1', 'CL or OL/2');
    T('Setpoint profile/1', 'OL limit/1'); T('OL limit/1', 'CL or OL/3');
    T('CL or OL/1', 'u_cmd_rpm/1'); T('CL or OL/1', 'Modbus latency/1');
    T('Modbus latency/1', 'Dead zone/1'); T('Dead zone/1', 'Drive acceleration limit/1');
    T('Drive acceleration limit/1', 'K over tau s + 1/1'); T('K over tau s + 1/1', 'Dead time theta/1');
    T('Dead time theta/1', 'speed_rpm/1'); T('Dead time theta/1', 'rpm to deg per s/1');
    T('rpm to deg per s/1', 'Motor-side angle/1'); T('Motor-side angle/1', 'Gearbox backlash/1');
    T('Motor-side angle/1', 'angle_motor_side_deg/1'); T('Gearbox backlash/1', 'angle_output_deg/1');
    T('Dead time theta/1', 'Drive speed register/1'); T('Drive speed register/1', 'Read speed/1');
    T('Gearbox backlash/1', 'Encoder location/1'); T('sensorAtLoad/1', 'Encoder location/2');
    T('Motor-side angle/1', 'Encoder location/3');
    T('Encoder location/1', 'deg to counts/1'); T('deg to counts/1', 'Encoder counts/1'); T('Encoder counts/1', 'Read counts/1');
    T('Read counts/1', 'Counts per sample/1'); T('Counts per sample/1', 'counts per Ts to rpm/1');
    T('Read counts/1', 'counts to deg/1');
    T('measSel/1', 'Measured/1'); T('Read speed/1', 'Measured/2');
    T('counts per Ts to rpm/1', 'Measured/3'); T('counts to deg/1', 'Measured/4');
    T('Measured/1', 'Error/2'); T('Measured/1', 'measured/1');

    note = Simulink.Annotation([mdl '/note']);
    note.Text = ['Rhino DC servo - IDENTIFIED model of the lab rig (RMCS-2303 speed mode + RMCS-5032), ' ...
        'parameters fitted to hardware runs of 2026-10-11 (docs/FIRST_PRINCIPLES.md, section 2). ' ...
        'Set parameters with run_motor_identified_simulink(m, c, profile, Tend).'];
    note.Position = [20 400 900 430];

    if ~exist(outDir, 'dir'), mkdir(outDir); end
    save_system(mdl, fullfile(outDir, [mdl '.slx']));
end
