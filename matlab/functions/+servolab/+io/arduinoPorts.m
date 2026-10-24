function [ports, names] = arduinoPorts()
%ARDUINOPORTS  Serial ports that can be an Arduino, on Windows, macOS and Linux (fast).
%
%   [ports, names] = servolab.io.arduinoPorts()
%
%   ports  cellstr, most likely Arduino first:
%            Windows  COM ports (built-in COM1/COM2 last)
%            macOS    /dev/cu.* only. The /dev/tty.* twin of a port blocks on open, and
%                     Bluetooth / debug-console ports are left out.
%            Linux    /dev/ttyACM*, /dev/ttyUSB*
%   names  a short description per port ('' when unknown), e.g. 'Arduino Uno',
%          'CH340 USB-serial (clone Uno)'. It is cheap enough for a 1 s port watcher;
%          servolab.io.identifyPorts asks arduino-cli for the exact board and USB ids.
    ports = {}; names = {};
    if ispc
        try, ports = cellstr(serialportlist("all")); catch, ports = {}; end
        ports = ports(startsWith(ports, 'COM'));
        names = repmat({''}, size(ports));
        dev = winSerialDevices();                   % COMn -> \Device\... (registry, instant)
        for k = 1:numel(ports)
            if isKey(dev, ports{k}), names{k} = winKind(dev(ports{k}), ports{k}); end
        end
        builtin = strcmp(names, 'built-in serial port');
        ports = [ports(~builtin), ports(builtin)]; names = [names(~builtin), names(builtin)];
        return
    end
    if ismac
        try, cand = cellstr(serialportlist("all")); catch, cand = {}; end
        d = dir('/dev/cu.*');
        cand = unique([cand, strcat('/dev/', {d.name})]);
        skip = contains(cand, {'Bluetooth', 'debug-console', 'wlan', 'BLTH', 'AirPods'}, 'IgnoreCase', true);
        ports = cand(startsWith(cand, '/dev/cu.') & ~skip);
        names = cellfun(@macKind, ports, 'UniformOutput', false);
        [~, order] = sort(cellfun(@isempty, names)); ports = ports(order); names = names(order);
        return
    end
    d = [dir('/dev/ttyACM*'); dir('/dev/ttyUSB*')];
    for k = 1:numel(d), ports{end + 1} = fullfile('/dev', d(k).name); end %#ok<AGROW>
    names = repmat({''}, size(ports));
    byid = dir('/dev/serial/by-id/*');
    for k = 1:numel(byid)
        [st, target] = system(sprintf('readlink -f "%s"', fullfile(byid(k).folder, byid(k).name)));
        if st == 0
            i = find(strcmp(ports, strtrim(target)), 1);
            if ~isempty(i), names{i} = linuxKind(byid(k).name); end
        end
    end
end

function m = winSerialDevices()
    m = containers.Map();
    try
        key = 'HARDWARE\DEVICEMAP\SERIALCOMM';
        vals = winqueryreg('name', 'HKEY_LOCAL_MACHINE', key);
        for k = 1:numel(vals)
            m(winqueryreg('HKEY_LOCAL_MACHINE', key, vals{k})) = vals{k};
        end
    catch
        % no registry access: names stay empty
    end
end

function s = winKind(dev, port)
    d = lower(dev);
    if contains(d, 'usbser'),        s = 'USB serial (Arduino Uno or compatible)';
    elseif contains(d, 'ch341') || contains(d, 'wch'), s = 'CH340 USB-serial (clone Uno)';
    elseif contains(d, 'vcp'),       s = 'FTDI USB-serial';
    elseif contains(d, 'silabser'),  s = 'CP210x USB-serial';
    elseif contains(d, 'bth'),       s = 'Bluetooth serial';
    elseif any(strcmp(port, {'COM1', 'COM2'})) && ~isempty(regexp(d, '\\device\\serial[01]$', 'once'))
        s = 'built-in serial port';
    else,                            s = '';
    end
end

function s = macKind(p)
    if contains(p, 'usbmodem'),                         s = 'Arduino Uno (USB)';
    elseif contains(p, 'wchusbserial'),                 s = 'CH340 USB-serial (clone Uno)';
    elseif contains(p, 'usbserial'),                    s = 'USB-serial (CH340 / FTDI clone Uno)';
    elseif contains(p, 'SLAB_USBtoUART'),               s = 'CP210x USB-serial';
    else,                                               s = '';
    end
end

function s = linuxKind(byid)
    b = lower(byid);
    if contains(b, 'arduino'),                          s = 'Arduino Uno';
    elseif contains(b, '1a86') || contains(b, 'ch34'),  s = 'CH340 USB-serial (clone Uno)';
    elseif contains(b, 'ftdi'),                         s = 'FTDI USB-serial';
    elseif contains(b, 'cp210'),                        s = 'CP210x USB-serial';
    else,                                               s = strrep(b, 'usb-', '');
    end
end
