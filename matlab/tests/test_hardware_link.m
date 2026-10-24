function tests = test_hardware_link
%TEST_HARDWARE_LINK  Host side of the serial link, against a fake transport.
%   This proves the MATLAB side follows the protocol. It says nothing about
%   real hardware: the firmware does not exist yet.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_path.m'));
end

function setup(tc)
    tc.TestData.ft = FakeTransport();
    tc.TestData.link = servolab.motor.HardwareLink();
    tc.TestData.link.attach(tc.TestData.ft);
end

function testStartSequence(tc)
    link = tc.TestData.link; ft = tc.TestData.ft;
    c = servolab.motor.defaultConfig('rig', 'position'); c.ctrl = 'P'; c.Kp = 0.3;
    link.configure(c); link.setpoint(90); link.run();
    tc.verifyEqual(numel(ft.sent), 3);
    tc.verifyTrue(startsWith(ft.sent(1), "$CFG,1,P,P,0.3,"));
    tc.verifyTrue(startsWith(ft.sent(2), "$SET,1,90*"));
    tc.verifyTrue(startsWith(ft.sent(3), "$RUN,1*"));
    tc.verifyTrue(link.running);
end

function testPollParsesAndCounts(tc)
    link = tc.TestData.link; ft = tc.TestData.ft;
    link.run();
    tel = @(seq) servolab.protocol.encode('TEL', seq, 100 * seq, 'S', 'PI', 100, 90 + seq, 10 - seq, 100, 0, 9000, '1');
    ft.push(tel(0), tel(1), '# debug text', 'not a frame', tel(3), ...
            servolab.protocol.encode('ACK', 'RUN'));
    added = link.poll();
    tc.verifyEqual(added, 3);
    tc.verifyEqual(link.n, 3);
    tc.verifyEqual(link.invalidCount, 1);
    tc.verifyEqual(link.seqGaps, 1);                      % seq 2 missing
    T = link.table();
    tc.verifyEqual(T.meas', [90 91 93]);
    tc.verifyEqual(T.t_s', [0 0.1 0.3]);
    kinds = link.eventLog(:, 2);
    tc.verifyTrue(any(strcmp(kinds, 'debug')) && any(strcmp(kinds, 'ACK')) && any(strcmp(kinds, 'invalid')));
end

function testStopAndEstopSendCommands(tc)
    link = tc.TestData.link; ft = tc.TestData.ft;
    link.run(); link.stop();
    tc.verifyTrue(startsWith(ft.sent(end), "$STOP,1*")); tc.verifyFalse(link.running);
    link.run(); link.estop();
    tc.verifyTrue(startsWith(ft.sent(end), "$ESTOP,1*"));
end

function testCloseWhileRunningSendsStop(tc)
    link = tc.TestData.link; ft = tc.TestData.ft;
    link.run(); link.close();
    tc.verifyTrue(startsWith(ft.sent(end), "$STOP,1,NOW*"), "closing while running stops at once (no soft stop)");
    tc.verifyFalse(link.isOpen());
end

function testGrowsBeyondPreallocation(tc)
    link = tc.TestData.link; ft = tc.TestData.ft;
    link.run();
    for k = 0:1499
        ft.push(servolab.protocol.encode('TEL', k, k, 'P', 'P', 1, 1, 0, 0, 0, 0, '1'));
    end
    link.poll();
    tc.verifyEqual(link.n, 1500); tc.verifyEqual(link.seqGaps, 0);
    tc.verifyEqual(height(link.table()), 1500);
end

function testWaitForHelloAndDiagLines(tc)
    link = tc.TestData.link; ft = tc.TestData.ft;
    ft.push('# RMCS-2303 found, slave id 11', servolab.protocol.encode('HELLO', 'rhino_servo_lab', 'abc1234', '11'));
    tc.verifyTrue(link.waitForHello(1));
    tc.verifyEqual(link.hello, {'rhino_servo_lab', 'abc1234', '11'});
    n0 = size(link.eventLog, 1);
    ft.push('# DIAG slave 11', '# reg 10 LPR = 13 (0xD)', servolab.protocol.encode('ACK', 'DIAG'));
    link.poll();
    tc.verifyEqual(link.debugLines(n0), {'# DIAG slave 11'; '# reg 10 LPR = 13 (0xD)'});
end

function testNoHelloTimesOut(tc)
    t0 = tic; ok = tc.TestData.link.waitForHello(0.3);
    tc.verifyFalse(ok); tc.verifyLessThan(toc(t0), 1);
end
