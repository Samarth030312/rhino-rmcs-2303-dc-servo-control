function tests = test_tools_and_ports
%TEST_TOOLS_AND_PORTS  Cross-platform toolchain helpers, port discovery and the run index.
%   Runs on Windows, macOS and Linux (CI). Nothing is downloaded and no port is opened.
    tests = functiontests(localfunctions);
end

function testManifestPinsEveryPlatform(tc)
    M = servolab.tools.manifest();
    for a = {'win64', 'maci64', 'maca64', 'glnxa64', 'glnxaarm64'}
        x = M.cli.assets.(a{1});
        tc.verifyTrue(contains(x{1}, M.cli.version), a{1});
        tc.verifyMatches(x{2}, '^[0-9a-f]{64}$', a{1});
    end
    tc.verifyTrue(isfield(M.cli.assets, computer('arch')), 'this platform is pinned');
    for f = fieldnames(M.sketches)'
        tc.verifyTrue(isfolder(fullfile(servolab.repoRoot(), M.sketches.(f{1}))), f{1});
    end
end

function testPathsAreThisProjectsOwn(tc)
    P = servolab.tools.paths();
    tc.verifyTrue(startsWith(P.cli, P.root));
    tc.verifyFalse(contains(P.data, {'.arduino15', 'Arduino15'}), 'never the global Arduino folder');
    if ispc, tc.verifyTrue(endsWith(P.cli, '.exe')); end
    old = getenv('SERVOLAB_TOOLS'); c = onCleanup(@() setenv('SERVOLAB_TOOLS', old));
    setenv('SERVOLAB_TOOLS', fullfile(tempdir, 'lab tools test'));
    tc.verifyEqual(servolab.tools.paths().root, fullfile(tempdir, 'lab tools test'));
end

function testCliReportsMissingInstall(tc)
    old = getenv('SERVOLAB_TOOLS'); c = onCleanup(@() setenv('SERVOLAB_TOOLS', old));
    setenv('SERVOLAB_TOOLS', tempname);
    [st, out] = servolab.tools.cli('version');
    tc.verifyEqual(st, -1);
    tc.verifyTrue(contains(out, 'servolab.tools.install'));
end

function testSha256(tc)
    f = [tempname '.txt']; fid = fopen(f, 'w'); fwrite(fid, 'abc'); fclose(fid);
    c = onCleanup(@() delete(f));
    tc.verifyEqual(servolab.tools.sha256File(f), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
end

function testGitRev(tc)
    r = servolab.tools.gitRev();
    tc.verifyTrue(strcmp(r, 'nogit') || ~isempty(regexp(r, '^[0-9a-f]{7,}(-dirty)?$', 'once')), r);
end

function testPortDiscoveryNeverThrows(tc)
    [p, n] = servolab.io.arduinoPorts();
    tc.verifyClass(p, 'cell'); tc.verifySize(n, size(p));
    if ismac, tc.verifyFalse(any(startsWith(p, '/dev/tty.')), 'macOS: only cu. ports'); end
    if ispc, tc.verifyTrue(all(startsWith(p, 'COM'))); end
end

function testDoctorRunsQuietly(tc)
    r = servolab.doctor('Quiet', true);
    tc.verifyTrue(all(ismember({r.status}, {'OK', 'WARN', 'FAIL', 'INFO'})));
    tc.verifyTrue(any(strcmp({r.check}, 'MATLAB')));
end

function testRunIndexReadsTheRecordedRuns(tc)
    I = servolab.motor.runIndex();
    tc.assumeFalse(isempty(I), 'no recorded runs');
    tc.verifyTrue(issorted(flipud(I.created)), 'newest first');
    tc.verifyTrue(all(startsWith(I.result, {'FINISHED', 'STOPPED'})));
    R = servolab.motor.loadHardwareRun(I.id{1});
    tc.verifyTrue(all(ismember({'t_s', 'setpoint', 'meas', 'u'}, R.T.Properties.VariableNames)));
end
