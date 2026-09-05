#!/usr/bin/env python3
"""Export synchronized interval balance and evidence coverage from tester artifacts.

The exporter is deliberately fail-closed.  Closed lifecycle streams can
reconstruct balance and position occupancy, while EQUITY_SNAPSHOT logger events
are preserved at their exact observation timestamps.  It never interpolates
mark-to-market equity, interval minima, or pending-order state.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import tempfile
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Mapping, Sequence


SPEC_SCHEMA = "qm.interval-equity-export-spec/v1"
OUTPUT_SCHEMA = "qm.interval-equity-export/v1"
TRADE_EVENT = "TRADE_CLOSED"
SNAPSHOT_EVENT = "EQUITY_SNAPSHOT"
MAX_ROWS = 5_000_000


class IntervalExportError(ValueError):
    """Input evidence is malformed or insufficient for a safe export."""


def _reject_constant(token: str) -> None:
    raise IntervalExportError(f"non-finite JSON constant: {token}")


def _object_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise IntervalExportError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def _loads(raw: bytes, label: str) -> Any:
    try:
        return json.loads(
            raw.decode("utf-8-sig"),
            object_pairs_hook=_object_no_duplicates,
            parse_constant=_reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise IntervalExportError(f"{label}: invalid UTF-8/JSON: {exc}") from exc


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise IntervalExportError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def _binding(path_value: Any, label: str) -> tuple[Path, dict[str, Any]]:
    if not isinstance(path_value, str) or not path_value.strip():
        raise IntervalExportError(f"{label}: expected non-empty path")
    path = Path(path_value).expanduser().resolve()
    if not path.is_file():
        raise IntervalExportError(f"{label}: file absent: {path}")
    return path, {"path": str(path), "size_bytes": path.stat().st_size, "sha256": _sha256(path)}


def _decimal(value: Any, label: str) -> Decimal:
    if isinstance(value, bool):
        raise IntervalExportError(f"{label}: boolean is not numeric")
    try:
        number = Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise IntervalExportError(f"{label}: expected finite decimal") from exc
    if not number.is_finite():
        raise IntervalExportError(f"{label}: expected finite decimal")
    return number


def _money(value: Decimal) -> str:
    return format(value.quantize(Decimal("0.01")), "f")


def _timestamp(value: Any, label: str) -> dt.datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise IntervalExportError(f"{label}: expected explicit UTC timestamp ending Z")
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise IntervalExportError(f"{label}: invalid timestamp") from exc
    if parsed.utcoffset() != dt.timedelta(0):
        raise IntervalExportError(f"{label}: timestamp is not UTC")
    return parsed.astimezone(dt.UTC)


def _iso(value: dt.datetime) -> str:
    return value.isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _positive_int(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise IntervalExportError(f"{label}: expected positive integer")
    return value


@dataclass(frozen=True)
class Trade:
    opened: dt.datetime
    closed: dt.datetime
    net: Decimal


@dataclass(frozen=True)
class Snapshot:
    observed: dt.datetime
    equity: Decimal
    day_key: int


@dataclass(frozen=True)
class Sleeve:
    sleeve_id: str
    initial_balance: Decimal
    weight: Decimal
    trades: tuple[Trade, ...]
    snapshots: tuple[Snapshot, ...]
    trade_binding: dict[str, Any]
    logger_binding: dict[str, Any]


def _jsonl(path: Path, label: str) -> list[tuple[int, Mapping[str, Any]]]:
    rows: list[tuple[int, Mapping[str, Any]]] = []
    try:
        with path.open("rb") as handle:
            for number, raw in enumerate(handle, 1):
                if number > MAX_ROWS:
                    raise IntervalExportError(f"{label}: row limit exceeded")
                if not raw.strip():
                    raise IntervalExportError(f"{label}:{number}: blank row")
                row = _loads(raw, f"{label}:{number}")
                if not isinstance(row, Mapping):
                    raise IntervalExportError(f"{label}:{number}: expected object")
                rows.append((number, row))
    except OSError as exc:
        raise IntervalExportError(f"{label}: cannot read {path}: {exc}") from exc
    return rows


def _load_trades(path: Path, label: str) -> tuple[Trade, ...]:
    trades: list[Trade] = []
    for number, row in _jsonl(path, label):
        if row.get("event") != TRADE_EVENT:
            raise IntervalExportError(f"{label}:{number}: expected {TRADE_EVENT}")
        try:
            opened = dt.datetime.fromtimestamp(int(row["entry_time"]), tz=dt.UTC)
            closed = dt.datetime.fromtimestamp(int(row["time"]), tz=dt.UTC)
        except (KeyError, TypeError, ValueError, OSError) as exc:
            raise IntervalExportError(f"{label}:{number}: invalid lifecycle timestamps") from exc
        if closed < opened:
            raise IntervalExportError(f"{label}:{number}: closes before entry")
        trades.append(Trade(opened, closed, _decimal(row.get("net"), f"{label}:{number}.net")))
    if not trades:
        raise IntervalExportError(f"{label}: no closed lifecycles")
    return tuple(sorted(trades, key=lambda item: (item.closed, item.opened)))


def _load_snapshots(path: Path, label: str) -> tuple[Snapshot, ...]:
    snapshots: list[Snapshot] = []
    for number, row in _jsonl(path, label):
        if row.get("event") != SNAPSHOT_EVENT:
            continue
        payload = row.get("payload")
        if not isinstance(payload, Mapping):
            raise IntervalExportError(f"{label}:{number}: snapshot payload missing")
        observed = _timestamp(row.get("ts_utc"), f"{label}:{number}.ts_utc")
        day_key = payload.get("day_key")
        if isinstance(day_key, bool) or not isinstance(day_key, int):
            raise IntervalExportError(f"{label}:{number}.payload.day_key: expected integer")
        snapshots.append(
            Snapshot(observed, _decimal(payload.get("equity"), f"{label}:{number}.payload.equity"), day_key)
        )
    if not snapshots:
        raise IntervalExportError(f"{label}: no {SNAPSHOT_EVENT} rows")
    snapshots.sort(key=lambda item: item.observed)
    if any(right.observed <= left.observed for left, right in zip(snapshots, snapshots[1:])):
        raise IntervalExportError(f"{label}: snapshot timestamps are not strictly increasing")
    return tuple(snapshots)


def _load_sleeve(value: Any, index: int) -> Sleeve:
    label = f"sleeves[{index}]"
    required = {"sleeve_id", "initial_balance", "weight", "trade_stream_path", "logger_path"}
    if not isinstance(value, Mapping) or set(value) != required:
        raise IntervalExportError(f"{label}: unexpected fields")
    sleeve_id = value["sleeve_id"]
    if not isinstance(sleeve_id, str) or not sleeve_id.strip():
        raise IntervalExportError(f"{label}.sleeve_id: expected non-empty string")
    initial = _decimal(value["initial_balance"], f"{label}.initial_balance")
    weight = _decimal(value["weight"], f"{label}.weight")
    if initial <= 0 or weight <= 0:
        raise IntervalExportError(f"{label}: initial_balance and weight must be positive")
    trade_path, trade_binding = _binding(value["trade_stream_path"], f"{label}.trade_stream_path")
    logger_path, logger_binding = _binding(value["logger_path"], f"{label}.logger_path")
    return Sleeve(
        sleeve_id.strip(), initial, weight,
        _load_trades(trade_path, f"{label}.trades"),
        _load_snapshots(logger_path, f"{label}.logger"),
        trade_binding, logger_binding,
    )


def _grid(start: dt.datetime, end: dt.datetime, minutes: int) -> list[dt.datetime]:
    if start.second or start.microsecond or end.second or end.microsecond:
        raise IntervalExportError("from_utc/to_utc must be exact minutes")
    if end <= start:
        raise IntervalExportError("to_utc must be after from_utc")
    step = dt.timedelta(minutes=minutes)
    span = end - start
    if span % step:
        raise IntervalExportError("window must be an exact multiple of grid_minutes")
    count = int(span / step) + 1
    if count > MAX_ROWS:
        raise IntervalExportError("output grid row limit exceeded")
    return [start + index * step for index in range(count)]


def _sleeve_point(sleeve: Sleeve, previous: dt.datetime | None, endpoint: dt.datetime) -> dict[str, Any]:
    closed_net = sum((trade.net for trade in sleeve.trades if trade.closed <= endpoint), Decimal(0))
    balance = sleeve.initial_balance + sleeve.weight * closed_net
    open_positions = sum(1 for trade in sleeve.trades if trade.opened <= endpoint < trade.closed)
    opened_positions = 0 if previous is None else sum(
        1 for trade in sleeve.trades if previous < trade.opened <= endpoint
    )
    exact = [item for item in sleeve.snapshots if item.observed == endpoint]
    within = [] if previous is None else [
        item for item in sleeve.snapshots if previous < item.observed <= endpoint
    ]
    observation = exact[-1] if exact else (within[-1] if within else None)
    return {
        "sleeve_id": sleeve.sleeve_id,
        "balance": _money(balance),
        "balance_basis": "RECONSTRUCTED_CUMULATIVE_CLOSED_NET",
        "equity": _money(observation.equity) if exact else None,
        "equity_basis": "EXACT_EVENT_AT_ENDPOINT" if exact else "MISSING_AT_ENDPOINT",
        "equity_observation": (
            None if observation is None else {
                "observed_at_utc": _iso(observation.observed),
                "equity": _money(observation.equity),
                "day_key": observation.day_key,
                "basis": (
                    "EXACT_EVENT_AT_ENDPOINT" if exact else "EXACT_EVENT_WITHIN_INTERVAL_NOT_ENDPOINT"
                ),
            }
        ),
        "interval_min_equity": None,
        "interval_min_equity_basis": "MISSING_NO_TICK_EVENT_MINIMUM",
        "open_positions": open_positions,
        "open_positions_basis": "RECONSTRUCTED_FROM_CLOSED_LIFECYCLE_INTERVALS",
        "opened_positions": opened_positions,
        "pending_orders": None,
        "pending_orders_basis": "MISSING_NOT_EXPORTED",
    }


def export_spec(spec: Any) -> dict[str, Any]:
    required = {
        "schema", "from_utc", "to_utc", "grid_minutes", "book_initial_balance",
        "currency", "sleeves",
    }
    if not isinstance(spec, Mapping) or set(spec) != required:
        raise IntervalExportError("spec: unexpected fields")
    if spec["schema"] != SPEC_SCHEMA:
        raise IntervalExportError("spec.schema: unsupported schema")
    currency = spec["currency"]
    if not isinstance(currency, str) or len(currency) != 3 or not currency.isupper():
        raise IntervalExportError("currency: expected three uppercase letters")
    start = _timestamp(spec["from_utc"], "from_utc")
    end = _timestamp(spec["to_utc"], "to_utc")
    grid_minutes = _positive_int(spec["grid_minutes"], "grid_minutes")
    book_initial = _decimal(spec["book_initial_balance"], "book_initial_balance")
    if book_initial <= 0:
        raise IntervalExportError("book_initial_balance must be positive")
    values = spec["sleeves"]
    if not isinstance(values, list) or not values:
        raise IntervalExportError("sleeves: expected non-empty list")
    sleeves = tuple(_load_sleeve(value, index) for index, value in enumerate(values))
    if len({item.sleeve_id for item in sleeves}) != len(sleeves):
        raise IntervalExportError("sleeves: duplicate sleeve_id")

    endpoints = _grid(start, end, grid_minutes)
    rows: list[dict[str, Any]] = []
    for index, endpoint in enumerate(endpoints):
        previous = endpoints[index - 1] if index else None
        points = [_sleeve_point(sleeve, previous, endpoint) for sleeve in sleeves]
        joint_delta = sum(
            sleeve.weight * sum(
                (trade.net for trade in sleeve.trades if trade.closed <= endpoint), Decimal(0)
            )
            for sleeve in sleeves
        )
        exact_equity = all(point["equity"] is not None for point in points)
        joint_equity = None
        if exact_equity:
            joint_equity = book_initial + sum(
                sleeve.weight * (
                    _decimal(point["equity"], "point.equity") - sleeve.initial_balance
                )
                for sleeve, point in zip(sleeves, points)
            )
        rows.append(
            {
                "ts_utc": _iso(endpoint),
                "interval_start_utc": None if previous is None else _iso(previous),
                "joint": {
                    "balance": _money(book_initial + joint_delta),
                    "balance_basis": "WEIGHTED_SUPERPOSITION_OF_RECONSTRUCTED_CLOSED_NET",
                    "equity": None if joint_equity is None else _money(joint_equity),
                    "equity_basis": (
                        "WEIGHTED_SUPERPOSITION_EXACT_SLEEVE_ENDPOINTS"
                        if joint_equity is not None else "MISSING_ONE_OR_MORE_SLEEVE_ENDPOINTS"
                    ),
                    "interval_min_equity": None,
                    "interval_min_equity_basis": "MISSING_NO_TICK_EVENT_MINIMUM",
                    "open_positions": sum(point["open_positions"] for point in points),
                    "open_positions_basis": "SUM_RECONSTRUCTED_CLOSED_LIFECYCLES",
                    "opened_positions": sum(point["opened_positions"] for point in points),
                    "pending_orders": None,
                    "pending_orders_basis": "MISSING_NOT_EXPORTED",
                },
                "sleeves": points,
            }
        )

    coverage = []
    for sleeve in sleeves:
        exact_count = sum(
            1 for endpoint in endpoints if any(item.observed == endpoint for item in sleeve.snapshots)
        )
        within_window = [item for item in sleeve.snapshots if start < item.observed <= end]
        coverage.append(
            {
                "sleeve_id": sleeve.sleeve_id,
                "trade_stream": sleeve.trade_binding,
                "logger": sleeve.logger_binding,
                "closed_lifecycles": len(sleeve.trades),
                "first_entry_utc": _iso(min(item.opened for item in sleeve.trades)),
                "last_close_utc": _iso(max(item.closed for item in sleeve.trades)),
                "equity_snapshots": len(sleeve.snapshots),
                "first_snapshot_utc": _iso(sleeve.snapshots[0].observed),
                "last_snapshot_utc": _iso(sleeve.snapshots[-1].observed),
                "snapshots_in_window": len(within_window),
                "exact_grid_endpoint_snapshots": exact_count,
                "balance_coverage": "RECONSTRUCTED",
                "equity_endpoint_coverage": "PARTIAL_EXACT_EVENT_TIMES_ONLY",
                "interval_min_coverage": "MISSING",
                "open_position_coverage": "RECONSTRUCTED_CLOSED_LIFECYCLES_ONLY",
                "pending_order_coverage": "MISSING",
            }
        )

    balances = [_decimal(row["joint"]["balance"], "joint.balance") for row in rows]
    return {
        "schema": OUTPUT_SCHEMA,
        "status": "ABSTAIN",
        "ftmo_readiness": {
            "daily_loss": "ABSTAIN_MISSING_INTERVAL_MIN_EQUITY",
            "flat_at_target": "ABSTAIN_MISSING_PENDING_ORDERS_AND_ENDPOINT_EQUITY",
            "challenge_proof": False,
        },
        "currency": currency,
        "window": {
            "from_utc": _iso(start), "to_utc": _iso(end),
            "grid_minutes": grid_minutes, "rows": len(rows),
        },
        "book_initial_balance": _money(book_initial),
        "closed_balance_diagnostic": {
            "minimum": _money(min(balances)), "maximum": _money(max(balances)),
            "final": _money(balances[-1]),
            "not_a_daily_loss_or_target_pass_test": True,
        },
        "coverage": coverage,
        "rows": rows,
    }


def _json_default(value: Any) -> Any:
    if isinstance(value, Decimal):
        return format(value, "f")
    raise TypeError(type(value).__name__)


def _write_atomic(path: Path, value: Any) -> str:
    target = path.expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, sort_keys=True, indent=2, allow_nan=False, default=_json_default) + "\n").encode("utf-8")
    handle, temporary = tempfile.mkstemp(prefix=target.name + ".", suffix=".tmp", dir=target.parent)
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return hashlib.sha256(payload).hexdigest()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        spec_path, binding = _binding(str(args.spec), "spec")
        spec = _loads(spec_path.read_bytes(), "spec")
        result = export_spec(spec)
        result["spec"] = binding
        digest = _write_atomic(args.output, result)
        print(json.dumps({"status": result["status"], "path": str(args.output.resolve()), "sha256": digest}))
        return 0
    except IntervalExportError as exc:
        print(json.dumps({"status": "REFUSED", "error": str(exc)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
