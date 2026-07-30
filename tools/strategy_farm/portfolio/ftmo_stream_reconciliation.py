"""Reconcile an MAE trade stream against its originating MT5 smoke report.

Historical unmarked Q08 rows record only closing-side commission and retain the
known one-entry/one-exit correction.  Lifecycle-v1 rows carry an explicit money
basis and already include actual entry and exit commission in their money
decomposition; ``mae_acct`` remains a separate floating-MAE measure.  Unknown,
malformed, or mixed money bases are rejected before a stream can feed portfolio
simulation.
"""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
from typing import Any, Iterable

try:
    from .ftmo_phase1_mae import (
        FULL_POSITION_LIFECYCLE_ACTUAL_V1,
        LEGACY_Q08_MONEY_BASIS,
        Q08MoneyBasisError,
        Q08MoneyRowError,
        q08_money_basis,
        q08_round_trip_values,
    )
    from .ftmo_report_cost_reconcile import RoundTrip, extract_round_trips
except ImportError:  # direct script execution
    from ftmo_phase1_mae import (  # type: ignore
        FULL_POSITION_LIFECYCLE_ACTUAL_V1,
        LEGACY_Q08_MONEY_BASIS,
        Q08MoneyBasisError,
        Q08MoneyRowError,
        q08_money_basis,
        q08_round_trip_values,
    )
    from ftmo_report_cost_reconcile import RoundTrip, extract_round_trips  # type: ignore


DEFAULT_STREAM_DIR = (
    Path(os.environ.get("APPDATA", r"C:\Users\Administrator\AppData\Roaming"))
    / "MetaQuotes" / "Terminal" / "Common" / "Files" / "QM" / "q08_trades"
)
MAX_Q08_STREAM_BYTES = 256 * 1024 * 1024
MAX_Q08_LINE_BYTES = 1024 * 1024
MAX_Q08_LINES = 2_000_000


def default_stream_path(ea_id: int, symbol: str) -> Path:
    return DEFAULT_STREAM_DIR / f"{ea_id}_{symbol.replace('.', '_')}.jsonl"


def _number(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def strict_json_loads(raw: str, *, label: str) -> Any:
    def pairs_hook(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"{label}: duplicate JSON key {key!r}")
            result[key] = value
        return result

    def reject_constant(token: str) -> Any:
        raise ValueError(f"{label}: nonfinite JSON constant {token}")

    value = json.loads(
        raw,
        object_pairs_hook=pairs_hook,
        parse_constant=reject_constant,
    )

    def finite(child: Any) -> None:
        if isinstance(child, float) and not math.isfinite(child):
            raise ValueError(f"{label}: nonfinite JSON number")
        if isinstance(child, dict):
            for item in child.values():
                finite(item)
        elif isinstance(child, list):
            for item in child:
                finite(item)

    finite(value)
    return value


def load_q08_trade_rows(path: Path) -> list[dict[str, Any]]:
    if path.stat().st_size > MAX_Q08_STREAM_BYTES:
        raise ValueError(f"{path}: Q08 stream exceeds size limit")
    rows: list[dict[str, Any]] = []
    with path.open(encoding="utf-8", errors="strict") as handle:
        for line_number, line in enumerate(handle, 1):
            if line_number > MAX_Q08_LINES:
                raise ValueError(f"{path}: Q08 stream exceeds line limit")
            if len(line.encode("utf-8")) > MAX_Q08_LINE_BYTES:
                raise ValueError(f"{path}:{line_number}: Q08 row exceeds size limit")
            if not line.strip():
                continue
            value = strict_json_loads(line, label=f"{path}:{line_number}")
            if not isinstance(value, dict):
                raise ValueError(f"{path}:{line_number}: JSON row is not an object")
            if str(value.get("event") or "TRADE_CLOSED") == "TRADE_CLOSED":
                rows.append(value)
    return rows


def summarize_stream(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"path": str(path), "exists": False, "trade_count": 0}
    invalid_rows = 0
    try:
        trades = load_q08_trade_rows(path)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError):
        trades = []
        invalid_rows = 1
    raw_net = sum(_number(row.get("net")) for row in trades)
    basis_counts = {
        LEGACY_Q08_MONEY_BASIS: 0,
        FULL_POSITION_LIFECYCLE_ACTUAL_V1: 0,
    }
    unknown_basis_rows = 0
    malformed_money_rows = 0
    corrected_values: list[float] = []
    closing_commission = 0.0
    total_commission = 0.0
    for row in trades:
        try:
            basis = q08_money_basis(row)
        except Q08MoneyBasisError:
            unknown_basis_rows += 1
            continue
        basis_counts[basis] += 1
        try:
            corrected_net, _ = q08_round_trip_values(row)
        except (
            Q08MoneyBasisError,
            Q08MoneyRowError,
            KeyError,
            TypeError,
            ValueError,
            OverflowError,
        ):
            malformed_money_rows += 1
            continue
        corrected_values.append(corrected_net)
        if basis == FULL_POSITION_LIFECYCLE_ACTUAL_V1:
            closing_commission += _number(row.get("exit_commission"))
        else:
            closing_commission += _number(row.get("commission"))
        total_commission += _number(row.get("commission"))

    observed_bases = [basis for basis, count in basis_counts.items() if count]
    mixed_money_basis = len(observed_bases) > 1
    homogeneous_basis = observed_bases[0] if len(observed_bases) == 1 else None
    money_contract_valid = not (
        unknown_basis_rows or malformed_money_rows or mixed_money_basis
    )
    return {
        "path": str(path),
        "exists": True,
        "trade_count": len(trades),
        "invalid_rows": invalid_rows,
        "missing_mae_rows": sum(
            1 for row in trades if row.get("entry_time") is None or row.get("mae_acct") is None
        ),
        "raw_net": round(raw_net, 6),
        "closing_commission": round(closing_commission, 6),
        "total_commission": round(total_commission, 6),
        "money_basis": homogeneous_basis,
        "money_basis_counts": basis_counts,
        "mixed_money_basis": mixed_money_basis,
        "unknown_money_basis_rows": unknown_basis_rows,
        "malformed_money_rows": malformed_money_rows,
        "money_contract_valid": money_contract_valid,
        "round_trip_corrected_net": (
            round(sum(corrected_values), 6) if money_contract_valid else None
        ),
    }


