"""Strict, content-addressed FTMO standalone-event replay (V1).

The joint QM5_20181 run is not accepted as strategy truth because its timer
scheduling has already been shown to change at least one sleeve's trades.  This
module therefore replays one native standalone MT5 export per sleeve, validates
that export against immutable receipts, and only then combines the normalized
PnL paths on one synthetic account.

V1 deliberately does *not* claim book readiness.  Historical market-session /
holiday proof and event-complete margin replay are represented by explicit
qualification blockers.  Missing or inconsistent execution, price, cost,
position, pending-order, swap, checkpoint, receipt, or sizing evidence raises a
fail-closed contract error instead of being inferred.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation, ROUND_HALF_EVEN
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo
import datetime as dt

try:  # pragma: no cover - direct-script fallback
    from . import ftmo_rules_engine as rules_engine
except ImportError:  # pragma: no cover
    import ftmo_rules_engine as rules_engine  # type: ignore


MANIFEST_SCHEMA = "FTMO_EVENT_COMPLETE_REPLAY_MANIFEST_V1"
SYMBOL_PROPERTIES_SCHEMA = "FTMO_SYMBOL_PROPERTIES_V1"
SIZING_SCHEMA = "FTMO_BOOK_SIZING_POLICY_V1"
TICK_SCHEMA = "FTMO_TICK_V1"
ORDER_SCHEMA = "FTMO_ORDER_EVENT_V1"
DEAL_SCHEMA = "FTMO_DEAL_V1"
ACCOUNT_EVENT_SCHEMA = "FTMO_ACCOUNT_EVENT_V1"
CHECKPOINT_SCHEMA = "FTMO_ACCOUNT_CHECKPOINT_V1"
MODIFICATION_SCHEMA = "FTMO_POSITION_MODIFICATION_V1"
HISTORY_COMPLETE_SCHEMA = "FTMO_STANDALONE_HISTORY_COMPLETE_V1"
OUTPUT_SCHEMA = "FTMO_EVENT_COMPLETE_REPLAY_RESULT_V1"

PRAGUE = ZoneInfo("Europe/Prague")
NEW_YORK = ZoneInfo("America/New_York")
TIMESTAMP_BASIS = "DARWINEX_US_DST_BROKER_WALL_EPOCH"
_SHA_RE = re.compile(r"^[0-9a-f]{64}$")
_CURRENCY_RE = re.compile(r"^[A-Z]{3}$")
_PENDING_ORDER_TYPES = frozenset(
    {
        "BUY_LIMIT",
        "SELL_LIMIT",
        "BUY_STOP",
        "SELL_STOP",
        "BUY_STOP_LIMIT",
        "SELL_STOP_LIMIT",
    }
)
_ORDER_TYPES = _PENDING_ORDER_TYPES | {"BUY", "SELL"}
_ORDER_EVENTS = frozenset(
    {"PLACED", "MODIFIED", "PARTIAL_FILL", "FILLED", "CANCELLED", "EXPIRED"}
)
_TERMINAL_ORDER_EVENTS = frozenset({"FILLED", "CANCELLED", "EXPIRED"})
_DEAL_REASONS = frozenset({"EXPERT", "SL", "TP", "STOP_OUT"})
_GLOBAL_ROLES = frozenset(
    {
        "tester_binary",
        "custom_symbol_db",
        "rules_snapshot",
        "cost_model",
        "news_calendar",
        "market_sessions",
        "symbol_properties",
        "sizing_policy",
        "tick_set_complete",
    }
)
_SLEEVE_ROLES = frozenset(
    {
        "ea_binary",
        "setfile",
        "tester_report",
        "hcc",
        "tkc",
        "ticks",
        "tick_chunks",
        "tick_complete",
        "orders",
        "deals",
        "account_events",
        "checkpoints",
        "history_complete",
        "modifications",
        "execution_manifest",
        "prague_midnight_proof",
    }
)


class ReplayContractError(ValueError):
    """Base class for evidence that cannot support a replay."""

    status = "SETUP_DATA_INVALID"

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


class ReplayDataMissing(ReplayContractError):
    status = "SETUP_DATA_MISSING"


class ReplayDataInvalid(ReplayContractError):
    status = "SETUP_DATA_INVALID"


@dataclass(frozen=True)
class ArtifactBinding:
    role: str
    symbol: str | None
    path: str
    sha256: str

    @property
    def key(self) -> tuple[str, str | None]:
        return self.role, self.symbol


@dataclass(frozen=True)
class BoundSnapshot:
    binding: ArtifactBinding
    resolved_path: Path
    payload: bytes
    sha256: str


@dataclass(frozen=True)
class Sleeve:
    sleeve_id: str
    symbol: str
    run_id: str
    magic: int
    native_initial_balance: Decimal
    scale: Decimal


@dataclass(frozen=True)
class SymbolSpec:
    symbol: str
    calc_mode: str
    contract_size: Decimal
    tick_size: Decimal
    tick_value: Decimal
    profit_currency: str
    account_currency: str
    conversion_mode: str
    swap_mode: str


@dataclass(frozen=True)
class Tick:
    time_msc: int
    source_sequence: int
    bid: Decimal
    ask: Decimal
    last: Decimal


@dataclass(frozen=True)
class OrderEvent:
    time_msc: int
    source_sequence: int
    order_id: int
    position_id: int | None
    event: str
    order_type: str
    volume_initial: Decimal
    volume_remaining: Decimal
    price: Decimal
    stop_limit: Decimal
    sl: Decimal
    tp: Decimal


@dataclass(frozen=True)
class Deal:
    time_msc: int
    source_sequence: int
    deal_id: int
    order_id: int
    position_id: int
    entry: str
    side: str
    execution_mode: str
    reason: str
    volume: Decimal
    price: Decimal
    profit: Decimal
    commission: Decimal
    swap: Decimal
    fee: Decimal


@dataclass(frozen=True)
class AccountEvent:
    time_msc: int
    source_sequence: int
    event_id: str
    position_id: int
    amount: Decimal


@dataclass(frozen=True)
class Checkpoint:
    time_msc: int
    source_sequence: int
    kind: str
    deal_ids: tuple[int, ...]
    balance: Decimal
    equity: Decimal
    open_positions: int
    pending_orders: int
    position_swaps: tuple[tuple[int, Decimal], ...]
    margin: Decimal
    margin_free: Decimal
    margin_level: Decimal
    account_leverage: int
    account_currency: str
    account_margin_mode: int


@dataclass
class Position:
    side: str
    symbol: str
    magic: int
    volume: Decimal
    average_price: Decimal
    swap_mark: Decimal = Decimal("0")


@dataclass(frozen=True)
class SleeveReplay:
    trace: rules_engine.NormalizedTrace
    max_margin_reported: Decimal
    min_margin_free_reported: Decimal
    modification_observation_complete: bool
    position_modifications_present: bool
    input_fingerprint_sha256: str


@dataclass(frozen=True)
class ReplayProduct:
    manifest_id: str
    manifest_sha256: str
    source_fingerprint_sha256: str
    trace: rules_engine.NormalizedTrace | None
    artifacts: tuple[ArtifactBinding, ...]
    sleeves: tuple[SleeveReplay, ...]
    qualification_blockers: tuple[str, ...]

    @property
    def book_ready(self) -> bool:
        return not self.qualification_blockers

    def as_document(self) -> dict[str, Any]:
        return {
            "schema": OUTPUT_SCHEMA,
            "status": (
                "BOOK_READY_REPLAY" if self.book_ready else "REPLAY_COMPLETE_BLOCKED"
            ),
            "book_ready": self.book_ready,
            "challenge_proof": False,
            "manifest_id": self.manifest_id,
            "manifest_sha256": self.manifest_sha256,
            "source_fingerprint_sha256": self.source_fingerprint_sha256,
            "qualification_blockers": list(self.qualification_blockers),
            "input_artifacts": [
                {
                    "role": item.role,
                    "symbol": item.symbol,
                    "path": item.path,
                    "sha256": item.sha256,
                }
                for item in self.artifacts
            ],
            "sleeve_reconciliation": [
                {
                    "trace_id": item.trace.trace_id,
                    "source_fingerprint_sha256": item.input_fingerprint_sha256,
                    "max_margin_reported": _money_text(item.max_margin_reported, 2),
                    "min_margin_free_reported": _money_text(
                        item.min_margin_free_reported, 2
                    ),
                    "modification_observation_complete": (
                        item.modification_observation_complete
                    ),
                    "position_modifications_present": (
                        item.position_modifications_present
                    ),
                }
                for item in self.sleeves
            ],
            "trace": None if self.trace is None else _trace_document(self.trace),
        }


def _duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    output: dict[str, Any] = {}
    for key, value in pairs:
        if key in output:
            raise ReplayDataInvalid(f"json_duplicate_key:{key}")
        output[key] = value
    return output


def _read_once(path: Path, label: str) -> bytes:
    try:
        return path.read_bytes()
    except FileNotFoundError as exc:
        raise ReplayDataMissing(f"{label}_missing") from exc
    except OSError as exc:
        raise ReplayDataInvalid(f"{label}_unreadable:{type(exc).__name__}") from exc


def _json(payload: bytes, label: str) -> dict[str, Any]:
    try:
        text = payload.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ReplayDataInvalid(f"{label}_utf8_invalid") from exc
    try:
        result = json.loads(text, object_pairs_hook=_duplicate_keys)
    except json.JSONDecodeError as exc:
        raise ReplayDataInvalid(f"{label}_json_invalid") from exc
    if not isinstance(result, dict):
        raise ReplayDataInvalid(f"{label}_not_object")
    return result


def _jsonl(payload: bytes, label: str) -> list[dict[str, Any]]:
    try:
        text = payload.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ReplayDataInvalid(f"{label}_utf8_invalid") from exc
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line, object_pairs_hook=_duplicate_keys)
        except json.JSONDecodeError as exc:
            raise ReplayDataInvalid(f"{label}_json_invalid:{line_number}") from exc
        if not isinstance(row, dict):
            raise ReplayDataInvalid(f"{label}_row_not_object:{line_number}")
        rows.append(row)
    return rows


def _canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _require_sha(value: Any, label: str) -> str:
    raw = str(value or "").strip().lower()
    if not _SHA_RE.fullmatch(raw):
        raise ReplayDataInvalid(f"{label}_sha256_invalid")
    return raw


def _require_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value or value != value.strip():
        raise ReplayDataInvalid(f"{label}_invalid")
    return value


def _require_bool(value: Any, label: str) -> bool:
    if not isinstance(value, bool):
        raise ReplayDataInvalid(f"{label}_invalid")
    return value


def _integer(value: Any, label: str, *, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise ReplayDataInvalid(f"{label}_invalid")
    return value


def _decimal(value: Any, label: str, *, positive: bool = False) -> Decimal:
    if isinstance(value, bool) or value is None:
        raise ReplayDataInvalid(f"{label}_invalid")
    try:
        result = Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise ReplayDataInvalid(f"{label}_invalid") from exc
    if not result.is_finite() or (positive and result <= 0):
        raise ReplayDataInvalid(f"{label}_invalid")
    return result


def _money(value: Any, label: str, decimals: int) -> Decimal:
    result = _decimal(value, label)
    quantum = Decimal(1).scaleb(-decimals)
    if result.quantize(quantum) != result:
        raise ReplayDataInvalid(f"{label}_precision_exceeds_{decimals}")
    return result


def _money_text(value: Decimal, decimals: int) -> str:
    return format(value, f".{decimals}f")


def _at_cent(value: Decimal, decimals: int) -> Decimal:
    return value.quantize(Decimal(1).scaleb(-decimals), rounding=ROUND_HALF_EVEN)


def _assert_identity(row: Mapping[str, Any], sleeve: Sleeve, label: str) -> None:
    if row.get("run_id") != sleeve.run_id:
        raise ReplayDataInvalid(f"{label}_run_id_mismatch")
    if row.get("symbol") != sleeve.symbol:
        raise ReplayDataInvalid(f"{label}_foreign_symbol")
    if row.get("magic") != sleeve.magic:
        raise ReplayDataInvalid(f"{label}_magic_mismatch")


def broker_wall_msc_to_utc_msc(value: Any, label: str = "time_msc") -> int:
    """Decode a Darwinex GMT+2/+3 wall-clock epoch without guessing DST folds."""

    raw = _integer(value, label)
    valid: list[int] = []
    for offset_hours in (2, 3):
        candidate = raw - offset_hours * 3_600_000
        instant = dt.datetime(1970, 1, 1, tzinfo=dt.UTC) + dt.timedelta(
            milliseconds=candidate
        )
        expected = 3 if instant.astimezone(NEW_YORK).dst() not in {
            None,
            dt.timedelta(0),
        } else 2
        if expected == offset_hours:
            valid.append(candidate)
    if len(valid) != 1:
        reason = "ambiguous" if len(valid) > 1 else "nonexistent"
        raise ReplayDataInvalid(f"broker_wall_time_{reason}:{label}:{raw}")
    return valid[0]


def _artifact_map(
    manifest: Mapping[str, Any], manifest_dir: Path
) -> tuple[tuple[ArtifactBinding, ...], dict[tuple[str, str | None], BoundSnapshot]]:
    raw = manifest.get("artifacts")
    if not isinstance(raw, list):
        raise ReplayDataMissing("manifest_artifacts_missing")
    bindings: list[ArtifactBinding] = []
    seen_keys: set[tuple[str, str | None]] = set()
    seen_paths: set[str] = set()
    for index, item in enumerate(raw):
        if not isinstance(item, Mapping):
            raise ReplayDataInvalid(f"artifact_invalid:{index}")
        role = _require_string(item.get("role"), f"artifact_role:{index}")
        symbol_raw = item.get("symbol")
        symbol = None if symbol_raw is None else _require_string(
            symbol_raw, f"artifact_symbol:{index}"
        )
        path = _require_string(item.get("path"), f"artifact_path:{index}")
        digest = _require_sha(item.get("sha256"), f"artifact:{role}")
        binding = ArtifactBinding(role, symbol, path, digest)
        if binding.key in seen_keys:
            raise ReplayDataInvalid(f"artifact_binding_duplicate:{role}:{symbol}")
        seen_keys.add(binding.key)
        bindings.append(binding)

    snapshots: dict[tuple[str, str | None], BoundSnapshot] = {}
    for binding in sorted(bindings, key=lambda value: (value.role, value.symbol or "")):
        candidate = Path(binding.path)
        resolved = (manifest_dir / candidate).resolve() if not candidate.is_absolute() else candidate.resolve()
        normalized_path = str(resolved).casefold()
        if normalized_path in seen_paths:
            raise ReplayDataInvalid(f"artifact_path_reused:{binding.role}:{binding.symbol}")
        seen_paths.add(normalized_path)
        payload = _read_once(resolved, f"artifact:{binding.role}:{binding.symbol}")
        actual = _sha(payload)
        if actual != binding.sha256:
            raise ReplayDataInvalid(
                f"artifact_hash_mismatch:{binding.role}:{binding.symbol}:{actual}"
            )
        snapshots[binding.key] = BoundSnapshot(binding, resolved, payload, actual)
    return tuple(sorted(bindings, key=lambda value: (value.role, value.symbol or ""))), snapshots


def _snapshot(
    snapshots: Mapping[tuple[str, str | None], BoundSnapshot],
    role: str,
    symbol: str | None = None,
) -> BoundSnapshot:
    try:
        return snapshots[(role, symbol)]
    except KeyError as exc:
        raise ReplayDataMissing(f"artifact_role_missing:{role}:{symbol}") from exc


def _parse_sleeves(
    manifest: Mapping[str, Any], sizing: Mapping[str, Any], decimals: int
) -> tuple[Sleeve, ...]:
    if sizing.get("schema") != SIZING_SCHEMA:
        raise ReplayDataInvalid("sizing_schema_invalid")
    if sizing.get("normalization_basis") != (
        "PNL_DELTA_FROM_RECONCILED_STANDALONE_INITIAL_BALANCE"
    ):
        raise ReplayDataInvalid("sizing_normalization_basis_invalid")
    synthetic = _money(sizing.get("synthetic_initial_balance"), "sizing_initial", decimals)
    if synthetic != _money(manifest.get("initial_balance"), "manifest_initial", decimals):
        raise ReplayDataInvalid("sizing_synthetic_initial_balance_mismatch")
    raw_manifest = manifest.get("sleeves")
    raw_sizing = sizing.get("sleeves")
    if not isinstance(raw_manifest, list) or not isinstance(raw_sizing, list):
        raise ReplayDataMissing("sleeves_missing")

    def parse(row: Any, index: int, prefix: str) -> Sleeve:
        if not isinstance(row, Mapping):
            raise ReplayDataInvalid(f"{prefix}_sleeve_invalid:{index}")
        return Sleeve(
            sleeve_id=_require_string(row.get("sleeve_id"), f"{prefix}_sleeve_id:{index}"),
            symbol=_require_string(row.get("symbol"), f"{prefix}_symbol:{index}"),
            run_id=_require_string(row.get("run_id"), f"{prefix}_run_id:{index}"),
            magic=_integer(row.get("magic"), f"{prefix}_magic:{index}", minimum=1),
            native_initial_balance=_money(
                row.get("native_initial_balance"), f"{prefix}_native_initial:{index}", decimals
            ),
            scale=_decimal(row.get("scale"), f"{prefix}_scale:{index}"),
        )

    manifest_sleeves = tuple(parse(row, i, "manifest") for i, row in enumerate(raw_manifest))
    sizing_sleeves = tuple(parse(row, i, "sizing") for i, row in enumerate(raw_sizing))
    if not manifest_sleeves:
        raise ReplayDataInvalid("sleeves_empty")
    if manifest_sleeves != sizing_sleeves:
        raise ReplayDataInvalid("sizing_sleeves_mismatch")
    if any(item.scale < 0 for item in manifest_sleeves) or not any(
        item.scale > 0 for item in manifest_sleeves
    ):
        raise ReplayDataInvalid("sizing_scales_invalid")
    for field_name, values in {
        "sleeve_id": [item.sleeve_id for item in manifest_sleeves],
        "symbol": [item.symbol for item in manifest_sleeves],
        "run_id": [item.run_id for item in manifest_sleeves],
        "magic": [item.magic for item in manifest_sleeves],
    }.items():
        if len(values) != len(set(values)):
            raise ReplayDataInvalid(f"sleeve_{field_name}_duplicate")
    return tuple(sorted(manifest_sleeves, key=lambda item: item.sleeve_id))


def _symbol_specs(
    payload: bytes, sleeves: Sequence[Sleeve], account_currency: str
) -> tuple[dict[str, SymbolSpec], int, int]:
    document = _json(payload, "symbol_properties")
    if document.get("schema") != SYMBOL_PROPERTIES_SCHEMA:
        raise ReplayDataInvalid("symbol_properties_schema_invalid")
    if document.get("account_currency") != account_currency:
        raise ReplayDataInvalid("symbol_properties_account_currency_mismatch")
    expected_leverage = _integer(
        document.get("expected_account_leverage"),
        "symbol_properties_expected_account_leverage",
        minimum=1,
    )
    expected_margin_mode = _integer(
        document.get("expected_account_margin_mode"),
        "symbol_properties_expected_account_margin_mode",
    )
    raw = document.get("symbols")
    if not isinstance(raw, list):
        raise ReplayDataMissing("symbol_properties_symbols_missing")
    output: dict[str, SymbolSpec] = {}
    for index, item in enumerate(raw):
        if not isinstance(item, Mapping):
            raise ReplayDataInvalid(f"symbol_properties_row_invalid:{index}")
        symbol = _require_string(item.get("symbol"), f"symbol:{index}")
        calc_mode = _require_string(item.get("calc_mode"), f"calc_mode:{symbol}")
        conversion = _require_string(
            item.get("conversion_mode"), f"conversion_mode:{symbol}"
        )
        if calc_mode not in {"FOREX", "CFD_LINEAR"}:
            raise ReplayDataInvalid(f"unsupported_calc_mode:{symbol}:{calc_mode}")
        if conversion not in {"IDENTITY", "FOREX_QUOTE_ACCOUNT_INVERSE"}:
            raise ReplayDataInvalid(f"unsupported_conversion:{symbol}:{conversion}")
        spec = SymbolSpec(
            symbol=symbol,
            calc_mode=calc_mode,
            contract_size=_decimal(item.get("contract_size"), f"contract_size:{symbol}", positive=True),
            tick_size=_decimal(item.get("tick_size"), f"tick_size:{symbol}", positive=True),
            tick_value=_decimal(item.get("tick_value"), f"tick_value:{symbol}", positive=True),
            profit_currency=_require_string(item.get("profit_currency"), f"profit_currency:{symbol}"),
            account_currency=_require_string(item.get("account_currency"), f"account_currency:{symbol}"),
            conversion_mode=conversion,
            swap_mode=str(_integer(item.get("swap_mode"), f"swap_mode:{symbol}")),
        )
        if spec.account_currency != account_currency:
            raise ReplayDataInvalid(f"symbol_account_currency_mismatch:{symbol}")
        if conversion == "IDENTITY" and spec.profit_currency != account_currency:
            raise ReplayDataInvalid(f"identity_conversion_currency_mismatch:{symbol}")
        if symbol in output:
            raise ReplayDataInvalid(f"symbol_properties_duplicate:{symbol}")
        output[symbol] = spec
    expected = {item.symbol for item in sleeves}
    if set(output) != expected:
        raise ReplayDataInvalid("symbol_properties_membership_mismatch")
    return output, expected_leverage, expected_margin_mode


def _stream_rows(
    snapshot: BoundSnapshot,
    schema: str,
    sleeve: Sleeve,
    label: str,
) -> list[dict[str, Any]]:
    rows = _jsonl(snapshot.payload, label)
    for index, row in enumerate(rows):
        if row.get("schema") != schema:
            raise ReplayDataInvalid(f"{label}_schema_invalid:{index}")
        _assert_identity(row, sleeve, f"{label}:{index}")
        if row.get("time_basis") != TIMESTAMP_BASIS:
            raise ReplayDataInvalid(f"{label}_time_basis_mismatch:{index}")
    return rows


def _parse_ticks(
    snapshots: Mapping[tuple[str, str | None], BoundSnapshot],
    sleeve: Sleeve,
    start: int,
    end: int,
    tick_run_id: str,
) -> tuple[Tick, ...]:
    tick_snapshot = _snapshot(snapshots, "ticks", sleeve.symbol)
    rows = _jsonl(tick_snapshot.payload, f"ticks:{sleeve.symbol}")
    ticks: list[Tick] = []
    raw_tick_times: list[int] = []
    previous: tuple[int, int] | None = None
    for index, row in enumerate(rows):
        if row.get("schema") != TICK_SCHEMA:
            raise ReplayDataInvalid(f"tick_schema_invalid:{sleeve.symbol}:{index}")
        if row.get("symbol") != sleeve.symbol:
            raise ReplayDataInvalid(f"tick_foreign_symbol:{sleeve.symbol}:{index}")
        time_msc = _integer(row.get("time_msc"), f"tick_time:{sleeve.symbol}:{index}")
        sequence = _integer(row.get("source_sequence"), f"tick_sequence:{sleeve.symbol}:{index}")
        key = (time_msc, sequence)
        if previous is not None and key <= previous:
            raise ReplayDataInvalid(f"tick_stream_nonmonotone:{sleeve.symbol}:{index}")
        previous = key
        raw_tick_times.append(time_msc)
        bid = _decimal(row.get("bid"), f"tick_bid:{sleeve.symbol}:{index}", positive=True)
        ask = _decimal(row.get("ask"), f"tick_ask:{sleeve.symbol}:{index}", positive=True)
        last = _decimal(row.get("last"), f"tick_last:{sleeve.symbol}:{index}")
        if last < 0:
            raise ReplayDataInvalid(f"tick_last_negative:{sleeve.symbol}:{index}")
        if bid > ask:
            raise ReplayDataInvalid(f"tick_crossed_market:{sleeve.symbol}:{index}")
        if not start <= time_msc < end:
            raise ReplayDataInvalid(f"tick_outside_range:{sleeve.symbol}:{index}")
        ticks.append(
            Tick(
                broker_wall_msc_to_utc_msc(
                    time_msc, f"tick_time:{sleeve.symbol}:{index}"
                ),
                sequence,
                bid,
                ask,
                last,
            )
        )
    if not ticks:
        raise ReplayDataMissing(f"ticks_empty:{sleeve.symbol}")
    chunks_snapshot = _snapshot(snapshots, "tick_chunks", sleeve.symbol)
    chunk_rows = _jsonl(chunks_snapshot.payload, f"tick_chunks:{sleeve.symbol}")
    if not chunk_rows:
        raise ReplayDataMissing(f"tick_chunks_empty:{sleeve.symbol}")
    expected_from = start
    total = 0
    tick_cursor = 0
    for index, row in enumerate(chunk_rows):
        if row.get("event") != "TICK_CHUNK" or row.get("schema_version") != 1 or row.get("symbol") != sleeve.symbol:
            raise ReplayDataInvalid(f"tick_chunk_identity_invalid:{sleeve.symbol}:{index}")
        if row.get("run_id") != tick_run_id:
            raise ReplayDataInvalid(f"tick_chunk_run_id_mismatch:{sleeve.symbol}:{index}")
        if row.get("time_basis") != TIMESTAMP_BASIS:
            raise ReplayDataInvalid(f"tick_chunk_time_basis_mismatch:{sleeve.symbol}:{index}")
        if _integer(row.get("chunk_index"), "chunk_index") != index:
            raise ReplayDataInvalid(f"tick_chunk_sequence_invalid:{sleeve.symbol}:{index}")
        from_msc = _integer(row.get("from_msc"), "chunk_from")
        to_msc = _integer(row.get("to_msc_exclusive"), "chunk_to")
        if from_msc != expected_from or to_msc < from_msc:
            raise ReplayDataInvalid(f"tick_chunk_chain_invalid:{sleeve.symbol}:{index}")
        if row.get("copy_status") != "COPY_RANGE_COMPLETE":
            raise ReplayDataInvalid(f"tick_chunk_copy_incomplete:{sleeve.symbol}:{index}")
        coverage_status = row.get("market_coverage_status")
        if coverage_status not in {"OBSERVED_TICKS_PRESENT", "REQUIRES_CLOSED_MARKET_PROOF"}:
            raise ReplayDataInvalid(f"tick_chunk_market_status_invalid:{sleeve.symbol}:{index}")
        expected_from = to_msc
        declared_count = _integer(row.get("tick_count"), "chunk_tick_count")
        chunk_start_cursor = tick_cursor
        while tick_cursor < len(raw_tick_times) and raw_tick_times[tick_cursor] < to_msc:
            if raw_tick_times[tick_cursor] < from_msc:
                raise ReplayDataInvalid(
                    f"tick_outside_chunk_chain:{sleeve.symbol}:{index}"
                )
            tick_cursor += 1
        actual_count = tick_cursor - chunk_start_cursor
        if declared_count != actual_count:
            raise ReplayDataInvalid(
                f"tick_chunk_count_mismatch:{sleeve.symbol}:{index}"
            )
        expected_coverage_status = (
            "REQUIRES_CLOSED_MARKET_PROOF"
            if declared_count == 0
            else "OBSERVED_TICKS_PRESENT"
        )
        if coverage_status != expected_coverage_status:
            raise ReplayDataInvalid(
                f"tick_chunk_market_status_count_mismatch:{sleeve.symbol}:{index}"
            )
        total += declared_count
    if chunk_rows[-1]["to_msc_exclusive"] != end or total != len(ticks):
        raise ReplayDataInvalid(f"tick_chunk_coverage_mismatch:{sleeve.symbol}")
    if tick_cursor != len(raw_tick_times):
        raise ReplayDataInvalid(f"tick_after_chunk_chain:{sleeve.symbol}")

    complete = _json(
        _snapshot(snapshots, "tick_complete", sleeve.symbol).payload,
        f"tick_complete:{sleeve.symbol}",
    )
    if complete.get("event") != "TICK_RAW_COPY_COMPLETE" or complete.get("schema_version") != 1 or complete.get("symbol") != sleeve.symbol:
        raise ReplayDataInvalid(f"tick_complete_identity_invalid:{sleeve.symbol}")
    if complete.get("run_id") != tick_run_id:
        raise ReplayDataInvalid(f"tick_complete_run_id_mismatch:{sleeve.symbol}")
    if complete.get("time_basis") != TIMESTAMP_BASIS:
        raise ReplayDataInvalid(f"tick_complete_time_basis_mismatch:{sleeve.symbol}")
    if not _require_bool(complete.get("raw_copy_complete"), "tick_raw_copy_complete"):
        raise ReplayDataInvalid(f"tick_export_incomplete:{sleeve.symbol}")
    if _require_bool(complete.get("market_coverage_complete"), "tick_market_coverage_complete"):
        raise ReplayDataInvalid(f"tick_complete_overclaims_market_coverage:{sleeve.symbol}")
    if complete.get("from_msc") != start or complete.get("to_msc_exclusive") != end:
        raise ReplayDataInvalid(f"tick_complete_range_mismatch:{sleeve.symbol}")
    if complete.get("chunk_count") != len(chunk_rows) or complete.get("tick_count") != len(ticks):
        raise ReplayDataInvalid(f"tick_complete_count_mismatch:{sleeve.symbol}")
    return tuple(ticks)


def _parse_orders(rows: Sequence[Mapping[str, Any]], sleeve: Sleeve) -> tuple[OrderEvent, ...]:
    output: list[OrderEvent] = []
    previous: tuple[int, int] | None = None
    for index, row in enumerate(rows):
        time_msc = _integer(row.get("time_msc"), f"order_time:{index}")
        sequence = _integer(row.get("source_sequence"), f"order_sequence:{index}")
        key = (time_msc, sequence)
        if previous is not None and key <= previous:
            raise ReplayDataInvalid(f"order_stream_nonmonotone:{sleeve.symbol}:{index}")
        previous = key
        event = _require_string(row.get("event"), f"order_event:{index}")
        order_type = _require_string(row.get("type"), f"order_type:{index}")
        if event not in _ORDER_EVENTS:
            raise ReplayDataInvalid(f"unsupported_order_event:{event}")
        if order_type not in _ORDER_TYPES:
            raise ReplayDataInvalid(f"unsupported_order_type:{order_type}")
        position_raw = row.get("position_id")
        position_id = None if position_raw is None else _integer(position_raw, f"order_position:{index}", minimum=1)
        output.append(
            OrderEvent(
                time_msc=broker_wall_msc_to_utc_msc(time_msc, f"order_time:{index}"),
                source_sequence=sequence,
                order_id=_integer(row.get("order_id"), f"order_id:{index}", minimum=1),
                position_id=position_id,
                event=event,
                order_type=order_type,
                volume_initial=_decimal(row.get("volume_initial"), f"order_volume_initial:{index}", positive=True),
                volume_remaining=_decimal(row.get("volume_remaining"), f"order_volume_remaining:{index}"),
                price=_decimal(row.get("price"), f"order_price:{index}", positive=True),
                stop_limit=_decimal(row.get("stop_limit", 0), f"order_stop_limit:{index}"),
                sl=_decimal(row.get("sl", 0), f"order_sl:{index}"),
                tp=_decimal(row.get("tp", 0), f"order_tp:{index}"),
            )
        )
        if output[-1].volume_remaining < 0 or output[-1].stop_limit < 0 or output[-1].sl < 0 or output[-1].tp < 0:
            raise ReplayDataInvalid(f"order_nonnegative_field_invalid:{index}")
    return tuple(output)


def _parse_deals(
    rows: Sequence[Mapping[str, Any]], sleeve: Sleeve, decimals: int
) -> tuple[Deal, ...]:
    output: list[Deal] = []
    previous: tuple[int, int] | None = None
    ids: set[int] = set()
    for index, row in enumerate(rows):
        time_msc = _integer(row.get("time_msc"), f"deal_time:{index}")
        sequence = _integer(row.get("source_sequence"), f"deal_sequence:{index}")
        key = (time_msc, sequence)
        if previous is not None and key <= previous:
            raise ReplayDataInvalid(f"deal_stream_nonmonotone:{sleeve.symbol}:{index}")
        previous = key
        deal_id = _integer(row.get("deal_id"), f"deal_id:{index}", minimum=1)
        if deal_id in ids:
            raise ReplayDataInvalid(f"deal_id_duplicate:{sleeve.symbol}:{deal_id}")
        ids.add(deal_id)
        entry = _require_string(row.get("entry"), f"deal_entry:{index}")
        side = _require_string(row.get("side"), f"deal_side:{index}")
        mode = _require_string(row.get("execution_mode"), f"deal_mode:{index}")
        reason = _require_string(row.get("reason"), f"deal_reason:{index}")
        if entry not in {"IN", "OUT"}:
            raise ReplayDataInvalid(f"unsupported_deal_entry:{entry}")
        if side not in {"BUY", "SELL"}:
            raise ReplayDataInvalid(f"unsupported_deal_side:{side}")
        if mode not in {"MARKET", "PENDING"}:
            raise ReplayDataInvalid(f"unsupported_execution_mode:{mode}")
        if reason not in _DEAL_REASONS:
            raise ReplayDataInvalid(f"unsupported_deal_reason:{reason}")
        output.append(
            Deal(
                time_msc=broker_wall_msc_to_utc_msc(time_msc, f"deal_time:{index}"),
                source_sequence=sequence,
                deal_id=deal_id,
                order_id=_integer(row.get("order_id"), f"deal_order:{index}", minimum=1),
                position_id=_integer(row.get("position_id"), f"deal_position:{index}", minimum=1),
                entry=entry,
                side=side,
                execution_mode=mode,
                reason=reason,
                volume=_decimal(row.get("volume"), f"deal_volume:{index}", positive=True),
                price=_decimal(row.get("price"), f"deal_price:{index}", positive=True),
                profit=_money(row.get("profit"), f"deal_profit:{index}", decimals),
                commission=_money(row.get("commission"), f"deal_commission:{index}", decimals),
                swap=_money(row.get("swap"), f"deal_swap:{index}", decimals),
                fee=_money(row.get("fee"), f"deal_fee:{index}", decimals),
            )
        )
    return tuple(output)


def _parse_account_events(
    rows: Sequence[Mapping[str, Any]], sleeve: Sleeve, decimals: int
) -> tuple[AccountEvent, ...]:
    output: list[AccountEvent] = []
    previous: tuple[int, int] | None = None
    ids: set[str] = set()
    for index, row in enumerate(rows):
        time_msc = _integer(row.get("time_msc"), f"account_time:{index}")
        sequence = _integer(row.get("source_sequence"), f"account_sequence:{index}")
        key = (time_msc, sequence)
        if previous is not None and key <= previous:
            raise ReplayDataInvalid(f"account_stream_nonmonotone:{sleeve.symbol}:{index}")
        previous = key
        if row.get("kind") != "POSITION_SWAP_MARK":
            raise ReplayDataInvalid(f"unsupported_account_event:{row.get('kind')}")
        if row.get("effective_time_msc") is not None or row.get(
            "effective_time_basis"
        ) != "UNRESOLVED_EXTERNAL_PRAGUE_RECONCILIATION_REQUIRED":
            raise ReplayDataInvalid(f"account_swap_effective_time_overclaim:{index}")
        event_id = str(row.get("event_id", "")).strip()
        if not event_id or event_id in ids:
            raise ReplayDataInvalid(f"account_event_id_invalid:{index}")
        ids.add(event_id)
        output.append(
            AccountEvent(
                time_msc=broker_wall_msc_to_utc_msc(time_msc, f"account_time:{index}"),
                source_sequence=sequence,
                event_id=event_id,
                position_id=_integer(row.get("position_id"), f"account_position:{index}", minimum=1),
                amount=_money(row.get("amount"), f"account_amount:{index}", decimals),
            )
        )
    return tuple(output)


def _validate_modifications(
    rows: Sequence[Mapping[str, Any]], sleeve: Sleeve, deals: Sequence[Deal]
) -> bool:
    deal_map = {item.deal_id: item for item in deals}
    previous: tuple[int, int] | None = None
    modification_ids: set[str] = set()
    for index, row in enumerate(rows):
        raw_time = _integer(row.get("time_msc"), f"modification_time:{index}")
        sequence = _integer(row.get("source_sequence"), f"modification_sequence:{index}")
        key = (raw_time, sequence)
        if previous is not None and key <= previous:
            raise ReplayDataInvalid(f"modification_stream_nonmonotone:{sleeve.symbol}:{index}")
        previous = key
        if row.get("time_basis") != TIMESTAMP_BASIS:
            raise ReplayDataInvalid(f"modification_time_basis_mismatch:{index}")
        normalized_time = broker_wall_msc_to_utc_msc(
            raw_time, f"modification_time:{index}"
        )
        modification_id = _require_string(
            row.get("modification_id"), f"modification_id:{index}"
        )
        if modification_id in modification_ids:
            raise ReplayDataInvalid(f"modification_id_duplicate:{modification_id}")
        modification_ids.add(modification_id)
        _integer(row.get("ticket"), f"modification_ticket:{index}", minimum=1)
        position_id = _integer(
            row.get("position_id"), f"modification_position:{index}", minimum=1
        )
        for field_name in ("old_sl", "new_sl", "old_tp", "new_tp"):
            if _decimal(row.get(field_name), f"modification_{field_name}:{index}") < 0:
                raise ReplayDataInvalid(f"modification_{field_name}_negative:{index}")
        _require_string(row.get("reason"), f"modification_reason:{index}")
        if not _require_bool(row.get("send_ok"), f"modification_send_ok:{index}"):
            raise ReplayDataInvalid(f"modification_send_failed:{index}")
        retcode = _integer(row.get("retcode"), f"modification_retcode:{index}")
        request_id = _integer(row.get("request_id"), f"modification_request_id:{index}", minimum=1)
        if not _require_bool(row.get("request_callback_seen"), f"modification_request_callback:{index}"):
            raise ReplayDataInvalid(f"modification_request_callback_missing:{index}")
        if not _require_bool(row.get("position_callback_seen"), f"modification_position_callback:{index}"):
            raise ReplayDataInvalid(f"modification_position_callback_missing:{index}")
        if row.get("callback_retcode") != retcode or row.get("callback_request_id") != request_id:
            raise ReplayDataInvalid(f"modification_callback_correlation_mismatch:{index}")
        correlated = _integer(
            row.get("correlated_sl_exit_deal"),
            f"modification_correlated_deal:{index}",
        )
        if correlated and correlated not in deal_map:
            raise ReplayDataInvalid(f"modification_correlated_deal_unknown:{index}")
        correlated_price = _decimal(
            row.get("correlated_sl_exit_price"),
            f"modification_correlated_price:{index}",
        )
        if correlated and correlated_price <= 0:
            raise ReplayDataInvalid(f"modification_correlated_price_invalid:{index}")
        if correlated:
            deal = deal_map[correlated]
            if (
                deal.reason != "SL"
                or deal.entry != "OUT"
                or deal.position_id != position_id
                or deal.price != correlated_price
                or deal.time_msc < normalized_time
            ):
                raise ReplayDataInvalid(
                    f"modification_correlated_deal_mismatch:{index}"
                )
    return bool(rows)


def _parse_checkpoints(
    rows: Sequence[Mapping[str, Any]], sleeve: Sleeve, decimals: int
) -> tuple[Checkpoint, ...]:
    output: list[Checkpoint] = []
    previous: tuple[int, int] | None = None
    for index, row in enumerate(rows):
        time_msc = _integer(row.get("time_msc"), f"checkpoint_time:{index}")
        sequence = _integer(row.get("source_sequence"), f"checkpoint_sequence:{index}")
        key = (time_msc, sequence)
        if previous is not None and key <= previous:
            raise ReplayDataInvalid(f"checkpoint_stream_nonmonotone:{sleeve.symbol}:{index}")
        previous = key
        kind = _require_string(row.get("kind"), f"checkpoint_kind:{index}")
        if kind not in {"START", "DEAL_BOUNDARY", "GRID_BOUNDARY", "END"}:
            raise ReplayDataInvalid(f"checkpoint_kind_unsupported:{kind}")
        deal_ids_raw = row.get("deal_ids")
        if not isinstance(deal_ids_raw, list):
            raise ReplayDataInvalid(f"checkpoint_deal_ids_invalid:{index}")
        deal_ids = tuple(_integer(value, f"checkpoint_deal_id:{index}", minimum=1) for value in deal_ids_raw)
        if len(deal_ids) != len(set(deal_ids)) or tuple(sorted(deal_ids)) != deal_ids:
            raise ReplayDataInvalid(f"checkpoint_deal_ids_not_canonical:{index}")
        swaps_raw = row.get("position_swaps")
        if not isinstance(swaps_raw, list):
            raise ReplayDataInvalid(f"checkpoint_position_swaps_invalid:{index}")
        swaps: list[tuple[int, Decimal]] = []
        for swap_index, item in enumerate(swaps_raw):
            if not isinstance(item, Mapping):
                raise ReplayDataInvalid(f"checkpoint_position_swap_invalid:{index}:{swap_index}")
            swaps.append(
                (
                    _integer(item.get("position_id"), "checkpoint_swap_position", minimum=1),
                    _money(item.get("amount"), "checkpoint_swap_amount", decimals),
                )
            )
        if tuple(sorted(swaps)) != tuple(swaps) or len({item[0] for item in swaps}) != len(swaps):
            raise ReplayDataInvalid(f"checkpoint_position_swaps_not_canonical:{index}")
        output.append(
            Checkpoint(
                time_msc=broker_wall_msc_to_utc_msc(time_msc, f"checkpoint_time:{index}"),
                source_sequence=sequence,
                kind=kind,
                deal_ids=deal_ids,
                balance=_money(row.get("balance"), f"checkpoint_balance:{index}", decimals),
                equity=_money(row.get("equity"), f"checkpoint_equity:{index}", decimals),
                open_positions=_integer(row.get("open_positions"), f"checkpoint_open:{index}"),
                pending_orders=_integer(row.get("pending_orders"), f"checkpoint_pending:{index}"),
                position_swaps=tuple(swaps),
                margin=_decimal(row.get("margin"), f"checkpoint_margin:{index}"),
                margin_free=_decimal(row.get("margin_free"), f"checkpoint_margin_free:{index}"),
                margin_level=_decimal(row.get("margin_level"), f"checkpoint_margin_level:{index}"),
                account_leverage=_integer(row.get("account_leverage"), f"checkpoint_account_leverage:{index}", minimum=1),
                account_currency=_require_string(
                    row.get("account_currency"),
                    f"checkpoint_account_currency:{index}",
                ),
                account_margin_mode=_integer(
                    row.get("account_margin_mode"),
                    f"checkpoint_account_margin_mode:{index}",
                ),
            )
        )
        if output[-1].margin < 0 or output[-1].margin_free < 0 or output[-1].margin_level < 0:
            raise ReplayDataInvalid(f"checkpoint_margin_state_negative:{index}")
    return tuple(output)


def _profit(spec: SymbolSpec, side: str, volume: Decimal, opened: Decimal, closed: Decimal) -> Decimal:
    direction = Decimal(1) if side == "BUY" else Decimal(-1)
    quote_profit = direction * volume * spec.contract_size * (closed - opened)
    if spec.conversion_mode == "IDENTITY":
        return quote_profit
    if spec.conversion_mode == "FOREX_QUOTE_ACCOUNT_INVERSE":
        if closed <= 0:
            raise ReplayDataInvalid(f"conversion_price_invalid:{spec.symbol}")
        return quote_profit / closed
    raise ReplayDataInvalid(f"unsupported_conversion:{spec.symbol}:{spec.conversion_mode}")


def _equity(
    balance: Decimal,
    positions: Mapping[int, Position],
    marks: Mapping[str, Tick],
    specs: Mapping[str, SymbolSpec],
) -> Decimal:
    result = balance
    for position in positions.values():
        try:
            tick = marks[position.symbol]
        except KeyError as exc:
            raise ReplayDataMissing(f"mark_missing:{position.symbol}") from exc
        liquidation = tick.bid if position.side == "BUY" else tick.ask
        result += _profit(
            specs[position.symbol],
            position.side,
            position.volume,
            position.average_price,
            liquidation,
        ) + position.swap_mark
    return result


def _pending_count(orders: Mapping[int, OrderEvent]) -> int:
    return sum(item.order_type in _PENDING_ORDER_TYPES for item in orders.values())


def _validate_checkpoint(
    checkpoint: Checkpoint,
    *,
    balance: Decimal,
    equity: Decimal,
    positions: Mapping[int, Position],
    orders: Mapping[int, OrderEvent],
    decimals: int,
) -> None:
    if checkpoint.balance != _at_cent(balance, decimals):
        raise ReplayDataInvalid(f"checkpoint_balance_mismatch:{checkpoint.time_msc}")
    if checkpoint.equity != _at_cent(equity, decimals):
        raise ReplayDataInvalid(f"checkpoint_equity_mismatch:{checkpoint.time_msc}")
    if checkpoint.open_positions != len(positions):
        raise ReplayDataInvalid(f"checkpoint_open_positions_mismatch:{checkpoint.time_msc}")
    if checkpoint.pending_orders != _pending_count(orders):
        raise ReplayDataInvalid(f"checkpoint_pending_orders_mismatch:{checkpoint.time_msc}")
    expected_swaps = tuple(sorted((key, value.swap_mark) for key, value in positions.items()))
    if checkpoint.position_swaps != expected_swaps:
        raise ReplayDataInvalid(f"checkpoint_position_swaps_mismatch:{checkpoint.time_msc}")
    if checkpoint.margin_free > checkpoint.equity:
        raise ReplayDataInvalid(f"checkpoint_margin_free_exceeds_equity:{checkpoint.time_msc}")


def _replay_sleeve(
    *,
    replay_id: str,
    sleeve: Sleeve,
    spec: SymbolSpec,
    snapshots: Mapping[tuple[str, str | None], BoundSnapshot],
    start: int,
    end: int,
    raw_start: int,
    raw_end: int,
    grid_seconds: int,
    decimals: int,
    tick_run_id: str,
    expected_account_leverage: int,
    expected_account_margin_mode: int,
) -> SleeveReplay:
    ticks = _parse_ticks(snapshots, sleeve, raw_start, raw_end, tick_run_id)
    order_rows = _stream_rows(_snapshot(snapshots, "orders", sleeve.symbol), ORDER_SCHEMA, sleeve, "orders")
    deal_rows = _stream_rows(_snapshot(snapshots, "deals", sleeve.symbol), DEAL_SCHEMA, sleeve, "deals")
    account_rows = _stream_rows(
        _snapshot(snapshots, "account_events", sleeve.symbol), ACCOUNT_EVENT_SCHEMA, sleeve, "account_events"
    )
    checkpoint_rows = _stream_rows(
        _snapshot(snapshots, "checkpoints", sleeve.symbol), CHECKPOINT_SCHEMA, sleeve, "checkpoints"
    )
    modification_rows = _stream_rows(
        _snapshot(snapshots, "modifications", sleeve.symbol),
        MODIFICATION_SCHEMA,
        sleeve,
        "modifications",
    )
    orders = _parse_orders(order_rows, sleeve)
    deals = _parse_deals(deal_rows, sleeve, decimals)
    account_events = _parse_account_events(account_rows, sleeve, decimals)
    checkpoints = _parse_checkpoints(checkpoint_rows, sleeve, decimals)
    has_modifications = _validate_modifications(
        modification_rows, sleeve, deals
    )

    for collection_name, collection in {
        "orders": orders,
        "deals": deals,
        "account_events": account_events,
        "checkpoints": checkpoints,
    }.items():
        if any(not start <= item.time_msc <= end for item in collection):
            raise ReplayDataInvalid(f"{collection_name}_outside_range:{sleeve.symbol}")

    receipt_snapshot = _snapshot(snapshots, "history_complete", sleeve.symbol)
    receipt = _json(receipt_snapshot.payload, f"history_complete:{sleeve.symbol}")
    if receipt.get("schema") != HISTORY_COMPLETE_SCHEMA:
        raise ReplayDataInvalid(f"history_complete_schema_invalid:{sleeve.symbol}")
    _assert_identity(receipt, sleeve, "history_complete")
    if receipt.get("time_basis") != TIMESTAMP_BASIS:
        raise ReplayDataInvalid(f"history_complete_time_basis_mismatch:{sleeve.symbol}")
    if not _require_bool(receipt.get("complete"), "history_complete"):
        raise ReplayDataInvalid(f"history_export_incomplete:{sleeve.symbol}")
    if not _require_bool(receipt.get("history_select_complete"), "history_select_complete"):
        raise ReplayDataInvalid(f"history_select_incomplete:{sleeve.symbol}")
    modification_complete = _require_bool(
        receipt.get("modification_observation_complete"), "modification_observation_complete"
    )
    if not _require_bool(receipt.get("end_flat"), "history_end_flat"):
        raise ReplayDataInvalid(f"history_not_end_flat:{sleeve.symbol}")
    if receipt.get("start_time_msc") != raw_start or receipt.get("end_time_msc") != raw_end:
        raise ReplayDataInvalid(f"history_complete_range_mismatch:{sleeve.symbol}")
    for role, receipt_field in (
        ("orders", "orders_sha256"),
        ("deals", "deals_sha256"),
        ("account_events", "account_events_sha256"),
        ("checkpoints", "checkpoints_sha256"),
        ("modifications", "modifications_sha256"),
    ):
        if _require_sha(receipt.get(receipt_field), f"history_{role}") != _snapshot(
            snapshots, role, sleeve.symbol
        ).sha256:
            raise ReplayDataInvalid(f"history_complete_hash_mismatch:{sleeve.symbol}:{role}")
    row_count_fields = {
        "order_rows": len(order_rows),
        "deal_rows": len(deal_rows),
        "account_event_rows": len(account_rows),
        "checkpoint_rows": len(checkpoint_rows),
        "modifications_rows": len(modification_rows),
    }
    if any(receipt.get(field) != count for field, count in row_count_fields.items()):
        raise ReplayDataInvalid(f"history_stream_count_mismatch:{sleeve.symbol}")
    if receipt.get("modifications_rows") != len(modification_rows):
        raise ReplayDataInvalid(f"history_modification_count_mismatch:{sleeve.symbol}")
    if not _require_bool(receipt.get("normal_deinit_complete"), "normal_deinit_complete"):
        raise ReplayDataInvalid(f"history_normal_deinit_incomplete:{sleeve.symbol}")
    if receipt.get("raw_evidence_window_semantics") != "EXACT_BROKER_WALL_TESTER_DATE_RANGE":
        raise ReplayDataInvalid(f"history_raw_window_semantics_invalid:{sleeve.symbol}")
    if receipt.get("prague_boundary_day_policy") != "PARTIAL_BOUNDARY_DAYS_PRESERVED_IN_RAW_EVIDENCE":
        raise ReplayDataInvalid(f"history_prague_day_policy_invalid:{sleeve.symbol}")
    if receipt.get("producer_window_transform") != "NONE":
        raise ReplayDataInvalid(f"history_window_transform_invalid:{sleeve.symbol}")
    if not _require_bool(receipt.get("strategy_truth_window_preserved"), "strategy_truth_window_preserved"):
        raise ReplayDataInvalid(f"history_strategy_window_not_preserved:{sleeve.symbol}")
    if receipt.get("expected_broker_wall_start_msc") != raw_start or receipt.get("expected_broker_wall_end_msc") != raw_end:
        raise ReplayDataInvalid(f"history_expected_window_mismatch:{sleeve.symbol}")
    actual_first_tick = _integer(
        receipt.get("actual_first_tick_broker_wall_msc"),
        "actual_first_tick_broker_wall_msc",
    )
    actual_last_tick = _integer(
        receipt.get("actual_last_tick_broker_wall_msc"),
        "actual_last_tick_broker_wall_msc",
    )
    if not raw_start <= actual_first_tick <= actual_last_tick <= raw_end:
        raise ReplayDataInvalid(f"history_actual_window_outside_contract:{sleeve.symbol}")
    if not _require_bool(receipt.get("execution_manifest_hash_verified"), "execution_manifest_hash_verified"):
        raise ReplayDataInvalid(f"history_execution_manifest_not_verified:{sleeve.symbol}")
    if not _require_bool(receipt.get("prague_midnight_proof_hash_verified"), "prague_midnight_proof_hash_verified"):
        raise ReplayDataInvalid(f"history_prague_proof_not_verified:{sleeve.symbol}")
    if _require_bool(receipt.get("prague_midnight_proof_semantically_consumed_by_producer"), "prague_midnight_proof_semantically_consumed"):
        raise ReplayDataInvalid(f"history_prague_proof_overclaim:{sleeve.symbol}")
    if receipt.get("swap_effective_timing_basis") != "OBSERVATION_ONLY_EFFECTIVE_TIME_NULL" or _require_bool(receipt.get("swap_effective_timing_complete"), "swap_effective_timing_complete"):
        raise ReplayDataInvalid(f"history_swap_timing_overclaim:{sleeve.symbol}")
    if not _require_bool(receipt.get("external_prague_swap_timing_reconciliation_required"), "external_swap_reconciliation_required"):
        raise ReplayDataInvalid(f"history_external_swap_reconciliation_not_required:{sleeve.symbol}")
    if not _require_bool(receipt.get("external_completed_tester_report_required"), "external_tester_report_required") or _require_bool(receipt.get("external_completed_tester_report_verified_by_producer"), "external_tester_report_verified"):
        raise ReplayDataInvalid(f"history_external_tester_report_contract_invalid:{sleeve.symbol}")
    if receipt.get("admission_authority") != "NONE":
        raise ReplayDataInvalid(f"history_admission_authority_overclaim:{sleeve.symbol}")
    if receipt.get("producer_status") != "PRODUCER_COMPLETE" or receipt.get("failure_count") != 0 or receipt.get("failure_reasons") not in {"", None}:
        raise ReplayDataInvalid(f"history_producer_not_clean:{sleeve.symbol}")
    expected_currency = receipt.get("expected_account_currency")
    actual_currency = receipt.get("account_currency")
    if expected_currency != spec.account_currency or actual_currency != expected_currency:
        raise ReplayDataInvalid(f"history_account_currency_mismatch:{sleeve.symbol}")
    expected_margin_mode = _integer(receipt.get("expected_account_margin_mode"), "expected_account_margin_mode")
    if (
        expected_margin_mode != expected_account_margin_mode
        or receipt.get("account_margin_mode") != expected_margin_mode
    ):
        raise ReplayDataInvalid(f"history_account_margin_mode_mismatch:{sleeve.symbol}")
    receipt_leverage = _integer(
        receipt.get("account_leverage"), "history_account_leverage", minimum=1
    )
    receipt_expected_leverage = _integer(
        receipt.get("expected_account_leverage"),
        "history_expected_account_leverage",
        minimum=1,
    )
    if (
        receipt_expected_leverage != expected_account_leverage
        or receipt_leverage != expected_account_leverage
        or any(item.account_leverage != receipt_leverage for item in checkpoints)
    ):
        raise ReplayDataInvalid(f"checkpoint_account_leverage_mismatch:{sleeve.symbol}")
    if any(
        item.account_currency != spec.account_currency
        or item.account_margin_mode != expected_account_margin_mode
        for item in checkpoints
    ):
        raise ReplayDataInvalid(f"checkpoint_account_contract_mismatch:{sleeve.symbol}")
    for role, receipt_field in (
        ("execution_manifest", "execution_manifest_sha256"),
        ("prague_midnight_proof", "prague_midnight_proof_sha256"),
    ):
        if _require_sha(receipt.get(receipt_field), receipt_field) != _snapshot(
            snapshots, role, sleeve.symbol
        ).sha256:
            raise ReplayDataInvalid(
                f"history_complete_hash_mismatch:{sleeve.symbol}:{role}"
            )

    if not checkpoints:
        raise ReplayDataMissing(f"checkpoints_empty:{sleeve.symbol}")
    if checkpoints[0].kind != "START" or checkpoints[0].time_msc != start:
        raise ReplayDataInvalid(f"start_checkpoint_missing:{sleeve.symbol}")
    if checkpoints[-1].kind != "END" or checkpoints[-1].time_msc != end:
        raise ReplayDataInvalid(f"end_checkpoint_missing:{sleeve.symbol}")
    deals_by_time: dict[int, tuple[int, ...]] = {}
    for deal in deals:
        deals_by_time.setdefault(deal.time_msc, tuple())
        deals_by_time[deal.time_msc] += (deal.deal_id,)
    boundary_map = {
        item.time_msc: item.deal_ids for item in checkpoints if item.kind == "DEAL_BOUNDARY"
    }
    for time_msc, ids in deals_by_time.items():
        if boundary_map.get(time_msc) != tuple(sorted(ids)):
            raise ReplayDataInvalid(f"deal_boundary_checkpoint_missing:{sleeve.symbol}:{time_msc}")

    # Per-sleeve source sequences are authoritative only inside the sleeve.  No
    # ordering is constructed between different standalone runs.
    events: list[tuple[int, int, int, str, Any]] = []
    for item in ticks:
        events.append((item.time_msc, 10, item.source_sequence, "tick", item))
    for item in orders:
        priority = 40 if item.event in _TERMINAL_ORDER_EVENTS or item.event == "PARTIAL_FILL" else 20
        events.append((item.time_msc, priority, item.source_sequence, "order", item))
    for item in deals:
        events.append((item.time_msc, 30, item.source_sequence, "deal", item))
    for item in account_events:
        events.append((item.time_msc, 35, item.source_sequence, "account", item))
    for item in checkpoints:
        events.append((item.time_msc, 50, item.source_sequence, "checkpoint", item))
    events.sort(key=lambda value: (value[0], value[1], value[2], value[3]))
    if len({(item[0], item[1], item[2], item[3]) for item in events}) != len(events):
        raise ReplayDataInvalid(f"ambiguous_event_key:{sleeve.symbol}")

    grid_msc = grid_seconds * 1000
    grid = tuple(range(start, end + 1, grid_msc))
    if not grid or grid[-1] != end:
        raise ReplayDataInvalid("grid_does_not_close_range")
    points: list[rules_engine.TracePoint] = []
    balance = sleeve.native_initial_balance
    marks: dict[str, Tick] = {}
    open_orders: dict[int, OrderEvent] = {}
    positions: dict[int, Position] = {}
    opened_in_interval = 0
    interval_min: Decimal | None = None
    event_index = 0
    max_margin = max(item.margin for item in checkpoints)
    min_margin_free = min(item.margin_free for item in checkpoints)

    for grid_index, boundary in enumerate(grid):
        while event_index < len(events) and events[event_index][0] <= boundary:
            _time, _priority, _sequence, kind, item = events[event_index]
            if kind == "tick":
                marks[sleeve.symbol] = item
            elif kind == "order":
                if item.event == "PLACED":
                    if item.order_id in open_orders:
                        raise ReplayDataInvalid(f"order_replaced_without_terminal:{sleeve.symbol}:{item.order_id}")
                    open_orders[item.order_id] = item
                elif item.event in {"MODIFIED", "PARTIAL_FILL"}:
                    if item.order_id not in open_orders:
                        raise ReplayDataInvalid(f"order_update_without_placed:{sleeve.symbol}:{item.order_id}")
                    if item.volume_remaining < 0 or item.volume_remaining > item.volume_initial:
                        raise ReplayDataInvalid(f"order_remaining_invalid:{sleeve.symbol}:{item.order_id}")
                    open_orders[item.order_id] = item
                else:
                    if item.order_id not in open_orders:
                        raise ReplayDataInvalid(f"order_terminal_without_placed:{sleeve.symbol}:{item.order_id}")
                    del open_orders[item.order_id]
            elif kind == "deal":
                if item.execution_mode == "PENDING":
                    existing_order = open_orders.get(item.order_id)
                    if existing_order is None or existing_order.order_type not in _PENDING_ORDER_TYPES:
                        raise ReplayDataInvalid(f"pending_deal_without_order:{sleeve.symbol}:{item.deal_id}")
                if item.entry == "IN":
                    if item.profit != 0 or item.swap != 0:
                        raise ReplayDataInvalid(f"entry_deal_profit_or_swap_nonzero:{sleeve.symbol}:{item.deal_id}")
                    current = positions.get(item.position_id)
                    if current is None:
                        positions[item.position_id] = Position(
                            item.side, sleeve.symbol, sleeve.magic, item.volume, item.price
                        )
                        opened_in_interval += 1
                    else:
                        if current.side != item.side:
                            raise ReplayDataInvalid(f"position_reverse_requires_inout:{sleeve.symbol}:{item.position_id}")
                        total = current.volume + item.volume
                        current.average_price = (
                            current.average_price * current.volume + item.price * item.volume
                        ) / total
                        current.volume = total
                else:
                    current = positions.get(item.position_id)
                    if current is None or item.side == current.side or item.volume > current.volume:
                        raise ReplayDataInvalid(f"close_deal_position_mismatch:{sleeve.symbol}:{item.deal_id}")
                    expected_profit = _at_cent(
                        _profit(spec, current.side, item.volume, current.average_price, item.price), decimals
                    )
                    if item.profit != expected_profit:
                        raise ReplayDataInvalid(
                            f"deal_profit_reconciliation_mismatch:{sleeve.symbol}:{item.deal_id}"
                        )
                    if item.swap != 0:
                        if _at_cent(current.swap_mark, decimals) == 0:
                            raise ReplayDataInvalid(f"deal_swap_without_open_swap_mark:{sleeve.symbol}:{item.deal_id}")
                        current.swap_mark -= item.swap
                    current.volume -= item.volume
                    if current.volume == 0:
                        if _at_cent(current.swap_mark, decimals) != 0:
                            raise ReplayDataInvalid(f"closed_position_swap_not_reconciled:{sleeve.symbol}:{item.position_id}")
                        del positions[item.position_id]
                balance += item.profit + item.commission + item.swap + item.fee
            elif kind == "account":
                try:
                    positions[item.position_id].swap_mark = item.amount
                except KeyError as exc:
                    raise ReplayDataInvalid(
                        f"swap_mark_without_open_position:{sleeve.symbol}:{item.position_id}"
                    ) from exc
            else:
                current_equity = _equity(balance, positions, marks, {sleeve.symbol: spec})
                _validate_checkpoint(
                    item,
                    balance=balance,
                    equity=current_equity,
                    positions=positions,
                    orders=open_orders,
                    decimals=decimals,
                )
            current_equity = _equity(balance, positions, marks, {sleeve.symbol: spec})
            interval_min = current_equity if interval_min is None else min(interval_min, current_equity)
            event_index += 1

        if positions and sleeve.symbol not in marks:
            raise ReplayDataMissing(f"grid_mark_missing:{sleeve.symbol}:{boundary}")
        equity = _equity(balance, positions, marks, {sleeve.symbol: spec})
        interval_min = equity if interval_min is None else min(interval_min, equity)
        timestamp = dt.datetime.fromtimestamp(boundary / 1000, tz=dt.UTC)
        is_anchor = timestamp.astimezone(PRAGUE).time() == dt.time(0, 0)
        points.append(
            rules_engine.TracePoint(
                ts_utc=timestamp,
                balance=_at_cent(balance, decimals),
                equity=_at_cent(equity, decimals),
                interval_min_equity=(
                    _at_cent(equity, decimals)
                    if grid_index == 0
                    else _at_cent(interval_min, decimals)
                ),
                open_positions=len(positions),
                opened_positions=0 if grid_index == 0 else opened_in_interval,
                day_anchor=is_anchor,
            )
        )
        interval_min = equity
        opened_in_interval = 0

    if event_index != len(events):
        raise ReplayDataInvalid(f"events_after_grid_end:{sleeve.symbol}")
    if positions or open_orders:
        raise ReplayDataInvalid(f"sleeve_not_flat_at_end:{sleeve.symbol}")

    fingerprint_payload = {
        "schema": "FTMO_STANDALONE_REPLAY_INPUT_V1",
        "replay_id": replay_id,
        "sleeve_id": sleeve.sleeve_id,
        "symbol": sleeve.symbol,
        "run_id": sleeve.run_id,
        "magic": sleeve.magic,
        "artifacts": [
            {"role": role, "sha256": _snapshot(snapshots, role, sleeve.symbol).sha256}
            for role in sorted(_SLEEVE_ROLES)
        ],
    }
    fingerprint = _sha(_canonical(fingerprint_payload))
    trace = rules_engine.NormalizedTrace(
        trace_id=f"{replay_id}:{sleeve.sleeve_id}",
        currency=spec.account_currency,
        source_fingerprint_sha256=fingerprint,
        money_decimals=decimals,
        grid_seconds=grid_seconds,
        balance_basis=rules_engine.BALANCE_BASIS_NET_TRADING,
        equity_basis=rules_engine.EQUITY_BASIS_MTM,
        opened_positions_basis=rules_engine.OPENED_POSITIONS_BASIS,
        interval_min_equity_basis=rules_engine.INTERVAL_MIN_EQUITY_BASIS,
        points=tuple(points),
    )
    # The rows are authenticated and correlation-checked, but V1 does not yet
    # replay SL/TP state between modification and exit as a qualification claim.
    return SleeveReplay(
        trace,
        max_margin,
        min_margin_free,
        modification_complete,
        has_modifications,
        fingerprint,
    )


def produce_replay(manifest_path: Path | str) -> ReplayProduct:
    """Read every bound input once and produce a deterministic blocked V1 trace."""

    path = Path(manifest_path).resolve()
    manifest_payload = _read_once(path, "manifest")
    manifest_sha = _sha(manifest_payload)
    manifest = _json(manifest_payload, "manifest")
    if manifest.get("schema") != MANIFEST_SCHEMA:
        raise ReplayDataInvalid("manifest_schema_invalid")
    manifest_id = _require_sha(manifest.get("manifest_id"), "manifest_id")
    id_payload = dict(manifest)
    id_payload.pop("manifest_id", None)
    if _sha(_canonical(id_payload)) != manifest_id:
        raise ReplayDataInvalid("manifest_id_mismatch")

    replay_id = _require_string(manifest.get("replay_id"), "replay_id")
    account_currency = _require_string(manifest.get("account_currency"), "account_currency")
    if not _CURRENCY_RE.fullmatch(account_currency):
        raise ReplayDataInvalid("account_currency_invalid")
    decimals = _integer(manifest.get("money_decimals"), "money_decimals")
    if decimals != 2:
        raise ReplayDataInvalid("money_decimals_v1_requires_2")
    grid_seconds = _integer(manifest.get("grid_seconds"), "grid_seconds", minimum=1)
    if grid_seconds > 3600 or 3600 % grid_seconds:
        raise ReplayDataInvalid("grid_seconds_must_divide_hour_and_not_exceed_3600")
    if manifest.get("observation_timezone") != "Europe/Prague":
        raise ReplayDataInvalid("observation_timezone_invalid")
    if manifest.get("gap_policy") != "CLOSED_MARKET_ONLY_WITH_PROOF":
        raise ReplayDataInvalid("gap_policy_invalid")
    if not _require_bool(manifest.get("require_end_flat"), "require_end_flat"):
        raise ReplayDataInvalid("require_end_flat_must_be_true")
    if manifest.get("timestamp_basis") != TIMESTAMP_BASIS:
        raise ReplayDataInvalid("timestamp_basis_invalid")
    raw_start = _integer(manifest.get("start_time_msc"), "start_time_msc")
    raw_end = _integer(manifest.get("end_time_msc"), "end_time_msc")
    start = broker_wall_msc_to_utc_msc(raw_start, "manifest_start_time_msc")
    end = broker_wall_msc_to_utc_msc(raw_end, "manifest_end_time_msc")
    if end <= start or (end - start) % (grid_seconds * 1000):
        raise ReplayDataInvalid("manifest_time_range_invalid")
    start_dt = dt.datetime.fromtimestamp(start / 1000, tz=dt.UTC)
    end_dt = dt.datetime.fromtimestamp(end / 1000, tz=dt.UTC)
    bindings, snapshots = _artifact_map(manifest, path.parent)
    sizing = _json(_snapshot(snapshots, "sizing_policy").payload, "sizing_policy")
    sleeves = _parse_sleeves(manifest, sizing, decimals)
    allowed = manifest.get("allowed_symbols")
    if not isinstance(allowed, list) or allowed != sorted(item.symbol for item in sleeves):
        raise ReplayDataInvalid("allowed_symbols_must_match_sorted_sleeves")

    expected_keys = {(role, None) for role in _GLOBAL_ROLES}
    for sleeve in sleeves:
        expected_keys.update((role, sleeve.symbol) for role in _SLEEVE_ROLES)
    if set(snapshots) != expected_keys:
        missing = sorted(expected_keys - set(snapshots))
        extra = sorted(set(snapshots) - expected_keys)
        raise ReplayDataInvalid(f"artifact_role_set_mismatch:missing={missing}:extra={extra}")

    specs, expected_account_leverage, expected_account_margin_mode = _symbol_specs(
        _snapshot(snapshots, "symbol_properties").payload, sleeves, account_currency
    )
    tick_set = _json(_snapshot(snapshots, "tick_set_complete").payload, "tick_set_complete")
    if tick_set.get("event") != "TICK_RAW_COPY_SET_COMPLETE" or tick_set.get("schema_version") != 1:
        raise ReplayDataInvalid("tick_set_complete_identity_invalid")
    tick_run_id = _require_string(tick_set.get("run_id"), "tick_set_run_id")
    if tick_set.get("time_basis") != TIMESTAMP_BASIS:
        raise ReplayDataInvalid("tick_set_time_basis_mismatch")
    if not _require_bool(tick_set.get("raw_copy_complete"), "tick_set_raw_copy_complete"):
        raise ReplayDataInvalid("tick_set_raw_copy_incomplete")
    if _require_bool(tick_set.get("market_coverage_complete"), "tick_set_market_coverage_complete"):
        raise ReplayDataInvalid("tick_set_overclaims_market_coverage")
    if tick_set.get("symbol_count") != len(sleeves) or tick_set.get("from_msc") != raw_start or tick_set.get("to_msc_exclusive") != raw_end:
        raise ReplayDataInvalid("tick_set_complete_scope_mismatch")
    sleeve_replays = tuple(
        _replay_sleeve(
            replay_id=replay_id,
            sleeve=sleeve,
            spec=specs[sleeve.symbol],
            snapshots=snapshots,
            start=start,
            end=end,
            raw_start=raw_start,
            raw_end=raw_end,
            grid_seconds=grid_seconds,
            decimals=decimals,
            tick_run_id=tick_run_id,
            expected_account_leverage=expected_account_leverage,
            expected_account_margin_mode=expected_account_margin_mode,
        )
        for sleeve in sleeves
    )
    trace_map = {
        sleeve.sleeve_id: replay.trace for sleeve, replay in zip(sleeves, sleeve_replays)
    }
    complete_days = max(
        0,
        sum(point.day_anchor for point in next(iter(trace_map.values())).points) - 1,
    )
    joint = rules_engine.combine_synchronized_traces(
        trace_map,
        starting_balance=manifest["initial_balance"],
        minimum_overlap_days=complete_days,
        scales={sleeve.sleeve_id: sleeve.scale for sleeve in sleeves},
        joint_trace_id=replay_id,
    )

    blockers = {
        "HISTORICAL_MARKET_SESSION_AND_HOLIDAY_REPLAY_NOT_IMPLEMENTED_V1",
        "EVENT_COMPLETE_MARGIN_AND_JOINT_FREE_MARGIN_REPLAY_NOT_IMPLEMENTED_V1",
        "STATIC_TESTER_REPORT_HCC_TKC_EX5_SET_CROSS_IDENTITY_NOT_RECONCILED_V1",
        "SWAP_EFFECTIVE_TIMING_NOT_RECONCILED_V1",
        "NEWS_CALENDAR_POLICY_NOT_SEMANTICALLY_CONSUMED_V1",
        "FTMO_RULE_SNAPSHOT_NOT_EVALUATED_V1",
        "COST_MODEL_NOT_SEMANTICALLY_RECONCILED_V1",
        "STREAMING_TICK_REPLAY_NOT_IMPLEMENTED_V1",
    }
    if not all(item.modification_observation_complete for item in sleeve_replays):
        blockers.add("ORDER_MODIFICATION_LIFECYCLE_NOT_PROVEN")
    if any(item.position_modifications_present for item in sleeve_replays):
        blockers.add("POSITION_MODIFICATION_CAUSAL_REPLAY_NOT_IMPLEMENTED_V1")
    source_payload = {
        "schema": "FTMO_EVENT_COMPLETE_REPLAY_SOURCE_V1",
        "manifest_id": manifest_id,
        "manifest_sha256": manifest_sha,
        "artifacts": [
            {"role": item.role, "symbol": item.symbol, "sha256": item.sha256}
            for item in bindings
        ],
        "sleeves": [item.input_fingerprint_sha256 for item in sleeve_replays],
        "joint_trace_source_fingerprint_sha256": joint.source_fingerprint_sha256,
    }
    return ReplayProduct(
        manifest_id=manifest_id,
        manifest_sha256=manifest_sha,
        source_fingerprint_sha256=_sha(_canonical(source_payload)),
        trace=joint,
        artifacts=bindings,
        sleeves=sleeve_replays,
        qualification_blockers=tuple(sorted(blockers)),
    )


def _timestamp_text(value: dt.datetime) -> str:
    return value.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def _trace_document(trace: rules_engine.NormalizedTrace) -> dict[str, Any]:
    return {
        "schema_version": rules_engine.TRACE_SCHEMA_VERSION,
        "trace_id": trace.trace_id,
        "currency": trace.currency,
        "source_fingerprint_sha256": trace.source_fingerprint_sha256,
        "money_decimals": trace.money_decimals,
        "grid_seconds": trace.grid_seconds,
        "balance_basis": trace.balance_basis,
        "equity_basis": trace.equity_basis,
        "opened_positions_basis": trace.opened_positions_basis,
        "interval_min_equity_basis": trace.interval_min_equity_basis,
        "rows": [
            {
                "ts_utc": _timestamp_text(point.ts_utc),
                "balance": _money_text(point.balance, trace.money_decimals),
                "equity": _money_text(point.equity, trace.money_decimals),
                "interval_min_equity": _money_text(
                    point.interval_min_equity, trace.money_decimals
                ),
                "open_positions": point.open_positions,
                "opened_positions": point.opened_positions,
                "day_anchor": point.day_anchor,
            }
            for point in trace.points
        ],
    }


def canonical_result_bytes(product: ReplayProduct) -> bytes:
    """Stable serialization suitable for a hash-bound evidence artifact."""

    return _canonical(product.as_document()) + b"\n"


__all__ = [
    "ReplayContractError",
    "ReplayDataInvalid",
    "ReplayDataMissing",
    "ReplayProduct",
    "broker_wall_msc_to_utc_msc",
    "canonical_result_bytes",
    "produce_replay",
]
