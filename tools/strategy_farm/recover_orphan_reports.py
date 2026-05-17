"""Recover orphan MT5 reports for work_items that hit REPORT_MISSING.

The run_smoke.ps1 wrapper uses a tight timestamp-match to find the MT5
tester's output .htm file. MT5 sometimes writes with a slightly different
timestamp than what run_smoke.ps1 expected (sub-minute drift between
script-start tag and tester-launch wall-clock). When that mismatch
happens, run_smoke.ps1 marks the run as REPORT_MISSING even though
the tester ran successfully and the .htm exists.

This recovery tool:
  1. Find work_items with status='done' verdict='FAIL' AND
     verdict_reason containing REPORT_MISSING.
  2. For each, glob `D:/QM/mt5/T*/QM5_<id>_<symbol_no_dot>_*_run_01.htm`
     for files newer than work_item's updated_at - 30 min.
  3. If a matching .htm exists, parse it for total_trades / net_profit /
     final_balance / OnTester result.
  4. Derive verdict (PASS if trades >= min_trades AND OnTester > 0).
  5. Update work_item: verdict, evidence_path (to recovered .htm).

OWNER 2026-05-17 /loop iteration 6: 11 P3 FAILs that were actually
real backtest runs with real PnL data — we just couldn't see them.
This recovery tool makes that data visible without needing to re-run
the (already-completed) backtests.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sqlite3
import sys
from pathlib import Path

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
MT5_ROOT = Path(r"D:\QM\mt5")


def _connect() -> sqlite3.Connection:
    con = sqlite3.connect(str(DB))
    con.row_factory = sqlite3.Row
    return con


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _ea_num(ea_id: str) -> str | None:
    m = re.match(r"^QM5_(\d+)$", ea_id)
    return m.group(1) if m else None


def _symbol_safe(symbol: str) -> str:
    # 'NDX.DWX' → 'NDX_DWX' (MT5 substitutes '.' for '_' in report filenames)
    return symbol.replace(".", "_")


def find_recent_reports(ea_id: str, symbol: str, after_iso: str) -> list[Path]:
    """Find .htm reports in any D:/QM/mt5/T*/ dir for this (EA, symbol)
    newer than `after_iso`."""
    num = _ea_num(ea_id)
    if not num:
        return []
    sym = _symbol_safe(symbol)
    try:
        cutoff = dt.datetime.fromisoformat(after_iso.replace("Z", "+00:00")).timestamp()
    except Exception:
        return []
    cutoff -= 1800  # allow 30-min look-back window
    pattern = f"QM5_{num}_{sym}_*_run_01.htm"
    hits: list[Path] = []
    for tdir in sorted(MT5_ROOT.glob("T*")):
        for f in tdir.glob(pattern):
            try:
                if f.stat().st_mtime >= cutoff:
                    hits.append(f)
            except OSError:
                pass
    # Newest first
    hits.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return hits


def parse_report_htm(path: Path) -> dict:
    """Best-effort parser for MT5 tester .htm. Returns {total_trades, net_profit, ...}.

    MT5 saves UTF-16 LE HTML. Labels of interest (per MT5 build 5833 report):
      "Total Net Profit:" → net profit
      "Total Trades:"     → total trade count
      "Profit Factor:"    → PF
      "Sharpe Ratio:"     → annualized Sharpe
      "Maximal Drawdown:" → max equity DD ($ + %)
    Values are in adjacent <td> with class="msp_t" or just numeric text.
    """
    try:
        text = path.read_text(encoding="utf-16", errors="ignore")
    except Exception:
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            return {}
    # Strip HTML
    no_html = re.sub(r"<[^>]+>", " ", text)
    # Collapse whitespace
    flat = re.sub(r"\s+", " ", no_html)
    out: dict = {}

    def grab_after(label_re: str, value_re: str = r"(-?[\d \xa0,.]+(?:\s*%)?)") -> str | None:
        m = re.search(label_re + r"\s*:?\s*" + value_re, flat, re.IGNORECASE)
        return m.group(1) if m else None

    def to_float(s: str) -> float | None:
        if s is None: return None
        cleaned = s.replace("\xa0", "").replace(" ", "").replace(",", ".")
        # Multiple decimal dots (e.g. "1.234.56") → strip thousands first
        if cleaned.count(".") > 1:
            parts = cleaned.split(".")
            cleaned = "".join(parts[:-1]) + "." + parts[-1]
        cleaned = cleaned.rstrip("%")
        try: return float(cleaned)
        except ValueError: return None

    raw_trades = grab_after(r"Total\s+Trades")
    if raw_trades:
        try: out["total_trades"] = int(raw_trades.strip().split()[0].replace(",", "").replace(" ", ""))
        except ValueError: pass

    raw_profit = grab_after(r"Total\s+Net\s+Profit")
    if raw_profit:
        v = to_float(raw_profit)
        if v is not None: out["net_profit"] = v

    raw_pf = grab_after(r"Profit\s+Factor")
    if raw_pf:
        v = to_float(raw_pf)
        if v is not None: out["profit_factor"] = v

    raw_sharpe = grab_after(r"Sharpe\s+Ratio")
    if raw_sharpe:
        v = to_float(raw_sharpe)
        if v is not None: out["sharpe"] = v

    raw_dd = grab_after(r"Maximal\s+Drawdown")
    if raw_dd:
        v = to_float(raw_dd)
        if v is not None: out["max_dd"] = v

    return out


def derive_verdict(stats: dict, min_trades: int = 5) -> tuple[str, str]:
    """Derive PASS/FAIL from parsed stats."""
    trades = stats.get("total_trades", 0) or 0
    if trades < min_trades:
        return "INVALID", f"MIN_TRADES_NOT_MET (got {trades})"
    profit = stats.get("net_profit", 0) or 0
    if profit > 0:
        return "PASS", f"trades={trades} net_profit={profit:.2f}"
    return "FAIL", f"trades={trades} net_profit={profit:.2f} (negative)"


def recover(dry_run: bool = False, limit: int = 50) -> dict:
    con = _connect()
    out = {"checked": 0, "matched": 0, "updated": 0, "rows": []}
    rows = list(con.execute(
        """
        SELECT id, ea_id, symbol, phase, updated_at, payload_json
        FROM work_items
        WHERE status='done' AND verdict='FAIL'
        ORDER BY updated_at DESC LIMIT ?
        """, (limit,),
    ))
    for r in rows:
        out["checked"] += 1
        p = json.loads(r["payload_json"]) if r["payload_json"] else {}
        reason = (p.get("verdict_reason") or "")
        if "REPORT_MISSING" not in reason and "METATESTER_HUNG" not in reason:
            continue
        hits = find_recent_reports(r["ea_id"], r["symbol"], r["updated_at"])
        if not hits:
            out["rows"].append({
                "work_item": r["id"], "ea_id": r["ea_id"], "symbol": r["symbol"],
                "status": "no .htm found in MT5 dirs",
            })
            continue
        out["matched"] += 1
        report = hits[0]
        stats = parse_report_htm(report)
        verdict, reason_str = derive_verdict(stats)
        out["rows"].append({
            "work_item": r["id"], "ea_id": r["ea_id"], "symbol": r["symbol"],
            "phase": r["phase"],
            "report": str(report), "stats": stats,
            "new_verdict": verdict, "reason": reason_str,
        })
        if dry_run:
            continue
        p["recovered_from_orphan_report"] = str(report)
        p["recovered_stats"] = stats
        p["verdict_reason"] = f"recovered: {reason_str}"
        con.execute(
            "UPDATE work_items SET verdict=?, evidence_path=?, payload_json=?, updated_at=? WHERE id=?",
            (verdict, str(report), json.dumps(p), _utc_now(), r["id"]),
        )
        out["updated"] += 1
    if not dry_run:
        con.commit()
    con.close()
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be recovered, don't update DB")
    parser.add_argument("--limit", type=int, default=50,
                        help="Max work_items to check (default 50)")
    args = parser.parse_args()
    result = recover(dry_run=args.dry_run, limit=args.limit)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
