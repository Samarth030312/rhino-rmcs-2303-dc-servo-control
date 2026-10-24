function m = parse(line)
%PARSE  Parse one received line. Never throws on bad input; reports it instead.
%
%   m = servolab.protocol.parse(line)
%
%   m.kind   'frame' | 'debug' | 'empty' | 'invalid'
%   m.type   frame type ('TEL', 'ACK', 'ERR', 'HELLO', ...) or ''
%   m.fields cell array of the fields after the version
%   m.err    reason when kind == 'invalid'
%   m.tel    decoded telemetry struct for TEL / TTEL / LTEL (see schema)
%
%   Lines starting with '#' are human-readable debug text: they are returned as
%   'debug' and must never be treated as data.

    m = struct('kind', 'invalid', 'type', '', 'fields', {{}}, 'err', '', 'raw', '', 'tel', []);
    s = strtrim(char(line));
    m.raw = s;
    if isempty(s), m.kind = 'empty'; return; end
    if s(1) == '#', m.kind = 'debug'; return; end
    if s(1) ~= '$', m.err = 'no leading $'; return; end
    star = find(s == '*', 1, 'last');
    if isempty(star) || star ~= numel(s) - 2
        m.err = 'missing or misplaced *CS'; return;
    end
    body = s(2:star-1);
    if ~strcmpi(s(star+1:end), servolab.protocol.checksum(body))
        m.err = sprintf('checksum mismatch (got %s, expected %s)', s(star+1:end), ...
                        servolab.protocol.checksum(body));
        return;
    end
    tok = strsplit(body, ',', 'CollapseDelimiters', false);
    if numel(tok) < 2, m.err = 'missing version'; return; end
    if ~strcmp(tok{2}, servolab.protocol.version())
        m.err = sprintf('protocol version %s not supported', tok{2}); return;
    end
    m.type = upper(tok{1});
    m.fields = tok(3:end);
    m.kind = 'frame';
    if any(strcmp(m.type, {'TEL', 'TTEL', 'LTEL'}))
        [m.tel, why] = servolab.protocol.decodeTelemetry(m.fields, m.type);
        if isempty(m.tel), m.kind = 'invalid'; m.err = why; end
    end
end
