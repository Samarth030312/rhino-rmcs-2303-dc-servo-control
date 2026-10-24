function attachVideo(runDir, videoFile, fps)
%ATTACHVIDEO  Record a video's name, size and capture method in run_config.json.
    f = fullfile(runDir, 'run_config.json');
    if ~isfile(f), return; end
    meta = jsondecode(fileread(f));
    d = dir(videoFile);
    meta.video = struct('file', d.name, 'bytes', d.bytes, 'fps', fps, ...
        'method', 'MATLAB getframe of the app window, converted with ffmpeg', ...
        'note', 'Frames are the app''s own rendering of the simulation, captured while it ran. Not a hardware recording.');
    fid = fopen(f, 'w'); fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true)); fclose(fid);
end
