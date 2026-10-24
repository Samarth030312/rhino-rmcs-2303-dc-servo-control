function R = run_motor_identified_simulink(m, c, profile, Tend, modelDir)
%RUN_MOTOR_IDENTIFIED_SIMULINK  Run servo_identified.slx.
%
%   R = run_motor_identified_simulink(m, c, profile, Tend)
%
%   m, c, profile, Tend as for servolab.motor.identifiedSim. c.antiWindup = false switches
%   the PID block to a plain integrator (course S3-12).
%   R.t, R.meas, R.u, R.w, R.thMotor, R.thOut on the 1 ms grid; R.tk, R.measK, R.uK at
%   the controller samples. Builds the model if it is missing.

    here = fileparts(mfilename('fullpath'));
    if nargin >= 5, here = modelDir; end
    mdl = 'servo_identified';
    if ~isfile(fullfile(here, [mdl '.slx'])), build_motor_identified_simulink(here); end
    load_system(fullfile(here, [mdl '.slx']));
    cleanup = onCleanup(@() close_system(mdl, 0));
    aw = 'clamping'; if isfield(c, 'antiWindup') && ~c.antiWindup, aw = 'none'; end
    set_param([mdl '/Arduino PID'], 'AntiWindupMode', aw);

    w = motor_identified_simulink_params(m, c, profile, Tend);
    in = Simulink.SimulationInput(mdl);
    f = fieldnames(w);
    for k = 1:numel(f), in = in.setVariable(f{k}, w.(f{k}), 'Workspace', mdl); end
    in = in.setModelParameter('ReturnWorkspaceOutputs', 'on', 'OutputSaveName', 'yout');
    out = sim(in);
    y = out.yout;
    val = @(k) y.getElement(k).Values;
    R.t = val(1).Time; R.meas = val(1).Data(:); R.u = val(2).Data(:); R.w = val(3).Data(:);
    R.thMotor = val(4).Data(:); R.thOut = val(5).Data(:);
    tk = (0:c.Ts:Tend + 1e-9)';
    R.tk = tk;
    % sample hits are logged at e.g. 5.549999 s: look up half a step later, never the previous sample
    R.measK = interp1(R.t, R.meas, tk + 5e-4, 'previous', 'extrap');
    R.uK = interp1(R.t, R.u, tk + 5e-4, 'previous', 'extrap');
    R.simulinkVersion = ver('simulink').Version;
end
