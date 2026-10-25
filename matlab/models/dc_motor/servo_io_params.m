function w = servo_io_params(c, profile, Tend, olProfile, qSpd)
%SERVO_IO_PARAMS  Model-workspace variables of the Arduino side (simulink_servo_io).
%
%   w = servo_io_params(c, profile, Tend, olProfile, qSpd)
%
%   c: loop, ctrl, Kp Ki Kd Tf Ts uMax latency, quant, spdFb (as servolab.motor.defaultConfig).
%   profile: [t, setpoint]; olProfile: [t, command] played in open loop; qSpd: the drive
%   speed register's step in output rpm (0: none).
    tiny = 1e-9;                                     % "no quantisation" for the Quantizer blocks
    if ~isfield(c, 'spdFb'), c.spdFb = 'drive'; end
    w.dt = 1e-3; w.Tend = Tend;
    w.spProfile = profile; w.olProfile = olProfile;
    w.Ts = c.Ts; w.nLat = round(c.latency / w.dt); w.uMax = c.uMax;
    w.Kp = c.Kp; w.Ki = c.Ki; w.Kd = c.Kd; w.Tf = c.Tf;
    if strcmp(c.ctrl, 'P'), w.Ki = 0; w.Kd = 0; end
    if strcmp(c.ctrl, 'I'), w.Kp = 0; w.Kd = 0; end
    if strcmp(c.ctrl, 'PI'), w.Kd = 0; end
    w.closedLoop = double(~strcmp(c.ctrl, 'OL'));
    w.KiOn = double(w.Ki ~= 0);
    w.aw = 1; if isfield(c, 'antiWindup') && ~c.antiWindup, w.aw = 0; end   % 0: plain integrator
    if c.quant && qSpd > 0, w.qSpd = qSpd; else, w.qSpd = tiny; end
    if c.quant, w.qCnt = 1; else, w.qCnt = tiny; end
    if strcmp(c.loop, 'position'), w.measSel = 3;
    elseif strcmp(c.spdFb, 'encoder'), w.measSel = 2;
    else, w.measSel = 1; end
end
