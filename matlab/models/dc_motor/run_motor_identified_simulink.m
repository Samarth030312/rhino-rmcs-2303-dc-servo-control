function R = run_motor_identified_simulink(m, c, profile, Tend, modelDir)
%RUN_MOTOR_IDENTIFIED_SIMULINK  Run servo_identified.slx.
%
%   R = run_motor_identified_simulink(m, c, profile, Tend)
%
%   m, c, profile, Tend as for servolab.motor.identifiedSim. c.antiWindup = false runs
%   the controller with a plain integrator (windup).
%   R.t, R.meas, R.u, R.w, R.thMotor, R.thOut on the 1 ms grid; R.tk, R.measK, R.uK at
%   the controller samples. Builds the model if it is missing.

    here = fileparts(mfilename('fullpath'));
    if nargin >= 5, here = modelDir; end
    mdl = 'servo_identified';
    if ~isfile(fullfile(here, [mdl '.slx'])), build_motor_identified_simulink(here); end
    load_system(fullfile(here, [mdl '.slx']));
    cleanup = onCleanup(@() close_system(mdl, 0));

    w = motor_identified_simulink_params(m, c, profile, Tend);
    in = Simulink.SimulationInput(mdl);
    f = fieldnames(w);
    for k = 1:numel(f), in = in.setVariable(f{k}, w.(f{k}), 'Workspace', mdl); end
    in = in.setModelParameter('ReturnWorkspaceOutputs', 'on', 'OutputSaveName', 'yout');
    out = sim(in);
    val = simulink_outputs(out.yout);
    R.t = val.speed_rpm.Time; R.w = val.speed_rpm.Data(:);
    R.meas = interp1(val.measured.Time, val.measured.Data(:), R.t, 'previous', 'extrap');
    R.u = interp1(val.u_cmd_rpm.Time, val.u_cmd_rpm.Data(:), R.t, 'previous', 'extrap');
    R.thMotor = val.angle_motor_side_deg.Data(:); R.thOut = val.angle_output_deg.Data(:);
    tk = (0:c.Ts:Tend + 1e-9)';
    R.tk = tk;
    % sample hits are logged at e.g. 5.549999 s: look up half a step later, never the previous sample
    % each signal on its own time base (sampled signals may be logged only at their samples)
    R.measK = interp1(val.measured.Time, val.measured.Data(:), tk + 5e-4, 'previous', 'extrap');
    R.uK = interp1(val.u_cmd_rpm.Time, val.u_cmd_rpm.Data(:), tk + 5e-4, 'previous', 'extrap');
    R.simulinkVersion = ver('simulink').Version;
end
