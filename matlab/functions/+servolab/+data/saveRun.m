function out = saveRun(code, T, cfg, events, info)
%SAVERUN  Save one rig run of any apparatus as evidence, and register it.
%
%   out = servolab.data.saveRun('MOTOR', T, cfg, events, info)
%
%   T       telemetry table (SerialLink.table())
%   cfg     the configuration that was sent (stored as config_sent; a field P is dropped)
%   events  SerialLink.eventLog ({t, kind, text}) for the session so far
%   info    struct: mission (tag), experiment, run (k in a series), port, invalidCount,
%           seqGaps, hello (firmware fields), rig (name), result ('FINISHED' or the stop reason),
%           and anything else worth keeping
%   Writes data/raw/<folder>/<id>.csv (read-only), data/metadata/<folder>/<id>.json, appends
%   data/RUN_REGISTER.csv. Nothing is ever overwritten. out: runId, csv, meta, runNo.
    A = servolab.data.apparatus(code);
    root = servolab.data.root();
    rawDir = fullfile(root, 'data', 'raw', A.folder); metaDir = fullfile(root, 'data', 'metadata', A.folder);
    if ~isfolder(rawDir), mkdir(rawDir); end
    if ~isfolder(metaDir), mkdir(metaDir); end
    mission = getf(info, 'mission', 'LAB');
    [id, n] = servolab.data.newRunId(A.code, mission);
    csv = fullfile(rawDir, [id '.csv']);
    assert(~isfile(csv), 'servolab:data:exists', 'refusing to overwrite %s', csv);
    writetable(T, csv);
    fileattrib(csv, '-w', 'a');

    if isfield(cfg, 'P'), cfg = rmfield(cfg, 'P'); end
    if isfield(cfg, 'PD'), cfg = rmfield(cfg, 'PD'); end
    hello = getf(info, 'hello', {});
    fw = ''; if numel(hello) >= 2, fw = sprintf('%s %s', hello{1}, hello{2}); end
    meta = struct();
    meta.run_id = id; meta.run_no = n; meta.apparatus = A.code; meta.data_class = 'HARDWARE';
    meta.raw_data_file = strrep(fullfile('data', 'raw', A.folder, [id '.csv']), '\', '/');
    meta.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssZ', 'TimeZone', 'local'));
    meta.rig = rigName(A, info, hello);
    meta.mission = mission;
    meta.experiment = getf(info, 'experiment', '');
    meta.run_in_series = getf(info, 'run', 1);
    meta.firmware = fw;
    meta.matlab_version = version();
    meta.os = computer('arch');
    meta.config_sent = cfg;
    meta.link = struct('port', getf(info, 'port', ''), 'invalidCount', getf(info, 'invalidCount', NaN), ...
                       'seqGaps', getf(info, 'seqGaps', NaN));
    meta.rows = height(T);
    meta.result = getf(info, 'result', 'FINISHED');
    meta.events = events;
    meta.execution_status = 'EXECUTED';
    metaFile = fullfile(metaDir, [id '.json']);
    fid = fopen(metaFile, 'w');
    assert(fid > 0, 'servolab:data:open', 'cannot write metadata for %s', id);
    fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true)); fclose(fid);

    row = {id, A.code, n, meta.created, meta.rig, mission, meta.experiment, meta.run_in_series, ...
           getf(cfg, 'ctrl', getf(cfg, 'mode', '')), settingsText(cfg), meta.result, height(T), fw, ...
           meta.link.port, meta.os, getf(info, 'legacy_id', ''), meta.raw_data_file, ...
           strrep(fullfile('data', 'metadata', A.folder, [id '.json']), '\', '/')};
    servolab.data.appendRegister(row);
    out = struct('runId', id, 'runNo', n, 'csv', csv, 'meta', metaFile);
end

function r = rigName(A, info, hello)
    r = getf(info, 'rig', getenv('SERVOLAB_RIG'));
    if isempty(r)
        r = [A.code ' bench'];
        if strcmp(A.code, 'MOTOR') && numel(hello) >= 3, r = sprintf('%s, drive id %s', r, hello{3}); end
    end
end

function s = settingsText(c)
    parts = {};
    for f = {'loop', 'ctrl', 'mode', 'Kp', 'Ki', 'Kd', 'setpoint', 'spdFb', 'uMax', 'hyst', 'window', 'Lmin', 'Lmax'}
        if isfield(c, f{1}) && ~isempty(c.(f{1}))
            v = c.(f{1}); if isnumeric(v), v = num2str(v, 4); end
            parts{end + 1} = sprintf('%s=%s', f{1}, v); %#ok<AGROW>
        end
    end
    s = strjoin(parts, ' ');
end

function v = getf(s, f, d)
    if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
