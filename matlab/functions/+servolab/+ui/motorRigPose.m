function motorRigPose(rig, angleDeg, speedRpm, opts)
%MOTORRIGPOSE  Pose an servolab.ui.motorRig model.
%
%   servolab.ui.motorRigPose(rig, angleDeg, speedRpm)
%   servolab.ui.motorRigPose(rig, angleDeg, speedRpm, 'Setpoint', 60, 'RefAngle', 90, 'TrailDeg', 25)
%
%   angleDeg   output-shaft angle (deg, + = counter-clockwise seen from the shaft end)
%   speedRpm   output speed (rpm): the speed ring shows |speed| / 180 rpm
%   Setpoint   speed setpoint (rpm): white tick on the ring (NaN hides it)
%   RefAngle   position setpoint (deg): dashed radius on the disc (NaN hides it)
%   TrailDeg   the angle turned over the last ~80 ms, drawn as a translucent wedge
    arguments
        rig struct
        angleDeg (1,1) double
        speedRpm (1,1) double
        opts.Setpoint (1,1) double = NaN
        opts.RefAngle (1,1) double = NaN
        opts.TrailDeg (1,1) double = 0
    end
    if ~isvalid(rig.disc), return; end
    zA = rig.zA; full = 180;
    rig.disc.Matrix = makehgtform('translate', [0 0 zA]) * makehgtform('xrotate', deg2rad(angleDeg));
    % trail wedge on the disc face, from (angle - trail) to angle
    if abs(opts.TrailDeg) > 0.5
        a = linspace(angleDeg - opts.TrailDeg, angleDeg, 20) + 90;
        r = rig.R - 0.004;
        set(rig.trail, 'XData', [rig.xFace, rig.xFace * ones(1, 20)] + 0.0002, ...
            'YData', [0, r * cosd(a)], 'ZData', zA + [0, r * sind(a)]);
    else
        set(rig.trail, 'XData', nan, 'YData', nan, 'ZData', nan);
    end
    % speed ring, starting at the top, turning the same way as the disc (+ = counter-clockwise)
    f = min(abs(speedRpm) / full, 1);
    if f > 0.002
        a = 90 + sign(speedRpm) * linspace(0, 360 * f, max(2, round(120 * f)));
        set(rig.ring, 'XData', rig.xRing * ones(size(a)), 'YData', rig.Rr * cosd(a), 'ZData', zA + rig.Rr * sind(a));
    else
        set(rig.ring, 'XData', nan, 'YData', nan, 'ZData', nan);
    end
    if isfinite(opts.Setpoint) && abs(opts.Setpoint) > 0
        a = 90 + sign(opts.Setpoint) * 360 * min(abs(opts.Setpoint) / full, 1);
        rr = rig.Rr + [-0.005 0.005];
        set(rig.ringSp, 'XData', rig.xRing * [1 1], 'YData', rr * cosd(a), 'ZData', zA + rr * sind(a));
    else
        set(rig.ringSp, 'XData', nan, 'YData', nan, 'ZData', nan);
    end
    if isfinite(opts.RefAngle)
        a = opts.RefAngle + 90;
        set(rig.ref, 'XData', rig.xFace * [1 1] + 0.0004, 'YData', [0 rig.R * cosd(a)], 'ZData', zA + [0 rig.R * sind(a)]);
    else
        set(rig.ref, 'XData', nan, 'YData', nan, 'ZData', nan);
    end
end
