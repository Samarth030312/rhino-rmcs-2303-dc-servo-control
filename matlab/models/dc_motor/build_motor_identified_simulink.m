function mdl = build_motor_identified_simulink(outDir)
%BUILD_MOTOR_IDENTIFIED_SIMULINK  Generate servo_identified.slx: the rig as identified from its runs.
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
    % ------------------------------------------------------------ identified plant
    B('simulink/Discontinuities/Dead Zone', 'Dead zone', [500 125 540 155], 'LowerValue', '-dz', 'UpperValue', 'dz');
    B('simulink/Discontinuities/Rate Limiter', 'Drive acceleration limit', [570 125 620 155], ...
      'RisingSlewLimit', 'acc', 'FallingSlewLimit', '-acc');
    B('simulink/Discrete/Discrete Transfer Fcn', 'K over tau s + 1', [650 120 730 160], ...
      'Numerator', '[(1-aTF)*K]', 'Denominator', '[1 -aTF]', 'SampleTime', 'dt');
    B('simulink/Discrete/Delay', 'Dead time theta', [760 125 810 155], 'DelayLength', 'nTheta', 'SampleTime', 'dt');
    B('simulink/Math Operations/Gain', 'rpm to deg per s', [840 200 880 230], 'Gain', '6');
    % backward Euler, as identifiedSim: angle(k) = angle(k-1) + dt * 6 * speed(k)
    B('simulink/Discrete/Discrete-Time Integrator', 'Motor-side angle', [900 200 930 230], ...
      'IntegratorMethod', 'Integration: Backward Euler', 'SampleTime', 'dt');
    B('simulink/Discontinuities/Backlash', 'Gearbox backlash', [960 260 1000 290], 'BacklashWidth', 'blWidth');
    B('simulink/Sources/Constant', 'sensorAtLoad', [960 200 1000 220], 'Value', 'sensorAtLoad');
    B('simulink/Signal Routing/Switch', 'Encoder location', [1030 200 1060 300], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    B('simulink/Sinks/Out1', 'speed_rpm', [860 135 890 150], 'Port', '3');
    B('simulink/Sinks/Out1', 'angle_motor_side_deg', [960 330 990 345], 'Port', '4');
    B('simulink/Sinks/Out1', 'angle_output_deg', [1030 330 1060 345], 'Port', '5');

    T = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');
    T('Dead zone/1', 'Drive acceleration limit/1');
    T('Drive acceleration limit/1', 'K over tau s + 1/1'); T('K over tau s + 1/1', 'Dead time theta/1');
    T('Dead time theta/1', 'speed_rpm/1'); T('Dead time theta/1', 'rpm to deg per s/1');
    T('rpm to deg per s/1', 'Motor-side angle/1'); T('Motor-side angle/1', 'Gearbox backlash/1');
    T('Motor-side angle/1', 'angle_motor_side_deg/1'); T('Gearbox backlash/1', 'angle_output_deg/1');
    T('Gearbox backlash/1', 'Encoder location/1'); T('sensorAtLoad/1', 'Encoder location/2');
    T('Motor-side angle/1', 'Encoder location/3');
    % the Arduino and its sensors, shared with servo_drive_physics
    simulink_name_signal([mdl '/Motor-side angle'], 1, 'motor-side angle (deg)');
    simulink_name_signal([mdl '/Gearbox backlash'], 1, 'output angle (deg)');
    io = simulink_servo_io(mdl, 'Dead zone/1', 'Dead time theta/1', 'Encoder location/1');
    simulink_tidy(mdl, [io; {'Drive + motor, identified from the rig', {'Dead zone', 'Drive acceleration limit', ...
        'K over tau s + 1', 'Dead time theta', 'rpm to deg per s', 'Motor-side angle', 'Gearbox backlash', ...
        'sensorAtLoad', 'Encoder location'}}]);

    outs = {'measured', 'u_cmd_rpm', 'speed_rpm', 'angle_motor_side_deg', 'angle_output_deg'};               % outport order, as run_* read them
    for k = 1:numel(outs), set_param([mdl '/' outs{k}], 'Port', num2str(k)); end

    note = Simulink.Annotation([mdl '/note']);
    note.Text = ['Rhino DC servo - IDENTIFIED model of the lab rig (RMCS-2303 speed mode + RMCS-5032), ' ...
        'parameters fitted to hardware runs of 2026-10-11 (docs/FIRST_PRINCIPLES.md, section 2). ' ...
        'Set parameters with run_motor_identified_simulink(m, c, profile, Tend).'];
    note.Position = simulink_note_position(mdl, 900);

    if ~exist(outDir, 'dir'), mkdir(outDir); end
    simulink_save(mdl, fullfile(outDir, [mdl '.slx']));
end
