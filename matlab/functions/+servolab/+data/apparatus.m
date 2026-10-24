function A = apparatus(code)
%APPARATUS  The rig of this repository: run-id code, data folder, telemetry type, firmware.
%
%   A = servolab.data.apparatus()           % or apparatus('MOTOR')
    all = struct('code', 'MOTOR', 'folder', 'dc_motor', 'tel', 'TEL', 'sketch', 'motor', ...
        'name', 'DC servo (RMCS-2303 + RMCS-5032)');
    if nargin == 0, A = all; return; end
    A = all(strcmpi({all.code}, code));
    assert(~isempty(A), 'servolab:data:apparatus', 'unknown apparatus %s (this repository: MOTOR)', code);
end
