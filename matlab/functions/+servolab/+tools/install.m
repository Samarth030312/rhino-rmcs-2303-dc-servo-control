function R = install(opts)
%INSTALL  Install the pinned Arduino toolchain for this project (any OS, no admin rights).
%
%   R = servolab.tools.install()                 % idempotent: skips what is already there
%   R = servolab.tools.install('Force', true)    % download the CLI again
%   R = servolab.tools.install('Progress', @(msg) disp(msg))
%
%   1. arduino-cli (version and SHA-256 from servolab.tools.manifest), from
%      downloads.arduino.cc, into servolab.tools.paths().root
%   2. the AVR core and the libraries at their pinned versions, into the same folder
%   3. on an Apple-silicon Mac: checks Rosetta 2, which the AVR compiler needs
%      (arduino:avr ships only x86_64 macOS builds of avr-gcc and avrdude)
%
%   R.ok is true when the toolchain is complete; R.steps lists what was done.
%   Needs internet access (about 60 MB the first time).

    arguments
        opts.Force (1,1) logical = false
        opts.Progress = @(msg) fprintf('  %s\n', msg)
    end
    M = servolab.tools.manifest(); P = servolab.tools.paths();
    R = struct('ok', false, 'steps', {{}}, 'root', P.root);
    say = @(msg) step(msg);

    % ---- 1. arduino-cli --------------------------------------------------------
    if ~isfield(M.cli.assets, P.arch)
        error('servolab:tools:arch', 'No arduino-cli build is pinned for MATLAB platform %s.', P.arch);
    end
    if opts.Force || ~cliIsVersion(M.cli.version)
        asset = M.cli.assets.(P.arch);
        say(sprintf('Downloading arduino-cli %s (%s) ...', M.cli.version, asset{1}));
        tmp = fullfile(tempdir, ['arduino-lab-' asset{1}]);
        cleanTmp = onCleanup(@() deleteIfThere(tmp));
        websave(tmp, [M.cli.base asset{1}], weboptions('Timeout', 180));
        h = servolab.tools.sha256File(tmp);
        if ~strcmp(h, asset{2})
            error('servolab:tools:hash', ['SHA-256 of %s is %s, expected %s. The download is corrupt ' ...
                  'or was altered; nothing was installed.'], asset{1}, h, asset{2});
        end
        say('SHA-256 verified.');
        dest = fileparts(P.cli);
        if isfolder(dest), rmdir(dest, 's'); end
        mkdir(dest);
        if endsWith(asset{1}, '.zip'), unzip(tmp, dest); else, untar(tmp, dest); end
        if ~ispc
            system(sprintf('chmod +x "%s"', P.cli));
            if ismac, system(sprintf('xattr -dr com.apple.quarantine "%s" 2>/dev/null', dest)); end
        end
        assert(isfile(P.cli), 'servolab:tools:extract', 'arduino-cli not found after extracting to %s', dest);
        say(sprintf('arduino-cli %s installed in %s', M.cli.version, dest));
    else
        say(sprintf('arduino-cli %s already installed.', M.cli.version));
    end

    % ---- 2. AVR core and libraries ------------------------------------------------
    [~, cores] = servolab.tools.cli('core', 'list');
    [coreName, coreVer] = strtok(M.core, '@'); coreVer = coreVer(2:end);
    if isempty(regexp(cores, [regexptranslate('escape', coreName) '\s+' regexptranslate('escape', coreVer)], 'once'))
        say(sprintf('Installing %s (compiler and uploader, about 50 MB) ...', M.core));
        run('core', 'update-index');
        run('core', 'install', M.core);
    else
        say(sprintf('%s already installed.', M.core));
    end
    [~, libs] = servolab.tools.cli('lib', 'list');
    needIndex = true;
    for k = 1:numel(M.libs)
        [nm, ver] = strtok(M.libs{k}, '@'); ver = ver(2:end);
        if isempty(regexp(libs, ['(^|\n)' regexptranslate('escape', nm) '\s+' regexptranslate('escape', ver) '\s'], 'once'))
            if needIndex, run('lib', 'update-index'); needIndex = false; end
            say(sprintf('Installing library %s ...', M.libs{k}));
            run('lib', 'install', M.libs{k});
        end
    end
    say('Libraries: all pinned versions present.');

    % ---- 3. Rosetta on Apple silicon ------------------------------------------------
    if ismac && appleSilicon() && ~rosettaPresent()
        say(['Apple silicon without Rosetta 2: the AVR compiler cannot run. In Terminal run:  ' ...
             'softwareupdate --install-rosetta --agree-to-license']);
        return
    end
    R.ok = true;
    say('Arduino toolchain ready.');

    function step(msg)
        R.steps{end + 1} = msg; opts.Progress(msg);
    end
    function run(varargin)
        [st, out] = servolab.tools.cli(varargin{:});
        if st ~= 0
            error('servolab:tools:cli', 'arduino-cli %s failed:\n%s', strjoin(varargin, ' '), out);
        end
    end
end

function tf = cliIsVersion(v)
    [st, out] = servolab.tools.cli('version');
    tf = st == 0 && contains(out, ['Version: ' v]);
end

function deleteIfThere(f)
    if isfile(f), delete(f); end
end

function tf = appleSilicon()
    [st, out] = system('sysctl -n hw.optional.arm64 2>/dev/null');
    tf = st == 0 && strcmp(strtrim(out), '1');
end

function tf = rosettaPresent()
    tf = system('arch -x86_64 /usr/bin/true >/dev/null 2>&1') == 0;
end
