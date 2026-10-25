function p = simulink_note_position(mdl, width)
%SIMULINK_NOTE_POSITION  A note's position just below the blocks of MDL, WIDTH pixels wide.
    pos = cell2mat(get_param(find_system(mdl, 'SearchDepth', 1, 'Type', 'Block'), 'Position'));
    x = min(pos(:, 1)); y = max(pos(:, 4)) + 80;      % below the blocks and the feedback lines under them
    p = [x, y, x + width, y + 30];
end
