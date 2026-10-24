function m = rigModel()
%RIGMODEL  The lab rig as identified from its own open-loop steps (MEASURED, 2026-10-21 fit).
%
%   m = servolab.motor.rigModel()      % for servolab.motor.identifiedSim
%
%   Fitted with servolab.motor.fitIdentified on the four open-loop runs of 2026-10-11
%   (docs/FIRST_PRINCIPLES.md, section 2): gain K = 1.000, the
%   drive's acceleration ramp 53.4 output rpm/s, internal dynamics faster than the
%   100 ms sampling (tau ~ 0, theta = 0), RMSE 2.34 rpm. It predicts 14 closed-loop
%   runs within 2-9 % RMSE (S3-7). The speed register moves in steps of one encoder
%   line per ~10 ms window: 461.5 base rpm = 4.615 output rpm (params spd_fb_step_base_rpm).
%   The Modbus latency (70 ms) and sample time (100 ms) belong to the controller
%   config (servolab.motor.defaultConfig), not to this model.
    P = servolab.motor.params();
    m = struct('K', 1.000, 'tau', 1e-3, 'theta', 0, 'acc', 53.4, 'dz', 0, ...
               'qSpd', P.spd_fb_step_base_rpm / P.N, 'backlash', 0, 'sensorAtLoad', false, ...
               'source', 'fitIdentified, open-loop runs 2026-10-11 (MEASURED)');
end
