function w = motor_identified_simulink_params(m, c, profile, Tend)
%MOTOR_IDENTIFIED_SIMULINK_PARAMS  Model-workspace variables for servo_identified.slx.
%   Same meaning as servolab.motor.identifiedSim(m, c, profile, Tend).
    def = struct('K', 1, 'tau', 0.3, 'theta', 0, 'acc', Inf, 'dz', 0, 'qSpd', 0, 'backlash', 0, 'sensorAtLoad', false);
    for f = fieldnames(def)', if ~isfield(m, f{1}), m.(f{1}) = def.(f{1}); end, end
    if ~isfield(c, 'spdFb'), c.spdFb = 'drive'; end
    tiny = 1e-9;                                     % "no quantisation" for the Quantizer blocks
    w.dt = 1e-3; w.Tend = Tend;
    w.spProfile = profile;
    w.Ts = c.Ts; w.latency = c.latency; w.uMax = c.uMax;
    w.Kp = c.Kp; w.Ki = c.Ki; w.Kd = c.Kd; w.Tf = c.Tf;
    if strcmp(c.ctrl, 'P'), w.Ki = 0; w.Kd = 0; end
    if strcmp(c.ctrl, 'I'), w.Kp = 0; w.Kd = 0; end
    if strcmp(c.ctrl, 'PI'), w.Kd = 0; end
    w.closedLoop = double(~strcmp(c.ctrl, 'OL'));
    w.K = m.K; w.aTF = exp(-w.dt / m.tau); w.theta = max(m.theta, w.dt);   % >= 1 step: no algebraic loop
    w.acc = min(m.acc, 1e9); w.dz = m.dz;
    w.blWidth = max(m.backlash, tiny); w.sensorAtLoad = double(m.sensorAtLoad);
    if c.quant && m.qSpd > 0, w.qSpd = m.qSpd; else, w.qSpd = tiny; end
    if c.quant, w.qCnt = 1; else, w.qCnt = tiny; end
    if strcmp(c.loop, 'position'), w.measSel = 3;
    elseif strcmp(c.spdFb, 'encoder'), w.measSel = 2;
    else, w.measSel = 1; end
end
