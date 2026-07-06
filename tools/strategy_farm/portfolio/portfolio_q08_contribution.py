from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from pathlib import Path
from typing import Any, Sequence

# Basket EAs carry a logical composite work-item symbol (QM5_<id>_..., which can
# never be a real MT5 symbol) but dump their q08 stream under the HOST symbol —
# the Q09 edition of the 45ec67a7 host_symbol class (Q08's aggregate.py got the
# fix on 2026-07-05; this module never did, so every basket died NEED_MORE_DATA
# with trade_count=0 despite a full stream, e.g. 12778 AUDUSD~EURJPY).
BASKET_SYMBOL_RE = re.compile(r"^QM5_\d+_", re.IGNORECASE)
REPO_EAS = Path(r"C:\QM\repo\framework\EAs")
HOST_SYMBOL_HEADER_RE = re.compile(r";\s*host_symbol\s*:\s*(\S+)", re.IGNORECASE)


def _resolve_basket_stream_key(candidate, common_dir: Path):
    """Return ((ea, stream_key_symbol), note) for logical basket symbols, else (None, None).

    Resolution order (2026-07-06 audit G7 — existence-aware, because the durable
    store persists basket streams under the LOGICAL symbol while the volatile
    Common\\Files stream is keyed by HOST symbol):
      1. '; host_symbol:' setfile header (mirrors q08_davey.aggregate.
         _host_symbol_from_setfile) — used when the host-keyed stream file exists.
      2. Logical-named stream file (durable-store layout) — key mangled exactly
         as stream_path_key() mangles the filename, so load_streams matches.
         Commission stays correct: _load_one_stream prices each trade from the
         row's own symbol field, not the file key.
      3. Unique non-logical <ea>_*.jsonl stream in common_dir.
    Ambiguity keeps the miss (explicit note)."""
    ea, sym = candidate
    if not BASKET_SYMBOL_RE.match(str(sym)):
        return None, None
    stream_dir = common_dir / "QM" / "q08_trades"
    logical_name = f"{ea}_{str(sym).replace('.', '_')}.jsonl"
    logical_key = (int(ea), str(sym).replace("_", "."))

    host = None
    host_note = None
    for sf in sorted(REPO_EAS.glob(f"QM5_{ea}_*/sets/*.set")):
        try:
            for line in sf.read_text(encoding="utf-8-sig").splitlines():
                m = HOST_SYMBOL_HEADER_RE.match(line.strip())
                if m:
                    host = m.group(1)
                    host_note = f"host_symbol_from_setfile:{sf.name}"
                    break
        except (OSError, UnicodeDecodeError):
            continue
        if host is not None:
            break

    if host is not None:
        if (stream_dir / f"{ea}_{host.replace('.', '_')}.jsonl").exists():
            return (int(ea), host), host_note
        if (stream_dir / logical_name).exists():
            return logical_key, f"logical_stream_fallback:{logical_name}"
        # Neither file present yet (e.g. volatile dir pre-run): keep the host
        # key — the pre-G7 behavior — so a later-appearing stream still matches.
        return (int(ea), host), host_note

    if (stream_dir / logical_name).exists():
        return logical_key, f"logical_stream_fallback:{logical_name}"
    others = [p for p in stream_dir.glob(f"{ea}_*.jsonl") if p.name != logical_name]
    if len(others) == 1:
        sym_part = others[0].stem.split("_", 1)[1]
        resolved = re.sub(r"_([A-Z0-9]+)$", r".\1", sym_part)
        return (int(ea), resolved), f"unique_stream_fallback:{others[0].name}"
    return None, f"basket_stream_ambiguous:{len(others)}_candidates"

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
    from .portfolio_manifest import DEFAULT_STARTING_CAPITAL
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
    from portfolio_manifest import DEFAULT_STARTING_CAPITAL  # type: ignore


