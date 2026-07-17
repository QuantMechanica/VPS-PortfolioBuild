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
import hashlib
import json
import re
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso
from framework.scripts.q08_davey.common import load_trades_from_mt5_report, parse_ts
from framework.scripts.q08_5_neighborhood_runner import parse_setfile_assignments

GATE_NAME = "Q08.7_pbo"
DEFAULT_N_SLICES = 8
MIN_DISTINCT_CONFIGS = 2
FARM_DB = Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")
SCORES_SCHEMA_VERSION = 2
ENGINE_VERSION = "q08_pbo_distinct_config_v2"


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
    if out:
        return out
    report_path = None
    for run in runs:
        report_path = run.get("report_canonical_path") or run.get("report_source_path")
        if report_path:
            break
    if report_path:
        parsed: list[dict] = []
        for trade in load_trades_from_mt5_report(Path(report_path)):
            close_ts = parse_ts(trade.get("ts_utc") or trade.get("time"))
            if close_ts is None:
                continue
            try:
                net_f = float(trade["net"])
            except (KeyError, TypeError, ValueError):
                continue
            parsed.append({"ts": close_ts, "net": net_f})
        return parsed
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


def _effective_config_hash(setfile_path: Path | None) -> str | None:
    """Return a content identity only when the effective config is verifiable."""
    if setfile_path is not None and setfile_path.exists():
        try:
            assignments = parse_setfile_assignments(setfile_path)
            if not assignments:
                return None
            active_values = [
                (key, str(meta["cells"][0]))
                for key, meta in sorted(assignments.items())
            ]
            canonical = json.dumps(active_values, separators=(",", ":"), ensure_ascii=True)
            return hashlib.sha256(canonical.encode("utf-8")).hexdigest()
        except (OSError, ValueError):
            pass
    return None


def discover_sweep_configs(sweep_dir: Path) -> list[tuple[str, Path]]:
    """Find Q03 sweep config summaries: grid_001/summary.json, etc."""
    out: list[tuple[str, Path]] = []
    seen: set[str] = set()
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
            setfiles = sorted(config_dir.glob("*.set"))
            config_hash = _effective_config_hash(setfiles[0] if setfiles else None)
            if config_hash is None or config_hash in seen:
                continue
            seen.add(config_hash)
            out.append((f"q03_{config_hash[:16]}", summary))
    return out


def discover_work_item_q03_configs(ea_id: int, symbol: str) -> list[tuple[str, Path]]:
    """Fallback for the current farm: Q03 evidence lives under work_items."""
    if not FARM_DB.exists():
        return []
    con = sqlite3.connect(str(FARM_DB))
    con.row_factory = sqlite3.Row
    rows = con.execute(
        """
        SELECT id, setfile_path, evidence_path
        FROM work_items
        WHERE ea_id=? AND symbol=? AND phase='Q03' AND status='done'
          AND verdict IN ('PASS', 'FAIL')
          AND evidence_path IS NOT NULL
        ORDER BY updated_at ASC, created_at ASC
        """,
        (f"QM5_{ea_id}", symbol),
    ).fetchall()
    out: list[tuple[str, Path]] = []
    seen: set[str] = set()
    for row in rows:
        summary = Path(row["evidence_path"])
        if not summary.exists():
            continue
        setfile_raw = str(row["setfile_path"] or "").strip()
        setfile = Path(setfile_raw) if setfile_raw else None
        config_hash = _effective_config_hash(setfile)
        if config_hash is None or config_hash in seen:
            # Repeated deterministic runs of one setfile are evidence replicas,
            # not distinct parameter configurations.  Treating their work-item
            # IDs as new configs makes a one-point family look rankable and can
            # yield a vacuous PBO=0% PASS.
            continue
        seen.add(config_hash)
        out.append((f"q03_{config_hash[:16]}", summary))
    return out


