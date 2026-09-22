#!/usr/bin/env python3
"""Reproduce the task-scoped U.S. news-calendar one-hour DST audit.

This program is deliberately read-only outside its own evidence directory.  It
audits the immutable Q09 calendar, creates a correction *proposal* under this
task directory, and inventories hash-bound work items without changing either
the source archive or farm state.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sqlite3
import sys
from collections import Counter
from datetime import date, datetime, time, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping
from zoneinfo import ZoneInfo


TASK_ID = "a36a5983-8cfc-4528-8277-8b5d21787f82"
OUT = Path(__file__).resolve().parent
REPO = Path(r"C:/QM/repo")
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_calendar as q09  # noqa: E402


SEALED_DIR = Path(
    r"D:/QM/data/news_calendar/q09_bundles/"
    r"q09cal-20150101-20260809-0bb19b5bb9790b76"
)
SEALED_EVENTS = SEALED_DIR / "events.csv"
SEALED_MANIFEST = SEALED_DIR / "manifest.json"
PRIMARY = Path(r"D:/QM/data/news_calendar/news_calendar_2015_2025.csv")
SECONDARY = Path(r"D:/QM/data/news_calendar/forex_factory_calendar_clean.csv")
PAIR_MANIFEST = Path(r"D:/QM/data/news_calendar/news_calendar_bundle_manifest.json")
NATIVE_EXPORT = Path(
    r"D:/QM/mt5/T_Export/MQL5/Files/T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv"
)
NATIVE_JOIN = OUT / "native_control" / "native_join_deltas.csv"
DB_URI = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
OVERRIDES_CONFIG = (
    REPO
    / "tools"
    / "strategy_farm"
    / "config"
    / "news_calendar_scoped_consumer_b.v1.json"
)
NEW_YORK = ZoneInfo("America/New_York")
UTC = timezone.utc
YEAR_FROM = 2015
YEAR_TO = 2025
USD_INDEX_SYMBOLS = {"NDX", "SP500", "SPX500", "WS30", "US30", "US500", "USTEC"}


# Fixed release clocks in America/New_York.  The authority key points to the
# official schedules recorded below.  These are schedule classes, not guesses
# from the stored UTC values under test.
FIXED_CLOCKS: dict[str, tuple[int, int, str]] = {
    "Advance GDP Price Index q/q": (8, 30, "BEA"),
    "Advance GDP q/q": (8, 30, "BEA"),
    "Average Hourly Earnings m/m": (8, 30, "BLS"),
    "Building Permits": (8, 30, "CENSUS"),
    "CPI m/m": (8, 30, "BLS"),
    "CPI y/y": (8, 30, "BLS"),
    "Core CPI m/m": (8, 30, "BLS"),
    "Core Durable Goods Orders m/m": (8, 30, "CENSUS"),
    "Core PCE Price Index m/m": (8, 30, "BEA"),
    "Core PPI m/m": (8, 30, "BLS"),
    "Core Retail Sales m/m": (8, 30, "CENSUS"),
    "Employment Cost Index q/q": (8, 30, "BLS"),
    "Empire State Manufacturing Index": (8, 30, "NYFED"),
    "Final GDP Price Index q/q": (8, 30, "BEA"),
    "Final GDP q/q": (8, 30, "BEA"),
    "Goods Trade Balance": (8, 30, "CENSUS"),
    "Non-Farm Employment Change": (8, 30, "BLS"),
    "Personal Spending m/m": (8, 30, "BEA"),
    "Philly Fed Manufacturing Index": (8, 30, "PHILFED"),
    "PPI m/m": (8, 30, "BLS"),
    "Prelim GDP Price Index q/q": (8, 30, "BEA"),
    "Prelim GDP q/q": (8, 30, "BEA"),
    "Prelim Unit Labor Costs q/q": (8, 30, "BLS"),
    "Retail Sales m/m": (8, 30, "CENSUS"),
    "Trade Balance": (8, 30, "CENSUS"),
    "Unemployment Claims": (8, 30, "DOL"),
    "Unemployment Rate": (8, 30, "BLS"),
    "CB Consumer Confidence": (10, 0, "CONFERENCE_BOARD"),
    "Existing Home Sales": (10, 0, "NAR"),
    "ISM Manufacturing PMI": (10, 0, "ISM"),
    "ISM Services PMI": (10, 0, "ISM"),
    "JOLTS Job Openings": (10, 0, "BLS"),
    "New Home Sales": (10, 0, "CENSUS"),
    "Pending Home Sales m/m": (10, 0, "NAR"),
    "Prelim UoM Consumer Sentiment": (10, 0, "UMICH"),
    "Revised UoM Consumer Sentiment": (10, 0, "UMICH"),
}

OFFICIAL_SOURCES: dict[str, dict[str, str]] = {
    "BLS": {
        "description": "BLS release calendars (Eastern Time)",
        "url": "https://www.bls.gov/schedule/2026/",
    },
    "BEA": {
        "description": "BEA news release schedule",
        "url": "https://www.bea.gov/news/schedule",
    },
    "CENSUS": {
        "description": "U.S. Census economic indicators calendar",
        "url": "https://www.census.gov/economic-indicators/calendar-listview.html",
    },
    "DOL": {
        "description": "Department of Labor economic data releases",
        "url": "https://www.dol.gov/newsroom/economicdata",
    },
    "ISM": {
        "description": "ISM PMI report release schedule",
        "url": "https://www.ismworld.org/supply-management-news-and-reports/reports/ism-pmi-reports/",
    },
    "NAR": {
        "description": "NAR statistical news release schedule",
        "url": "https://www.nar.realtor/press-releases/nar-releases-2026-statistical-news-release-schedule",
    },
    "UMICH": {
        "description": "University of Michigan Surveys of Consumers",
        "url": "https://www.sca.isr.umich.edu/",
    },
    "CONFERENCE_BOARD": {
        "description": "Conference Board Consumer Confidence releases",
        "url": "https://www.conference-board.org/topics/consumer-confidence/press",
    },
    "NYFED": {
        "description": "Federal Reserve Bank of New York Empire State survey",
        "url": "https://www.newyorkfed.org/survey/empire/empiresurvey_overview",
    },
    "PHILFED": {
        "description": "Federal Reserve Bank of Philadelphia Manufacturing survey",
        "url": "https://www.philadelphiafed.org/surveys-and-data/regional-economic-analysis/mbos-2026",
    },
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode(
            "utf-8"
        )
    )


def normalize_lf(path: Path) -> None:
    """Canonicalize generated task evidence without touching source inputs."""

    raw = path.read_bytes()
    normalized = raw.replace(b"\r\n", b"\n")
    if normalized != raw:
        path.write_bytes(normalized)


def write_csv(path: Path, fieldnames: list[str], rows: Iterable[Mapping[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=fieldnames,
            extrasaction="raise",
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})


def parse_utc(value: str) -> datetime:
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    parsed: datetime | None = None
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y.%m.%d %H:%M:%S"):
            try:
                parsed = datetime.strptime(text, fmt)
                break
            except ValueError:
                continue
    if parsed is None:
        raise ValueError(f"unsupported timestamp: {value!r}")
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def utc_text(value: datetime) -> str:
    return value.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_day(value: str) -> date:
    return date.fromisoformat(value.strip()[:10].replace(".", "-"))


def expected_instant(day: date, hour: int, minute: int) -> tuple[datetime, datetime]:
    local = datetime.combine(day, time(hour, minute), tzinfo=NEW_YORK)
    return local, local.astimezone(UTC)


def load_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise RuntimeError(f"missing CSV header: {path}")
        fieldnames = [field.strip() for field in reader.fieldnames]
        rows = [
            {(key or "").strip(): (value or "").strip() for key, value in row.items()}
            for row in reader
        ]
    return fieldnames, rows


def native_confirmations() -> dict[tuple[str, str], str]:
    result: dict[tuple[str, str], str] = {}
    if not NATIVE_JOIN.is_file():
        return result
    _, rows = load_csv(NATIVE_JOIN)
    for row in rows:
        try:
            delta = float(row["delta_hours"])
            stored = utc_text(parse_utc(row["stored_utc"]))
            native = utc_text(parse_utc(row["native_utc"]))
        except (KeyError, ValueError):
            continue
        if abs(delta + 1.0) <= 0.001:
            result[(row["event"], stored)] = native
    return result


def audit_calendar(
    path: Path,
    *,
    datetime_field: str,
    currency_field: str,
    impact_field: str,
    event_field: str,
    source_label: str,
    native: Mapping[tuple[str, str], str] | None = None,
) -> dict[str, Any]:
    fieldnames, rows = load_csv(path)
    required = {datetime_field, currency_field, impact_field, event_field}
    if not required.issubset(fieldnames):
        raise RuntimeError(f"{source_label} is missing required fields: {sorted(required - set(fieldnames))}")

    audited: list[dict[str, Any]] = []
    affected: list[dict[str, Any]] = []
    delta_counts: Counter[int] = Counter()
    source_hash = sha256_file(path)
    for row_number, row in enumerate(rows, start=2):
        event = row[event_field]
        if row[currency_field].upper() != "USD" or row[impact_field].upper() != "HIGH":
            continue
        if event not in FIXED_CLOCKS:
            continue
        stored = parse_utc(row[datetime_field])
        if not (YEAR_FROM <= stored.year <= YEAR_TO):
            continue
        hour, minute, authority = FIXED_CLOCKS[event]
        local, expected = expected_instant(stored.date(), hour, minute)
        delta_minutes_float = (stored - expected).total_seconds() / 60.0
        if not delta_minutes_float.is_integer():
            raise RuntimeError(
                f"non-integral minute delta at {source_label} row {row_number}: {delta_minutes_float}"
            )
        delta_minutes = int(delta_minutes_float)
        delta_counts[delta_minutes] += 1
        record: dict[str, Any] = {
            "source": source_label,
            "source_content_sha256": source_hash,
            "source_row_number": row_number,
            "row_identity_sha256": sha256_text(canonical_json(row)),
            "currency": "USD",
            "impact": "HIGH",
            "event_name": event,
            "authority": authority,
            "expected_release_et": f"{hour:02d}:{minute:02d}",
            "expected_local_iso": local.isoformat(timespec="seconds"),
            "stored_utc": utc_text(stored),
            "expected_utc": utc_text(expected),
            "delta_minutes": delta_minutes,
            "stored_hour": row.get("hour", str(stored.hour)),
            "expected_hour": str(expected.hour),
        }
        audited.append(record)
        if delta_minutes == -60:
            native_utc = (native or {}).get((event, utc_text(stored)))
            record["native_confirmation"] = "EXACT_MINUS_60_MIN" if native_utc == utc_text(expected) else "NO_MAPPED_NATIVE_JOIN"
            record["native_utc"] = native_utc or ""
            affected.append(record)

    return {
        "source": source_label,
        "source_path": path.as_posix(),
        "source_sha256": source_hash,
        "source_row_count": len(rows),
        "audited_rows": audited,
        "affected_rows": affected,
        "audited_count": len(audited),
        "affected_count": len(affected),
        "delta_counts": dict(sorted(delta_counts.items())),
    }


def affected_keyset(audit: Mapping[str, Any]) -> set[tuple[str, str]]:
    return {
        (str(row["event_name"]), str(row["expected_utc"]))
        for row in audit["affected_rows"]
    }


def build_candidate(
    sealed_audit: Mapping[str, Any], parent: Mapping[str, Any]
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    fieldnames, rows = load_csv(SEALED_EVENTS)
    corrections = {
        int(record["source_row_number"]): record
        for record in sealed_audit["affected_rows"]
    }
    diffs: list[dict[str, Any]] = []
    for row_number, row in enumerate(rows, start=2):
        record = corrections.get(row_number)
        if record is None:
            continue
        old_datetime = row["datetime"]
        old_hour = row["hour"]
        row["datetime"] = str(record["expected_utc"])
        row["hour"] = str(record["expected_hour"])
        change_id = sha256_text(
            f"{sealed_audit['source_sha256']}:{row_number}:{old_datetime}:{row['datetime']}"
        )
        diffs.append(
            {
                "change_id": change_id,
                "parent_content_sha256": sealed_audit["source_sha256"],
                "source_row_number": row_number,
                "source_row_identity_sha256": record["row_identity_sha256"],
                "currency": row["currency"],
                "impact": row["impact"],
                "event_name": row["event_name"],
                "old_datetime_utc": old_datetime,
                "new_datetime_utc": row["datetime"],
                "old_hour": old_hour,
                "new_hour": row["hour"],
                "delta_minutes": 60,
                "changed_fields": "datetime;hour",
                "basis": "official fixed ET release clock converted with America/New_York",
            }
        )

    if len(diffs) != int(sealed_audit["affected_count"]):
        raise RuntimeError("candidate correction count does not match affected row count")

    candidate_dir = OUT / "proposed_archive"
    candidate_dir.mkdir(parents=True, exist_ok=True)
    temporary = candidate_dir / "_uncanonicalized.csv"
    write_csv(temporary, fieldnames, rows)
    canonical_bytes, metadata = q09.canonicalize_events(temporary)
    temporary.unlink()
    candidate = candidate_dir / "events.csv"
    candidate.write_bytes(canonical_bytes)

    if metadata["row_count"] != int(parent["row_count"]):
        raise RuntimeError("candidate canonicalization changed the row count")
    roundtrip_bytes, roundtrip_meta = q09.canonicalize_events(candidate)
    if roundtrip_bytes != candidate.read_bytes() or roundtrip_meta != metadata:
        raise RuntimeError("candidate is not stable under Q09 canonicalization")

    return (
        {
            "path": candidate.as_posix(),
            "relative_path": "proposed_archive/events.csv",
            "sha256": sha256_file(candidate),
            "size_bytes": candidate.stat().st_size,
            **metadata,
        },
        diffs,
    )


def load_overrides() -> tuple[dict[str, list[str]], str]:
    raw = OVERRIDES_CONFIG.read_bytes()
    doc = json.loads(raw.decode("utf-8-sig"))
    values = doc.get("admissibility", {}).get("symbol_currency_overrides", {})
    overrides = {
        str(symbol).upper(): [str(currency).upper() for currency in currencies]
        for symbol, currencies in values.items()
        if isinstance(currencies, list)
    }
    return overrides, hashlib.sha256(raw).hexdigest()


def payload_symbols(item: Mapping[str, Any], payload: Mapping[str, Any]) -> list[str]:
    basket = payload.get("basket_symbols")
    if isinstance(basket, list) and basket:
        return sorted({str(symbol) for symbol in basket})
    host = payload.get("host_symbol") or item.get("symbol")
    return [str(host)] if host else []


def symbol_currencies(
    symbols: list[str], overrides: Mapping[str, list[str]]
) -> tuple[list[str], list[str]]:
    currencies: set[str] = set()
    sources: list[str] = []
    for raw in symbols:
        normalized = re.sub(r"[^A-Z0-9]", "", raw.upper().replace(".DWX", ""))
        dotted = raw.upper() if "." in raw else f"{raw.upper()}.DWX"
        if dotted in overrides:
            currencies.update(overrides[dotted])
            sources.append(f"{dotted}:owner_override")
            continue
        if normalized in USD_INDEX_SYMBOLS:
            currencies.add("USD")
            sources.append(f"{normalized}:usd_index_alias")
            continue
        if len(normalized) >= 6:
            currencies.update((normalized[:3], normalized[3:6]))
            sources.append(f"{normalized}:legs")
    return sorted(currencies), sources


def inventory_verdicts(
    calendar_hash: str, affected: list[Mapping[str, Any]]
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    overrides, overrides_hash = load_overrides()
    query = """
        SELECT id, phase, ea_id, symbol, status, verdict,
               data_window_start, data_window_end, news_calendar_sha256,
               payload_json, evidence_path
          FROM work_items
         WHERE news_calendar_sha256 = ?
         ORDER BY phase, ea_id, id
    """
    database = sqlite3.connect(DB_URI, uri=True)
    database.row_factory = sqlite3.Row
    try:
        database.execute("BEGIN")
        source_rows = database.execute(query, (calendar_hash,)).fetchall()
    finally:
        database.close()

    result: list[dict[str, Any]] = []
    affected_dates = [parse_utc(str(row["expected_utc"])).date() for row in affected]
    for source in source_rows:
        item = dict(source)
        try:
            payload = json.loads(item.get("payload_json") or "{}")
        except json.JSONDecodeError:
            payload = {}
        symbols = payload_symbols(item, payload)
        currencies, mapping_sources = symbol_currencies(symbols, overrides)
        has_usd = "USD" in currencies
        start = parse_day(item["data_window_start"]) if item.get("data_window_start") else None
        end = parse_day(item["data_window_end"]) if item.get("data_window_end") else None
        overlap = (
            sum(1 for affected_day in affected_dates if start <= affected_day <= end)
            if has_usd and start is not None and end is not None
            else 0
        )
        if overlap:
            impact = "DIRECT_USD_WINDOW_EXPOSURE"
            action = "APPEND_ONLY_REMEASUREMENT_AND_READJUDICATION"
        elif not has_usd:
            impact = "HASH_BOUND_NO_DIRECT_USD_EXPOSURE"
            action = "CONTENT_HASH_REPLACEMENT_REVIEW"
        else:
            impact = "HASH_BOUND_NO_RECORDED_WINDOW_OVERLAP"
            action = "CONTENT_HASH_REPLACEMENT_REVIEW"
        result.append(
            {
                "work_item_id": item["id"],
                "phase": item["phase"],
                "ea_id": item["ea_id"],
                "symbol": item["symbol"],
                "status": item["status"],
                "verdict": item["verdict"] or "",
                "data_window_start": item["data_window_start"] or "",
                "data_window_end": item["data_window_end"] or "",
                "news_calendar_sha256": item["news_calendar_sha256"],
                "exposure_symbols": ";".join(symbols),
                "currencies": ";".join(currencies),
                "currency_mapping_sources": ";".join(mapping_sources),
                "usd_exposed": "YES" if has_usd else "NO",
                "affected_rows_in_recorded_window": overlap,
                "calendar_binding_impact": impact,
                "required_action": action,
                "existing_evidence_path": item["evidence_path"] or "",
            }
        )

    direct = [row for row in result if row["calendar_binding_impact"] == "DIRECT_USD_WINDOW_EXPOSURE"]
    no_direct = [row for row in result if row["calendar_binding_impact"] != "DIRECT_USD_WINDOW_EXPOSURE"]
    summary = {
        "calendar_sha256": calendar_hash,
        "bound_work_items": len(result),
        "distinct_bound_eas": len({row["ea_id"] for row in result}),
        "directly_exposed_work_items": len(direct),
        "directly_exposed_distinct_eas": len({row["ea_id"] for row in direct}),
        "hash_bound_without_direct_exposure": len(no_direct),
        "by_phase_verdict": dict(
            sorted(Counter(f"{row['phase']}|{row['verdict']}" for row in result).items())
        ),
        "direct_by_phase_verdict": dict(
            sorted(Counter(f"{row['phase']}|{row['verdict']}" for row in direct).items())
        ),
        "owner_override_config_path": OVERRIDES_CONFIG.as_posix(),
        "owner_override_config_sha256": overrides_hash,
        "interpretation": (
            "Existing pipeline verdicts remain immutable. Direct rows require new append-only "
            "measurement before any new adjudication; the remaining rows are still content-hash "
            "bound and require replacement review, but have no direct USD/window exposure in this audit."
        ),
    }
    return result, summary


def date_range(rows: list[Mapping[str, Any]]) -> dict[str, str | None]:
    values = sorted(str(row["stored_utc"]) for row in rows)
    return {"first_stored_utc": values[0] if values else None, "last_stored_utc": values[-1] if values else None}


def generate() -> dict[str, Any]:
    OUT.mkdir(parents=True, exist_ok=True)
    for native_artifact in (
        NATIVE_JOIN,
        OUT / "native_control" / "stored_tod_histogram.csv",
        OUT / "native_control" / "summary.json",
    ):
        normalize_lf(native_artifact)
    source_hashes_before = {
        "sealed_events": sha256_file(SEALED_EVENTS),
        "sealed_manifest": sha256_file(SEALED_MANIFEST),
        "primary": sha256_file(PRIMARY),
        "secondary": sha256_file(SECONDARY),
        "pair_manifest": sha256_file(PAIR_MANIFEST),
        "native_export": sha256_file(NATIVE_EXPORT),
    }
    parent = json.loads(SEALED_MANIFEST.read_text(encoding="utf-8"))
    if source_hashes_before["sealed_events"] != parent["content_sha256"]:
        raise RuntimeError("sealed events hash does not match its manifest")

    native = native_confirmations()
    sealed = audit_calendar(
        SEALED_EVENTS,
        datetime_field="datetime",
        currency_field="currency",
        impact_field="impact",
        event_field="event_name",
        source_label="sealed_q09",
        native=native,
    )
    primary = audit_calendar(
        PRIMARY,
        datetime_field="datetime",
        currency_field="currency",
        impact_field="impact",
        event_field="event_name",
        source_label="active_primary",
    )
    secondary = audit_calendar(
        SECONDARY,
        datetime_field="DateTime_UTC",
        currency_field="Currency",
        impact_field="Impact",
        event_field="Event",
        source_label="active_secondary",
    )
    if sealed["affected_count"] != 82:
        raise RuntimeError(f"expected 82 sealed exact -60 minute rows, got {sealed['affected_count']}")

    affected_fields = [
        "source",
        "source_content_sha256",
        "source_row_number",
        "row_identity_sha256",
        "currency",
        "impact",
        "event_name",
        "authority",
        "expected_release_et",
        "expected_local_iso",
        "stored_utc",
        "expected_utc",
        "delta_minutes",
        "native_confirmation",
        "native_utc",
    ]
    affected_path = OUT / "affected_rows.csv"
    write_csv(affected_path, affected_fields, sealed["affected_rows"])

    candidate, diffs = build_candidate(sealed, parent)
    diff_fields = [
        "change_id",
        "parent_content_sha256",
        "source_row_number",
        "source_row_identity_sha256",
        "currency",
        "impact",
        "event_name",
        "old_datetime_utc",
        "new_datetime_utc",
        "old_hour",
        "new_hour",
        "delta_minutes",
        "changed_fields",
        "basis",
    ]
    diff_path = OUT / "proposed_correction_diff.csv"
    write_csv(diff_path, diff_fields, diffs)

    impact_rows, impact_summary = inventory_verdicts(
        str(parent["content_sha256"]), sealed["affected_rows"]
    )
    impact_fields = [
        "work_item_id",
        "phase",
        "ea_id",
        "symbol",
        "status",
        "verdict",
        "data_window_start",
        "data_window_end",
        "news_calendar_sha256",
        "exposure_symbols",
        "currencies",
        "currency_mapping_sources",
        "usd_exposed",
        "affected_rows_in_recorded_window",
        "calendar_binding_impact",
        "required_action",
        "existing_evidence_path",
    ]
    impact_path = OUT / "sealed_verdict_impact.csv"
    write_csv(impact_path, impact_fields, impact_rows)

    yearly = Counter(parse_utc(str(row["stored_utc"])).year for row in sealed["affected_rows"])
    by_event = Counter(str(row["event_name"]) for row in sealed["affected_rows"])
    native_count = sum(
        1
        for row in sealed["affected_rows"]
        if row["native_confirmation"] == "EXACT_MINUS_60_MIN"
    )
    sealed_keys = affected_keyset(sealed)
    primary_keys = affected_keyset(primary)
    secondary_keys = affected_keyset(secondary)

    proposal_path = OUT / "proposed_archive" / "manifest.proposed.json"
    proposal = {
        "schema_version": "qm.q09-news-calendar-correction-proposal/v1",
        "task_id": TASK_ID,
        "status": "PROPOSAL_ONLY_NOT_AUTHORIZED",
        "publishable_now": False,
        "parent": {
            "bundle_id": parent["bundle_id"],
            "content_sha256": parent["content_sha256"],
            "manifest_path": SEALED_MANIFEST.as_posix(),
            "manifest_sha256": source_hashes_before["sealed_manifest"],
            "coverage_from_utc": parent["coverage_from_utc"],
            "coverage_to_utc": parent["coverage_to_utc"],
            "row_count": parent["row_count"],
        },
        "candidate": candidate,
        "correction": {
            "classification": "EXACT_MINUS_ONE_HOUR_DST_NORMALIZATION_SUBSET",
            "row_count": len(diffs),
            "changed_fields": ["datetime", "hour"],
            "unchanged_archive_in_place": True,
            "affected_rows_path": "../affected_rows.csv",
            "affected_rows_sha256": sha256_file(affected_path),
            "diff_path": "../proposed_correction_diff.csv",
            "diff_sha256": sha256_file(diff_path),
            "suggested_correction_reason": (
                "Correct 82 high-impact USD fixed-clock releases stored exactly one hour early "
                "relative to America/New_York in 2021-2025; retain all other event fields."
            ),
        },
        "publication_contract": {
            "required_publication_reason": "APPROVED_CORRECTION",
            "required_parent_bundle_id": parent["bundle_id"],
            "owner_approval_received": False,
            "required_owner_receipt_fields": [
                "approved_by",
                "approved_at",
                "reason",
                "correction_reason",
            ],
            "next_safe_step": (
                "OWNER reviews this proposal and, only if approved, supplies a durable receipt; "
                "then run q09_news_calendar.py plan before publish."
            ),
            "whatif_command_template": (
                "python C:/QM/repo/tools/strategy_farm/q09_news_calendar.py plan "
                "--source-csv <THIS_TASK_DIR>/proposed_archive/events.csv "
                "--receipt <OWNER_APPROVAL_RECEIPT.json> "
                f"--coverage-from-utc {parent['coverage_from_utc']} "
                f"--coverage-to-utc {parent['coverage_to_utc']} "
                "--publication-reason APPROVED_CORRECTION "
                f"--parent-manifest {SEALED_MANIFEST.as_posix()}"
            ),
        },
        "evidence": {
            "audit_program": "../audit.py",
            "audit_program_sha256": sha256_file(Path(__file__)),
            "native_control_path": "../native_control/native_join_deltas.csv",
            "native_control_sha256": sha256_file(NATIVE_JOIN),
        },
    }
    write_json(proposal_path, proposal)

    source_hashes_after = {
        "sealed_events": sha256_file(SEALED_EVENTS),
        "sealed_manifest": sha256_file(SEALED_MANIFEST),
        "primary": sha256_file(PRIMARY),
        "secondary": sha256_file(SECONDARY),
        "pair_manifest": sha256_file(PAIR_MANIFEST),
        "native_export": sha256_file(NATIVE_EXPORT),
    }
    if source_hashes_before != source_hashes_after:
        raise RuntimeError("a read-only input changed while the audit was running")

    summary = {
        "schema_version": "qm.news-calendar-dst-audit/v1",
        "task_id": TASK_ID,
        "verdict": "FAIL_EXACT_MINUS_ONE_HOUR_ROWS_CONFIRMED",
        "scope": {
            "currency": "USD",
            "impact": "HIGH",
            "years": [YEAR_FROM, YEAR_TO],
            "fixed_release_clocks_et": ["08:30", "10:00"],
            "timezone_rule": "America/New_York (IANA zoneinfo)",
            "event_classes": len(FIXED_CLOCKS),
        },
        "sealed_calendar": {
            "bundle_id": parent["bundle_id"],
            "content_sha256": parent["content_sha256"],
            "row_count": parent["row_count"],
            "audited_fixed_clock_rows": sealed["audited_count"],
            "exact_minus_60_minute_rows": sealed["affected_count"],
            "affected_stored_range": date_range(sealed["affected_rows"]),
            "affected_by_year": {str(year): count for year, count in sorted(yearly.items())},
            "affected_by_event": dict(sorted(by_event.items())),
            "native_export_exact_confirmations": native_count,
            "native_export_unmapped_rows": sealed["affected_count"] - native_count,
        },
        "active_pair_sensitivity": {
            "primary": {
                "path": PRIMARY.as_posix(),
                "sha256": primary["source_sha256"],
                "audited_fixed_clock_rows": primary["audited_count"],
                "exact_minus_60_minute_rows": primary["affected_count"],
                "symmetric_difference_from_sealed": len(primary_keys ^ sealed_keys),
            },
            "secondary": {
                "path": SECONDARY.as_posix(),
                "sha256": secondary["source_sha256"],
                "audited_fixed_clock_rows": secondary["audited_count"],
                "exact_minus_60_minute_rows": secondary["affected_count"],
                "intersection_with_sealed": len(secondary_keys & sealed_keys),
                "symmetric_difference_from_sealed": len(secondary_keys ^ sealed_keys),
                "note": "Difference includes source impact-taxonomy/row-selection differences; the Q-gate correction set is the sealed 82-row set.",
            },
        },
        "pattern_classification": {
            "classification": "SEASONAL_BATCH_SUBSET_NOT_GLOBAL_TIMEZONE_RULE",
            "facts": [
                "The 82 target rows are exactly -60 minutes, not a distribution around -60.",
                "The concentration is 2023-2024 between late March and September, with one March row in each of 2021, 2022, and 2025.",
                "Unrelated 08:30 and 10:00 ET event families shift together while adjacent rows can remain correct.",
                "The identical sealed and active-primary affected key sets exclude a one-off consumer display error.",
            ],
            "root_cause_inference": (
                "A mixed-source or batch-level DST normalization path applied an extra daylight "
                "offset to a subset of rows. The evidence does not identify a single upstream code line."
            ),
            "separate_known_defect": (
                "This exact -60-minute class is separate from the previously documented -16/-17-hour "
                "population; this proposal does not repair or waive that larger defect."
            ),
        },
        "sealed_verdict_impact": impact_summary,
        "proposal": {
            "manifest_path": proposal_path.as_posix(),
            "manifest_sha256": sha256_file(proposal_path),
            "candidate_path": candidate["path"],
            "candidate_sha256": candidate["sha256"],
            "candidate_row_count": candidate["row_count"],
            "correction_rows": len(diffs),
            "authorized": False,
        },
        "official_schedule_sources": OFFICIAL_SOURCES,
        "source_integrity": {
            "read_only_inputs_unchanged": True,
            "hashes_before": source_hashes_before,
            "hashes_after": source_hashes_after,
        },
        "artifact_hashes": {
            "audit.py": sha256_file(Path(__file__)),
            "affected_rows.csv": sha256_file(affected_path),
            "proposed_correction_diff.csv": sha256_file(diff_path),
            "sealed_verdict_impact.csv": sha256_file(impact_path),
            "proposed_archive/events.csv": candidate["sha256"],
            "proposed_archive/manifest.proposed.json": sha256_file(proposal_path),
            "native_control/native_join_deltas.csv": sha256_file(NATIVE_JOIN),
            "native_control/stored_tod_histogram.csv": sha256_file(
                OUT / "native_control" / "stored_tod_histogram.csv"
            ),
            "native_control/summary.json": sha256_file(OUT / "native_control" / "summary.json"),
        },
    }
    summary_path = OUT / "summary.json"
    write_json(summary_path, summary)
    return summary


def verify_existing() -> dict[str, Any]:
    summary_path = OUT / "summary.json"
    proposal_path = OUT / "proposed_archive" / "manifest.proposed.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    proposal = json.loads(proposal_path.read_text(encoding="utf-8"))
    failures: list[str] = []

    for relative, expected_hash in summary["artifact_hashes"].items():
        path = OUT / relative
        if not path.is_file():
            failures.append(f"missing {relative}")
        elif sha256_file(path) != expected_hash:
            failures.append(f"hash mismatch {relative}")
    parent_hash = summary["sealed_calendar"]["content_sha256"]
    if sha256_file(SEALED_EVENTS) != parent_hash:
        failures.append("sealed source hash changed")
    candidate = OUT / "proposed_archive" / "events.csv"
    canonical, meta = q09.canonicalize_events(candidate)
    if canonical != candidate.read_bytes():
        failures.append("candidate is not canonical")
    if meta["row_count"] != summary["proposal"]["candidate_row_count"]:
        failures.append("candidate row count mismatch")
    if proposal.get("publishable_now") is not False or proposal.get("status") != "PROPOSAL_ONLY_NOT_AUTHORIZED":
        failures.append("proposal authorization guard missing")
    for relative, expected_rows in (
        ("affected_rows.csv", 82),
        ("proposed_correction_diff.csv", 82),
        ("sealed_verdict_impact.csv", summary["sealed_verdict_impact"]["bound_work_items"]),
    ):
        _, rows = load_csv(OUT / relative)
        if len(rows) != expected_rows:
            failures.append(f"row count mismatch {relative}: {len(rows)} != {expected_rows}")

    result = {
        "status": "PASS" if not failures else "FAIL",
        "task_id": TASK_ID,
        "failures": failures,
        "sealed_source_sha256": sha256_file(SEALED_EVENTS),
        "candidate_sha256": sha256_file(candidate),
        "candidate_rows": meta["row_count"],
        "corrected_rows": summary["proposal"]["correction_rows"],
        "bound_work_items": summary["sealed_verdict_impact"]["bound_work_items"],
        "directly_exposed_work_items": summary["sealed_verdict_impact"]["directly_exposed_work_items"],
    }
    if failures:
        raise RuntimeError(json.dumps(result, indent=2))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    result = verify_existing() if args.verify_only else generate()
    if args.verify_only:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(
            json.dumps(
                {
                    "status": "GENERATED",
                    "task_id": TASK_ID,
                    "verdict": result["verdict"],
                    "affected_rows": result["sealed_calendar"]["exact_minus_60_minute_rows"],
                    "candidate_sha256": result["proposal"]["candidate_sha256"],
                    "bound_work_items": result["sealed_verdict_impact"]["bound_work_items"],
                    "directly_exposed_work_items": result["sealed_verdict_impact"]["directly_exposed_work_items"],
                },
                indent=2,
                sort_keys=True,
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
