#!/usr/bin/env python3
"""Analyse one DC-motor hardware run (raw CSV + metadata) and write a figure and a report.

    python3 scripts/reports/analyze_motor_run.py data/raw/dc_motor/<run_id>.csv [--lpr-in-drive N]

Raw data is read only. Outputs:
    data/processed/dc_motor/<run_id>_analysis.csv   per-setpoint segment statistics
    results/figures/dc_motor/<run_id>_analysis.png  measured vs commanded, corrected for LPR
    docs/experiments/dc_motor/<run_id>_ANALYSIS.md   findings

--lpr-in-drive: the drive's Lines-per-Rotation register during the run (read with Drive check).
The drive computes rpm from it, so a wrong LPR scales every speed reading by LPR/13.
"""
import argparse, csv, json, pathlib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = pathlib.Path(__file__).resolve().parents[2]
LPR_TRUE = 13          # RMCS-5032: 13 lines per base revolution (SRC-003)
GEAR = 100.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--lpr-in-drive", type=int, default=LPR_TRUE)
    ap.add_argument("--reference-speed", type=float, default=None,
                    help="output rpm measured in another run with correct LPR, for the cross-check")
    a = ap.parse_args()
    raw = pathlib.Path(a.csv).resolve()
    run_id = raw.stem
    meta = json.loads((ROOT / "data" / "metadata" / "dc_motor" / f"{run_id}.json").read_text())
    rows = list(csv.DictReader(raw.open()))
    t = [float(r["t_s"]) for r in rows]
    sp = [float(r["setpoint"]) for r in rows]
    u = [float(r["u"]) for r in rows]
    base = [float(r["spd_base_rpm"]) for r in rows]
    scale = a.lpr_in_drive / LPR_TRUE                   # drive's rpm reading is too small by this factor
    reported = [b / GEAR for b in base]                 # output rpm as the app showed it
    true = [b * scale / GEAR for b in base]             # output rpm after the LPR correction

    # segments of constant setpoint
    segs, start = [], 0
    for i in range(1, len(rows) + 1):
        if i == len(rows) or sp[i] != sp[start]:
            idx = range(start, i)
            tr = [true[k] for k in idx]
            segs.append(dict(t0=t[start], t1=t[i - 1], setpoint=sp[start], n=len(idx),
                             reported_mean=sum(reported[k] for k in idx) / len(idx),
                             true_mean=sum(tr) / len(tr), true_min=min(tr), true_max=max(tr)))
            start = i
    revs = sum(abs(true[k]) * (t[k] - t[k - 1]) for k in range(1, len(t))) / 60.0
    out_csv = ROOT / "data" / "processed" / "dc_motor" / f"{run_id}_analysis.csv"
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(segs[0].keys())); w.writeheader(); w.writerows(segs)

    fig, ax = plt.subplots(2, 1, figsize=(11, 7.5), sharex=True)
    ax[0].step(t, sp, where="post", color="#21974f", lw=2, label="commanded setpoint")
    ax[0].plot(t, reported, color="#9aa0a6", lw=1.5, label=f"as displayed (drive LPR {a.lpr_in_drive})")
    ax[0].plot(t, true, color="#c62e29", lw=2.2, label=f"corrected: x {scale:.1f} (true LPR {LPR_TRUE})")
    if a.reference_speed is not None:
        ax[0].axhline(a.reference_speed, color="#2962c8", ls=":", lw=1.5,
                      label=f"earlier run with LPR 13: {a.reference_speed:.0f} rpm")
    ax[0].axhline(0, color="k", lw=0.6)
    ax[0].set_ylabel("output rpm"); ax[0].grid(alpha=.3); ax[0].legend(loc="center right", fontsize=9)
    ax[0].set_title(f"{run_id}: MEASURED (hardware). Motor ran at full speed opposite to every command.",
                    fontsize=11, weight="bold")
    ax[1].step(t, u, where="post", color="#6a3fa8", lw=1.6, label="speed command sent to the drive")
    ax[1].set_ylabel("command (output rpm)"); ax[1].set_xlabel("t (s)"); ax[1].grid(alpha=.3); ax[1].legend()
    fig_path = ROOT / "results" / "figures" / "dc_motor" / f"{run_id}_analysis.png"
    fig_path.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout(); fig.savefig(fig_path, dpi=120); plt.close(fig)

    lines = [f"# Analysis of {run_id}", "",
             f"Raw: `{raw.relative_to(ROOT)}` (read-only, {len(rows)} samples, "
             f"{meta['link']['invalidCount']} invalid lines, {meta['link']['seqGaps']} sequence gaps). "
             f"Experiment: {meta['link'].get('experiment', '?')}. Data class: **HARDWARE**.", "",
             f"Drive LPR during the run: **{a.lpr_in_drive}** (true value {LPR_TRUE}); "
             f"speed readings corrected by x{scale:.2f}.", "",
             "| t (s) | Commanded (rpm) | Displayed (rpm) | Corrected (rpm) | Corrected range |",
             "|---|---|---|---|---|"]
    for s in segs:
        lines.append(f"| {s['t0']:.1f}-{s['t1']:.1f} | {s['setpoint']:+.0f} | {s['reported_mean']:+.2f} | "
                     f"**{s['true_mean']:+.1f}** | {s['true_min']:+.1f} … {s['true_max']:+.1f} |")
    lines += ["", f"Output shaft travel during the run: **≈ {revs:.0f} revolutions**.", "",
              f"Figure: `{fig_path.relative_to(ROOT)}`. Segment table: `{out_csv.relative_to(ROOT)}`."]
    rep = ROOT / "docs" / "experiments" / "dc_motor" / f"{run_id}_ANALYSIS.md"
    rep.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
