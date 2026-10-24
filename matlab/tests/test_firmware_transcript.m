function tests = test_firmware_transcript
%TEST_FIRMWARE_TRANSCRIPT  MATLAB parses everything the real motor firmware prints.
%   The fixture is produced by running firmware/motor_controller on the PC
%   against an emulated RMCS-2303 (scripts/validation/build_firmware.sh). This checks
%   the firmware and MATLAB agree on protocol v1; it is not a hardware test.
    tests = functiontests(localfunctions);
end

function setupOnce(tc)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_path.m'));
    f = fullfile(servolab.repoRoot(), 'firmware', 'tests', 'fixtures', 'firmware_transcript.txt');
    tc.assumeTrue(isfile(f), 'run scripts/validation/build_firmware.sh first');
    tc.TestData.lines = splitlines(string(fileread(f)));
    tc.TestData.lines(tc.TestData.lines == "") = [];
end

function testEveryLineIsValid(tc)
    kinds = strings(size(tc.TestData.lines));
    for k = 1:numel(kinds)
        m = servolab.protocol.parse(tc.TestData.lines(k));
        kinds(k) = m.kind;
        tc.verifyNotEqual(m.kind, 'invalid', sprintf('line %d: %s (%s)', k, tc.TestData.lines(k), m.err));
    end
    tc.verifyGreaterThan(nnz(kinds == "frame"), 100);
end

function testLinkBuildsTelemetryTable(tc)
    ft = FakeTransport(); link = servolab.motor.HardwareLink(); link.attach(ft);
    ft.push(tc.TestData.lines{:});
    tc.verifyTrue(link.waitForHello(1));
    tc.verifyEqual(link.hello{1}, 'rhino_servo_lab');
    tc.verifyEqual(link.hello{3}, '7');                  % the emulated drive answers as the lab's drive (id 7)
    link.poll();
    T = link.table();
    tc.verifyGreaterThan(height(T), 100);
    tc.verifyEqual(link.invalidCount, 0);
    tc.verifyTrue(all(ismember(T.loop, ["S", "E", "P"])));
    % the first speed run settles at its 50 rpm setpoint
    s = T(T.setpoint == 50, :);
    tc.verifyEqual(s.meas(end), 50, 'AbsTol', 1);
end
