"""Build the E1-D3/D4 review candidate and exact unresolved-anchor taxonomy.

This is staging-only.  It does not publish, mirror, repin, alter holds, or turn a
declaration into a measured pass.
"""
from __future__ import annotations

import argparse
from collections import Counter
import csv
from datetime import datetime, timezone
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.strategy_farm import news_calendar_full_scope_seal as seal
from tools.strategy_farm import news_calendar_gate as gate
from tools.strategy_farm import news_calendar_repair as repair


DECISION = "OWNER-DEC-CALENDAR-E1A-20260905"

# The task payload supplies the event-identity decisions and civil release
# conventions.  Each timestamp retains its civil offset on the actual date;
# ``repair.stamp`` converts it to an absolute instant for comparisons.
NEW_ANCHORS = (
    ("EUR", "ecb-interest-rate-decision", "2024-09-12T14:15:00+02:00", "rate",
     "https://www.ecb.europa.eu/press/govcdec/mopo/html/index.en.html ; https://www.ecb.europa.eu/press/pr/date/2024/html/ecb.mp240912~67cb23badb.en.html", "Europe/Berlin"),
    ("EUR", "consumer-price-index-yy", "2025-02-03T11:00:00+01:00", "nonrate",
     "https://ec.europa.eu/eurostat/en/web/products-euro-indicators/w/2-03022025-ap ; CEO interpretation: HIGH EUR CPI y/y is the flash estimate", "Europe/Berlin"),
    ("GBP", "boe-interest-rate-decision", "2024-08-01T12:00:00+01:00", "rate",
     "https://www.bankofengland.co.uk/monetary-policy-summary-and-minutes/2024/august-2024 ; https://www.bankofengland.co.uk/monetary-policy", "Europe/London"),
    ("JPY", "boj-interest-rate-decision", "2024-07-31T12:56:00+09:00", "rate",
     "https://www.boj.or.jp/en/mopo/mpmdeci/state_2024/k240731a.htm", "Asia/Tokyo"),
    ("JPY", "boj-interest-rate-decision", "2025-01-24T12:23:00+09:00", "rate",
     "https://www.boj.or.jp/en/mopo/mpmdeci/state_2025/k250124a.htm", "Asia/Tokyo"),
    ("JPY", "tokyo-cpi-excl-food-energy-yy", "2025-01-31T08:30:00+09:00", "nonrate",
     "https://www.stat.go.jp/english/data/cpi/1585.htm", "Asia/Tokyo"),
    ("AUD", "rba-interest-rate-decision", "2024-11-05T14:30:00+11:00", "rate",
     "https://www.rba.gov.au/monetary-policy/int-rate-decisions/2024/", "Australia/Sydney"),
    ("AUD", "consumer-price-index-qq", "2025-01-29T11:30:00+11:00", "nonrate",
     "https://www.abs.gov.au/methodologies/consumer-price-index-australia-methodology/dec-quarter-2024", "Australia/Sydney"),
    ("CAD", "consumer-price-index-yy", "2025-01-21T08:30:00-05:00", "nonrate",
     "https://www150.statcan.gc.ca/n1/daily-quotidien/250121/dq250121a-eng.htm ; Statistics Canada The Daily 08:30 ET convention", "America/Toronto"),
)


OFFICIAL_SCHEDULE_CLASSES = {
    "10-y Bond Auction", "30-y Bond Auction", "Advance GDP Price Index q/q", "Advance GDP q/q",
    "Average Hourly Earnings m/m", "CPI m/m", "CPI y/y", "Chicago PMI", "Core CPI m/m",
    "Core CPI y/y", "Core PCE Price Index m/m", "Core PPI m/m", "Employment Cost Index q/q",
    "FOMC Financial Stability Report", "FOMC Meeting Minutes", "FOMC Press Conference",
    "FOMC Statement", "Fed Monetary Policy Report", "Federal Funds Rate", "Final GDP Price Index q/q",
    "Final Manufacturing PMI", "Flash Manufacturing PMI", "Flash Services PMI", "Goods Trade Balance",
    "Housing Starts", "ISM Manufacturing PMI", "Non-Farm Employment Change", "PPI m/m",
    "Pending Home Sales m/m", "Personal Spending m/m", "Prelim Benchmark Payrolls Revision",
    "Prelim GDP Price Index q/q", "Prelim GDP q/q", "Prelim UoM Consumer Sentiment",
    "Prelim UoM Inflation Expectations", "Revised UoM Consumer Sentiment",
    "Revised UoM Inflation Expectations", "S&P/CS Composite-20 HPI y/y", "Unemployment Rate",
}

