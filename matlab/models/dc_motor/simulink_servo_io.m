function groups = simulink_servo_io(mdl, plantIn, speedOut, angleOut)
%SIMULINK_SERVO_IO  The Arduino's side of a rig model: sampled controller and sensors.
%
%   simulink_servo_io(mdl, plantIn, speedOut, angleOut)
%
%   Adds to model MDL the blocks that are the same for every model of the rig
%   (servo_identified, servo_drive_physics), and wires them to the plant:
%
%     setpoint profile -> (+)-> Arduino PID (the firmware's law, Ts, +/-uMax) --[CL | OL]--> Modbus latency -> PLANTIN
%                         ^-                     OL command profile -> limit -^
%     measured <- [drive speed register | encoder speed | encoder angle] <- sampled every Ts
%                         ^ SPEEDOUT (output rpm)        ^ ANGLEOUT (output deg, at the encoder)
%
%   GROUPS: the block names of the Arduino and of its sensors, for simulink_tidy.
%   Outports 1 measured, 2 u_cmd_rpm. Variables (model workspace, servo_io_params): Ts, Kp, Ki,
%   Kd, Tf, uMax, aw, KiOn, nLat (latency in plant steps), closedLoop, spProfile, olProfile, qSpd, qCnt, measSel.

    B = @(lib, name, pos, varargin) add_block(lib, [mdl '/' name], 'Position', pos, varargin{:});
    % ------------------------------------------------------------ Arduino (sampled)
    B('simulink/Sources/From Workspace', 'Setpoint profile', [20 95 90 125], 'VariableName', 'spProfile', ...
      'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value', 'SampleTime', 'Ts');
    B('simulink/Math Operations/Sum', 'Error', [130 100 150 120], 'Inputs', '|+-', 'IconShape', 'round');
    simulink_arduino_pid([mdl '/Arduino PID']);          % the firmware's law, not Simulink's PID block
    B('simulink/Sources/From Workspace', 'Open-loop command', [20 160 90 190], 'VariableName', 'olProfile', ...
      'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value', 'SampleTime', 'Ts');
    B('simulink/Discontinuities/Saturation', 'OL limit', [190 160 230 190], 'UpperLimit', 'uMax', 'LowerLimit', '-uMax');
    B('simulink/Sources/Constant', 'closedLoop', [290 125 330 145], 'Value', 'closedLoop');
    B('simulink/Signal Routing/Switch', 'CL or OL', [360 90 390 190], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    % the command takes effect nLat plant steps after its sample, exactly as in the MATLAB loop
    B('simulink/Discrete/Delay', 'Modbus latency', [420 125 470 155], 'DelayLength', 'nLat', 'SampleTime', 'dt');

    % ------------------------------------------------------------ sensors (sampled)
    B('simulink/Discontinuities/Quantizer', 'Drive speed register', [1100 60 1140 90], 'QuantizationInterval', 'qSpd');
    B('simulink/Discrete/Zero-Order Hold', 'Read speed', [1160 60 1190 90], 'SampleTime', 'Ts');
    B('simulink/Math Operations/Gain', 'deg to counts', [1100 235 1140 265], 'Gain', '5200/360');
    B('simulink/Discontinuities/Quantizer', 'Encoder counts', [1160 235 1200 265], 'QuantizationInterval', 'qCnt');
    B('simulink/Discrete/Zero-Order Hold', 'Read counts', [1220 235 1250 265], 'SampleTime', 'Ts');
    B('simulink/Discrete/Difference', 'Counts per sample', [1280 170 1320 200]);
    B('simulink/Math Operations/Gain', 'counts per Ts to rpm', [1340 170 1390 200], 'Gain', '60/(5200*Ts)');
    B('simulink/Math Operations/Gain', 'counts to deg', [1340 235 1390 265], 'Gain', '360/5200');
    B('simulink/Sources/Constant', 'measSel', [1340 20 1380 40], 'Value', 'measSel');
    B('simulink/Signal Routing/Multiport Switch', 'Measured', [1430 20 1460 280], 'Inputs', '3');
    B('simulink/Sinks/Out1', 'measured', [1500 145 1530 160]);
    B('simulink/Sinks/Out1', 'u_cmd_rpm', [420 40 450 55], 'Port', '2');

    T = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');
    T('Setpoint profile/1', 'Error/1'); T('Error/1', 'Arduino PID/1');
    T('Arduino PID/1', 'CL or OL/1'); T('closedLoop/1', 'CL or OL/2');
    T('Open-loop command/1', 'OL limit/1'); T('OL limit/1', 'CL or OL/3');
    T('CL or OL/1', 'u_cmd_rpm/1'); T('CL or OL/1', 'Modbus latency/1');
    T('Modbus latency/1', plantIn);
    T(speedOut, 'Drive speed register/1'); T('Drive speed register/1', 'Read speed/1');
    T(angleOut, 'deg to counts/1'); T('deg to counts/1', 'Encoder counts/1'); T('Encoder counts/1', 'Read counts/1');
    T('Read counts/1', 'Counts per sample/1'); T('Counts per sample/1', 'counts per Ts to rpm/1');
    T('Read counts/1', 'counts to deg/1');
    T('measSel/1', 'Measured/1'); T('Read speed/1', 'Measured/2');
    T('counts per Ts to rpm/1', 'Measured/3'); T('counts to deg/1', 'Measured/4');
    T('Measured/1', 'Error/2'); T('Measured/1', 'measured/1');
    simulink_scope(mdl, 'Scope', {{'Setpoint profile/1', 'Measured/1'}, {'CL or OL/1'}}, ...
        {'setpoint and measured (rpm or deg)', 'command (output rpm)'}, [1600 20]);
    simulink_name_signal([mdl '/Setpoint profile'], 1, 'setpoint');
    simulink_name_signal([mdl '/CL or OL'], 1, 'command (output rpm)');
    simulink_name_signal([mdl '/Modbus latency'], 1, 'command at the drive (output rpm)');
    simulink_name_signal([mdl '/Measured'], 1, 'measured');
    simulink_name_signal([mdl '/' fileparts(speedOut)], 1, 'speed (output rpm)');
    simulink_name_signal([mdl '/' fileparts(angleOut)], 1, 'angle at the encoder (deg)');
    groups = {'Arduino (sampled every Ts)', {'Setpoint profile', 'Error', 'Arduino PID', 'Open-loop command', 'OL limit', ...
                                              'closedLoop', 'CL or OL', 'Modbus latency'}; ...
              'Sensors (encoder, speed register)', {'Drive speed register', 'Read speed', 'deg to counts', 'Encoder counts', ...
                                              'Read counts', 'Counts per sample', 'counts per Ts to rpm', 'counts to deg', 'measSel', 'Measured'}};
end
