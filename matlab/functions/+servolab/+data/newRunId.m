function [id, n] = newRunId(code, tag, when)
%NEWRUNID  The next run id of an apparatus: <CODE>-R<nnnn>_<yyyymmdd-HHMMSS>_<tag>.
%
%   [id, n] = servolab.data.newRunId('MOTOR', 'M6')      -> 'MOTOR-R0062_20261023-193103_M6', 62
%
%   n counts every rig run of that apparatus ever recorded (register and files on disk,
%   whichever is higher), so the number alone says how many runs came before. tag is the
%   mission (M1..M10, T1.., W1.., LAB); characters other than letters, digits and '-' are dropped.
    if nargin < 3, when = datetime('now'); end
    A = servolab.data.apparatus(code);
    R = servolab.data.register();
    n = 0;
    if ~isempty(R), n = max([0; R.run_no(strcmp(R.apparatus, A.code))]); end
    d = dir(fullfile(servolab.data.root(), 'data', 'raw', A.folder, [A.code '-R*.csv']));
    for k = 1:numel(d)
        t = regexp(d(k).name, '-R(\d+)_', 'tokens', 'once');
        if ~isempty(t), n = max(n, str2double(t{1})); end
    end
    n = n + 1;
    tag = regexprep(char(tag), '[^A-Za-z0-9-]', '');
    if isempty(tag), tag = 'RUN'; end
    id = sprintf('%s-R%04d_%s_%s', A.code, n, char(datetime(when, 'Format', 'yyyyMMdd-HHmmss')), tag);
end
