function report = doctor(opts)
%DOCTOR  Check this computer for everything Rhino DC Servo Lab needs, and say how to fix it.
%
%   servolab.doctor                  % check and print
%   servolab.doctor('Fix', true)     % also install the Arduino toolchain if it is missing
%   servolab.doctor('Probe', true)   % also open the board's port and wait for the firmware's
%                                  % $HELLO (resets the Uno; nothing moves)
%   r = servolab.doctor('Quiet', true)
%
%   Windows, macOS and Linux. Each check gives OK, WARN (works, but read the note),
%   FAIL (fix before using the rig) or INFO, and for WARN / FAIL the exact fix.
%   Covers: MATLAB release, where the repository is, write access, git, the Arduino
%   toolchain, Rosetta 2 on Apple silicon, USB drivers (CH340 / FTDI / CP210x), serial
%   permissions and busy ports, and optionally the firmware on the board.

    arguments
        opts.Fix (1,1) logical = false
        opts.Probe (1,1) logical = false
        opts.Quiet (1,1) logical = false
    end
    R = struct('check', {}, 'status', {}, 'detail', {}, 'fix', {});
    root = servolab.repoRoot();
    if ~opts.Quiet
        fprintf('\nRhino DC Servo Lab doctor  (%s, MATLAB %s, %s)\n\n', osName(), version('-release'), computer('arch'));
    end

    % ---------------------------------------------------------------- MATLAB
    rel = version('-release');
    if isMATLABReleaseOlderThan('R2023b')
        add('MATLAB', 'FAIL', ['R' rel], 'Use MATLAB R2023b or newer (the apps use uifigure features from R2023b).');
    else
        add('MATLAB', 'OK', ['R' rel], '');
    end
    if ~isempty(ver('simulink')), add('Simulink', 'OK', 'installed (Simulink models and their tests)', '');
    else, add('Simulink', 'INFO', 'not installed: apps and simulation work; the .slx models need it', ''); end

    % ---------------------------------------------------------------- repository
    add('Repository', 'OK', root, '');
    if any(double(root) > 127)
        add('Repository path', 'WARN', 'contains non-ASCII characters', ...
            'Move the folder to a plain path such as C:\rhino-rmcs-2303-dc-servo-control or ~/rhino-rmcs-2303-dc-servo-control.');
    end
    if contains(root, {'OneDrive', 'iCloud', 'Dropbox', 'Google Drive', 'CloudStorage'}, 'IgnoreCase', true)
        add('Repository path', 'WARN', 'inside a synced cloud folder', ...
            ['Cloud sync can lock files while a run is being saved. Clone to a local folder ' ...
             '(e.g. %USERPROFILE%\rhino-rmcs-2303-dc-servo-control on Windows, ~/rhino-rmcs-2303-dc-servo-control on macOS).']);
    end
    if ispc && strlength(root) > 120
        add('Repository path', 'WARN', sprintf('%d characters long', strlength(root)), ...
            'Windows limits paths to 260 characters; clone to a shorter folder such as C:\rhino-rmcs-2303-dc-servo-control.');
    end
    probeFile = fullfile(root, 'data', 'raw', sprintf('.write_test_%d', randi(1e9)));
    try
        fid = fopen(probeFile, 'w'); assert(fid > 0); fclose(fid); delete(probeFile);
        add('Write access', 'OK', 'data/raw is writable (rig runs are saved there)', '');
    catch
        add('Write access', 'FAIL', 'cannot write to data/raw', 'Clone the repository to a folder you own.');
    end
    rev = servolab.tools.gitRev(root);
    if strcmp(rev, 'nogit')
        add('git', 'WARN', 'not a git checkout, or git is not installed', ...
            'Install git (see install/README.md) to pull updates and push your rig data.');
    else
        add('git', 'OK', ['commit ' rev], '');
    end

    % ---------------------------------------------------------------- Arduino toolchain
    P = servolab.tools.paths(); M = servolab.tools.manifest();
    [st, out] = servolab.tools.cli('version');
    toolsOk = st == 0 && contains(out, M.cli.version);
    if toolsOk
        [~, cores] = servolab.tools.cli('core', 'list'); [~, libs] = servolab.tools.cli('lib', 'list');
        missing = {};
        if ~contains(cores, '1.8.8'), missing{end + 1} = M.core; end
        for k = 1:numel(M.libs)
            [nm, vv] = strtok(M.libs{k}, '@');
            if isempty(regexp(libs, ['(^|\n)' regexptranslate('escape', nm) '\s+' regexptranslate('escape', vv(2:end)) '\s'], 'once'))
                missing{end + 1} = M.libs{k}; %#ok<AGROW>
            end
        end
        toolsOk = isempty(missing);
    end
    if ~toolsOk && opts.Fix
        if ~opts.Quiet, fprintf('Installing the Arduino toolchain into %s ...\n', P.root); end
        try
            r = servolab.tools.install('Progress', @(m) progress(m));
            toolsOk = r.ok;
        catch err
            add('Arduino toolchain', 'FAIL', err.message, 'Check the internet connection (or proxy) and run setup again.');
        end
    end
    if toolsOk
        add('Arduino toolchain', 'OK', sprintf('arduino-cli %s, %s, %d libraries in %s', M.cli.version, M.core, numel(M.libs), P.root), '');
    elseif ~opts.Fix
        add('Arduino toolchain', 'FAIL', 'not installed (needed to flash the firmware)', ...
            'Run  setup fix  (downloads about 60 MB, no admin rights needed).');
    end
    if ismac
        [s1, o1] = system('sysctl -n hw.optional.arm64 2>/dev/null');
        if s1 == 0 && strcmp(strtrim(o1), '1')
            if system('arch -x86_64 /usr/bin/true >/dev/null 2>&1') == 0
                add('Rosetta 2', 'OK', 'present (the AVR compiler is an Intel binary)', '');
            else
                add('Rosetta 2', 'FAIL', 'missing on Apple silicon: the AVR compiler cannot run', ...
                    'In Terminal: softwareupdate --install-rosetta --agree-to-license');
            end
        end
    end

    % ---------------------------------------------------------------- serial ports and drivers
    [ports, names] = servolab.io.arduinoPorts();
    usb = ports(~cellfun(@isempty, names) & ~strcmp(names, 'built-in serial port'));
    if isempty(ports)
        add('Serial ports', 'FAIL', 'no serial port found', noPortFix());
    else
        lst = strjoin(cellfun(@(p, n) strtrim(sprintf('%s %s', p, paren(n))), ports, names, 'UniformOutput', false), ', ');
        if isempty(usb) && (ispc || ismac)
            add('Serial ports', 'WARN', lst, ['None of these looks like a USB Arduino. Plug the Uno in (data cable, ' ...
                'not charge-only) and run setup again. ' noPortFix()]);
        else
            add('Serial ports', 'OK', lst, '');
        end
    end
    driverChecks();
    busyChecks();
    if opts.Probe, probeFirmware(); end

    % ---------------------------------------------------------------- extras
    if ~ispc && ~ismac
        if system('command -v ffmpeg >/dev/null 2>&1') == 0, add('ffmpeg', 'OK', 'MP4 recordings of the app', '');
        else, add('ffmpeg', 'INFO', 'not installed: app recordings are saved as AVI', 'sudo apt install ffmpeg'); end
    end

    report = R;
    if ~opts.Quiet, printReport(R); end
    if nargout == 0, clear report; end

    % ================================================================ nested
    function add(check, status, detail, fix)
        R(end + 1) = struct('check', check, 'status', status, 'detail', detail, 'fix', fix);
    end
    function progress(m)
        if ~opts.Quiet, fprintf('  %s\n', m); end
    end

    function driverChecks()
        if ispc
            ps = ['Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match ''VID_(1A86|2341|2A03|0403|10C4)'' } | ' ...
                  'ForEach-Object { ''{0}|{1}|{2}|{3}'' -f $_.Status,$_.Class,$_.FriendlyName,$_.InstanceId }'];
            [s, o] = system(['powershell -NoProfile -NonInteractive -Command "' ps '"']);
            if s ~= 0, return; end
            L = strtrim(splitlines(strtrim(o))); L = L(~cellfun(@isempty, L));
            for i = 1:numel(L)
                f = strsplit(L{i}, '|'); if numel(f) < 4, continue; end
                bad = ~strcmpi(f{1}, 'OK') || ~strcmpi(f{2}, 'Ports');
                isCh340 = contains(upper(f{4}), 'VID_1A86');
                if bad && isCh340
                    add('USB driver', 'FAIL', sprintf('"%s" is plugged in but has no working driver (CH340 chip)', f{3}), ...
                        ['Device Manager (devmgmt.msc) > Other devices > right-click the device > Update driver > ' ...
                         'Search automatically. If Windows finds nothing, install CH341SER.EXE from the maker''s site ' ...
                         'https://www.wch-ic.com/downloads/CH341SER_EXE.html , then unplug and replug the board.']);
                elseif bad
                    add('USB driver', 'FAIL', sprintf('"%s" has no working driver', f{3}), ...
                        'Install the Arduino IDE once (it installs the Arduino USB drivers): winget install --id ArduinoSA.IDE.stable -e');
                else
                    add('USB driver', 'OK', sprintf('%s', f{3}), '');
                end
            end
        elseif ismac
            [s, o] = system('system_profiler SPUSBDataType 2>/dev/null | grep -i -E "vendor id: 0x(1a86|2341|2a03|0403|10c4)"');
            if s == 0 && ~isempty(strtrim(o)) && isempty(usb)
                add('USB driver', 'FAIL', 'a USB-serial chip is connected but no /dev/cu.* port appeared', ...
                    ['macOS 11 or newer includes the CH340 driver: update macOS, or install the CH34x driver from ' ...
                     'https://www.wch-ic.com/downloads/CH34XSER_MAC_ZIP.html and allow it in System Settings > ' ...
                     'Privacy & Security.']);
            end
        else
            [s, o] = system('id -nG');
            if s == 0 && ~any(strcmp(strsplit(strtrim(o)), 'dialout')) && ~any(strcmp(strsplit(strtrim(o)), 'uucp'))
                add('Serial permission', 'FAIL', 'you are not in the dialout group', ...
                    'sudo usermod -aG dialout $USER   then log out and back in.');
            else
                add('Serial permission', 'OK', 'member of dialout', '');
            end
            if system('command -v brltty >/dev/null 2>&1') == 0
                add('brltty', 'WARN', 'installed: on Ubuntu it can grab CH340 boards (the ttyUSB port vanishes)', ...
                    'If a clone Uno appears and disappears: sudo apt remove brltty');
            end
        end
    end

    function busyChecks()
        for i = 1:numel(usb)
            try
                s = serialport(usb{i}, 115200, 'Timeout', 0.2); delete(s);
            catch err
                if contains(lower(err.message), {'in use', 'busy', 'access', 'denied', 'permission'})
                    add('Port free', 'WARN', sprintf('%s is in use by another program', usb{i}), ...
                        'Close the Arduino IDE Serial Monitor, other MATLAB windows or apps holding the port.');
                else
                    add('Port free', 'WARN', sprintf('%s: %s', usb{i}, err.message), '');
                end
            end
        end
    end

    function probeFirmware()
        if isempty(usb), return; end
        link = servolab.motor.HardwareLink();
        c = onCleanup(@() link.close());
        try
            link.open(usb{1});
            if link.waitForHello(6)
                h = link.hello;
                add('Firmware', 'OK', sprintf('%s rev %s on %s, drive slave id %s', h{1}, h{2}, usb{1}, h{min(3, end)}), '');
            else
                add('Firmware', 'WARN', sprintf('no $HELLO from %s within 6 s', usb{1}), ...
                    'Flash the firmware: in the app press FLASH, or servolab.tools.flash(''motor'', port).');
            end
        catch err
            add('Firmware', 'WARN', err.message, '');
        end
    end
