"""Report-only semantic diagnostics for QuantMechanica news calendars.

This module is deliberately separate from ``news_calendar_gate.py``.  It reads
calendar/export files and writes evidence, but never changes gate status,
calendar bytes, database rows, scheduled tasks, or terminal state.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, Sequence


SCHEMA = "qm.news-calendar-semantic-diagnose/v1"
DST_RULE = "qm.dst_rule.us.v1"
DEFAULT_CALENDAR_DIR = Path(r"D:/QM/data/news_calendar")
DEFAULT_NATIVE_DIR = Path(r"D:/QM/mt5/T_Export/MQL5/Files")
DEFAULT_REPORT_ROOT = Path(r"D:/QM/reports/news_calendar")
DEFAULT_EVIDENCE_COPY = Path(
    r"C:/QM/repo/docs/ops/evidence/2026-09-05_news_calendar_diagnose.md"
)
CURRENCIES = ("USD", "EUR", "GBP", "JPY")


# Forex Factory event name -> native MT5 event name.  The native files contain
# only MT5-high events; unmapped names remain visible in the unmatched counts.
NATIVE_NAME_MAP: dict[str, dict[str, str]] = {
    "USD": {
        "Non-Farm Employment Change": "Nonfarm Payrolls",
        "Unemployment Rate": "Unemployment Rate",
        "Average Hourly Earnings m/m": "Average Hourly Earnings m/m",
        "CPI m/m": "CPI m/m",
        "Core CPI m/m": "Core CPI m/m",
        "CPI y/y": "CPI y/y",
        "PPI m/m": "PPI m/m",
        "Retail Sales m/m": "Retail Sales m/m",
        "Core Retail Sales m/m": "Core Retail Sales m/m",
        "Unemployment Claims": "Initial Jobless Claims",
        "Core PCE Price Index m/m": "Core PCE Price Index m/m",
        "Philly Fed Manufacturing Index": "Philadelphia Fed Manufacturing Index",
        "JOLTS Job Openings": "JOLTS Job Openings",
        "ISM Manufacturing PMI": "ISM Manufacturing PMI",
        "ISM Services PMI": "ISM Non-Manufacturing PMI",
        "ADP Non-Farm Employment Change": "ADP Nonfarm Employment Change",
        "CB Consumer Confidence": "CB Consumer Confidence Index",
        "Crude Oil Inventories": "EIA Crude Oil Stocks Change",
        "Federal Funds Rate": "Fed Interest Rate Decision",
        "FOMC Press Conference": "FOMC Press Conference",
        "Core Durable Goods Orders m/m": "Durable Goods Orders m/m",
        "Advance GDP q/q": "GDP q/q",
        "Prelim GDP q/q": "GDP q/q",
        "Final GDP q/q": "GDP q/q",
    },
    "EUR": {
        "ECB President Lagarde Speaks": "ECB President Lagarde Speech",
        "ECB President Draghi Speaks": "ECB President Draghi Speech",
        "ECB Press Conference": "ECB Monetary Policy Press Conference",
        "Main Refinancing Rate": "ECB Interest Rate Decision",
        "Monetary Policy Statement": "ECB Interest Rate Decision",
        "CPI Flash Estimate y/y": "CPI y/y",
        "EU Economic Summit": "EU Leaders Summit",
        "Euro Summit": "EU Leaders Summit",
        "EU Economic Forecasts": "EU Economic Forecasts",
    },
    "GBP": {
        "BOE Gov Bailey Speaks": "BoE Governor Bailey Speech",
        "BOE Gov Carney Speaks": "BoE Governor Carney Speech",
        "BOE Press Conference": "BoE Monetary Policy Press Conference",
        "Official Bank Rate": "BoE Interest Rate Decision",
        "Monetary Policy Summary": "BoE Interest Rate Decision",
        "CPI y/y": "CPI y/y",
        "GDP m/m": "GDP m/m",
        "Prelim GDP q/q": "GDP q/q",
        "Second Estimate GDP q/q": "GDP q/q",
        "Monetary Policy Report Hearings": "BoE Inflation Report Hearings",
        "Annual Budget Release": "Annual Budget",
        "Autumn Forecast Statement": "Autumn Forecast Statement",
    },
    "JPY": {
        "Monetary Policy Statement": "BoJ Interest Rate Decision",
        "BOJ Policy Rate": "BoJ Interest Rate Decision",
        "BOJ Press Conference": "BoJ Press Conference",
        "BOJ Gov Kuroda Speaks": "BoJ Governor Kuroda Speech",
        "Tokyo Core CPI y/y": "Tokyo CPI excl. Food and Energy y/y",
        "Retail Sales m/m": "Retail Sales m/m",
        "Prelim GDP q/q": "GDP q/q",
    },
}


@dataclass(frozen=True)
class CalendarRow:
    source: str
    instant: datetime
    currency: str
    impact: str
    event: str
    raw: dict[str, str]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _nth_sunday(year: int, month: int, ordinal: int) -> int:
    first = date(year, month, 1).weekday()  # Monday=0, Sunday=6
    return 1 + ((6 - first) % 7) + 7 * (ordinal - 1)


def us_dst_start_utc(year: int) -> datetime:
    """Port of QM_DSTAware_USDSTStartUTC (second Sunday, 07:00Z)."""
    return datetime(year, 3, _nth_sunday(year, 3, 2), 7, tzinfo=timezone.utc)


def us_dst_end_utc(year: int) -> datetime:
    """Port of QM_DSTAware_USDSTEndUTC (first Sunday, 06:00Z)."""
    return datetime(year, 11, _nth_sunday(year, 11, 1), 6, tzinfo=timezone.utc)


def is_us_dst_utc(instant: datetime) -> bool:
    instant = instant.astimezone(timezone.utc)
    return us_dst_start_utc(instant.year) <= instant < us_dst_end_utc(instant.year)


def eastern_local_to_utc(day: date, hour: int, minute: int = 0) -> datetime:
    """Map an unambiguous US/Eastern daytime release to UTC via qm.dst_rule.us.v1."""
    dst_candidate = datetime(day.year, day.month, day.day, hour + 4, minute, tzinfo=timezone.utc)
    if is_us_dst_utc(dst_candidate):
        return dst_candidate
    return datetime(day.year, day.month, day.day, hour + 5, minute, tzinfo=timezone.utc)


def _parse_primary(path: Path) -> tuple[list[CalendarRow], list[dict[str, object]]]:
    rows: list[CalendarRow] = []
    parse_errors: list[dict[str, object]] = []
    with path.open(encoding="utf-8-sig", errors="replace", newline="") as handle:
        for line_number, raw in enumerate(csv.DictReader(handle), 2):
            try:
                instant = datetime.strptime(raw["datetime"], "%Y-%m-%d %H:%M:%S").replace(
                    tzinfo=timezone.utc
                )
            except (KeyError, ValueError) as exc:
                parse_errors.append({"line": line_number, "error": str(exc)})
                continue
            rows.append(
                CalendarRow(
                    source="primary",
                    instant=instant,
                    currency=raw.get("currency", "").strip().upper(),
                    impact=raw.get("impact", "").strip().lower(),
                    event=raw.get("event_name", "").strip(),
                    raw=raw,
                )
            )
    return rows, parse_errors


def _parse_secondary(path: Path) -> tuple[list[CalendarRow], list[dict[str, object]]]:
    rows: list[CalendarRow] = []
    parse_errors: list[dict[str, object]] = []
    with path.open(encoding="utf-8-sig", errors="replace", newline="") as handle:
        for line_number, raw in enumerate(csv.DictReader(handle), 2):
            try:
                instant = datetime.strptime(raw["DateTime_UTC"], "%Y.%m.%d %H:%M").replace(
                    tzinfo=timezone.utc
                )
            except (KeyError, ValueError) as exc:
                parse_errors.append({"line": line_number, "error": str(exc)})
                continue
            rows.append(
                CalendarRow(
                    source="secondary",
                    instant=instant,
                    currency=raw.get("Currency", "").strip().upper(),
                    impact=raw.get("Impact", "").strip().lower(),
                    event=raw.get("Event", "").strip(),
                    raw=raw,
                )
            )
    return rows, parse_errors


def anchor_class(event: str, currency: str) -> tuple[str, int, int] | None:
    """Return (class, ET hour, minute) for explicit scheduled USD anchors."""
    if currency.upper() != "USD":
        return None
    normalized = event.strip().lower()
    if normalized in {"non-farm employment change", "nonfarm payrolls"}:
        return "NFP", 8, 30
    if normalized in {"unemployment claims", "initial jobless claims"}:
        return "UNEMPLOYMENT_CLAIMS", 8, 30
    if normalized == "fomc statement":
        return "FOMC_STATEMENT", 14, 0
    if "retail sales" in normalized:
        return "RETAIL_SALES", 8, 30
    if normalized.startswith("cpi ") or normalized.startswith("core cpi "):
        return "CPI", 8, 30
    if normalized.startswith("ppi ") or normalized.startswith("core ppi "):
        return "PPI", 8, 30
    return None


def diagnose_anchors(rows: Iterable[CalendarRow]) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    detail: list[dict[str, object]] = []
    grouped: dict[tuple[str, str, int], Counter[str]] = defaultdict(Counter)
    for row in rows:
        anchor = anchor_class(row.event, row.currency)
        if anchor is None:
            continue
        event_class, hour, minute = anchor
        expected = eastern_local_to_utc(row.instant.date(), hour, minute)
        delta_minutes = int(round((row.instant - expected).total_seconds() / 60.0))
        time_ok = abs(delta_minutes) <= 5
        schedule_ok = True
        if event_class == "NFP":
            schedule_ok = row.instant.weekday() == 4 and row.instant.day <= 7
        status = "PASS" if time_ok and schedule_ok else "FAIL"
        detail.append(
            {
                "source": row.source,
                "currency": row.currency,
                "event": row.event,
                "class": event_class,
                "year": row.instant.year,
                "stored_utc": row.instant.isoformat(),
                "expected_utc": expected.isoformat(),
                "delta_minutes": delta_minutes,
                "within_5_minutes": time_ok,
                "schedule_rule_ok": schedule_ok,
                "status": status,
            }
        )
        grouped[(row.source, event_class, row.instant.year)][status] += 1
    summary = []
    for (source, event_class, year), counts in sorted(grouped.items()):
        total = counts["PASS"] + counts["FAIL"]
        summary.append(
            {
                "source": source,
                "class": event_class,
                "year": year,
                "within_anchor": counts["PASS"],
                "total": total,
                "share_within_5_minutes": round(counts["PASS"] / total, 6) if total else None,
            }
        )
    return detail, summary


def diagnose_primary_columns(rows: Iterable[CalendarRow]) -> tuple[list[dict[str, object]], dict[str, object]]:
    mismatches: list[dict[str, object]] = []
    field_counts: Counter[str] = Counter()
    total = 0
    for row in rows:
        total += 1
        expected = {
            "day_of_week": row.instant.weekday(),
            "hour": row.instant.hour,
            "day": row.instant.day,
            "is_first_friday": int(row.instant.weekday() == 4 and row.instant.day <= 7),
        }
        for field, value in expected.items():
            raw_value = row.raw.get(field, "")
            try:
                actual = int(raw_value)
            except (TypeError, ValueError):
                actual = None
            if actual != value:
                field_counts[field] += 1
                mismatches.append(
                    {
                        "stored_utc": row.instant.isoformat(),
                        "currency": row.currency,
                        "event": row.event,
                        "field": field,
                        "stored": raw_value,
                        "expected": value,
                    }
                )
    return mismatches, {
        "rows_checked": total,
        "mismatch_count": len(mismatches),
        "mismatches_by_field": dict(sorted(field_counts.items())),
    }


def _nearest(
    instant: datetime, candidates: Sequence[CalendarRow], max_delta: timedelta = timedelta(days=1)
) -> CalendarRow | None:
    eligible = [row for row in candidates if abs(row.instant - instant) <= max_delta]
    return min(eligible, key=lambda row: abs(row.instant - instant)) if eligible else None


def compare_cross_file(
    primary: Iterable[CalendarRow], secondary: Iterable[CalendarRow]
) -> tuple[list[dict[str, object]], dict[str, object]]:
    secondary_index: dict[tuple[str, str], list[CalendarRow]] = defaultdict(list)
    for row in secondary:
        secondary_index[(row.currency, row.event)].append(row)
    detail: list[dict[str, object]] = []
    unmatched = 0
    histogram: Counter[str] = Counter()
    for row in primary:
        match = _nearest(row.instant, secondary_index.get((row.currency, row.event), ()))
        if match is None:
            unmatched += 1
            continue
        delta = int(round((row.instant - match.instant).total_seconds() / 60.0))
        histogram[str(delta)] += 1
        detail.append(
            {
                "currency": row.currency,
                "event": row.event,
                "primary_utc": row.instant.isoformat(),
                "secondary_utc": match.instant.isoformat(),
                "delta_minutes_primary_minus_secondary": delta,
                "identical_instant": delta == 0,
            }
        )
    return detail, {
        "matched": len(detail),
        "unmatched_primary_rows": unmatched,
        "identical_instant": histogram["0"],
        "delta_histogram_minutes": dict(
            sorted(histogram.items(), key=lambda item: int(item[0]))
        ),
    }


def _load_native(native_dir: Path, currency: str) -> tuple[Path, list[CalendarRow]]:
    path = native_dir / f"T_EXPORT_{currency}_HIGH_2018_2025_NATIVE.csv"
    rows: list[CalendarRow] = []
    with path.open(encoding="utf-8-sig", errors="replace", newline="") as handle:
        for raw in csv.DictReader(handle):
            instant = datetime.fromtimestamp(int(raw["broker_time"]), tz=timezone.utc)
            rows.append(
                CalendarRow(
                    source=f"native_{currency}",
                    instant=instant,
                    currency=currency,
                    impact=raw.get("importance", "").strip().lower(),
                    event=raw.get("event_name", "").strip(),
                    raw=raw,
                )
            )
    return path, rows


def compare_native(
    secondary: Iterable[CalendarRow], native_dir: Path
) -> tuple[list[dict[str, object]], dict[str, object], list[dict[str, object]]]:
    native_index: dict[tuple[str, str], list[CalendarRow]] = defaultdict(list)
    native_files: list[dict[str, object]] = []
    for currency in CURRENCIES:
        path, rows = _load_native(native_dir, currency)
        native_files.append(
            {"currency": currency, "path": str(path), "sha256": _sha256(path), "rows": len(rows)}
        )
        for row in rows:
            native_index[(currency, row.event)].append(row)

    detail: list[dict[str, object]] = []
    unmatched: Counter[str] = Counter()
    by_currency: dict[str, Counter[str]] = defaultdict(Counter)
    by_event: dict[str, Counter[str]] = defaultdict(Counter)
    for row in secondary:
        if row.currency not in CURRENCIES or row.impact != "high":
            continue
        native_name = NATIVE_NAME_MAP.get(row.currency, {}).get(row.event)
        if native_name is None or not (2018 <= row.instant.year <= 2025):
            continue
        match = _nearest(row.instant, native_index.get((row.currency, native_name), ()))
        if match is None:
            unmatched[f"{row.currency}:{row.event}"] += 1
            continue
        delta = int(round((row.instant - match.instant).total_seconds() / 60.0))
        bucket = "exact" if delta == 0 else "within_5m" if abs(delta) <= 5 else "other"
        by_currency[row.currency][bucket] += 1
        by_event[f"{row.currency}:{row.event}"][bucket] += 1
        detail.append(
            {
                "currency": row.currency,
                "event": row.event,
                "native_event": native_name,
                "stored_utc": row.instant.isoformat(),
                "native_utc": match.instant.isoformat(),
                "native_epoch_true_utc": match.raw.get("broker_time", ""),
                "delta_minutes_stored_minus_native": delta,
                "bucket": bucket,
            }
        )
    summary = {
        "matched": len(detail),
        "unmatched_mapped_rows": sum(unmatched.values()),
        "unmatched_by_event": dict(sorted(unmatched.items())),
        "per_currency": {key: dict(value) for key, value in sorted(by_currency.items())},
        "per_event": {key: dict(value) for key, value in sorted(by_event.items())},
        "delta_histogram_minutes": dict(
            sorted(
                Counter(str(row["delta_minutes_stored_minus_native"]) for row in detail).items(),
                key=lambda item: int(item[0]),
            )
        ),
    }
    return detail, summary, native_files


def _month_range(start: str, end: str) -> list[str]:
    cursor = datetime.strptime(start, "%Y-%m").date().replace(day=1)
    stop = datetime.strptime(end, "%Y-%m").date().replace(day=1)
    months: list[str] = []
    while cursor <= stop:
        months.append(cursor.strftime("%Y-%m"))
        cursor = date(cursor.year + (cursor.month == 12), 1 if cursor.month == 12 else cursor.month + 1, 1)
    return months


def diagnose_coverage(
    sources: dict[str, Sequence[CalendarRow]], start: str | None = None, end: str | None = None
) -> tuple[list[dict[str, object]], dict[str, list[str]]]:
    all_rows = [row for rows in sources.values() for row in rows]
    if not all_rows:
        return [], {source: [] for source in sources}
    start = start or min(row.instant for row in all_rows).strftime("%Y-%m")
    end = end or max(row.instant for row in all_rows).strftime("%Y-%m")
    months = _month_range(start, end)
    detail: list[dict[str, object]] = []
    zero_months: dict[str, list[str]] = {}
    for source, rows in sources.items():
        counts = Counter(row.instant.strftime("%Y-%m") for row in rows)
        zero_months[source] = [month for month in months if counts[month] == 0]
        for month in months:
            detail.append(
                {"source": source, "month": month, "rows": counts[month], "zero_month": counts[month] == 0}
            )
    return detail, zero_months


def _write_csv(path: Path, rows: Sequence[dict[str, object]], fields: Sequence[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def _markdown(summary: dict[str, object]) -> str:
    anchors = summary["anchors"]
    primary = summary["primary_derived_columns"]
    cross = summary["cross_file"]
    native = summary["native_comparison"]
    coverage = summary["coverage"]
    lines = [
        "# News-calendar semantic timestamp diagnostic",
        "",
        f"Generated UTC: {summary['generated_at_utc']}",
        f"Report directory: `{summary['report_dir']}`",
        "",
        "This is a report-only diagnostic. It does not participate in or change the news-calendar gate verdict.",
        "",
        "## Headline",
        "",
        f"- Anchor checks: {anchors['passed']} PASS / {anchors['failed']} FAIL across {anchors['total']} rows.",
        f"- Primary derived-column mismatches: {primary['mismatch_count']} across {primary['rows_checked']} rows.",
        f"- Cross-file identical instants: {cross['identical_instant']} / {cross['matched']} matched rows.",
        f"- Native matches: {native['matched']}; per-currency buckets: `{json.dumps(native['per_currency'], sort_keys=True)}`.",
        f"- Zero months: `{json.dumps(coverage['zero_months'], sort_keys=True)}`.",
        "",
        "## Scheduled-anchor assertions",
        "",
        "Expected UTC is computed from `qm.dst_rule.us.v1`: US DST starts at 07:00Z on the second Sunday of March and ends at 06:00Z on the first Sunday of November. NFP must also occur on the first Friday. All shares use a ±5 minute tolerance.",
        "",
        "| source | class | year | within ±5m | total | share |",
        "|---|---|---:|---:|---:|---:|",
    ]
    for row in anchors["per_class_year"]:
        lines.append(
            f"| {row['source']} | {row['class']} | {row['year']} | {row['within_anchor']} | {row['total']} | {row['share_within_5_minutes']:.3f} |"
        )
    lines += [
        "",
        "## Internal consistency",
        "",
        f"The primary file was checked against its own datetime for `day_of_week`, `hour`, `day`, and `is_first_friday`: `{json.dumps(primary['mismatches_by_field'], sort_keys=True)}`.",
        "",
        "## Cross-file and native comparison",
        "",
        f"Primary-vs-secondary delta histogram in minutes: `{json.dumps(cross['delta_histogram_minutes'], sort_keys=True)}`.",
        f"Secondary-vs-native delta histogram in minutes: `{json.dumps(native['delta_histogram_minutes'], sort_keys=True)}`.",
        "The native export column named `broker_time` is treated as true UTC epoch; NFP 2023-02-03 (`1675431000`) resolves to 13:30Z.",
        "",
        "## Coverage",
        "",
        f"Monthly table range: {coverage['start']} through {coverage['end']}. Zero-row months are flagged in `monthly_coverage.csv`.",
        "",
        "## Detector chronology",
        "",
        "- The seed was copied on 2026-04-21. An anchor assertion or native-event comparison run that day would have rejected the displaced 08:30 ET classes immediately.",
        "- The private lab recorded displaced NFP/CPI rows on 2026-07-11. The anchor and native delta reports would have made that observation durable and visible to the factory without altering the gate.",
        "- The monthly coverage detector would have flagged the 2025-05 through 2026-06 hole on the first diagnostic run after the copy.",
        "",
        "## Artifacts",
        "",
        "- `summary.json`: machine-readable aggregate and input hashes.",
        "- `anchor_detail.csv` / `anchor_summary.csv`: row-level and class/year anchor checks.",
        "- `primary_derived_mismatches.csv`: derived-column discrepancies.",
        "- `cross_file_comparison.csv`: same currency/event nearest-date comparison.",
        "- `native_comparison.csv`: maintained FF-to-native name-map comparison for USD/EUR/GBP/JPY.",
        "- `monthly_coverage.csv`: monthly row counts and zero-month flags.",
        "",
        "No calendar bytes, gate results, verdict rows, T_Live files, terminals, or scheduled tasks were changed.",
        "",
    ]
    return "\n".join(lines)


def run_diagnostics(
    primary_path: Path,
    secondary_path: Path,
    native_dir: Path,
    out_dir: Path,
    *,
    coverage_start: str | None = None,
    coverage_end: str | None = None,
) -> dict[str, object]:
    out_dir.mkdir(parents=True, exist_ok=True)
    primary, primary_parse_errors = _parse_primary(primary_path)
    secondary, secondary_parse_errors = _parse_secondary(secondary_path)
    anchor_detail, anchor_summary = diagnose_anchors([*primary, *secondary])
    derived_detail, derived_summary = diagnose_primary_columns(primary)
    cross_detail, cross_summary = compare_cross_file(primary, secondary)
    native_detail, native_summary, native_files = compare_native(secondary, native_dir)
    coverage_detail, zero_months = diagnose_coverage(
        {"primary": primary, "secondary": secondary}, coverage_start, coverage_end
    )
    coverage_start_actual = coverage_detail[0]["month"] if coverage_detail else coverage_start
    coverage_end_actual = coverage_detail[-1]["month"] if coverage_detail else coverage_end
    summary: dict[str, object] = {
        "schema_version": SCHEMA,
        "dst_rule_version": DST_RULE,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "report_dir": str(out_dir),
        "report_only": True,
        "inputs": {
            "primary": {"path": str(primary_path), "sha256": _sha256(primary_path), "rows": len(primary)},
            "secondary": {"path": str(secondary_path), "sha256": _sha256(secondary_path), "rows": len(secondary)},
            "native": native_files,
        },
        "parse_errors": {"primary": primary_parse_errors, "secondary": secondary_parse_errors},
        "anchors": {
            "total": len(anchor_detail),
            "passed": sum(row["status"] == "PASS" for row in anchor_detail),
            "failed": sum(row["status"] == "FAIL" for row in anchor_detail),
            "per_class_year": anchor_summary,
        },
        "primary_derived_columns": derived_summary,
        "cross_file": cross_summary,
        "native_comparison": native_summary,
        "coverage": {
            "start": coverage_start_actual,
            "end": coverage_end_actual,
            "zero_months": zero_months,
        },
    }
    _write_csv(
        out_dir / "anchor_detail.csv",
        anchor_detail,
        ("source", "currency", "event", "class", "year", "stored_utc", "expected_utc", "delta_minutes", "within_5_minutes", "schedule_rule_ok", "status"),
    )
    _write_csv(
        out_dir / "anchor_summary.csv",
        anchor_summary,
        ("source", "class", "year", "within_anchor", "total", "share_within_5_minutes"),
    )
    _write_csv(
        out_dir / "primary_derived_mismatches.csv",
        derived_detail,
        ("stored_utc", "currency", "event", "field", "stored", "expected"),
    )
    _write_csv(
        out_dir / "cross_file_comparison.csv",
        cross_detail,
        ("currency", "event", "primary_utc", "secondary_utc", "delta_minutes_primary_minus_secondary", "identical_instant"),
    )
    _write_csv(
        out_dir / "native_comparison.csv",
        native_detail,
        ("currency", "event", "native_event", "stored_utc", "native_utc", "native_epoch_true_utc", "delta_minutes_stored_minus_native", "bucket"),
    )
    _write_csv(out_dir / "monthly_coverage.csv", coverage_detail, ("source", "month", "rows", "zero_month"))
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out_dir / "report.md").write_text(_markdown(summary), encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--primary", type=Path, default=DEFAULT_CALENDAR_DIR / "news_calendar_2015_2025.csv")
    parser.add_argument("--secondary", type=Path, default=DEFAULT_CALENDAR_DIR / "forex_factory_calendar_clean.csv")
    parser.add_argument("--native-dir", type=Path, default=DEFAULT_NATIVE_DIR)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--evidence-copy", type=Path, default=DEFAULT_EVIDENCE_COPY)
    parser.add_argument("--no-evidence-copy", action="store_true")
    parser.add_argument("--coverage-start")
    parser.add_argument("--coverage-end")
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = args.out or DEFAULT_REPORT_ROOT / f"diagnose_{stamp}"
    summary = run_diagnostics(
        args.primary,
        args.secondary,
        args.native_dir,
        out_dir,
        coverage_start=args.coverage_start,
        coverage_end=args.coverage_end,
    )
    if not args.no_evidence_copy:
        args.evidence_copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(out_dir / "report.md", args.evidence_copy)
    print(json.dumps({"status": "ok", "report_dir": str(out_dir), "summary": summary}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
