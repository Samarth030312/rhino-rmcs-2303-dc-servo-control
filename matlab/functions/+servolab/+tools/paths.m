function P = paths()
%PATHS  Where the project's own Arduino toolchain lives on this computer.
%
%   P = servolab.tools.paths()
%
%   P.root      tool folder (shared by the Arduino lab repositories of this family)
%   P.cli       arduino-cli executable (P.root/arduino-cli/arduino-cli[.exe])
%   P.data, P.downloads, P.user   arduino-cli directories (cores, archives, libraries)
%   P.build     build folder for compiled sketches
%   P.arch      MATLAB's computer('arch'): win64, maci64, maca64, glnxa64, glnxaarm64
%
%   Default root:
%     Windows   %LOCALAPPDATA%\arduino-lab-tools      (C:\arduino-lab-tools if that path is not plain ASCII:
%                                           the AVR compiler fails on non-ASCII paths)
%     macOS     ~/Library/Application Support/arduino-lab-tools
%     Linux     ~/.local/share/arduino-lab-tools
%   Set the environment variable SERVOLAB_TOOLS to use another folder.
%
%   Nothing is written to the global Arduino folders (~/.arduino15, Documents\Arduino),
%   so an Arduino IDE on the same computer is unaffected.

    P.arch = computer('arch');
    root = getenv('SERVOLAB_TOOLS');
    if isempty(root)
        if ispc
            root = fullfile(getenv('LOCALAPPDATA'), 'arduino-lab-tools');
            if isempty(getenv('LOCALAPPDATA')) || any(double(root) > 127)
                root = fullfile(getenv('SystemDrive'), 'arduino-lab-tools');
                if isempty(getenv('SystemDrive')), root = 'C:\arduino-lab-tools'; end
            end
        elseif ismac
            root = fullfile(getenv('HOME'), 'Library', 'Application Support', 'arduino-lab-tools');
        else
            root = fullfile(getenv('HOME'), '.local', 'share', 'arduino-lab-tools');
        end
    end
    P.root = root;
    exe = 'arduino-cli'; if ispc, exe = 'arduino-cli.exe'; end
    P.cli = fullfile(root, 'arduino-cli', exe);
    P.data = fullfile(root, 'arduino', 'data');
    P.downloads = fullfile(root, 'arduino', 'downloads');
    P.user = fullfile(root, 'arduino', 'user');
    P.build = fullfile(root, 'build');
end
