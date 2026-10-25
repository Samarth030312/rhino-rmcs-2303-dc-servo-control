function R = run_drive_physics_simulink(c, profile, Tend, modelDir)
%RUN_DRIVE_PHYSICS_SIMULINK  Run servo_drive_physics.slx.
%
%   R = run_drive_physics_simulink(c, profile, Tend)
%
%   c as for servolab.motor.simulate with plant 'rig' (c.P from servolab.motor.params or
%   servolab.motor.physics; c.dist, c.tDist a load torque step at the output shaft).
%   R.t, R.w, R.thOut, R.i on the 1 ms grid (R.meas, R.u held on it); R.tk, R.measK, R.uK at the
%   controller samples. Builds the model if it is missing.

    here = fileparts(mfilename('fullpath'));
    if nargin >= 4, here = modelDir; end
    mdl = 'servo_drive_physics';
    if ~isfile(fullfile(here, [mdl '.slx'])), build_drive_physics_simulink(here); end
    load_system(fullfile(here, [mdl '.slx']));
    cleanup = onCleanup(@() close_system(mdl, 0));

    w = drive_physics_simulink_params(c, profile, Tend);
    in = Simulink.SimulationInput(mdl);
    f = fieldnames(w);
    for k = 1:numel(f), in = in.setVariable(f{k}, w.(f{k}), 'Workspace', mdl); end
    in = in.setModelParameter('ReturnWorkspaceOutputs', 'on', 'OutputSaveName', 'yout');
    out = sim(in);
    val = simulink_outputs(out.yout);
    R.t = val.speed_rpm.Time; R.w = val.speed_rpm.Data(:);
    R.meas = interp1(val.measured.Time, val.measured.Data(:), R.t, 'previous', 'extrap');
    R.u = interp1(val.u_cmd_rpm.Time, val.u_cmd_rpm.Data(:), R.t, 'previous', 'extrap');
    R.thOut = val.angle_output_deg.Data(:); R.i = val.current_A.Data(:);
    tk = (0:c.Ts:Tend + 1e-9)';
    R.tk = tk;
    % sample hits are logged at e.g. 5.549999 s: look up half a step later, never the previous sample
    % each signal on its own time base (sampled signals may be logged only at their samples)
    R.measK = interp1(val.measured.Time, val.measured.Data(:), tk + 5e-4, 'previous', 'extrap');
    R.uK = interp1(val.u_cmd_rpm.Time, val.u_cmd_rpm.Data(:), tk + 5e-4, 'previous', 'extrap');
    R.simulinkVersion = ver('simulink').Version;
end
