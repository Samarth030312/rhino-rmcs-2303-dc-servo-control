function R = run_dc_motor_simulink(c, modelDir)
%RUN_DC_MOTOR_SIMULINK  Run servo_armature.slx with a servolab.motor config (plant 'bare').
%
%   L = servolab.motor.presets('M10'); R = run_dc_motor_simulink(servolab.motor.specConfig(L(3).spec))
%   (or servolab.motor.runSimulink, which picks the model from the config's plant)
%
%   R.t, R.y (true output in the loop's units), R.u (volts), R.i (A), R.ym (measured), on the
%   output grid; R.tk, R.measK, R.uK at the controller samples. Builds the model if it is missing.
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

    val = simulink_outputs(out.yout);
    R.t = val.y_true_speed_rpm.Time;
    if strcmp(c.loop, 'speed'), R.y = val.y_true_speed_rpm.Data; else, R.y = val.y_true_angle_deg.Data; end
    on = @(x) interp1(x.Time, x.Data(:), R.t, 'previous', 'extrap');   % sampled signals onto R.t
    R.u = on(val.u_volts);
    R.i = on(val.current_A);
    R.ym = on(val.measured);
    % controller samples: outputs are logged at fixed times, and at a sample instant the log can
    % still hold the value from before the hold updates, so read 1.5 plant steps after it
    R.tk = (0:c.Ts:c.Tend + 1e-9)';
    R.measK = interp1(R.t, R.ym, R.tk + 1.5 * c.dt, 'previous', 'extrap');
    R.uK = interp1(R.t, R.u, R.tk + 1.5 * c.dt, 'previous', 'extrap');
    R.cfg = c;
    R.simulinkVersion = ver('simulink').Version;
end
