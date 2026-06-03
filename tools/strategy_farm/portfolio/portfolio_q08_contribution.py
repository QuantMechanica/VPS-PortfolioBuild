from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any, Sequence

try:
    from . import portfolio_admission
    from .portfolio_common import (
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        Trade,
        key_label,
        load_streams,
        read_candidates,
    )
except ImportError:  # pragma: no cover - direct script execution
    import portfolio_admission  # type: ignore
    from portfolio_common import (  # type: ignore
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        Trade,
        key_label,
        load_streams,
        read_candidates,
    )


Key = tuple[int, str]
DEFAULT_MIN_PORTFOLIO_TRADES = 30


def monthly_returns(trades: Sequence[Trade]) -> dict[str, float]:
    monthly: dict[str, float] = {}
    for trade in trades:
        stamp = dt.datetime.fromtimestamp(int(trade.time), tz=dt.UTC)
        key = f"{stamp.year:04d}-{stamp.month:02d}"
        monthly[key] = monthly.get(key, 0.0) + float(trade.net_of_cost)
    return {key: round(value, 6) for key, value in sorted(monthly.items())}


def equity_curve(trades: Sequence[Trade]) -> list[dict[str, Any]]:
    equity = 0.0
    rows: list[dict[str, Any]] = []
    for trade in sorted(trades, key=lambda item: int(item.time)):
        equity += float(trade.net_of_cost)
        rows.append(
            {
                "time": int(trade.time),
                "equity": round(equity, 6),
                "net_of_cost": round(float(trade.net_of_cost), 6),
            }
        )
    return rows


def evaluate_q08_soft_rescue(
    candidate_key: Key,
    *,
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    q08_summary_path: Path | None = None,
    min_portfolio_trades: int = DEFAULT_MIN_PORTFOLIO_TRADES,
    max_corr: float = portfolio_admission.DEFAULT_MAX_CORR,
) -> dict[str, Any]:
    candidate = (int(candidate_key[0]), str(candidate_key[1]))
    streams = load_streams(common_dir, candidates=[candidate])
    trades = streams.get(candidate, [])
    trade_count = len(trades)

    q08_summary = _load_json(q08_summary_path)
    regime_catastrophe = _has_regime_catastrophe(q08_summary)

    base: dict[str, Any] = {
        "candidate": key_label(candidate),
        "phase": "Q09_PORTFOLIO",
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "min_portfolio_trades": int(min_portfolio_trades),
        "trade_count": trade_count,
        "q08_summary_path": str(q08_summary_path) if q08_summary_path else None,
        "monthly_returns": monthly_returns(trades),
        "equity_curve": equity_curve(trades),
    }

    if trade_count < min_portfolio_trades:
        return {
            **base,
            "verdict": "NEED_MORE_DATA",
            "reason": "portfolio_trade_count_below_min",
        }

    if regime_catastrophe:
        return {
            **base,
            "verdict": "FAIL_PORTFOLIO",
            "reason": "q08_regime_catastrophe",
        }

    book = read_candidates(candidates_db)
    book = [key for key in book if key != candidate]
    admission = portfolio_admission.evaluate_candidate(
        candidate,
        book,
        common_dir,
        max_corr=max_corr,
    )
    standalone_pf = admission.get("standalone_pf")
    pf_ok = isinstance(standalone_pf, (int, float)) and float(standalone_pf) > 1.0
    verdict = "PASS_PORTFOLIO" if admission.get("admit") and pf_ok else "FAIL_PORTFOLIO"
    if not pf_ok:
        reason = "standalone_pf_not_above_1"
    else:
        reason = str(admission.get("reason") or "").strip() or (
            "portfolio_contribution_pass" if verdict == "PASS_PORTFOLIO" else "portfolio_contribution_fail"
        )
    return {
        **base,
        **admission,
        "verdict": verdict,
        "reason": reason,
    }


def write_aggregate(artifact: dict[str, Any], out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "aggregate.json"
    out_path.write_text(json.dumps(artifact, indent=2, sort_keys=True), encoding="utf-8")
    return out_path


def _load_json(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _has_regime_catastrophe(q08_summary: dict[str, Any]) -> bool:
    for gate in q08_summary.get("sub_gates") or []:
        if not isinstance(gate, dict):
            continue
        name = str(gate.get("name") or "").lower()
        detail = str(gate.get("detail") or "").lower()
        if name.startswith("8.10") and "unprofitable_regimes" in detail:
            return True
    return False


def _parse_candidate(ea_id: str, symbol: str) -> Key:
    text = str(ea_id).strip()
    if text.startswith("QM5_"):
        text = text.split("_", 2)[1]
    return int(text), str(symbol)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate Q08 soft-fail portfolio contribution.")
    parser.add_argument("--ea-id", required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--report-root", type=Path, required=True)
    parser.add_argument("--q08-summary", type=Path)
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--min-portfolio-trades", type=int, default=DEFAULT_MIN_PORTFOLIO_TRADES)
    parser.add_argument("--max-corr", type=float, default=portfolio_admission.DEFAULT_MAX_CORR)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    candidate = _parse_candidate(args.ea_id, args.symbol)
    artifact = evaluate_q08_soft_rescue(
        candidate,
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        q08_summary_path=args.q08_summary,
        min_portfolio_trades=args.min_portfolio_trades,
        max_corr=args.max_corr,
    )
    out_dir = (
        args.report_root
        / f"QM5_{candidate[0]}"
        / "Q09_PORTFOLIO"
        / str(args.symbol).replace(".", "_")
    )
    out_path = write_aggregate(artifact, out_dir)
    print(f"wrote {out_path} verdict={artifact['verdict']} reason={artifact['reason']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
