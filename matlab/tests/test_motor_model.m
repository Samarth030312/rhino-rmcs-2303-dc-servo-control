function tests = test_motor_model
%TEST_MOTOR_MODEL  The DC-motor simulation against closed-form results.
%   cd matlab/tests; results = runtests; assertSuccess(results)
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_path.m'));
end

function testParameterStatusVocabulary(tc)
    P = servolab.motor.params();
    ok = {'VERIFIED_FROM_MANUAL', 'MEASURED', 'TESTED', 'ESTIMATED', 'ASSUMED', 'UNVERIFIED'};
    f = fieldnames(P.meta);
    for i = 1:numel(f)
        tc.verifyTrue(ismember(P.meta.(f{i}).status, ok), f{i});
    end
    % A MEASURED value must cite the hardware session that produced it, and that log must exist.
    for i = 1:numel(f)
        m = P.meta.(f{i});
        if strcmp(m.status, 'MEASURED')
            tc.verifyTrue(startsWith(m.source, 'hw_session_'), [f{i} ': MEASURED without a session reference']);
            tc.verifyTrue(isfile(fullfile(servolab.repoRoot(), 'results', 'evidence', 'logs', [m.source '.log'])), ...
                [f{i} ': cited session log not found']);
        end
    end
end

function testDatasheetConsistency(tc)
    P = servolab.motor.params();
    tc.verifyEqual(P.lines * 4 * P.N, P.cpr_out);                      % 13 x 4 x 100 = 5200
    tc.verifyEqual(P.w_nl_base / P.rpm / P.N, 180, 'AbsTol', 1e-9);    % C-M2: table value
    % No-load operating point of the estimated model reproduces the datasheet.
    w = (P.V_nom - P.R * P.I_nl) / P.Ke;
    tc.verifyEqual(w, P.w_nl_base, 'RelTol', 1e-12);
    tc.verifyEqual(P.b * w / P.Kt, P.I_nl, 'RelTol', 1e-12);
end

function testBareMotorMatchesOde45(tc)
    % Exact ZOH discretisation must match a high-accuracy ODE solution.
    c = servolab.motor.defaultConfig('bare', 'speed');
    c.ctrl = 'OL'; c.quant = false; c.setpoint = 100; c.tStep = 0; c.Tend = 0.5;
    S = servolab.motor.simulate(c);
    P = c.P; V = S.u(end);
    f = @(~, x) [(V - P.R * x(1) - P.Ke * x(2)) / P.L; (P.Kt * x(1) - P.b * x(2)) / P.J];
    [~, X] = ode45(f, S.t, [0; 0], odeset('RelTol', 1e-10, 'AbsTol', 1e-12));
    wOde = X(:, 2) / P.rpm / P.N;
    % The simulator logs the state at the start of each step, the ODE at the same instant.
    tc.verifyEqual(S.y, wOde, 'AbsTol', 1e-4);
end

function testBareOpenLoopReachesSetpoint(tc)
    c = servolab.motor.defaultConfig('bare', 'speed'); c.ctrl = 'OL'; c.quant = false;
    S = servolab.motor.simulate(c);
    tc.verifyEqual(S.y(end), c.setpoint, 'RelTol', 1e-3);
end

function testRigSpeedPSteadyStateError(tc)
    % Outer P around a speed-controlled drive: e_ss = r / (1 + Kp).
    for Kp = [0.2 0.5 0.8]
        c = servolab.motor.defaultConfig('rig', 'speed'); c.ctrl = 'P'; c.Kp = Kp; c.Tend = 8;
        c.quant = false;                % theory has no 4.6 rpm feedback steps
        S = servolab.motor.simulate(c);
        tc.verifyEqual(S.metrics.ess_pct, 100 / (1 + Kp), 'AbsTol', 0.5, sprintf('Kp = %g', Kp));
    end
end

function testBareSpeedPSteadyStateError(tc)
    c = servolab.motor.defaultConfig('bare', 'speed'); c.ctrl = 'P'; c.Kp = 0.2; c.quant = false;
    P = c.P; Kss = P.Kt / (P.R * P.b + P.Kt * P.Ke) / P.rpm / P.N;
    S = servolab.motor.simulate(c);
    tc.verifyEqual(S.metrics.ess_pct, 100 / (1 + c.Kp * Kss), 'AbsTol', 0.2);
end

function testRigSpeedPOscillatesAboveUnity(tc)
    c = servolab.motor.defaultConfig('rig', 'speed'); c.ctrl = 'P'; c.Kp = 1.2;
    S = servolab.motor.simulate(c);
    tc.verifyEqual(S.metrics.verdict, 'OSCILLATING');
end

function testIntegralActionRemovesError(tc)
    for plant = {'rig', 'bare'}
        c = servolab.motor.defaultConfig(plant{1}, 'speed'); c.ctrl = 'PI'; c.dist = 0.5; c.quant = false;
        c.tDist = 8; c.Tend = 14;      % the lab drive ramps at ~50 rpm/s (measured register): give it time
        S = servolab.motor.simulate(c);
        tc.verifyLessThan(abs(S.metrics.ess_pct), 0.5, plant{1});
        tc.verifyLessThan(abs(S.metrics.distFinal), 1, plant{1});   % rpm, under load
    end
