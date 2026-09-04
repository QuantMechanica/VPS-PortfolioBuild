"""Supplemental CopyRates cross-check; does NOT claim raw-tick/tester parity."""
import csv
import hashlib
import json
import random
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    results = []
    for symbol in ("EURUSD.DWX", "GBPUSD.DWX"):
        base = Path("D:/QM/mt5/T_Export/MQL5/Files")
        daily, hourly = base / f"{symbol}_D1.csv", base / f"{symbol}_H1.csv"
        with daily.open(newline="") as f:
            d1 = {int(r["time"]): r for r in csv.DictReader(f)}
        groups = defaultdict(list)
        with hourly.open(newline="") as f:
            for row in csv.DictReader(f):
                groups[int(row["time"]) // 86400 * 86400].append(row)
        eligible = sorted(t for t in d1 if t in groups and 2019 <= datetime.fromtimestamp(t, timezone.utc).year <= 2025)
        days = random.Random(20260904).sample(eligible, 20)
        checks = []
        for day in sorted(days):
            rows = sorted(groups[day], key=lambda r: int(r["time"]))
            actual = dict(open=float(rows[0]["open"]), high=max(float(r["high"]) for r in rows),
                          low=min(float(r["low"]) for r in rows), close=float(rows[-1]["close"]),
                          tickvol=sum(int(r["tickvol"]) for r in rows))
            expected = {k: float(d1[day][k]) for k in actual}
            checks.append({"broker_day": datetime.fromtimestamp(day, timezone.utc).date().isoformat(),
                           "h1_bars": len(rows), "daily_export": expected, "h1_aggregation": actual,
                           "exact_ohlcv_match": actual == expected})
        archive = Path(f"D:/QM/archive/Custom_master/ticks/{symbol}")
        files = sorted(archive.glob("*.tkc"))
        results.append({"symbol": symbol, "seed": 20260904, "sample_days": 20,
                        "sample_population_days": len(eligible), "matched": sum(c["exact_ohlcv_match"] for c in checks),
                        "daily_path": str(daily), "daily_sha256": digest(daily),
                        "hourly_path": str(hourly), "hourly_sha256": digest(hourly),
                        "archive_path": str(archive), "native_tkc_files": len(files),
                        "native_tkc_first_last": [files[0].name, files[-1].name],
                        "archive_total_bytes": sum(p.stat().st_size for p in files),
                        "checks": checks})
    output = {"schema": "qm.pattern_fire_count.supplemental_bar_probe.v1",
              "raw_tick_derivation_verified": False, "tester_bar_spot_checks_verified": False,
              "limitation": "Independent D1 versus H1 native CopyRates exports only. No decoder for native TKC. "
                            "Retained baseline report directories contain report.htm/tester.ini, not the referenced tester logs.",
              "results": results}
    path = Path(__file__).with_suffix(".json")
    path.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps([{k: r[k] for k in ("symbol", "matched", "sample_days", "native_tkc_files")} for r in results]))


if __name__ == "__main__":
    main()
