function c = defaultConfig(plant, loop)
%DEFAULTCONFIG  A complete, runnable simulation configuration.
%
%   c = servolab.motor.defaultConfig()                     % rig, speed
%   c = servolab.motor.defaultConfig('rig'|'bare', 'speed'|'position')
%
%   plant 'rig'   RMCS-2303 in digital speed mode (Mode 1) + RMCS-5032, with the
%                 Arduino closing an outer loop over Modbus (ED-M1 option B).
%                 Controller output u = speed command, OUTPUT-shaft rpm.
%   plant 'bare'  The same motor driven by armature voltage (course week-4 / CTMS
%                 model; ED-M1 option C). Not the lab hardware. u = volts.
%
%   Setpoint units: output rpm (speed) or output degrees (position).

    if nargin < 1, plant = 'rig'; end
    if nargin < 2, loop = 'speed'; end
    P = servolab.motor.params();

    c.plant = plant;          % 'rig' | 'bare'
    c.loop  = loop;           % 'speed' | 'position'
    c.ctrl  = 'PI';           % 'OL' | 'P' | 'I' | 'PI' | 'PID'
    c.Kd = 0; c.Tf = 0.01;
    c.tStep = 0.2;
    c.Tend  = 5;
    c.dist  = 0;              % load torque step at the OUTPUT shaft, N*m
    c.tDist = 3;
    c.quant = true;
    c.spdFb = 'drive';        % rig speed feedback: 'drive' register 24 | 'encoder' counts over Ts           % encoder counts and integer-rpm feedback
    c.dt    = 1e-3;           % plant integration step
    c.experiment = '';
    c.P = P;

    switch plant
        case 'rig'
            c.uMax = P.w_max_out_rpm;                       % 180 output rpm
            if strcmp(loop, 'speed')
                c.Ts = P.Ts_speed; c.latency = P.lat_speed;
                c.setpoint = 60; c.Kp = 0.3; c.Ki = 1.5;      % tuned for the measured drive ramp
            else
                c.Ts = P.Ts_position; c.latency = P.lat_position;
                c.setpoint = 90;  c.Kp = 0.5; c.Ki = 0.15;
            end
        case 'bare'
            c.uMax = P.V_nom;                               % volts
            c.Ts = 0.01; c.latency = 0;                    % 100 Hz local loop, encoder on the MCU
            if strcmp(loop, 'speed')
                c.setpoint = 100; c.Kp = 0.05; c.Ki = 1.0;
            else
                c.setpoint = 90;  c.Kp = 0.3; c.Ki = 0.5; c.Kd = 0.01;
            end
        otherwise
            error('servolab:motor:config', 'plant must be ''rig'' or ''bare'', got ''%s''', plant);
    end
end
