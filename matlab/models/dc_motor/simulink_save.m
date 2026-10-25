function simulink_save(mdl, file)
%SIMULINK_SAVE  Save a generated model so that every supported release opens it.
%   MATLAB R2023b is the oldest supported release; a model saved by a newer release does not
%   open in an older one, so on a newer release the saved model is exported to R2023b's format.
    save_system(mdl, file);
    if isMATLABReleaseOlderThan('R2024a'), return; end
    tmp = tempname; mkdir(tmp); cl = onCleanup(@() rmdir(tmp, 's'));
    old = fullfile(tmp, [mdl '.slx']);
    Simulink.exportToVersion(mdl, old, 'R2023b');
    close_system(mdl, 0);
    movefile(old, file, 'f');
end
