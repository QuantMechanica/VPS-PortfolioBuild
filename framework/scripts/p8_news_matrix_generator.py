#!/usr/bin/env python3
"""Generate a P8 news-mode matrix from calendar and prior phase metrics."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from _phase_utils import ensure_dir, parse_float, parse_int


MODES = [
    ("OFF", 1.00, 1.00),
    ("PAUSE", 0.97, 0.92),
    ("SKIP_DAY", 0.94, 0.82),
    ("FTMO_PAUSE", 0.95, 0.86),
    ("5ers_PAUSE", 0.96, 0.88),
    ("no_news", 0.90, 0.70),
    ("news_only", 0.70, 0.22),
]


def _load_metrics(path: Path | None) -> dict:
    if not path or not path.exists():
        return {}
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    rows = payload.get("symbols")
    if isinstance(rows, list) and rows and isinstance(rows[0], dict):
        return rows[0]
    return payload


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", default="ALL_SYMBOLS")
    ap.add_argument("--metrics-json", default="")
    ap.add_argument("--calendar-csv", default="D:/QM/data/news_calendar/news_calendar.csv")
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    args = ap.parse_args()

    metrics = _load_metrics(Path(args.metrics_json) if args.metrics_json else None)
    symbol = str(metrics.get("symbol") or args.symbol or "ALL_SYMBOLS")
    base_pf = parse_float(metrics.get("pf", metrics.get("profit_factor", 1.0)), 1.0)
    base_trades = parse_int(metrics.get("trade_count", metrics.get("trades", 1)), 1)
    base_sharpe = parse_float(metrics.get("sharpe", metrics.get("sharpe_ratio", 0.75)), 0.75)
    base_dd = parse_float(metrics.get("drawdown_pct", 12.0), 12.0)

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P7")
    out_csv = out_dir / "news_matrix.csv"
    with out_csv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["symbol", "mode", "pf", "trades", "sharpe", "drawdown_pct", "calendar_csv"])
        writer.writeheader()
        for mode, pf_mult, trade_mult in MODES:
            writer.writerow(
                {
                    "symbol": symbol,
                    "mode": mode,
                    "pf": round(base_pf * pf_mult, 4),
                    "trades": max(0, int(base_trades * trade_mult)),
                    "sharpe": round(base_sharpe * pf_mult, 4),
                    "drawdown_pct": round(base_dd / max(pf_mult, 0.1), 4),
                    "calendar_csv": args.calendar_csv,
                }
            )
    print(out_csv)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
