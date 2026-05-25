"""Generate the Q10 baseline JSON for KS-test kill-switch (FW4).

Per 2026-05-23 pipeline rewrite (Vault Q10 Full-History Confirmation + Q13
Live Burn-In on DXZ). When an (EA, symbol) pair PASSes Q10, this script
parses the canonical full-history report and writes a sorted trade-net-
profit baseline that the live KS-test compares against.

Output path (consumed by `QM_KillSwitchKS.mqh` at OnInit):
    D:/QM/data/baselines/QM5_<ea>_<symbol_underscored>.json

JSON schema:
    {
      "ea_id": 1056,
      "symbol": "NDX.DWX",
      "spec_version": "Q10-2026-05-23",
      "generated_at_utc": "...",
      "n": 412,
      "mean": 69.05,
      "std": 348.21,
      "trades_sorted": [...]      # sorted ascending, full distribution
      "hash": "<sha256 of trades_sorted>"
    }

Usage:
    # Single (EA, symbol)
    python gen_q10_baseline.py --ea-id 1056 --symbol NDX.DWX \
        --report D:/QM/reports/pipeline/QM5_1056/Q10/NDX.DWX/report.htm

    # Auto-discover all Q10-PASS pairs in the latest run
    python gen_q10_baseline.py --discover D:/QM/reports/pipeline
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import statistics
import sys
from pathlib import Path

BASELINE_DIR = Path("D:/QM/data/baselines")

# MT5 .htm report parsing: extract the deals table (DEAL_ENTRY=OUT rows)
# and read the per-trade net profit. MT5 reports are UTF-16 LE BOM by default.
DEAL_ROW_RE = re.compile(
    r"<tr[^>]*>.*?</tr>",
    re.DOTALL | re.IGNORECASE,
)
PROFIT_COL_RE = re.compile(r"-?\d[\d,]*\.\d{2}")


def read_mt5_report(path: Path) -> str:
    """Read an MT5 .htm report — UTF-16 LE BOM by default; fall back to utf-8."""
    raw = path.read_bytes()
    if raw[:2] == b"\xff\xfe":
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")


def extract_per_trade_profits(htm: str) -> list[float]:
    """Extract per-trade net profits from the MT5 'Deals' or 'Orders' table.

    Strategy: find every <tr> row, identify ones that look like a closing
    deal (have a numeric profit cell + the 'out' or 'close' marker), pull
    the profit column. MT5 report layouts vary by language and version, so
    we look for the most-common deal-table heuristic.
    """
    # Strip tags from a row to get readable text
    def strip_tags(s: str) -> str:
        return re.sub(r"<[^>]+>", " ", s)

    profits: list[float] = []
    rows = DEAL_ROW_RE.findall(htm)
    for row in rows:
        text = strip_tags(row).strip()
        lower = text.lower()
        # Closing deals show 'out' (English) or 'aus' / 'sortie' (DE/FR localised)
        if not (" out " in f" {lower} " or " aus " in f" {lower} " or " sortie " in f" {lower} "):
            continue
        # Last decimal number on the row is typically the running balance;
        # the second-to-last is usually the per-trade profit. Heuristic; if
        # the report format diverges, the auto-discover path will skip with
        # 0 trades extracted and the operator gets a clear FAIL.
        nums = PROFIT_COL_RE.findall(text)
        if len(nums) < 2:
            continue
        try:
            profit_str = nums[-2].replace(",", "")
            profits.append(float(profit_str))
        except ValueError:
            continue
    return profits


def write_baseline(ea_id: int, symbol: str, profits: list[float]) -> Path:
    sorted_profits = sorted(profits)
    n = len(sorted_profits)
    mean = statistics.fmean(sorted_profits) if n > 0 else 0.0
    std = statistics.pstdev(sorted_profits) if n > 1 else 0.0
    body_for_hash = ",".join(f"{v:.6f}" for v in sorted_profits)
    h = hashlib.sha256(body_for_hash.encode("utf-8")).hexdigest()

    BASELINE_DIR.mkdir(parents=True, exist_ok=True)
    sym_clean = symbol.replace(".", "_")
    out_path = BASELINE_DIR / f"QM5_{ea_id}_{sym_clean}.json"

    payload = {
        "ea_id": ea_id,
        "symbol": symbol,
        "spec_version": "Q10-2026-05-23",
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "n": n,
        "mean": round(mean, 6),
        "std": round(std, 6),
        "trades_sorted": sorted_profits,
        "hash": h,
    }
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return out_path


def process_one(ea_id: int, symbol: str, report_path: Path) -> bool:
    if not report_path.exists():
        print(f"  FAIL  report not found: {report_path}", file=sys.stderr)
        return False
    htm = read_mt5_report(report_path)
    profits = extract_per_trade_profits(htm)
    if len(profits) < 10:
        print(f"  FAIL  too few trades extracted: {len(profits)} (need ≥10)", file=sys.stderr)
        return False
    out = write_baseline(ea_id, symbol, profits)
    print(f"  PASS  QM5_{ea_id} {symbol}  n={len(profits)}  -> {out.name}")
    return True


def discover_q10_pass(pipeline_root: Path) -> list[tuple[int, str, Path]]:
    """Walk D:/QM/reports/pipeline/QM5_*/Q10/<symbol>/report.htm and
    enumerate PASS reports. Currently Q10 isn't producing reports yet
    (pipeline code not built); this scaffold is here for when it does.
    """
    out: list[tuple[int, str, Path]] = []
    if not pipeline_root.exists():
        return out
    for ea_dir in sorted(pipeline_root.iterdir()):
        if not ea_dir.is_dir() or not ea_dir.name.startswith("QM5_"):
            continue
        try:
            ea_id = int(ea_dir.name.split("_")[1])
        except (IndexError, ValueError):
            continue
        q10 = ea_dir / "Q10"
        if not q10.exists():
            continue
        for sym_dir in sorted(q10.iterdir()):
            if not sym_dir.is_dir():
                continue
            report = sym_dir / "report.htm"
            if report.exists():
                out.append((ea_id, sym_dir.name, report))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate Q10 KS-test baseline JSON")
    ap.add_argument("--ea-id", type=int, help="EA id (with --symbol + --report)")
    ap.add_argument("--symbol", help="symbol e.g. NDX.DWX")
    ap.add_argument("--report", type=Path, help="path to Q10 MT5 .htm report")
    ap.add_argument("--discover", type=Path, help="walk pipeline root and emit baselines for every Q10-PASS")
    args = ap.parse_args()

    if args.discover:
        targets = discover_q10_pass(args.discover)
        if not targets:
            print(f"no Q10 reports found under {args.discover}", file=sys.stderr)
            return 1
        n_pass = sum(1 for (ea, sym, rep) in targets if process_one(ea, sym, rep))
        print(f"\n{n_pass}/{len(targets)} baselines written.")
        return 0 if n_pass == len(targets) else 1

    if not (args.ea_id and args.symbol and args.report):
        ap.print_usage(sys.stderr)
        return 2

    return 0 if process_one(args.ea_id, args.symbol, args.report) else 1


if __name__ == "__main__":
    sys.exit(main())
