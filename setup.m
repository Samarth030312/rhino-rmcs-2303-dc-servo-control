function out = setup(varargin)
%SETUP  Get Rhino DC Servo Lab ready on this computer, say what is missing, open the app.
%
%   setup            put the code on the path and check this computer
%   setup open       the same, then open the app (rhino_servo_lab)
%   setup fix        also install the project's Arduino toolchain if it is missing
%                    (about 60 MB, into a folder of your user account; no admin rights)
%   setup probe      also ask a connected board for its firmware ($HELLO)
%
%   Works on Windows, macOS and Linux. The simulation needs only MATLAB R2023b or newer;
%   Simulink is optional. Nothing outside this folder is changed except the tool folder
%   (see servolab.tools.paths) and, with 'save', the MATLAB path.
%       setup save       keep the path for future MATLAB sessions (savepath)
    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, 'matlab', 'setup_path.m'));
    a = lower(string(varargin));
    fprintf('\nRhino DC Servo Lab  ·  %s\n', here);
    r = servolab.doctor('Fix', any(a == "fix" | a == "open"), 'Probe', any(a == "probe"), 'Quiet', ~any(a == "fix" | a == "probe"));
    bad = r(strcmp({r.status}, 'FAIL') | strcmp({r.status}, 'WARN'));
    for k = 1:numel(bad)
        fprintf('  %-4s %s: %s\n', bad(k).status, bad(k).check, bad(k).detail);
        if ~isempty(bad(k).fix), fprintf('       -> %s\n', bad(k).fix); end
    end
    if isempty(bad), fprintf('  All checks passed.\n'); end
    if any(a == "save"), savepath; fprintf('  Path saved for future sessions.\n'); end
    h = [];
    if any(a == "open")
        h = rhino_servo_lab();
    else
        fprintf('  Open the app:  setup open    (or rhino_servo_lab)\n\n');
    end
    if nargout, out = struct('report', r, 'app', h); end
end