OFFICIAL_FAMILY = {
    "10-y Bond Auction": "US_TREASURY", "30-y Bond Auction": "US_TREASURY",
    "Advance GDP Price Index q/q": "BEA", "Advance GDP q/q": "BEA",
    "Core PCE Price Index m/m": "BEA", "Final GDP Price Index q/q": "BEA",
    "Personal Spending m/m": "BEA", "Prelim GDP Price Index q/q": "BEA", "Prelim GDP q/q": "BEA",
    "Average Hourly Earnings m/m": "BLS", "CPI m/m": "BLS", "CPI y/y": "BLS",
    "Core CPI m/m": "BLS", "Core CPI y/y": "BLS", "Core PPI m/m": "BLS",
    "Employment Cost Index q/q": "BLS", "PPI m/m": "BLS",
    "Prelim Benchmark Payrolls Revision": "BLS", "Unemployment Rate": "BLS",
    "FOMC Financial Stability Report": "FEDERAL_RESERVE", "FOMC Meeting Minutes": "FEDERAL_RESERVE",
    "FOMC Press Conference": "FEDERAL_RESERVE", "FOMC Statement": "FEDERAL_RESERVE",
    "Fed Monetary Policy Report": "FEDERAL_RESERVE", "Federal Funds Rate": "FEDERAL_RESERVE",
    "Goods Trade Balance": "US_CENSUS", "Housing Starts": "US_CENSUS",
    "Chicago PMI": "MNI_CHICAGO", "ISM Manufacturing PMI": "ISM",
    "Non-Farm Employment Change": "ADP", "Pending Home Sales m/m": "NAR",
    "Final Manufacturing PMI": "SP_GLOBAL", "Flash Manufacturing PMI": "SP_GLOBAL",
    "Flash Services PMI": "SP_GLOBAL", "S&P/CS Composite-20 HPI y/y": "SP_GLOBAL",
    "Prelim UoM Consumer Sentiment": "UNIVERSITY_OF_MICHIGAN",
    "Prelim UoM Inflation Expectations": "UNIVERSITY_OF_MICHIGAN",
    "Revised UoM Consumer Sentiment": "UNIVERSITY_OF_MICHIGAN",
    "Revised UoM Inflation Expectations": "UNIVERSITY_OF_MICHIGAN",
}


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build_anchor_catalog(base_path: Path, output: Path) -> dict:
    base = json.loads(base_path.read_text(encoding="utf-8-sig"))
    if base.get("decision_id") != DECISION or not isinstance(base.get("anchors"), list):
        raise ValueError("base official-anchor catalogue authority envelope invalid")
    anchors = list(base["anchors"])
    seen = {(item["currency"], item["event_code"], repair.stamp(item["utc"])) for item in anchors}
    for currency, code, instant, kind, source, zone in NEW_ANCHORS:
        key = (currency, code, repair.stamp(instant))
        if key in seen:
            continue
        seen.add(key)
        anchors.append({"currency": currency, "event_code": code, "utc": instant, "kind": kind,
                        "source": source, "source_local": instant, "timezone_rule": zone})
    result = {
        "schema": "qm.official-anchor-catalog/e1d34-v1",
        "decision_id": DECISION,
        "approved_by": "CEO-routed E1-D3/D4 task d74fa978; source ingestion only, no publication approval",
        "approved_at": datetime.now(timezone.utc).isoformat(),
        "anchors": anchors,
        "publication_authorized": False,
        "source_notes": [
            "EUR CPI y/y is the Eurostat flash estimate under the CEO task assumption; the final release is not a separate HIGH anchor.",
            "CAD CPI uses Statistics Canada The Daily's 08:30 ET release convention.",
            "Civil offsets are retained per actual date; no fixed offset is substituted across DST boundaries.",
        ],
    }
    write_json(output, result)
    return result


