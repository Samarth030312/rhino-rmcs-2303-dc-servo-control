function tests = test_export
%TEST_EXPORT  Simulation evidence files are complete and labelled SIMULATION.
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'setup_path.m'));
end

function testExportWritesLabelledEvidence(tc)
    tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    c = specOf('M5', 'Speed PI step to 60 rpm');       % Kp 0.3, Ki 1.5, on the drive physics
    S = servolab.motor.simulate(c);
    out = servolab.motor.exportRun(S, tmp.Folder);
    tc.verifyTrue(startsWith(out.runId, 'MOTOR-07-SIM-'));
    for f = {'trace.csv', 'samples.csv', 'run_config.json', 'summary.md'}
        tc.verifyTrue(isfile(fullfile(out.dir, f{1})), f{1});
    end
    meta = jsondecode(fileread(fullfile(out.dir, 'run_config.json')));
    tc.verifyEqual(meta.data_class, 'SIMULATION');
    tc.verifyEqual(meta.parameters.J.status, 'ESTIMATED');
    tc.verifyEqual(meta.config.Kp, 0.3);
    T = readtable(fullfile(out.dir, 'trace.csv'));
    tc.verifyEqual(T.Properties.VariableNames, {'t_s', 'setpoint', 'output_true', 'control_applied', ...
        'current_A', 'speed_out_rpm', 'angle_out_deg'});
    tc.verifyEqual(height(T), numel(S.t));
    tc.verifySubstring(fileread(fullfile(out.dir, 'summary.md')), 'Data class: SIMULATION');
end

function testRunIdsAreNeverReused(tc)
    tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    S = servolab.motor.simulate(specOf('M3', 'run 2/3: Kp 0.5'));
    ids = cell(1, 3);
    for k = 1:3, o = servolab.motor.exportRun(S, tmp.Folder); ids{k} = o.runId; end
    tc.verifyEqual(numel(unique(ids)), 3);
    tc.verifyEqual(numel(dir(fullfile(tmp.Folder, 'MOTOR-05-SIM-*'))), 3);
end

function c = specOf(mission, label)
    L = servolab.motor.presets(mission);
    c = servolab.motor.specConfig(L(find(contains({L.label}, label), 1)).spec);
end