def discover_neighborhood_configs(artifact_path: Path) -> tuple[list[tuple[str, Path]], dict]:
    """Return only valid, distinct Q08.5 configs with exact summary provenance."""
    if not artifact_path.exists():
        return [], {}
    try:
        payload = json.loads(artifact_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return [], {}
    configs: list[tuple[str, Path]] = []
    seen_hashes: set[str] = set()
    rows = [payload.get("baseline") or {}] + list(payload.get("perturbations") or [])
    for row in rows:
        if str(row.get("status") or "").upper() != "VALID":
            continue
        try:
            trades = int(row.get("trades") or 0)
        except (TypeError, ValueError):
            continue
        config_hash = str(row.get("setfile_sha256") or "").strip().lower()
        summary_raw = str(row.get("summary_path") or "").strip()
        if trades <= 0 or not config_hash or config_hash in seen_hashes or not summary_raw:
            continue
        summary = Path(summary_raw)
        if not summary.exists():
            continue
        seen_hashes.add(config_hash)
        configs.append((f"neighborhood_{config_hash[:16]}", summary))
    return configs, payload


def _extract_trade_family(
        configs: list[tuple[str, Path]]) -> tuple[dict[str, list[dict]], list[dict]]:
    trades_by_config: dict[str, list[dict]] = {}
    provenance: list[dict] = []
    for config_id, summary_path in configs:
        trades = _parse_trades_from_summary(summary_path)
        if not trades or config_id in trades_by_config:
            continue
        trades_by_config[config_id] = trades
        provenance.append({
            "config_id": config_id,
            "summary_path": str(summary_path.resolve()),
            "n_trades": len(trades),
        })
    return trades_by_config, provenance


def _score_family(
        trades_by_config: dict[str, list[dict]], n_slices: int
        ) -> tuple[list[list[object]], dict[str, object]]:
    timestamps = [trade["ts"] for trades in trades_by_config.values() for trade in trades]
    if not timestamps:
        return [], {"n_common_slices": 0, "time_window": None}
    min_ts = min(timestamps)
    max_ts = max(timestamps)
    slices = chronological_slices(min_ts, max_ts + dt.timedelta(seconds=1), n_slices)
    rows: list[list[object]] = []
    slices_by_config: dict[str, set[str]] = defaultdict(set)
    for config_id, trades in trades_by_config.items():
        for slice_id, slice_start, slice_end in slices:
            pf = _slice_pf(trades, slice_start, slice_end)
            if pf is None:
                continue
            if pf == float("inf"):
                pf = 99.0
            rows.append([config_id, slice_id, round(pf, 6)])
            slices_by_config[config_id].add(slice_id)
    common = (
        set.intersection(*(slices_by_config[key] for key in trades_by_config))
        if trades_by_config else set()
    )
    return rows, {
        "n_common_slices": len(common),
        "common_slices": sorted(common),
        "time_window": {"start": min_ts.isoformat(), "end": max_ts.isoformat()},
    }


def _write_scores_and_meta(
        scores_path: Path, meta_path: Path, rows: list[list[object]], meta: dict) -> None:
    scores_path.parent.mkdir(parents=True, exist_ok=True)
    scores_temp = scores_path.with_name(f".{scores_path.name}.tmp")
    with scores_temp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["config_id", "slice_id", "score"])
        writer.writerows(rows)
    meta_temp = meta_path.with_name(f".{meta_path.name}.tmp")
    meta_temp.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    scores_temp.replace(scores_path)
    meta_temp.replace(meta_path)


