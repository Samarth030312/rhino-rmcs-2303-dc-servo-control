function [tel, why] = decodeTelemetry(f, type)
%DECODETELEMETRY  Fields of a telemetry frame (after the version) -> struct.
%
%   [tel, why] = servolab.protocol.decodeTelemetry(fields, type)   type default 'TEL'
%
%   The field list per type is servolab.protocol.schema(type). Returns [] and a
%   reason if the frame is malformed. 'nan' is accepted for numeric fields.

    if nargin < 2, type = 'TEL'; end
    tel = []; why = '';
    s = servolab.protocol.schema(type);
    if numel(f) ~= numel(s.names)
        why = sprintf('%s has %d fields, expected %d', type, numel(f), numel(s.names)); return;
    end
    t = struct();
    for k = 1:numel(s.names)
        n = s.names{k}; kind = s.kinds{k};
        if iscell(kind)
            if ~any(strcmp(f{k}, kind)), why = sprintf('bad %s "%s"', n, f{k}); return; end
            t.(n) = f{k};
        elseif strcmp(kind, 'hex')
            if isempty(regexp(f{k}, '^[0-9A-Fa-f]{1,4}$', 'once')), why = ['bad flags ' f{k}]; return; end
            t.(n) = hex2dec(f{k});
        else
            v = str2double(f{k});
            if isnan(v) && ~strcmpi(f{k}, 'nan'), why = sprintf('bad number in %s: "%s"', n, f{k}); return; end
            t.(n) = v;
        end
    end
    tel = t;
end
