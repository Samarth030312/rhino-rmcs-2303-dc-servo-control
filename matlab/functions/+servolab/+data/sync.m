function R = sync(code, root)
%SYNC  Commit this computer's new rig data and push it to GitHub (the SYNC DATA button).
%
%   R = servolab.data.sync('MOTOR')      % or 'TEMP', 'WATER', or '' for everything
%
%   1. stages data/ (raw runs, metadata, RUN_REGISTER.csv), results/evidence/logs and
%      results/reports
%   2. commits them as "data(<apparatus>): runs R0062-R0065 (<date>)"
%   3. git pull --rebase (other groups may have pushed runs meanwhile), then git push
%   R.ok, R.message (one sentence for the app), R.log (every command and its output).
%   Nothing else in the repository is committed. Needs git, and permission to push
%   (the repository owner adds you as a collaborator; the first push asks you to sign in).
    if nargin < 1, code = ''; end
    if nargin < 2, root = servolab.repoRoot(); end                    % tests use a scratch clone
    R = struct('ok', false, 'message', '', 'log', '');
    paths = {'data', fullfile('results', 'evidence', 'logs'), fullfile('results', 'reports')};
    paths = paths(cellfun(@(p) isfolder(fullfile(root, p)), paths));        % git refuses missing paths
    pq = strjoin(cellfun(@(p) ['"' p '"'], paths, 'UniformOutput', false), ' ');
    [st, out] = git('rev-parse --is-inside-work-tree');
    if st ~= 0, R.message = 'This copy is not a git checkout (or git is not installed): install git and clone the repository to sync.'; return; end
    [~, out] = git(['status --porcelain --untracked-files=all -- ' pq]);
    if isempty(strtrim(out)), R.ok = true; R.message = 'Nothing new to sync: every run is already on GitHub (or committed here).'; return; end
    newRuns = regexp(out, '([A-Z]+)-R(\d{4})_', 'tokens');
    git(['add -- ' pq]);
    msg = 'data: rig runs and logs';
    if ~isempty(newRuns)
        n = cellfun(@(t) str2double(t{2}), newRuns); a = unique(cellfun(@(t) t{1}, newRuns, 'UniformOutput', false));
        msg = sprintf('data(%s): runs R%04d-R%04d (%s)', strjoin(a, ', '), min(n), max(n), char(datetime('now', 'Format', 'yyyy-MM-dd')));
    end
    [st, out] = git(sprintf('commit -m "%s" -- %s', msg, pq));
    if st ~= 0
        if contains(out, 'user.email') || contains(out, 'identity')
            R.message = ['git does not know who you are. In a terminal: git config --global user.name "Your Name" ' ...
                         'and git config --global user.email you@example.com, then SYNC again.'];
        else
            R.message = ['Commit failed: ' firstLine(out)];
        end
        return
    end
    [st, out] = git('pull --rebase --autostash');
    if st ~= 0
        R.message = ['Committed here, but pulling from GitHub failed (' firstLine(out) '). Check the internet connection and SYNC again.'];
        return
    end
    [st, out] = git('push');
    if st ~= 0
        if contains(lower(out), {'permission', '403', 'denied', 'authentication', 'could not read username'})
            R.message = ['Committed here; GitHub refused the push. Ask the repository owner to add your GitHub account ' ...
                         'as a collaborator, run  git push  once in a terminal to sign in, then SYNC again.'];
        else
            R.message = ['Committed here; push failed: ' firstLine(out)];
        end
        return
    end
    R.ok = true; R.message = ['Synced to GitHub: ' msg '.'];

    function [st, out] = git(args)
        [st, out] = system(sprintf('git -C "%s" %s', root, args));
        R.log = sprintf('%s$ git %s\n%s\n', R.log, args, out);
    end
end

function s = firstLine(t)
    L = strtrim(splitlines(strtrim(t))); L = L(~cellfun(@isempty, L));
    if isempty(L), s = ''; else, s = L{end}; end
end
