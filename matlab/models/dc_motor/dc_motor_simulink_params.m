function w = dc_motor_simulink_params(c)
%DC_MOTOR_SIMULINK_PARAMS  Model-workspace variables for servo_armature.slx
%   from an servolab.motor config (plant must be 'bare').
    assert(strcmp(c.plant, 'bare'), 'servolab:simulink:plant', ...
        'servo_armature is the bare motor; the rig models are servo_identified and servo_drive_physics');
    assert(~(strcmp(c.ctrl, 'OL') && strcmp(c.loop, 'position')), 'servolab:simulink:olpos', ...
        'timed open-loop position is not modelled in Simulink');
    P = c.P;
    w = struct('R', P.R, 'L', P.L, 'Ke', P.Ke, 'Kt', P.Kt, 'J', P.J + P.J_load_out / P.N^2, ...
               'b', P.b, 'N', P.N, 'eta', P.eta);
    g = struct('Kp', c.Kp, 'Ki', c.Ki, 'Kd', c.Kd);
    switch c.ctrl
        case 'P',  g.Ki = 0; g.Kd = 0;
        case 'I',  g.Kp = 0; g.Kd = 0;
        case 'PI', g.Kd = 0;
    end
    w.Kp = g.Kp; w.Ki = g.Ki; w.Kd = g.Kd; w.Tf = c.Tf;
    w.Ts = c.Ts; w.uMax = c.uMax;
    w.KiOn = double(w.Ki ~= 0); w.aw = 1;
    w.setpoint = c.setpoint; w.tStep = c.tStep; w.dist = c.dist; w.tDist = c.tDist; w.Tend = c.Tend;
    w.loopSel = 1 + strcmp(c.loop, 'position');
    w.closedLoop = double(~strcmp(c.ctrl, 'OL'));
    Kss = P.Kt / (P.R * P.b + P.Kt * P.Ke) / P.rpm / P.N;           % output rpm per volt
    w.ffGain = 1 / Kss;
    if c.quant, w.qInt = P.deg_per_count; else, w.qInt = 1e-12; end
end
