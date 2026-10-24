function c = presetConfig(name)
%PRESETCONFIG  Simulation config for a named preset (see servolab.motor.presets).
    p = servolab.motor.presets();
    k = find(strcmp({p.name}, name), 1);
    assert(~isempty(k), 'servolab:motor:preset', 'no preset named ''%s''', name);
    c = servolab.motor.defaultConfig(p(k).plant, p(k).loop);
    c.experiment = p(k).experiment;
    s = p(k).set;
    for i = 1:2:numel(s), c.(s{i}) = s{i + 1}; end
    if ~ismember('Kp', s(1:2:end)) && ismember(c.ctrl, {'I', 'OL'}), c.Kp = 0; end
    if ~ismember('Ki', s(1:2:end)) && ismember(c.ctrl, {'P', 'OL'}), c.Ki = 0; end
    if ~ismember('Kd', s(1:2:end)) && ~strcmp(c.ctrl, 'PID'), c.Kd = 0; end
end
