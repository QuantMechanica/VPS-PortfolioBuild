#!/usr/bin/env python3
"""Validate and cost-project the dated FTMO current-pool term snapshot."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from . import ftmo_cost_adjusted_export as exporter
except ImportError:  # pragma: no cover
    import ftmo_cost_adjusted_export as exporter  # type: ignore


SCHEMA = "qm.ftmo-current-pool-cost-snapshot/v1"
EXPECTED_SYMBOLS = {"EURUSD", "GBPUSD", "USDCAD", "NZDUSD", "XAGUSD", "XTIUSD"}
EXPECTED_SLEEVES = {
    "10706:GBPUSD", "11421:EURUSD", "11422:USDCAD", "11910:NZDUSD",
    "13054:XTIUSD", "1537:XAGUSD", "20048:XTIUSD", "21505:XAGUSD",
}


class SnapshotError(ValueError):
    pass


def _reject_constant(value: str) -> None:
    raise SnapshotError(f"non-finite JSON constant: {value}")


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise SnapshotError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8-sig"),
            parse_constant=_reject_constant,
            object_pairs_hook=_pairs,
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SnapshotError(f"snapshot unreadable: {exc}") from exc
    validate(value)
    return value


def _finite(value: Any, label: str) -> float:
    if isinstance(value, bool):
        raise SnapshotError(f"{label}: boolean is not numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise SnapshotError(f"{label}: expected finite number") from exc
    if not math.isfinite(number):
        raise SnapshotError(f"{label}: expected finite number")
    return number


def validate(value: Any) -> None:
    required = {
        "schema", "retrieved_at_utc", "status", "sources", "internal_bindings",
        "symbols", "sleeves", "consumer_instrument_rows", "diff_from_2026_07_30",
        "projection", "owner_actions", "authorization",
    }
    if not isinstance(value, Mapping) or set(value) != required:
        raise SnapshotError("snapshot: unexpected fields")
    if value["schema"] != SCHEMA:
        raise SnapshotError("snapshot: unsupported schema")
    if value["status"] not in {"PASS_PROVISIONAL_ROLLOVER", "ABSTAIN"}:
        raise SnapshotError("snapshot: invalid status")
    symbols = value["symbols"]
    if not isinstance(symbols, list) or {row.get("symbol") for row in symbols if isinstance(row, Mapping)} != EXPECTED_SYMBOLS:
        raise SnapshotError("snapshot: current-pool symbol set mismatch")
    rows = value["consumer_instrument_rows"]
    if not isinstance(rows, list) or len(rows) != len(EXPECTED_SYMBOLS):
        raise SnapshotError("snapshot: consumer rows incomplete")
    by_code = {str(row.get("code")): row for row in rows if isinstance(row, Mapping)}
    if len(by_code) != len(rows):
        raise SnapshotError("snapshot: duplicate/invalid consumer code")
    for index, symbol in enumerate(symbols):
        label = f"symbols[{index}]"
        if not isinstance(symbol, Mapping):
            raise SnapshotError(f"{label}: expected object")
        provider = symbol.get("provider")
        normalized = symbol.get("normalized")
        if not isinstance(provider, Mapping) or not isinstance(normalized, Mapping):
            raise SnapshotError(f"{label}: provider/normalized missing")
        code = str(symbol.get("ftmo_code"))
        if code not in by_code:
            raise SnapshotError(f"{label}: consumer row absent")
        commission = normalized.get("commission_round_trip")
        swap = normalized.get("swap")
        contract = normalized.get("contract")
        margin = normalized.get("margin")
        if not all(isinstance(item, Mapping) for item in (commission, swap, contract, margin)):
            raise SnapshotError(f"{label}: normalized sections missing")
        commission_type = provider.get("commissionType")
        expected_unit = (
            "USD_PER_TARGET_LOT_ROUND_TRIP"
            if commission_type == "flat_USD"
            else "PERCENT_OF_NOTIONAL_PER_SIDE"
        )
        if commission_type not in {"flat_USD", "percent"} or commission.get("unit") != expected_unit:
            raise SnapshotError(f"{label}: commission unit/type mismatch")
        if swap.get("unit") != "POINTS_PER_TARGET_LOT_PER_ROLLOVER_UNIT":
            raise SnapshotError(f"{label}: swap unit mismatch")
        if contract.get("contract_size_unit") != "UNDERLYING_UNITS_PER_TARGET_LOT":
            raise SnapshotError(f"{label}: contract unit mismatch")
        if contract.get("tick_value_unit") != "PROFIT_CURRENCY_PER_TARGET_LOT_PER_TICK":
            raise SnapshotError(f"{label}: tick-value unit mismatch")
        if margin.get("unit") != "PERCENT_OF_NOTIONAL":
            raise SnapshotError(f"{label}: margin unit mismatch")
        for numeric_label, numeric in (
            ("commission", provider.get("commission")), ("swapLong", provider.get("swapLong")),
            ("swapShort", provider.get("swapShort")), ("contractSize", provider.get("contractSize")),
            ("tick_size", contract.get("tick_size")), ("tick_value", contract.get("tick_value")),
            ("swing_margin", margin.get("swing_margin_percent")),
        ):
            _finite(numeric, f"{label}.{numeric_label}")
        row = by_code[code]
        for field in ("commission", "commissionType", "swapLong", "swapShort", "contractSize", "digits"):
            if row.get(field) != provider.get(field):
                raise SnapshotError(f"{label}: consumer/provider drift in {field}")
        if row.get("tripleWeekday") != 2:
            raise SnapshotError(f"{label}: provisional rollover weekday drift")
    sleeves = value["sleeves"]
    if not isinstance(sleeves, list) or {row.get("sleeve_id") for row in sleeves if isinstance(row, Mapping)} != EXPECTED_SLEEVES:
        raise SnapshotError("snapshot: current-pool sleeve set mismatch")
    projection = value["projection"]
    if not isinstance(projection, Mapping) or projection.get("basis") != "FTMO_COMMISSION_AND_SWAP_ONLY_SPREAD_EXCLUDED":
        raise SnapshotError("snapshot: projection basis mismatch")
    results = projection.get("sleeves")
    if not isinstance(results, list) or {row.get("sleeve_id") for row in results if isinstance(row, Mapping)} != EXPECTED_SLEEVES:
        raise SnapshotError("snapshot: projection sleeve set mismatch")
    for index, row in enumerate(results):
        for field in ("source_net", "projected_ftmo_net_before_spread", "net_delta", "ftmo_commission", "ftmo_swap"):
            _finite(row.get(field), f"projection.sleeves[{index}].{field}")


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def project(value: Mapping[str, Any]) -> dict[str, Any]:
    terms = {str(row["code"]): row for row in value["consumer_instrument_rows"]}
    results = []
    for sleeve in value["sleeves"]:
        sleeve_id = str(sleeve["sleeve_id"])
        source_symbol = str(sleeve["source_symbol"])
        stream_path = Path(str(sleeve["trade_stream_path"])).resolve()
        # Q08 contains a small number of broker-reported same-second closes.  They
        # still incur commission, while their rollover and spread duration is zero.
        trades = exporter._load_q08(
            stream_path,
            source_symbol=source_symbol,
            sleeve_id=sleeve_id,
            allow_zero_lifecycle=True,
        )
        term = terms[str(sleeve["ftmo_code"])]
        buckets: dict[str, float] = {}
        for trade in trades:
            buckets[exporter._bucket_name(trade.entry_utc, 60)] = 0.0
            buckets[exporter._bucket_name(trade.exit_utc, 60)] = 0.0
        adjusted = [exporter._adjust_trade(trade, term=term, buckets=buckets, bucket_minutes=60) for trade in trades]
        source_net = sum(trade.net for trade in trades)
        commission = -sum(row.ftmo_entry_commission_charge + row.ftmo_exit_commission_charge for row in adjusted)
        swap = sum(row.ftmo_swap_cash for row in adjusted)
        projected = sum(row.source.profit + row.source.fee for row in adjusted) + commission + swap
        results.append({
            "sleeve_id": sleeve_id,
            "trade_stream_sha256": _sha(stream_path),
            "trades": len(trades),
            "source_net": round(source_net, 2),
            "projected_ftmo_net_before_spread": round(projected, 2),
            "net_delta": round(projected - source_net, 2),
            "ftmo_commission": round(commission, 2),
            "ftmo_swap": round(swap, 2),
            "spread_delta": None,
            "spread_status": "MISSING_MATCHED_FTMO_DXZ_CALIBRATION",
        })
    return {"basis": "FTMO_COMMISSION_AND_SWAP_ONLY_SPREAD_EXCLUDED", "sleeves": results}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "project"))
    parser.add_argument("snapshot", type=Path)
    args = parser.parse_args(argv)
    try:
        value = load(args.snapshot)
        result = {"status": "PASS", "snapshot_sha256": _sha(args.snapshot)}
        if args.command == "project":
            result["projection"] = project(value)
        print(json.dumps(result, indent=2, sort_keys=True, allow_nan=False))
        return 0
    except (SnapshotError, exporter.CostAdjustedExportError) as exc:
        print(json.dumps({"status": "REFUSED", "error": str(exc)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