def adjudicate(anchor_detail: Path, verification: Path, output_dir: Path) -> dict:
    with verification.open(encoding="utf-8-sig") as handle:
        failed_groups = json.load(handle)["gates"]["6.1_anchor_shares"]["failed_groups"]
    group_classes = {row["class"] for row in failed_groups}
    if len(group_classes) != 79:
        raise ValueError(f"expected 79 failing HIGH classes, got {len(group_classes)}")
    failed_rows = []
    with anchor_detail.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            if row["status"] == "FAIL":
                failed_rows.append(row)
    if len(failed_rows) != 2591:
        raise ValueError(f"expected 2,591 failed/unverified HIGH rows, got {len(failed_rows)}")

    group_counter = Counter((row["class"], row["source"]) for row in failed_groups)
    group_rows = Counter()
    for row in failed_groups:
        group_rows[row["class"]] += int(row["total"])
    failed_counter = Counter(row["class"] for row in failed_rows)
    classes = []
    for name in sorted(group_classes):
        schedulable = name in OFFICIAL_SCHEDULE_CLASSES
        classes.append({
            "event_class": name,
            "disposition": "OFFICIAL_SCHEDULE_ANCHOR_REQUIRED" if schedulable else "DECLARED_EVENT_BY_EVENT_UNANCHORED",
            "authority_family": OFFICIAL_FAMILY.get(name) if schedulable else None,
            "failed_groups": sum(count for (event, _), count in group_counter.items() if event == name),
            "failed_group_rows": group_rows[name],
            "failed_or_unverified_high_rows": failed_counter[name],
            "declaration_is_measured_pass": False,
        })
    totals = Counter(item["disposition"] for item in classes)
    row_totals = Counter()
    for item in classes:
        row_totals[item["disposition"]] += item["failed_or_unverified_high_rows"]
    report = {
        "schema": "qm.news-calendar-anchor-taxonomy/e1d34-v1",
        "source_verification": str(verification.resolve()),
        "source_anchor_detail": str(anchor_detail.resolve()),
        "failing_event_classes": len(classes),
        "failed_groups": len(failed_groups),
        "failed_group_rows": sum(int(row["total"]) for row in failed_groups),
        "failed_or_unverified_high_rows": len(failed_rows),
        "class_disposition_counts": dict(sorted(totals.items())),
        "row_disposition_counts": dict(sorted(row_totals.items())),
        "classes": classes,
        "policy": "Official schedules identify work still required; ad-hoc events remain declared. Neither disposition is a measured pass.",
    }
    write_json(output_dir / "anchor_taxonomy.json", report)
    with (output_dir / "high_row_adjudication.csv").open("w", encoding="utf-8", newline="") as handle:
        fields = list(failed_rows[0]) + ["disposition", "authority_family", "declaration_is_measured_pass"]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        by_class = {item["event_class"]: item for item in classes}
        for row in failed_rows:
            item = by_class[row["class"]]
            writer.writerow({**row, "disposition": item["disposition"],
                             "authority_family": item["authority_family"] or "",
                             "declaration_is_measured_pass": "false"})
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-anchors", type=Path, required=True)
    parser.add_argument("--prior-candidate", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        raise ValueError("E1-D3/D4 output must be a new immutable staging child")
    args.out.mkdir(parents=True)
    catalogue = build_anchor_catalog(args.base_anchors, args.out / "official_anchors.json")
    taxonomy = adjudicate(args.prior_candidate / "diagnose/anchor_detail.csv",
                          args.prior_candidate / "verification.json", args.out)
    candidate = args.out / "candidate"
    result = repair.run_repair(
        gate.DEFAULT_SOURCE_DIR / gate.PRIMARY_NAME,
        gate.DEFAULT_SOURCE_DIR / gate.SECONDARY_NAME,
        repair.NATIVE_DIR,
        repair.NATIVE_DIR,
        candidate,
        extra_anchors=args.out / "official_anchors.json",
        declare_inadmissible=True,
    )
    seal_path = args.out / "full_scope_seal.json"
    seal_report = seal.analyze_candidate(candidate)
    with seal_path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(seal_report, handle, indent=2, sort_keys=True, ensure_ascii=False)
        handle.write("\n")
    summary = {
        "schema": "qm.news-calendar-e1d34-continuation/v1",
        "production_write": False,
        "repin_recorded": False,
        "holds_changed": False,
        "official_anchor_count": len(catalogue["anchors"]),
        "taxonomy": {key: taxonomy[key] for key in (
            "failing_event_classes", "failed_groups", "failed_group_rows",
            "failed_or_unverified_high_rows", "class_disposition_counts", "row_disposition_counts")},
        "candidate": result,
        "seal_status": seal_report["status"],
        "multi_plan": seal_report["multi_plan"],
        "paths": {"candidate": str(candidate.resolve()), "seal": str(seal_path.resolve())},
    }
    write_json(args.out / "result.json", summary)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
