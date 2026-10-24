#!/usr/bin/env python3
"""Draw the DC-motor circuit diagram and power diagram (PNG + SVG).

    python3 scripts/reports/draw_dc_motor_diagrams.py
    -> docs/wiring/figures/dc_motor_circuit.{png,svg}, dc_motor_power.{png,svg}

The pin plan is the one in docs/wiring/DC_MOTOR_WIRING.md and the firmware
firmware/motor_controller. Change all three together.
"""
import pathlib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "wiring" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

NAVY, GREY, RED, BLUE, GREEN = "#17294a", "#6b6f76", "#c62e29", "#2962c8", "#21974f"
WIRE = {"black": "#111111", "brown": "#7b4a12", "red": "#d62020", "orange": "#f08c00", "white": "#b8b8b8",
        "yellow": "#e0c000", "green": "#1f9a3a", "blue": BLUE, "grey": GREY, "purple": "#6a3fa8"}


def box(ax, x, y, w, h, title, sub="", fc="#eef2fa", ec=NAVY):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.15",
                                fc=fc, ec=ec, lw=1.8))
    ax.text(x + w / 2, y + h - 0.35, title, ha="center", va="top", fontsize=12, weight="bold", color=NAVY)
    if sub:
        ax.text(x + w / 2, y + h - 0.85, sub, ha="center", va="top", fontsize=8.5, color=GREY)


def pin(ax, x, y, label, side):
    ax.plot([x], [y], "o", ms=5, color=NAVY, zorder=5)
    if side == "r":
        ax.text(x - 0.12, y, label, ha="right", va="center", fontsize=8.5, family="monospace")
    else:
        ax.text(x + 0.12, y, label, ha="left", va="center", fontsize=8.5, family="monospace")


def wire(ax, pts, color, lw=2.2, label=None, lx=None, ly=None, ls="-"):
    xs, ys = zip(*pts)
    ax.plot(xs, ys, ls, color=color, lw=lw, solid_capstyle="round", zorder=3)
    if label:
        ax.text(lx, ly, label, fontsize=8, color=color if color not in (WIRE["yellow"],) else "#8a7600",
                ha="center", va="bottom", weight="bold",
                bbox=dict(fc="white", ec="none", pad=0.5, alpha=0.85))


