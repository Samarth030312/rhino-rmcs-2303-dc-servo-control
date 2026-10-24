function [u, st, sat] = pidStep(st, e, g)
%PIDSTEP  One sample of the discrete P / I / PI / PID law the Arduino runs.
%
%   [u, st, sat] = servolab.motor.pidStep(st, e, g)
%
%   st  state struct from pidInit (integrator, filtered derivative, last error)
%   e   error this sample, e = setpoint - measurement
%   g   struct: Kp, Ki, Kd, Tf (derivative filter time constant, s), Ts, uMax
%
%   u_k   = Kp e_k + I_k + D_k, clipped to +/- uMax
%   I_k   = I_{k-1} + Ki Ts e_k               (backward Euler)
%   D_k   = (Tf D_{k-1} + Kd (e_k - e_{k-1})) / (Tf + Ts)
%
%   Anti-windup: clamping. When the output saturates and the error pushes
%   further into saturation, the integrator is advanced only until the output
%   reaches the limit, and is never pulled back by a large P term. The
%   firmware must implement exactly this, in this order.

    if st.first
        d = 0;                                   % no derivative kick on sample 1
    else
        d = (g.Tf * st.d + g.Kd * (e - st.e)) / (g.Tf + g.Ts);
    end
    iNew = st.i + g.Ki * g.Ts * e;
    uRaw = g.Kp * e + iNew + d;
    u = min(max(uRaw, -g.uMax), g.uMax);
    sat = u ~= uRaw;
    if sat && sign(uRaw) == sign(e) && g.Ki ~= 0
        % integrate only as far as the limit, and never unwind it because of P
        pd = g.Kp * e + d;
        iNew = min(max(iNew, -g.uMax - pd), g.uMax - pd);
        if (e > 0 && iNew < st.i) || (e < 0 && iNew > st.i), iNew = st.i; end
        u = min(max(pd + iNew, -g.uMax), g.uMax);
    end
    st.i = iNew; st.d = d; st.e = e; st.first = false;
end
