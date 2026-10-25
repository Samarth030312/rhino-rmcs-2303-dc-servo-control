function simulink_scope(mdl, name, sources, labels, pos)
%SIMULINK_SCOPE  A scope at the top level of MDL that opens when the model runs.
%
%   simulink_scope(mdl, 'Scope: speed', {{'Setpoint profile/1', 'Measured/1'}, {'CL or OL/1'}}, ...
%                  {'setpoint and measured', 'command'}, [x y])
%
%   SOURCES: one cell per axes, each a list of 'block/port' signals drawn together (through a
%   Mux when there are several). LABELS: the axes titles.
    n = numel(sources);
    blk = [mdl '/' name];
    add_block('simulink/Sinks/Scope', blk, 'Position', [pos, pos + [40 30 + 20 * n]]);
    set_param(blk, 'NumInputPorts', num2str(n), 'OpenAtSimulationStart', 'on');
    try, set_param(blk, 'LayoutDimensionsString', sprintf('[%d 1]', n)); catch, end   % one axes per input
    for k = 1:n
        s = sources{k};
        if numel(s) == 1
            add_line(mdl, s{1}, sprintf('%s/%d', name, k), 'autorouting', 'smart');
        else
            mux = sprintf('%s mux %d', name, k);
            add_block('simulink/Signal Routing/Mux', [mdl '/' mux], 'Inputs', num2str(numel(s)), ...
                'Position', [pos(1) - 40, pos(2) + 40 * k, pos(1) - 35, pos(2) + 40 * k + 30]);
            for j = 1:numel(s), add_line(mdl, s{j}, sprintf('%s/%d', mux, j), 'autorouting', 'smart'); end
            add_line(mdl, [mux '/1'], sprintf('%s/%d', name, k), 'autorouting', 'smart');
        end
    end
    try   % axes titles (property names differ between releases; the plot works without them)
        cfg = get_param(blk, 'ScopeConfiguration');
        cfg.AxesScaling = 'Auto';
        for k = 1:n, cfg.ActiveDisplay = k; cfg.Title = labels{k}; cfg.ShowLegend = numel(sources{k}) > 1; end
    catch
    end
end
