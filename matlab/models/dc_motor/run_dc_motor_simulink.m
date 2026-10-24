function R = run_dc_motor_simulink(c, modelDir)
%RUN_DC_MOTOR_SIMULINK  Run servo_armature.slx with an servolab.motor config.
%
%   R = run_dc_motor_simulink(servolab.motor.presetConfig('Bare motor - speed - PI + load'))
%
%   R.t, R.y (true output in the loop's units), R.u (volts), R.i (A), R.ym
%   (measured, at the controller samples). Builds the model if it is missing.
%   modelDir (optional) is where the .slx lives; default is this folder.

    here = fileparts(mfilename('fullpath'));
    if nargin >= 2, here = modelDir; end
    mdl = 'servo_armature';
    if ~isfile(fullfile(here, [mdl '.slx'])), build_dc_motor_simulink(here); end
    load_system(fullfile(here, [mdl '.slx']));
    cleanup = onCleanup(@() close_system(mdl, 0));

    w = dc_motor_simulink_params(c);
    in = Simulink.SimulationInput(mdl);
    f = fieldnames(w);
    for k = 1:numel(f), in = in.setVariable(f{k}, w.(f{k}), 'Workspace', mdl); end
    tGrid = (0:c.dt:c.Tend)';
    in = in.setModelParameter('SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset', ...
                              'ReturnWorkspaceOutputs', 'on', 'OutputOption', 'SpecifiedOutputTimes', ...
                              'OutputTimes', mat2str(tGrid'));
    out = sim(in);

    y = out.yout;
    % Outports in port order: 1 speed_rpm, 2 angle_deg, 3 u_volts, 4 current_A, 5 measured
    val = @(k) y.getElement(k).Values;
    spd = val(1); ang = val(2);
    R.t = spd.Time;
    if strcmp(c.loop, 'speed'), R.y = spd.Data; else, R.y = ang.Data; end
    R.u = val(3).Data;
    R.i = val(4).Data;
    R.ym = val(5).Data;
    R.cfg = c;
    R.simulinkVersion = ver('simulink').Version;
end
