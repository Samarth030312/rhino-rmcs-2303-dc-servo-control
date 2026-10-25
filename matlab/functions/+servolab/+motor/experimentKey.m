function key = experimentKey(name)
%EXPERIMENTKEY  The stable key of a hardware experiment, from its current or an earlier name.
%
%   key = servolab.motor.experimentKey('Static map: steady speed against command, both directions')
%   key = servolab.motor.experimentKey('Course S3-3: static map, speed vs command (fwd + rev)')
%       -> 'static_map'  (both)
%
%   Recorded runs keep the name the app had when they ran; this maps all of them to one key
%   (servolab.motor.hwExperiments). Unknown names give ''. NAME may be a cellstr.
    persistent map
    if isempty(map)
        map = containers.Map();
        E = servolab.motor.hwExperiments();
        for k = 1:numel(E)
            map(E(k).name) = E(k).key;
            for a = E(k).aliases, map(a{1}) = E(k).key; end
        end
    end
    if iscell(name), key = cellfun(@one, name, 'UniformOutput', false); else, key = one(name); end
    function k = one(n)
        if isKey(map, n), k = map(n); else, k = ''; end
    end
end
