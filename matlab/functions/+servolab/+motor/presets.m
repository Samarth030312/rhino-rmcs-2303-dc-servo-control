function p = presets()
%PRESETS  Named experiment configurations shared by the app and the batch runner.
%
%   p = servolab.motor.presets()      struct array: name, experiment, plant, loop, set
%   c = servolab.motor.presetConfig(name)
%
%   Gains were chosen in simulation with ESTIMATED plant parameters. They are a
%   starting point for hardware, not a validated tuning.

    p = struct('name', {}, 'experiment', {}, 'plant', {}, 'loop', {}, 'set', {});
    % --------------------------------------------- lab rig (ED-M1 option B)
    add('Rig - speed - open loop (drive only)',   'MOTOR-03', 'rig', 'speed',    {'ctrl', 'OL'});
    add('Rig - speed - P, Kp 0.5',                'MOTOR-05', 'rig', 'speed',    {'ctrl', 'P', 'Kp', 0.5});
    add('Rig - speed - P, Kp 1.2 (too high)',     'MOTOR-05', 'rig', 'speed',    {'ctrl', 'P', 'Kp', 1.2});
    add('Rig - speed - I, Ki 1.0',                'MOTOR-06', 'rig', 'speed',    {'ctrl', 'I', 'Ki', 1.0});
    add('Rig - speed - PI, Kp 0.3 Ki 1.5',        'MOTOR-07', 'rig', 'speed',    {'ctrl', 'PI', 'Kp', 0.3, 'Ki', 1.5});
    add('Rig - position - open loop (timed)',     'MOTOR-04', 'rig', 'position', {'ctrl', 'OL'});
    add('Rig - position - P, Kp 0.3',             'MOTOR-05', 'rig', 'position', {'ctrl', 'P', 'Kp', 0.3});
    add('Rig - position - P, Kp 1.5 (too high)',  'MOTOR-05', 'rig', 'position', {'ctrl', 'P', 'Kp', 1.5});
    add('Rig - position - I only, Ki 0.1',        'MOTOR-06', 'rig', 'position', {'ctrl', 'I', 'Ki', 0.1, 'Tend', 8});
    add('Rig - position - PI, Kp 0.3 Ki 0.03',    'MOTOR-07', 'rig', 'position', {'ctrl', 'PI', 'Kp', 0.3, 'Ki', 0.03, 'Tend', 8});
    add('Rig - position - P under 1 N*m load',    'MOTOR-05', 'rig', 'position', {'ctrl', 'P', 'Kp', 0.3, 'dist', 1.0});
    % ------------------------------- bare motor, course week 4 (ED-M1 option C)
    add('Bare motor - speed - open loop + load',  'SIM-W4', 'bare', 'speed',    {'ctrl', 'OL', 'dist', 0.5});
    add('Bare motor - speed - P + load',          'SIM-W4', 'bare', 'speed',    {'ctrl', 'P', 'Kp', 0.2, 'dist', 0.5});
    add('Bare motor - speed - PI + load',         'SIM-W4', 'bare', 'speed',    {'ctrl', 'PI', 'Kp', 0.05, 'Ki', 1, 'dist', 0.5});
    add('Bare motor - position - P + load',       'SIM-W4', 'bare', 'position', {'ctrl', 'P', 'Kp', 0.3, 'dist', 0.5});
    add('Bare motor - position - PID + load',     'SIM-W4', 'bare', 'position', {'ctrl', 'PID', 'Kp', 0.3, 'Ki', 0.5, 'Kd', 0.01, 'dist', 0.5});

    function add(name, exp, plant, loop, set)
        p(end + 1) = struct('name', name, 'experiment', exp, 'plant', plant, 'loop', loop, 'set', {set});
    end
end
