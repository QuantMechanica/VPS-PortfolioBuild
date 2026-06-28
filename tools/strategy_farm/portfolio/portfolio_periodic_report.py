"""R-064-5 periodic portfolio report on the STRESS-GATED robust sleeve pool.

Sources candidates from the Q08 FAIL_SOFT verdict (= robust-but-regime-dependent EAs
that cleared Q05/Q06/Q07 stress + multi-seed; FAIL_HARD = net-losing = excluded), NOT
from --all-streams (the Q04/all-stream pool overfits — see the 2026-06-21 finding) and
NOT only from portfolio_candidates (which currently holds 1 row). Runs the fixed greedy
assembler (inverse_vol, mission DD cap) + the out-of-sample selection guard, and writes
a dated + a 'latest' report so the book's growth is visible as sleeves accumulate.

Numpy-FREE on purpose: the SYSTEM scheduled-task interpreter (AppData Python311) has no
numpy; the whole assemble/KPI path has a pure-python fallback, so this must too.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.strategy_farm.portfolio.portfolio_common import (
        DEFAULT_CANDIDATES_DB, DEFAULT_COMMON_DIR, _coerce_ea_int, align, key_label,
        load_streams, to_daily_pnl,
    )
    from tools.strategy_farm.portfolio.commission import load_model
    from tools.strategy_farm.portfolio.portfolio_assemble import (
        greedy_select, select_and_validate,
    )
    from tools.strategy_farm.portfolio.portfolio_manifest import DEFAULT_STARTING_CAPITAL
else:
    from .portfolio_common import (
        DEFAULT_CANDIDATES_DB, DEFAULT_COMMON_DIR, _coerce_ea_int, align, key_label,
        load_streams, to_daily_pnl,
    )
    from .commission import load_model
    from .portfolio_assemble import greedy_select, select_and_validate
    from .portfolio_manifest import DEFAULT_STARTING_CAPITAL

BOMBERS = ("10809", "11072", "11092")
DEFAULT_OUT_DIR = Path(r"D:\QM\reports\portfolio")


def _sharpe(value: object) -> float:
    return float("-inf") if value is None else float(value)  # type: ignore[arg-type]


def robust_pairs(db_path: Path) -> list[tuple[int, str]]:
    """Distinct (ea_int, symbol) with a Q08 FAIL_SOFT verdict, minus known bombers."""
    conn = sqlite3.connect(db_path)
    try:
        rows = conn.execute(
            "SELECT DISTINCT ea_id, symbol FROM work_items "
            "WHERE phase='Q08' AND verdict='FAIL_SOFT' AND symbol IS NOT NULL"
        ).fetchall()
    finally:
        conn.close()
    out: list[tuple[int, str]] = []
    for ea_id, symbol in rows:
        if any(b in str(ea_id) for b in BOMBERS):
            continue
        ei = _coerce_ea_int(ea_id)
        if ei is not None:
            out.append((ei, str(symbol)))
    return sorted(set(out))


def build_report(
    *,
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    max_dd_pct: float = 20.0,
    weighting: str = "inverse_vol",
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    generated_at: str | None = None,
) -> dict:
    pairs = robust_pairs(candidates_db)
    model = load_model()
    streams = {
        k: v
        for k, v in load_streams(common_dir, candidates=pairs, commission_model=model).items()
        if v
    }
    report: dict = {
        "generated_at_utc": generated_at or "",
        "basis": "q08_fail_soft_robust_pool",
        "certification_scope": "exploratory_q08_fail_soft_robust_pool",
        "deployment_eligible": False,
        "deployment_note": (
            "Not a certified T_Live book. Q12 deployment manifests must be generated from "
            "portfolio_candidates.Q12_REVIEW_READY_all via portfolio_manifest."
        ),
        "weighting": weighting,
        "max_dd_pct_constraint": float(max_dd_pct),
        "commission_degraded": model.degraded,
        "n_candidate_pairs": len(pairs),
        "n_sleeves_with_streams": len(streams),
    }
    if len(streams) < 2:
        report["status"] = "insufficient_sleeves"
        report["note"] = (
            f"{len(streams)} sleeve(s) with streams — need >=2 for a portfolio. "
            "Pool grows as more EAs clear Q05-Q08."
        )
        return report

    series = {k: to_daily_pnl(t) for k, t in streams.items()}
    keys, dates, matrix = align(series)

    # Try both weightings and keep the best book: prefer one that meets the DD cap,
    # then the higher Sharpe. (Risk-parity is the principled default but on a tiny pool
    # naive equal-weight can find a cap-feasible book that inverse_vol misses.)
    best = None
    for wmode in ("inverse_vol", "equal"):
        sel, w, k = greedy_select(
            keys, matrix, max_dd_pct=max_dd_pct, weighting=wmode,
            starting_capital=starting_capital,
        )
        rank = (bool(k.get("cap_met")), _sharpe(k.get("sharpe")))
        if best is None or rank > best[0]:
            best = (rank, wmode, sel, w, k)
    _, weighting, selected, weights, kpis = best
    report["weighting"] = weighting
    oos = select_and_validate(
        keys, matrix, max_dd_pct=max_dd_pct, weighting=weighting,
        starting_capital=starting_capital,
    )
    report.update(
        status="ok",
        n_days=len(dates),
        date_start=str(dates[0]) if dates else None,
        date_end=str(dates[-1]) if dates else None,
        sleeves_considered=[key_label(k) for k in keys],
        n_selected=len(selected),
        selected_keys=[key_label(k) for k in selected],
        weights={key_label(k): round(weights[k], 6) for k in selected},
        kpis=kpis,
        oos_validation=oos,
    )
    return report


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Periodic robust-pool portfolio report (R-064-5).")
    p.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    p.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    p.add_argument("--max-dd-pct", type=float, default=20.0)
    p.add_argument("--weighting", choices=("equal", "inverse_vol"), default="inverse_vol")
    p.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
    p.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    p.add_argument("--stamp", default=None, help="UTC timestamp (the scheduler passes this; "
                                                 "Date.now is unavailable in some contexts)")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    stamp = args.stamp or dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    report = build_report(
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        max_dd_pct=args.max_dd_pct,
        weighting=args.weighting,
        starting_capital=args.starting_capital,
        generated_at=stamp,
    )
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "portfolio_latest.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    datestr = stamp[:10].replace("-", "")
    (args.out_dir / f"portfolio_report_{datestr}.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    status = report.get("status")
    if status == "ok":
        k = report.get("kpis", {})
        oos = report.get("oos_validation", {})
        print(
            f"portfolio report: {report['n_selected']}/{report['n_sleeves_with_streams']} "
            f"sleeves  DD={k.get('max_drawdown_pct')}%  Sharpe={k.get('sharpe')}  "
            f"oos_cap_met={oos.get('oos_cap_met')}"
        )
    else:
        print(f"portfolio report: {status} ({report.get('n_sleeves_with_streams')} sleeves)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
