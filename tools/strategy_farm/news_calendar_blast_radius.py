"""Read-only blast-radius census for the 2026-09-05 calendar timestamp defect.

The classifier inventories completed Q09/Q10/Q14 evidence.  It never changes a
calendar, gate, work item, verdict, terminal, or scheduled task.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Sequence


REPO = Path(r"C:/QM/repo")
DB_URI = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
DEFAULT_OUT = REPO / "docs/ops/evidence/2026-09-05_news_defect_blast_radius"
PHASES = ("Q09", "Q10", "Q14")
USD_INDEX_SYMBOLS = {"NDX", "SP500", "SPX500", "WS30", "US30", "US500", "USTEC"}
TIMEFRAMES = ("M1", "M2", "M3", "M4", "M5", "M6", "M10", "M12", "M15", "M20", "M30", "H1", "H2", "H3", "H4", "H6", "H8", "H12", "D1", "W1", "MN1")
MODE_KEYS = ("qm_news_temporal", "qm_news_mode", "qm_news_mode_legacy")
INPUT_RE = re.compile(
    r"^\s*input\s+(?:const\s+)?[A-Za-z_][\w<>]*\s+([A-Za-z_]\w*)\s*=\s*([^;]+);",
    re.MULTILINE,
)


def sha256(path: Path | None) -> str | None:
    if path is None or not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalize_symbol(symbol: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", symbol.upper().replace(".DWX", ""))


def symbol_has_usd_exposure(symbol: str) -> bool:
    normalized = normalize_symbol(symbol)
    if normalized in USD_INDEX_SYMBOLS:
        return True
    if len(normalized) >= 6:
        return normalized[:3] == "USD" or normalized[3:6] == "USD"
    return False


def parse_set_assignments(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith((";", "#")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().split("||", 1)[0].strip()
    return values


def parse_input_defaults(text: str) -> dict[str, str]:
    return {name: value.strip() for name, value in INPUT_RE.findall(text)}


def _mode_state(value: str, key: str) -> str:
    normalized = value.strip().strip('"').upper()
    if key == "qm_news_temporal":
        if normalized in {"0", "QM_NEWS_TEMPORAL_OFF"}:
            return "OFF"
        if normalized in {"1", "2", "3", "4", "5", "6"} or normalized.startswith("QM_NEWS_TEMPORAL_"):
            return "ACTIVE"
    else:
        if normalized in {"0", "QM_NEWS_OFF"}:
            return "OFF"
        if normalized in {"1", "2", "3", "4", "5", "6"} or normalized.startswith("QM_NEWS_"):
            return "ACTIVE"
    return "UNKNOWN"


def effective_news_mode(
    set_values: dict[str, str], source_defaults: dict[str, str], evidence: dict[str, Any]
) -> tuple[str, str, str]:
    evidence_temporal = evidence.get("news_temporal")
    if isinstance(evidence_temporal, str) and evidence_temporal.strip():
        return _mode_state(evidence_temporal, "qm_news_temporal"), "evidence.news_temporal", evidence_temporal
    for key in MODE_KEYS:
        if key in set_values:
            return _mode_state(set_values[key], key), f"setfile.{key}", set_values[key]
    for key in MODE_KEYS:
        if key in source_defaults:
            return _mode_state(source_defaults[key], key), f"mq5_default.{key}", source_defaults[key]
    return "UNKNOWN", "none", ""


def extract_timeframe(setfile: Path | None, evidence: dict[str, Any], payload: dict[str, Any]) -> str | None:
    for key in ("period", "host_timeframe"):
        value = evidence.get(key) or payload.get(key)
        if str(value or "").upper() in TIMEFRAMES:
            return str(value).upper()
    if setfile:
        match = re.search(r"_(" + "|".join(TIMEFRAMES) + r")_", setfile.name, re.IGNORECASE)
        if match:
            return match.group(1).upper()
    return None


def classify_pair(
    *, symbol: str, timeframe: str | None, news_state: str, source_text: str
) -> tuple[str, str, str]:
    if not symbol_has_usd_exposure(symbol):
        return "INERT", "symbol_has_no_USD_leg_or_USD_index_mapping", "USD_NOT_APPLICABLE"
    if news_state == "OFF":
        return "INERT", "effective_news_mode_OFF", "NEWS_OFF"
    if news_state == "UNKNOWN":
        return "UNKNOWN", "effective_news_mode_unresolved", "UNKNOWN"
    if not re.search(r"QM_News(?:AllowsTrade2|AllowsTrade|EntryAllowed)", source_text):
        return "UNKNOWN", "active_news_input_but_entry_filter_call_not_proven", "UNKNOWN"
    if timeframe in {"D1", "W1", "MN1"}:
        return "INERT", f"{timeframe}_bar_entry_grid_does_not_intersect_target_30m_windows", "DAILY_OR_SLOWER"
    if timeframe in TIMEFRAMES:
        return "EXPOSED", f"active_news_filter_on_{timeframe}_intraday_entry_grid", "INTRADAY_CAPABLE"
    return "UNKNOWN", "entry_timeframe_unresolved", "UNKNOWN"


def _read_json(path: Path | None) -> dict[str, Any]:
    if path is None or not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig", errors="replace"))
    except (OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _walk_dict(value: Any) -> Iterable[tuple[str, Any]]:
    if isinstance(value, dict):
        for key, item in value.items():
            yield str(key), item
            yield from _walk_dict(item)
    elif isinstance(value, list):
        for item in value:
            yield from _walk_dict(item)


def _first_existing_path(evidence: dict[str, Any], keys: set[str], suffixes: tuple[str, ...]) -> Path | None:
    for key, value in _walk_dict(evidence):
        if key.lower() not in keys or not isinstance(value, str):
            continue
        path = Path(value)
        if path.suffix.lower() in suffixes and path.is_file():
            return path
    return None


def resolve_sources(row: sqlite3.Row, evidence: dict[str, Any]) -> tuple[Path | None, Path | None, Path | None]:
    setfile = _first_existing_path(
        evidence,
        {"setfile_path", "source_setfile_path", "baseline_setfile_path"},
        (".set",),
    )
    if setfile is None:
        candidate = Path(str(row["setfile_path"] or ""))
        setfile = candidate if candidate.is_file() else None
    ea_dir: Path | None = setfile.parent.parent if setfile is not None else None
    ea_match = re.search(r"(?:QM5_)?(\d+)", str(row["ea_id"]), re.IGNORECASE)
    ea_numeric = ea_match.group(1) if ea_match else ""
    if ea_dir is None or not ea_dir.is_dir() or not list(ea_dir.glob("*.mq5")):
        dirs = sorted((REPO / "framework/EAs").glob(f"QM5_{ea_numeric}_*"))
        ea_dir = dirs[0] if len(dirs) == 1 else None
    mq5s = sorted(ea_dir.glob("*.mq5")) if ea_dir else []
    ex5s = sorted(ea_dir.glob("*.ex5")) if ea_dir else []
    mq5 = mq5s[0] if len(mq5s) == 1 else None
    ex5 = _first_existing_path(
        evidence, {"ex5_path", "source_ex5_path", "baseline_ex5_path"}, (".ex5",)
    )
    if ex5 is None and len(ex5s) == 1:
        ex5 = ex5s[0]
    return setfile, mq5, ex5


def resolve_report(row: sqlite3.Row, evidence: dict[str, Any]) -> Path | None:
    report = _first_existing_path(
        evidence,
        {"report", "report_htm", "report_path", "source_report_path", "baseline_report_path", "native_report_path"},
        (".htm", ".html"),
    )
    if report is not None:
        return report
    root = Path(r"D:/QM/reports/work_items") / str(row["id"])
    reports = list(root.rglob("report.htm")) + list(root.rglob("report.html")) if root.is_dir() else []
    return max(reports, key=lambda path: path.stat().st_mtime) if reports else None


def _connect(db_uri: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_uri, uri=True)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def cohort_rows(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    placeholders = ",".join("?" for _ in PHASES)
    return conn.execute(
        f"""
        WITH ranked AS (
          SELECT *, ROW_NUMBER() OVER (
            PARTITION BY phase, ea_id, symbol ORDER BY updated_at DESC, id DESC
          ) AS rn
          FROM work_items
          WHERE phase IN ({placeholders}) AND status='done' AND verdict IS NOT NULL
        )
        SELECT * FROM ranked WHERE rn=1 ORDER BY phase, ea_id, symbol
        """,
        PHASES,
    ).fetchall()


def q11_pass_pairs(conn: sqlite3.Connection) -> set[tuple[str, str]]:
    rows = conn.execute(
        "SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase='Q11' AND status='done' AND verdict='PASS'"
    ).fetchall()
    return {(str(row["ea_id"]), str(row["symbol"])) for row in rows}


def q14_keep_rows(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute(
        """SELECT * FROM work_items
           WHERE phase='Q14' AND status='done' AND verdict='KEEP_INCUMBENT'
           ORDER BY updated_at,id"""
    ).fetchall()


def classify_row(row: sqlite3.Row, q11_pairs: set[tuple[str, str]]) -> dict[str, Any]:
    evidence_path = Path(str(row["evidence_path"] or "")) if row["evidence_path"] else None
    evidence = _read_json(evidence_path)
    payload = json.loads(row["payload_json"] or "{}")
    setfile, mq5, ex5 = resolve_sources(row, evidence)
    report = resolve_report(row, evidence)
    set_text = setfile.read_text(encoding="utf-8-sig", errors="replace") if setfile else ""
    source_text = mq5.read_text(encoding="utf-8-sig", errors="replace") if mq5 else ""
    set_values = parse_set_assignments(set_text)
    source_defaults = parse_input_defaults(source_text)
    news_state, news_source, news_value = effective_news_mode(set_values, source_defaults, evidence)
    timeframe = extract_timeframe(setfile, evidence, payload)
    classification, reason, timing_class = classify_pair(
        symbol=str(row["symbol"]), timeframe=timeframe, news_state=news_state, source_text=source_text
    )
    pair = (str(row["ea_id"]), str(row["symbol"]))
    return {
        "phase": row["phase"],
        "verdict": row["verdict"],
        "work_item_id": row["id"],
        "updated_at": row["updated_at"],
        "ea_id": row["ea_id"],
        "symbol": row["symbol"],
        "classification": classification,
        "classification_reason": reason,
        "usd_exposure": symbol_has_usd_exposure(str(row["symbol"])),
        "news_state": news_state,
        "news_value": news_value,
        "news_value_source": news_source,
        "entry_timing_class": timing_class,
        "timeframe": timeframe,
        "q11_pass_pair": pair in q11_pairs,
        "setfile_path": str(setfile) if setfile else None,
        "setfile_sha256_current": sha256(setfile),
        "setfile_sha256_bound": row["setfile_sha256"],
        "mq5_path": str(mq5) if mq5 else None,
        "mq5_sha256_current": sha256(mq5),
        "mq5_sha256_bound": row["mq5_sha256"],
        "ex5_path": str(ex5) if ex5 else None,
        "ex5_sha256_current": sha256(ex5),
        "ex5_sha256_bound": row["ex5_sha256"],
        "evidence_path": str(evidence_path) if evidence_path else None,
        "report_path": str(report) if report else None,
    }


def _nth_sunday(year: int, month: int, nth: int) -> int:
    first = datetime(year, month, 1).weekday()
    return 1 + (6 - first) % 7 + (nth - 1) * 7


def _is_us_dst(instant: datetime) -> bool:
    start = datetime(instant.year, 3, _nth_sunday(instant.year, 3, 2), 7, tzinfo=timezone.utc)
    end = datetime(instant.year, 11, _nth_sunday(instant.year, 11, 1), 6, tzinfo=timezone.utc)
    return start <= instant < end


def broker_wall_to_utc(wall: datetime) -> datetime:
    """QM_BrokerToUTC parity: prefer valid UTC+2 candidate at fallback."""
    wall = wall.replace(tzinfo=timezone.utc)
    standard = wall - timedelta(hours=2)
    dst = wall - timedelta(hours=3)
    if not _is_us_dst(standard):
        return standard
    if _is_us_dst(dst):
        return dst
    return standard


def _minutes_from_clock(instant: datetime, hour: int, minute: int) -> int:
    return abs((instant.hour * 60 + instant.minute) - (hour * 60 + minute))


def count_entry_windows(entry_times_broker: Sequence[datetime]) -> dict[str, Any]:
    converted = [broker_wall_to_utc(value) for value in entry_times_broker]
    true = [value for value in converted if min(_minutes_from_clock(value, 12, 30), _minutes_from_clock(value, 13, 30)) <= 30]
    wrong = [
        value
        for value in converted
        if value.weekday() == 3
        and min(_minutes_from_clock(value, 19, 30), _minutes_from_clock(value, 20, 30)) <= 30
    ]
    return {
        "entries": len(converted),
        "true_window_entries": len(true),
        "wrong_thursday_window_entries": len(wrong),
        "sample_true_utc": [value.isoformat() for value in true[:5]],
        "sample_wrong_utc": [value.isoformat() for value in wrong[:5]],
    }


def _parse_report_entry_times(report: Path) -> list[datetime]:
    scripts = REPO / "framework/scripts"
    if str(scripts) not in sys.path:
        sys.path.insert(0, str(scripts))
    import q10_recency  # type: ignore

    trades, _ = q10_recency.extract_closed_trades(report)
    return sorted({trade.entry_time for trade in trades})


def build_spot_checks(rows: Sequence[dict[str, Any]], per_class: int = 5) -> list[dict[str, Any]]:
    checks: list[dict[str, Any]] = []
    used_pairs: set[tuple[str, str]] = set()
    for target in ("EXPOSED", "INERT"):
        candidates = [row for row in rows if row["classification"] == target and row["report_path"]]
        if target == "INERT":
            candidates.sort(key=lambda row: (row["entry_timing_class"] != "DAILY_OR_SLOWER", row["phase"], row["ea_id"], row["symbol"]))
        else:
            candidates.sort(key=lambda row: (row["phase"], row["ea_id"], row["symbol"]))
        for row in candidates:
            pair = (str(row["ea_id"]), str(row["symbol"]))
            if pair in used_pairs:
                continue
            try:
                counts = count_entry_windows(_parse_report_entry_times(Path(str(row["report_path"]))))
            except Exception as exc:
                continue
            observed = counts["true_window_entries"] + counts["wrong_thursday_window_entries"] > 0
            agreement = observed if target == "EXPOSED" else not observed
            checks.append(
                {
                    "expected_classification": target,
                    "agreement": agreement,
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "phase": row["phase"],
                    "work_item_id": row["work_item_id"],
                    "report_path": row["report_path"],
                    **counts,
                }
            )
            used_pairs.add(pair)
            if sum(check["expected_classification"] == target for check in checks) >= per_class:
                break
    return checks


def summarize(
    rows: Sequence[dict[str, Any]],
    spot_checks: Sequence[dict[str, Any]],
    q14_keep: Sequence[dict[str, Any]],
    q11_classifications: Sequence[dict[str, Any]],
) -> dict[str, Any]:
    counts = Counter((row["phase"], row["verdict"], row["classification"]) for row in rows)
    phase_verdict_class = [
        {"phase": key[0], "verdict": key[1], "classification": key[2], "count": value}
        for key, value in sorted(counts.items())
    ]
    q14_exposed = [row for row in q14_keep if row["classification"] == "EXPOSED"]
    q11_exposed_pairs = sorted(
        (row["ea_id"], row["symbol"])
        for row in q11_classifications
        if row["classification"] == "EXPOSED"
    )
    return {
        "schema_version": "qm.news-calendar-defect-blast-radius/v1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "db_uri": DB_URI,
        "read_only": True,
        "row_count": len(rows),
        "distinct_pairs": len({(row["ea_id"], row["symbol"]) for row in rows}),
        "classification_counts": dict(Counter(row["classification"] for row in rows)),
        "phase_verdict_class_counts": phase_verdict_class,
        "q14_keep_incumbent_rows": len(q14_keep),
        "q14_keep_incumbent_classification_counts": dict(
            Counter(row["classification"] for row in q14_keep)
        ),
        "q14_keep_incumbent_exposed": q14_exposed,
        "q11_pass_pair_count": len(q11_classifications),
        "q11_pass_classification_counts": dict(
            Counter(row["classification"] for row in q11_classifications)
        ),
        "q11_pass_exposed_pairs": [{"ea_id": ea, "symbol": symbol} for ea, symbol in q11_exposed_pairs],
        "spot_checks": {
            "rows": len(spot_checks),
            "agreement": sum(bool(row["agreement"]) for row in spot_checks),
            "disagreement": sum(not bool(row["agreement"]) for row in spot_checks),
        },
    }


def _write_csv(path: Path, rows: Sequence[dict[str, Any]]) -> None:
    fields = list(rows[0]) if rows else ["empty"]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def _markdown(summary: dict[str, Any]) -> str:
    lines = [
        "# News-calendar timestamp defect: Q09/Q10/Q14 blast radius",
        "",
        f"Generated UTC: {summary['generated_at_utc']}",
        "",
        "## Result",
        "",
        f"The read-only census classified {summary['row_count']} latest completed phase/pair rows across {summary['distinct_pairs']} distinct EA/symbol pairs: `{json.dumps(summary['classification_counts'], sort_keys=True)}`.",
        "",
        "`INERT` means the USD event is not applicable, the effective news mode is off, or the daily/slower entry grid cannot intersect either ±30 minute slot. `EXPOSED` means a USD-applicable intraday EA has an active news filter and can enter in at least one slot. Ambiguous source/mode/timeframe cases remain `UNKNOWN`.",
        "",
        "## Counts by phase, verdict, and class",
        "",
        "| phase | verdict | class | count |",
        "|---|---|---|---:|",
    ]
    for row in summary["phase_verdict_class_counts"]:
        lines.append(f"| {row['phase']} | {row['verdict']} | {row['classification']} | {row['count']} |")
    lines += [
        "",
        "## Q14 KEEP_INCUMBENT rows classified EXPOSED",
        "",
        f"Across all {summary['q14_keep_incumbent_rows']} historical KEEP_INCUMBENT rows (including repeated decisions for the same pair), classifications are `{json.dumps(summary['q14_keep_incumbent_classification_counts'], sort_keys=True)}`.",
        "",
    ]
    if summary["q14_keep_incumbent_exposed"]:
        for row in summary["q14_keep_incumbent_exposed"]:
            lines.append(f"- `{row['work_item_id']}` — {row['ea_id']} / {row['symbol']} ({row['classification_reason']})")
    else:
        lines.append("- None.")
    lines += [
        "",
        "## Q11 PASS pairs classified EXPOSED",
        "",
    ]
    if summary["q11_pass_exposed_pairs"]:
        for row in summary["q11_pass_exposed_pairs"]:
            lines.append(f"- {row['ea_id']} / {row['symbol']}")
    else:
        lines.append("- None.")
    spot = summary["spot_checks"]
    lines += [
        "",
        "## Entry-timestamp spot check",
        "",
        f"Five EXPOSED and five INERT classifications were requested. The available native reports yielded {spot['rows']} checks: {spot['agreement']} agreement / {spot['disagreement']} disagreement. Counts use unique entry timestamps converted from Darwinex broker wall time to UTC with `qm.dst_rule.us.v1`; true windows are ±30 minutes around 12:30/13:30Z, and displaced windows are Thursday ±30 minutes around 19:30/20:30Z.",
        "",
        "See `spot_checks.csv` for counts and samples. A static EXPOSED classification means the EA *can* enter in the interval; a zero empirical count in one finite report is retained as a disagreement rather than silently reclassifying the EA.",
        "",
        "## Method and limits",
        "",
        "- SQLite was opened with `mode=ro` and `PRAGMA query_only=ON`.",
        "- For each `(phase, ea_id, symbol)`, the latest completed non-null verdict row was selected.",
        "- Exact set/MQ5/EX5 paths, current hashes, stored evidence hashes, evidence paths, and report paths are in `blast_radius.csv` and `blast_radius.json`.",
        "- `q14_keep_incumbent.*` preserves all nine historical KEEP_INCUMBENT rows; `q11_pass_classifications.*` gives one classification for each of the 31 Q11 PASS pairs.",
        "- USD applicability follows `QM_NewsIndexCurrencies` plus base/quote currency legs. NDX/SP500/WS30 aliases therefore count as USD; GDAXI does not.",
        "- The analysis is report-only. It does not alter verdicts or claim that an affected verdict would reverse under corrected timestamps.",
        "",
        "No calendar, gate, verdict, database, terminal, T_Live, or AutoTrading state was changed.",
        "",
    ]
    return "\n".join(lines)


def run(out_dir: Path, db_uri: str = DB_URI) -> dict[str, Any]:
    out_dir.mkdir(parents=True, exist_ok=True)
    with _connect(db_uri) as conn:
        q11 = q11_pass_pairs(conn)
        rows = [classify_row(row, q11) for row in cohort_rows(conn)]
        q14_keep = [classify_row(row, q11) for row in q14_keep_rows(conn)]
    latest_by_pair: dict[tuple[str, str], dict[str, Any]] = {}
    for row in sorted(rows, key=lambda item: (str(item["updated_at"]), str(item["work_item_id"]))):
        latest_by_pair[(str(row["ea_id"]), str(row["symbol"]))] = row
    q11_classifications = []
    for pair in sorted(q11):
        source = latest_by_pair.get(pair)
        if source is None:
            q11_classifications.append(
                {
                    "ea_id": pair[0],
                    "symbol": pair[1],
                    "classification": "UNKNOWN",
                    "classification_reason": "no_completed_Q09_Q10_Q14_row_to_resolve",
                    "source_phase": None,
                    "source_work_item_id": None,
                }
            )
        else:
            q11_classifications.append(
                {
                    "ea_id": pair[0],
                    "symbol": pair[1],
                    "classification": source["classification"],
                    "classification_reason": source["classification_reason"],
                    "source_phase": source["phase"],
                    "source_work_item_id": source["work_item_id"],
                }
            )
    checks = build_spot_checks(rows)
    summary = summarize(rows, checks, q14_keep, q11_classifications)
    _write_csv(out_dir / "blast_radius.csv", rows)
    _write_csv(out_dir / "spot_checks.csv", checks)
    _write_csv(out_dir / "q14_keep_incumbent.csv", q14_keep)
    _write_csv(out_dir / "q11_pass_classifications.csv", q11_classifications)
    (out_dir / "blast_radius.json").write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out_dir / "spot_checks.json").write_text(json.dumps(checks, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out_dir / "q14_keep_incumbent.json").write_text(json.dumps(q14_keep, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out_dir / "q11_pass_classifications.json").write_text(json.dumps(q11_classifications, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out_dir / "README.md").write_text(_markdown(summary), encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--db-uri", default=DB_URI)
    args = parser.parse_args()
    print(json.dumps(run(args.out, args.db_uri), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
