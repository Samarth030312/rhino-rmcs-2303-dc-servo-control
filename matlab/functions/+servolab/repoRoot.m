function r = repoRoot()
%REPOROOT  Absolute path of the rhino-rmcs-2303-dc-servo-control repository.
    r = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end