Key = tuple[int, str]
DEFAULT_MIN_PORTFOLIO_TRADES = 20


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
    common_dir: Path = portfolio_admission.DEFAULT_ADMISSION_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    q08_summary_path: Path | None = None,
    min_portfolio_trades: int = DEFAULT_MIN_PORTFOLIO_TRADES,
    max_corr: float = portfolio_admission.DEFAULT_MAX_CORR,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    lineage_payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    candidate = (int(candidate_key[0]), str(candidate_key[1]))
    stream_key = candidate
    stream_resolution = None
    resolved, note = _resolve_basket_stream_key(candidate, Path(common_dir))
    if resolved is not None:
        stream_key = resolved
        stream_resolution = note
    elif note is not None:
        stream_resolution = note
    streams = load_streams(common_dir, candidates=[stream_key])
    trades = streams.get(stream_key, [])
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
        "q08_regime_catastrophe": regime_catastrophe,
        "stream_key": key_label(stream_key),
        "stream_resolution": stream_resolution,
        "monthly_returns": monthly_returns(trades),
        "equity_curve": equity_curve(trades),
    }

    if trade_count < min_portfolio_trades:
        return {
            **base,
            "verdict": "NEED_MORE_DATA",
            "reason": "portfolio_trade_count_below_min",
        }

    # DL-078 (OWNER-ratified 2026-06-27): a STANDALONE Q08 8.10 regime catastrophe no
    # longer hard-rejects a portfolio sleeve. DL-075's premise is that the anticorrelation
    # book ABSORBS regime dependence: a sleeve whose bad regime is uncorrelated with the
    # book can still lower the book's drawdown. The standalone reject contradicted that
    # (and was applied inconsistently -- e.g. 10440:NDX was grandfathered in with the same
    # flag while genuine diversifiers were turned away). The decision now defers to
    # portfolio_admission, which admits ONLY when the candidate is sufficiently uncorrelated
    # AND demonstrably improves the book (Sharpe up OR maxDD down) -- the portfolio-context
    # equity curve already spans the candidate's bad regime, so admission proves absorption.
    # This mirrors the F4 (2026-06-03) treatment of standalone PF<1 below. A regime-fragile
    # sleeve that does NOT improve the book still FAILs at the admission check.

    book = read_candidates(candidates_db)
    book = [key for key in book if key not in (candidate, stream_key)]
    try:
        admission_kwargs: dict[str, Any] = {
            "max_corr": max_corr,
            "starting_capital": starting_capital,
        }
        if lineage_payload is not None:
            admission_kwargs["lineage_payload"] = lineage_payload
        admission = portfolio_admission.evaluate_candidate(
            stream_key,
            book,
            common_dir,
            **admission_kwargs,
        )
    except ValueError as exc:
        if "missing q08 trade streams" not in str(exc):
            raise
        return {
            **base,
            "verdict": "NEED_MORE_DATA",
            "reason": "portfolio_admission_missing_streams",
            "admission_error": str(exc),
        }

    if admission.get("reason") == "insufficient_overlap":
        return {
            **base,
            **admission,
            "verdict": "NEED_MORE_DATA",
            "reason": "portfolio_correlation_overlap_below_min",
            "previous_verdict": "FAIL_PORTFOLIO",
            "previous_reason": "insufficient_overlap",
            "sparse_overlap_watchlist": bool(admission.get("diversifies")),
        }

    # Trust portfolio_admission: it admits only when the candidate is sufficiently
    # uncorrelated AND actually improves the book (Sharpe up OR maxDD down). A standalone
    # net PF < 1 does NOT disqualify a portfolio sleeve - that is the whole point of the
    # rescue track, and test_portfolio_admission proves an anti-correlated PF<1 candidate
    # can be admitted when the portfolio improves. Genuinely negative-edge EAs (net PF < 1
    # over the window) are already FAIL_HARD upstream in Q08 and never reach Q09.
    # (OWNER feedback F4 2026-06-03: the standalone_pf>1 gate contradicted admission.)
    verdict = "PASS_PORTFOLIO" if admission.get("admit") else "FAIL_PORTFOLIO"
    reason = str(admission.get("reason") or "").strip() or (
        "portfolio_contribution_pass" if verdict == "PASS_PORTFOLIO" else "portfolio_contribution_fail"
    )
    # DL-078 audit trail: surface when a regime-fragile sleeve was admitted because the
    # book absorbed its regime dependence (vs the pre-DL-078 standalone hard-reject).
    if regime_catastrophe and verdict == "PASS_PORTFOLIO":
        base["regime_catastrophe_absorbed_by_book"] = True
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
    parser.add_argument("--common-dir", type=Path, default=portfolio_admission.DEFAULT_ADMISSION_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--min-portfolio-trades", type=int, default=DEFAULT_MIN_PORTFOLIO_TRADES)
    parser.add_argument("--max-corr", type=float, default=portfolio_admission.DEFAULT_MAX_CORR)
    parser.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
    parser.add_argument("--lineage-payload-json")
    parser.add_argument("--lineage-payload-file", type=Path)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    candidate = _parse_candidate(args.ea_id, args.symbol)
    lineage_payload = portfolio_admission.load_lineage_payload(
        args.lineage_payload_json,
        args.lineage_payload_file,
    )
    artifact = evaluate_q08_soft_rescue(
        candidate,
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        q08_summary_path=args.q08_summary,
        min_portfolio_trades=args.min_portfolio_trades,
        max_corr=args.max_corr,
        starting_capital=args.starting_capital,
        lineage_payload=lineage_payload,
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
