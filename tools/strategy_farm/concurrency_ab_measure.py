"""Read-only measurement harness for the terminal-concurrency A/B experiment.

Phase 1 records a trailing baseline without changing worker, queue, or policy
state.  It deliberately has no switch/apply command.  A later, reviewed Phase 2
may change ``state/disabled_terminals.txt`` outside this program.

Metrics:

* execution verdicts/day, excluding ``disposition_only`` rows;
* ``MEASURED`` non-gate measurement cells/hour;
* timestamped ``cpu_high_pause`` events/hour and events/slot-hour;
* claimed-to-terminal median wall time for each operator-facing Q phase; and
* occupied terminal-hours / configured slot-hours.

The SQLite connection is URI ``mode=ro`` plus ``PRAGMA query_only=ON``.  Worker
logs are scanned backwards and only timestamped events inside the explicit
window are accepted.  The tool writes only the requested CSV and Markdown
evidence files.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable, Iterator, Mapping, Sequence

try:  # direct ``python tools/strategy_farm/<script>.py`` imports
    from phase_ids import phase_qid
    from sqlite_timestamp import normalized_timestamp_sql
    from throughput_telemetry import is_disposition_only
except ModuleNotFoundError:  # package imports (tests, module consumers)
    from tools.strategy_farm.phase_ids import phase_qid
    from tools.strategy_farm.sqlite_timestamp import normalized_timestamp_sql
    from tools.strategy_farm.throughput_telemetry import is_disposition_only

UPDATED_AT_SQL = normalized_timestamp_sql("updated_at")


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_LOG_DIR = Path(r"D:\QM\strategy_farm\logs")
DEFAULT_DISABLED_TERMINALS = Path(
    r"D:\QM\strategy_farm\state\disabled_terminals.txt"
)
DEFAULT_WINDOW_HOURS = 24.0
DEFAULT_CONFIGURED_SLOTS = 10
CPU_PAUSE_EVENT = "cpu_high_pause"
_Q_PHASE_RE = re.compile(r"^(Q\d{2})(?:[_-].+)?$", re.IGNORECASE)
_TERMINAL_RE = re.compile(r"^T(?:[1-9]|10)$", re.IGNORECASE)


def _utc(value: dt.datetime) -> dt.datetime:
    if value.tzinfo is None:
        value = value.replace(tzinfo=dt.timezone.utc)
    return value.astimezone(dt.timezone.utc)


def _iso(value: dt.datetime) -> str:
    return _utc(value).isoformat()


def _parse_iso(value: Any) -> dt.datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError:
        try:
            parsed = dt.datetime.strptime(text, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            return None
    return _utc(parsed)


def _payload(value: Any) -> dict[str, Any]:
    try:
        parsed = json.loads(str(value or "{}"))
    except (json.JSONDecodeError, TypeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def operator_q_phase(phase: Any, contract_version: Any) -> str | None:
    """Return a Q-only operator phase; non-gate measurement families are None."""
    qid = phase_qid(str(phase or ""), contract_version).upper()
    match = _Q_PHASE_RE.fullmatch(qid)
    return match.group(1) if match else None


def _terminal(value: Any) -> str | None:
    terminal = str(value or "").strip().upper()
    return terminal if _TERMINAL_RE.fullmatch(terminal) else None


def _row_value(row: Any, key: str, index: int) -> Any:
    try:
        return row[key]
    except (IndexError, KeyError, TypeError):
        return row[index]


def _median(values: Sequence[float]) -> float | None:
    if not values:
        return None
    return round(float(statistics.median(values)), 3)


def _merge_seconds(
    intervals: Iterable[tuple[dt.datetime, dt.datetime]],
) -> float:
    ordered = sorted((start, end) for start, end in intervals if end > start)
    if not ordered:
        return 0.0
    total = 0.0
    current_start, current_end = ordered[0]
    for start, end in ordered[1:]:
        if start <= current_end:
            current_end = max(current_end, end)
            continue
        total += (current_end - current_start).total_seconds()
        current_start, current_end = start, end
    return total + (current_end - current_start).total_seconds()


def collect_db_metrics(
    con: sqlite3.Connection,
    *,
    window_end: dt.datetime,
    window_hours: float = DEFAULT_WINDOW_HOURS,
    configured_slots: int = DEFAULT_CONFIGURED_SLOTS,
) -> dict[str, Any]:
    """Measure one consistent DB snapshot using SELECT statements only."""
    end = _utc(window_end)
    start = end - dt.timedelta(hours=window_hours)
    permitted_terminals = {f"T{i}" for i in range(1, configured_slots + 1)}

    rows = con.execute(
        f"""
        SELECT phase, gate_contract_version, status, verdict, claimed_by,
               payload_json, updated_at
        FROM work_items
        WHERE status='active'
           OR (status IN ('done','failed') AND {UPDATED_AT_SQL} >= datetime(?)
               AND {UPDATED_AT_SQL} <= datetime(?))
        """,
        (_iso(start), _iso(end)),
    ).fetchall()

    execution_total = 0
    disposition_total = 0
    measured_total = 0
    execution_by_phase: dict[str, int] = defaultdict(int)
    wall_by_phase: dict[str, list[float]] = defaultdict(list)
    measurement_wall: list[float] = []
    intervals_by_terminal: dict[
        str, list[tuple[dt.datetime, dt.datetime]]
    ] = defaultdict(list)
    skipped_wall_no_claim = 0
    skipped_utilization_no_binding = 0

    for row in rows:
        phase = _row_value(row, "phase", 0)
        contract_version = _row_value(row, "gate_contract_version", 1)
        status = str(_row_value(row, "status", 2) or "").lower()
        verdict = str(_row_value(row, "verdict", 3) or "").upper()
        claimed_by = _row_value(row, "claimed_by", 4)
        payload_json = _row_value(row, "payload_json", 5)
        updated = _parse_iso(_row_value(row, "updated_at", 6))
        payload = _payload(payload_json)
        claimed = _parse_iso(payload.get("claimed_at_iso"))
        q_phase = operator_q_phase(phase, contract_version)
        disposition = is_disposition_only(payload_json)

        terminal_row = status in {"done", "failed"} and bool(verdict)
        finished_in_window = terminal_row and updated is not None and start <= updated <= end
        if finished_in_window:
            if disposition:
                disposition_total += 1
            else:
                execution_total += 1
                if q_phase:
                    execution_by_phase[q_phase] += 1
                if verdict == "MEASURED":
                    measured_total += 1

                if claimed is None:
                    skipped_wall_no_claim += 1
                else:
                    wall_minutes = max(
                        0.0, (updated - claimed).total_seconds() / 60.0
                    )
                    if q_phase:
                        wall_by_phase[q_phase].append(wall_minutes)
                    elif verdict == "MEASURED":
                        measurement_wall.append(wall_minutes)

        # Utilization uses every claim interval that intersects the window,
        # including active work and non-gate measurement work.  Completed rows
        # persist their terminal in payload_json; active rows may also use
        # claimed_by as a compatibility fallback.
        interval_end = end if status == "active" else updated
        bound_terminal = _terminal(payload.get("terminal")) or _terminal(claimed_by)
        if claimed is None or interval_end is None or bound_terminal not in permitted_terminals:
            if status == "active" or finished_in_window:
                skipped_utilization_no_binding += 1
            continue
        clipped_start = max(start, claimed)
        clipped_end = min(end, interval_end)
        if clipped_end > clipped_start:
            intervals_by_terminal[bound_terminal].append((clipped_start, clipped_end))

    occupied_by_terminal = {
        terminal: round(_merge_seconds(intervals_by_terminal.get(terminal, ())) / 3600.0, 3)
        for terminal in sorted(permitted_terminals, key=lambda value: int(value[1:]))
    }
    occupied_hours = round(sum(occupied_by_terminal.values()), 3)
    available_hours = round(float(configured_slots) * float(window_hours), 3)
    utilization = 0.0 if available_hours <= 0 else occupied_hours / available_hours
    days = float(window_hours) / 24.0
    hours = float(window_hours)

    # This snapshot is context for matching the Phase-2 queue mix.  Only Q phase
    # dimensions are operator-facing; utility measurement work is reported as a
    # separate non-gate pool.
    queue_rows = con.execute(
        """
        SELECT phase, gate_contract_version, status, COUNT(*) AS row_count
        FROM work_items
        WHERE status IN ('pending','active')
        GROUP BY phase, gate_contract_version, status
        """
    ).fetchall()
    queue_by_phase: dict[str, dict[str, int]] = defaultdict(
        lambda: {"pending": 0, "active": 0}
    )
    measurement_queue = {"pending": 0, "active": 0}
    other_non_gate_queue = {"pending": 0, "active": 0}
    for row in queue_rows:
        phase = _row_value(row, "phase", 0)
        contract_version = _row_value(row, "gate_contract_version", 1)
        status = str(_row_value(row, "status", 2) or "").lower()
        count = int(_row_value(row, "row_count", 3) or 0)
        q_phase = operator_q_phase(phase, contract_version)
        if q_phase:
            queue_by_phase[q_phase][status] += count
        elif str(phase or "").upper() == "OPT_CENSUS":
            measurement_queue[status] += count
        else:
            other_non_gate_queue[status] += count

    return {
        "window_start_utc": _iso(start),
        "window_end_utc": _iso(end),
        "window_hours": float(window_hours),
        "configured_slots": int(configured_slots),
        "execution_verdicts": execution_total,
        "execution_verdicts_per_day": round(execution_total / (days or 1.0), 3),
        "disposition_only_rows": disposition_total,
        "measured_cells": measured_total,
        "measured_cells_per_hour": round(measured_total / (hours or 1.0), 3),
        "execution_by_phase": dict(sorted(execution_by_phase.items())),
        "median_wall_minutes_by_phase": {
            phase: {
                "median": _median(values),
                "sample_count": len(values),
            }
            for phase, values in sorted(wall_by_phase.items())
        },
        "measurement_pool_wall_minutes": {
            "median": _median(measurement_wall),
            "sample_count": len(measurement_wall),
        },
        "slot_utilization": round(utilization, 6),
        "occupied_terminal_hours": occupied_hours,
        "available_slot_hours": available_hours,
        "occupied_hours_by_terminal": occupied_by_terminal,
        "skipped_wall_no_claim": skipped_wall_no_claim,
        "skipped_utilization_no_binding": skipped_utilization_no_binding,
        "queue_by_phase": dict(sorted(queue_by_phase.items())),
        "measurement_pool_queue": measurement_queue,
        "other_non_gate_queue": other_non_gate_queue,
    }


def _reverse_lines(path: Path, block_size: int = 128 * 1024) -> Iterator[str]:
    """Yield a potentially large append-only log from newest line to oldest."""
    with path.open("rb") as handle:
        handle.seek(0, os.SEEK_END)
        position = handle.tell()
        remainder = b""
        while position > 0:
            take = min(block_size, position)
            position -= take
            handle.seek(position)
            data = handle.read(take) + remainder
            lines = data.split(b"\n")
            remainder = lines[0]
            for raw in reversed(lines[1:]):
                if raw:
                    yield raw.rstrip(b"\r").decode("utf-8", errors="replace")
        if remainder:
            yield remainder.rstrip(b"\r").decode("utf-8", errors="replace")


def collect_cpu_pause_metrics(
    log_dir: Path,
    *,
    window_end: dt.datetime,
    window_hours: float = DEFAULT_WINDOW_HOURS,
    configured_slots: int = DEFAULT_CONFIGURED_SLOTS,
) -> dict[str, Any]:
    """Count timestamped CPU pauses without streaming the full multi-GB logs."""
    end = _utc(window_end)
    start = end - dt.timedelta(hours=window_hours)
    counts: dict[str, int] = {}
    coverage: dict[str, dict[str, Any]] = {}
    total = 0

    for index in range(1, configured_slots + 1):
        terminal = f"T{index}"
        path = Path(log_dir) / f"terminal_worker_{terminal}.log"
        count = 0
        lines_scanned = 0
        timestamped_lines = 0
        newest: dt.datetime | None = None
        oldest: dt.datetime | None = None
        reached_cutoff = False
        if path.is_file():
            try:
                for line in _reverse_lines(path):
                    lines_scanned += 1
                    stripped = line.strip()
                    if not stripped.startswith("{"):
                        continue
                    try:
                        event = json.loads(stripped)
                    except json.JSONDecodeError:
                        continue
                    if not isinstance(event, dict):
                        continue
                    stamp = _parse_iso(event.get("at_utc"))
                    if stamp is None:
                        continue
                    timestamped_lines += 1
                    newest = stamp if newest is None else max(newest, stamp)
                    oldest = stamp if oldest is None else min(oldest, stamp)
                    if stamp < start:
                        reached_cutoff = True
                        break
                    if stamp <= end and event.get("event") == CPU_PAUSE_EVENT:
                        event_terminal = _terminal(event.get("terminal")) or terminal
                        if event_terminal == terminal:
                            count += 1
            except OSError:
                pass
        counts[terminal] = count
        total += count
        coverage[terminal] = {
            "path_exists": path.is_file(),
            "reached_cutoff": reached_cutoff,
            "lines_scanned": lines_scanned,
            "timestamped_lines": timestamped_lines,
            "newest_at_utc": _iso(newest) if newest else None,
            "oldest_at_utc": _iso(oldest) if oldest else None,
        }

    hours = float(window_hours)
    slot_hours = hours * float(configured_slots)
    return {
        "cpu_high_pause_events": total,
        "cpu_high_pause_events_per_hour": round(total / (hours or 1.0), 3),
        "cpu_high_pause_events_per_slot_hour": round(total / (slot_hours or 1.0), 3),
        "cpu_high_pause_by_terminal": counts,
        "log_coverage": coverage,
        "coverage_complete": all(
            item["path_exists"] and item["reached_cutoff"]
            for item in coverage.values()
        ),
    }


def disabled_file_snapshot(path: Path) -> dict[str, Any]:
    try:
        raw = Path(path).read_bytes()
    except OSError:
        return {"path": str(path), "exists": False, "bytes": None, "sha256": None}
    return {
        "path": str(path),
        "exists": True,
        "bytes": len(raw),
        "sha256": hashlib.sha256(raw).hexdigest(),
    }


def metric_rows(snapshot: Mapping[str, Any], label: str) -> list[dict[str, Any]]:
    base = {
        "window_label": label,
        "window_start_utc": snapshot["window_start_utc"],
        "window_end_utc": snapshot["window_end_utc"],
        "configured_slots": snapshot["configured_slots"],
    }
    rows: list[dict[str, Any]] = []

    def add(
        metric: str,
        dimension: str,
        value: Any,
        unit: str,
        sample_count: Any = "",
        note: str = "",
    ) -> None:
        rows.append(
            {
                **base,
                "metric": metric,
                "dimension": dimension,
                "value": value,
                "unit": unit,
                "sample_count": sample_count,
                "note": note,
            }
        )

    add(
        "execution_verdicts_per_day",
        "all",
        snapshot["execution_verdicts_per_day"],
        "verdicts/day",
        snapshot["execution_verdicts"],
        "terminal execution rows; disposition_only excluded",
    )
    add(
        "measured_cells_per_hour",
        "non_gate_measurement_pool",
        snapshot["measured_cells_per_hour"],
        "cells/hour",
        snapshot["measured_cells"],
    )
    add(
        "cpu_high_pause_events_per_hour",
        "fleet",
        snapshot["cpu_high_pause_events_per_hour"],
        "events/hour",
        snapshot["cpu_high_pause_events"],
    )
    add(
        "cpu_high_pause_events_per_slot_hour",
        "fleet",
        snapshot["cpu_high_pause_events_per_slot_hour"],
        "events/slot-hour",
        snapshot["cpu_high_pause_events"],
    )
    add(
        "slot_utilization",
        "fleet",
        round(float(snapshot["slot_utilization"]) * 100.0, 3),
        "percent",
        note=(
            f"{snapshot['occupied_terminal_hours']} occupied terminal-hours / "
            f"{snapshot['available_slot_hours']} configured slot-hours"
        ),
    )
    for phase, item in snapshot["median_wall_minutes_by_phase"].items():
        add(
            "median_wall_minutes",
            phase,
            item["median"],
            "minutes",
            item["sample_count"],
        )
    measurement_wall = snapshot["measurement_pool_wall_minutes"]
    add(
        "median_measurement_cell_wall_minutes",
        "non_gate_measurement_pool",
        measurement_wall["median"],
        "minutes",
        measurement_wall["sample_count"],
    )
    for terminal, hours in snapshot["occupied_hours_by_terminal"].items():
        add("occupied_terminal_hours", terminal, hours, "hours")
    return rows


def _fmt(value: Any, digits: int = 2) -> str:
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def render_report(snapshot: Mapping[str, Any], label: str) -> str:
    coverage = "complete" if snapshot["coverage_complete"] else "INCOMPLETE (lower bound)"
    disabled = snapshot["disabled_terminals_file"]
    lines = [
        f"# V3 concurrency A/B — {label} 24-hour baseline",
        "",
        "**Verdict:** `BASELINE_MEASURED_NO_SWITCH`",
        "",
        (
            f"Window: `{snapshot['window_start_utc']}` through "
            f"`{snapshot['window_end_utc']}` ({_fmt(snapshot['window_hours'])} h). "
            "The database was opened read-only; no worker, queue row, terminal, "
            "or concurrency-policy file was changed."
        ),
        "",
        "## Baseline metrics",
        "",
        "| Metric | Result | Sample / denominator |",
        "|---|---:|---:|",
        (
            f"| Net execution verdicts/day | "
            f"**{_fmt(snapshot['execution_verdicts_per_day'], 3)}** | "
            f"{snapshot['execution_verdicts']} execution rows; "
            f"{snapshot['disposition_only_rows']} administrative rows excluded |"
        ),
        (
            f"| MEASURED cells/hour | **{_fmt(snapshot['measured_cells_per_hour'], 3)}** | "
            f"{snapshot['measured_cells']} cells |"
        ),
        (
            f"| CPU-high pause rate | **{_fmt(snapshot['cpu_high_pause_events_per_hour'], 3)}** "
            f"events/hour | {snapshot['cpu_high_pause_events']} events; log coverage {coverage} |"
        ),
        (
            f"| CPU-high pause density | "
            f"**{_fmt(snapshot['cpu_high_pause_events_per_slot_hour'], 3)}** "
            f"events/slot-hour | {snapshot['configured_slots']} configured slots |"
        ),
        (
            f"| Slot utilization | **{_fmt(snapshot['slot_utilization'] * 100.0, 2)}%** | "
            f"{_fmt(snapshot['occupied_terminal_hours'], 3)} / "
            f"{_fmt(snapshot['available_slot_hours'], 3)} terminal-hours |"
        ),
        "",
        "`disposition_only` is excluded only from execution throughput and wall-time "
        "samples. Occupancy includes every terminal-bound claim because it consumed a slot.",
        "",
        "## Median wall time by Q phase",
        "",
        "| Q phase | Median minutes | n | Execution verdicts |",
        "|---|---:|---:|---:|",
    ]
    phases = sorted(
        set(snapshot["median_wall_minutes_by_phase"])
        | set(snapshot["execution_by_phase"])
    )
    if phases:
        for phase in phases:
            wall = snapshot["median_wall_minutes_by_phase"].get(
                phase, {"median": None, "sample_count": 0}
            )
            lines.append(
                f"| {phase} | {_fmt(wall['median'], 3)} | {wall['sample_count']} | "
                f"{snapshot['execution_by_phase'].get(phase, 0)} |"
            )
    else:
        lines.append("| — | n/a | 0 | 0 |")
    measurement_wall = snapshot["measurement_pool_wall_minutes"]
    lines.extend(
        [
            "",
            (
                "The separate non-gate measurement pool had median cell wall time "
                f"**{_fmt(measurement_wall['median'], 3)} min** "
                f"(n={measurement_wall['sample_count']}). It is not presented as a "
                "pipeline phase; operator-facing phase labels above remain Q-only."
            ),
            "",
            "## Occupancy by terminal",
            "",
            "| Terminal | Occupied hours | Window utilization | CPU-high pauses |",
            "|---|---:|---:|---:|",
        ]
    )
    for terminal, hours in snapshot["occupied_hours_by_terminal"].items():
        pct = 100.0 * float(hours) / float(snapshot["window_hours"])
        lines.append(
            f"| {terminal} | {_fmt(hours, 3)} | {_fmt(pct, 2)}% | "
            f"{snapshot['cpu_high_pause_by_terminal'].get(terminal, 0)} |"
        )
    lines.extend(
        [
            "",
            "## Queue-mix anchor for a later matched window",
            "",
            "| Q phase | Pending | Active |",
            "|---|---:|---:|",
        ]
    )
    for phase, states in snapshot["queue_by_phase"].items():
        lines.append(f"| {phase} | {states['pending']} | {states['active']} |")
    mq = snapshot["measurement_pool_queue"]
    lines.extend(
        [
            "",
            (
                "Separate non-gate measurement pool: "
                f"{mq['pending']} pending, {mq['active']} active. "
                f"Other non-gate work: {snapshot['other_non_gate_queue']['pending']} pending, "
                f"{snapshot['other_non_gate_queue']['active']} active."
            ),
            "",
            "## Phase-2 switch checklist — not executed",
            "",
            "1. Obtain explicit review/authorization for a separate eight-worker A/B step "
            "and preregister the comparison threshold before seeing its result.",
            "2. Match the 24-hour candidate window to the baseline queue mix, data contract, "
            "and metric code/commit; record material mix differences as confounders.",
            "3. Select two factory terminals only after both have no active work item. Never "
            "interrupt a backtest and never include T_Live.",
            "4. Write those two terminal names, one per line, only to the governed "
            "`D:/QM/strategy_farm/state/disabled_terminals.txt` file. The present file "
            f"snapshot is `{disabled['sha256']}` ({disabled['bytes']} bytes).",
            "5. Critical implementation check: the file filters future spawns but a resident "
            "worker does not read it inside its claim loop. Therefore do not start the "
            "candidate clock until both selected daemons have exited through an authorized, "
            "non-interrupting lifecycle path and probes show exactly eight enabled daemons.",
            "6. Run this same read-only harness for an exact 24 hours as `CANDIDATE_8`; "
            "compare execution verdicts/day, MEASURED cells/hour, CPU-high pause density, "
            "Q-phase medians, utilization, and queue mix. Pipeline verdicts remain untouched.",
            "7. Rollback is exactly an empty `disabled_terminals.txt` (zero bytes; SHA-256 "
            "`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`). "
            "Let the governed spawner restore eligible workers; never start `terminal64.exe` manually.",
            "",
            "## Measurement caveats",
            "",
            f"- Timestamped worker-log coverage: **{coverage}**. A partial window makes the "
            "CPU-high pause result a lower bound and invalidates a strict A/B comparison.",
            f"- Rows skipped from wall-time because claim time was absent: "
            f"{snapshot['skipped_wall_no_claim']}.",
            f"- Rows skipped from utilization because claim/terminal binding was absent: "
            f"{snapshot['skipped_utilization_no_binding']}.",
            "- Utilization intervals are clipped to the window and merged per terminal, so "
            "retries/overlaps cannot produce more than 100% utilization for one terminal.",
            "",
        ]
    )
    return "\n".join(lines)


def _atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def write_outputs(
    snapshot: Mapping[str, Any],
    *,
    output_dir: Path,
    output_stem: str,
    label: str,
) -> tuple[Path, Path]:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = output_dir / f"{output_stem}.csv"
    report_path = output_dir / f"{output_stem}.md"
    fieldnames = [
        "window_label",
        "window_start_utc",
        "window_end_utc",
        "configured_slots",
        "metric",
        "dimension",
        "value",
        "unit",
        "sample_count",
        "note",
    ]
    temporary = csv_path.with_name(f".{csv_path.name}.{os.getpid()}.tmp")
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(metric_rows(snapshot, label))
    os.replace(temporary, csv_path)
    _atomic_write_text(report_path, render_report(snapshot, label))
    return csv_path, report_path


def _read_only_connection(path: Path) -> sqlite3.Connection:
    uri = Path(path).resolve().as_uri() + "?mode=ro"
    con = sqlite3.connect(uri, uri=True, timeout=30.0)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA query_only=ON")
    return con


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Measure a read-only terminal-concurrency A/B window."
    )
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--logs-dir", type=Path, default=DEFAULT_LOG_DIR)
    parser.add_argument(
        "--disabled-terminals-file", type=Path, default=DEFAULT_DISABLED_TERMINALS
    )
    parser.add_argument("--window-hours", type=float, default=DEFAULT_WINDOW_HOURS)
    parser.add_argument(
        "--window-end-utc",
        help="ISO-8601 end anchor; default is current UTC.",
    )
    parser.add_argument("--configured-slots", type=int, default=DEFAULT_CONFIGURED_SLOTS)
    parser.add_argument("--label", default="BASELINE_10")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--output-stem", default="v3_concurrency_baseline_10_workers")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    if args.window_hours <= 0:
        raise SystemExit("--window-hours must be > 0")
    if not 1 <= args.configured_slots <= 10:
        raise SystemExit("--configured-slots must be between 1 and 10")
    end = _parse_iso(args.window_end_utc) if args.window_end_utc else dt.datetime.now(dt.timezone.utc)
    if end is None:
        raise SystemExit("--window-end-utc is not valid ISO-8601")

    with _read_only_connection(args.db) as con:
        con.execute("BEGIN")
        snapshot = collect_db_metrics(
            con,
            window_end=end,
            window_hours=args.window_hours,
            configured_slots=args.configured_slots,
        )
        con.rollback()
    snapshot.update(
        collect_cpu_pause_metrics(
            args.logs_dir,
            window_end=end,
            window_hours=args.window_hours,
            configured_slots=args.configured_slots,
        )
    )
    snapshot["disabled_terminals_file"] = disabled_file_snapshot(
        args.disabled_terminals_file
    )
    csv_path, report_path = write_outputs(
        snapshot,
        output_dir=args.output_dir,
        output_stem=args.output_stem,
        label=args.label,
    )
    print(
        json.dumps(
            {
                "status": "BASELINE_MEASURED_NO_SWITCH",
                "csv": str(csv_path.resolve()),
                "report": str(report_path.resolve()),
                "execution_verdicts_per_day": snapshot["execution_verdicts_per_day"],
                "measured_cells_per_hour": snapshot["measured_cells_per_hour"],
                "cpu_high_pause_events_per_hour": snapshot["cpu_high_pause_events_per_hour"],
                "slot_utilization": snapshot["slot_utilization"],
                "coverage_complete": snapshot["coverage_complete"],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
