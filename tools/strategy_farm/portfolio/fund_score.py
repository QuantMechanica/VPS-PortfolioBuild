"""Reusable FUND_SCORE facade over the established 60-day challenge engine.

This module deliberately imports sleeve_improvement_targets, which itself reuses
challenge_book_60d. It does not maintain a second implementation of rolling
windows, entry-time eligibility, calendar deadlines, or dormancy.
"""
from __future__ import annotations

import argparse
import contextlib
import io
import json
import sys
from pathlib import Path
from typing import Any

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
DEFAULT_CACHE = Path(r"D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json")
sys.path.insert(0, str(Path(__file__).resolve().parent))


def _engine_rows() -> list[dict[str, Any]]:
    with contextlib.redirect_stdout(io.StringIO()):
        import sleeve_improvement_targets as engine
    return list(engine.rows)


def score_all() -> list[dict[str, Any]]:
    scored = {row["k"]: row for row in _engine_rows()}
    # Point 2.4: active_days_per_60d is produced here rather than merged in afterwards.
    # refresh_cache() rewrites rows from scratch, so anything merged into the cache by a
    # separate pass is erased by the next refresh -- an interim that needs a manual step
    # after every refresh is not an interim.
    import sleeve_density
    density = sleeve_density.density_rows()
    result: list[dict[str, Any]] = []
    for path in sorted(STREAMS.glob("*.jsonl")):
        bare, _, stem = path.stem.partition("_")
        key = f"{bare}:{stem.replace('_DWX', '').upper()}"
        row = scored.get(key)
        if row is None:
            n = covered = 0
            with path.open(encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    try:
                        trade = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if str(trade.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                        continue
                    n += 1
                    covered += bool(trade.get("entry_time"))
            result.append({
                "sleeve": key, "status": "UNSCORABLE",
                "reason": "entry_time_incomplete" if n and covered < n else "challenge_engine_ineligible",
                "records": n, "entry_time_records": covered,
            })
            continue
        med60 = float(row["med60_1x"])
        worst_day = abs(float(row["worst_day"]))
        wdd_p90 = float(row["wdd_p90"])
        denominator = max(2.0, 2.0 * worst_day, wdd_p90)
        entry = {
            "sleeve": key, "status": "SCORED",
            "fund_score": med60 / denominator if denominator else None,
            "med60_1x": med60, "worst_day_1x": worst_day,
            "wdd_p90_1x": wdd_p90, "denominator": denominator,
            "screening_only": True,
        }
        entry.update(density.get(key, {"active_days_per_60d": None,
                                       "active_days_reason": "no_active_day_set"}))
        result.append(entry)
    return result


def refresh_cache(path: Path = DEFAULT_CACHE) -> dict[str, Any]:
    rows = score_all()
    payload = {
        "metric": "FUND_SCORE",
        "screening_only": True,
        "gate_override_allowed": False,
        "rows": rows,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ea")
    parser.add_argument("--symbol")
    parser.add_argument("--refresh-cache", action="store_true")
    args = parser.parse_args()
    payload = refresh_cache() if args.refresh_cache else {
        "metric": "FUND_SCORE", "screening_only": True,
        "gate_override_allowed": False, "rows": score_all(),
    }
    rows = payload["rows"]
    if args.ea:
        bare = str(args.ea).upper().replace("QM5_", "")
        rows = [r for r in rows if r["sleeve"].split(":", 1)[0] == bare]
    if args.symbol:
        symbol = str(args.symbol).upper().replace(".DWX", "")
        rows = [r for r in rows if r["sleeve"].split(":", 1)[-1] == symbol]
    print(json.dumps({**payload, "rows": rows}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
