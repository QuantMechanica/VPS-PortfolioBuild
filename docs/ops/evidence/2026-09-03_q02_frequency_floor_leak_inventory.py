"""Read-only inventory of Q02 frequency-floor rows affected by the marker leak.

Context
-------
Until 2026-09-03 the Q02 frequency-floor evidence
(``qm.q02-frequency-coverage/v1``) text-scanned the MetaTester day-log for
``QM_PATTERN_FIRST_TRADABLE_BAR`` and adopted any marker it found. The day-log
is a SHARED terminal artifact, so two fail-open leaks were possible:

* **cross-EA** - a marker printed by a different expert on a different symbol
  (e.g. work item ``95e706ea-...``: QM5_41321 / NDX.DWX adopted QM5_41195 /
  XAGUSD.DWX, coverage start 2021.01.01 -> 2022.01.12, floor 10 -> 5);
* **cross-RUN** - a marker printed by an EARLIER RUN of the same EA on the same
  symbol with a different (usually 1-year DL089 census) window.

Both shorten the scored window and therefore understate the ``>= 5 trades/yr``
Q02 floor. ``framework/scripts/pattern_warmup_evidence.ps1`` now attributes
markers per RUN (schema ``qm.q02-frequency-coverage/v2``, contract
``docs/ops/evidence/2026-08-21_bug4_pattern_warmup_contract.md`` section B4-5).
That repair applies to FUTURE runs only.

What this script does
---------------------
Enumerates every ``summary.json`` under ``D:\\QM\\reports\\work_items`` from
2026-08-01 onward and reports the rows whose recorded floor is, or may be,
built on a marker the new rule rejects:

* ``foreign_symbol_marker``  - the recorded ``first_tradable_bar.symbol``
  differs from the run symbol (provable from the summary alone);
* ``rejected_under_new_rule`` - the retained run artifacts were re-parsed with
  a faithful Python mirror of the new rule and the marker is not attributable
  to this run (or resolves to a later coverage start);
* ``unverifiable_tester_log_marker`` - the run used a tester-log marker but the
  day-log it quoted has since been purged (D: retention), so the recheck cannot
  be performed and the row must be treated as potentially affected.

``recheck_status`` says how far the recheck got: ``recomputed`` (every declared
run artifact still on disk), ``recomputed_partial`` (the quoted artifact is
there, another run's day-log is not), ``source_artifact_purged`` /
``artifacts_not_retained`` (not decidable).

It writes ``2026-09-03_q02_frequency_floor_leak_inventory.csv`` next to itself
with ``floor_used`` vs ``floor_fail_closed`` and the live work-item verdict.

It is strictly READ-ONLY: the farm database is opened through a
``file:...?mode=ro`` URI and no row is written. Regrading Q02 verdicts is an
OWNER decision (ROT zone: "delete/overwrite verdicts or trade streams"), so
this script produces the decision input and nothing else.

Usage
-----
    python docs/ops/evidence/2026-09-03_q02_frequency_floor_leak_inventory.py
    python docs/ops/evidence/2026-09-03_q02_frequency_floor_leak_inventory.py \
        --since 2026-08-01 --out <path.csv>
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sqlite3
import sys
from contextlib import closing
from datetime import date, datetime
from pathlib import Path
from typing import Any, Iterable

WORK_ITEM_ROOT = Path(r"D:\QM\reports\work_items")
FARM_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_SINCE = "2026-08-01"
DEFAULT_OUT = Path(__file__).with_suffix(".csv")

TAB = "\t"

MARKER_RE = re.compile(
    r"QM_PATTERN_FIRST_TRADABLE_BAR\s+schema=qm\.pattern-first-tradable-bar/v1"
    r"\s+symbol=(?P<symbol>\S+)\s+reference_timeframe=(?P<tf>-?\d+)"
    r"\s+tradable_bar_date=(?P<date>\d{4}\.\d{2}\.\d{2})"
    r"\s+tradable_bar_time=(?P<tradable>-?\d+)"
    r"\s+reference_bar_time=(?P<reference>-?\d+)"
    r"\s+required_bars=(?P<required>\d+)\s+profile_key=(?P<profile>\S+)"
)
RUN_START_RE = re.compile(
    r"(?P<symbol>[^\s,\t]+),[^:\t]*:\s+testing of\s+Experts\\(?P<expert>\S+?)\.ex5"
    r"\s+from\s+(?P<from>\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}"
    r"\s+to\s+(?P<to>\d{4}\.\d{2}\.\d{2})\s+\d{2}:\d{2}\s+started with inputs",
    re.IGNORECASE,
)
SOURCE_EXPERT_RE = re.compile(r"^(?P<expert>.+?)\s+\((?P<symbol>[^,()]+),(?P<tf>[^,()]+)\)$")
SOURCE_CORE_RE = re.compile(r"^Core\s+\d+$", re.IGNORECASE)
CLOCK_RE = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\.(\d{3})$")

END_OF_LOG = 10**12  # milliseconds sentinel, larger than any wall clock


# --------------------------------------------------------------------------
# faithful Python mirror of pattern_warmup_evidence.ps1 (schema v2)
# --------------------------------------------------------------------------


def expert_leaf(value: str) -> str:
    leaf = (value or "").strip().strip('"').replace("/", "\\").split("\\")[-1].strip()
    if leaf.lower().endswith(".ex5"):
        leaf = leaf[:-4]
    return leaf


def expert_matches(leaf: str, expected_leaf: str, expected_ea_id: int) -> bool:
    if not leaf:
        return False
    name = leaf[:-4] if leaf.lower().endswith(".ex5") else leaf
    if expected_leaf and name.lower() == expected_leaf.lower():
        return True
    if expected_ea_id > 0 and re.match(rf"^QM5_0*{expected_ea_id}(?:_|$)", name, re.IGNORECASE):
        return True
    return False


def symbol_equals(left: str, right: str) -> bool:
    if not left or not right:
        return False
    return left.strip().lower() == right.strip().lower()


def parse_clock(line: str) -> int | None:
    fields = line.split(TAB)
    if len(fields) < 3:
        return None
    m = CLOCK_RE.match(fields[2].strip())
    if not m:
        return None
    h, mi, s, ms = (int(g) for g in m.groups())
    return ((h * 60 + mi) * 60 + s) * 1000 + ms


def read_log_lines(path: Path) -> list[str]:
    raw = path.read_bytes()
    if raw[:2] == b"\xff\xfe":
        text = raw.decode("utf-16-le", "replace")
    elif raw[:3] == b"\xef\xbb\xbf":
        text = raw[3:].decode("utf-8", "replace")
    else:
        text = raw.decode("utf-8", "replace")
    return text.splitlines()


def resolve_run_window(
    lines: Iterable[str],
    expected_leaf: str,
    expected_ea_id: int,
    run_symbol: str,
    from_date: str,
    to_date: str,
) -> dict[str, Any]:
    """Mirror of Resolve-QmTesterLogRunWindow."""
    if not (expected_leaf or expected_ea_id > 0) or not run_symbol:
        return {"resolved": False, "window_source": "unresolved_no_expected_run_identity",
                "start": 0, "end": END_OF_LOG, "exact": 0, "own": 0, "starts": 0}

    start: int | None = None
    end: int | None = None
    exact = own = starts = 0

    for line in lines:
        if "testing of Experts" in line:
            m = RUN_START_RE.search(line)
            if m:
                starts += 1
                clock = parse_clock(line)
                leaf = expert_leaf(m.group("expert"))
                is_own = expert_matches(leaf, expected_leaf, expected_ea_id) and symbol_equals(
                    m.group("symbol"), run_symbol
                )
                if is_own:
                    own += 1
                is_exact = (
                    is_own
                    and clock is not None
                    and m.group("from") == from_date
                    and m.group("to") == to_date
                )
                if is_exact:
                    exact += 1
                    start, end = clock, None
                    continue
                if start is not None and end is None and clock is not None:
                    end = clock
                continue
        if "expert file added:" in line.lower():
            if start is not None and end is None:
                clock = parse_clock(line)
                if clock is not None:
                    end = clock

    if start is not None:
        effective_end = END_OF_LOG if end is None or end < start else end
        return {"resolved": True, "window_source": "tester_log_run_start_exact",
                "start": start, "end": effective_end, "exact": exact, "own": own, "starts": starts}
    if starts == 0:
        return {"resolved": True, "window_source": "rollover_continuation_no_run_start",
                "start": 0, "end": END_OF_LOG, "exact": 0, "own": 0, "starts": 0}
    return {"resolved": False, "window_source": "unresolved_no_matching_run_start",
            "start": 0, "end": END_OF_LOG, "exact": 0, "own": own, "starts": starts}


def attribute(
    marker_symbol: str,
    host_symbol: str,
    identity_present: bool,
    identity_matched: bool,
    window_state: str,
    source_kind: str,
    run_symbol: str,
    has_identity_anchor: bool,
) -> tuple[bool, str]:
    """Mirror of Resolve-QmPatternMarkerAttribution."""
    if not has_identity_anchor or not run_symbol:
        return False, "no_expected_run_identity"
    if window_state == "unresolved":
        return False, "run_window_unresolved"
    if window_state == "no_timestamp":
        return False, "marker_line_without_timestamp"
    if window_state == "outside":
        return False, "outside_run_window"
    if source_kind == "tester_core":
        if symbol_equals(marker_symbol, run_symbol):
            return True, "core_source_window"
        return False, "foreign_symbol"
    if not identity_present:
        return False, "source_line_without_ea_identity"
    if not identity_matched:
        return False, "foreign_ea"
    if symbol_equals(marker_symbol, run_symbol):
        return True, "own_ea_run_symbol"
    if symbol_equals(host_symbol, run_symbol):
        return True, "own_ea_member_symbol"
    return False, "foreign_symbol"


def markers_from_tester_log(
    path: Path, expected_leaf: str, expected_ea_id: int, run_symbol: str,
    from_date: str, to_date: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    lines = read_log_lines(path)
    window = resolve_run_window(lines, expected_leaf, expected_ea_id, run_symbol, from_date, to_date)
    has_anchor = bool(expected_leaf) or expected_ea_id > 0
    out: list[dict[str, Any]] = []
    for line in lines:
        m = MARKER_RE.search(line)
        if not m:
            continue
        fields = line.split(TAB)
        marker_field = next(
            (i for i, f in enumerate(fields) if "QM_PATTERN_FIRST_TRADABLE_BAR" in f), -1
        )
        log_expert = host_symbol = ""
        source_kind = "missing"
        if marker_field > 0:
            source_text = fields[marker_field - 1].strip()
            sm = SOURCE_EXPERT_RE.match(source_text)
            if sm:
                log_expert = sm.group("expert").strip()
                host_symbol = sm.group("symbol").strip()
                source_kind = "expert_chart"
            elif SOURCE_CORE_RE.match(source_text):
                source_kind = "tester_core"
            else:
                source_kind = "unrecognized"
        clock = parse_clock(line)
        if not window["resolved"]:
            state = "unresolved"
        elif clock is None:
            state = "no_timestamp"
        elif window["start"] <= clock <= window["end"]:
            state = "inside"
        else:
            state = "outside"
        ok, reason = attribute(
            m.group("symbol"), host_symbol, bool(log_expert),
            bool(log_expert) and expert_matches(log_expert, expected_leaf, expected_ea_id),
            state, source_kind, run_symbol, has_anchor,
        )
        out.append({
            "date": m.group("date"), "symbol": m.group("symbol"),
            "profile_key": m.group("profile"), "source_path": str(path),
            "attributed": ok, "reason": reason,
        })
    return out, window


def markers_from_logger_sample(
    path: Path, expected_ea_id: int, run_symbol: str, has_anchor: bool
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if "PATTERN_FIRST_TRADABLE_BAR" not in line:
                continue
            try:
                row = json.loads(line)
            except Exception:
                continue
            if row.get("event") != "PATTERN_FIRST_TRADABLE_BAR":
                continue
            payload = row.get("payload") or {}
            if payload.get("marker_schema") != "qm.pattern-first-tradable-bar/v1":
                continue
            ea_id = row.get("ea_id")
            magic = row.get("magic")
            identity_present = bool(ea_id) or bool(magic)
            identity_matched = False
            if expected_ea_id > 0:
                if isinstance(ea_id, int) and ea_id == expected_ea_id:
                    identity_matched = True
                elif isinstance(magic, int) and magic > 0 and magic // 10000 == expected_ea_id:
                    identity_matched = True
            ok, reason = attribute(
                str(payload.get("symbol") or ""), str(row.get("symbol") or ""),
                identity_present, identity_matched,
                "run_scoped_capture", "run_scoped_capture", run_symbol, has_anchor,
            )
            out.append({
                "date": str(payload.get("tradable_bar_date") or ""),
                "symbol": str(payload.get("symbol") or ""),
                "profile_key": str(payload.get("profile_key") or ""),
                "source_path": str(path), "attributed": ok, "reason": reason,
            })
    return out


# --------------------------------------------------------------------------
# summary walk
# --------------------------------------------------------------------------


def parse_qm_date(value: str) -> date | None:
    try:
        return datetime.strptime(value, "%Y.%m.%d").date()
    except Exception:
        return None


def floor_for(rate: int, start: str, end: str) -> int | None:
    a, b = parse_qm_date(start), parse_qm_date(end)
    if not a or not b:
        return None
    years = max(1, b.year - a.year + 1)
    return max(rate, rate * years)


def summary_date(summary: dict[str, Any], path: Path) -> date | None:
    tag = str(summary.get("run_tag") or "")
    if len(tag) >= 8 and tag[:8].isdigit():
        try:
            return datetime.strptime(tag[:8], "%Y%m%d").date()
        except Exception:
            pass
    stamp = str(summary.get("timestamp_utc") or "")
    if stamp:
        try:
            return datetime.fromisoformat(stamp.replace("Z", "+00:00")).date()
        except Exception:
            pass
    try:
        return datetime.fromtimestamp(path.stat().st_mtime).date()
    except Exception:
        return None


def load_work_items(ids: set[str]) -> dict[str, dict[str, Any]]:
    """Read-only lookup of the live work_items rows."""
    if not ids or not FARM_DB.is_file():
        return {}
    # mode=ro: the connection physically cannot write, so even a bug here can
    # never touch live farm state.
    uri = f"file:{FARM_DB.as_posix()}?mode=ro"
    out: dict[str, dict[str, Any]] = {}
    with closing(sqlite3.connect(uri, uri=True)) as conn:
        conn.row_factory = sqlite3.Row
        ordered = sorted(ids)
        for i in range(0, len(ordered), 400):
            chunk = ordered[i : i + 400]
            placeholders = ",".join("?" * len(chunk))
            rows = conn.execute(
                "SELECT id, phase, status, verdict, verdict_taxonomy, ea_id, symbol, updated_at "
                f"FROM work_items WHERE id IN ({placeholders})",
                chunk,
            ).fetchall()
            for row in rows:
                out[row["id"]] = dict(row)
    return out


def evaluate_summary(summary_path: Path, summary: dict[str, Any]) -> dict[str, Any] | None:
    floor = summary.get("frequency_floor")
    if not isinstance(floor, dict):
        return None

    run_symbol = str(summary.get("symbol") or "")
    expert = str(summary.get("expert") or "")
    leaf = expert_leaf(expert)
    try:
        ea_id = int(summary.get("ea_id") or 0)
    except Exception:
        ea_id = 0
    from_date = str(summary.get("from_date") or "")
    to_date = str(summary.get("to_date") or "")
    rate = int(floor.get("rate_per_year") or 5)

    marker = floor.get("first_tradable_bar") or {}
    marker_symbol = str(marker.get("symbol") or "")
    marker_kind = str(marker.get("source_kind") or "")
    coverage_start_v1 = str(floor.get("coverage_start") or "")
    source_v1 = str(floor.get("coverage_start_source") or "")

    # `min_trades_required` is what the run actually applied; in SmokeMode
    # run_smoke overwrites it with the explicit -MinTrades value (often 0), so
    # the parser's own result lives in `calculated_min_trades_required`. Compare
    # against the calculated value, and keep `applied` visible: a floor that was
    # never applied cannot have decided a verdict.
    floor_calculated = floor.get("calculated_min_trades_required")
    floor_used = floor.get("min_trades_required")
    floor_applied = bool(floor.get("applied"))
    floor_parser = floor_calculated if isinstance(floor_calculated, int) else floor_used
    floor_fail_closed = floor_for(rate, from_date, to_date)

    runs = summary.get("runs") or []
    # Only OK legs carry a trade count that a Q02 verdict was ever built on; an
    # INVALID retry reports 0 and would fake a "verdict at risk".
    ok_trades = [
        r["total_trades"]
        for r in runs
        if r.get("status") == "OK" and isinstance(r.get("total_trades"), int)
    ]
    all_trades = [r["total_trades"] for r in runs if isinstance(r.get("total_trades"), int)]
    trades = ok_trades or all_trades
    min_trades = min(trades) if trades else None

    # -- recompute where the run artifacts still exist ---------------------
    # A recheck is only conclusive when the artifact the v1 result actually
    # QUOTED is still on disk. D: retention purges day-logs aggressively, and a
    # run whose logger_sample.jsonl survived while its day-log did not would
    # otherwise look like "marker rejected" when it is simply unverifiable.
    declared_logs = [Path(str(r["tester_log_path"])) for r in runs if r.get("tester_log_path")]
    tester_logs = [p for p in declared_logs if p.is_file()]
    run_dir = summary_path.parent
    logger_samples = [p for p in run_dir.glob("raw/run_*/logger_sample.jsonl") if p.is_file()]
    if not declared_logs:
        tester_logs = [p for p in run_dir.glob("raw/run_*/*.log") if p.is_file()]
    recorded_source = str(marker.get("source_path") or "")
    recorded_source_present = bool(recorded_source) and Path(recorded_source).is_file()
    all_declared_logs_present = len(tester_logs) == len(declared_logs)

    has_anchor = bool(leaf) or ea_id > 0
    recomputed: list[dict[str, Any]] = []
    windows: list[dict[str, Any]] = []
    for path in logger_samples:
        try:
            recomputed.extend(markers_from_logger_sample(path, ea_id, run_symbol, has_anchor))
        except Exception:
            pass
    for path in tester_logs:
        try:
            found, window = markers_from_tester_log(path, leaf, ea_id, run_symbol, from_date, to_date)
        except Exception:
            continue
        recomputed.extend(found)
        windows.append(window)

    conclusive = recorded_source_present or not recorded_source
    if conclusive and (logger_samples or tester_logs):
        attributed = [m for m in recomputed if m["attributed"]]
        per_file: dict[str, dict[str, Any]] = {}
        fb, fe = parse_qm_date(from_date), parse_qm_date(to_date)
        for m in attributed:
            d = parse_qm_date(m["date"])
            if not d or not fb or not fe or d < fb or d > fe:
                continue
            cur = per_file.get(m["source_path"])
            if cur is None or m["date"] > cur["date"]:
                per_file[m["source_path"]] = m
        dates = sorted({m["date"] for m in per_file.values()})
        if dates:
            coverage_start_new = dates[0]
            marker_status_new = (
                "present_consistent" if len(dates) == 1 else "present_conflict_conservative_earliest"
            )
            reason_new = next(
                (m["reason"] for m in per_file.values() if m["date"] == dates[0]), ""
            )
        else:
            coverage_start_new = from_date
            marker_status_new = "present_not_attributable" if recomputed else "absent"
            reasons = sorted({m["reason"] for m in recomputed if not m["attributed"]})
            reason_new = ";".join(reasons)
        recheck_status = "recomputed" if all_declared_logs_present else "recomputed_partial"
        floor_new = floor_for(rate, coverage_start_new, to_date)
    else:
        coverage_start_new = ""
        marker_status_new = ""
        reason_new = ""
        recheck_status = (
            "source_artifact_purged" if recorded_source else "artifacts_not_retained"
        )
        floor_new = None

    foreign_symbol = bool(marker_symbol) and not symbol_equals(marker_symbol, run_symbol)

    selection: list[str] = []
    if foreign_symbol:
        selection.append("foreign_symbol_marker")
    # "rejected under the new rule" means the marker the v1 scan used is not the
    # one the per-run rule accepts - i.e. the coverage start moves. Comparing
    # floors instead would mis-flag every SmokeMode row (applied floor 0).
    if recheck_status.startswith("recomputed") and coverage_start_new and coverage_start_v1:
        if coverage_start_new != coverage_start_v1:
            selection.append("rejected_under_new_rule")
    if (
        not recheck_status.startswith("recomputed")
        and source_v1 == "pattern_first_tradable_bar"
        and marker_kind == "tester_log"
        and not foreign_symbol
    ):
        selection.append("unverifiable_tester_log_marker")
    if not selection:
        return None

    # A verdict is only at risk where the floor was actually applied AND the run
    # cleared the recorded floor but would miss the corrected one.
    verdict_at_risk = ""
    effective_new = floor_new if floor_new is not None else floor_fail_closed
    if not floor_applied:
        verdict_at_risk = "n/a_floor_not_applied"
    elif min_trades is not None and effective_new is not None and floor_parser is not None:
        if int(min_trades) >= int(floor_parser) and int(min_trades) < int(effective_new):
            verdict_at_risk = "yes"
        else:
            verdict_at_risk = "no"

    try:
        rel = summary_path.relative_to(WORK_ITEM_ROOT).parts
    except ValueError:
        rel = summary_path.parts
    work_item_id = rel[0] if rel else ""
    # Everything between the work item id and the EA directory: "" for a plain
    # Q02 run, "q09_contract_v3/cells/<cell>/runs/<leg>" for a Q09 cell, etc.
    scope = "/".join(rel[1:-3]) if len(rel) > 4 else ""

    return {
        "work_item_id": work_item_id,
        "evidence_scope": scope,
        "ea_label": str(summary.get("ea_label") or ""),
        "ea_id": ea_id,
        "symbol": run_symbol,
        "run_tag": str(summary.get("run_tag") or ""),
        "result": str(summary.get("result") or ""),
        "from_date": from_date,
        "to_date": to_date,
        "rate_per_year": rate,
        "evidence_schema": str(floor.get("schema") or ""),
        "selection_reason": "|".join(selection),
        "recheck_status": recheck_status,
        "coverage_start_recorded": coverage_start_v1,
        "coverage_start_source_recorded": source_v1,
        "marker_symbol_recorded": marker_symbol,
        "marker_source_kind_recorded": marker_kind,
        "marker_profile_key_recorded": str(marker.get("profile_key") or ""),
        "coverage_start_recomputed": coverage_start_new,
        "marker_status_recomputed": marker_status_new,
        "attribution_reason_recomputed": reason_new,
        "run_window_sources": ";".join(sorted({w["window_source"] for w in windows})),
        "floor_used": floor_used,
        "floor_applied": floor_applied,
        "floor_calculated": floor_calculated,
        "floor_recomputed": floor_new if floor_new is not None else "",
        "floor_fail_closed": floor_fail_closed,
        "min_total_trades": min_trades if min_trades is not None else "",
        "q02_verdict_at_risk": verdict_at_risk,
        "summary_path": str(summary_path),
    }


FIELDS = [
    "work_item_id", "evidence_scope", "ea_label", "ea_id", "symbol", "run_tag", "result",
    "from_date", "to_date", "rate_per_year", "evidence_schema",
    "selection_reason", "recheck_status",
    "coverage_start_recorded", "coverage_start_source_recorded",
    "marker_symbol_recorded", "marker_source_kind_recorded",
    "marker_profile_key_recorded",
    "coverage_start_recomputed", "marker_status_recomputed",
    "attribution_reason_recomputed", "run_window_sources",
    "floor_used", "floor_applied", "floor_calculated", "floor_recomputed",
    "floor_fail_closed",
    "min_total_trades", "q02_verdict_at_risk",
    "wi_phase", "wi_status", "wi_verdict", "wi_verdict_taxonomy", "wi_updated_at",
    "summary_path",
]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--since", default=DEFAULT_SINCE, help="ISO date, default 2026-08-01")
    parser.add_argument("--root", default=str(WORK_ITEM_ROOT))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    args = parser.parse_args(argv)

    since = datetime.strptime(args.since, "%Y-%m-%d").date()
    root = Path(args.root)
    globals()["WORK_ITEM_ROOT"] = root
    if not root.is_dir():
        print(f"work-item root not found: {root}", file=sys.stderr)
        return 2

    scanned = 0
    with_floor = 0
    rows: list[dict[str, Any]] = []
    # summary.json sits at several depths under a work item: a plain Q02 run is
    # <wi>/<EA>/<run_tag>/, a Q09 contract-v3 cell is
    # <wi>/q09_contract_v3/cells/<cell>/runs/<leg>/<EA>/<run_tag>/, an
    # equivalence probe is <wi>/equivalence/{pre,post}/<EA>/<run_tag>/. Walk
    # them all - a fixed-depth glob silently drops ~30% of the evidence tree.
    for dirpath, _dirnames, filenames in os.walk(root):
        if "summary.json" not in filenames:
            continue
        summary_path = Path(dirpath) / "summary.json"
        try:
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        scanned += 1
        when = summary_date(summary, summary_path)
        if when is None or when < since:
            continue
        if not isinstance(summary.get("frequency_floor"), dict):
            continue
        with_floor += 1
        row = evaluate_summary(summary_path, summary)
        if row:
            rows.append(row)

    work_items = load_work_items({r["work_item_id"] for r in rows if r["work_item_id"]})
    for row in rows:
        wi = work_items.get(row["work_item_id"]) or {}
        row["wi_phase"] = wi.get("phase", "")
        row["wi_status"] = wi.get("status", "")
        row["wi_verdict"] = wi.get("verdict", "")
        row["wi_verdict_taxonomy"] = wi.get("verdict_taxonomy", "")
        row["wi_updated_at"] = wi.get("updated_at", "")

    rows.sort(key=lambda r: (r["selection_reason"], str(r["ea_label"]), str(r["run_tag"])))

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    breakdown: dict[str, int] = {}
    at_risk = 0
    for row in rows:
        breakdown[row["selection_reason"]] = breakdown.get(row["selection_reason"], 0) + 1
        if row["q02_verdict_at_risk"] == "yes":
            at_risk += 1
    print(f"summaries scanned      : {scanned}")
    print(f"with frequency_floor   : {with_floor} (since {since.isoformat()})")
    print(f"affected rows           : {len(rows)}")
    for key in sorted(breakdown):
        print(f"  {key:38s} {breakdown[key]}")
    print(f"Q02 verdict at risk     : {at_risk} (passed the recorded floor, below the fail-closed floor)")
    print(f"csv                     : {out_path}")
    print("NOTE: read-only. Regrading these rows is an OWNER decision.")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
