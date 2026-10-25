function R = runSimulink(c, m)
%RUNSIMULINK  Run a config in the Simulink model of its plant.
%
%   R = servolab.motor.runSimulink(c)       % c from specConfig, or the app's panel
%   R = servolab.motor.runSimulink(c, m)    % m: identified model (default rigModel)
%
%   c.plantKey 'rigId'   -> servo_identified.slx     (run_motor_identified_simulink)
%              'rigPhys' -> servo_drive_physics.slx  (run_drive_physics_simulink)
%              'arm'     -> servo_armature.slx       (run_dc_motor_simulink)
%   R.model, and at the controller samples R.tk, R.meas, R.u: the same signals as
%   servolab.motor.simulatePlant(c).tk / .meas / .u, so the two can be compared directly.
%   Needs Simulink.
    if nargin < 2, m = servolab.motor.rigModel(); end
    switch c.plantKey
        case 'rigId'
            K = run_motor_identified_simulink(m, c, c.profile, c.Tend);
            R = struct('model', 'servo_identified', 'tk', K.tk, 'meas', K.measK, 'u', K.uK, 'raw', K);
        case 'rigPhys'
            K = run_drive_physics_simulink(c, c.profile, c.Tend);
            R = struct('model', 'servo_drive_physics', 'tk', K.tk, 'meas', K.measK, 'u', K.uK, 'raw', K);
        case 'arm'
            ca = c; ca.setpoint = c.profile(end, 2);           % the armature model plays one step
            ca.tStep = c.profile(min(2, end), 1) * (size(c.profile, 1) > 1);
            K = run_dc_motor_simulink(ca);
            R = struct('model', 'servo_armature', 'tk', K.tk, 'meas', K.measK, 'u', K.uK, 'raw', K);
        otherwise
            error('servolab:motor:plant', 'unknown plant ''%s''', c.plantKey);
    end
end