end

function s = noPortFix()
    if ispc
        s = ['Use a data USB cable and another USB socket; open Device Manager (devmgmt.msc) and look under ' ...
             '"Ports (COM & LPT)" and "Other devices". A "USB2.0-Serial" with a warning sign is a CH340 board without ' ...
             'its driver (see USB driver).'];
    elseif ismac
        s = 'Use a data USB cable (an adapter hub can be the problem); the port appears as /dev/cu.usbmodem* or /dev/cu.usbserial-*.';
    else
        s = 'Use a data USB cable; check  dmesg | tail  after plugging in (ttyACM0 / ttyUSB0 should appear).';
    end
end

function s = osName()
    if ispc, s = 'Windows'; elseif ismac, s = 'macOS'; else, s = 'Linux'; end
end

function s = paren(n)
    if isempty(n), s = ''; else, s = ['(' n ')']; end
end

function printReport(R)
    w = max(cellfun(@numel, {R.check}));
    for k = 1:numel(R)
        fprintf('  %-5s %-*s  %s\n', R(k).status, w, R(k).check, R(k).detail);
        if ~isempty(R(k).fix) && any(strcmp(R(k).status, {'WARN', 'FAIL', 'INFO'}))
            fprintf('        %*s  -> %s\n', w, '', R(k).fix);
        end
    end
    nf = nnz(strcmp({R.status}, 'FAIL'));
    if nf == 0
        fprintf('\n  Ready. Start the lab with:  setup open\n\n');
    else
        fprintf('\n  %d problem(s) to fix (FAIL). Fix them and run setup again.\n\n', nf);
    end
end
