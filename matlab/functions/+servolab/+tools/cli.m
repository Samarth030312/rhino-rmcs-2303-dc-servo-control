function [status, out, cmd] = cli(varargin)
%CLI  Run the project's arduino-cli with the project's own directories.
%
%   [status, out] = servolab.tools.cli('core', 'list')
%   [status, out] = servolab.tools.cli('board', 'list', '--format', 'json')
%
%   Arguments are quoted for the shell of this OS. The arduino-cli directories
%   are passed as ARDUINO_DIRECTORIES_* environment variables for this call only,
%   so no configuration file with machine paths is needed, and the global
%   Arduino folders are never touched. status is -1 when the CLI is not
%   installed (run servolab.tools.install).

    P = servolab.tools.paths();
    out = ''; cmd = '';
    if ~isfile(P.cli)
        status = -1;
        out = sprintf('arduino-cli is not installed in %s. Run servolab.tools.install (or setup).', P.root);
        return
    end
    env = {'ARDUINO_DIRECTORIES_DATA', P.data; 'ARDUINO_DIRECTORIES_DOWNLOADS', P.downloads; ...
           'ARDUINO_DIRECTORIES_USER', P.user; 'ARDUINO_UPDATER_ENABLE_NOTIFICATION', 'false'; ...
           'ARDUINO_LIBRARY_ENABLE_UNSAFE_INSTALL', 'false'};
    old = cell(size(env, 1), 1);
    for k = 1:size(env, 1)
        old{k} = getenv(env{k, 1}); setenv(env{k, 1}, env{k, 2});
    end
    restore = onCleanup(@() restoreEnv(env(:, 1), old));
    parts = [{P.cli}, varargin];
    cmd = strjoin(cellfun(@quoteArg, parts, 'UniformOutput', false), ' ');
    % no extra outer quotes on Windows: MATLAB's system() already hands cmd.exe the whole line
    % in one pair (an extra pair broke every call there, seen in CI on windows-latest)
    [status, out] = system([cmd ' 2>&1']);
end

function q = quoteArg(a)
    a = char(a);
    if ispc
        q = ['"' strrep(a, '"', '\"') '"'];
    else
        q = ['''' strrep(a, '''', '''\''''') ''''];
    end
end

function restoreEnv(names, vals)
    for k = 1:numel(names), setenv(names{k}, vals{k}); end
end
