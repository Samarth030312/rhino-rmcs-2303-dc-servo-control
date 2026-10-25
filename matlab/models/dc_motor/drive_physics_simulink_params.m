function w = drive_physics_simulink_params(c, profile, Tend)
%DRIVE_PHYSICS_SIMULINK_PARAMS  Model-workspace variables for servo_drive_physics.slx.
%   Same meaning as servolab.motor.simulate(c) with c.plant 'rig' and c.profile = profile.
    P = c.P; N = P.N;
    w = servo_io_params(c, profile, Tend, olCommand(c, profile), P.spd_fb_step_base_rpm / N);
    w.N = N; w.kU = N * P.rpm;
    w.wMax = P.spd_max_base_rpm * P.rpm;
    w.accDt = P.acc_base_rpm_s * P.rpm * w.dt;
    w.Kpd = P.J * P.wc_drive / P.Kt; w.KidDt = w.Kpd * P.wc_drive / 4 * w.dt;
    w.Ke = P.Ke; w.Kt = P.Kt; w.R = P.R; w.b = P.b; w.Vs = P.V_supply; w.Ilim = P.I_lim_drive;
    w.Jt = P.J + P.J_load_out / N^2;
    w.TLbase = c.dist / (N * P.eta); w.tDist = c.tDist;
end

function ol = olCommand(c, profile)
    % open loop as in servolab.motor.simulate: speed plays the setpoint; position runs at half
    % the command limit for the time the move should take
    if strcmp(c.loop, 'speed'), ol = profile; return; end
    vOL = 0.5 * c.uMax; sp = profile(end, 2); t0 = profile(find(profile(:, 2) ~= 0, 1), 1);
    if isempty(t0) || sp == 0, ol = [0 0]; return; end
    ol = [0 0; t0 sign(sp) * vOL; t0 + abs(sp) / (6 * vOL) 0];
    if t0 == 0, ol(1, :) = []; end
end