def summarize_report(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"path": str(path), "exists": False}
    try:
        summary = strict_json_loads(
            path.read_text(encoding="utf-8-sig", errors="strict"), label=str(path)
        )
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        return {"path": str(path), "exists": True, "read_error": type(exc).__name__}
    usable = [
        run for run in summary.get("runs") or []
        if str(run.get("status") or "").upper() == "OK"
        and int(_number(run.get("total_trades"))) > 0
    ]
    if not usable:
        return {
            "path": str(path),
            "exists": True,
            "result": summary.get("result"),
            "usable_run": None,
        }
    run = usable[-1]
    return {
        "path": str(path),
        "exists": True,
        "result": summary.get("result"),
        "usable_run": run.get("run"),
        "trade_count": int(_number(run.get("total_trades"))),
        "profit_factor": run.get("profit_factor"),
        "net_profit": _number(run.get("net_profit")),
        "drawdown": run.get("drawdown"),
        "report_canonical_path": run.get("report_canonical_path"),
        "report_sha256": run.get("report_sha256"),
        "report_size_bytes": run.get("report_size_bytes"),
    }


def _finite_row_number(row: dict[str, Any], key: str, label: str) -> float:
    value = row.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{label}: {key} is not a JSON number")
    number = float(value)
    if not math.isfinite(number):
        raise ValueError(f"{label}: {key} is nonfinite")
    return number


def _row_timestamp(row: dict[str, Any], key: str, label: str) -> int:
    value = row.get(key)
    if type(value) is not int or value <= 0:
        raise ValueError(f"{label}: {key} is not a positive JSON integer")
    return value


