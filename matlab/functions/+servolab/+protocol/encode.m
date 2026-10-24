function line = encode(type, varargin)
%ENCODE  Build one protocol frame:  $TYPE,1,f1,...,fn*CS   (no terminator).
%
%   line = servolab.protocol.encode('SET', 90)
%   line = servolab.protocol.encode('CFG', 'P', 'PI', 0.3, 0.03, 0, 10, 150, 180)
%
%   Numbers are written with %.6g; NaN is written as 'nan'.

    f = cell(1, numel(varargin));
    for k = 1:numel(varargin)
        v = varargin{k};
        if ischar(v) || isstring(v)
            s = char(v);
            assert(~any(ismember(s, ',*$')) && ~any(s < 32), 'servolab:protocol:field', ...
                'field %d contains a reserved character', k);
            f{k} = s;
        elseif isnan(v)
            f{k} = 'nan';
        else
            f{k} = sprintf('%.6g', v);
        end
    end
    body = strjoin([{upper(type), servolab.protocol.version()}, f], ',');
    line = ['$' body '*' servolab.protocol.checksum(body)];
end
