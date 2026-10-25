function motor_guide_screenshots()
%MOTOR_GUIDE_SCREENSHOTS  The app pictures in docs/guide/img and results/figures, from the app.
%
%   motor_guide_screenshots()      % needs a display
%
%   Each picture is a mission and preset as docs/guide/README.md describes it; where the guide
%   quotes a rig run, the run of the 2026-10-23 session it quotes is overlaid (OVERLAY RUN).
    root = servolab.repoRoot(); img = fullfile(root, 'docs', 'guide', 'img');
    I = servolab.motor.runIndex(); day = string(I.created, 'yyyy-MM-dd') == "2026-10-23";
    app = rhino_servo_lab(); cl = onCleanup(@() delete(app.fig));
    M = servolab.motor.missions(); tagIx = @(t) find(strcmp({M.tag}, t));
    shot('M5', 1, '', 'lab_start.png');
    shot('M1', 1, run1('ol_step', 1), 'm1_open_loop.png');
    shot('M2', 1, run1('static_map', 1), 'm2_static_map.png');
    shot('M4', 4, run1('speed_i_sweep', 4), 'm4_speed_i.png');
    shot('M5', 1, run1('speed_pi_design', 1), 'm5_speed_pi_rig.png');
    shot('M6', 1, run1('windup', 1), 'm6_windup.png');
    shot('M7', 3, run1('position_p_small', 3), 'm7_position_p.png');
    shot('M10', 3, '', 'm10_armature_load.png');
    copyfile(fullfile(img, 'm5_speed_pi_rig.png'), fullfile(root, 'results', 'figures', 'app_mission_control.png'));

    function id = run1(key, k)
        j = find(day & strcmp(I.key, key) & I.run == k & strcmp(I.result, 'FINISHED'), 1);
        id = I.id{j};
    end
    function shot(tag, preset, id, file)
        app.selectMission(tagIx(tag)); app.setPreset(preset);
        if ~isempty(id), app.overlay(id); end
        drawnow; pause(1.5); drawnow;
        exportapp(app.fig, fullfile(img, file));
        fprintf('%s -> %s\n', tag, file);
    end
end