end

function testDriveSpeedFeedbackStepsAsMeasured(tc)
    % the lab drive's speed register moves in ~4.6 output-rpm steps (hardware 2026-10-11)
    c = servolab.motor.defaultConfig('rig', 'speed'); c.ctrl = 'OL'; c.setpoint = 37; c.Tend = 3;
    S = servolab.motor.simulate(c);
    q = c.P.spd_fb_step_base_rpm / c.P.N;
    tc.verifyEqual(mod(S.ym(end) / q, 1), 0, 'AbsTol', 1e-9);
    c.spdFb = 'encoder'; S = servolab.motor.simulate(c);
    tc.verifyEqual(S.ym(end), 37, 'AbsTol', 60 / (5200 * c.Ts) + 1e-9);   % one count per Ts
end

function testPositionFeedbackIsQuantised(tc)
    c = servolab.motor.defaultConfig('rig', 'position'); c.ctrl = 'P'; c.Kp = 0.3;
    S = servolab.motor.simulate(c);
    counts = S.ym / c.P.deg_per_count;
    tc.verifyEqual(counts, round(counts), 'AbsTol', 1e-9);
end

function testLoadCurrentMatchesTorqueConstant(tc)
    c = servolab.motor.defaultConfig('rig', 'position'); c.ctrl = 'P'; c.Kp = 0.3; c.dist = 1.0;
    S = servolab.motor.simulate(c);
    P = c.P;
    tc.verifyEqual(S.i(end), (c.dist / P.N + P.b * S.w_rpm(end) * P.rpm * P.N) / P.Kt, 'RelTol', 0.02);
end

function testDriveCurrentLimit(tc)
    c = servolab.motor.defaultConfig('rig', 'speed'); c.ctrl = 'OL'; c.dist = 3;   % beyond 1.7 N*m capability
    S = servolab.motor.simulate(c);
    tc.verifyLessThanOrEqual(max(abs(S.i)), c.P.I_lim_drive + 1e-12);
    tc.verifyLessThan(S.y(end), 0.5 * c.setpoint);       % the motor is overpowered
end

function testLatencyMustNotExceedTs(tc)
    c = servolab.motor.defaultConfig('rig', 'speed'); c.latency = 2 * c.Ts;
    tc.verifyError(@() servolab.motor.simulate(c), 'servolab:motor:latency');
end

function testEveryPresetRunsOnItsPlantAndOnTheDrivePhysics(tc)
    % every experiment the app offers, on its own plant; a rig experiment also on the physics plant
    L = servolab.motor.presets(); L = L(arrayfun(@(x) isempty(x.series), L));
    for k = 1:numel(L)
        c = servolab.motor.specConfig(L(k).spec); what = [L(k).mission ' ' L(k).label];
        S = servolab.motor.simulatePlant(c);
        tc.verifyFalse(S.diverged, what); tc.verifyTrue(all(isfinite(S.meas)), what);
        if strcmp(c.plantKey, 'rigId')
            c.plantKey = 'rigPhys'; S = servolab.motor.simulatePlant(c);
            tc.verifyFalse(S.diverged, [what ' (drive physics)']); tc.verifyTrue(all(isfinite(S.meas)), [what ' (drive physics)']);
        end
    end
end

function testPidAntiWindup(tc)
    g = struct('Kp', 0, 'Ki', 10, 'Kd', 0, 'Tf', 0.01, 'Ts', 0.1, 'uMax', 1);
    st = servolab.motor.pidInit();
    for k = 1:50, [u, st, sat] = servolab.motor.pidStep(st, 5, g); end
    tc.verifyEqual(u, 1); tc.verifyTrue(sat);
    tc.verifyLessThanOrEqual(st.i, 1 + 5 * 10 * 0.1);     % held, not 50 steps of growth
    [u, ~] = servolab.motor.pidStep(st, -1, g);             % recovers at once
    tc.verifyLessThan(u, 1);
end

function testPidMatchesHandCalculation(tc)
    g = struct('Kp', 2, 'Ki', 3, 'Kd', 0.5, 'Tf', 0.02, 'Ts', 0.1, 'uMax', 100);
    st = servolab.motor.pidInit();
    [u1, st] = servolab.motor.pidStep(st, 1, g);
    tc.verifyEqual(u1, 2 * 1 + 3 * 0.1 * 1, 'AbsTol', 1e-12);              % no D kick
    u2 = servolab.motor.pidStep(st, 2, g);
    d2 = (0.02 * 0 + 0.5 * (2 - 1)) / (0.02 + 0.1);
    tc.verifyEqual(u2, 2 * 2 + 3 * 0.1 * 3 + d2, 'AbsTol', 1e-12);
end
