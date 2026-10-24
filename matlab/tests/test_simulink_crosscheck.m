function tests = test_simulink_crosscheck
%TEST_SIMULINK_CROSSCHECK  The Simulink model and the MATLAB simulator agree.
%   Skipped (not failed) when Simulink is not installed.
    tests = functiontests(localfunctions);
end

function setupOnce(tc)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_path.m'));
    tc.assumeTrue(~isempty(ver('simulink')) && license('test', 'Simulink'), 'Simulink not installed');
    tc.TestData.dir = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    build_dc_motor_simulink(tc.TestData.dir);
end

function testCasesAgree(tc)
    cases = {'Bare motor - speed - open loop + load', 'Bare motor - speed - PI + load', ...
             'Bare motor - position - P + load', 'Bare motor - position - PID + load'};
    for k = 1:numel(cases)
        c = servolab.motor.presetConfig(cases{k});
        c.quant = false;                     % compare the dynamics, not rounding ties
        M = servolab.motor.simulate(c);
        R = run_dc_motor_simulink(c, tc.TestData.dir);
        scale = max(abs(M.y));
        % Same equations, same discrete controller (backward-Euler I and D filter,
        % clamping anti-windup): measured agreement on 2026-10-09 was < 1e-10.
        err = max(abs(R.y - M.y)) / scale;
        fprintf('  %-40s max relative difference %.2e\n', cases{k}, err);
        tc.verifyLessThan(err, 1e-6, sprintf('%s: max relative error %.3g', cases{k}, err));
        tc.verifyEqual(M.metrics.ess, servolab.motor.metrics(swapY(M, R)).ess, 'AbsTol', 0.02 * scale, cases{k});
    end
end

function S = swapY(S, R)
    S.y = R.y;
end
