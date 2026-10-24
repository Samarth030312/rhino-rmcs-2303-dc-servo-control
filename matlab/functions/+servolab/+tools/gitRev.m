function rev = gitRev(root)
%GITREV  Short commit of the repository, '-dirty' if tracked files changed; 'nogit' without git.
%
%   rev = servolab.tools.gitRev()        % this repository
%
%   Works when git is missing (a ZIP download): returns 'nogit'.
    if nargin < 1, root = servolab.repoRoot(); end
    rev = 'nogit';
    [s1, r] = system(sprintf('git -C "%s" rev-parse --short HEAD', root));
    if s1 ~= 0, return; end
    rev = strtrim(r);
    [s2, st] = system(sprintf('git -C "%s" status --porcelain --untracked-files=no', root));
    if s2 == 0 && ~isempty(strtrim(st)), rev = [rev '-dirty']; end
end
