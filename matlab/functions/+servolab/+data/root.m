function r = root()
%ROOT  Where run data lives: the repository, or SERVOLAB_DATA_ROOT (tests write elsewhere).
    r = servolab.repoRoot();
    if ~isempty(getenv('SERVOLAB_DATA_ROOT')), r = getenv('SERVOLAB_DATA_ROOT'); end
end
