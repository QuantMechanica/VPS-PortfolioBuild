"""Produce immutable, loser-inclusive DSR cohorts for new Q08 work items.

The producer is deliberately fail closed.  It accepts only a sealed DL-089
ledger whose complete declared annual/numeric search can be reconstructed from
terminal matrix rows, plus readable Q02 and Q03 provenance.  Missing or pruned
trials are UNAVAILABLE; they are never represented by zeroes or a survivor-only
subset.
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import math
import os
import sqlite3
import statistics
import sys
import uuid
from pathlib import Path
from typing import Any, Mapping, Sequence


SCHEMA = "qm.dsr-cohort/v1"
DL089_LEDGER_SCHEMA = "qm.opt-census.v1"
DL089_DECLARED_TRIALS = 154
DL089_TERMINAL_STATES = {"PATTERN_SELECTION_READY", "WF_UNSTABLE", "READY_FOR_Q15"}
MEASURED_VERDICTS = {"MEASURED"}
DEFAULT_ARTIFACT_ROOT = Path(
    os.environ.get(
        "QM_DSR_COHORT_ROOT",
        r"D:\QM\strategy_farm\artifacts\dsr_cohorts",
    )
)
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_LEDGER_ROOT = Path(r"D:\QM\strategy_farm\artifacts\opt_census")


class CohortUnavailable(ValueError):
    """The governed history is not complete enough to apply DSR."""


def _require(condition: bool, reason: str) -> None:
    if not condition:
        raise CohortUnavailable(reason)


def _canonical(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False
    ).encode("utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _load_json(path: Path) -> dict[str, Any]:
    try:
        raw = gzip.open(path, "rb").read() if path.suffix.lower() == ".gz" else path.read_bytes()
        value = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CohortUnavailable(f"UNREADABLE_JSON:{path}") from exc
    _require(isinstance(value, dict), f"JSON_OBJECT_REQUIRED:{path}")
    return value


def _payload(row: Mapping[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(str(row.get("payload_json") or "{}"))
    except (TypeError, json.JSONDecodeError) as exc:
        raise CohortUnavailable(f"INVALID_PAYLOAD_JSON:{row.get('id')}") from exc
    _require(isinstance(value, dict), f"PAYLOAD_OBJECT_REQUIRED:{row.get('id')}")
    return value


def _row_dict(row: Any) -> dict[str, Any]:
    return dict(row) if not isinstance(row, dict) else dict(row)


def _timeframe(candidate: Mapping[str, Any], payload: Mapping[str, Any]) -> str:
    for key in ("expected_period", "host_timeframe", "timeframe", "period"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip().upper()
    setfile = Path(str(candidate.get("setfile_path") or "")).stem.upper()
    for token in ("M5", "M15", "M30", "H1", "H2", "H4", "H6", "D1"):
        if f"_{token}_" in f"_{setfile}_":
            return token
    raise CohortUnavailable("CANDIDATE_TIMEFRAME_UNAVAILABLE")


def _date_text(value: Any) -> str:
    raw = str(value or "").strip()
    for fmt in ("%Y.%m.%d", "%Y-%m-%d"):
        try:
            return dt.datetime.strptime(raw, fmt).date().isoformat()
        except ValueError:
            pass
    raise CohortUnavailable("CANDIDATE_WINDOW_UNAVAILABLE")


def _utc_timestamp(value: Any, reason: str) -> dt.datetime:
    raw = str(value or "").strip()
    try:
        parsed = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError as exc:
        raise CohortUnavailable(reason) from exc
    _require(parsed.tzinfo is not None, reason)
    return parsed.astimezone(dt.UTC)


def _factory_search_before_q08_claim(
    conn: sqlite3.Connection,
    candidate: Mapping[str, Any],
    payload: Mapping[str, Any],
) -> dict[str, Any]:
    """Prove that no governed optimization row predates this Q08 claim."""
    _require(str(candidate.get("phase") or "").upper() == "Q08", "Q08_CLAIM_ROW_REQUIRED")
    q08_id = str(candidate.get("id") or "").strip()
    _require(bool(q08_id), "Q08_WORK_ITEM_ID_REQUIRED")
    claimed_at = _utc_timestamp(payload.get("claimed_at_iso"), "Q08_CLAIM_TIMESTAMP_REQUIRED")
    rows = conn.execute(
        "SELECT id,kind,phase,created_at,payload_json FROM work_items "
        "WHERE ea_id=? AND id<>? ORDER BY created_at,id",
        (str(candidate.get("ea_id") or ""), q08_id),
    ).fetchall()
    prior = []
    optimization = []
    for raw in rows:
        row = _row_dict(raw)
        created_at = _utc_timestamp(
            row.get("created_at"), f"FACTORY_SEARCH_LEDGER_TIMESTAMP_INVALID:{row.get('id')}"
        )
        if created_at >= claimed_at:
            continue
        prior.append(row)
        phase = str(row.get("phase") or "").upper()
        searchable = " ".join(
            str(row.get(key) or "") for key in ("kind", "phase", "payload_json")
        ).lower().replace("-", "_").replace(" ", "_")
        if (
            phase.startswith("OPT_")
            or phase in {"Q12", "Q13", "Q14", "Q15", "Q16"}
            or any(marker in searchable for marker in (
                "optimization_fork", "optimisation_fork", "opt_fork"
            ))
        ):
            optimization.append({
                "id": str(row.get("id") or ""),
                "phase": str(row.get("phase") or ""),
                "created_at": created_at.isoformat(),
            })
    _require(not optimization, "FACTORY_SEARCH_LEDGER_PRECEDES_Q08")
    return {
        "schema": "qm.factory-search-before-q08-claim/v1",
        "complete": True,
        "q08_work_item_id": q08_id,
        "q08_claimed_at_utc": claimed_at.isoformat(),
        "work_items_examined": len(prior),
        "optimization_rows": [],
    }


def _binding(path: Path, *, role: str, row_id: str | None = None) -> dict[str, Any]:
    _require(path.is_file(), f"{role.upper()}_MISSING:{path}")
    result = {"role": role, "path": str(path.resolve()), "sha256": sha256_file(path)}
    if row_id:
        result["work_item_id"] = row_id
    return result


def _source_rows(
    conn: sqlite3.Connection,
    *,
    phase: str,
    ea_id: str,
    symbol: str,
    timeframe: str,
) -> list[dict[str, Any]]:
    rows = conn.execute(
        "SELECT * FROM work_items WHERE ea_id=? AND symbol=? AND phase=? "
        "AND status='done' AND evidence_path IS NOT NULL "
        "ORDER BY julianday(updated_at) DESC, updated_at DESC, id DESC",
        (ea_id, symbol, phase),
    ).fetchall()
    accepted: dict[str, dict[str, Any]] = {}
    for raw in rows:
        row = _row_dict(raw)
        payload = _payload(row)
        observed = str(
            payload.get("expected_period")
            or payload.get("host_timeframe")
            or payload.get("timeframe")
            or ""
        ).upper()
        path = Path(str(row.get("evidence_path") or ""))
        if observed == timeframe and path.is_file():
            # Parse as well as hash: a corrupt but present file is not provenance.
            _load_json(path)
            set_sha = str(
                row.get("setfile_sha256")
                or (payload.get("artifact_identity") or {}).get("setfile_sha256")
                or payload.get("expected_setfile_sha256")
                or ""
            ).lower()
            _require(len(set_sha) == 64, f"{phase}_SETFILE_IDENTITY_UNAVAILABLE:{row['id']}")
            if set_sha not in accepted:
                accepted[set_sha] = row
    _require(bool(accepted), f"{phase}_GOVERNED_SOURCE_UNAVAILABLE")
    # Q02 is the baseline, not every historical rerun.  Q03 may contain many
    # governed parameter configurations and must retain losers as well as the
    # winning/default configuration.
    selected = list(accepted.values()) if phase == "Q03" else [next(iter(accepted.values()))]
    return selected


def _source_binding(row: Mapping[str, Any], role: str) -> dict[str, Any]:
    path = Path(str(row.get("evidence_path") or ""))
    return {
        **_binding(path, role=role, row_id=str(row["id"])),
        "verdict": row.get("verdict"),
        "setfile_path": row.get("setfile_path"),
    }


def _source_by_id(
    conn: sqlite3.Connection, row_id: str, *, phase: str, timeframe: str
) -> dict[str, Any]:
    raw = conn.execute("SELECT * FROM work_items WHERE id=?", (row_id,)).fetchone()
    _require(raw is not None, f"{phase}_GOVERNED_SOURCE_UNAVAILABLE")
    row = _row_dict(raw)
    payload = _payload(row)
    observed = str(
        payload.get("expected_period")
        or payload.get("host_timeframe")
        or payload.get("timeframe")
        or ""
    ).upper()
    _require(str(row.get("phase") or "").upper() == phase
             and str(row.get("status") or "").lower() == "done"
             and observed == timeframe, f"{phase}_GOVERNED_SOURCE_UNAVAILABLE")
    path = Path(str(row.get("evidence_path") or ""))
    _load_json(path)
    set_sha = str(
        row.get("setfile_sha256")
        or (payload.get("artifact_identity") or {}).get("setfile_sha256")
        or payload.get("expected_setfile_sha256")
        or ""
    ).lower()
    _require(len(set_sha) == 64, f"{phase}_SETFILE_IDENTITY_UNAVAILABLE:{row_id}")
    return row


def _pipeline_peer_metric(row: Mapping[str, Any], trial_id: str, trial_index: int) -> dict[str, Any]:
    summary_path = Path(str(row.get("evidence_path") or ""))
    summary = _load_json(summary_path)
    ok = [run for run in summary.get("runs", []) if run.get("status") == "OK"]
    _require(bool(ok), f"PIPELINE_TRIAL_HAS_NO_OK_RUN:{row.get('id')}")
    run = ok[-1]
    report_path = Path(str(run.get("report_canonical_path") or ""))
    report_binding = _binding(report_path, role="native_report")
    expected = str(run.get("report_sha256") or "").lower()
    _require(not expected or expected == report_binding["sha256"],
             f"REPORT_SHA256_MISMATCH:{trial_id}")
    start = dt.datetime.strptime(str(run.get("from_date") or summary.get("from_date")), "%Y.%m.%d").date()
    end = dt.datetime.strptime(str(run.get("to_date") or summary.get("to_date")), "%Y.%m.%d").date()
    values = [0.0] * ((end - start).days + 1)
    total = int(run.get("total_trades") or 0)
    if total:
        trades, native = _closed_trades(report_path)
        _require(int(native.get("total_trades") or 0) == len(trades) == total,
                 f"TRADE_RECONCILIATION_FAILED:{trial_id}")
        for trade in trades:
            day = trade.exit_time.date()
            _require(start <= day <= end, f"TRADE_OUTSIDE_TRIAL_WINDOW:{trial_id}")
            values[(day - start).days] += float(trade.net)
    mean, sd = statistics.fmean(values), statistics.stdev(values)
    return {
        "trial_index": trial_index, "trial_id": trial_id, "role": "research",
        "frequency": "CALENDAR_DAY", "return_unit": "NET_CASH",
        "n_calendar_days": len(values), "net_return_input": math.fsum(values),
        "sharpe_daily": 0.0 if sd == 0 else mean / sd,
        "series_sha256": hashlib.sha256(_canonical(values)).hexdigest(),
        "provenance": [
            _binding(summary_path, role=str(row.get("phase") or "").lower(), row_id=str(row["id"])),
            report_binding,
        ],
    }


def _find_ledger(
    *, ea_id: str, symbol: str, timeframe: str, ledger_root: Path
) -> tuple[Path, dict[str, Any]]:
    matches: list[tuple[Path, dict[str, Any]]] = []
    for path in sorted(ledger_root.glob("*/ledger.json")):
        try:
            ledger = _load_json(path)
        except CohortUnavailable:
            continue
        subject = str(ledger.get("subject_ea_id") or ledger.get("ea_id") or "").upper()
        if (
            subject == ea_id.upper()
            and str(ledger.get("symbol") or "").upper() == symbol.upper()
            and str(ledger.get("timeframe") or "").upper() == timeframe
        ):
            matches.append((path, ledger))
    _require(bool(matches), "SEALED_SEARCH_LEDGER_UNAVAILABLE")
    _require(len(matches) == 1, "AMBIGUOUS_SEARCH_LEDGER")
    return matches[0]


def _current_matrix_rows(
    conn: sqlite3.Connection, program_id: str
) -> dict[str, dict[str, Any]]:
    rows = conn.execute(
        "SELECT * FROM work_items WHERE phase='OPT_CENSUS' "
        "AND json_valid(payload_json) "
        "AND json_extract(payload_json,'$.program_id')=? "
        "ORDER BY julianday(updated_at) DESC, updated_at DESC, id DESC",
        (program_id,),
    ).fetchall()
    current: dict[str, dict[str, Any]] = {}
    for raw in rows:
        row = _row_dict(raw)
        key = str(_payload(row).get("cell_key") or "")
        if key and key not in current:
            current[key] = row
    return current


def _closed_trades(report: Path) -> tuple[list[Any], dict[str, Any]]:
    try:
        from framework.scripts.q10_recency import extract_closed_trades
    except ModuleNotFoundError:
        sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
        from framework.scripts.q10_recency import extract_closed_trades
    return extract_closed_trades(report)


def _peer_metric(
    trial_id: str,
    trial_index: int,
    rows: Sequence[dict[str, Any]],
    *,
    role: str,
) -> dict[str, Any]:
    returns: list[float] = []
    provenance: list[dict[str, Any]] = []
    for row in sorted(rows, key=lambda value: int(_payload(value).get("year") or 0)):
        payload = _payload(row)
        _require(str(row.get("status") or "").lower() == "done", f"INCOMPLETE_TRIAL:{trial_id}")
        _require(str(row.get("verdict") or "").upper() in MEASURED_VERDICTS,
                 f"UNMEASURED_OR_PRUNED_TRIAL:{trial_id}")
        summary_path = Path(str(row.get("evidence_path") or ""))
        summary = _load_json(summary_path)
        ok = [run for run in summary.get("runs", []) if run.get("status") == "OK"]
        _require(len(ok) == 1, f"EXACTLY_ONE_OK_RUN_REQUIRED:{trial_id}")
        run = ok[0]
        report_path = Path(str(run.get("report_canonical_path") or ""))
        report_binding = _binding(report_path, role="native_report")
        expected_report_sha = str(run.get("report_sha256") or "").lower()
        _require(not expected_report_sha or expected_report_sha == report_binding["sha256"],
                 f"REPORT_SHA256_MISMATCH:{trial_id}")
        start = dt.datetime.strptime(str(payload.get("from_date")), "%Y.%m.%d").date()
        end = dt.datetime.strptime(str(payload.get("to_date")), "%Y.%m.%d").date()
        values = [0.0] * ((end - start).days + 1)
        total_trades = int(run.get("total_trades") or 0)
        if total_trades:
            trades, native = _closed_trades(report_path)
            _require(int(native.get("total_trades") or 0) == len(trades) == total_trades,
                     f"TRADE_RECONCILIATION_FAILED:{trial_id}")
            for trade in trades:
                day = trade.exit_time.date()
                _require(start <= day <= end, f"TRADE_OUTSIDE_TRIAL_WINDOW:{trial_id}")
                values[(day - start).days] += float(trade.net)
        returns.extend(values)
        provenance.extend([
            _binding(summary_path, role="matrix_summary", row_id=str(row["id"])),
            report_binding,
        ])
    _require(len(returns) >= 2, f"TRIAL_RETURN_SERIES_TOO_SHORT:{trial_id}")
    mean = statistics.fmean(returns)
    sd = statistics.stdev(returns)
    sharpe = 0.0 if sd == 0 else mean / sd
    _require(math.isfinite(sharpe), f"NONFINITE_SHARPE:{trial_id}")
    return {
        "trial_index": trial_index,
        "trial_id": trial_id,
        "role": role,
        "frequency": "CALENDAR_DAY",
        "return_unit": "NET_CASH",
        "n_calendar_days": len(returns),
        "net_return_input": math.fsum(returns),
        "sharpe_daily": sharpe,
        "series_sha256": hashlib.sha256(_canonical(returns)).hexdigest(),
        "provenance": provenance,
    }


def _matrix_trial_groups(
    ledger: Mapping[str, Any], current: Mapping[str, dict[str, Any]]
) -> list[tuple[str, str, list[dict[str, Any]]]]:
    years = [int(value) for value in ledger.get("years") or []]
    _require(bool(years), "LEDGER_YEARS_UNAVAILABLE")
    by_arm: dict[str, list[dict[str, Any]]] = {}
    for cell in ledger.get("cells") or []:
        arm = str(cell.get("arm") or "")
        if not arm or arm == "baseline":
            continue
        row = current.get(str(cell.get("cell_key") or ""))
        _require(row is not None, f"MATRIX_CELL_MISSING:{cell.get('cell_key')}")
        by_arm.setdefault(arm, []).append(row)
    declared = int(ledger.get("declared_trial_count") or 0)
    _require(declared == DL089_DECLARED_TRIALS, "DL089_DECLARED_TRIAL_COUNT_MISMATCH")
    _require(len(by_arm) == declared, "DL089_DECLARED_TRIAL_COVERAGE_MISMATCH")
    for arm, rows in by_arm.items():
        observed_years = sorted(int(_payload(row).get("year") or 0) for row in rows)
        _require(observed_years == years, f"ANNUAL_HISTORY_INCOMPLETE:{arm}")

    groups = [(f"DL089:PATTERN:{arm}", "selection", by_arm[arm]) for arm in sorted(by_arm)]
    driver = ledger.get("driver") or {}
    numeric = driver.get("numeric") or {}
    increment = int(numeric.get("numeric_trial_increment") or 0)
    if increment:
        expected: set[tuple[str, str]] = set()
        for param in numeric.get("parameters") or []:
            parent = param.get("parent_value")
            for value in param.get("candidate_values") or []:
                if value != parent:
                    expected.add((str(param.get("name")), str(value)))
        _require(len(expected) == increment, "NUMERIC_DECLARATION_COUNT_MISMATCH")
        numeric_groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
        for run in numeric.get("runs") or []:
            if run.get("role") != "numeric":
                continue
            key = (str(run.get("param")), str(run.get("value")))
            row = current.get(str(run.get("cell_key") or ""))
            _require(row is not None, f"NUMERIC_CELL_MISSING:{run.get('cell_key')}")
            numeric_groups.setdefault(key, []).append(row)
        _require(set(numeric_groups) == expected, "NUMERIC_HISTORY_COVERAGE_MISMATCH")
        for key in sorted(expected):
            rows = numeric_groups[key]
            observed_years = sorted(int(_payload(row).get("year") or 0) for row in rows)
            _require(observed_years == years, f"NUMERIC_ANNUAL_HISTORY_INCOMPLETE:{key}")
            groups.append((f"DL089:NUMERIC:{key[0]}={key[1]}", "selection", rows))
    effective = int(ledger.get("declared_trial_count_effective") or declared + increment)
    _require(effective == declared + increment == len(groups), "EFFECTIVE_TRIAL_COUNT_MISMATCH")
    return groups


def assemble(
    conn: sqlite3.Connection,
    candidate_row: Mapping[str, Any],
    candidate_payload: Mapping[str, Any],
    *,
    ledger_root: Path = DEFAULT_LEDGER_ROOT,
) -> dict[str, Any]:
    candidate = _row_dict(candidate_row)
    ea_id = str(candidate.get("ea_id") or "")
    symbol = str(candidate.get("symbol") or "")
    _require(bool(ea_id and symbol), "CANDIDATE_IDENTITY_UNAVAILABLE")
    timeframe = _timeframe(candidate, candidate_payload)
    window = {
        "from": _date_text(
            candidate_payload.get("from_date")
            or candidate_payload.get("expected_from_date")
            or candidate.get("data_window_start")
        ),
        "to": _date_text(
            candidate_payload.get("to_date")
            or candidate_payload.get("expected_to_date")
            or candidate.get("data_window_end")
        ),
    }
    try:
        ledger_path, ledger = _find_ledger(
            ea_id=ea_id, symbol=symbol, timeframe=timeframe, ledger_root=Path(ledger_root)
        )
    except CohortUnavailable as exc:
        if str(exc) != 'SEALED_SEARCH_LEDGER_UNAVAILABLE':
            raise
        return assemble_single_configuration(
            conn, candidate, candidate_payload, timeframe, window
        )
    _require(ledger.get("schema") == DL089_LEDGER_SCHEMA, "UNSUPPORTED_SEARCH_LEDGER_SCHEMA")
    _require(ledger.get("authority") == "DL-089", "SEARCH_LEDGER_AUTHORITY_MISMATCH")
    _require(str((ledger.get("driver") or {}).get("state") or "") in DL089_TERMINAL_STATES,
             "DL089_SEARCH_HISTORY_NOT_TERMINAL")
    _require(isinstance(ledger.get("sealed_rule_sha256"), str)
             and len(str(ledger["sealed_rule_sha256"])) == 64, "SEALED_RULE_HASH_UNAVAILABLE")
    q02_precondition_id = str((ledger.get("q02_precondition") or {}).get("id") or "")
    q02_rows = (
        [_source_by_id(conn, q02_precondition_id, phase="Q02", timeframe=timeframe)]
        if q02_precondition_id
        else _source_rows(conn, phase="Q02", ea_id=ea_id, symbol=symbol, timeframe=timeframe)
    )
    q03_rows = _source_rows(conn, phase="Q03", ea_id=ea_id, symbol=symbol, timeframe=timeframe)
    q12_id = str(ledger.get("q12_work_item_id") or "")
    q12 = conn.execute("SELECT * FROM work_items WHERE id=?", (q12_id,)).fetchone()
    _require(q12 is not None, "MATRIX_SERVICE_RECEIPT_ROW_UNAVAILABLE")
    q12_row = _row_dict(q12)
    _require(str(q12_row.get("status") or "").lower() == "done", "MATRIX_SERVICE_NOT_COMPLETE")
    q12_binding = _binding(
        Path(str(q12_row.get("evidence_path") or "")), role="matrix_service_receipt",
        row_id=q12_id,
    )
    current = _current_matrix_rows(conn, str(ledger.get("program_id") or ""))
    groups = _matrix_trial_groups(ledger, current)
    selection_peers = [
        _peer_metric(trial_id, index, rows, role=role)
        for index, (trial_id, role, rows) in enumerate(groups)
    ]
    research_rows: dict[str, dict[str, Any]] = {}
    for row in [*q02_rows, *q03_rows]:
        row_payload = _payload(row)
        set_sha = str(
            row.get("setfile_sha256")
            or (row_payload.get("artifact_identity") or {}).get("setfile_sha256")
            or row_payload.get("expected_setfile_sha256")
        ).lower()
        research_rows.setdefault(set_sha, row)
    research_peers = [
        _pipeline_peer_metric(row, f"PIPELINE:{set_sha}", len(selection_peers) + index)
        for index, (set_sha, row) in enumerate(sorted(research_rows.items()))
    ]
    peers = selection_peers + research_peers
    sharpes = [float(peer["sharpe_daily"]) for peer in peers]
    _require(len(sharpes) >= 2, "COHORT_DISPERSION_UNAVAILABLE")
    cohort_std = statistics.stdev(sharpes)
    _require(cohort_std > 0 and math.isfinite(cohort_std), "COHORT_DISPERSION_UNAVAILABLE")
    return {
        "schema": SCHEMA,
        "sealed": True,
        "complete": True,
        "losers_included": True,
        # Deterministic source timestamp: repeated enqueue attempts seal to the
        # same content hash instead of manufacturing time-dependent cohorts.
        "created_at_utc": str(q12_row.get("updated_at") or ledger.get("created_at_utc") or ""),
        "candidate": {"ea_id": ea_id, "symbol": symbol, "timeframe": timeframe},
        "window": window,
        "timezone": "UTC",
        "initial_balance": float(candidate_payload.get("tester_deposit") or 100000.0),
        "frequency": "CALENDAR_DAY",
        "costs_attested": True,
        "selection_mode": "DL089_V3",
        "declared_trial_count": int(ledger["declared_trial_count"]),
        "selection_trial_count": len(selection_peers),
        "research_trial_count": len(research_peers),
        "effective_trial_count": len(peers),
        "cohort_std_daily": cohort_std,
        "trial_ids": [peer["trial_id"] for peer in peers],
        "peers": peers,
        "search_history": {
            "complete": True,
            "unit": "candidate_configuration",
            "annual_measurements_are_trials": False,
            "sources": [
                _binding(ledger_path, role="sealed_census_ledger"),
                q12_binding,
                *[_source_binding(row, "q02") for row in q02_rows],
                *[_source_binding(row, "q03") for row in q03_rows],
            ],
        },
    }


def assemble_single_configuration(conn, candidate, payload, timeframe, window):
    try:
        from . import dsr_single_configuration as single
    except ImportError:
        import dsr_single_configuration as single
    setfile = Path(str(candidate.get('setfile_path') or ''))
    ea_directory = setfile.parent.parent
    label = ea_directory.name
    paths = {'card': Path('D:/QM/strategy_farm/artifacts/cards_approved') / (label+'.md'),
             'spec': ea_directory/'SPEC.md', 'mq5': ea_directory/(label+'.mq5'),
             'ex5': ea_directory/(label+'.ex5'), 'setfile': setfile}
    try:
        # Check explicit search authority first; defaults and absent ledgers never imply n=1.
        single.declaration(paths['card'].read_bytes())
        provenance = {role: {'path': str(path.resolve()), 'sha256': sha256_file(path)} for role, path in paths.items()}
        identity = {role+'_sha256': candidate.get(role+'_sha256') or (payload.get('artifact_identity') or {}).get(role+'_sha256') or payload.get('expected_'+role+'_sha256') for role in ('mq5','ex5','setfile')}
        for role in ('mq5', 'ex5', 'setfile'):
            claims = [candidate.get(role+'_sha256'), (payload.get('artifact_identity') or {}).get(role+'_sha256'), payload.get('expected_'+role+'_sha256')]
            _require(all(value == identity[role+'_sha256'] for value in claims if value), 'CONFLICTING_BUILD_IDENTITY:'+role)
        candidate_id = {'ea_id': str(candidate['ea_id']), 'symbol': str(candidate['symbol']), 'timeframe': timeframe}
        single.validate(provenance, candidate_id, identity)
        factory_search_ledger = _factory_search_before_q08_claim(conn, candidate, payload)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise CohortUnavailable('SINGLE_CONFIGURATION_UNAVAILABLE:'+str(exc)) from exc
    return {'schema': single.SCHEMA, 'sealed': True, 'complete': True,
            'losers_included': True, 'losers': [], 'candidate': candidate_id,
            'window': window, 'timezone': 'UTC', 'initial_balance': float(payload.get('tester_deposit') or 100000),
            'frequency': 'CALENDAR_DAY', 'costs_attested': True,
            'selection_mode': 'DECLARED_SINGLE_CONFIGURATION', 'declared_trial_count': 1,
            'selection_trial_count': 1, 'research_trial_count': 0, 'effective_trial_count': 1,
            'cohort_std_daily': 0.0, 'build_identity': identity, 'provenance': provenance,
            'search_history': {'complete': True, 'unit': 'candidate_configuration',
                               'annual_measurements_are_trials': False,
                               'factory_search_ledger': factory_search_ledger}}


def seal(document: Mapping[str, Any], artifact_root: Path = DEFAULT_ARTIFACT_ROOT) -> dict[str, str]:
    raw = _canonical(document) + b"\n"
    digest = hashlib.sha256(raw).hexdigest()
    candidate = document["candidate"]
    slug = "_".join(
        str(candidate[key]).replace(".", "_").replace("/", "_")
        for key in ("ea_id", "symbol", "timeframe")
    )
    target = Path(artifact_root).resolve() / slug / f"{digest}.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        _require(target.read_bytes() == raw, "CONTENT_ADDRESS_COLLISION")
    else:
        temporary = target.with_name(f".{target.name}.{uuid.uuid4().hex}.tmp")
        try:
            with temporary.open("xb") as handle:
                handle.write(raw)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, target)
        finally:
            temporary.unlink(missing_ok=True)
    return {"path": str(target), "sha256": digest}


def produce(
    conn: sqlite3.Connection,
    candidate_row: Mapping[str, Any],
    candidate_payload: Mapping[str, Any],
    *,
    ledger_root: Path = DEFAULT_LEDGER_ROOT,
    artifact_root: Path = DEFAULT_ARTIFACT_ROOT,
) -> dict[str, str]:
    return seal(
        assemble(conn, candidate_row, candidate_payload, ledger_root=ledger_root),
        artifact_root=artifact_root,
    )


def attach(
    conn: sqlite3.Connection,
    candidate_row: Mapping[str, Any],
    payload: dict[str, Any],
    *,
    ledger_root: Path = DEFAULT_LEDGER_ROOT,
    artifact_root: Path = DEFAULT_ARTIFACT_ROOT,
) -> dict[str, Any]:
    """Attach only to a not-yet-inserted Q08 payload; never mutate a DB row."""
    payload.pop("dsr_context", None)
    try:
        binding = produce(
            conn, candidate_row, payload, ledger_root=ledger_root, artifact_root=artifact_root
        )
    except CohortUnavailable as exc:
        payload["dsr_context_status"] = {
            "status": "UNAVAILABLE", "reason": str(exc), "producer_schema": SCHEMA
        }
        return payload["dsr_context_status"]
    payload["dsr_context"] = binding
    payload["dsr_context_status"] = {"status": "SEALED", "producer_schema": SCHEMA}
    return payload["dsr_context_status"]


def replay(conn: sqlite3.Connection, *, limit: int = 3) -> dict[str, Any]:
    rows = conn.execute(
        "SELECT * FROM work_items WHERE phase='Q08' AND status='done' "
        "ORDER BY julianday(updated_at) DESC, updated_at DESC, id DESC LIMIT ?",
        (int(limit),),
    ).fetchall()
    result: list[dict[str, Any]] = []
    for raw in rows:
        row = _row_dict(raw)
        payload = _payload(row)
        # Historical Q08 rows predate identity columns on some paths.  The
        # immutable baseline summary is the authoritative replay fallback.
        if not (payload.get("from_date") and payload.get("to_date") and payload.get("expected_period")):
            try:
                aggregate = _load_json(Path(str(row.get("evidence_path") or "")))
                baseline = aggregate.get("baseline_run") or {}
                summary = _load_json(Path(str(baseline.get("baseline_summary_path") or "")))
                if not payload.get("from_date"):
                    payload["from_date"] = summary.get("from_date")
                if not payload.get("to_date"):
                    payload["to_date"] = summary.get("to_date")
                if not payload.get("expected_period"):
                    payload["expected_period"] = baseline.get("period") or summary.get("period")
            except CohortUnavailable:
                pass
        entry = {
            "work_item_id": row["id"], "ea_id": row["ea_id"], "symbol": row["symbol"],
            "stored_verdict": row.get("verdict"),
        }
        try:
            document = assemble(conn, row, payload)
            entry.update({
                "cohort_status": "AVAILABLE",
                "selection_trial_count": document["selection_trial_count"],
                "v2_outcome": "COMPUTABLE_ON_RERUN",
            })
        except CohortUnavailable as exc:
            entry.update({
                "cohort_status": "UNAVAILABLE", "reason": str(exc),
                "selection_trial_count": None, "v2_outcome": "UNCORRECTED_SELECTION",
            })
        result.append(entry)
    return {
        "schema": "qm.dsr-cohort-replay/v1",
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "read_only": True,
        "rows": result,
    }


def _main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("replay",))
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--limit", type=int, default=3)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    conn = sqlite3.connect(f"file:{args.db.resolve()}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    output = replay(conn, limit=args.limit)
    rendered = json.dumps(output, indent=2, sort_keys=True) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
