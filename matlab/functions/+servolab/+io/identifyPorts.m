function B = identifyPorts()
%IDENTIFYPORTS  Every serial port with its USB ids and board, from arduino-cli (1-3 s).
%
%   B = servolab.io.identifyPorts()
%
%   B(k).port     'COM5', '/dev/cu.usbserial-1420', '/dev/ttyUSB0'
%   B(k).vid, .pid  lower-case hex without 0x ('' for a port that is not USB)
%   B(k).board    'Arduino Uno' when arduino-cli recognises it, else ''
%   B(k).kind     from servolab.tools.manifest().usb: 'Arduino (genuine)', 'CH340 clone', ...
%   B(k).likely   true for a USB port that can be this lab's Uno
%
%   Empty (0x1) when arduino-cli is not installed; servolab.io.arduinoPorts needs no CLI.
    B = struct('port', {}, 'vid', {}, 'pid', {}, 'board', {}, 'kind', {}, 'likely', {});
    [st, out] = servolab.tools.cli('board', 'list', '--format', 'json');
    if st ~= 0, return; end
    i = find(out == '{', 1);
    if isempty(i), return; end
    try
        J = jsondecode(out(i:end));
    catch
        return
    end
    if ~isfield(J, 'detected_ports') || isempty(J.detected_ports), return; end
    D = J.detected_ports; if isstruct(D), D = num2cell(D); end
    M = servolab.tools.manifest();
    for k = 1:numel(D)
        p = D{k}.port;
        if ~isfield(p, 'protocol') || ~strcmp(p.protocol, 'serial'), continue; end
        b.port = p.address; b.vid = ''; b.pid = ''; b.board = ''; b.kind = '';
        if isfield(p, 'properties') && isfield(p.properties, 'vid')
            b.vid = lower(erase(p.properties.vid, '0x')); b.pid = lower(erase(p.properties.pid, '0x'));
        end
        if isfield(D{k}, 'matching_boards') && ~isempty(D{k}.matching_boards)
            mb = D{k}.matching_boards; if iscell(mb), mb = mb{1}; end
            b.board = mb(1).name;
        end
        j = find(strcmp({M.usb.vid}, b.vid), 1);
        if ~isempty(j), b.kind = M.usb(j).kind; end
        b.likely = ~isempty(b.vid);
        if ismac && startsWith(b.port, '/dev/tty.'), continue; end      % use the cu. twin
        B(end + 1) = b; %#ok<AGROW>
    end
end
