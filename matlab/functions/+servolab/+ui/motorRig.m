function rig = motorRig(ax)
%MOTORRIG  3-D model of the DC-motor rig, true to size, for the mission-control app.
%
%   rig = servolab.ui.motorRig(ax)                     % ax: uiaxes
%   servolab.ui.motorRigPose(rig, angleDeg, speedRpm, opts)
%
%   Dimensions (metres in the code, mm below) and their sources:
%     RMCS-5032 (datasheet mechanical drawing, SRC-003): output shaft D6 x 12 with a D-flat,
%       mounting boss D20 x 3 with 4 x M3 holes, planetary gearbox D32 x 32, motor section 51
%       long (neck D27.6, can D30, encoder end 14.5).
%     Arduino Uno Rev3 (SRC-004): board 68.6 x 53.4, USB-B and barrel-jack positions.
%     RMCS-2303 (manual photo p.4, SRC-002): square board, 10-way green terminal block
%       (pins 8-17, 5.08 mm pitch), 7-way white header (pins 1-7), two electrolytics.
%       Board 67 x 56 x 13 (Robokits product page, SRC-018); the lab unit's board is black
%       (owner, 2026-10-25).
%     Battery: Pro-Range INR18650 3S2P 4400 mAh (SRC-016): six 18650 cells (D18.5 x 65) in
%       blue sleeve; drawn as a 3 x 2 stack, 65 x 56 x 37 (the cell layout is ASSUMED).
%     The indicator disc on the shaft (D44) is a display aid, not part of the rig.
%   Cables in the lab's colours (DC_MOTOR_WIRING.md). The disc turns with the angle; a ring
%   shows |speed| out of 180 rpm with the setpoint as a tick.

    K = servolab.ui.palette();
    hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off');
    ax.Color = 'none'; ax.Clipping = 'off';
    try, ax.Toolbar.Visible = 'off'; catch, end
    try, disableDefaultInteractivity(ax); catch, end
    view(ax, 52, 20);
    xlim(ax, [-0.125 0.105]); ylim(ax, [-0.105 0.095]); zlim(ax, [0 0.075]);

    can = [0.70 0.72 0.76]; gear = [0.62 0.64 0.67]; dark = [0.09 0.10 0.12];
    pcbG = [0.05 0.38 0.20]; pcbB = [0.00 0.44 0.55]; alu = [0.78 0.80 0.83]; blk = [0.06 0.06 0.07];

    zB = 0.006;                                                      % top of the base plate
    zA = zB + 0.030;                                                 % shaft axis height
    box3([-0.010 0 zB / 2], [0.235 0.200 zB], [0.13 0.14 0.17], ax); % base plate (display)
    % L-bracket at the mounting face
    box3([-0.0055 0 zB + 0.024], [0.004 0.046 0.048], alu * 0.85, ax);
    box3([-0.0180 0 zB + 0.0015], [0.025 0.046 0.003], alu * 0.85, ax);
    % RMCS-5032, front face at x = 0, body towards -x
    cyl3([-0.003 0 zA], 0.010, 0.003, gear * 1.05, ax);              % boss D20 x 3
    cyl3([-0.035 0 zA], 0.016, 0.032, gear, ax);                     % gearbox D32 x 32
    cyl3([-0.0425 0 zA], 0.0138, 0.0075, can * 0.9, ax);             % neck D27.6
    cyl3([-0.0715 0 zA], 0.015, 0.029, can, ax);                     % can D30 x 29
    cyl3([-0.0860 0 zA], 0.015, 0.0145, dark, ax);                   % encoder end x 14.5
    cyl3([0 0 zA], 0.003, 0.012, alu, ax);                           % shaft D6 x 12
    for a = 45:90:315                                                % 4 x M3 on the face
        cyl3([-0.0005 0.0085 * cosd(a) zA + 0.0085 * sind(a)], 0.0013, 0.0006, blk, ax);
    end

    % indicator disc on the shaft: rotates with the output angle (about the x axis)
    rig.disc = hgtransform('Parent', ax);
    xD = 0.008; R = 0.022;
    cyl3([xD 0 0], R, 0.003, [0.16 0.18 0.22], rig.disc);
    for a = 0:30:330
        L = 0.003 + 0.002 * (mod(a, 90) == 0);
        plot3(rig.disc, [1 1] * (xD + 0.0035), -[R - 0.002, R - 0.002 - L] * sind(a), [R - 0.002, R - 0.002 - L] * cosd(a), ...
              '-', 'Color', K.dim, 'LineWidth', 1 + (mod(a, 90) == 0));
    end
    rig.marker = patch(rig.disc, 'XData', [1 1 1 1] * (xD + 0.0038), 'YData', [-0.0022 0.0022 0.0022 -0.0022], ...
        'ZData', [0.004 0.004 R - 0.003 R - 0.003], 'FaceColor', K.orange, 'EdgeColor', 'none');
    cyl3([xD + 0.003 0 0], 0.005, 0.003, alu, rig.disc);
    rig.disc.Matrix = makehgtform('translate', [0 0 zA]);
    rig.trail = patch(ax, 'XData', nan, 'YData', nan, 'ZData', nan, 'FaceColor', K.cyan, ...
        'FaceAlpha', 0.22, 'EdgeColor', 'none');
    rig.ref = plot3(ax, nan, nan, nan, '--', 'Color', K.text, 'LineWidth', 1.6);
    Rr = R + 0.005;
    th = linspace(0, 2 * pi, 121);
    plot3(ax, (xD + 0.004) * ones(size(th)), Rr * cos(th), zA + Rr * sin(th), '-', 'Color', K.line, 'LineWidth', 3);
    rig.ring = plot3(ax, nan, nan, nan, '-', 'Color', K.cyan, 'LineWidth', 4);
    rig.ringSp = plot3(ax, nan, nan, nan, '-', 'Color', K.text, 'LineWidth', 3.5);
    rig.xRing = xD + 0.0045; rig.zA = zA; rig.xFace = xD + 0.0036; rig.R = R; rig.Rr = Rr;

    % RMCS-2303 drive (front left)
    cD = [-0.062 -0.062]; zP = zB + 0.008;                            % on 8 mm standoffs
    box3([cD zP], [0.067 0.056 0.0016], blk * 1.6, ax);              % black board (lab unit)
    box3([cD(1) cD(2) + 0.022 zP + 0.006], [0.051 0.010 0.011], [0.10 0.55 0.25], ax);   % terminals 8-17
    for k = 0:9, cyl3([cD(1) - 0.0229 + k * 0.00508, cD(2) + 0.022, zP + 0.0115], 0.0012, 0.0003, alu, ax); end
    box3([cD(1) - 0.020 cD(2) - 0.012 zP + 0.004], [0.006 0.018 0.007], [0.92 0.92 0.90], ax); % header 1-7
    cylZ([cD(1) + 0.012 cD(2) - 0.008 zP], 0.004, 0.010, blk, ax);    % electrolytics
    cylZ([cD(1) + 0.020 cD(2) - 0.008 zP], 0.004, 0.010, blk, ax);
    box3([cD(1) - 0.004 cD(2) zP + 0.0015], [0.010 0.010 0.0014], blk, ax);              % ICs
    box3([cD(1) + 0.010 cD(2) + 0.008 zP + 0.0015], [0.008 0.006 0.0014], blk, ax);
    % Arduino Uno Rev3 (front right), 68.6 x 53.4
    cU = [0.060 -0.064];
    box3([cU zP], [0.0686 0.0534 0.0016], pcbB, ax);
    box3([cU(1) - 0.0300 cU(2) + 0.012 zP + 0.0063], [0.016 0.012 0.011], alu * 0.9, ax); % USB-B
    box3([cU(1) - 0.0290 cU(2) - 0.015 zP + 0.0063], [0.014 0.009 0.011], blk, ax);       % barrel jack
    box3([cU(1) + 0.010 cU(2) - 0.006 zP + 0.002], [0.035 0.0075 0.003], blk, ax);       % ATmega328P
    box3([cU(1) + 0.004 cU(2) + 0.0245 zP + 0.004], [0.055 0.0025 0.0085], blk, ax);     % header rows
    box3([cU(1) + 0.008 cU(2) - 0.0245 zP + 0.004], [0.045 0.0025 0.0085], blk, ax);
    % battery pack (behind, left)
    cB = [-0.070 0.062 zB + 0.0185];                                   % centre of the 3 x 2 cell stack
    sleeve = [0.10 0.32 0.78];
    for iy = -1:1
        for iz = 0:1
            cyl3([cB(1) - 0.0325, cB(2) + iy * 0.0185, zB + 0.00925 + iz * 0.0185], 0.00925, 0.065, sleeve, ax);
        end
    end
    box3([cB(1) + 0.0335 cB(2) cB(3)], [0.002 0.056 0.037], [0.85 0.85 0.85], ax);  % nickel strip / BMS end

    % cables: battery -> drive 16/17, drive 14/15 -> motor, encoder 8-11, Uno D8/D9/GND -> drive 1-3
    tb = [cD(1) cD(2) + 0.022 zP + 0.012];
    cable(ax, [cB + [0.020 -0.028 0]; -0.070 0.010 0.030; tb + [0.020 0 0]], [0.85 0.15 0.15], 2.4);
    cable(ax, [cB + [0.028 -0.028 0]; -0.060 0.010 0.028; tb + [0.024 0 0]], [0.15 0.15 0.15], 2.4);
    cable(ax, [tb + [0.012 0 0]; -0.040 -0.020 0.045; -0.060 -0.008 zA - 0.010], [0.15 0.65 0.30], 1.8);
    cable(ax, [tb + [0.016 0 0]; -0.036 -0.020 0.047; -0.060 -0.004 zA - 0.012], [0.95 0.85 0.20], 1.8);
    cable(ax, [tb + [-0.015 0 0]; -0.090 -0.030 0.040; -0.0865 -0.010 zA - 0.006], [0.85 0.15 0.15], 1.0);
    cable(ax, [tb + [-0.010 0 0]; -0.086 -0.030 0.042; -0.0865 -0.006 zA - 0.010], [0.95 0.55 0.15], 1.0);
    hdr = [cD(1) - 0.020 cD(2) - 0.012 zP + 0.008];
    cable(ax, [hdr; 0.000 -0.075 0.030; cU + [-0.010 0.0245] zP + 0.009], [0.25 0.45 0.95], 1.2);
    cable(ax, [hdr + [0 0.003 0]; 0.000 -0.070 0.032; cU + [-0.007 0.0245] zP + 0.009], [0.20 0.70 0.30], 1.2);
    cable(ax, [hdr + [0 -0.003 0]; 0.000 -0.080 0.028; cU + [-0.013 0.0245] zP + 0.009], [0.10 0.10 0.10], 1.2);

    lab = @(p, s) text(ax, p(1), p(2), p(3), s, 'Color', K.dim, 'FontSize', 9, 'HorizontalAlignment', 'center');
    rig.labels = [lab([cD zP + 0.030], 'RMCS-2303'), lab([cU zP + 0.022], 'Arduino Uno'), ...
                  lab([-0.045 0 zA + 0.026], 'RMCS-5032  100:1'), lab(cB + [0 0 0.026], '3S2P Li-ion 11.1 V 4400 mAh')];
    light(ax, 'Position', [0.8 -0.6 1.0]); light(ax, 'Position', [-0.5 0.5 0.6], 'Color', [0.35 0.35 0.40]);
    rig.prev = 0;
    servolab.ui.motorRigPose(rig, 0, 0);
