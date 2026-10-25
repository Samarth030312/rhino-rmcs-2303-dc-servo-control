function R = loadHardwareRun(runId)
%LOADHARDWARERUN  Read one exported DC-motor hardware run (raw CSV + metadata JSON).
%
%   R = servolab.motor.loadHardwareRun('MOTOR-R0006_20261011-133631_M1')
%   R = servolab.motor.loadHardwareRun('MOTOR-02-HW-20261011-133631')      % legacy id, same run
%
%   R.T     table (seq, t_ms, loop, ctrl, setpoint, meas, err, u, pos_counts, spd_base_rpm, flags, t_s)
%   R.meta  decoded metadata (config_sent, link, ...)
%   R.cfg   simulation config rebuilt from config_sent (servolab.motor.defaultConfig + fields)
%   R.id    run id
%   R.corrected  what was corrected on reading (empty if nothing)
%   Raw files are only read. One correction is applied on reading, never to the file: an
%   encoder-speed run's first sample is set to 0 (and its error to the setpoint). Before firmware
%   8ea43d3 it was a difference across the drive's late count reset after HOME, 10-46 rpm with the
%   motor at rest in 34 of 72 runs; the firmware and the models now define it as 0.

    root = servolab.data.root();
    runId = servolab.data.resolve(runId);                  % old ids (MOTOR-02-HW-...) still work
    f = fullfile(root, 'data', 'raw', 'dc_motor', [runId '.csv']);
    assert(isfile(f), 'servolab:motor:run', 'no raw data %s', f);
    R.id = runId;
    R.T = readtable(f, 'TextType', 'char');
    R.meta = jsondecode(fileread(fullfile(root, 'data', 'metadata', 'dc_motor', [runId '.json'])));
    cs = R.meta.config_sent;
    c = servolab.motor.defaultConfig('rig', cs.loop);
    for k = fieldnames(cs)'
        if ~strcmp(k{1}, 'P'), c.(k{1}) = cs.(k{1}); end
    end
    R.cfg = c;
    R.corrected = '';
    if height(R.T) > 0 && strcmp(R.T.loop{1}, 'E') && R.T.meas(1) ~= 0
        R.corrected = sprintf('first encoder-speed sample %.2f rpm set to 0 (count reset after HOME)', R.T.meas(1));
        R.T.meas(1) = 0; R.T.err(1) = R.T.setpoint(1);
    end
end
