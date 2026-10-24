function appendRegister(row)
%APPENDREGISTER  Add one row (cell, in registerColumns order) to data/RUN_REGISTER.csv.
%   Fields are quoted, so commas inside them are safe. The header is written with the first row.
    f = fullfile(servolab.data.root(), 'data', 'RUN_REGISTER.csv');
    cols = servolab.data.registerColumns();
    assert(numel(row) == numel(cols), 'servolab:data:row', 'register row needs %d fields', numel(cols));
    newFile = ~isfile(f);
    if ~isfolder(fileparts(f)), mkdir(fileparts(f)); end
    fid = fopen(f, 'a'); assert(fid > 0, 'servolab:data:register', 'cannot write %s', f);
    c = onCleanup(@() fclose(fid));
    if newFile, fprintf(fid, '%s\n', strjoin(cols, ',')); end
    q = cellfun(@quote, row, 'UniformOutput', false);
    fprintf(fid, '%s\n', strjoin(q, ','));
end

function s = quote(v)
    if isnumeric(v) || islogical(v)
        if isempty(v) || ~isfinite(v), s = ''; else, s = num2str(v, 10); end
    else
        s = ['"' strrep(char(v), '"', '""') '"'];
    end
end
