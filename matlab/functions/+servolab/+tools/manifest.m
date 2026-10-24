function M = manifest()
%MANIFEST  Pinned versions of everything the firmware build needs, on every OS.
%
%   M = servolab.tools.manifest()
%
%   One place for the Arduino toolchain: the CLI release and its SHA-256 per
%   platform (from the release's own checksums file, 1.5.1-checksums.txt), the
%   AVR core and the libraries. servolab.tools.install fetches exactly these and
%   refuses a download whose hash differs. Change a version here, and only here.

    M.cli.version = '1.5.1';
    M.cli.base = 'https://downloads.arduino.cc/arduino-cli/';
    M.cli.assets = struct( ...
        'win64',      {{'arduino-cli_1.5.1_Windows_64bit.zip',  'fabe42e0eb04d00e776a66178299ff95a46c623dbc260f997e58fd514853dd40'}}, ...
        'maci64',     {{'arduino-cli_1.5.1_macOS_64bit.tar.gz', 'c982e940027996bea9901050e95fae99c59c1dcfee54beedecaf28141e7bf2e7'}}, ...
        'maca64',     {{'arduino-cli_1.5.1_macOS_ARM64.tar.gz', 'cb952e8c1621c95ef5f1d17831c945e3d0ec5973f89c557a7ec8feb9c4f7d4c9'}}, ...
        'glnxa64',    {{'arduino-cli_1.5.1_Linux_64bit.tar.gz', '28a8e119c498a25607821c36cb2dc49e8463941b261a0d99091baa7bc692dd2b'}}, ...
        'glnxaarm64', {{'arduino-cli_1.5.1_Linux_ARM64.tar.gz', '1e69e077479f300614d4551334e0a33f08ee40b04315d83b8e7e0e94f0d0ee62'}});

    M.core = 'arduino:avr@1.8.8';
    M.fqbn = 'arduino:avr:uno';
    M.libs = {'AltSoftSerial@1.4'};

    % sketch folders, relative to the repository root
    M.sketches = struct('motor', fullfile('firmware', 'motor_controller'));

    % USB vendor / product IDs of the boards this lab meets (hex, lower case)
    M.usb = struct( ...
        'vid', {'2341', '2a03', '1a86', '0403', '10c4'}, ...
        'kind', {'Arduino (genuine)', 'Arduino (genuine, .org)', 'CH340 clone', 'FTDI', 'CP210x'});
end
