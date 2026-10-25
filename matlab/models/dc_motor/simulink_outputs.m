function v = simulink_outputs(yout)
%SIMULINK_OUTPUTS  The logged outports of a run, by outport block name.
%   v = simulink_outputs(out.yout)      v.<outport name> is a timeseries
    v = struct();
    for k = 1:yout.numElements
        e = yout.getElement(k);
        [~, name] = fileparts(e.BlockPath.getBlock(1));
        v.(matlab.lang.makeValidName(name)) = e.Values;
    end
end