def _lifecycle_reconciliation(
    trades: list[RoundTrip], rows: list[dict[str, Any]]
) -> tuple[dict[str, Any], list[str]]:
    reasons: list[str] = []
    if len(trades) != len(rows):
        reasons.append(f"lifecycle_count_mismatch:{len(rows)}!={len(trades)}")
        return {
            "status": "FAIL",
            "matching_contract": "SEQUENTIAL_NATIVE_DEAL_LIFECYCLE_V1_NO_POSITION_ID",
            "checked_rows": min(len(trades), len(rows)),
            "mismatch_count": 1,
        }, reasons

    report_keys: set[tuple[Any, ...]] = set()
    q08_keys: set[tuple[Any, ...]] = set()
    mismatches: list[str] = []
    for index, (trade, row) in enumerate(zip(trades, rows), 1):
        label = f"lifecycle_{index}"
        try:
            entry_time = _row_timestamp(row, "entry_time", label)
            exit_time = _row_timestamp(row, "time", label)
            volume = _finite_row_number(row, "volume", label)
            entry_price = _finite_row_number(row, "entry_price", label)
            exit_price = _finite_row_number(row, "exit_price", label)
            profit = _finite_row_number(row, "profit", label)
            swap = _finite_row_number(row, "swap", label)
            commission = _finite_row_number(row, "commission", label)
            entry_commission = _finite_row_number(row, "entry_commission", label)
            exit_commission = _finite_row_number(row, "exit_commission", label)
            fee = _finite_row_number(row, "fee", label)
            net = _finite_row_number(row, "net", label)
        except ValueError as exc:
            mismatches.append(str(exc))
            continue
        side = str(row.get("side") or "").lower()
        symbol = str(row.get("symbol") or "").upper()
        report_key = (
            int(trade.entry_time.timestamp()),
            int(trade.exit_time.timestamp()),
            trade.symbol.upper(),
            trade.side,
            round(trade.volume, 10),
            round(trade.entry_price, 10),
            round(trade.exit_price, 10),
        )
        q08_key = (
            entry_time,
            exit_time,
            symbol,
            side,
            round(volume, 10),
            round(entry_price, 10),
            round(exit_price, 10),
        )
        if report_key in report_keys or q08_key in q08_keys:
            mismatches.append(f"{label}:ambiguous_duplicate_lifecycle_identity")
        report_keys.add(report_key)
        q08_keys.add(q08_key)
        if report_key != q08_key:
            mismatches.append(f"{label}:identity_mismatch")
        money_pairs = (
            ("profit", profit, trade.profit),
            ("swap", swap, trade.native_swap),
            ("commission", commission, trade.native_commission),
            (
                "entry_commission",
                entry_commission,
                trade.native_entry_commission,
            ),
            (
                "exit_commission",
                exit_commission,
                trade.native_exit_commission,
            ),
        )
        for name, observed, expected in money_pairs:
            if abs(observed - expected) > 0.005:
                mismatches.append(
                    f"{label}:{name}_mismatch:{observed:.6f}!={expected:.6f}"
                )
        # Native MT5 report deal tables used here have no separate fee column.
        # Therefore a non-zero Q08 fee cannot be reconciled and is refused.
        if abs(fee) > 0.005:
            mismatches.append(f"{label}:unreconciled_nonzero_fee:{fee:.6f}")
        if abs(commission - entry_commission - exit_commission) > 0.005:
            mismatches.append(f"{label}:q08_commission_side_decomposition_mismatch")
        if abs(net - (profit + swap + commission + fee)) > 0.005:
            mismatches.append(f"{label}:q08_money_decomposition_mismatch")
    if mismatches:
        reasons.extend(f"lifecycle:{value}" for value in mismatches[:20])
    return {
        "status": "PASS" if not mismatches else "FAIL",
        "matching_contract": "SEQUENTIAL_NATIVE_DEAL_LIFECYCLE_V1_NO_POSITION_ID",
        "position_id_available_in_native_report": False,
        "checked_rows": len(rows),
        "mismatch_count": len(mismatches),
        "money_tolerance_usd": 0.005,
        "identity_fields": [
            "entry_time",
            "exit_time",
            "symbol",
            "side",
            "volume",
            "entry_price",
            "exit_price",
        ],
        "money_fields": [
            "profit",
            "swap",
            "commission",
            "entry_commission",
            "exit_commission",
            "fee",
            "net",
        ],
    }, reasons


