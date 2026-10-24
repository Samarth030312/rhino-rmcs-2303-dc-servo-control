#!/usr/bin/env python3
"""Analyse a batch of DC-motor hardware runs (raw CSV + metadata) recorded in one session.

    python3 scripts/reports/analyze_motor_session.py <session_name> <run_id> [<run_id> ...]

Raw data is read only. Outputs:
    data/processed/dc_motor/<session>_metrics.csv     one row per setpoint segment of every run
    results/figures/dc_motor/<session>_<group>.png    one figure per experiment
    docs/experiments/dc_motor/<session>_ANALYSIS.md   tables and findings

Metrics per constant-setpoint segment (units: output rpm or output degrees):
    final   mean of the measurement over the last 30 % of the segment
    e_ss    setpoint - final
    peak    largest excursion beyond the setpoint, as % of the step size (overshoot)
    t_rise  10 %-90 % rise time of the step, s
    t_set   time after which the measurement stays within the band (5 % of the step,
            at least 2 quantisation steps), s; blank if it never settles
"""
import argparse, csv, json, pathlib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = pathlib.Path(__file__).resolve().parents[2]
QUANT = {"S": 4.5, "P": 360.0 / 5200}      # speed fb ~450 base rpm steps; 5200 counts / output rev


def load(run_id):
    rows = list(csv.DictReader((ROOT / "data/raw/dc_motor" / f"{run_id}.csv").open()))
    meta = json.loads((ROOT / "data/metadata/dc_motor" / f"{run_id}.json").read_text())
    f = lambda k: [float(r[k]) for r in rows]
    return dict(id=run_id, meta=meta, loop=rows[0]["loop"], ctrl=rows[0]["ctrl"],
                t=f("t_s"), r=f("setpoint"), y=f("meas"), u=f("u"))


def segments(run):
    t, r, y = run["t"], run["r"], run["y"]
    out, s, prev_final = [], 0, y[0]
    for i in range(1, len(t) + 1):
        if i < len(t) and r[i] == r[s]:
            continue
        idx = list(range(s, i))
        tail = idx[int(len(idx) * 0.7):] or idx
        final = sum(y[k] for k in tail) / len(tail)
        step = r[s] - prev_final
        seg = dict(run=run["id"], loop=run["loop"], ctrl=run["ctrl"],
                   Kp=run["meta"]["config_sent"]["Kp"], Ki=run["meta"]["config_sent"]["Ki"],
                   t0=t[s], t1=t[i - 1], setpoint=r[s], start=prev_final, final=final,
                   e_ss=r[s] - final, peak=None, t_rise=None, t_set=None)
        if abs(step) > 2 * QUANT[run["loop"]]:
            sgn = 1 if step > 0 else -1
            ex = max(sgn * (y[k] - r[s]) for k in idx)
            seg["peak"] = max(0.0, 100 * ex / abs(step))
            lo = next((t[k] for k in idx if sgn * (y[k] - prev_final) >= 0.1 * abs(step)), None)
            hi = next((t[k] for k in idx if sgn * (y[k] - prev_final) >= 0.9 * abs(step)), None)
            if lo is not None and hi is not None:
                seg["t_rise"] = hi - lo
            band = max(0.05 * abs(step), 2 * QUANT[run["loop"]])
            outside = [k for k in idx if abs(y[k] - r[s]) > band]
            if not outside:
                seg["t_set"] = 0.0
            elif outside[-1] < idx[-1]:
                seg["t_set"] = t[outside[-1] + 1] - t[s]
        out.append(seg)
        prev_final, s = final, i
    return out


def fmt(v, nd=1):
    return "" if v is None else f"{v:.{nd}f}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("session")
    ap.add_argument("runs", nargs="+")
    a = ap.parse_args()
    runs = [load(r) for r in a.runs]
    segs = [s for run in runs for s in segments(run)]

    out_csv = ROOT / "data/processed/dc_motor" / f"{a.session}_metrics.csv"
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with out_csv.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(segs[0].keys())); w.writeheader(); w.writerows(segs)

    # one figure per experiment name, all its runs overlaid
    groups = {}
    for run in runs:
        groups.setdefault((run["meta"]["config_sent"]["experiment"], run["meta"]["link"]["experiment"]), []).append(run)
    figdir = ROOT / "results/figures/dc_motor"; figdir.mkdir(parents=True, exist_ok=True)
    figs = []
    for gi, ((exp, name), rs) in enumerate(groups.items()):
        fig, ax = plt.subplots(2, 1, figsize=(10, 6.5), sharex=True)
        unit = "output rpm" if rs[0]["loop"] == "S" else "output deg"
        for run in rs:
            c = run["meta"]["config_sent"]
            lab = f"{run['id'][-6:]}  {c['ctrl']} Kp {c['Kp']:g} Ki {c['Ki']:g}"
            line, = ax[0].plot(run["t"], run["y"], lw=1.6, label=lab)
            ax[0].step(run["t"], run["r"], where="post", color=line.get_color(), ls="--", lw=1, alpha=.7)
            ax[1].step(run["t"], run["u"], where="post", color=line.get_color(), lw=1.3)
        ax[0].set_ylabel(f"measured ({unit})"); ax[0].grid(alpha=.3); ax[0].legend(fontsize=8)
        ax[0].set_title(f"{exp}: {name}  -  MEASURED (hardware), dashed = setpoint", fontsize=10, weight="bold")
        ax[1].set_ylabel("controller output\n(speed cmd, output rpm)"); ax[1].set_xlabel("t (s)"); ax[1].grid(alpha=.3)
        p = figdir / f"{a.session}_{gi + 1:02d}_{exp}.png"
        fig.tight_layout(); fig.savefig(p, dpi=110); plt.close(fig)
        figs.append((exp, name, p))

    L = [f"# Hardware session analysis: {a.session}", "",
         "Data class: **HARDWARE** (RMCS-2303 drive, RMCS-5032 motor, 11.2 V battery, drive LPR 13).",
         f"Runs: {len(runs)}. Raw files are read-only in `data/raw/dc_motor/`. "
         f"Segment metrics: `{out_csv.relative_to(ROOT)}`.", "",
         "| Run | Loop | Ctrl | Kp | Ki | Setpoint | Final | e_ss | Overshoot % | t_rise s | t_settle s |",
         "|---|---|---|---|---|---|---|---|---|---|---|"]
    for s in segs:
        L.append(f"| {s['run']} | {s['loop']} | {s['ctrl']} | {s['Kp']:g} | {s['Ki']:g} | {s['setpoint']:+g} | "
                 f"{s['final']:+.1f} | {s['e_ss']:+.1f} | {fmt(s['peak'], 0)} | {fmt(s['t_rise'], 2)} | {fmt(s['t_set'], 2)} |")
    L += ["", "Figures:"] + [f"- {e} {n}: `{p.relative_to(ROOT)}`" for e, n, p in figs]
    rep = ROOT / "docs/experiments/dc_motor" / f"{a.session}_ANALYSIS.md"
    rep.write_text("\n".join(L) + "\n")
    print("\n".join(L))


if __name__ == "__main__":
    main()
