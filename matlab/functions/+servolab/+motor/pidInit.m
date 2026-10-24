function st = pidInit()
%PIDINIT  Zero state for servolab.motor.pidStep.
    st = struct('i', 0, 'd', 0, 'e', 0, 'first', true);
end
