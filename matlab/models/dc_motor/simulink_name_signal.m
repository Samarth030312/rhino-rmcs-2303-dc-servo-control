function simulink_name_signal(blk, port, name)
%SIMULINK_NAME_SIGNAL  Name the signal leaving output PORT of block BLK (shown on the line and
%   used by simulink_tidy for the ports of the subsystems it crosses).
    ph = get_param(blk, 'PortHandles');
    set_param(get_param(ph.Outport(port), 'Line'), 'Name', name);
end