def circuit():
    fig, ax = plt.subplots(figsize=(17, 10.5))
    ax.set_xlim(0, 34); ax.set_ylim(0, 21); ax.axis("off")
    ax.text(0.3, 20.6, "Rhino DC servo  -  circuit diagram", fontsize=17, weight="bold", color=NAVY, va="top")
    ax.text(0.3, 19.8, "Arduino Uno  ->  Robokits RMCS-2303 drive (Modbus ASCII, 9600 8N1)  ->  Robokits RMCS-5032 motor "
                       "(12 V, 100:1, 5200 counts/rev).   Wire by PIN NUMBER on the drive silkscreen.",
            fontsize=10, color=GREY, va="top")

    # ---------------- Arduino
    box(ax, 1, 6, 6, 11, "Arduino Uno", "USB: power + MATLAB link", fc="#e3f1f3", ec="#0a7a86")
    ua = {"D9 (TX, AltSoftSerial)": 15.0, "D8 (RX, AltSoftSerial)": 13.8, "GND": 12.6, "D4 (STOP button)": 10.2,
          "D13 (LED: running)": 8.6}
    for k, y in ua.items():
        pin(ax, 7, y, k, "r")
    ax.text(4, 6.5, "do NOT connect 12 V\nto any Uno pin", ha="center", fontsize=8.5, color=RED)

    # ---------------- STOP button
    ax.plot([7, 8.5], [10.2, 10.2], color=WIRE["purple"], lw=2.2)
    ax.plot([8.5, 9.2], [10.2, 10.6], color=NAVY, lw=2.2)
    ax.plot([9.3, 10.0], [10.2, 10.2], color=WIRE["purple"], lw=2.2)
    ax.plot([10.0, 10.0, 7.6], [10.2, 9.3, 9.3], color=WIRE["black"], lw=2.2)
    ax.text(9.25, 10.75, "STOP push-button\n(normally open)", ha="center", fontsize=8.5)
    ax.text(8.3, 9.0, "to Uno GND", fontsize=8, color=GREY)

    # ---------------- Drive
    box(ax, 13, 3, 7.5, 15, "RMCS-2303 drive", "lab drive answers as slave id 7 (firmware scans 11, 7, 1-6)", fc="#f1eefa", ec=NAVY)
    left = {"2  RXD": 15.0, "3  TXD": 13.8, "1  GND": 12.6}
    for k, y in left.items():
        pin(ax, 13, y, k, "l")
    right = {"9  +5 V (encoder)": 15.6, "8  GND (encoder)": 14.6, "11 ENC_A": 13.6, "10 ENC_B": 12.6,
             "15 Motor+": 10.6, "14 Motor-": 9.6, "16 VDD (+12 V)": 6.4, "17 GND (0 V)": 5.2}
    for k, y in right.items():
        pin(ax, 20.5, y, k, "r")
    ax.text(16.75, 4.0, "pins 4-7 (ENA/ADC/DIR/BRK)\nleave unconnected", ha="center", fontsize=8, color=GREY)

    wire(ax, [(7, 15.0), (13, 15.0)], WIRE["blue"], label="Uno TX -> drive RXD", lx=10, ly=15.1)
    wire(ax, [(7, 13.8), (13, 13.8)], WIRE["green"], label="drive TXD -> Uno RX", lx=10, ly=13.9)
    wire(ax, [(7, 12.6), (13, 12.6)], WIRE["black"], label="common GND (mandatory)", lx=10, ly=12.7)

    # ---------------- Motor
    box(ax, 26, 8, 6.8, 9.5, "RMCS-5032 motor", "12 V, 180 rpm out, 15 kgf.cm rated", fc="#fff4e5", ec="#b06a00")
    mpins = {"Blue   +5 V": 15.6, "Green  GND": 14.6, "White  EncA": 13.6, "Yellow EncB": 12.6,
             "Red (thin) Motor+": 10.6, "Black (thin) Motor-": 9.6}
    for k, y in mpins.items():
        pin(ax, 26, y, k, "l")
    colors = ["blue", "green", "white", "yellow", "red", "black"]
    for (k, y), c in zip(mpins.items(), colors):
        wire(ax, [(20.5, y), (26, y)], WIRE[c])
    ax.text(29.4, 8.45, "Colours of the LAB motor cable (verified 2026-10-11).\nDatasheet colours differ: wire by pin function.\n"
                        "Wrong direction? swap ONE pair (14/15 or 10/11).", ha="center", fontsize=7.8, color=RED)

    # ---------------- Supply
    box(ax, 26, 1.0, 6.8, 5.6, "12 V DC supply", ">= 5 A, or bench PSU\n12.0 V, current limit 4 A", fc="#fdecec", ec=RED)
    pin(ax, 26, 5.0, "+12 V", "l"); pin(ax, 26, 2.2, "0 V", "l")
    wire(ax, [(20.5, 6.4), (22.0, 6.4)], RED, lw=3)
    ax.add_patch(FancyBboxPatch((22.0, 6.1), 1.2, 0.6, boxstyle="round,pad=0.02", fc="white", ec=RED, lw=1.5))
    ax.text(22.4, 5.3, "fuse 5 A T\n(slow-blow)", ha="center", fontsize=8, color=RED)
    wire(ax, [(23.2, 6.4), (24.0, 6.4)], RED, lw=3)
    ax.plot([24.0, 24.7], [6.4, 6.9], color=NAVY, lw=2.5)
    ax.text(24.6, 7.6, "ON/OFF switch\n(emergency stop)", ha="center", fontsize=8, color=NAVY)
    wire(ax, [(24.8, 6.4), (25.3, 6.4), (25.3, 5.0), (26, 5.0)], RED, lw=3)
    wire(ax, [(20.5, 5.2), (21.4, 5.2), (21.4, 2.2), (26, 2.2)], WIRE["black"], lw=3)
    ax.text(23.5, 1.9, "0.75 mm^2 (18 AWG) for supply and motor leads", ha="center", fontsize=8, color=GREY)

    # ---------------- legend
    ax.text(1, 4.6, "Signal wires: jumper wires, < 30 cm, twisted with their GND if possible.", fontsize=9)
    ax.text(1, 3.9, "Power-up order: Uno on USB first, then switch on 12 V. Power-down: 12 V off first.", fontsize=9)
    ax.text(1, 3.2, "Firmware: firmware/motor_controller   Upload: scripts/setup/upload motor", fontsize=9, family="monospace")
    ax.text(1, 2.5, "Verified on the lab rig 2026-10-11 (11.2 V battery, slave id 7); see docs/wiring/DC_MOTOR_WIRING.md.", fontsize=9, color=RED)
    for ext in ("png", "svg"):
        fig.savefig(OUT / f"dc_motor_circuit.{ext}", dpi=130, bbox_inches="tight")
    plt.close(fig)


