function simulink_tidy(sys, groups)
%SIMULINK_TIDY  Group blocks into named subsystems and lay out every level, for reading.
%
%   simulink_tidy('servo_drive_physics', {'RMCS-2303 drive', {'Ramp', 'wr', ...}; ...})
%
%   Each group's blocks (names at the top level of SYS) become one subsystem with that name;
%   the signals between them are unchanged (Simulink.BlockDiagram.createSubsystem). Then SYS,
%   and every subsystem in it, is arranged automatically (Simulink.BlockDiagram.arrangeSystem).
    if nargin < 2, groups = cell(0, 2); end
    for g = 1:size(groups, 1)
        h = cellfun(@(n) get_param([sys '/' n], 'Handle'), groups{g, 2});
        before = find_system(sys, 'SearchDepth', 1, 'BlockType', 'SubSystem');
        Simulink.BlockDiagram.createSubsystem(h);
        made = setdiff(find_system(sys, 'SearchDepth', 1, 'BlockType', 'SubSystem'), before);
        set_param(made{1}, 'Name', groups{g, 1});
        nameOutports([sys '/' groups{g, 1}]);              % while the signal names are still on the lines
    end
    for g = 1:size(groups, 1), nameInports([sys '/' groups{g, 1}]); end
    subs = find_system(sys, 'FollowLinks', 'off', 'LookUnderMasks', 'none', 'BlockType', 'SubSystem');
    subs = subs(strcmp(get_param(subs, 'LinkStatus'), 'none') & strcmp(get_param(subs, 'Mask'), 'off'));   % ours, not library blocks
    for k = numel(subs):-1:1, Simulink.BlockDiagram.arrangeSystem(subs{k}); end
    Simulink.BlockDiagram.arrangeSystem(sys);
end

function nameOutports(sub)
    % an auto-created port is called Out1, ...: name it after the signal on its line (set by the builder)
    L = get_param(sub, 'LineHandles');
    outs = find_system(sub, 'SearchDepth', 1, 'BlockType', 'Outport');
    for k = 1:numel(outs)
        name = lineName(L.Outport(str2double(get_param(outs{k}, 'Port'))));
        if ~isempty(name), rename(outs{k}, name); end
    end
end

function nameInports(sub)
    % an input takes the name of what feeds it: the source subsystem's output port, a named
    % signal, or the source block
    pc = get_param(sub, 'PortConnectivity'); L = get_param(sub, 'LineHandles');
    ins = find_system(sub, 'SearchDepth', 1, 'BlockType', 'Inport');
    for k = 1:numel(ins)
        n = str2double(get_param(ins{k}, 'Port')); src = pc(n).SrcBlock; name = '';
        if ~isempty(src) && src > 0 && strcmp(get_param(src, 'BlockType'), 'SubSystem')
            o = find_system(getfullname(src), 'SearchDepth', 1, 'BlockType', 'Outport', 'Port', num2str(pc(n).SrcPort + 1));
            if ~isempty(o), name = get_param(o{1}, 'Name'); end
        end
        if isempty(name), name = lineName(L.Inport(n)); end
        if isempty(name) && ~isempty(src) && src > 0, name = get_param(src, 'Name'); end
        if ~isempty(name), rename(ins{k}, name); end
    end
end

function s = lineName(h)
    s = ''; if h > 0, s = get_param(h, 'Name'); end
end

function rename(blk, name)
    name = strrep(name, newline, ' '); base = name; i = 1;
    parent = get_param(blk, 'Parent');
    if strcmp(get_param(blk, 'Name'), name), return; end
    while ~isempty(find_system(parent, 'SearchDepth', 1, 'Name', name)) && ~strcmp([parent '/' name], blk)
        i = i + 1; name = sprintf('%s %d', base, i);
    end
    set_param(blk, 'Name', name);
end
