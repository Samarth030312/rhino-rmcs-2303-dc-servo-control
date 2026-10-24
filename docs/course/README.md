# Course guide: ENR312 Control Systems Laboratory (Ahmedabad University)

This repository is the DC-motor apparatus of the ENR312 control laboratory. Everything in it
is general; this page is the map from the course's MOTOR handout to the parts of the
repository that let you **do** each task and **find** each answer yourself. It does not give
the answers: the data, the models and the tools do.

## Before the lab

1. Install and open the app ([the sequence](../SEQUENCE.md), steps 1–5); run each mission in
   simulation once. Write down what you expect the rig to do before you see it.
2. Read [how it works](../HOW_IT_WORKS.md): the drive closes its own speed loop, and your
   Arduino controller is an outer loop around it. Most handout questions turn on this.

## The handout, task by task

| Handout | Mission in the app | What to look at |
|---|---|---|
| Section 1, task 1: identify the motor | — | [hardware reference](../hardware/HARDWARE_REFERENCE.md) §1, the label on your motor |
| task 2: the driver | DRIVE CHECK | [hardware reference](../hardware/HARDWARE_REFERENCE.md) §2: modes, registers, scaling |
| task 3: position and speed with the Arduino | M1, M7 | the firmware (`firmware/motor_controller`), the loop letter `S` / `E` / `P` in the data |
| task 4: P, I and PI | M3–M9 | each mission's presets; the SIM / RIG / REF table |
| S3-1 resolution | — | encoder lines, gear ratio: [first principles §3](../FIRST_PRINCIPLES.md#3-the-sampled-outer-loop) |
| S3-2 speed from counts, window, noise | M1 (DRIVE SPEED / ENCODER COUNTS) | the two feedback paths of the same step |
| S3-3 static map, dead zone, saturation | M2 | the map plot; push the command towards the battery's free speed |
| S3-4 K and τ from a step | M1 | the step's shape; is a first-order model adequate? |
| S3-5 position P final error | M7 | the final error in counts for three gains |
| S3-6 loop time | DRIVE CHECK after a run | the firmware's own `micros()` measurement |
| S3-7 Simulink model vs measurements | OPEN IN SIMULINK, identified plant | [Simulink](../SIMULINK.md); overlay a rig run on the model |
| S3-8 more inertia | M10 (inertia factor), and the rig | why the rig and the bare motor answer differently |
| S3-9 I only, damping against Ki | M4 | four gains; compare the textbook ζ with SIM and RIG |
| S3-10 PI designed for ζ 0.7 | M5 | design it on paper first; then SIM, then RIG |
| S3-11 why P stops short | M7 | the final error; what would make it stop short? |
| S3-12 windup | M6 | ANTI-WINDUP on / PLAIN INTEGRATOR in simulation; the rig clamps |
| Assignment 3 (Simulink) | M10 and the identified plant | [Simulink](../SIMULINK.md) |

## Running the rig in a session

Wiring and safety first ([checklist](../safety/EXPERIMENT_CHECKLIST.md)). Then
[the sequence](../SEQUENCE.md) steps 7–10: every run is saved and numbered in
`data/RUN_REGISTER.csv`, so your report can cite run ids. `motor_session_report('<date>')`
turns a session into figures and tables; use them, and explain them in your own words.

## The lab report

The course asks for a summary of the tasks, a description of what you did, your programs, the
answers to the Section 2 and Section 3 questions, screenshots of simulation inputs and
outputs, and a comparison of simulation and hardware with its advantages and limitations.
Cite run ids for every hardware number. Your measurements may differ from the lab's earlier
ones (another battery charge, another day); say how and why.

Live-session steps for the teaching assistant: [checklist](LIVE_SESSION_CHECKLIST.md).
