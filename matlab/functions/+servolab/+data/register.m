function T = register()
%REGISTER  The run register: one row per rig run of any apparatus (data/RUN_REGISTER.csv).
%
%   T = servolab.data.register()
%
%   Columns: run_id, apparatus, run_no, created, rig, mission, experiment, run_in_series,
%   controller, settings, result, rows, firmware, port, os, legacy_id, raw_file, meta_file.
%   An empty table with these columns when the file does not exist yet.
    f = fullfile(servolab.data.root(), 'data', 'RUN_REGISTER.csv');
    cols = servolab.data.registerColumns();
    if ~isfile(f)
        T = cell2table(cell(0, numel(cols)), 'VariableNames', cols); return;
    end
    o = detectImportOptions(f, 'TextType', 'char', 'Delimiter', ',');
    o = setvartype(o, cols, 'char'); o = setvartype(o, {'run_no', 'run_in_series', 'rows'}, 'double');
    T = readtable(f, o);
end
