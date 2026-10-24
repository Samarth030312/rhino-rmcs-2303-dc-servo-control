function s = schema(type)
%SCHEMA  Field list of a telemetry frame type (docs/architecture/SERIAL_PROTOCOL.md).
%
%   s = servolab.protocol.schema('TEL' | 'TTEL' | 'LTEL')
%   s.names  field names after the version
%   s.kinds  'num' | 'hex' | cell of allowed strings
%   s.flags  bit names, bit 0 first
%
%   TEL   DC motor          (firmware/motor_controller)
%   TTEL  temperature       (temperature/firmware/temperature_controller)
%   LTEL  water level       (water_level/firmware/level_controller)

    switch upper(type)
        case 'TEL'
            s.names = {'seq', 't_ms', 'loop', 'ctrl', 'setpoint', 'meas', 'err', 'u', ...
                       'pos_counts', 'spd_base_rpm', 'flags'};
            s.kinds = {'num', 'num', {'S', 'E', 'P'}, {'OL', 'P', 'I', 'PI', 'PID'}, 'num', 'num', 'num', 'num', ...
                       'num', 'num', 'hex'};
            s.flags = {'RUNNING', 'SATURATED', 'MODBUS_TIMEOUT', 'MODBUS_LRC_ERROR', 'ESTOPPED', ...
                       'SPEED_CLAMPED', 'WATCHDOG_STOP', 'OVERRUN'};
        case 'TTEL'
            s.names = {'seq', 't_ms', 'mode', 'setpoint', 'temp_raw', 'temp_filt', 'err', 'u', ...
                       'heater', 'flags'};
            s.kinds = {'num', 'num', {'ONOFF', 'HYST', 'MA', 'P', 'TPROP', 'STEP', 'PI'}, 'num', 'num', 'num', 'num', 'num', ...
                       'num', 'hex'};
            s.flags = {'RUNNING', 'SENSOR_FAIL', 'OVERTEMP_CUTOFF', 'WATCHDOG_STOP', 'BUTTON_STOP'};
        case 'LTEL'
            s.names = {'seq', 't_ms', 'mode', 'setpoint', 'level_cm', 'level_pct', 'err', 'u', ...
                       'pump', 'flags'};
            s.kinds = {'num', 'num', {'ONOFF', 'P', 'PI'}, 'num', 'num', 'num', 'num', 'num', ...
                       'num', 'hex'};
            s.flags = {'RUNNING', 'SENSOR_FAIL', 'OVERFLOW_GUARD', 'DRYRUN_GUARD', 'WATCHDOG_STOP', 'BUTTON_STOP'};
        otherwise
            error('servolab:protocol:type', 'unknown telemetry type ''%s''', type);
    end
end
