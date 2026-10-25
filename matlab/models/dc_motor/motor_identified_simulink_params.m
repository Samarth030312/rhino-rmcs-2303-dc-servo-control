function w = motor_identified_simulink_params(m, c, profile, Tend)
%MOTOR_IDENTIFIED_SIMULINK_PARAMS  Model-workspace variables for servo_identified.slx.
%   Same meaning as servolab.motor.identifiedSim(m, c, profile, Tend).
    def = struct('K', 1, 'tau', 0.3, 'theta', 0, 'acc', Inf, 'dz', 0, 'qSpd', 0, 'backlash', 0, 'sensorAtLoad', false);
    for f = fieldnames(def)', if ~isfield(m, f{1}), m.(f{1}) = def.(f{1}); end, end
    if ~isfield(c, 'spdFb'), c.spdFb = 'drive'; end
    tiny = 1e-9;
    w = servo_io_params(c, profile, Tend, profile, m.qSpd);   % open loop: the command is the setpoint
    w.K = m.K; w.aTF = exp(-w.dt / m.tau); w.nTheta = round(m.theta / w.dt);   % dead time in plant steps (the transfer function already delays one)
    w.acc = min(m.acc, 1e9); w.dz = m.dz;
    w.blWidth = max(m.backlash, tiny); w.sensorAtLoad = double(m.sensorAtLoad);
end
