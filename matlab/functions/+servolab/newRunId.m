function id = newRunId(prefix, exists)
%NEWRUNID  <prefix>-<yyyyMMdd-HHmmss>, plus -2, -3 ... if that ID is taken.
%   EXISTS is a function handle: exists(id) is true when the ID is in use.
%   Run IDs are never reused (docs/EXPERIMENT_RECORDING_PROTOCOL.md section 7).
    base = sprintf('%s-%s', prefix, char(datetime('now', 'Format', 'yyyyMMdd-HHmmss')));
    id = base; k = 1;
    while exists(id)
        k = k + 1; id = sprintf('%s-%d', base, k);
    end
end
