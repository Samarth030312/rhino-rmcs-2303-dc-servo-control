function c = specConfig(spec, physicsSpec)
%SPECCONFIG  A complete simulation config from a preset spec, as the app builds it.
%
%   c = servolab.motor.specConfig(spec)               % spec from servolab.motor.presets
%   c = servolab.motor.specConfig(spec, physicsSpec)  % other datasheet values (servolab.motor.physics)
%
%   c.plantKey is the spec's plant: 'rigId' (identified rig), 'rigPhys' (rig from datasheet
%   physics) or 'arm' (bare motor, voltage). Run c with servolab.motor.simulatePlant (MATLAB)
%   or servolab.motor.runSimulink (Simulink).
    if nargin < 2, physicsSpec = struct(); end
    isSpd = strcmp(spec.loop, 'speed');
    isArm = strcmp(spec.plant, 'arm');
    if isArm, base = 'bare'; else, base = 'rig'; end
    c = servolab.motor.defaultConfig(base, spec.loop);
    c.plantKey = spec.plant;
    c.ctrl = spec.ctrl; c.Kp = spec.Kp; c.Ki = spec.Ki;
    c.Kd = 0; if strcmp(c.ctrl, 'PID'), c.Kd = spec.Kd; end
    physicsSpec.J_factor = spec.Jf;
    [c.P, c.PD] = servolab.motor.physics(physicsSpec);
    if isArm, c.uMax = c.P.V_supply; end                   % the battery is the voltage limit
    if ~isnan(spec.uMax), c.uMax = spec.uMax; end
    c.spdFb = 'drive'; if isSpd && (isArm || strcmp(spec.spdFb, 'encoder')), c.spdFb = 'encoder'; end
    c.dist = spec.dist; c.tDist = spec.tDist;
    c.profile = spec.profile; c.Tend = spec.Tend; c.tStep = 0;
    c.setpoint = spec.profile(1, 2);
    c.antiWindup = true;
    c.experiment = spec.experiment; c.preset = spec.name;
end
