function videoFile = recordFrames(fig, nFrames, drawFrame, outDir, fps)
%RECORDFRAMES  Capture an app window frame by frame into <outDir>/simulation.mp4.
%
%   videoFile = servolab.ui.recordFrames(fig, nFrames, @(j) draw(j), outDir, fps)
%
%   drawFrame(j) must update the window for frame j (1..nFrames). Frames are
%   captured with getframe after drawnow. Windows and macOS: written as MPEG-4 by
%   VideoWriter. Linux (no MPEG-4 profile): Motion-JPEG AVI, converted to H.264 MP4
%   with ffmpeg; if ffmpeg fails the AVI is kept and its name returned, with a warning.
%   The file name, size and method are written into <outDir>/run_config.json if
%   that file exists.

    if nargin < 5, fps = 15; end
    if ~isfolder(outDir), mkdir(outDir); end
    native = ispc || ismac;                       % VideoWriter writes MP4 itself there
    if native
        tmp = fullfile(outDir, 'simulation.mp4');
        vw = VideoWriter(tmp, 'MPEG-4'); vw.FrameRate = fps; vw.Quality = 92;
    else
        tmp = [tempname '.avi'];
        vw = VideoWriter(tmp, 'Motion JPEG AVI'); vw.FrameRate = fps; vw.Quality = 92;
    end
    open(vw); cleaner = onCleanup(@() close(vw));
    for j = 1:nFrames
        if ~isvalid(fig), break; end
        drawFrame(j);
        drawnow;
        fr = getframe(fig);
        fr.cdata = fr.cdata(1:2 * floor(end / 2), 1:2 * floor(end / 2), :);   % even size for H.264
        writeVideo(vw, fr);
    end
    clear cleaner;
    if native
        videoFile = tmp;
    else
        mp4 = fullfile(outDir, 'simulation.mp4');
        [st, msg] = system(sprintf('ffmpeg -y -loglevel error -i "%s" -c:v libx264 -pix_fmt yuv420p "%s"', tmp, mp4));
        if st == 0 && isfile(mp4)
            videoFile = mp4; delete(tmp);
        else
            videoFile = fullfile(outDir, 'simulation.avi'); movefile(tmp, videoFile);
            warning('servolab:record:ffmpeg', 'ffmpeg conversion failed, kept AVI: %s', msg);
        end
    end
    servolab.evidence.attachVideo(outDir, videoFile, fps);
end
