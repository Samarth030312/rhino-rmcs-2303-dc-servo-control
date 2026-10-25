function tests = test_motor_app
%TEST_MOTOR_APP  rhino_servo_lab without hardware: missions, presets, numbers, overlay, playback.
%   Needs a display (uifigure); CI provides one (Xvfb on Linux). The hardware path is
%   tested end to end against the firmware emulator in tests/e2e/e2e_motor_mission_control.m.
    tests = functiontests(localfunctions);
end

function setupOnce(tc)
    try
        f = uifigure('Visible', 'off'); delete(f);
    catch err
        tc.assumeFail(['no display for uifigure: ' err.message]);
    end
    tc.TestData.app = rhino_servo_lab();
end

function teardownOnce(tc)
    if isfield(tc.TestData, 'app') && isvalid(tc.TestData.app.fig), delete(tc.TestData.app.fig); end
end

function testEveryMissionSimulatesAndFillsItsTable(tc)
    app = tc.TestData.app; M = servolab.motor.missions();
    for k = 1:numel(M)
        app.selectMission(k);
        tc.verifyEqual(app.mission().tag, M(k).tag);
        tc.verifyGreaterThanOrEqual(numel(app.ui.preset.Items), 1, M(k).tag);
        D = app.metricsTable();
        tc.verifyGreaterThanOrEqual(size(D, 1), numel(M(k).rows), M(k).tag); tc.verifyEqual(size(D, 2), 4);
        S = app.sim();
        tc.verifyTrue(all(isfinite(S.w)), [M(k).tag ': simulation finite']);
    end
end

function testEveryPresetOfEveryMissionRunsWithoutAWarning(tc)
    % what a user sees: every preset simulates and the message line shows no warning; a rig
    % preset also on the drive-physics plant
    app = tc.TestData.app; M = servolab.motor.missions(); K = servolab.ui.palette();
    for k = 1:numel(M)
        app.selectMission(k);
        for p = 1:numel(app.ui.preset.Items)
            app.setPreset(p); what = sprintf('%s: %s', M(k).tag, app.ui.preset.Items{p});
            S = app.sim();
            tc.verifyTrue(all(isfinite(S.meas)), what);
            tc.verifyNotEqual(app.ui.say.FontColor, K.amber, [what ' -> ' app.ui.say.Text]);
            if strcmp(app.ui.plant.Value, 'rigId')
                app.set('plant', 'rigPhys'); S = app.sim();
                tc.verifyTrue(all(isfinite(S.meas)), [what ' (drive physics)']);
                tc.verifyNotEqual(app.ui.say.FontColor, K.amber, [what ' (drive physics) -> ' app.ui.say.Text]);
            end
        end
    end
end

function testSpeedPIDesignAgainstTheory(tc)
    % M5, PI designed for zeta 0.7 (Kp 1.0, Ki 2.9): first-order theory (REF) gives ~10 %
    % overshoot on the first step; the identified rig model (SIM) much more (latency, ramp).
    app = tc.TestData.app; app.selectMission(5); app.setPreset(1);
    D = app.metricsTable();
    row = strcmp(D(:, 1), 'overshoot (%)');
    sim = str2double(D{row, 2}); ref = str2double(D{row, 4});
    tc.verifyGreaterThan(sim, 15);
    tc.verifyLessThan(ref, 15);
end

function testEditingAGainResimulates(tc)
    app = tc.TestData.app; app.selectMission(3); app.setPreset(1);
    e1 = app.sim(); app.set('Kp', 0.8); e2 = app.sim();
    tc.verifyLessThan(abs(e2.e(end)), abs(e1.e(end)), 'more Kp, less P error');
end

function testOverlayARecordedRunScoresTheRigColumn(tc)
    I = servolab.motor.runIndex();
    tc.assumeFalse(isempty(I), 'no recorded runs in data/');
    app = tc.TestData.app; app.selectMission(5);
    id = I.id{find(strcmp(I.result, 'FINISHED') & strcmp(I.loop, 'speed'), 1)};
    app.overlay(id);
    D = app.metricsTable();
    tc.verifyTrue(any(~strcmp(D(:, 3), '—')), 'RIG column filled');
    rm = strcmp(D(:, 1), 'RMSE rig vs sim (rpm)');
    if any(rm), tc.verifyLessThan(str2double(D{rm, 3}), 20); end
end

function testProfileFieldAcceptsAndRejects(tc)
    app = tc.TestData.app; app.selectMission(find(strcmp({servolab.motor.missions().tag}, 'LAB'))); app.setPreset(1);
    app.set('profile', '0 20; 3 50'); S = app.sim();
    tc.verifyEqual(S.r(end), 50);
    app.set('profile', '5 20');                          % must start at t = 0: refused, sim kept
    tc.verifyEqual(app.sim().r(end), 50);
    tc.verifyTrue(contains(app.ui.say.Text, 'Profile'));
end

function testPlaybackMovesTheClock(tc)
    % R2023b's software renderer on CI's virtual display hangs in drawnow during animated 3-D
    % playback ("Graphics timeout"); playback is covered by the newer releases on every OS
    tc.assumeFalse(isMATLABReleaseOlderThan('R2024a') && ~isempty(getenv('CI')), ...
        'animated playback is not tested on R2023b under a virtual display');
    app = tc.TestData.app; app.selectMission(1); app.setPreset(1);
    app.play('sim'); pause(1.2); drawnow;
    t = sscanf(erase(app.ui.clock.Text, 't ='), '%f');
    tc.verifyGreaterThan(t, 0.3);
    app.abort();
end

function testNoRigMeansRunIsRefusedPolitely(tc)
    app = tc.TestData.app;
    app.runRig();
    tc.verifyFalse(app.state().on);
    tc.verifyTrue(contains(app.ui.say.Text, 'Not connected'));
end

function testOpenInSimulinkForEveryPlant(tc)
    tc.assumeTrue(~isempty(ver('simulink')) && license('test', 'Simulink'), 'Simulink not installed');
    app = tc.TestData.app; K = servolab.ui.palette(); M = servolab.motor.missions();
    plans = {'M5', 'rigId', 'servo_identified'; 'M5', 'rigPhys', 'servo_drive_physics'; 'M10', 'arm', 'servo_armature'};
    for k = 1:size(plans, 1)
        app.selectMission(find(strcmp({M.tag}, plans{k, 1}))); app.setPreset(1);
        if ~strcmp(app.ui.plant.Value, plans{k, 2}), app.set('plant', plans{k, 2}); end
        app.simulink();
        tc.verifyTrue(bdIsLoaded(plans{k, 3}), plans{k, 3});
        tc.verifyNotEqual(app.ui.say.FontColor, K.amber, [plans{k, 3} ': ' app.ui.say.Text]);
        if bdIsLoaded(plans{k, 3}), close_system(plans{k, 3}, 0); end
    end
end
