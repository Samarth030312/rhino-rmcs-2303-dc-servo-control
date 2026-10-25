function simulink_arduino_pid(sub)
%SIMULINK_ARDUINO_PID  The firmware's PID law as a Simulink subsystem (in: error, out: command).
%
%   simulink_arduino_pid('servo_identified/Arduino PID')
%
%   Builds, from primitive blocks sampled every Ts, exactly servolab.motor.pidStep, which is
%   exactly pidStep() in firmware/motor_controller/motor_controller.ino:
%
%     D_k  = 0 on the first sample, else (Tf D_{k-1} + Kd (e_k - e_{k-1})) / (Tf + Ts)
%     I    = I_{k-1} + Ki Ts e_k                     (backward Euler)
%     u    = clip(Kp e_k + I + D_k, +/- uMax)
%     anti-windup (aw = 1): if u is clipped, the push is the error's way and Ki ~= 0, then
%       I_k = clip(I, -uMax - pd, uMax - pd), pd = Kp e_k + D_k, never moved back against e_k,
%       and u = clip(pd + I_k); otherwise I_k = I.
%
%   Simulink's Discrete PID Controller block with 'clamping' stops the integrator instead; the
%   rig runs the law above. Variables: Kp, Ki, Kd, Tf, Ts, uMax, aw (1 clamping, 0 none), KiOn.
    add_block('simulink/Ports & Subsystems/Subsystem', sub, 'Position', [190 90 270 130]);
    delete_line(sub, 'In1/1', 'Out1/1'); delete_block([sub '/In1']); delete_block([sub '/Out1']);
    B = @(lib, name, pos, varargin) add_block(lib, [sub '/' name], 'Position', pos, varargin{:});
    UD = @(name, pos, ic) B('simulink/Discrete/Unit Delay', name, pos, 'SampleTime', 'Ts', 'InitialCondition', ic);
    B('simulink/Sources/In1', 'e', [20 200 50 215]);
    % ---- derivative, filtered, no kick on the first sample
    UD('e previous', [100 300 130 330], '0');
    B('simulink/Math Operations/Sum', 'de', [160 290 180 320], 'Inputs', '+-');
    B('simulink/Math Operations/Gain', 'Kd over Tf+Ts', [200 290 250 320], 'Gain', 'Kd/(Tf+Ts)');
    UD('D state', [200 350 230 380], '0');
    B('simulink/Math Operations/Gain', 'Tf over Tf+Ts', [250 350 300 380], 'Gain', 'Tf/(Tf+Ts)');
    B('simulink/Math Operations/Sum', 'D filter', [320 300 340 360], 'Inputs', '++');
    B('simulink/Sources/Constant', 'zero', [320 380 350 400], 'Value', '0');
    B('simulink/Sources/Constant', 'later', [100 420 130 440], 'Value', '0');
    UD('first sample', [160 420 190 450], '1');
    B('simulink/Signal Routing/Switch', 'no kick', [380 300 410 400], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    % ---- integral and the raw command
    UD('I state', [100 100 130 130], '0');
    B('simulink/Math Operations/Gain', 'Ki Ts', [100 160 140 190], 'Gain', 'Ki*Ts');
    B('simulink/Math Operations/Sum', 'I candidate', [170 110 190 190], 'Inputs', '++');
    B('simulink/Math Operations/Gain', 'Kp', [100 230 140 260], 'Gain', 'Kp');
    B('simulink/Math Operations/Sum', 'pd', [440 230 460 330], 'Inputs', '++');
    B('simulink/Math Operations/Sum', 'u raw', [500 150 520 260], 'Inputs', '++');
    B('simulink/Discontinuities/Saturation', 'clip', [550 190 590 220], 'UpperLimit', 'uMax', 'LowerLimit', '-uMax');
    % ---- clamping
    B('simulink/Logic and Bit Operations/Relational Operator', 'clipped', [620 120 650 150], 'Operator', '~=');
    B('simulink/Math Operations/Sign', 'sign u raw', [550 60 570 80]);
    B('simulink/Math Operations/Sign', 'sign e', [100 40 120 60]);
    B('simulink/Logic and Bit Operations/Relational Operator', 'same way', [620 50 650 80], 'Operator', '==');
    B('simulink/Sources/Constant', 'KiOn', [620 10 650 30], 'Value', 'KiOn');
    B('simulink/Sources/Constant', 'aw', [620 160 650 180], 'Value', 'aw');
    B('simulink/Logic and Bit Operations/Logical Operator', 'clamp', [690 20 720 180], 'Operator', 'AND', 'Inputs', '4');
    B('simulink/Sources/Constant', 'uMax', [480 380 510 400], 'Value', 'uMax');
    B('simulink/Math Operations/Sum', 'upper', [540 360 560 400], 'Inputs', '+-');
    B('simulink/Math Operations/Sum', 'lower', [540 420 560 460], 'Inputs', '--');
    B('simulink/Math Operations/MinMax', 'below upper', [600 100 630 140], 'Function', 'min', 'Inputs', '2');
    B('simulink/Math Operations/MinMax', 'above lower', [660 220 690 260], 'Function', 'max', 'Inputs', '2');
    B('simulink/Math Operations/Sign', 'sign change', [700 300 720 320]);
    B('simulink/Math Operations/Sum', 'I move', [660 290 680 320], 'Inputs', '+-');
    B('simulink/Math Operations/Product', 'against e', [740 290 770 330]);
    B('simulink/Logic and Bit Operations/Compare To Constant', 'moved back', [790 295 830 325], 'relop', '<', 'const', '0');
    B('simulink/Signal Routing/Switch', 'keep I', [860 220 890 320], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    B('simulink/Signal Routing/Switch', 'I next', [920 100 950 300], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    B('simulink/Math Operations/Sum', 'u clamped raw', [980 220 1000 330], 'Inputs', '++');
    B('simulink/Discontinuities/Saturation', 'clip clamped', [1020 260 1060 290], 'UpperLimit', 'uMax', 'LowerLimit', '-uMax');
    B('simulink/Signal Routing/Switch', 'u', [1100 150 1130 290], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
    B('simulink/Sinks/Out1', 'command', [1170 215 1200 230]);

    T = @(a, b) add_line(sub, a, b, 'autorouting', 'smart');
    T('e/1', 'e previous/1'); T('e/1', 'de/1'); T('e previous/1', 'de/2'); T('de/1', 'Kd over Tf+Ts/1');
    T('D state/1', 'Tf over Tf+Ts/1'); T('Kd over Tf+Ts/1', 'D filter/1'); T('Tf over Tf+Ts/1', 'D filter/2');
    T('later/1', 'first sample/1');
    T('zero/1', 'no kick/1'); T('first sample/1', 'no kick/2'); T('D filter/1', 'no kick/3'); T('no kick/1', 'D state/1');
    T('e/1', 'Ki Ts/1'); T('I state/1', 'I candidate/1'); T('Ki Ts/1', 'I candidate/2');
    T('e/1', 'Kp/1'); T('Kp/1', 'pd/1'); T('no kick/1', 'pd/2');
    T('pd/1', 'u raw/1'); T('I candidate/1', 'u raw/2'); T('u raw/1', 'clip/1');
    T('clip/1', 'clipped/1'); T('u raw/1', 'clipped/2');
    T('u raw/1', 'sign u raw/1'); T('e/1', 'sign e/1'); T('sign u raw/1', 'same way/1'); T('sign e/1', 'same way/2');
    T('KiOn/1', 'clamp/1'); T('clipped/1', 'clamp/2'); T('same way/1', 'clamp/3'); T('aw/1', 'clamp/4');
    T('uMax/1', 'upper/1'); T('pd/1', 'upper/2'); T('uMax/1', 'lower/1'); T('pd/1', 'lower/2');
    T('I candidate/1', 'below upper/1'); T('upper/1', 'below upper/2');
    T('below upper/1', 'above lower/1'); T('lower/1', 'above lower/2');
    T('above lower/1', 'I move/1'); T('I state/1', 'I move/2'); T('I move/1', 'sign change/1');
    T('sign change/1', 'against e/1'); T('sign e/1', 'against e/2'); T('against e/1', 'moved back/1');
    T('I state/1', 'keep I/1'); T('moved back/1', 'keep I/2'); T('above lower/1', 'keep I/3');
    T('keep I/1', 'I next/1'); T('clamp/1', 'I next/2'); T('I candidate/1', 'I next/3'); T('I next/1', 'I state/1');
    T('pd/1', 'u clamped raw/1'); T('keep I/1', 'u clamped raw/2'); T('u clamped raw/1', 'clip clamped/1');
    T('clip clamped/1', 'u/1'); T('clamp/1', 'u/2'); T('clip/1', 'u/3'); T('u/1', 'command/1');
end
