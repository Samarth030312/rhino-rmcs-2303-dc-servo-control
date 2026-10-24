function R = flash(which, port, opts)
%FLASH  Compile the sketch and upload it to an Arduino Uno (any OS).
%
%   R = servolab.tools.flash('motor', 'COM5')
%   R = servolab.tools.flash('motor', '/dev/cu.usbserial-1420')
%   R = servolab.tools.flash('temperature', '/dev/ttyACM0', 'Defines', {'LCD_I2C', 'DHT_KIND=DHT11'})
%   R = servolab.tools.flash('motor', '', 'UploadOnly', false)   % compile only (no port)
%
%   which   'motor', 'temperature' or 'level' (servolab.tools.manifest().sketches)
%   port    serial port; '' compiles without uploading
%
%   The firmware revision (git commit, '-dirty' for local changes) is compiled in
%   and reported by the board in $HELLO. Every call writes a log to
%   results/evidence/logs/flash_<time>.log. R.ok, R.log (text), R.logFile, R.rev.
%   Close any program holding the port (Serial Monitor, another MATLAB) first.

    arguments
        which (1,:) char {mustBeMember(which, {'motor', 'temperature', 'level'})}
        port = ''
        opts.Defines cell = {}
        opts.LogDir char = ''
    end
    M = servolab.tools.manifest(); P = servolab.tools.paths(); root = servolab.repoRoot();
    port = char(port);
    sketch = fullfile(root, M.sketches.(which));
    rev = servolab.tools.gitRev(root);
    flags = sprintf('-DFW_REV="%s"', rev);
    for k = 1:numel(opts.Defines), flags = [flags ' -D' opts.Defines{k}]; end %#ok<AGROW>
    buildDir = fullfile(P.build, which);
    args = {'compile', '--fqbn', M.fqbn, '--build-path', buildDir, ...
            '--build-property', ['compiler.cpp.extra_flags=' flags]};
    if ~isempty(port), args = [args, {'--upload', '--port', port}]; end
    args{end + 1} = sketch;
    [st, out, cmd] = servolab.tools.cli(args{:});

    R = struct('ok', st == 0, 'rev', rev, 'port', port, 'log', out, 'logFile', '', 'hint', '');
    if st ~= 0, R.hint = hintFor(out, port); end
    logDir = opts.LogDir;
    if isempty(logDir), logDir = fullfile(root, 'results', 'evidence', 'logs'); end
    if ~isfolder(logDir), mkdir(logDir); end
    R.logFile = fullfile(logDir, ['flash_' char(datetime('now', 'Format', 'yyyyMMdd-HHmmss')) '.log']);
    fid = fopen(R.logFile, 'w');
    if fid > 0
        fprintf(fid, '# %s  %s -> %s  (FW_REV %s)\n%s\n%s\n', computer('arch'), which, port, rev, cmd, out);
        if ~isempty(R.hint), fprintf(fid, '\n# hint: %s\n', R.hint); end
        fclose(fid);
    end
end

function h = hintFor(out, port)
%HINTFOR  Turn the commonest upload failures into one sentence of advice.
    o = lower(out);
    if contains(o, 'not installed') || contains(o, 'servolab.tools.install')
        h = 'The Arduino toolchain is missing: run setup (it installs it).';
    elseif contains(o, 'bad cpu type') || contains(o, 'exec format error')
        h = 'Apple silicon: install Rosetta 2 in Terminal: softwareupdate --install-rosetta --agree-to-license';
    elseif contains(o, 'access is denied') || contains(o, 'resource busy') || contains(o, 'permission denied')
        if ispc || ismac
            h = sprintf('%s is in use: close the Arduino IDE Serial Monitor, other MATLAB windows, or press Disconnect.', port);
        else
            h = sprintf(['%s: no permission or in use. Close other programs on the port; on Linux add yourself ' ...
                         'to the dialout group (sudo usermod -aG dialout $USER, then log out and in).'], port);
        end
    elseif contains(o, 'not in sync') || contains(o, 'stk500') || contains(o, 'programmer is not responding')
        h = ['The board did not answer the uploader: check that it is an Uno (ATmega328P), try another USB cable ' ...
             'or port, and unplug anything on pins 0/1.'];
    elseif (~isempty(port) && contains(o, 'no such file') && contains(o, lower(port))) || ...
            contains(o, 'could not open port') || contains(o, 'cannot open port')
        h = sprintf('Port %s not found: replug the board, press Refresh, and pick the port again.', port);
    else
        h = 'See the log for the compiler / uploader output.';
    end
end
