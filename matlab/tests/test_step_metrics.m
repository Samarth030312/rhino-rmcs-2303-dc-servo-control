function tests = test_step_metrics
%TEST_STEP_METRICS  servolab.motor.stepMetrics on signals with known answers.
    tests = functiontests(localfunctions);
end

function testFirstOrderStep(tc)
    t = (0:0.01:10)'; tau = 0.5; r = 60 * ones(size(t)); y = 60 * (1 - exp(-t / tau)); u = r;
    m = servolab.motor.stepMetrics(t, r, y, u, 'Resolution', 0.1);
    tc.verifyEqual(m.rise, tau * log(9), 'AbsTol', 0.02);          % 10-90 % of a first-order lag
    tc.verifyEqual(m.overshoot, 0, 'AbsTol', 1e-9);
    tc.verifyEqual(m.ess, 0, 'AbsTol', 0.01);
    tc.verifyEqual(m.settling, -tau * log(1.2 / 60), 'AbsTol', 0.02);   % band 2 % of 60 = 1.2
end

function testOvershootAndOffset(tc)
    t = (0:0.01:8)'; z = 0.3; wn = 3; wd = wn * sqrt(1 - z^2);
    y = 40 * (1 - exp(-z * wn * t) .* (cos(wd * t) + z / sqrt(1 - z^2) * sin(wd * t)));
    m = servolab.motor.stepMetrics(t, 40 * ones(size(t)), 0.9 * y, y, 'Resolution', 0.1);
    tc.verifyEqual(m.overshoot, 100 * (0.9 * max(y) / 40 - 1), 'AbsTol', 0.2);
    tc.verifyEqual(m.ess, 4, 'AbsTol', 0.05);
    m2 = servolab.motor.stepMetrics(t, 40 * ones(size(t)), y, y, 'Resolution', 0.1);
    tc.verifyEqual(m2.overshoot, 100 * exp(-pi * z / sqrt(1 - z^2)), 'AbsTol', 0.5);
end

function testStaticMapIgnoresUnsteadySegments(tc)
    t = (0:0.1:12)'; r = [5 * ones(40, 1); 50 * ones(40, 1); 0 * ones(41, 1)];
    y = r; y(81:end) = 50 - 20 * (t(81:end) - t(81));          % last segment still falling
    m = servolab.motor.stepMetrics(t, r, y, r, 'Resolution', 0.2);
    tc.verifyEqual(m.map.cmd', [5 50]);
end

function testWindupRecovery(tc)
    t = (0:0.1:12)'; r = [80 * ones(60, 1); 30 * ones(61, 1)];
    y = min(50, 25 * t); y(61:end) = max(30, 50 - 10 * (t(61:end) - 6));    % 2 s to reach 30
    u = 50 * ones(size(t)); u(61:end) = 30;
    m = servolab.motor.stepMetrics(t, r, y, u, 'Resolution', 0.2, 'uMax', 50);
    tc.verifyEqual(m.recovery, 1.85, 'AbsTol', 0.11);       % first within 5 % of 30: y = 31.5
    tc.verifyEqual(m.satTime, 6, 'AbsTol', 0.15);
end

function testEmptyAndShortInputs(tc)
    m = servolab.motor.stepMetrics([], [], [], []);
    tc.verifyTrue(isnan(m.rise));
    m = servolab.motor.stepMetrics([0; 0.1], [1; 1], [0; 0], [0; 0]);
    tc.verifyTrue(isnan(m.overshoot));
end
