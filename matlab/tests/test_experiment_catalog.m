function tests = test_experiment_catalog
%TEST_EXPERIMENT_CATALOG  docs/EXPERIMENTS.md is what the code defines (regenerate with
%   motor_experiment_catalog after changing an experiment, a mission or a model).
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    here = fileparts(fileparts(mfilename('fullpath')));
    run(fullfile(here, 'setup_path.m')); addpath(fullfile(here, 'scripts'));
end

function testCatalogIsCurrent(tc)
    want = motor_experiment_catalog('');
    have = strtrim(fileread(fullfile(servolab.repoRoot(), 'docs', 'EXPERIMENTS.md')));
    have = strrep(have, sprintf('\r\n'), newline);
    tc.verifyEqual(have, strtrim(want), 'docs/EXPERIMENTS.md is stale: run motor_experiment_catalog');
end
