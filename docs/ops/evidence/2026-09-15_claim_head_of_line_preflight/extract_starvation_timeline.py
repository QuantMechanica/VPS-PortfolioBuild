"""Read-only timeline extraction for the 2026-09-15 head-of-line claim-order
preflight starvation (ticket c30eebc8-c655-4425-9c01-7dc43348992a).

Scans terminal_worker_T*.log (JSON lines) for stage_event=="claim_result"
entries inside the incident window [08:47Z, 09:32Z] and writes one CSV row
per claim attempt: terminal, at_utc, claimed, reason, history_skipped,
q08_dsr_context_skipped, ram_class_skipped (from the claim_result's own
`skips` summary field when present). Read-only: opens log files for read
only, writes only inside this evidence directory.
"""
import csv
import json
from pathlib import Path

LOG_DIR = Path(r"D:/QM/strategy_farm/logs")
WINDOW_START = "2026-09-15T08:47:00+00:00"
WINDOW_END = "2026-09-15T09:32:00+00:00"
OUT = Path(__file__).resolve().parent / "starvation_timeline_0847_0932.csv"
TAIL_BYTES = 6_000_000  # window is ~45min; recent enough to sit well inside this tail


def main() -> None:
    rows = []
    for path in sorted(LOG_DIR.glob("terminal_worker_T*.log")):
        terminal = path.stem.replace("terminal_worker_", "")
        size = path.stat().st_size
        with path.open("rb") as handle:
            handle.seek(max(0, size - TAIL_BYTES))
            raw = handle.read().decode("utf-8", errors="replace")
        for line in raw.splitlines():
            line = line.strip()
            if '"claim_result"' not in line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("stage_event") != "claim_result":
                continue
            at = str(entry.get("at_utc") or "")
            if not (WINDOW_START <= at <= WINDOW_END):
                continue
            skips = entry.get("skips") or {}
            rows.append({
                "terminal": terminal,
                "at_utc": at,
                "claimed": entry.get("claimed"),
                "reason": entry.get("reason"),
                "claimed_item_id": entry.get("claimed_item_id"),
                "history_skipped": skips.get("history_preflight_deferred") or skips.get("history_skipped"),
                "q08_dsr_context_skipped": skips.get("q08_dsr_context_skipped"),
                "ram_class_skipped": skips.get("ram_class_skipped"),
                "history_claim_preflights_count": len(entry.get("history_claim_preflights") or []),
            })
    rows.sort(key=lambda r: (r["at_utc"], r["terminal"]))
    with OUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=[
            "terminal", "at_utc", "claimed", "reason", "claimed_item_id",
            "history_skipped", "q08_dsr_context_skipped", "ram_class_skipped",
            "history_claim_preflights_count",
        ])
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} rows to {OUT}")
    terminals_with_rows = sorted({r["terminal"] for r in rows})
    print("terminals represented:", terminals_with_rows)
    claimed_rows = [r for r in rows if r["claimed"]]
    print(f"claimed=true rows: {len(claimed_rows)}")
    for r in claimed_rows:
        print(" ", r["at_utc"], r["terminal"], r["claimed_item_id"])


if __name__ == "__main__":
    main()
