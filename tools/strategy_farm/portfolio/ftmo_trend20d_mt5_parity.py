"""Compare native MT5 entries for the locked WS30 trend-20d filter.

The comparator is read-only. It derives the expected target entries from every
baseline round trip with the frozen observed-M15 shift-1/shift-1921 oracle,
then matches native target entries by New York date, UTC M15 bucket, and side.
Profit, loss, exit price, and exit time never participate in selection.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter
from pathlib import Path
from typing import Any, Mapping, Sequence
from zoneinfo import ZoneInfo

import pandas as pd

try:
    from . import ftmo_bar_joint_book_sim as joint
    from . import ftmo_trend20d_entry_oracle as oracle
    from .ftmo_report_cost_reconcile import RoundTrip, extract_round_trips
except ImportError:  # pragma: no cover - direct script execution
    import ftmo_bar_joint_book_sim as joint  # type: ignore
    import ftmo_trend20d_entry_oracle as oracle  # type: ignore
    from ftmo_report_cost_reconcile import RoundTrip, extract_round_trips  # type: ignore


NEW_YORK = ZoneInfo("America/New_York")
NO_MONEY_PATTERN = re.compile(
    r"(?:TRADE_RETCODE_)?NO_MONEY|not\s+enough\s+money|insufficient\s+(?:funds|margin|money)|retcode\s*[=:]?\s*10019",
    re.IGNORECASE,
)
EA_ID_PATTERN = re.compile(r"QM5_(\d+)_", re.IGNORECASE)


def _path_key(path: Path) -> str:
    return str(path.resolve()).replace("\\", "/").casefold()


def _json_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"{path}: invalid summary JSON ({type(exc).__name__})") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path}: summary must be a JSON object")
    return value


def _decode_text(payload: bytes, *, label: Path) -> str:
    encodings = (
        ("utf-16",) if payload.startswith((b"\xff\xfe", b"\xfe\xff")) else ()
    ) + ("utf-8-sig", "utf-16", "cp1252")
    for encoding in encodings:
        try:
            return payload.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise ValueError(f"{label}: unsupported text encoding")


def _resolve_summary_path(summary_path: Path, raw: Any) -> Path:
    path = Path(str(raw))
    return path if path.is_absolute() else summary_path.parent / path


def _matching_run(
    summary: Mapping[str, Any],
    *,
    summary_path: Path,
    report_path: Path,
) -> Mapping[str, Any]:
    runs = summary.get("runs")
    if not isinstance(runs, list) or not runs:
        raise ValueError(f"{summary_path}: runs must be a non-empty list")
    report_key = _path_key(report_path)
    matches = [
        run
        for run in runs
        if isinstance(run, Mapping)
        and run.get("report_canonical_path")
        and _path_key(
            _resolve_summary_path(summary_path, run["report_canonical_path"])
        )
        == report_key
    ]
    if len(matches) != 1:
        raise ValueError(
            f"{summary_path}: expected exactly one run bound to {report_path}, "
            f"found {len(matches)}"
        )
    return matches[0]


def _tester_log_path(
    summary_path: Path,
    run: Mapping[str, Any],
) -> Path | None:
    raw = run.get("tester_log_path")
    if not raw:
        return None
    return _resolve_summary_path(summary_path, raw)


def referenced_tester_log_path(summary_path: Path, report_path: Path) -> Path | None:
    """Return the exact tester log referenced by the report-bound summary run."""

    summary = _json_object(summary_path)
    run = _matching_run(summary, summary_path=summary_path, report_path=report_path)
    return _tester_log_path(summary_path, run)


def scan_tester_log(
    path: Path | None,
    *,
    expected_expert: str | None = None,
    expected_symbol: str | None = None,
    expected_period: str | None = None,
) -> dict[str, Any]:
    if path is None:
        return {
            "referenced": False,
            "path": None,
            "no_money_detected": False,
        }
    if not path.is_file():
        raise ValueError(f"referenced tester log missing: {path}")
    text = _decode_text(path.read_bytes(), label=path)
    lines = text.splitlines()
    scoped_lines = lines
    scope_start = 0
    scope_end = len(lines) - 1
    scope_contract = "whole_referenced_log"
    if expected_expert and expected_symbol and expected_period:
        expert_name = expected_expert.replace("\\", "/").rsplit("/", 1)[-1]
        if expert_name.casefold().endswith(".ex5"):
            expert_name = expert_name[:-4]
        anchor_tokens = (
            f"{expected_symbol},{expected_period}".casefold(),
            expert_name.casefold(),
            "testing of experts",
        )
        anchors = [
            index
            for index, line in enumerate(lines)
            if all(token in line.casefold() for token in anchor_tokens)
        ]
        if not anchors:
            raise ValueError(
                f"{path}: no tester block for {expected_expert} "
                f"{expected_symbol},{expected_period}"
            )
        scope_start = anchors[-1]
        endings = [
            index
            for index in range(scope_start, len(lines))
            if "connection closed" in lines[index].casefold()
        ]
        if not endings:
            raise ValueError(f"{path}: scoped tester block has no connection-close marker")
        scope_end = endings[0]
        scoped_lines = lines[scope_start : scope_end + 1]
        if not any("test passed" in line.casefold() for line in scoped_lines):
            raise ValueError(f"{path}: scoped tester block has no Test passed marker")
        scope_contract = "last_exact_expert_symbol_period_block_to_connection_close"

    scoped_text = "\n".join(scoped_lines)
    match = NO_MONEY_PATTERN.search(scoped_text)
    return {
        "referenced": True,
        "path": str(path.resolve()),
        "no_money_detected": match is not None,
        "matched_marker": match.group(0) if match else None,
        "scope_contract": scope_contract,
        "scope_start_line": scope_start + 1 if lines else None,
        "scope_end_line": scope_end + 1 if lines else None,
        "scope_line_count": len(scoped_lines),
    }


def _read_set_values(path: Path) -> dict[str, str]:
    payload = path.read_bytes()
    text = _decode_text(payload, label=path)
    values: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith((";", "#")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def validate_set_binding(
    path: Path,
    *,
    expected_ea_id: int,
    expected_risk_fixed: float,
) -> dict[str, Any]:
    values = _read_set_values(path)
    try:
        ea_id = int(values["qm_ea_id"])
        risk_fixed = float(values["RISK_FIXED"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(f"{path}: qm_ea_id and numeric RISK_FIXED are required") from exc
    if ea_id != int(expected_ea_id):
        raise ValueError(f"{path}: qm_ea_id {ea_id} != summary EA {expected_ea_id}")
    if not math.isfinite(risk_fixed) or not math.isclose(
        risk_fixed, float(expected_risk_fixed), rel_tol=0.0, abs_tol=1e-12
    ):
        raise ValueError(
            f"{path}: RISK_FIXED {risk_fixed} != required {expected_risk_fixed}"
        )
    return {"ea_id": ea_id, "risk_fixed": risk_fixed}


def validate_binary_binding(path: Path, *, expected_ea_id: int) -> None:
    if path.suffix.casefold() != ".ex5":
        raise ValueError(f"{path}: native binary must have .ex5 suffix")
    match = EA_ID_PATTERN.search(path.name)
    if match is None or int(match.group(1)) != int(expected_ea_id):
        raise ValueError(f"{path}: binary filename is not bound to EA {expected_ea_id}")


def load_report_evidence(
    summary_path: Path,
    report_path: Path,
    *,
    expected_symbol: str,
    timestamp_basis: str,
    role: str,
    expected_ea_id: int | None = None,
    expected_trade_count: int | None = None,
) -> dict[str, Any]:
    """Bind one report to its deterministic summary and parse all round trips."""

    summary = _json_object(summary_path)
    symbol = expected_symbol.upper()
    if str(summary.get("result") or "").upper() != "PASS":
        raise ValueError(f"{summary_path}: top-level result is not PASS")
    if str(summary.get("symbol") or "").upper() != symbol:
        raise ValueError(f"{summary_path}: symbol does not equal {symbol}")
    if str(summary.get("period") or "").upper() != "M15":
        raise ValueError(f"{summary_path}: period must be M15")
    if summary.get("deterministic") is not True:
        raise ValueError(f"{summary_path}: deterministic must be true")
    try:
        ea_id = int(summary["ea_id"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(f"{summary_path}: positive integer ea_id is required") from exc
    if ea_id <= 0:
        raise ValueError(f"{summary_path}: positive integer ea_id is required")
    if expected_ea_id is not None and ea_id != int(expected_ea_id):
        raise ValueError(f"{summary_path}: EA {ea_id} != expected {expected_ea_id}")

    run = _matching_run(summary, summary_path=summary_path, report_path=report_path)
    if str(run.get("status") or "").upper() != "OK":
        raise ValueError(f"{summary_path}: report-bound run status is not OK")
    if run.get("oninit_failure") is True:
        raise ValueError(f"{summary_path}: report-bound run has OnInit failure")
    if run.get("exit_code") not in (None, 0, "0"):
        raise ValueError(f"{summary_path}: report-bound run exit code is not zero")
    try:
        declared_count = int(run["total_trades"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(f"{summary_path}: report-bound total_trades is invalid") from exc
    if declared_count <= 0:
        raise ValueError(f"{summary_path}: report-bound total_trades must be positive")

    trades, report_stats = extract_round_trips(report_path, symbol)
    if len(trades) != declared_count:
        raise ValueError(
            f"{role} count mismatch: parsed {len(trades)} != summary {declared_count}"
        )
    if expected_trade_count is not None and len(trades) != int(expected_trade_count):
        raise ValueError(
            f"{role} count mismatch: parsed {len(trades)} != expected "
            f"{expected_trade_count}"
        )
    for number, trade in enumerate(trades, 1):
        if trade.symbol.upper() != symbol:
            raise ValueError(
                f"{role} trade {number}: symbol {trade.symbol!r} != {symbol!r}"
            )
        entry_utc = joint.normalize_timestamp(trade.entry_time, timestamp_basis)
        if entry_utc.tz_convert(NEW_YORK).weekday() != 4:
            raise ValueError(f"{role} trade {number}: entry is not Friday New York")

    log_scan = scan_tester_log(
        _tester_log_path(summary_path, run),
        expected_expert=str(summary.get("expert") or ""),
        expected_symbol=symbol,
        expected_period="M15",
    )
    if log_scan["no_money_detected"]:
        raise ValueError(
            f"{role} tester log contains NO_MONEY marker: {log_scan['path']}"
        )
    return {
        "ea_id": ea_id,
        "summary": summary,
        "run": dict(run),
        "trades": trades,
        "report_stats": report_stats,
        "declared_trade_count": declared_count,
        "tester_log_scan": log_scan,
    }


def _entry_identity(
    trade: RoundTrip,
    *,
    timestamp_basis: str,
) -> dict[str, str]:
    entry_utc = joint.normalize_timestamp(trade.entry_time, timestamp_basis)
    entry_bucket = entry_utc.floor(joint.GRID_FREQUENCY)
    ny_date = entry_utc.tz_convert(NEW_YORK).date().isoformat()
    side = str(trade.side).casefold()
    if side not in {"buy", "sell"}:
        raise ValueError(f"unsupported trade side: {trade.side!r}")
    key = f"{ny_date}|{entry_bucket.isoformat()}|{side}"
    return {
        "key": key,
        "entry_date_new_york": ny_date,
        "entry_bar_open_utc": entry_bucket.isoformat(),
        "side": side,
        "entry_time_utc": entry_utc.isoformat(),
    }


def _counter_rows(counter: Counter[str]) -> list[dict[str, Any]]:
    return [
        {"entry_key": key, "count": int(count)}
        for key, count in sorted(counter.items())
        if count > 0
    ]


def compare_entry_parity(
    baseline_trades: Sequence[RoundTrip],
    target_trades: Sequence[RoundTrip],
    bars: pd.DataFrame,
    *,
    timestamp_basis: str,
    expected_symbol: str,
) -> dict[str, Any]:
    """Compare expected and native entries without reading any PnL field."""

    if not baseline_trades:
        raise ValueError("baseline has no trades")
    symbol = expected_symbol.upper()
    baseline_rows: list[dict[str, Any]] = []
    for number, trade in enumerate(baseline_trades, 1):
        if trade.symbol.upper() != symbol:
            raise ValueError(f"baseline trade {number}: symbol mismatch")
        identity = _entry_identity(trade, timestamp_basis=timestamp_basis)
        if pd.Timestamp(identity["entry_time_utc"]).tz_convert(NEW_YORK).weekday() != 4:
            raise ValueError(f"baseline trade {number}: entry is not Friday New York")
        row = oracle.trade_oracle_row(
            trade,
            bars,
            trade_number=number,
            timestamp_basis=timestamp_basis,
        )
        row["entry_match"] = identity
        baseline_rows.append(row)

    target_rows: list[dict[str, Any]] = []
    for number, trade in enumerate(target_trades, 1):
        if trade.symbol.upper() != symbol:
            raise ValueError(f"target trade {number}: symbol mismatch")
        identity = _entry_identity(trade, timestamp_basis=timestamp_basis)
        if pd.Timestamp(identity["entry_time_utc"]).tz_convert(NEW_YORK).weekday() != 4:
            raise ValueError(f"target trade {number}: entry is not Friday New York")
        target_rows.append(
            {
                "target_trade_number": number,
                "entry_time_source": oracle._iso_timestamp(trade.entry_time),
                "entry_match": identity,
            }
        )

    baseline_keys = Counter(row["entry_match"]["key"] for row in baseline_rows)
    expected_keys = Counter(
        row["entry_match"]["key"] for row in baseline_rows if row["accepted"]
    )
    target_keys = Counter(row["entry_match"]["key"] for row in target_rows)
    duplicate_baseline = Counter(
        {key: count for key, count in baseline_keys.items() if count != 1}
    )
    duplicate_target = Counter(
        {key: count for key, count in target_keys.items() if count != 1}
    )
    outside_baseline = target_keys - baseline_keys
    missing_expected = expected_keys - target_keys
    unexpected_target = target_keys - expected_keys

    reasons: list[str] = []
    if duplicate_baseline:
        reasons.append("duplicate_baseline_entry_key")
    if duplicate_target:
        reasons.append("duplicate_target_entry_key")
    if outside_baseline:
        reasons.append("target_not_exact_baseline_subset")
    if len(target_trades) != sum(expected_keys.values()):
        reasons.append("target_count_not_expected_accepted_count")
    if missing_expected:
        reasons.append("expected_entry_missing_from_target")
    if unexpected_target:
        reasons.append("unexpected_entry_present_in_target")

    decisions = Counter(str(row["decision"]) for row in baseline_rows)
    return {
        "status": "PASS" if not reasons else "FAIL",
        "reasons": reasons,
        "counts": {
            "baseline": len(baseline_rows),
            "expected_accepted": int(sum(expected_keys.values())),
            "expected_rejected": int(decisions["rejected"]),
            "expected_unavailable": int(decisions["unavailable"]),
            "target": len(target_rows),
        },
        "checks": {
            "target_is_exact_baseline_subset": not bool(outside_baseline),
            "target_count_equals_expected_accepted": len(target_trades)
            == sum(expected_keys.values()),
            "expected_entries_equal_target_entries": not missing_expected
            and not unexpected_target,
            "baseline_entry_keys_unique": not duplicate_baseline,
            "target_entry_keys_unique": not duplicate_target,
            "pnl_used_for_selection": False,
        },
        "deltas": {
            "outside_baseline": _counter_rows(outside_baseline),
            "missing_expected": _counter_rows(missing_expected),
            "unexpected_target": _counter_rows(unexpected_target),
            "duplicate_baseline": _counter_rows(duplicate_baseline),
            "duplicate_target": _counter_rows(duplicate_target),
        },
        "baseline_oracle": baseline_rows,
        "target_entries": target_rows,
    }


def _source_records(paths: Mapping[str, Path]) -> dict[str, dict[str, Any]]:
    records: dict[str, dict[str, Any]] = {}
    for name, path in paths.items():
        if not path.is_file():
            raise ValueError(f"{name} missing: {path}")
        records[name] = oracle._source_record(path)
    return records


def _assert_distinct_eas(baseline_ea_id: int, target_ea_id: int) -> None:
    if int(baseline_ea_id) == int(target_ea_id):
        raise ValueError("baseline and target EA IDs must be distinct")


def build_parity_artifact(
    *,
    baseline_summary: Path,
    baseline_report: Path,
    baseline_binary: Path,
    baseline_set: Path,
    target_summary: Path,
    target_report: Path,
    target_binary: Path,
    target_set: Path,
    bar_csv: Path,
    timestamp_basis: str,
    expected_symbol: str,
    expected_risk_fixed: float = 10.0,
    expected_baseline_ea_id: int | None = None,
    expected_target_ea_id: int | None = None,
    expected_baseline_trades: int | None = None,
    expected_target_trades: int | None = None,
) -> dict[str, Any]:
    if timestamp_basis not in joint.VALID_TIMESTAMP_BASES:
        raise ValueError(f"unsupported timestamp_basis: {timestamp_basis}")
    symbol = expected_symbol.upper()
    if not symbol:
        raise ValueError("expected_symbol must not be empty")

    source_paths = {
        "baseline_summary": baseline_summary,
        "baseline_report": baseline_report,
        "baseline_binary": baseline_binary,
        "baseline_set": baseline_set,
        "target_summary": target_summary,
        "target_report": target_report,
        "target_binary": target_binary,
        "target_set": target_set,
        "observed_m15_bars": bar_csv,
    }
    baseline_log = referenced_tester_log_path(baseline_summary, baseline_report)
    target_log = referenced_tester_log_path(target_summary, target_report)
    if baseline_log is not None:
        source_paths["baseline_tester_log"] = baseline_log
    if target_log is not None:
        source_paths["target_tester_log"] = target_log
    before = _source_records(source_paths)

    baseline = load_report_evidence(
        baseline_summary,
        baseline_report,
        expected_symbol=symbol,
        timestamp_basis=timestamp_basis,
        role="baseline",
        expected_ea_id=expected_baseline_ea_id,
        expected_trade_count=expected_baseline_trades,
    )
    target = load_report_evidence(
        target_summary,
        target_report,
        expected_symbol=symbol,
        timestamp_basis=timestamp_basis,
        role="target",
        expected_ea_id=expected_target_ea_id,
        expected_trade_count=expected_target_trades,
    )
    _assert_distinct_eas(baseline["ea_id"], target["ea_id"])
    validate_binary_binding(baseline_binary, expected_ea_id=baseline["ea_id"])
    validate_binary_binding(target_binary, expected_ea_id=target["ea_id"])
    baseline_set_binding = validate_set_binding(
        baseline_set,
        expected_ea_id=baseline["ea_id"],
        expected_risk_fixed=expected_risk_fixed,
    )
    target_set_binding = validate_set_binding(
        target_set,
        expected_ea_id=target["ea_id"],
        expected_risk_fixed=expected_risk_fixed,
    )
    bars = joint.load_resampled_bars(bar_csv, timestamp_basis=timestamp_basis)
    comparison = compare_entry_parity(
        baseline["trades"],
        target["trades"],
        bars,
        timestamp_basis=timestamp_basis,
        expected_symbol=symbol,
    )

    after = _source_records(source_paths)
    oracle._assert_sources_unchanged(before, after)
    semantic_sources = _source_records(
        {
            "comparator": Path(__file__),
            "entry_oracle": Path(str(oracle.__file__)),
            "bar_timestamp_semantics": Path(str(joint.__file__)),
        }
    )
    return {
        "schema_version": 1,
        "artifact_type": "trend20d_native_mt5_entry_parity",
        "status": comparison["status"],
        "symbol": symbol,
        "timestamp_basis": timestamp_basis,
        "rule_contract": {
            "timeframe": "M15",
            "bar_source": "observed_only_no_gap_fill",
            "newest_shift": oracle.NEWEST_SHIFT,
            "oldest_shift": oracle.OLDEST_SHIFT,
            "required_completed_closes": oracle.REQUIRED_COMPLETED_CLOSES,
            "signed_return": "side * (close_shift1 / close_shift1921 - 1.0)",
            "strict_operator": ">",
            "threshold": 0.0,
            "insufficient_history": "reject",
        },
        "matching_contract": {
            "fields": ["entry_date_new_york", "entry_bar_open_utc", "side"],
            "entry_bar_frequency": joint.GRID_FREQUENCY,
            "first_tick_seconds_ignored_within_bucket": True,
            "target_must_equal_expected_accepted_entries": True,
            "target_must_be_exact_baseline_subset": True,
        },
        "selection_contract": {
            "baseline_policy": "every_report_reconciled_friday_round_trip",
            "pnl_fields_used": False,
            "exit_fields_used": False,
            "post_entry_fields_used": False,
        },
        "input_binding": {
            "expected_risk_fixed": float(expected_risk_fixed),
            "baseline": {
                "ea_id": baseline["ea_id"],
                "summary_declared_trades": baseline["declared_trade_count"],
                "set": baseline_set_binding,
                "tester_log_scan": baseline["tester_log_scan"],
            },
            "target": {
                "ea_id": target["ea_id"],
                "summary_declared_trades": target["declared_trade_count"],
                "set": target_set_binding,
                "tester_log_scan": target["tester_log_scan"],
            },
        },
        "source_freeze": {
            "algorithm": "SHA256",
            "stable_during_comparison": True,
            "inputs": after,
            "semantic_sources": semantic_sources,
        },
        "comparison": comparison,
    }


def _failure_artifact(exc: Exception, args: argparse.Namespace) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": "trend20d_native_mt5_entry_parity",
        "status": "FAIL",
        "reason_class": "INPUT_VALIDATION_ERROR",
        "error": str(exc),
        "symbol": str(args.expected_symbol).upper(),
        "timestamp_basis": args.timestamp_basis,
        "selection_contract": {"pnl_fields_used": False},
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-summary", type=Path, required=True)
    parser.add_argument("--baseline-report", type=Path, required=True)
    parser.add_argument("--baseline-binary", type=Path, required=True)
    parser.add_argument("--baseline-set", type=Path, required=True)
    parser.add_argument("--target-summary", type=Path, required=True)
    parser.add_argument("--target-report", type=Path, required=True)
    parser.add_argument("--target-binary", type=Path, required=True)
    parser.add_argument("--target-set", type=Path, required=True)
    parser.add_argument("--bar-csv", type=Path, required=True)
    parser.add_argument(
        "--timestamp-basis",
        choices=sorted(joint.VALID_TIMESTAMP_BASES),
        required=True,
    )
    parser.add_argument("--expected-symbol", required=True)
    parser.add_argument("--expected-risk-fixed", type=float, default=10.0)
    parser.add_argument("--expected-baseline-ea-id", type=int)
    parser.add_argument("--expected-target-ea-id", type=int)
    parser.add_argument("--expected-baseline-trades", type=int)
    parser.add_argument("--expected-target-trades", type=int)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--sha256-out", type=Path)
    args = parser.parse_args(argv)

    try:
        artifact = build_parity_artifact(
            baseline_summary=args.baseline_summary,
            baseline_report=args.baseline_report,
            baseline_binary=args.baseline_binary,
            baseline_set=args.baseline_set,
            target_summary=args.target_summary,
            target_report=args.target_report,
            target_binary=args.target_binary,
            target_set=args.target_set,
            bar_csv=args.bar_csv,
            timestamp_basis=args.timestamp_basis,
            expected_symbol=args.expected_symbol,
            expected_risk_fixed=args.expected_risk_fixed,
            expected_baseline_ea_id=args.expected_baseline_ea_id,
            expected_target_ea_id=args.expected_target_ea_id,
            expected_baseline_trades=args.expected_baseline_trades,
            expected_target_trades=args.expected_target_trades,
        )
    except (OSError, ValueError, KeyError) as exc:
        artifact = _failure_artifact(exc, args)

    sha256_path = args.sha256_out or args.out.with_suffix(".sha256")
    digest = oracle.write_artifact(
        artifact,
        out_path=args.out,
        sha256_path=sha256_path,
    )
    print(
        json.dumps(
            {
                "out": str(args.out),
                "sha256_out": str(sha256_path),
                "sha256": digest,
                "status": artifact["status"],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0 if artifact["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
