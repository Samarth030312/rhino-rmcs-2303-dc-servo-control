function tests = test_simulink_crosscheck
%TEST_SIMULINK_CROSSCHECK  Every experiment runs in Simulink, and gives what the MATLAB simulator gives.
%   For each preset of every mission (servolab.motor.presets), its config runs in the MATLAB
%   simulator (servolab.motor.simulatePlant) and in the Simulink model of its plant
%   (servolab.motor.runSimulink: servo_identified, servo_drive_physics or servo_armature).
%   A rig experiment also runs on the drive physics. Without quantisation the two are the same
%   algorithm and agree to rounding; with it, a rounding tie at an encoder count may resolve
%   differently, so there the check is that both run and stay within a few counts.
%   Skipped (not failed) when Simulink is not installed.
    tests = functiontests(localfunctions);
end

function setupOnce(tc)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_path.m'));
    tc.assumeTrue(~isempty(ver('simulink')) && license('test', 'Simulink'), 'Simulink not installed');
    L = servolab.motor.presets();
    tc.TestData.L = L(arrayfun(@(x) isempty(x.series), L));
end

function testSameAlgorithmWithoutQuantisation(tc)
    for k = 1:numel(tc.TestData.L)
        for c = configs(tc.TestData.L(k))
            c{1}.quant = false; what = sprintf('%s %s (%s)', tc.TestData.L(k).mission, tc.TestData.L(k).label, c{1}.plantKey);
            [dm, du] = compare(c{1});
            tc.verifyLessThan(dm, 1e-8, [what ': measured']);
            tc.verifyLessThan(du, 1e-8, [what ': command']);
        end
    end
end

function testEveryExperimentRunsQuantised(tc)
    for k = 1:numel(tc.TestData.L)
        for c = configs(tc.TestData.L(k))
            what = sprintf('%s %s (%s)', tc.TestData.L(k).mission, tc.TestData.L(k).label, c{1}.plantKey);
            [dm, ~, S, R] = compare(c{1});
            tc.verifyTrue(all(isfinite(R.meas)) && all(isfinite(S.meas)), what);
            tc.verifyLessThan(dm, 0.05, [what ': measured, relative to its largest value']);
        end
    end
end

function C = configs(entry)
    c = servolab.motor.specConfig(entry.spec); C = {c};
    if strcmp(c.plantKey, 'rigId'), c.plantKey = 'rigPhys'; C{end + 1} = c; end
end

function [dm, du, S, R] = compare(c)
    S = servolab.motor.simulatePlant(c); R = servolab.motor.runSimulink(c);
    n = min(numel(S.tk), numel(R.tk));
    dm = max(abs(R.meas(1:n) - S.meas(1:n))) / max(max(abs(S.meas(1:n))), eps);
    du = max(abs(R.u(1:n) - S.u(1:n))) / max(max(abs(S.u(1:n))), eps);
end
