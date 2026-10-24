function c = registerColumns()
%REGISTERCOLUMNS  Column order of data/RUN_REGISTER.csv.
    c = {'run_id', 'apparatus', 'run_no', 'created', 'rig', 'mission', 'experiment', 'run_in_series', ...
         'controller', 'settings', 'result', 'rows', 'firmware', 'port', 'os', 'legacy_id', 'raw_file', 'meta_file'};
end