def power():
    fig, ax = plt.subplots(figsize=(17, 8.5))
    ax.set_xlim(0, 34); ax.set_ylim(0, 17); ax.axis("off")
    ax.text(0.3, 16.6, "Rhino DC servo  -  power diagram and budget", fontsize=17, weight="bold", color=NAVY, va="top")
    ax.text(0.3, 15.8, "Two separate supplies, one common ground at the drive's logic GND. Values: datasheet (D) or model estimate (E).",
            fontsize=10, color=GREY, va="top")
    # chain 1: mains -> PSU -> fuse -> switch -> drive -> motor
    box(ax, 0.5, 9, 4.5, 4, "Mains", "230 V AC 50 Hz\n(wall socket)", fc="#fdecec", ec=RED)
    box(ax, 6.5, 9, 5, 4, "12 V DC PSU", "rating >= 12 V 5 A (60 W)\nor bench PSU, limit 4 A", fc="#fdecec", ec=RED)
    box(ax, 13, 9.6, 3.2, 2.8, "Fuse", "5 A slow-blow", fc="white", ec=RED)
    box(ax, 17.4, 9.6, 3.2, 2.8, "Switch", "within reach\n= E-stop", fc="white", ec=NAVY)
    box(ax, 22, 9, 5, 4, "RMCS-2303", "10-30 V in (D)\n3 A peak phase (D)", fc="#f1eefa", ec=NAVY)
    box(ax, 28.5, 9, 5, 4, "RMCS-5032", "12 V nominal (D)\n0.8 A no-load (D)", fc="#fff4e5", ec="#b06a00")
    for x0, x1 in [(5, 6.5), (11.5, 13), (16.2, 17.4), (20.6, 22), (27, 28.5)]:
        ax.annotate("", xy=(x1, 11), xytext=(x0, 11), arrowprops=dict(arrowstyle="-|>", color=RED, lw=2.5))
    ax.text(12.25, 11.3, "12 V", fontsize=9, color=RED, ha="center")
    ax.text(27.75, 11.3, "PWM\n0-12 V", fontsize=8.5, color=RED, ha="center")
    # chain 2: laptop -> USB -> Uno -> signals
    box(ax, 15.5, 2.5, 5, 3.5, "Laptop USB", "5 V, <= 500 mA", fc="#e3f1f3", ec="#0a7a86")
    box(ax, 22, 2.5, 5, 3.5, "Arduino Uno", "~50 mA (E)\nlogic 5 V", fc="#e3f1f3", ec="#0a7a86")
    ax.annotate("", xy=(22, 4.25), xytext=(20.5, 4.25), arrowprops=dict(arrowstyle="-|>", color="#0a7a86", lw=2.5))
    ax.annotate("", xy=(24.5, 9), xytext=(24.5, 6.0), arrowprops=dict(arrowstyle="<|-|>", color=BLUE, lw=1.8))
    ax.text(24.2, 7.0, "Modbus TX/RX\n+ common GND\n(signals only)", fontsize=8.5, color=BLUE, ha="right")
    ax.annotate("", xy=(29.5, 9), xytext=(26.5, 9), arrowprops=dict(arrowstyle="-|>", color=GREEN, lw=1.5,
                connectionstyle="arc3,rad=0.4"))
    ax.text(28.1, 7.9, "encoder 5 V\nfrom drive pin 9", fontsize=8, color=GREEN, ha="center")

    rows = [("Supply voltage", "12 V DC", "motor nominal 12 V (D); drive accepts 10-30 V (D); 24 V would over-speed (C-M6)"),
            ("Supply rating", ">= 5 A (60 W)", "drive limits motor current to 3 A peak (D) -> 36 W max; margin for start-up"),
            ("Fuse", "5 A slow-blow, + lead", "protects the 0.75 mm^2 leads; product page lists the drive as '10 A' (C-M7)"),
            ("Motor current, no load", "0.4-0.8 A", "0.8 A at 18000 rpm base (D); ~0.45 A at 100 rpm output (E)"),
            ("Motor current, rated 15 kgf.cm", "~3 A", "reaches the drive's 3 A limit (E) -> about 17 kgf.cm max through this drive"),
            ("Motor stall current", "up to 7.5 A (D)", "not reachable: drive limits to 3 A"),
            ("Uno", "5 V USB, ~50 mA", "never powered from the 12 V rail in this set-up"),
            ("Wire", "0.75 mm^2 power, jumpers signal", "keep power leads short; signal wires away from motor leads")]
    y = 1.6
    ax.text(0.5, 7.4, "Budget", fontsize=12, weight="bold", color=NAVY)
    for i, (a, b, c) in enumerate(rows):
        yy = 6.8 - i * 0.62 if i < 9 else y
        ax.text(0.5, yy, a, fontsize=8.8, weight="bold")
        ax.text(7.2, yy, b, fontsize=8.8, color=RED if "A" in b or "V" in b else NAVY)
    ax.text(0.5, 1.2, "Right-hand notes per row are in docs/wiring/DC_MOTOR_WIRING.md section 3.", fontsize=8.5, color=GREY)
    for ext in ("png", "svg"):
        fig.savefig(OUT / f"dc_motor_power.{ext}", dpi=130, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    circuit()
    power()
    print("wrote", *sorted(p.name for p in OUT.glob("dc_motor_*")))
