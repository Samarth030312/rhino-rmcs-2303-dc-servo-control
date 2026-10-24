function setup_path()
%SETUP_PATH  Put this repository's MATLAB code (and only it) on the path for this session.
%
%   Called by setup.m in the repository root; tests call it directly.
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, 'functions'));
    for g = {'apps', 'models'}
        d = dir(fullfile(here, g{1}));
        for a = d([d.isdir] & ~startsWith({d.name}, '.'))'
            addpath(fullfile(a.folder, a.name));
        end
    end
    addpath(fullfile(here, 'scripts'));
end