def main() -> int:
    ap = argparse.ArgumentParser(description="Q08.7 PBO runner — emit CSCV scores.csv")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--sweep-dir", type=Path,
                    help="Q03 sweep dir (autodetected from --ea/--symbol if absent)")
    ap.add_argument("--neighborhood-artifact", type=Path,
                    help="Q08.5 perturbations.json with exact config/summary lineage")
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
    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q08" / "pbo" / sym_clean)
    scores_path = out_dir / "scores.csv"
    meta_path = out_dir / "scores_meta.json"
    neighborhood_path = args.neighborhood_artifact or (
        args.report_root / f"QM5_{ea_id}" / "Q08" / "neighborhood" / sym_clean
        / "perturbations.json"
    )

    filesystem_configs = discover_sweep_configs(sweep_dir)
    db_configs = discover_work_item_q03_configs(ea_id, args.symbol)
    combined_q03: list[tuple[str, Path]] = []
    seen_q03: set[str] = set()
    for config in filesystem_configs + db_configs:
        if config[0] in seen_q03:
            continue
        seen_q03.add(config[0])
        combined_q03.append(config)
    q03_trades, q03_provenance = _extract_trade_family(combined_q03)
    q03_rows, q03_stats = _score_family(q03_trades, args.n_slices)

    neighborhood_configs, neighborhood_payload = discover_neighborhood_configs(
        neighborhood_path
    )
    neighborhood_trades, neighborhood_provenance = _extract_trade_family(
        neighborhood_configs
    )
    neighborhood_rows, neighborhood_stats = _score_family(
        neighborhood_trades, args.n_slices
    )

    def evaluable(family: dict[str, list[dict]], stats: dict[str, object]) -> bool:
        common = int(stats.get("n_common_slices") or 0)
        return len(family) >= MIN_DISTINCT_CONFIGS and common >= 2 and common % 2 == 0

    if evaluable(q03_trades, q03_stats):
        all_trades_by_config = q03_trades
        rows = q03_rows
        stats = q03_stats
        provenance = q03_provenance
        config_source = "Q03"
    elif evaluable(neighborhood_trades, neighborhood_stats):
        all_trades_by_config = neighborhood_trades
        rows = neighborhood_rows
        stats = neighborhood_stats
        provenance = neighborhood_provenance
        config_source = "Q08.5_neighborhood"
    elif len(q03_trades) >= len(neighborhood_trades) and q03_trades:
        all_trades_by_config = q03_trades
        rows = q03_rows
        stats = q03_stats
        provenance = q03_provenance
        config_source = "Q03"
    else:
        all_trades_by_config = neighborhood_trades
        rows = neighborhood_rows
        stats = neighborhood_stats
        provenance = neighborhood_provenance
        config_source = "Q08.5_neighborhood"

    n_configs = len(all_trades_by_config)
    n_common_slices = int(stats.get("n_common_slices") or 0)
    if n_configs < MIN_DISTINCT_CONFIGS:
        status = (
            "INVALID_NA"
            if neighborhood_payload.get("structurally_inapplicable") is True
            else "INVALID"
        )
        reason = (
            "structurally_inapplicable_config_family"
            if status == "INVALID_NA"
            else f"insufficient_distinct_configs:got={n_configs}:need>={MIN_DISTINCT_CONFIGS}"
        )
    elif n_common_slices < 2 or n_common_slices % 2:
        status = "INVALID"
        reason = f"insufficient_common_even_slices:got={n_common_slices}:need_even>=2"
    else:
        status = "VALID"
        reason = "evaluable_distinct_config_family"

    neighborhood_sha = None
    if neighborhood_path.exists():
        try:
            neighborhood_sha = hashlib.sha256(neighborhood_path.read_bytes()).hexdigest()
        except OSError:
            pass
    published_rows = rows if n_configs >= MIN_DISTINCT_CONFIGS else []
    meta = {
        "schema_version": SCORES_SCHEMA_VERSION,
        "engine_version": ENGINE_VERSION,
        "status": status,
        "reason": reason,
        "ea_id": ea_id,
        "symbol": args.symbol,
        "n_configs": n_configs,
        "n_slices": args.n_slices,
        "n_common_slices": n_common_slices,
        "common_slices": stats.get("common_slices") or [],
        "time_window": stats.get("time_window"),
        "rows_written": len(published_rows),
        "scores_csv": str(scores_path),
        "config_source": config_source,
        "configs": provenance,
        "q03_candidate_configs": len(q03_trades),
        "neighborhood_candidate_configs": len(neighborhood_trades),
        "neighborhood_artifact": str(neighborhood_path),
        "neighborhood_artifact_sha256": neighborhood_sha,
        "generated_at_utc": utc_now_iso(),
    }
    _write_scores_and_meta(scores_path, meta_path, published_rows, meta)

    print(
        f"Q08.7 wrote {len(published_rows)} rows to {scores_path}; "
        f"status={status} source={config_source} configs={n_configs} common={n_common_slices}"
    )
    if status != "VALID":
        print(reason, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
