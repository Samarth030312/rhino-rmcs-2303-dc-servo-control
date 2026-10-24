# Roadmap

| Next | Why |
|---|---|
| Soft stop and the Rhino-software bridge on the rig | both are tested against the emulated drive only |
| Compare the Rhino program's register read-out with DRIVE CHECK, on Windows | proof that both see the same drive ([procedure](docs/RHINO_SOFTWARE.md)) |
| A current measurement at stall (meter in the battery lead) | settles the drive's current limit, 3 A or 5 A (C-M7) |
| Log the battery voltage with every run | removes the largest unknown from the free-speed and torque predictions |
| A delay-aware PI design mission | the textbook design fails on this rig for a known reason; design it with the delay and check on the rig |
| Load experiments (a disc of known inertia, a brake) | the drive's speed loop under load: what the outer loop then has to do |
| Run identification from the app on any user's rig, and share the model | every rig of this kind differs a little |
