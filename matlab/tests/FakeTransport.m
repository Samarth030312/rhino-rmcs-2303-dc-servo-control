classdef FakeTransport < handle
%FAKETRANSPORT  Stands in for serialport in tests: queued input, recorded output.
    properties
        inbox = strings(0, 1)      % lines the "Arduino" will send
        sent = strings(0, 1)       % lines the host wrote
    end
    properties (Dependent)
        NumBytesAvailable
    end
    methods
        function n = get.NumBytesAvailable(obj)
            n = sum(strlength(obj.inbox) + 1);
        end
        function writeline(obj, line)
            obj.sent(end + 1) = string(line);
        end
        function line = readline(obj)
            line = obj.inbox(1); obj.inbox(1) = [];
        end
        function push(obj, varargin)
            for k = 1:numel(varargin), obj.inbox(end + 1) = string(varargin{k}); end
        end
    end
end
