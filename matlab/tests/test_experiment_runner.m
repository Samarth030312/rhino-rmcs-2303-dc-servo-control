function tests = test_experiment_runner
%TEST_EXPERIMENT_RUNNER  Hardware experiment sequencing, against a fake transport and clock.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_path.m'));
end

function setup(tc)
    tc.TestData.ft = FakeTransport();
    tc.TestData.link = servolab.motor.HardwareLink();
    tc.TestData.link.attach(tc.TestData.ft);
    tc.TestData.t = 0;
end

function testLibraryIsSafeAndComplete(tc)
    E = servolab.motor.hwExperiments();
    tc.verifyGreaterThanOrEqual(numel(E), 10);
    ids = unique({E.id});
    tc.verifyTrue(all(ismember({'MOTOR-02', 'MOTOR-03', 'MOTOR-04', 'MOTOR-05', 'MOTOR-06', 'MOTOR-07'}, ids)));
    for e = E
        for r = e.runs
            if strcmp(r.loop, 'speed')
                lim = 120; if startsWith(e.name, 'Course S3-3'), lim = 150; end
                tc.verifyLessThanOrEqual(max(abs(r.profile(:, 2))), lim, e.name);   % 11.2 V battery
                tc.verifyLessThan(lim, servolab.motor.params().w_free_out_rpm, e.name);
            else
                tc.verifyLessThanOrEqual(max(abs(r.profile(:, 2))), 360, e.name);
            end
            tc.verifyLessThan(r.profile(end, 1), r.duration, e.name);
            tc.verifyTrue(issorted(r.profile(:, 1)), e.name);
        end
    end
end

function testPlaysProfileAndSweep(tc)
    ft = tc.TestData.ft; link = tc.TestData.link;
    E = servolab.motor.hwExperiments();
    e = E(strcmp({E.name}, 'Speed P gain sweep (Kp 0.2 / 0.5 / 0.8)'));
    done = [];
    runner = servolab.motor.ExperimentRunner(link, e, @(c, k) [], @(s, T, k) noteDone(k), @() clk(tc));
    runner.start();
    tc.verifyTrue(any(startsWith(ft.sent, "$CFG,1,S,P,0.2,")));
    for step = 1:400                       % 40 s of 0.1 s ticks
        tc.TestData.t = step * 0.1; runner.tick();
        if ~runner.isActive(), break; end
    end
    tc.verifyEqual(runner.state, 'done');
    tc.verifyEqual(nnz(startsWith(ft.sent, "$RUN,1")), 3);
    tc.verifyEqual(nnz(startsWith(ft.sent, "$STOP,1")), 3);
    tc.verifyTrue(any(startsWith(ft.sent, "$CFG,1,S,P,0.8,")));
    tc.verifyEqual(done, [1 2 3]);

    function noteDone(k), done(end + 1) = k; end
end

function testEncoderFeedbackAndLimitReachFirmware(tc)
    ft = tc.TestData.ft; link = tc.TestData.link;
    E = servolab.motor.hwExperiments();
    e = E(startsWith({E.name}, 'Course S3-12'));
    runner = servolab.motor.ExperimentRunner(link, e, @(c, k) [], @(s, T, k) [], @() clk(tc));
    runner.start();
    tc.verifyTrue(any(startsWith(ft.sent, "$CFG,1,E,PI,0.3,1.5,0,10,100,50*")), strjoin(ft.sent, ' | '));
end

function testSetpointProfileTiming(tc)
    ft = tc.TestData.ft; link = tc.TestData.link;
    E = servolab.motor.hwExperiments();
    e = E(strcmp({E.name}, 'Direction and reversal, open loop'));
    runner = servolab.motor.ExperimentRunner(link, e, @(c, k) [], @(s, T, k) [], @() clk(tc));
    runner.start();
    tc.TestData.t = 4.9; runner.tick();
    tc.verifyFalse(any(startsWith(ft.sent, "$SET,1,-30")));
    tc.TestData.t = 5.0; runner.tick();
    tc.verifyTrue(any(startsWith(ft.sent, "$SET,1,-30")));
end

function testFirmwareErrorAborts(tc)
    ft = tc.TestData.ft; link = tc.TestData.link;
    E = servolab.motor.hwExperiments();
    runner = servolab.motor.ExperimentRunner(link, E(1), @(c, k) [], @(s, T, k) [], @() clk(tc));
    runner.start();
    ft.push(servolab.protocol.encode('ERR', 'RUN', 11, 'runaway: wrong way - swap encoder pins 10/11'));
    link.poll();
    tc.TestData.t = 0.5; runner.tick();
    tc.verifyEqual(runner.state, 'aborted');
    tc.verifySubstring(runner.message, 'runaway');
    tc.verifyTrue(startsWith(ft.sent(end), "$STOP,1"));
end

function t = clk(tc)
    t = tc.TestData.t;
end
