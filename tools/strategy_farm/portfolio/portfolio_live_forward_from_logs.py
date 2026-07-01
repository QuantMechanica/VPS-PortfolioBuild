"""Live-forward burn-in evidence FROM the T_Live per-EA logs (not the shared q08 Common).

Why this exists
---------------
``portfolio_burnin.py`` was written to read ``QM/q08_trades/<ea>_<symbol>.jsonl`` streams.
Those streams are unusable for a running live book:
  * the EA only dumps them at ``OnDeinit`` (shutdown) with ``FILE_WRITE`` (overwrite), and
  * the path is ``FILE_COMMON`` — SHARED between T_Live and the T1-T10 factory, so a Q08
    backtest of the same (ea, symbol) overwrites any live dump. Empirically all 13 live
    sleeves' q08 streams contain ONLY backtest trades (2017-2025), zero live trades.

The clean live source is the T_Live terminal's **per-EA log**
(``C:\\QM\\mt5\\T_Live\\MT5_Base\\MQL5\\Files\\QM\\QM5_<id>_*.log``): terminal-LOCAL (no
factory contamination), append-written, and it carries a daily ``EQUITY_SNAPSHOT`` event
(``AccountInfoDouble(ACCOUNT_EQUITY)`` = the whole live book / SUM of sleeves) plus trade
open/close events. This adapter extracts the real live book equity curve from those logs
and feeds the existing ``portfolio_burnin.burnin_verdict`` machinery.

Read-only. Never touches T_Live trading state. Evidence for OWNER only.
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import statistics
from pathlib import Path
from typing import Any, Mapping

try:
    from . import portfolio_burnin as pb
except ImportError:  # pragma: no cover - direct execution
    import portfolio_burnin as pb  # type: ignore

DEFAULT_TLIVE_LOG_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM")
# Trade-lifecycle events emitted by QM_TradeManager into the per-EA log.
OPEN_EVENTS = {"TM_OPEN", "ENTRY_ACCEPTED"}
CLOSE_EVENTS = {"TM_CLOSE"}


def _iter_log_events(log_dir: Path):
    """Yield parsed JSON records from every QM5_<id>_*.log (skip the unconfigured stub)."""
    for path in sorted(glob.glob(str(log_dir / "QM5_*.log"))):
        if "QM5_0000_unconfigured" in path:
            continue
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line or '"event"' not in line:
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue


def collect_forward_equity_from_logs(
    log_dir: Path,
    manifest: Mapping[str, Any],
) -> dict[str, Any]:
    """Build the live book equity curve from EQUITY_SNAPSHOT events.

    ``equity`` is the whole-account value, so every sleeve's log carries the same daily
    book equity. We take the per-day median across all sleeve logs (robust to the intraday
    snapshot of a sleeve that happens to hold an open position at its own bar rollover).
    """
    equity_by_day: dict[int, list[float]] = {}
    trades_by_ea: dict[int, dict[str, int]] = {}

    for rec in _iter_log_events(log_dir):
        event = rec.get("event")
        payload = rec.get("payload") or {}
        if event == "EQUITY_SNAPSHOT":
            day_key = payload.get("day_key")
            equity = payload.get("equity")
            if day_key is not None and equity is not None:
                equity_by_day.setdefault(int(day_key), []).append(float(equity))
        elif event in OPEN_EVENTS or event in CLOSE_EVENTS:
            ea_id = rec.get("ea_id")
            if ea_id is None:
                continue
            bucket = trades_by_ea.setdefault(int(ea_id), {"opens": 0, "closes": 0})
            if event in OPEN_EVENTS:
                bucket["opens"] += 1
            else:
                bucket["closes"] += 1

    days = sorted(equity_by_day)
    dates = [_day_key_to_date(d) for d in days]
    equity_curve = [round(statistics.median(equity_by_day[d]), 2) for d in days]
    starting_capital = float(manifest.get("starting_capital", 100_000.0))
    # Daily P&L = successive day-over-day differences of the account equity levels.
    # (Do NOT use equity_to_daily_pnl here: it treats curve[0] as a jump from zero, which
    # would book the whole starting balance as day-1 profit.)
    daily_pnl = [round(equity_curve[i] - equity_curve[i - 1], 2)
                 for i in range(1, len(equity_curve))]

    return {
        "source": "t_live_per_ea_logs",
        "log_dir": str(log_dir),
        "dates": [d.isoformat() for d in dates],
        "equity_curve": equity_curve,
        "daily_pnl": [round(v, 2) for v in daily_pnl],
        "starting_capital": starting_capital,
        "n_days": len(days),
        "trades_by_ea": trades_by_ea,
        "sleeves": {},  # per-sleeve equity is not separable from ACCOUNT_EQUITY
    }


def _day_key_to_date(day_key: int) -> dt.date:
    y, m, d = day_key // 10000, (day_key // 100) % 100, day_key % 100
    return dt.date(y, m, d)


def build_report(
    *,
    manifest: Mapping[str, Any],
    forward_equity: Mapping[str, Any],
    mc_artifact: Mapping[str, Any],
    config: Mapping[str, Any],
    generated_at_utc: str,
) -> dict[str, Any]:
    tol = config["pass_tolerances"]
    verdict = pb.burnin_verdict(
        manifest,
        forward_equity,
        mc_artifact,
        dd_tolerance=float(tol["dd_tolerance"]),
        sharpe_band=float(tol["sharpe_band"]),
    )
    window = int(config.get("burnin_window_days", 42))
    n_days = int(forward_equity.get("n_days", 0))
    immature = n_days < window
    mc_basis = str(mc_artifact.get("_basis", "unknown"))
    dd_basis_ok = mc_basis.startswith("sum_of_sleeves")
    caveat = (
        "Live equity = ACCOUNT_EQUITY (deployed SUM of sleeves at flat RISK_PERCENT). "
        "Sharpe is scale-invariant so the Sharpe-band check is directionally valid. "
    )
    if dd_basis_ok:
        caveat += (
            "DD check uses the SUM-basis 42d MC reference (mc_reference_d2c_42d.json, "
            "make_live_burnin_mc_reference.py) -> correct basis + window."
        )
    else:
        caveat += (
            "DD check is using a PLACEHOLDER reference (manifest weighted-avg, full-history) "
            "-> not directly comparable; supply --mc-artifact with the SUM-basis reference."
        )
    return {
        "status": "EVIDENCE_FOR_OWNER",
        "generated_at_utc": generated_at_utc,
        "source": "t_live_per_ea_logs",
        "basis_caveat": caveat,
        "dd_reference": {
            "basis": mc_basis,
            "basis_ok": dd_basis_ok,
            "mc_p95_max_drawdown_pct": pb._mc_drawdown_p95(mc_artifact),
            "provenance": mc_artifact.get("_provenance", {}),
        },
        "maturity": {
            "n_days_observed": n_days,
            "burnin_window_days": window,
            "immature": immature,
            "note": (
                "Window not yet filled; verdict is advisory-only and NOT binding until "
                f"n_days >= {window}."
            ) if immature else "Window filled.",
        },
        "forward_equity": forward_equity,
        "verdict": verdict,
    }


def _default_mc_artifact(manifest: Mapping[str, Any]) -> dict[str, Any]:
    """Fallback MC artifact from the manifest's own mc_p95 KPI (weighted-avg basis).

    Flagged in basis_caveat; the SUM-basis reference is a follow-up.
    """
    p95 = pb._nested_get(manifest, ("kpis", "mc_p95_max_drawdown_pct"))
    if p95 is None:
        p95 = pb._nested_get(manifest, ("kpis", "max_drawdown_pct"))
    return {"max_drawdown_pct": {"p95": float(p95) if p95 is not None else 0.0},
            "_basis": "manifest_weighted_avg_placeholder"}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--manifest", type=Path, required=True)
    p.add_argument("--log-dir", type=Path, default=DEFAULT_TLIVE_LOG_DIR)
    p.add_argument("--config", type=Path, default=pb.DEFAULT_CONFIG)
    p.add_argument("--mc-artifact", type=Path, default=None)
    p.add_argument("--out", type=Path,
                   default=Path(r"D:\QM\reports\portfolio\live_burnin\portfolio_live_burnin_report.json"))
    p.add_argument("--generated-at-utc", type=str, required=True,
                   help="ISO UTC timestamp (scripts have no clock); pass from the caller.")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        config = pb.load_burnin_config(args.config)
        manifest = pb._read_json(args.manifest)
        mc_artifact = pb._read_json(args.mc_artifact) if args.mc_artifact else _default_mc_artifact(manifest)
        forward_equity = collect_forward_equity_from_logs(args.log_dir, manifest)
        report = build_report(
            manifest=manifest,
            forward_equity=forward_equity,
            mc_artifact=mc_artifact,
            config=config,
            generated_at_utc=args.generated_at_utc,
        )
        out = args.out
        out.parent.mkdir(parents=True, exist_ok=True)
        with out.open("w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2, sort_keys=True)
            fh.write("\n")
        print(f"wrote {out}")
        v = report["verdict"]
        m = report["maturity"]
        r = v.get("realised", {})
        print(f"n_days={m['n_days_observed']} (window {m['burnin_window_days']}, "
              f"immature={m['immature']})")
        print(f"realised: net_pnl={r.get('total_net_of_cost_profit')}  "
              f"maxDD={r.get('max_drawdown_pct')}%  sharpe={r.get('sharpe')}")
        print(f"verdict={v.get('verdict')} reasons={v.get('reasons')}")
        print(pb.note_go_live_is_manual())
        return 0
    except (pb.ConfigError, FileNotFoundError, ValueError, KeyError) as exc:
        print(f"live burn-in refused: {exc}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
