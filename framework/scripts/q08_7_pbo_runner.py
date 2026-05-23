"""Q08.7 — PBO (Probability of Backtest Overfitting) runner.

Produces the scores.csv consumed by `pbo_calculator.py` + the
`q08_davey/sub_8_7_pbo.py` gate.

CSCV (Combinatorially Symmetric Cross-Validation, López de Prado & Bailey 2014)
splits the full backtest history into S equal time-slices, then for every
combination of S/2 slices as "in-sample" vs the complement as "out-of-sample",
checks whether the IS-best config is also OOS-best. The PBO is the
proportion of splits where the IS-winner ranks below the OOS median.

Input: the Q03 sweep results (every (config, time-slice) score) at:
    D:/QM/reports/pipeline/QM5_<id>/Q03/<symbol>/sweep_heatmap.csv
    (written by the Q03 sweep runner — contract)

This runner slices the existing Q03 sweep grid into S=8 chronological
time-slices by parsing the per-trade history from each sweep config's
report, computing per-slice PF, and writing the canonical scores.csv:

    config_id, slice_id, score
    grid_001,  S1,       1.42
    grid_001,  S2,       1.18
    ...

Output:
    D:/QM/reports/pipeline/QM5_<id>/Q08/pbo/<symbol>/scores.csv
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso

GATE_NAME = "Q08.7_pbo"
DEFAULT_N_SLICES = 8


def _parse_trades_from_summary(summary_path: Path) -> list[dict]:
    """Pull per-trade net-profit + close-ts from a sweep config's summary.json.

    Contract: the Q03 sweep runner writes per-trade detail under
    `runs[0].deals` (sourced from the MT5 report parse). When absent,
    return empty list — that config can't contribute slice scores.
    """
    if not summary_path.exists():
        return []
    try:
        sj = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return []
    runs = sj.get("runs") or []
    if not runs:
        return []
    deals = runs[0].get("deals") or []
    out: list[dict] = []
    for d in deals:
        ts = d.get("close_time") or d.get("ts_utc")
        net = d.get("net") or d.get("profit")
        if ts is None or net is None:
            continue
        try:
            close_ts = (dt.datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
                        if isinstance(ts, str)
                        else dt.datetime.fromtimestamp(int(ts), tz=dt.UTC))
        except (ValueError, TypeError):
            continue
        try:
            net_f = float(net)
        except (TypeError, ValueError):
            continue
        out.append({"ts": close_ts, "net": net_f})
    return out


def _slice_pf(trades: list[dict], slice_start, slice_end) -> float | None:
    """Profit factor of trades whose close timestamp lies in [start, end)."""
    wins = 0.0
    losses = 0.0
    for t in trades:
        if not (slice_start <= t["ts"] < slice_end):
            continue
        if t["net"] > 0:
            wins += t["net"]
        elif t["net"] < 0:
            losses += abs(t["net"])
    if losses == 0:
        return None if wins == 0 else float("inf")
    return wins / losses


def chronological_slices(start: dt.datetime, end: dt.datetime, n: int) -> list[tuple]:
    """Equal-width chronological slices [start, end) → list of (id, lo, hi)."""
    span = (end - start) / n
    return [(f"S{i+1}", start + i * span, start + (i + 1) * span) for i in range(n)]


def discover_sweep_configs(sweep_dir: Path) -> list[tuple[str, Path]]:
    """Find Q03 sweep config summaries: grid_001/summary.json, etc."""
    out: list[tuple[str, Path]] = []
    if not sweep_dir.exists():
        return out
    for config_dir in sorted(sweep_dir.iterdir()):
        if not config_dir.is_dir():
            continue
        m = re.match(r"(grid_\d+|synth_\d+|baseline)", config_dir.name)
        if not m:
            continue
        summary = config_dir / "summary.json"
        if summary.exists():
            out.append((m.group(1), summary))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Q08.7 PBO runner — emit CSCV scores.csv")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--sweep-dir", type=Path,
                    help="Q03 sweep dir (autodetected from --ea/--symbol if absent)")
    ap.add_argument("--n-slices", type=int, default=DEFAULT_N_SLICES,
                    help="Number of equal-width chronological slices (CSCV S)")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))
    sym_clean = args.symbol.replace(".", "_")

    sweep_dir = args.sweep_dir or (
        args.report_root / f"QM5_{ea_id}" / "Q03" / sym_clean
    )
    configs = discover_sweep_configs(sweep_dir)
    if not configs:
        print(f"no Q03 sweep configs found under {sweep_dir}", file=sys.stderr)
        return 1

    # Collect trades per config + determine global time window
    all_trades_by_config: dict[str, list[dict]] = {}
    min_ts = None
    max_ts = None
    for config_id, summary_path in configs:
        trades = _parse_trades_from_summary(summary_path)
        if not trades:
            continue
        all_trades_by_config[config_id] = trades
        for t in trades:
            if min_ts is None or t["ts"] < min_ts:
                min_ts = t["ts"]
            if max_ts is None or t["ts"] > max_ts:
                max_ts = t["ts"]

    if not all_trades_by_config or min_ts is None or max_ts is None:
        print("no trade-level data extractable from any sweep config", file=sys.stderr)
        return 1

    slices = chronological_slices(min_ts, max_ts + dt.timedelta(seconds=1), args.n_slices)
    print(f"Q08.7 PBO: {len(all_trades_by_config)} configs × {args.n_slices} slices")
    print(f"  time window: {min_ts.isoformat()} → {max_ts.isoformat()}")

    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q08" / "pbo" / sym_clean)
    scores_path = out_dir / "scores.csv"

    rows_written = 0
    with scores_path.open("w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["config_id", "slice_id", "score"])
        for config_id, trades in all_trades_by_config.items():
            for slice_id, slice_start, slice_end in slices:
                pf = _slice_pf(trades, slice_start, slice_end)
                if pf is None:
                    continue
                # CSCV PF in [-inf, +inf]; cap inf for numerical sanity
                if pf == float("inf"):
                    pf = 99.0
                w.writerow([config_id, slice_id, round(pf, 6)])
                rows_written += 1

    meta_path = out_dir / "scores_meta.json"
    meta = {
        "ea_id": ea_id,
        "symbol": args.symbol,
        "n_configs": len(all_trades_by_config),
        "n_slices": args.n_slices,
        "time_window": {"start": min_ts.isoformat(), "end": max_ts.isoformat()},
        "rows_written": rows_written,
        "scores_csv": str(scores_path),
        "generated_at_utc": utc_now_iso(),
    }
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")

    print(f"Q08.7 wrote {rows_written} rows to {scores_path}")
    print(f"  ready for pbo_calculator.py and sub_8_7_pbo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
