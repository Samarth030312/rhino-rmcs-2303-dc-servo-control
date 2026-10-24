function cs = checksum(body)
%CHECKSUM  XOR of every byte of BODY as two upper-case hex digits.
%   BODY is the text between '$' and '*' (docs/architecture/SERIAL_PROTOCOL.md).
    x = uint8(0);
    b = uint8(char(body));
    for k = 1:numel(b), x = bitxor(x, b(k)); end
    cs = sprintf('%02X', x);
end