def reconcile_case(
    ea_id: int,
    symbol: str,
    summary_path: Path,
    *,
    stream_path: Path | None = None,
    report_path: Path | None = None,
    cents_per_trade_tolerance: float = 0.01,
    absolute_tolerance: float = 1.0,
) -> dict[str, Any]:
    resolved_stream_path = stream_path or default_stream_path(ea_id, symbol)
    stream = summarize_stream(resolved_stream_path)
    report = summarize_report(summary_path)
    reasons: list[str] = []
    if not stream.get("exists"):
        reasons.append("stream_missing")
    if stream.get("invalid_rows"):
        reasons.append(f"stream_invalid_rows:{stream['invalid_rows']}")
    if stream.get("unknown_money_basis_rows"):
        reasons.append(
            f"stream_unknown_money_basis_rows:{stream['unknown_money_basis_rows']}"
        )
    if stream.get("malformed_money_rows"):
        reasons.append(f"stream_malformed_money_rows:{stream['malformed_money_rows']}")
    if stream.get("mixed_money_basis"):
        reasons.append("stream_mixed_money_basis")
    if stream.get("missing_mae_rows"):
        reasons.append(f"stream_missing_mae_rows:{stream['missing_mae_rows']}")
    if not report.get("exists"):
        reasons.append("report_summary_missing")
    elif report.get("usable_run") is None:
        reasons.append("report_usable_run_missing")

    count_delta: int | None = None
    net_delta: float | None = None
    net_tolerance: float | None = None
    if stream.get("exists") and report.get("usable_run") is not None:
        count_delta = int(stream["trade_count"]) - int(report["trade_count"])
        if count_delta:
            reasons.append(f"trade_count_mismatch:{stream['trade_count']}!={report['trade_count']}")
        if stream.get("round_trip_corrected_net") is not None:
            net_delta = float(stream["round_trip_corrected_net"]) - float(report["net_profit"])
            net_tolerance = max(
                absolute_tolerance,
                cents_per_trade_tolerance * int(report["trade_count"]),
            )
            if abs(net_delta) > net_tolerance:
                reasons.append(
                    f"corrected_net_mismatch:delta={net_delta:.2f}:tolerance={net_tolerance:.2f}"
                )

    lifecycle: dict[str, Any] = {
        "status": "NOT_RUN",
        "matching_contract": "SEQUENTIAL_NATIVE_DEAL_LIFECYCLE_V1_NO_POSITION_ID",
    }
    if not reasons and report_path is not None:
        try:
            q08_rows = load_q08_trade_rows(resolved_stream_path)
            report_trades, _report_stats = extract_round_trips(report_path, symbol)
            lifecycle, lifecycle_reasons = _lifecycle_reconciliation(
                report_trades, q08_rows
            )
            reasons.extend(lifecycle_reasons)
        except (OSError, UnicodeError, ValueError, OverflowError) as exc:
            reasons.append(f"lifecycle_parse_error:{type(exc).__name__}:{exc}")
            lifecycle = {
                "status": "FAIL",
                "matching_contract": "SEQUENTIAL_NATIVE_DEAL_LIFECYCLE_V1_NO_POSITION_ID",
                "parse_error": type(exc).__name__,
            }

    basis = stream.get("money_basis")
    if not stream.get("money_contract_valid"):
        contract = "invalid_or_mixed_money_basis"
    elif basis == FULL_POSITION_LIFECYCLE_ACTUAL_V1:
        contract = "full_position_lifecycle_actual_v1"
    elif basis == LEGACY_Q08_MONEY_BASIS:
        contract = "one_entry_one_exit_duplicate_closing_commission"
    else:
        contract = "invalid_or_mixed_money_basis"
    return {
        "ea_id": int(ea_id),
        "symbol": symbol.upper(),
        "status": "PASS" if not reasons else "FAIL",
        "reasons": reasons,
        "contract": contract,
        "count_delta": count_delta,
        "corrected_net_delta": round(net_delta, 6) if net_delta is not None else None,
        "net_tolerance": round(net_tolerance, 6) if net_tolerance is not None else None,
        "stream": stream,
        "report": report,
        "lifecycle": lifecycle,
    }


def reconcile_manifest(cases: Iterable[dict[str, Any]]) -> dict[str, Any]:
    results = [
        reconcile_case(
            int(case["ea_id"]),
            str(case["symbol"]),
            Path(case["summary_path"]),
            stream_path=Path(case["stream_path"]) if case.get("stream_path") else None,
        )
        for case in cases
    ]
    return {
        "schema_version": 1,
        "status": "PASS" if results and all(row["status"] == "PASS" for row in results) else "FAIL",
        "pass_count": sum(row["status"] == "PASS" for row in results),
        "fail_count": sum(row["status"] != "PASS" for row in results),
        "results": results,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    cases = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    if not isinstance(cases, list):
        parser.error("--manifest must contain a JSON list")
    artifact = reconcile_manifest(cases)
    rendered = json.dumps(artifact, indent=2, sort_keys=True) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered, encoding="utf-8")
        print(f"wrote {args.out} status={artifact['status']}")
    else:
        print(rendered, end="")
    return 0 if artifact["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
