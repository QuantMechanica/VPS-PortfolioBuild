"""Score sleeves by what a time-boxed, loss-capped challenge actually rewards.

    speed = (account-% per year) / max-drawdown-%

WHY THIS METRIC
---------------
Density was the standing screen ("≥250 trades/yr/symbol") and it does not decide
anything. QM5_13036 is a textbook density motor — 1,352 trades, exactly one held
overnight — and it earns 1.82 per session against the 455 an FTMO Phase-1 run
needs. What decides a +10 % run inside ~22 sessions under a 10 % loss cap is how
much return a sleeve produces per unit of drawdown per unit of time.

Speed is **sizing-invariant**: scaling risk scales return and drawdown together.
That is the property that makes it the right screen, and it is also why the gap
cannot be closed by position sizing, by the FTMO governor, or by portfolio
construction — only by owning better strategies.

Reference points, measured 2026-07-26 over 175 streams:
  book requirement for +10 % in 22 sessions at ~6 % book drawdown : ~19
  best sleeve surviving the robustness gates                      : 0.96
  best raw sleeve (Q05 FAIL + Q08 FAIL_HARD — rejected, not usable): 9.50

That last line is the reason `--include-rejected` is off by default: in-sample
speed means nothing if the edge does not survive stress testing.

SWAP
----
Overnight share is reported alongside, because FTMO swap is what turned a
+20,624 book into −5,780 on the two qualified gold sleeves. A trade opening and
closing on the same day pays none. This is measured from the stream, not inferred
from EA source — a regex over source was tried and failed, missing sleeves whose
authors express the same rule with different vocabulary.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

STREAM_DIR = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
ACCOUNT = 100_000.0
PNL_KEYS = ("net", "profit_acct", "net_acct", "pnl_acct", "profit")
REJECTING = {"FAIL", "FAIL_HARD"}


def parse_ts(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        try:
            return datetime.fromtimestamp(float(value), tz=timezone.utc)
        except (OverflowError, OSError, ValueError):
            return None
    text = str(value).strip()
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        pass
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S",
                "%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(text[:19], fmt)
        except ValueError:
            continue
    return None


def gate_verdicts(conn: sqlite3.Connection) -> dict[tuple[str, str, str], str]:
    out: dict[tuple[str, str, str], str] = {}
    for row in conn.execute(
        "SELECT ea_id, symbol, phase, verdict FROM work_items "
        "WHERE phase IN ('Q05','Q08','Q10') AND status='done' ORDER BY updated_at"
    ):
        out[(row["ea_id"], str(row["symbol"]).upper(), row["phase"])] = str(row["verdict"])
    return out


def score_stream(path: Path) -> dict[str, Any] | None:
    equity = peak = max_dd = net = 0.0
    trades = overnight = 0
    first = last = None
    try:
        with path.open(encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if str(row.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                    continue
                pnl = None
                for key in PNL_KEYS:
                    if key in row:
                        try:
                            pnl = float(row[key])
                        except (TypeError, ValueError):
                            pnl = None
                        break
                close = parse_ts(row.get("time"))
                if pnl is None or close is None:
                    continue
                entry = parse_ts(row.get("entry_time"))
                trades += 1
                net += pnl
                equity += pnl
                peak = max(peak, equity)
                max_dd = max(max_dd, peak - equity)
                first = close if first is None else min(first, close)
                last = close if last is None else max(last, close)
                if entry is not None and entry.date() != close.date():
                    overnight += 1
    except OSError:
        return None

    if trades < 30 or max_dd <= 0 or first is None or last is None:
        return None
    years = max((last - first).days / 365.25, 0.25)
    dd_pct = max_dd / ACCOUNT * 100.0
    pct_per_year = (net / ACCOUNT * 100.0) / years
    return {
        "trades": trades,
        "net": net,
        "drawdown_pct": dd_pct,
        "pct_per_year": pct_per_year,
        "speed": pct_per_year / dd_pct,
        "overnight_pct": 100.0 * overnight / trades,
        "years": years,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--min-speed", type=float, default=0.0)
    parser.add_argument("--max-overnight", type=float, default=100.0,
                        help="percent of trades allowed to cross a day boundary")
    parser.add_argument("--include-rejected", action="store_true",
                        help="also score sleeves the robustness gates hard-rejected")
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    verdicts = gate_verdicts(conn)

    rows: list[dict[str, Any]] = []
    for path in sorted(STREAM_DIR.glob("*.jsonl")):
        bare, _, stem = path.stem.partition("_")
        ea_id = f"QM5_{bare}"
        symbol = stem.replace("_DWX", ".DWX").upper()
        q05 = verdicts.get((ea_id, symbol, "Q05"))
        q08 = verdicts.get((ea_id, symbol, "Q08"))
        rejected = q05 in REJECTING or q08 in REJECTING
        if rejected and not args.include_rejected:
            continue
        scored = score_stream(path)
        if scored is None:
            continue
        if scored["speed"] < args.min_speed:
            continue
        if scored["overnight_pct"] > args.max_overnight:
            continue
        scored.update({"ea_id": ea_id, "symbol": symbol,
                       "q05": q05, "q08": q08, "gate_rejected": rejected})
        rows.append(scored)

    rows.sort(key=lambda r: -r["speed"])

    print(f"{'EA':11}{'symbol':10}{'trades':>7}{'net':>11}{'DD%':>7}"
          f"{'%/yr':>8}{'speed':>7}{'o/n%':>7}  Q08")
    print("-" * 76)
    for r in rows[:args.limit]:
        flag = " (gate-rejected)" if r["gate_rejected"] else ""
        print(f"{r['ea_id']:11}{r['symbol'].replace('.DWX',''):10}{r['trades']:7}"
              f"{r['net']:11,.0f}{r['drawdown_pct']:7.2f}{r['pct_per_year']:8.2f}"
              f"{r['speed']:7.2f}{r['overnight_pct']:7.1f}  {r['q08']}{flag}")

    print()
    print(f"scored: {len(rows)}   speed>=5: {sum(1 for r in rows if r['speed'] >= 5)}"
          f"   swap-immune(<5% o/n): {sum(1 for r in rows if r['overnight_pct'] < 5)}")
    print("book requirement for +10% in ~22 sessions at ~6% book drawdown: speed ~19")

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(rows, indent=2, default=str) + "\n",
                            encoding="utf-8")
        print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
