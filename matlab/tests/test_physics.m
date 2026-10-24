function tests = test_physics
%TEST_PHYSICS  Datasheet / dimension physics of the three rigs, the thermal fit, the run register.
    tests = functiontests(localfunctions);
end

function testMotorFromTheDatasheet(tc)
    [P, D] = servolab.motor.physics();
    tc.verifyEqual(D.R, 12 / 7.5, 'AbsTol', 1e-12);
    tc.verifyEqual(D.Kt, D.Ke);
    tc.verifyEqual(D.w_free_out, 166.5, 'AbsTol', 0.5, 'free speed at 11.1 V (runaways measured 165.9-175.3, median 166.8 rpm)');
    tc.verifyEqual(D.I_batt_max, 8.8, 'AbsTol', 1e-9, '4400 mAh at 2C');
    tc.verifyEqual(D.I_limit_by, 'the drive', 'the 3 A drive limits before the battery and the motor');
    [~, F] = servolab.motor.physics(struct('soc', 100)); [~, E] = servolab.motor.physics(struct('soc', 0));
    tc.verifyEqual([F.spec.V_supply, E.spec.V_supply], [12.6, 9.0], 'AbsTol', 1e-9, 'Li-ion 3S: full and empty');
    tc.verifyEqual(P.cpr_out, 5200);
    [~, D2] = servolab.motor.physics(struct('J_factor', 1.5));
    tc.verifyEqual(D2.tau_m, 1.5 * D.tau_m, 'RelTol', 1e-9, 'tau_m scales with J');
    % the bare-motor transfer function: DC gain in output rpm per volt
    tc.verifyEqual(D.num / D.den(3) / (2 * pi / 60) / 100, D.gain_rpm_per_V, 'RelTol', 1e-9);
end

function testArmatureLoadTorqueNeedsCurrent(tc)
    [P, ~] = servolab.motor.physics();
    c = servolab.motor.defaultConfig('bare', 'speed'); c.P = P; c.ctrl = 'PI'; c.Kp = 0.05; c.Ki = 1;
    c.profile = [0 0; 0.1 100]; c.Tend = 2; c.dist = 1.0; c.tDist = 1;
    S = servolab.motor.simulate(c);
    before = mean(S.i(S.t > 0.8 & S.t < 1)); after = mean(S.i(S.t > 1.8));
    tc.verifyEqual(after - before, 1.0 / (P.N * P.Kt), 'RelTol', 0.05, '1 N*m at the output = T/(N Kt) more current');
    tc.verifyEqual(S.w_rpm(end), 100, 'AbsTol', 1, 'PI rejects the load');
end

function testRegisterIdsAndLegacy(tc)
    old = getenv('SERVOLAB_DATA_ROOT'); c = onCleanup(@() setenv('SERVOLAB_DATA_ROOT', old));
    tmp = tempname; mkdir(tmp); setenv('SERVOLAB_DATA_ROOT', tmp);
    T = table((0:4)', (100:100:500)', repmat({'S'}, 5, 1), repmat({'PI'}, 5, 1), 30 * ones(5, 1), (1:5)', ...
        'VariableNames', {'seq', 't_ms', 'loop', 'ctrl', 'setpoint', 'meas'});
    r1 = servolab.data.saveRun('MOTOR', T, struct('ctrl', 'PI', 'Kp', 1), {}, struct('mission', 'M5', 'legacy_id', 'OLD-1'));
    r2 = servolab.data.saveRun('MOTOR', T, struct('ctrl', 'P'), {}, struct('mission', 'M3', 'result', 'STOPPED: test'));
    tc.verifyMatches(r1.runId, '^MOTOR-R0001_\d{8}-\d{6}_M5$');
    tc.verifyMatches(r2.runId, '^MOTOR-R0002_\d{8}-\d{6}_M3$');
    R = servolab.data.register();
    tc.verifyEqual(height(R), 2); tc.verifyEqual(R.result{2}, 'STOPPED: test');
    tc.verifyEqual(servolab.data.resolve('OLD-1'), r1.runId);
end
