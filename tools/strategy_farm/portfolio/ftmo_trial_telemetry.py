#!/usr/bin/env python3
"""Validate and compact read-only FTMO trial telemetry into M5/day checks."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo


RAW_SCHEMA = "qm.ftmo-trial-telemetry.raw/v1"
OUTPUT_SCHEMA = "qm.ftmo-trial-telemetry.m5/v1"
PRAGUE = ZoneInfo("Europe/Prague")


class TelemetryError(ValueError):
    pass


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise TelemetryError(f"duplicate_json_key:{key}")
        result[key] = value
    return result


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _timestamp(value: Any) -> dt.datetime:
    if not isinstance(value, str):
        raise TelemetryError("ts_utc_not_string")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise TelemetryError("ts_utc_invalid") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != dt.timedelta(0):
        raise TelemetryError("ts_utc_not_utc")
    return parsed


def prague_day_key(timestamp: dt.datetime) -> int:
    local = timestamp.astimezone(PRAGUE)
    return local.year * 10000 + local.month * 100 + local.day


def load_rows(path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    identities: dict[tuple[str, int], bytes] = {}
    sessions: list[str] = []
    prior_sequence: dict[str, int] = {}
    stream_identity = None
    last_timestamp = None
    with path.open(encoding="utf-8-sig") as handle:
        for line_number, raw in enumerate(handle, 1):
            if not raw.strip():
                continue
            try:
                row = json.loads(raw, object_pairs_hook=_pairs)
            except json.JSONDecodeError as exc:
                raise TelemetryError(f"json_invalid:{line_number}") from exc
            if not isinstance(row, dict):
                raise TelemetryError(f"row_not_object:{line_number}")
            if row.get("schema") != RAW_SCHEMA or row.get("event") != "SAMPLE":
                raise TelemetryError(f"schema_or_event_invalid:{line_number}")
            session = row.get("session_id")
            sequence = row.get("sequence")
            if not isinstance(session, str) or not session or type(sequence) is not int or sequence < 0:
                raise TelemetryError(f"identity_invalid:{line_number}")
            timestamp = _timestamp(row.get("ts_utc"))
            identity = tuple(row.get(key) for key in ("trial_id", "account_login", "account_server", "currency"))
            if any(value is None or value == "" for value in identity) or type(identity[1]) is not int or identity[1] <= 0:
                raise TelemetryError(f"account_identity_invalid:{line_number}")
            if stream_identity is not None and identity != stream_identity:
                raise TelemetryError(f"mixed_account_or_trial:{line_number}")
            stream_identity = identity
            if type(row.get("ts_epoch")) is not int or row["ts_epoch"] != int(timestamp.timestamp()):
                raise TelemetryError(f"epoch_mismatch:{line_number}")
            if row.get("prague_day_key") != prague_day_key(timestamp):
                raise TelemetryError(f"prague_day_key_mismatch:{line_number}")
            for key in ("balance", "equity"):
                if not isinstance(row.get(key), (int, float)) or isinstance(row.get(key), bool) or not math.isfinite(row[key]):
                    raise TelemetryError(f"{key}_invalid:{line_number}")
            for key in ("open_positions", "pending_orders"):
                if not isinstance(row.get(key), int) or isinstance(row.get(key), bool) or row[key] < 0:
                    raise TelemetryError(f"{key}_invalid:{line_number}")
            if row.get("reconciliation_complete") is not True:
                raise TelemetryError(f"inventory_not_reconciled:{line_number}")
            for inventory in ("positions", "orders"):
                if not isinstance(row.get(inventory), list) or any(not isinstance(item, dict) or type(item.get("magic")) is not int for item in row[inventory]):
                    raise TelemetryError(f"inventory_invalid:{line_number}")
            if len(row.get("positions") or []) != row["open_positions"] or len(row.get("orders") or []) != row["pending_orders"]:
                raise TelemetryError(f"inventory_count_mismatch:{line_number}")
            encoded = json.dumps(row, sort_keys=True, separators=(",", ":")).encode()
            key = (session, sequence)
            if key in identities:
                if identities[key] != encoded:
                    raise TelemetryError(f"identity_race_conflict:{session}:{sequence}")
                continue
            if session in prior_sequence and sequence <= prior_sequence[session]:
                raise TelemetryError(f"sequence_regression:{line_number}")
            if session in prior_sequence and sequence != prior_sequence[session] + 1:
                raise TelemetryError(f"sequence_gap:{line_number}")
            if last_timestamp is not None and timestamp < last_timestamp:
                raise TelemetryError(f"timestamp_regression:{line_number}")
            if sessions and session != sessions[-1] and session in sessions:
                raise TelemetryError(f"interleaved_sessions:{line_number}")
            last_timestamp = timestamp
            identities[key] = encoded
            prior_sequence[session] = sequence
            if session not in sessions:
                sessions.append(session)
            row["_timestamp"] = timestamp
            rows.append(row)
    if not rows:
        raise TelemetryError("no_samples")
    ordered = rows  # Preserve capture order for same-second endpoint samples.
    return ordered, {"sessions": sessions, "restart_count": max(0, len(sessions) - 1), "deduplicated_samples": len(rows)}


def _bucket_start(timestamp: dt.datetime, seconds: int) -> dt.datetime:
    epoch = int(timestamp.timestamp())
    return dt.datetime.fromtimestamp(epoch - epoch % seconds, dt.timezone.utc)


def build_report(
    source: Path,
    *,
    grid_seconds: int = 300,
    maximum_sample_gap_seconds: int = 10,
    initial_balance: float = 100_000.0,
    daily_loss_fraction: float = 0.05,
    target_fraction: float = 0.10,
) -> dict[str, Any]:
    if grid_seconds <= 0 or maximum_sample_gap_seconds <= 0:
        raise TelemetryError("cadence_invalid")
    rows, ingestion = load_rows(source)
    gaps = []
    for previous, current in zip(rows, rows[1:]):
        seconds = (current["_timestamp"] - previous["_timestamp"]).total_seconds()
        if seconds > maximum_sample_gap_seconds:
            gaps.append({
                "after": previous["ts_utc"],
                "before": current["ts_utc"],
                "seconds": seconds,
                "restart_boundary": previous["session_id"] != current["session_id"],
            })
    groups: dict[dt.datetime, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        groups[_bucket_start(row["_timestamp"], grid_seconds)].append(row)
    m5 = []
    first_bucket = min(groups)
    last_bucket = max(groups)
    missing_intervals = []
    cursor = first_bucket
    while cursor <= last_bucket:
        if cursor not in groups:
            missing_intervals.append(cursor.isoformat().replace("+00:00", "Z"))
        cursor += dt.timedelta(seconds=grid_seconds)
    for start in sorted(groups):
        samples = groups[start]
        endpoint = samples[-1]
        m5.append({
            "interval_start_utc": start.isoformat().replace("+00:00", "Z"),
            "interval_end_utc": (start + dt.timedelta(seconds=grid_seconds)).isoformat().replace("+00:00", "Z"),
            "prague_day_key": endpoint["prague_day_key"],
            "sample_count": len(samples),
            "balance": round(float(endpoint["balance"]), 2),
            "equity": round(float(endpoint["equity"]), 2),
            "interval_min_equity": round(min(float(row["equity"]) for row in samples), 2),
            "open_positions": endpoint["open_positions"],
            "pending_orders": endpoint["pending_orders"],
            "positions_by_magic": _counts_by_magic(endpoint["positions"]),
            "pending_orders_by_magic": _counts_by_magic(endpoint["orders"]),
        })
    daily_groups: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        daily_groups[row["prague_day_key"]].append(row)
    keys = sorted(daily_groups)
    days = []
    for index, key in enumerate(keys):
        samples = daily_groups[key]
        first, last = samples[0], samples[-1]
        local_first = first["_timestamp"].astimezone(PRAGUE)
        anchor = local_first.replace(hour=0, minute=0, second=0, microsecond=0)
        anchor_lag = (local_first - anchor).total_seconds()
        complete_start = anchor_lag <= maximum_sample_gap_seconds
        next_anchor = (anchor + dt.timedelta(days=1)).astimezone(dt.timezone.utc)
        complete_end = rows[-1]["_timestamp"] >= next_anchor and (next_anchor - last["_timestamp"]).total_seconds() <= maximum_sample_gap_seconds
        day_has_gap = any(_timestamp(gap["after"]) < next_anchor and _timestamp(gap["before"]) > anchor.astimezone(dt.timezone.utc) for gap in gaps)
        day_min = min(float(row["equity"]) for row in samples)
        floor = float(first["balance"]) - initial_balance * daily_loss_fraction
        status = "EVALUABLE" if complete_start and complete_end else "ABSTAIN_PARTIAL_DAY"
        if day_has_gap:
            status = "ABSTAIN_GAPS"
        days.append({
            "prague_day_key": key,
            "anchor_ts_utc": first["ts_utc"],
            "anchor_lag_seconds": anchor_lag,
            "anchor_balance": round(float(first["balance"]), 2),
            "daily_floor": round(floor, 2),
            "minimum_equity": round(day_min, 2),
            "daily_loss_breached": (day_min < floor) if status == "EVALUABLE" else None,
            "status": status,
            "last_ts_utc": last["ts_utc"],
        })
    target = initial_balance * (1.0 + target_fraction)
    target_rows = [row for row in rows if float(row["balance"]) > target]
    first_target = target_rows[0] if target_rows else None
    return {
        "schema": OUTPUT_SCHEMA,
        "source": {"path": str(source.resolve()), "sha256": _sha256(source), "rows": len(rows)},
        "contract": {
            "timezone": "Europe/Prague",
            "grid_seconds": grid_seconds,
            "maximum_sample_gap_seconds": maximum_sample_gap_seconds,
            "equity_basis": "ACCOUNT_EQUITY_INCLUDING_OPEN_PNL_SWAP_COMMISSION",
            "interval_min_basis": "MINIMUM_OF_ALL_TICK_AND_TIMER_SAMPLES_IN_INTERVAL",
            "daily_loss_breach_operator": "equity < anchor_balance - initial_balance*0.05",
            "profit_target_operator": "balance > initial_balance*1.10 AND flat",
        },
        "ingestion": ingestion,
        "continuity": {"status": "PASS" if not gaps and not missing_intervals else "FAIL_GAPS", "gaps": gaps, "missing_intervals": missing_intervals},
        "m5_rows": m5,
        "days": days,
        "flat_at_target": {
            "status": "NOT_REACHED" if first_target is None else ("PASS" if first_target["open_positions"] == 0 and first_target["pending_orders"] == 0 else "FAIL_NOT_FLAT"),
            "target_balance_strictly_above": round(target, 2),
            "first_target_ts_utc": None if first_target is None else first_target["ts_utc"],
            "open_positions": None if first_target is None else first_target["open_positions"],
            "pending_orders": None if first_target is None else first_target["pending_orders"],
        },
        "challenge_proof": False,
    }


def _counts_by_magic(items: list[dict[str, Any]]) -> dict[str, int]:
    result: dict[str, int] = {}
    for item in items:
        magic = str(item.get("magic", 0))
        result[magic] = result.get(magic, 0) + 1
    return dict(sorted(result.items(), key=lambda pair: int(pair[0])))


def compact_daily(source: Path, destination: Path, *, maximum_sample_gap_seconds: int = 10) -> dict[str, Any]:
    """Compact an immutable snapshot; publish a hash manifest last, never fill holes."""
    source_hash = _sha256(source)
    report = build_report(source, maximum_sample_gap_seconds=maximum_sample_gap_seconds)
    if _sha256(source) != source_hash or report["source"]["sha256"] != source_hash:
        raise TelemetryError("source_changed_during_compaction")
    if report["continuity"]["status"] != "PASS":
        raise TelemetryError("compaction_refused_gaps")
    if destination.exists():
        raise TelemetryError("destination_already_exists")
    by_day: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for row in report["m5_rows"]:
        by_day[row["prague_day_key"]].append(row)
    destination.mkdir(parents=True)
    outputs = []
    for day, rows in sorted(by_day.items()):
        target = destination / f"{day}.jsonl"
        target.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")
        outputs.append({"path": target.name, "sha256": _sha256(target), "rows": len(rows), "prague_day_key": day})
    manifest = {"schema": "qm.ftmo-trial-telemetry.compaction/v1", "source": report["source"],
                "outputs": outputs, "continuity": report["continuity"], "days": report["days"],
                "ingestion": report["ingestion"], "challenge_proof": False}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    verify_compaction(destination)
    return manifest


def verify_compaction(destination: Path) -> dict[str, Any]:
    manifest = json.loads((destination / "manifest.json").read_text(encoding="utf-8"), object_pairs_hook=_pairs)
    if manifest.get("schema") != "qm.ftmo-trial-telemetry.compaction/v1":
        raise TelemetryError("manifest_schema_invalid")
    if _sha256(Path(manifest["source"]["path"])) != manifest["source"]["sha256"]:
        raise TelemetryError("manifest_source_hash_mismatch")
    expected = {"manifest.json"}
    for output in manifest["outputs"]:
        name = output["path"]
        if name != f"{output['prague_day_key']}.jsonl" or name in expected:
            raise TelemetryError("manifest_output_path_invalid")
        expected.add(name)
        target = destination / name
        if _sha256(target) != output["sha256"]:
            raise TelemetryError("manifest_output_hash_mismatch")
        rows = [json.loads(line) for line in target.read_text(encoding="utf-8").splitlines()]
        if len(rows) != output["rows"] or any(row["prague_day_key"] != output["prague_day_key"] for row in rows):
            raise TelemetryError("manifest_output_rows_mismatch")
    if {path.name for path in destination.iterdir()} != expected:
        raise TelemetryError("manifest_unexpected_files")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--grid-seconds", type=int, default=300)
    parser.add_argument("--maximum-sample-gap-seconds", type=int, default=10)
    parser.add_argument("--compact-directory", type=Path)
    args = parser.parse_args()
    result = build_report(args.input, grid_seconds=args.grid_seconds, maximum_sample_gap_seconds=args.maximum_sample_gap_seconds)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.compact_directory:
        compact_daily(args.input, args.compact_directory, maximum_sample_gap_seconds=args.maximum_sample_gap_seconds)
    print(json.dumps({"status": result["continuity"]["status"], "rows": len(result["m5_rows"]), "output": str(args.output)}))
    return 0 if result["continuity"]["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