end

function box3(c, d, col, parent)
    [X, Y, Z] = ndgrid([-1 1] * d(1) / 2, [-1 1] * d(2) / 2, [-1 1] * d(3) / 2);
    V = [X(:) Y(:) Z(:)] + c;
    F = [1 2 4 3; 5 6 8 7; 1 2 6 5; 3 4 8 7; 1 3 7 5; 2 4 8 6];
    shade = [0.70 0.70 0.86 0.86 0.78 1.00]';
    patch('Vertices', V, 'Faces', F, 'FaceVertexCData', min(1, shade * col), 'FaceColor', 'flat', ...
          'EdgeColor', col * 0.5, 'LineWidth', 0.5, 'FaceLighting', 'none', 'Parent', parent);
end

function cyl3(base, rad, len, col, parent)
%CYL3  Cylinder along +x from base, closed at both ends.
    [Y, Z, X] = cylinder(rad, 36); X = X * len;
    surf(X + base(1), Y + base(2), Z + base(3), 'FaceColor', col, 'EdgeColor', 'none', ...
         'FaceLighting', 'gouraud', 'AmbientStrength', 0.5, 'SpecularStrength', 0.6, 'Parent', parent);
    th = linspace(0, 2 * pi, 37);
    for e = [0 len]
        patch(base(1) + e + 0 * th, base(2) + rad * cos(th), base(3) + rad * sin(th), col * 0.92, ...
              'EdgeColor', 'none', 'FaceLighting', 'gouraud', 'Parent', parent);
    end
end

function cylZ(base, rad, len, col, parent)
%CYLZ  Upright cylinder (capacitor) from base, along +z.
    [X, Y, Z] = cylinder(rad, 24); Z = Z * len;
    surf(X + base(1), Y + base(2), Z + base(3), 'FaceColor', col, 'EdgeColor', 'none', 'FaceLighting', 'gouraud', 'Parent', parent);
    th = linspace(0, 2 * pi, 25);
    patch(base(1) + rad * cos(th), base(2) + rad * sin(th), base(3) + len + 0 * th, col * 1.6 + 0.1, 'EdgeColor', 'none', 'Parent', parent);
end

function cable(ax, P, col, w)
    t = linspace(0, 1, 24)';
    B = (1 - t).^2 .* P(1, :) + 2 * (1 - t) .* t .* P(2, :) + t.^2 .* P(3, :);   % quadratic Bezier
    plot3(ax, B(:, 1), B(:, 2), B(:, 3), '-', 'Color', col, 'LineWidth', w);
end
