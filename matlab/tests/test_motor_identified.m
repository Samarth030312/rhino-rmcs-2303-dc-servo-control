function tests = test_motor_identified
%TEST_MOTOR_IDENTIFIED  Identified rig model: fitting, MATLAB vs Simulink, the behaviours seen on the rig.
    tests = functiontests(localfunctions);
end

function setupOnce(tc)
    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, '..', 'setup_path.m'));
    addpath(fullfile(here, '..', 'models', 'dc_motor'));
    tc.TestData.tmp = tempname; mkdir(tc.TestData.tmp);
    build_motor_identified_simulink(tc.TestData.tmp);
end

function teardownOnce(tc)
    rmdir(tc.TestData.tmp, 's');
end

function testFitFOPDTRecoversKnownModel(tc)
    t = (0:0.05:5)';
    y = 2 + 3 * 1.5 * (1 - exp(-max(t - 0.4, 0) / 0.8));
    m = servolab.ident.fitFOPDT(t, y, 3);
    tc.verifyEqual([m.K m.tau m.theta], [1.5 0.8 0.4], 'AbsTol', 0.02);
    m1 = servolab.ident.fitFOPDT(t, y, 3, struct('theta', 0, 'K', 1.5));
    tc.verifyEqual(m1.K, 1.5); tc.verifyEqual(m1.theta, 0);
end

function testFitOnHardwareRuns(tc)
    % two of the 2026-10-11 open-loop runs: the drive behaves as K = 1 behind a ~50 rpm/s ramp
    [m, info] = servolab.motor.fitIdentified({'MOTOR-02-HW-20261011-131457', 'MOTOR-02-HW-20261011-133631'});
    tc.verifyEqual(m.K, 1, 'AbsTol', 0.05);
    tc.verifyGreaterThan(m.acc, 45); tc.verifyLessThan(m.acc, 62);
    tc.verifyLessThan(info.rmse, 3);                      % rpm; quantisation alone is 1.3 rpm rms
end

function testSimulinkMatchesMatlab(tc)
    m = struct('K', 1, 'tau', 0.1, 'theta', 0.03, 'acc', 53.4, 'qSpd', 4.615);
    cases = {'speed', 'PI', 'drive', [0 30; 4 50]; 'speed', 'I', 'encoder', [0 30]; ...
             'position', 'P', 'drive', [0 90; 5 -90]; 'speed', 'OL', 'drive', [0 20; 3 60]};
    for i = 1:size(cases, 1)
        c = servolab.motor.defaultConfig('rig', cases{i, 1}); c.ctrl = cases{i, 2}; c.spdFb = cases{i, 3}; c.quant = false;
        if strcmp(c.ctrl, 'I'), c.Kp = 0; c.Ki = 2; end
        if strcmp(c.ctrl, 'P'), c.Kp = 0.3; c.Ki = 0; end
        Sm = servolab.motor.identifiedSim(m, c, cases{i, 4}, 8);
        R = run_motor_identified_simulink(m, c, cases{i, 4}, 8, tc.TestData.tmp);
        n = min(numel(Sm.meas), numel(R.measK));
        d = Sm.meas(1:n) - R.measK(1:n);
        rng = max(abs(Sm.meas));
        % same structure; transients may differ by one sample of the 1 ms grid alignment
        tc.verifyLessThan(sqrt(mean(d.^2)) / rng, 0.03, sprintf('%s %s', cases{i, 1}, cases{i, 2}));
        tc.verifyEqual(Sm.meas(end), R.measK(n), 'AbsTol', 0.02 * rng, sprintf('%s %s final', cases{i, 1}, cases{i, 2}));
    end
end

function testWindupDelaysRecovery(tc)
    m = struct('K', 1, 'tau', 1e-4, 'acc', 53.4, 'qSpd', 4.615);
    c = servolab.motor.defaultConfig('rig', 'speed'); c.ctrl = 'PI'; c.Kp = 0.3; c.Ki = 1.5; c.uMax = 50; c.spdFb = 'encoder';
    rec = nan(1, 2);
    for aw = [true false]
        c.antiWindup = aw;
        S = servolab.motor.identifiedSim(m, c, [0 80; 6 30], 30);
        k = find(S.tk > 6 & abs(S.meas - 30) <= 3, 1);
        rec(1 + ~aw) = S.tk(k) - 6;
    end
    tc.verifyLessThan(rec(1), 1.5);                       % clamping: recovers at once
    tc.verifyGreaterThan(rec(2), 4 * rec(1));             % plain integrator: must unwind first
end

function testDeadZoneStopsPShort(tc)
    m = struct('K', 1, 'tau', 1e-4, 'acc', 53.4, 'dz', 1);
    c = servolab.motor.defaultConfig('rig', 'position'); c.ctrl = 'P'; c.Ki = 0; c.quant = false;
    c.Kp = 0.3; S = servolab.motor.identifiedSim(m, c, [0 10], 8);
    tc.verifyEqual(10 - S.meas(end), 1 / 0.3, 'AbsTol', 0.3);   % e = d / Kp
end
