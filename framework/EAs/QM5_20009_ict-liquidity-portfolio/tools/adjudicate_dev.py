"""Fail-closed Freeze-v5 DEV adjudicator for QM5_20009.

The adjudicator consumes an immutable matrix of 52 launcher receipts (four
markets by thirteen preregistered variants).  It never launches MetaTrader and
it never searches for a favourable result.  Every input is reached through a
canonical pointer, recursively hash-bound, and counted once after two semantic
duplicate runs have been proved identical.

The module is intentionally standalone.  It does not import the generator,
launcher, validator, or report auditor because those are mutable evidence
producers.  A merit FAIL is a valid verdict; malformed or incomplete evidence
is an integrity error and produces no verdict.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, localcontext
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping, Sequence

import research_evidence_io as evidence_io


SCHEMA_VERSION = 1
PHASE_ID = "DEV"
DEFAULT_PROTOCOL_ID = "QM5_20009_RESEARCH_FREEZE_V5"

POINTER_TYPE = "QM5_20009_FREEZE_V5_DEV_CELL_POINTER"
INVENTORY_TYPE = "QM5_20009_FREEZE_V5_DEV_RECEIPT_INVENTORY"
EVIDENCE_TYPE = "QM5_20009_FREEZE_V5_DEV_ADJUDICATION_EVIDENCE"
VERDICT_TYPE = "QM5_20009_FREEZE_V5_DEV_VERDICT"
LAUNCHER_RECEIPT_TYPE = "QM5_20009_FAIL_CLOSED_RESEARCH_LAUNCHER_RECEIPT"
COST_AUDIT_TYPE = "QM5_20009_DEV1_MT5_REPORT_AUDIT_RECEIPT"
COST_REPORT_TYPE = "QM5_20009_DEV1_MT5_REPORT_COST_AUDIT"

VARIANTS: tuple[str, ...] = (
    "center",
    "pivot_low",
    "pivot_high",
    "reclaim_low",
    "reclaim_high",
    "mss_low",
    "mss_high",
    "fvg_low",
    "fvg_high",
    "stop_low",
    "stop_high",
    "rr_low",
    "rr_high",
)
NEIGHBOURS: tuple[str, ...] = VARIANTS[1:]

MONEY_RE = re.compile(r"^-?(?:0|[1-9][0-9]*)\.[0-9]{2}$")
DECIMAL_RE = re.compile(r"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$")
TIME_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$")
ZERO = Decimal("0")
CENT = Decimal("0.01")
STARTING_EQUITY = Decimal("100000.00")
MAX_DRAWDOWN = Decimal("25000.00")


class AdjudicationError(evidence_io.EvidenceIOError):
    """The evidence graph is incomplete, inconsistent, or non-canonical."""


@dataclass(frozen=True)
class Market:
    symbol: str
    timeframe: str
    from_date: str
    to_date: str
    sleeve: str
    selection_role: str
    binding: bool

    @property
    def years(self) -> tuple[int, ...]:
        return tuple(range(int(self.from_date[:4]), int(self.to_date[:4]) + 1))


MARKETS: tuple[Market, ...] = (
    Market(
        "NDX.DWX",
        "M1",
        "2021-01-01",
        "2022-12-31",
        "A",
        "PRIMARY_BINDING",
        True,
    ),
    Market(
        "GDAXI.DWX",
        "M1",
        "2021-01-01",
        "2022-12-31",
        "A_TRANSPORT",
        "TRANSPORT_DIAGNOSTIC_ONLY",
        False,
    ),
    Market(
        "GBPUSD.DWX",
        "M5",
        "2017-10-01",
        "2022-12-31",
        "B",
        "POOLED_BINDING_MEMBER",
        True,
    ),
    Market(
        "EURUSD.DWX",
        "M5",
        "2017-10-01",
        "2022-12-31",
        "B",
        "POOLED_BINDING_MEMBER",
        True,
    ),
)
MARKET_BY_SYMBOL = {market.symbol: market for market in MARKETS}


@dataclass(frozen=True)
class Policy:
    pointer_root: Path
    receipt_root: Path
    output_root: Path
    freeze_inputs_sha256: str
    manifest_sha256: str
    protocol_id: str = DEFAULT_PROTOCOL_ID

    def __post_init__(self) -> None:
        object.__setattr__(self, "pointer_root", self.pointer_root.resolve(strict=False))
        object.__setattr__(self, "receipt_root", self.receipt_root.resolve(strict=False))
        object.__setattr__(self, "output_root", self.output_root.resolve(strict=False))
        evidence_io.require_sha256(self.freeze_inputs_sha256, "freeze_inputs_sha256")
        evidence_io.require_sha256(self.manifest_sha256, "manifest_sha256")
        if not self.protocol_id or not isinstance(self.protocol_id, str):
            raise AdjudicationError("protocol_id must be a non-empty string")


@dataclass(frozen=True)
class CellKey:
    market: Market
    variant: str

    def __post_init__(self) -> None:
        if self.variant not in VARIANTS:
            raise AdjudicationError(f"unknown variant: {self.variant}")

    @property
    def cell_id(self) -> str:
        return f"{PHASE_ID}|{self.market.symbol}|{self.market.timeframe}|{self.variant}"

    @property
    def safe_symbol(self) -> str:
        return re.sub(r"[^A-Za-z0-9_-]", "_", self.market.symbol)

    def pointer_path(self, root: Path) -> Path:
        return (
            root
            / PHASE_ID
            / self.safe_symbol
            / self.market.timeframe
            / f"{self.variant}.pointer.json"
        )


def expected_cells() -> tuple[CellKey, ...]:
    return tuple(CellKey(market, variant) for market in MARKETS for variant in VARIANTS)


def _mapping(value: Any, context: str) -> Mapping[str, Any]:
    if not isinstance(value, dict):
        raise AdjudicationError(f"{context} must be a JSON object")
    return value


def _list(value: Any, context: str) -> list[Any]:
    if not isinstance(value, list):
        raise AdjudicationError(f"{context} must be a JSON array")
    return value


def _exact_keys(value: Mapping[str, Any], required: set[str], context: str) -> None:
    evidence_io.require_exact_keys(value, required=required, context=context)


def _required_keys(value: Mapping[str, Any], required: set[str], context: str) -> None:
    missing = sorted(required - set(value))
    if missing:
        raise AdjudicationError(f"{context} missing required keys: {missing}")


def _expect(value: Any, expected: Any, context: str) -> None:
    if type(value) is not type(expected) or value != expected:
        raise AdjudicationError(f"{context} must equal {expected!r}, got {value!r}")


def _strict_canonical_json(path: Path, context: str) -> dict[str, Any]:
    payload = evidence_io.load_json_strict(path)
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise AdjudicationError(f"cannot read {context} bytes {path}: {exc}") from exc
    if raw != evidence_io.canonical_json_bytes(payload):
        raise AdjudicationError(f"{context} is not canonical JSON: {path}")
    return payload


def _parse_utc(value: Any, context: str) -> datetime:
    if not isinstance(value, str) or not value:
        raise AdjudicationError(f"{context} must be an ISO-8601 timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise AdjudicationError(f"{context} is not ISO-8601: {value!r}") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise AdjudicationError(f"{context} must include an UTC offset")
    return parsed.astimezone(timezone.utc)


def _parse_broker_time(value: Any, context: str) -> datetime:
    if not isinstance(value, str) or TIME_RE.fullmatch(value) is None:
        raise AdjudicationError(f"{context} must be YYYY-MM-DDTHH:MM:SS broker time")
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%S")
    except ValueError as exc:
        raise AdjudicationError(f"invalid {context}: {value!r}") from exc


def money(value: Any, context: str) -> Decimal:
    """Parse a canonical USD-cent string without ever passing through binary float."""

    if not isinstance(value, str) or MONEY_RE.fullmatch(value) is None:
        raise AdjudicationError(f"{context} must be a canonical two-place money string")
    try:
        parsed = Decimal(value)
    except InvalidOperation as exc:
        raise AdjudicationError(f"invalid money in {context}: {value!r}") from exc
    if not parsed.is_finite():
        raise AdjudicationError(f"{context} must be finite")
    return parsed


def decimal_value(value: Any, context: str) -> Decimal:
    if not isinstance(value, str) or DECIMAL_RE.fullmatch(value) is None:
        raise AdjudicationError(f"{context} must be a canonical decimal string")
    try:
        parsed = Decimal(value)
    except InvalidOperation as exc:
        raise AdjudicationError(f"invalid decimal in {context}: {value!r}") from exc
    if not parsed.is_finite():
        raise AdjudicationError(f"{context} must be finite")
    return parsed


def money_text(value: Decimal) -> str:
    return format(value.quantize(CENT, rounding=ROUND_HALF_UP), ".2f")


def decimal_text(value: Decimal) -> str:
    if value == ZERO:
        return "0"
    text = format(value, "f")
    return text.rstrip("0").rstrip(".") if "." in text else text


def profit_factor_floor(trade_count: int) -> Decimal:
    """Exact Decimal implementation of the frozen Q02 small-sample PF floor."""

    if isinstance(trade_count, bool) or not isinstance(trade_count, int) or trade_count <= 0:
        raise AdjudicationError("profit-factor floor requires a positive trade count")
    with localcontext() as context:
        context.prec = 50
        n = Decimal(trade_count)
        u = Decimal("1.94") / n.sqrt()
        d = u / (Decimal(1) + u * u).sqrt()
        calculated = (Decimal(1) + d) / (Decimal(1) - d)
        return max(Decimal("1.10"), +calculated)


@dataclass(frozen=True)
class Position:
    sequence: int
    entry_deals: tuple[str, ...]
    exit_deal: str
    symbol: str
    side: str
    volume: str
    entry_times: tuple[datetime, ...]
    entry_times_raw: tuple[str, ...]
    exit_time: datetime
    exit_time_raw: str
    raw_net: Decimal
    swap: Decimal
    entry_external_cost: Decimal
    exit_external_cost: Decimal
    external_cost: Decimal
    adjusted_net: Decimal

    @property
    def direction(self) -> str:
        return "LONG" if self.side == "buy" else "SHORT"

    @property
    def new_york_exit(self) -> datetime:
        return self.exit_time - timedelta(hours=7)

    @property
    def session(self) -> str | None:
        sessions = {_fx_session(value) for value in self.entry_times}
        if None in sessions or len(sessions) != 1:
            return None
        return next(iter(sessions))

    def canonical(self) -> dict[str, Any]:
        return {
            "sequence": self.sequence,
            "entry_deals": list(self.entry_deals),
            "exit_deal": self.exit_deal,
            "symbol": self.symbol,
            "side": self.side,
            "volume": self.volume,
            "entry_times": list(self.entry_times_raw),
            "exit_time": self.exit_time_raw,
            "raw_net_usd": money_text(self.raw_net),
            "swap_usd": money_text(self.swap),
            "entry_external_cost_usd": money_text(self.entry_external_cost),
            "exit_external_cost_usd": money_text(self.exit_external_cost),
            "external_cost_usd": money_text(self.external_cost),
            "cost_adjusted_net_usd": money_text(self.adjusted_net),
        }


POSITION_KEYS = {
    "sequence",
    "entry_deals",
    "exit_deal",
    "symbol",
    "side",
    "volume",
    "entry_times",
    "exit_time",
    "raw_net_usd",
    "swap_usd",
    "entry_external_cost_usd",
    "exit_external_cost_usd",
    "external_cost_usd",
    "cost_adjusted_net_usd",
}


def _fx_session(broker_time: datetime) -> str | None:
    ny_time = broker_time - timedelta(hours=7)
    minute = ny_time.hour * 60 + ny_time.minute
    if 2 * 60 <= minute < 5 * 60:
        return "LONDON"
    if 7 * 60 <= minute < 10 * 60:
        return "NEW_YORK"
    return None


def parse_position(raw: Any, *, expected_symbol: str, context: str) -> Position:
    value = _mapping(raw, context)
    _exact_keys(value, POSITION_KEYS, context)
    sequence = value["sequence"]
    if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence <= 0:
        raise AdjudicationError(f"{context}.sequence must be a positive integer")
    entry_deals_raw = _list(value["entry_deals"], f"{context}.entry_deals")
    if not entry_deals_raw or any(not isinstance(item, str) or not item for item in entry_deals_raw):
        raise AdjudicationError(f"{context}.entry_deals must contain non-empty strings")
    if len(set(entry_deals_raw)) != len(entry_deals_raw):
        raise AdjudicationError(f"{context}.entry_deals contains duplicates")
    exit_deal = value["exit_deal"]
    if not isinstance(exit_deal, str) or not exit_deal:
        raise AdjudicationError(f"{context}.exit_deal must be a non-empty string")
    _expect(value["symbol"], expected_symbol, f"{context}.symbol")
    if value["side"] not in {"buy", "sell"}:
        raise AdjudicationError(f"{context}.side must be buy or sell")
    volume = value["volume"]
    if not isinstance(volume, str) or DECIMAL_RE.fullmatch(volume) is None:
        raise AdjudicationError(f"{context}.volume must be a canonical decimal string")
    if decimal_value(volume, f"{context}.volume") <= ZERO:
        raise AdjudicationError(f"{context}.volume must be positive")
    entry_times_raw = _list(value["entry_times"], f"{context}.entry_times")
    if not entry_times_raw:
        raise AdjudicationError(f"{context}.entry_times cannot be empty")
    entry_times = tuple(
        _parse_broker_time(item, f"{context}.entry_times[{index}]")
        for index, item in enumerate(entry_times_raw)
    )
    exit_time = _parse_broker_time(value["exit_time"], f"{context}.exit_time")
    if any(entry_time > exit_time for entry_time in entry_times):
        raise AdjudicationError(f"{context} contains an entry after its exit")
    raw_net = money(value["raw_net_usd"], f"{context}.raw_net_usd")
    swap = money(value["swap_usd"], f"{context}.swap_usd")
    entry_cost = money(value["entry_external_cost_usd"], f"{context}.entry_external_cost_usd")
    exit_cost = money(value["exit_external_cost_usd"], f"{context}.exit_external_cost_usd")
    external_cost = money(value["external_cost_usd"], f"{context}.external_cost_usd")
    adjusted_net = money(value["cost_adjusted_net_usd"], f"{context}.cost_adjusted_net_usd")
    if entry_cost < ZERO or exit_cost < ZERO or external_cost < ZERO:
        raise AdjudicationError(f"{context} external costs cannot be negative")
    if entry_cost + exit_cost != external_cost:
        raise AdjudicationError(f"{context} entry/exit external cost reconciliation failed")
    if raw_net - external_cost != adjusted_net:
        raise AdjudicationError(f"{context} cost-adjusted net reconciliation failed")
    position = Position(
        sequence=sequence,
        entry_deals=tuple(entry_deals_raw),
        exit_deal=exit_deal,
        symbol=expected_symbol,
        side=value["side"],
        volume=volume,
        entry_times=entry_times,
        entry_times_raw=tuple(entry_times_raw),
        exit_time=exit_time,
        exit_time_raw=value["exit_time"],
        raw_net=raw_net,
        swap=swap,
        entry_external_cost=entry_cost,
        exit_external_cost=exit_cost,
        external_cost=external_cost,
        adjusted_net=adjusted_net,
    )
    if expected_symbol in {"EURUSD.DWX", "GBPUSD.DWX"} and position.session is None:
        raise AdjudicationError(
            f"{context} has outside-session or mixed-session partial entries"
        )
    return position


@dataclass(frozen=True)
class Metrics:
    trades: int
    net: Decimal
    gross_profit: Decimal
    gross_loss: Decimal
    external_cost: Decimal
    profit_factor: Decimal | None
    profit_factor_state: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "trades": self.trades,
            "net_profit_usd": money_text(self.net),
            "gross_profit_usd": money_text(self.gross_profit),
            "gross_loss_usd": money_text(self.gross_loss),
            "external_cost_usd": money_text(self.external_cost),
            "profit_factor": (
                decimal_text(self.profit_factor) if self.profit_factor is not None else None
            ),
            "profit_factor_state": self.profit_factor_state,
        }


def aggregate_positions(positions: Iterable[Position]) -> Metrics:
    rows = tuple(positions)
    net = sum((row.adjusted_net for row in rows), ZERO)
    gross_profit = sum((max(row.adjusted_net, ZERO) for row in rows), ZERO)
    gross_loss = sum((min(row.adjusted_net, ZERO) for row in rows), ZERO)
    external_cost = sum((row.external_cost for row in rows), ZERO)
    if gross_loss < ZERO:
        factor = gross_profit / -gross_loss
        state = "FINITE"
    elif gross_profit > ZERO:
        factor = None
        state = "INFINITE_NO_LOSSES"
    else:
        factor = None
        state = "UNDEFINED_NO_PROFIT_OR_LOSS"
    return Metrics(len(rows), net, gross_profit, gross_loss, external_cost, factor, state)


def _pf_at_least(metrics: Metrics, floor: Decimal) -> bool:
    if metrics.profit_factor_state == "INFINITE_NO_LOSSES":
        return True
    return metrics.profit_factor is not None and metrics.profit_factor >= floor


def closed_balance_drawdown(positions: Iterable[Position]) -> Decimal:
    balance = STARTING_EQUITY
    peak = balance
    maximum = ZERO
    for row in sorted(positions, key=lambda item: (item.exit_time, item.symbol, item.sequence)):
        balance += row.adjusted_net
        peak = max(peak, balance)
        maximum = max(maximum, peak - balance)
    return maximum


def pooled_same_timestamp_drawdown(positions: Iterable[Position]) -> Decimal:
    by_timestamp: defaultdict[datetime, Decimal] = defaultdict(lambda: ZERO)
    for row in positions:
        by_timestamp[row.exit_time] += row.adjusted_net
    balance = STARTING_EQUITY
    peak = balance
    maximum = ZERO
    for timestamp in sorted(by_timestamp):
        balance += by_timestamp[timestamp]
        peak = max(peak, balance)
        maximum = max(maximum, peak - balance)
    return maximum


def _validate_metrics(raw: Any, positions: tuple[Position, ...], context: str) -> None:
    value = _mapping(raw, context)
    required = {
        "closed_positions",
        "external_cost_total_usd",
        "cost_adjusted_net_profit_usd",
        "cost_adjusted_gross_profit_usd",
        "cost_adjusted_gross_loss_usd",
        "cost_adjusted_profit_factor",
        "cost_adjusted_profit_factor_state",
        "max_cumulative_closed_balance_drawdown_usd",
    }
    _required_keys(value, required, context)
    observed = aggregate_positions(positions)
    _expect(value["closed_positions"], observed.trades, f"{context}.closed_positions")
    comparisons = {
        "external_cost_total_usd": observed.external_cost,
        "cost_adjusted_net_profit_usd": observed.net,
        "cost_adjusted_gross_profit_usd": observed.gross_profit,
        "cost_adjusted_gross_loss_usd": observed.gross_loss,
        "max_cumulative_closed_balance_drawdown_usd": closed_balance_drawdown(positions),
    }
    for key, expected in comparisons.items():
        parsed = money(value[key], f"{context}.{key}")
        if parsed != expected:
            raise AdjudicationError(
                f"{context}.{key} drift: expected {money_text(expected)}, got {value[key]}"
            )
    _expect(
        value["cost_adjusted_profit_factor_state"],
        observed.profit_factor_state,
        f"{context}.cost_adjusted_profit_factor_state",
    )
    reported_pf = value["cost_adjusted_profit_factor"]
    if observed.profit_factor is None:
        if reported_pf is not None:
            raise AdjudicationError(f"{context}.cost_adjusted_profit_factor must be null")
    else:
        parsed_pf = decimal_value(reported_pf, f"{context}.cost_adjusted_profit_factor")
        expected_pf = observed.profit_factor.quantize(
            Decimal("0.00000001"), rounding=ROUND_HALF_UP
        )
        if parsed_pf != expected_pf:
            raise AdjudicationError(
                f"{context}.cost_adjusted_profit_factor does not match report-0 positions"
            )


def _binding_compat(
    raw: Any,
    *,
    context: str,
    root: Path | None = None,
) -> evidence_io.FileBinding:
    """Validate v5 ``size_bytes`` bindings and the launcher's legacy ``size`` spelling."""

    value = _mapping(raw, context)
    if set(value) == {"path", "size", "sha256"}:
        normalized = {
            "path": value["path"],
            "size_bytes": value["size"],
            "sha256": value["sha256"],
        }
    else:
        normalized = value
    return evidence_io.validate_file_binding(normalized, context=context, root=root)


def _binding_dict(binding: evidence_io.FileBinding) -> dict[str, Any]:
    return binding.as_dict()


@dataclass(frozen=True)
class CellEvidence:
    key: CellKey
    pointer: evidence_io.FileBinding
    pointer_sidecar: evidence_io.FileBinding
    receipt: evidence_io.FileBinding
    receipt_sidecar: evidence_io.FileBinding
    artifacts: Mapping[str, Any]
    toolchain: Mapping[str, Any]
    toolchain_sha256: str
    positions: tuple[Position, ...]
    metrics: Metrics
    native_drawdown: Decimal
    maximum_drawdown: Decimal
    duplicate_deal_sha256: str
    duplicate_run_sha256: str
    closure_sha256: str

    def inventory_record(self) -> dict[str, Any]:
        return {
            "cell_id": self.key.cell_id,
            "selection_role": self.key.market.selection_role,
            "request": expected_request(self.key),
            "pointer": _binding_dict(self.pointer),
            "pointer_sidecar": _binding_dict(self.pointer_sidecar),
            "receipt": _binding_dict(self.receipt),
            "receipt_sidecar": _binding_dict(self.receipt_sidecar),
            "artifacts": self.artifacts,
            "toolchain_sha256": self.toolchain_sha256,
            "duplicate_identity": {
                "required_runs": 2,
                "canonical_deal_sequence_sha256": self.duplicate_deal_sha256,
                "run_fingerprint_sha256": self.duplicate_run_sha256,
                "duplicate_fingerprint_check": "PASS",
            },
            "evidence_closure_sha256": self.closure_sha256,
        }


def expected_request(key: CellKey) -> dict[str, Any]:
    market = key.market
    return {
        "symbol": market.symbol,
        "timeframe": market.timeframe,
        "variant": key.variant,
        "from": market.from_date,
        "to": market.to_date,
        "runs": 2,
        "binding": market.binding,
    }


POINTER_KEYS = {
    "schema_version",
    "artifact_type",
    "protocol_id",
    "phase_id",
    "cell_id",
    "selection_role",
    "request",
    "receipt",
    "published_utc",
}
POINTER_RECEIPT_KEYS = {
    "path",
    "size_bytes",
    "sha256",
    "sidecar_path",
    "sidecar_file_sha256",
}
RECEIPT_KEYS = {
    "schema_version",
    "artifact_type",
    "status",
    "created_utc",
    "run_id",
    "protocol_id",
    "request",
    "fixed_tester_contract",
    "evidence_policy",
    "freeze_identity",
    "duplicate_identity",
    "toolchain",
    "artifacts",
}
ARTIFACT_KEYS = {
    "validator_pre",
    "validator_post",
    "runner_result",
    "runner_summary",
    "cost_audit",
    "raw_reports",
    "tester_inis",
    "tester_logs",
}
RUNTIME_TOOLCHAIN_KEYS = {
    "runtime_snapshot",
    "external_runtime",
    "postflight",
    "final_snapshot_verification",
}
RUNTIME_SNAPSHOT_BINDING_KEYS = {
    "root_path",
    "repo_root",
    "manifest_path",
    "manifest_size_bytes",
    "manifest_sha256",
    "manifest_sidecar_path",
    "manifest_sidecar_sha256",
    "selected_set_repo_relative",
    "role_bindings",
}
RUNTIME_SNAPSHOT_MANIFEST_KEYS = {
    "schema_version",
    "artifact_type",
    "status",
    "run_id",
    "source_repo_root",
    "snapshot_root",
    "snapshot_repo_root",
    "freeze_identity",
    "request",
    "files",
    "closure_sha256",
}
RUNTIME_SNAPSHOT_FILE_KEYS = {
    "role",
    "repo_relative_path",
    "source_path",
    "snapshot_path",
    "size_bytes",
    "sha256",
}
RUNTIME_SNAPSHOT_ROLES = {
    "launcher",
    "launcher_support",
    "validator",
    "generator",
    "report_auditor",
    "protocol",
    "sets_manifest",
    "sets_manifest_detached",
    "selected_set",
    "ea_binary",
    "runner_dev1_controller",
    "runner_dev1_child",
    "runner_smoke",
    "runner_dispatch_resolver",
    "runner_dispatch_pipeline",
    "runner_dispatch_gates",
    "tester_defaults",
    "tester_groups_canonical",
}
RUNTIME_SNAPSHOT_PATHS: dict[str, str | None] = {
    "launcher": "framework/EAs/QM5_20009_ict-liquidity-portfolio/tools/run_research_phase.ps1",
    "launcher_support": "framework/EAs/QM5_20009_ict-liquidity-portfolio/tools/research_launcher_support.psm1",
    "validator": "framework/EAs/QM5_20009_ict-liquidity-portfolio/tools/validate_research_run.py",
    "generator": "framework/EAs/QM5_20009_ict-liquidity-portfolio/tools/generate_research_sets.py",
    "report_auditor": "framework/EAs/QM5_20009_ict-liquidity-portfolio/tools/audit_mt5_report.py",
    "protocol": "framework/EAs/QM5_20009_ict-liquidity-portfolio/docs/research_protocol_v5.json",
    "sets_manifest": "framework/EAs/QM5_20009_ict-liquidity-portfolio/sets/manifest.json",
    "sets_manifest_detached": "framework/EAs/QM5_20009_ict-liquidity-portfolio/sets/manifest.sha256",
    "selected_set": None,
    "ea_binary": "framework/EAs/QM5_20009_ict-liquidity-portfolio/QM5_20009_ict-liquidity-portfolio.ex5",
    "runner_dev1_controller": "framework/scripts/run_dev1_smoke.ps1",
    "runner_dev1_child": "framework/scripts/invoke_dev1_smoke_task.ps1",
    "runner_smoke": "framework/scripts/run_smoke.ps1",
    "runner_dispatch_resolver": "framework/scripts/resolve_backtest_target.py",
    "runner_dispatch_pipeline": "framework/scripts/pipeline_dispatcher.py",
    "runner_dispatch_gates": "framework/scripts/dl054_gates.py",
    "tester_defaults": "framework/registry/tester_defaults.json",
    "tester_groups_canonical": "framework/registry/tester_groups/Darwinex-Live_real.canonical.txt",
}
EXTERNAL_RUNTIME_ROLES = {
    "terminal_binary",
    "metatester_binary",
    "commission_groups_dev1",
    "news_qmdev1_common_primary",
    "news_qmdev1_common_secondary",
    "python_executable",
    "powershell7",
}
VALIDATOR_REQUEST_KEYS = {"phase", "symbol", "timeframe", "variant", "from", "to"}
VALIDATOR_PRE_KEYS = {
    "schema_version",
    "artifact_type",
    "status",
    "run_id",
    "request",
    "freeze_inputs_sha256",
    "manifest_sha256",
    "set_sha256",
    "selected_data",
    "selected_data_sha256",
    "phase_unlock_records",
    "external_runtime",
    "runtime_snapshot",
}
VALIDATOR_POST_KEYS = {
    "schema_version",
    "artifact_type",
    "status",
    "run_id",
    "request",
    "preflight_receipt_sha256",
    "freeze_inputs_sha256",
    "manifest_sha256",
    "set_sha256",
    "selected_data_sha256",
    "phase_unlock_records",
    "runtime_snapshot_manifest_sha256",
    "external_runtime_sha256",
}


def _validate_pointer(policy: Policy, key: CellKey) -> tuple[dict[str, Any], evidence_io.FileBinding, evidence_io.FileBinding]:
    path = key.pointer_path(policy.pointer_root)
    sidecar_path = Path(f"{path}.sha256")
    if not evidence_io.is_within(path, policy.pointer_root):
        raise AdjudicationError(f"pointer escapes pointer root: {path}")
    pointer_binding = evidence_io.file_binding(path)
    sidecar_binding = evidence_io.verify_detached(path, sidecar_path)
    if not evidence_io.is_within(pointer_binding.path, policy.pointer_root):
        raise AdjudicationError(f"pointer resolves outside pointer root: {path}")
    if not evidence_io.is_within(sidecar_binding.path, policy.pointer_root):
        raise AdjudicationError(f"pointer sidecar resolves outside pointer root: {sidecar_path}")
    pointer = _strict_canonical_json(path, f"pointer {key.cell_id}")
    _exact_keys(pointer, POINTER_KEYS, f"pointer {key.cell_id}")
    _expect(pointer["schema_version"], SCHEMA_VERSION, f"pointer {key.cell_id}.schema_version")
    _expect(pointer["artifact_type"], POINTER_TYPE, f"pointer {key.cell_id}.artifact_type")
    _expect(pointer["protocol_id"], policy.protocol_id, f"pointer {key.cell_id}.protocol_id")
    _expect(pointer["phase_id"], PHASE_ID, f"pointer {key.cell_id}.phase_id")
    _expect(pointer["cell_id"], key.cell_id, f"pointer {key.cell_id}.cell_id")
    _expect(
        pointer["selection_role"],
        key.market.selection_role,
        f"pointer {key.cell_id}.selection_role",
    )
    _expect(pointer["request"], expected_request(key), f"pointer {key.cell_id}.request")
    _parse_utc(pointer["published_utc"], f"pointer {key.cell_id}.published_utc")
    return pointer, pointer_binding, sidecar_binding


def _validate_toolchain(
    raw: Any,
    context: str,
    *,
    expected_run_id: str | None = None,
    expected_snapshot_root: Path | None = None,
) -> tuple[dict[str, Any], str]:
    value = _mapping(raw, context)
    if not value:
        raise AdjudicationError(f"{context} cannot be empty")
    if set(value) == RUNTIME_TOOLCHAIN_KEYS:
        if expected_run_id is None or expected_snapshot_root is None:
            raise AdjudicationError(f"{context} lacks receipt-bound snapshot identity")
        return _validate_runtime_toolchain(
            value,
            context,
            expected_run_id=expected_run_id,
            expected_snapshot_root=expected_snapshot_root,
        )
    normalized: dict[str, Any] = {}
    for name in sorted(value):
        if not isinstance(name, str) or not name:
            raise AdjudicationError(f"{context} contains an invalid tool name")
        normalized[name] = _binding_dict(_binding_compat(value[name], context=f"{context}.{name}"))
    return normalized, evidence_io.canonical_payload_sha256(normalized)


def _canonical_relative_path(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value or "\\" in value:
        raise AdjudicationError(f"{context} is not a canonical repository path")
    path = PurePosixPath(value)
    if (
        path.is_absolute()
        or path.as_posix() != value
        or any(part in {"", ".", ".."} for part in path.parts)
        or ":" in path.parts[0]
    ):
        raise AdjudicationError(f"{context} escapes/is not canonical")
    return value


def _validate_runtime_toolchain(
    value: Mapping[str, Any],
    context: str,
    *,
    expected_run_id: str,
    expected_snapshot_root: Path,
) -> tuple[dict[str, Any], str]:
    snapshot = _mapping(value["runtime_snapshot"], f"{context}.runtime_snapshot")
    _exact_keys(snapshot, RUNTIME_SNAPSHOT_BINDING_KEYS, f"{context}.runtime_snapshot")
    for name in ("root_path", "repo_root", "manifest_path", "manifest_sidecar_path"):
        if not isinstance(snapshot[name], str) or not snapshot[name] or not Path(snapshot[name]).is_absolute():
            raise AdjudicationError(f"{context}.runtime_snapshot.{name} must be absolute")
    root = Path(str(snapshot["root_path"])).resolve(strict=False)
    repo_root = Path(str(snapshot["repo_root"])).resolve(strict=False)
    manifest_path = Path(str(snapshot["manifest_path"])).resolve(strict=False)
    sidecar_path = Path(str(snapshot["manifest_sidecar_path"])).resolve(strict=False)
    _expect(
        root,
        expected_snapshot_root.resolve(strict=False),
        f"{context}.runtime_snapshot.root_path",
    )
    _expect(repo_root, root / "repo", f"{context}.runtime_snapshot.repo_root")
    _expect(
        manifest_path,
        root / "runtime_manifest.json",
        f"{context}.runtime_snapshot.manifest_path",
    )
    _expect(
        sidecar_path,
        Path(f"{manifest_path}.sha256"),
        f"{context}.runtime_snapshot.manifest_sidecar_path",
    )
    manifest_binding = _binding_compat(
        {
            "path": str(manifest_path),
            "size_bytes": snapshot["manifest_size_bytes"],
            "sha256": snapshot["manifest_sha256"],
        },
        context=f"{context}.runtime_snapshot.manifest",
        root=root,
    )
    sidecar_binding = evidence_io.verify_detached(manifest_path, sidecar_path)
    _expect(
        sidecar_binding.sha256,
        evidence_io.require_sha256(
            snapshot["manifest_sidecar_sha256"],
            f"{context}.runtime_snapshot.manifest_sidecar_sha256",
        ),
        f"{context}.runtime_snapshot.manifest_sidecar_sha256",
    )
    manifest = _strict_canonical_json(manifest_path, f"{context}.runtime_snapshot.manifest")
    _exact_keys(
        manifest,
        RUNTIME_SNAPSHOT_MANIFEST_KEYS,
        f"{context}.runtime_snapshot.manifest",
    )
    _expect(manifest["schema_version"], 1, f"{context}.runtime_snapshot.schema_version")
    _expect(
        manifest["artifact_type"],
        "QM5_20009_RESEARCH_RUNTIME_SNAPSHOT",
        f"{context}.runtime_snapshot.artifact_type",
    )
    _expect(manifest["status"], "SEALED", f"{context}.runtime_snapshot.status")
    _expect(
        Path(str(manifest["snapshot_root"])).resolve(strict=False),
        root,
        f"{context}.runtime_snapshot.snapshot_root",
    )
    _expect(
        Path(str(manifest["snapshot_repo_root"])).resolve(strict=False),
        repo_root,
        f"{context}.runtime_snapshot.snapshot_repo_root",
    )
    _expect(manifest["run_id"], expected_run_id, f"{context}.runtime_snapshot.run_id")
    freeze_identity = _mapping(
        manifest["freeze_identity"], f"{context}.runtime_snapshot.freeze_identity"
    )
    _exact_keys(
        freeze_identity,
        {"freeze_inputs_sha256", "manifest_sha256"},
        f"{context}.runtime_snapshot.freeze_identity",
    )
    for name in ("freeze_inputs_sha256", "manifest_sha256"):
        evidence_io.require_sha256(
            freeze_identity[name], f"{context}.runtime_snapshot.freeze_identity.{name}"
        )
    request = _mapping(manifest["request"], f"{context}.runtime_snapshot.request")
    _exact_keys(request, VALIDATOR_REQUEST_KEYS, f"{context}.runtime_snapshot.request")
    source_root_raw = manifest["source_repo_root"]
    if not isinstance(source_root_raw, str) or not source_root_raw or not Path(source_root_raw).is_absolute():
        raise AdjudicationError(f"{context}.runtime_snapshot.source_repo_root must be absolute")
    source_root = Path(os.path.abspath(source_root_raw))

    role_bindings = _mapping(
        snapshot["role_bindings"], f"{context}.runtime_snapshot.role_bindings"
    )
    _exact_keys(
        role_bindings,
        RUNTIME_SNAPSHOT_ROLES,
        f"{context}.runtime_snapshot.role_bindings",
    )
    files = _list(manifest["files"], f"{context}.runtime_snapshot.files")
    rows_by_role: dict[str, Mapping[str, Any]] = {}
    normalized_roles: dict[str, Any] = {}
    for index, raw_row in enumerate(files):
        row = _mapping(raw_row, f"{context}.runtime_snapshot.files[{index}]")
        _exact_keys(
            row,
            RUNTIME_SNAPSHOT_FILE_KEYS,
            f"{context}.runtime_snapshot.files[{index}]",
        )
        role = row["role"]
        if not isinstance(role, str) or role not in RUNTIME_SNAPSHOT_ROLES or role in rows_by_role:
            raise AdjudicationError(f"{context}.runtime_snapshot has invalid/duplicate role")
        relative = _canonical_relative_path(
            row["repo_relative_path"], f"{context}.runtime_snapshot.{role}.relative"
        )
        contracted_relative = RUNTIME_SNAPSHOT_PATHS[role]
        if contracted_relative is not None:
            _expect(
                relative,
                contracted_relative,
                f"{context}.runtime_snapshot.{role}.relative",
            )
        elif PurePosixPath(relative).parent.as_posix() != (
            "framework/EAs/QM5_20009_ict-liquidity-portfolio/sets"
        ):
            raise AdjudicationError(
                f"{context}.runtime_snapshot.selected_set is outside the frozen set directory"
            )
        expected_path = (repo_root / Path(*PurePosixPath(relative).parts)).resolve(
            strict=False
        )
        expected_source = Path(
            os.path.abspath(source_root.joinpath(*PurePosixPath(relative).parts))
        )
        _expect(
            os.path.normcase(os.path.abspath(str(row["source_path"]))),
            os.path.normcase(str(expected_source)),
            f"{context}.runtime_snapshot.{role}.source_path",
        )
        _expect(
            Path(str(row["snapshot_path"])).resolve(strict=False),
            expected_path,
            f"{context}.runtime_snapshot.{role}.snapshot_path",
        )
        bound = _binding_compat(
            role_bindings[role],
            context=f"{context}.runtime_snapshot.role_bindings.{role}",
            root=repo_root,
        )
        _expect(bound.path, str(expected_path), f"{context}.runtime_snapshot.{role}.path")
        _expect(bound.size_bytes, row["size_bytes"], f"{context}.runtime_snapshot.{role}.size")
        _expect(bound.sha256, row["sha256"], f"{context}.runtime_snapshot.{role}.sha256")
        rows_by_role[role] = row
        normalized_roles[role] = {
            "repo_relative_path": relative,
            "size_bytes": bound.size_bytes,
            "sha256": bound.sha256,
        }
    _exact_keys(rows_by_role, RUNTIME_SNAPSHOT_ROLES, f"{context}.runtime_snapshot.files")
    if [str(row["role"]) for row in files] != sorted(RUNTIME_SNAPSHOT_ROLES):
        raise AdjudicationError(f"{context}.runtime_snapshot file order is not canonical")
    _expect(
        manifest["closure_sha256"],
        evidence_io.canonical_payload_sha256(files),
        f"{context}.runtime_snapshot.closure_sha256",
    )
    _expect(
        snapshot["selected_set_repo_relative"],
        normalized_roles["selected_set"]["repo_relative_path"],
        f"{context}.runtime_snapshot.selected_set_repo_relative",
    )

    external_rows = _list(value["external_runtime"], f"{context}.external_runtime")
    external: dict[str, Any] = {}
    for index, raw_row in enumerate(external_rows):
        row = _mapping(raw_row, f"{context}.external_runtime[{index}]")
        _exact_keys(
            row,
            {"role", "path", "size_bytes", "sha256"},
            f"{context}.external_runtime[{index}]",
        )
        role = row["role"]
        if not isinstance(role, str) or role not in EXTERNAL_RUNTIME_ROLES or role in external:
            raise AdjudicationError(f"{context}.external_runtime has invalid/duplicate role")
        binding = _binding_compat(
            {key: row[key] for key in ("path", "size_bytes", "sha256")},
            context=f"{context}.external_runtime.{role}",
        )
        external[role] = _binding_dict(binding)
    _exact_keys(external, EXTERNAL_RUNTIME_ROLES, f"{context}.external_runtime")
    if [str(row["role"]) for row in external_rows] != sorted(EXTERNAL_RUNTIME_ROLES):
        raise AdjudicationError(f"{context}.external_runtime order is not canonical")

    postflight = _mapping(value["postflight"], f"{context}.postflight")
    final = _mapping(
        value["final_snapshot_verification"],
        f"{context}.final_snapshot_verification",
    )
    _expect(final, postflight, f"{context}.final_snapshot_verification")
    _exact_keys(postflight, VALIDATOR_POST_KEYS, f"{context}.postflight")
    for field, expected in (
        ("schema_version", 1),
        ("status", "PASS"),
        ("artifact_type", "QM5_20009_RESEARCH_VALIDATOR_POST_RECEIPT"),
        ("run_id", manifest["run_id"]),
        ("request", request),
        ("freeze_inputs_sha256", freeze_identity["freeze_inputs_sha256"]),
        ("manifest_sha256", freeze_identity["manifest_sha256"]),
        ("set_sha256", normalized_roles["selected_set"]["sha256"]),
        ("runtime_snapshot_manifest_sha256", manifest_binding.sha256),
        ("external_runtime_sha256", evidence_io.canonical_payload_sha256(external_rows)),
    ):
        _expect(postflight.get(field), expected, f"{context}.postflight.{field}")
    for name in ("preflight_receipt_sha256", "selected_data_sha256"):
        evidence_io.require_sha256(postflight[name], f"{context}.postflight.{name}")
    if not isinstance(postflight["phase_unlock_records"], list):
        raise AdjudicationError(f"{context}.postflight.phase_unlock_records must be an array")
    normalized = {
        # The selected set is deliberately cell-specific.  It is validated above
        # and again against the PRE/final receipt, but cannot participate in the
        # 52-cell common-toolchain identity.
        "runtime_snapshot_roles": {
            role: normalized_roles[role]
            for role in sorted(normalized_roles)
            if role != "selected_set"
        },
        "external_runtime": external,
    }
    return normalized, evidence_io.canonical_payload_sha256(normalized)


def _validate_artifacts(
    raw: Any, *, context: str, receipt_root: Path
) -> tuple[dict[str, Any], dict[str, evidence_io.FileBinding]]:
    value = _mapping(raw, context)
    _exact_keys(value, ARTIFACT_KEYS, context)
    normalized: dict[str, Any] = {}
    scalar_bindings: dict[str, evidence_io.FileBinding] = {}
    for name in sorted(ARTIFACT_KEYS - {"raw_reports", "tester_inis", "tester_logs"}):
        binding = _binding_compat(value[name], context=f"{context}.{name}", root=receipt_root)
        scalar_bindings[name] = binding
        normalized[name] = _binding_dict(binding)
    for name in ("raw_reports", "tester_inis", "tester_logs"):
        items = _list(value[name], f"{context}.{name}")
        if len(items) != 2:
            raise AdjudicationError(f"{context}.{name} must contain exactly two runs")
        bindings = [
            _binding_compat(item, context=f"{context}.{name}[{index}]", root=receipt_root)
            for index, item in enumerate(items)
        ]
        normalized[name] = [_binding_dict(binding) for binding in bindings]
        for index, binding in enumerate(bindings):
            scalar_bindings[f"{name}[{index}]"] = binding
    paths: dict[str, str] = {}
    for name, binding in scalar_bindings.items():
        normalized_path = os.path.normcase(str(Path(binding.path).resolve(strict=False)))
        if normalized_path in paths:
            raise AdjudicationError(
                f"{context} aliases distinct artifacts {paths[normalized_path]} and {name}: "
                f"{binding.path}"
            )
        paths[normalized_path] = name
    return normalized, scalar_bindings


def _validate_nested_validator_receipts(
    *,
    receipt: Mapping[str, Any],
    key: CellKey,
    artifact_bindings: Mapping[str, evidence_io.FileBinding],
) -> None:
    toolchain = _mapping(receipt["toolchain"], f"receipt {key.cell_id}.toolchain")
    if set(toolchain) != RUNTIME_TOOLCHAIN_KEYS:
        return

    pre_binding = artifact_bindings["validator_pre"]
    post_binding = artifact_bindings["validator_post"]
    pre_path = Path(pre_binding.path)
    post_path = Path(post_binding.path)
    evidence_io.verify_detached(pre_path, Path(f"{pre_path}.sha256"))
    evidence_io.verify_detached(post_path, Path(f"{post_path}.sha256"))
    pre = _strict_canonical_json(pre_path, f"validator PRE {key.cell_id}")
    post = _strict_canonical_json(post_path, f"validator POST {key.cell_id}")
    _exact_keys(pre, VALIDATOR_PRE_KEYS, f"validator PRE {key.cell_id}")
    _exact_keys(post, VALIDATOR_POST_KEYS, f"validator POST {key.cell_id}")

    run_id = receipt["run_id"]
    expected_validator_request = {
        "phase": "DEV",
        "symbol": key.market.symbol,
        "timeframe": key.market.timeframe,
        "variant": key.variant,
        "from": key.market.from_date,
        "to": key.market.to_date,
    }
    for payload, label, artifact_type in (
        (pre, "PRE", "QM5_20009_RESEARCH_VALIDATOR_PRE_RECEIPT"),
        (post, "POST", "QM5_20009_RESEARCH_VALIDATOR_POST_RECEIPT"),
    ):
        _expect(payload["schema_version"], 1, f"validator {label} {key.cell_id}.schema")
        _expect(payload["artifact_type"], artifact_type, f"validator {label} {key.cell_id}.type")
        _expect(payload["status"], "PASS", f"validator {label} {key.cell_id}.status")
        _expect(payload["run_id"], run_id, f"validator {label} {key.cell_id}.run_id")
        _expect(
            payload["request"],
            expected_validator_request,
            f"validator {label} {key.cell_id}.request",
        )

    snapshot = _mapping(toolchain["runtime_snapshot"], f"receipt {key.cell_id}.runtime_snapshot")
    external_runtime = _list(
        toolchain["external_runtime"], f"receipt {key.cell_id}.external_runtime"
    )
    _expect(pre["runtime_snapshot"], snapshot, f"validator PRE {key.cell_id}.runtime_snapshot")
    _expect(pre["external_runtime"], external_runtime, f"validator PRE {key.cell_id}.external_runtime")
    _expect(post, toolchain["postflight"], f"validator POST {key.cell_id}.toolchain payload")
    _expect(
        post["preflight_receipt_sha256"],
        pre_binding.sha256,
        f"validator POST {key.cell_id}.preflight receipt binding",
    )

    freeze = _mapping(receipt["freeze_identity"], f"receipt {key.cell_id}.freeze_identity")
    _exact_keys(
        freeze,
        {
            "freeze_inputs_sha256",
            "manifest_sha256",
            "set_sha256",
            "selected_data_sha256",
            "phase_unlock_records",
            "postflight_exact_match",
        },
        f"receipt {key.cell_id}.freeze_identity",
    )
    for name in (
        "freeze_inputs_sha256",
        "manifest_sha256",
        "set_sha256",
        "selected_data_sha256",
    ):
        expected_sha = evidence_io.require_sha256(
            freeze[name], f"receipt {key.cell_id}.freeze_identity.{name}"
        )
        _expect(pre[name], expected_sha, f"validator PRE {key.cell_id}.{name}")
        if name != "selected_data_sha256" or name in post:
            _expect(post[name], expected_sha, f"validator POST {key.cell_id}.{name}")
    if not isinstance(pre["selected_data"], list):
        raise AdjudicationError(f"validator PRE {key.cell_id}.selected_data must be an array")
    _expect(
        evidence_io.canonical_payload_sha256(pre["selected_data"]),
        pre["selected_data_sha256"],
        f"validator PRE {key.cell_id}.selected_data_sha256",
    )
    _expect(
        pre["phase_unlock_records"],
        freeze["phase_unlock_records"],
        f"validator PRE {key.cell_id}.phase_unlock_records",
    )
    _expect(
        post["phase_unlock_records"],
        freeze["phase_unlock_records"],
        f"validator POST {key.cell_id}.phase_unlock_records",
    )

    roles = _mapping(snapshot["role_bindings"], f"receipt {key.cell_id}.runtime roles")
    selected = _mapping(roles["selected_set"], f"receipt {key.cell_id}.selected set")
    _expect(selected["sha256"], freeze["set_sha256"], f"receipt {key.cell_id}.selected set hash")
    kind = "index" if key.market.symbol in {"NDX.DWX", "GDAXI.DWX"} else "fx"
    expected_set_name = (
        f"QM5_20009_{key.market.symbol.replace('.', '_')}_{key.market.timeframe}_"
        f"{kind}_{key.variant}.set"
    )
    selected_relative = _canonical_relative_path(
        snapshot["selected_set_repo_relative"],
        f"receipt {key.cell_id}.selected_set_repo_relative",
    )
    _expect(
        PurePosixPath(selected_relative).name,
        expected_set_name,
        f"receipt {key.cell_id}.selected set filename",
    )


def _validate_runner_summary(
    path: Path,
    *,
    key: CellKey,
    reports: Sequence[evidence_io.FileBinding],
) -> Decimal:
    summary = evidence_io.load_json_strict(path)
    required = {
        "result",
        "symbol",
        "period",
        "model",
        "requested_runs",
        "deterministic",
        "model4_log_marker_detected",
        "oninit_failure_detected",
        "log_bomb_detected",
        "runs",
    }
    _required_keys(summary, required, f"runner summary {key.cell_id}")
    _expect(summary["result"], "PASS", f"runner summary {key.cell_id}.result")
    _expect(summary["symbol"], key.market.symbol, f"runner summary {key.cell_id}.symbol")
    _expect(summary["period"], key.market.timeframe, f"runner summary {key.cell_id}.period")
    _expect(summary["model"], 4, f"runner summary {key.cell_id}.model")
    _expect(summary["requested_runs"], 2, f"runner summary {key.cell_id}.requested_runs")
    _expect(summary["deterministic"], True, f"runner summary {key.cell_id}.deterministic")
    _expect(
        summary["model4_log_marker_detected"],
        True,
        f"runner summary {key.cell_id}.model4_log_marker_detected",
    )
    _expect(summary["oninit_failure_detected"], False, f"runner summary {key.cell_id}.oninit_failure_detected")
    _expect(summary["log_bomb_detected"], False, f"runner summary {key.cell_id}.log_bomb_detected")
    runs = _list(summary["runs"], f"runner summary {key.cell_id}.runs")
    if len(runs) != 2:
        raise AdjudicationError(f"runner summary {key.cell_id} must contain exactly two runs")
    drawdowns: list[Decimal] = []
    for index, raw_run in enumerate(runs):
        run = _mapping(raw_run, f"runner summary {key.cell_id}.runs[{index}]")
        _required_keys(
            run,
            {"status", "real_ticks_marker", "report_canonical_path", "native_max_equity_drawdown_usd"},
            f"runner summary {key.cell_id}.runs[{index}]",
        )
        _expect(run["status"], "OK", f"runner summary {key.cell_id}.runs[{index}].status")
        _expect(run["real_ticks_marker"], True, f"runner summary {key.cell_id}.runs[{index}].real_ticks_marker")
        if Path(str(run["report_canonical_path"])).resolve(strict=False) != Path(reports[index].path):
            raise AdjudicationError(f"runner summary {key.cell_id} raw report path drift at run {index}")
        drawdowns.append(
            money(
                run["native_max_equity_drawdown_usd"],
                f"runner summary {key.cell_id}.runs[{index}].native_max_equity_drawdown_usd",
            )
        )
    if drawdowns[0] < ZERO or drawdowns[0] != drawdowns[1]:
        raise AdjudicationError(f"runner summary {key.cell_id} duplicate native drawdown drift")
    return drawdowns[0]


def _validate_cost_audit(
    path: Path,
    *,
    key: CellKey,
    reports: Sequence[evidence_io.FileBinding],
    duplicate_identity: Mapping[str, Any],
) -> tuple[tuple[Position, ...], Metrics, str, str]:
    audit = evidence_io.load_json_strict(path)
    required = {
        "schema_version",
        "artifact_type",
        "status",
        "duplicate_count",
        "duplicate_fingerprint_check",
        "canonical_deal_sequence_sha256",
        "run_fingerprint_sha256",
        "reports",
    }
    _required_keys(audit, required, f"cost audit {key.cell_id}")
    _expect(audit["schema_version"], SCHEMA_VERSION, f"cost audit {key.cell_id}.schema_version")
    _expect(audit["artifact_type"], COST_AUDIT_TYPE, f"cost audit {key.cell_id}.artifact_type")
    _expect(audit["status"], "PASS", f"cost audit {key.cell_id}.status")
    _expect(audit["duplicate_count"], 2, f"cost audit {key.cell_id}.duplicate_count")
    _expect(audit["duplicate_fingerprint_check"], "PASS", f"cost audit {key.cell_id}.duplicate_fingerprint_check")
    deal_hash = evidence_io.require_sha256(
        audit["canonical_deal_sequence_sha256"], f"cost audit {key.cell_id}.deal hash"
    )
    run_hash = evidence_io.require_sha256(
        audit["run_fingerprint_sha256"], f"cost audit {key.cell_id}.run hash"
    )
    _expect(
        duplicate_identity["canonical_deal_sequence_sha256"],
        deal_hash,
        f"receipt {key.cell_id}.duplicate deal hash",
    )
    _expect(
        duplicate_identity["run_fingerprint_sha256"],
        run_hash,
        f"receipt {key.cell_id}.duplicate run hash",
    )
    report_rows = _list(audit["reports"], f"cost audit {key.cell_id}.reports")
    if len(report_rows) != 2:
        raise AdjudicationError(f"cost audit {key.cell_id} must contain exactly two reports")
    parsed_positions: list[tuple[Position, ...]] = []
    semantic_payloads: list[str] = []
    for index, raw_report in enumerate(report_rows):
        report = _mapping(raw_report, f"cost audit {key.cell_id}.reports[{index}]")
        _required_keys(
            report,
            {
                "schema_version",
                "artifact_type",
                "status",
                "report",
                "header",
                "identity",
                "native_integrity",
                "closed_positions",
                "metrics",
                "same_day_swap_proof",
            },
            f"cost audit {key.cell_id}.reports[{index}]",
        )
        _expect(
            report["schema_version"],
            SCHEMA_VERSION,
            f"cost audit {key.cell_id}.reports[{index}].schema_version",
        )
        _expect(
            report["artifact_type"],
            COST_REPORT_TYPE,
            f"cost audit {key.cell_id}.reports[{index}].artifact_type",
        )
        _expect(report["status"], "PASS", f"cost audit {key.cell_id}.reports[{index}].status")
        report_binding = _mapping(report["report"], f"cost audit {key.cell_id}.reports[{index}].report")
        _required_keys(report_binding, {"path", "sha256"}, f"cost audit {key.cell_id}.reports[{index}].report")
        if Path(str(report_binding["path"])).resolve(strict=False) != Path(reports[index].path):
            raise AdjudicationError(f"cost audit {key.cell_id} report path drift at run {index}")
        _expect(report_binding["sha256"], reports[index].sha256, f"cost audit {key.cell_id}.reports[{index}].report.sha256")
        header = _mapping(report["header"], f"cost audit {key.cell_id}.reports[{index}].header")
        expected_header = {
            "symbol": key.market.symbol,
            "timeframe": key.market.timeframe,
            "from_date": key.market.from_date,
            "to_date": key.market.to_date,
            "initial_deposit": money_text(STARTING_EQUITY),
            "currency": "USD",
        }
        for name, expected in expected_header.items():
            _expect(header.get(name), expected, f"cost audit {key.cell_id}.reports[{index}].header.{name}")
        identity = _mapping(report["identity"], f"cost audit {key.cell_id}.reports[{index}].identity")
        _expect(identity.get("canonical_deal_sequence_sha256"), deal_hash, f"cost audit {key.cell_id}.reports[{index}].deal hash")
        _expect(identity.get("run_fingerprint_sha256"), run_hash, f"cost audit {key.cell_id}.reports[{index}].run hash")
        native_integrity = _mapping(
            report["native_integrity"],
            f"cost audit {key.cell_id}.reports[{index}].native_integrity",
        )
        for name, expected in {
            "commission_exactly_zero": True,
            "simulated_commission_input_exactly_zero": True,
            "ledger_balance_recurrence": "PASS_CENT_EXACT",
            "total_net_reconciliation": "PASS_CENT_EXACT",
        }.items():
            _expect(
                native_integrity.get(name),
                expected,
                f"cost audit {key.cell_id}.reports[{index}].native_integrity.{name}",
            )
        raw_positions = _list(report["closed_positions"], f"cost audit {key.cell_id}.reports[{index}].closed_positions")
        positions = tuple(
            parse_position(
                row,
                expected_symbol=key.market.symbol,
                context=f"cost audit {key.cell_id}.reports[{index}].closed_positions[{position_index}]",
            )
            for position_index, row in enumerate(raw_positions)
        )
        sequences = [position.sequence for position in positions]
        if sequences != sorted(sequences) or len(sequences) != len(set(sequences)):
            raise AdjudicationError(f"cost audit {key.cell_id} position sequence is not strictly ordered")
        from_date = datetime.strptime(key.market.from_date, "%Y-%m-%d").date()
        to_date = datetime.strptime(key.market.to_date, "%Y-%m-%d").date()
        if any(
            not (from_date <= position.new_york_exit.date() <= to_date)
            or any(
                not (
                    from_date
                    <= (entry_time - timedelta(hours=7)).date()
                    <= to_date
                )
                for entry_time in position.entry_times
            )
            for position in positions
        ):
            raise AdjudicationError(
                f"cost audit {key.cell_id}.reports[{index}] contains positions outside the frozen window"
            )
        _validate_metrics(report["metrics"], positions, f"cost audit {key.cell_id}.reports[{index}].metrics")
        proof = _mapping(report["same_day_swap_proof"], f"cost audit {key.cell_id}.reports[{index}].same_day_swap_proof")
        expected_proof = "PASS" if positions else "NOT_APPLICABLE_NO_CLOSED_POSITIONS"
        _expect(proof.get("status"), expected_proof, f"cost audit {key.cell_id}.reports[{index}].same_day_swap_proof.status")
        if positions:
            if any(position.swap != ZERO for position in positions):
                raise AdjudicationError(
                    f"cost audit {key.cell_id}.reports[{index}] contains non-zero swap"
                )
            if any(
                any(
                    (entry_time - timedelta(hours=7)).date()
                    != position.new_york_exit.date()
                    for entry_time in position.entry_times
                )
                for position in positions
            ):
                raise AdjudicationError(
                    f"cost audit {key.cell_id}.reports[{index}] violates same-NY-day closure"
                )
        parsed_positions.append(positions)
        semantic_payloads.append(
            evidence_io.canonical_payload_sha256(
                {
                    "positions": [position.canonical() for position in positions],
                    "metrics": report["metrics"],
                    "same_day_swap_proof": report["same_day_swap_proof"],
                }
            )
        )
    if semantic_payloads[0] != semantic_payloads[1]:
        raise AdjudicationError(f"cost audit {key.cell_id} semantic duplicate payload drift")
    primary = parsed_positions[0]
    return primary, aggregate_positions(primary), deal_hash, run_hash


def load_cell_evidence(policy: Policy, key: CellKey) -> CellEvidence:
    pointer, pointer_binding, pointer_sidecar = _validate_pointer(policy, key)
    raw_receipt_ref = _mapping(pointer["receipt"], f"pointer {key.cell_id}.receipt")
    _exact_keys(raw_receipt_ref, POINTER_RECEIPT_KEYS, f"pointer {key.cell_id}.receipt")
    receipt_path = Path(str(raw_receipt_ref["path"])).resolve(strict=False)
    if not evidence_io.is_within(receipt_path, policy.receipt_root):
        raise AdjudicationError(f"pointer {key.cell_id} receipt escapes receipt root")
    receipt_binding = evidence_io.validate_file_binding(
        {
            "path": raw_receipt_ref["path"],
            "size_bytes": raw_receipt_ref["size_bytes"],
            "sha256": raw_receipt_ref["sha256"],
        },
        context=f"pointer {key.cell_id}.receipt",
        root=policy.receipt_root,
    )
    receipt_sidecar_path = Path(str(raw_receipt_ref["sidecar_path"])).resolve(strict=False)
    if receipt_sidecar_path != Path(f"{receipt_path}.sha256"):
        raise AdjudicationError(f"pointer {key.cell_id} receipt sidecar path is not canonical")
    if not evidence_io.is_within(receipt_sidecar_path, policy.receipt_root):
        raise AdjudicationError(f"pointer {key.cell_id} receipt sidecar escapes receipt root")
    receipt_sidecar = evidence_io.verify_detached(receipt_path, receipt_sidecar_path, allow_bare=True)
    _expect(
        receipt_sidecar.sha256,
        evidence_io.require_sha256(
            raw_receipt_ref["sidecar_file_sha256"],
            f"pointer {key.cell_id}.receipt.sidecar_file_sha256",
        ),
        f"pointer {key.cell_id}.receipt.sidecar_file_sha256",
    )

    receipt = evidence_io.load_json_strict(receipt_path)
    _exact_keys(receipt, RECEIPT_KEYS, f"receipt {key.cell_id}")
    _expect(receipt["schema_version"], SCHEMA_VERSION, f"receipt {key.cell_id}.schema_version")
    _expect(receipt["artifact_type"], LAUNCHER_RECEIPT_TYPE, f"receipt {key.cell_id}.artifact_type")
    _expect(receipt["status"], "PASS", f"receipt {key.cell_id}.status")
    _expect(receipt["protocol_id"], policy.protocol_id, f"receipt {key.cell_id}.protocol_id")
    _parse_utc(receipt["created_utc"], f"receipt {key.cell_id}.created_utc")
    if not isinstance(receipt["run_id"], str) or not receipt["run_id"]:
        raise AdjudicationError(f"receipt {key.cell_id}.run_id must be non-empty")
    request = _mapping(receipt["request"], f"receipt {key.cell_id}.request")
    for name, expected in expected_request(key).items():
        _expect(request.get(name), expected, f"receipt {key.cell_id}.request.{name}")
    tester = _mapping(receipt["fixed_tester_contract"], f"receipt {key.cell_id}.fixed_tester_contract")
    for name, expected in {
        "model": 4,
        "initial_deposit": 100000,
        "currency": "USD",
        "commission_per_lot": 0,
        "commission_per_side_native": 0,
        "direct_terminal_start_forbidden": True,
    }.items():
        _expect(tester.get(name), expected, f"receipt {key.cell_id}.fixed_tester_contract.{name}")
    policy_row = _mapping(receipt["evidence_policy"], f"receipt {key.cell_id}.evidence_policy")
    _expect(policy_row.get("verdict"), "NOT_ADJUDICATED", f"receipt {key.cell_id}.evidence_policy.verdict")
    _expect(policy_row.get("separate_recorded_phase_verdict_is_required"), True, f"receipt {key.cell_id}.evidence_policy.separate verdict")
    freeze = _mapping(receipt["freeze_identity"], f"receipt {key.cell_id}.freeze_identity")
    _expect(freeze.get("freeze_inputs_sha256"), policy.freeze_inputs_sha256, f"receipt {key.cell_id}.freeze_inputs_sha256")
    _expect(freeze.get("manifest_sha256"), policy.manifest_sha256, f"receipt {key.cell_id}.manifest_sha256")
    _expect(freeze.get("postflight_exact_match"), True, f"receipt {key.cell_id}.postflight_exact_match")
    evidence_io.require_sha256(freeze.get("set_sha256"), f"receipt {key.cell_id}.set_sha256")
    evidence_io.require_sha256(freeze.get("selected_data_sha256"), f"receipt {key.cell_id}.selected_data_sha256")
    duplicate = _mapping(receipt["duplicate_identity"], f"receipt {key.cell_id}.duplicate_identity")
    _required_keys(
        duplicate,
        {"required_runs", "canonical_deal_sequence_sha256", "run_fingerprint_sha256", "duplicate_fingerprint_check"},
        f"receipt {key.cell_id}.duplicate_identity",
    )
    _expect(duplicate["required_runs"], 2, f"receipt {key.cell_id}.duplicate_identity.required_runs")
    _expect(duplicate["duplicate_fingerprint_check"], "PASS", f"receipt {key.cell_id}.duplicate fingerprint")
    evidence_io.require_sha256(duplicate["canonical_deal_sequence_sha256"], f"receipt {key.cell_id}.deal hash")
    evidence_io.require_sha256(duplicate["run_fingerprint_sha256"], f"receipt {key.cell_id}.run hash")

    toolchain, toolchain_hash = _validate_toolchain(
        receipt["toolchain"],
        f"receipt {key.cell_id}.toolchain",
        expected_run_id=receipt["run_id"],
        expected_snapshot_root=receipt_path.parent / "runtime_snapshot",
    )
    artifacts, artifact_bindings = _validate_artifacts(
        receipt["artifacts"], context=f"receipt {key.cell_id}.artifacts", receipt_root=policy.receipt_root
    )
    _validate_nested_validator_receipts(
        receipt=receipt,
        key=key,
        artifact_bindings=artifact_bindings,
    )
    report_bindings = [artifact_bindings["raw_reports[0]"], artifact_bindings["raw_reports[1]"]]
    native_drawdown = _validate_runner_summary(
        Path(artifact_bindings["runner_summary"].path), key=key, reports=report_bindings
    )
    positions, metrics, deal_hash, run_hash = _validate_cost_audit(
        Path(artifact_bindings["cost_audit"].path),
        key=key,
        reports=report_bindings,
        duplicate_identity=duplicate,
    )
    maximum_drawdown = max(native_drawdown, closed_balance_drawdown(positions))
    closure = evidence_io.canonical_payload_sha256(
        {
            "cell_id": key.cell_id,
            "pointer": _binding_dict(pointer_binding),
            "pointer_sidecar": _binding_dict(pointer_sidecar),
            "receipt": _binding_dict(receipt_binding),
            "receipt_sidecar": _binding_dict(receipt_sidecar),
            "artifacts": artifacts,
            "toolchain": toolchain,
        }
    )
    return CellEvidence(
        key=key,
        pointer=pointer_binding,
        pointer_sidecar=pointer_sidecar,
        receipt=receipt_binding,
        receipt_sidecar=receipt_sidecar,
        artifacts=artifacts,
        toolchain=toolchain,
        toolchain_sha256=toolchain_hash,
        positions=positions,
        metrics=metrics,
        native_drawdown=native_drawdown,
        maximum_drawdown=maximum_drawdown,
        duplicate_deal_sha256=deal_hash,
        duplicate_run_sha256=run_hash,
        closure_sha256=closure,
    )


@dataclass(frozen=True)
class Inventory:
    payload: Mapping[str, Any]
    cells: Mapping[str, CellEvidence]


def build_inventory(policy: Policy, *, created_utc: str) -> Inventory:
    _parse_utc(created_utc, "inventory created_utc")
    cells = expected_cells()
    expected_paths = {key.pointer_path(policy.pointer_root).resolve(strict=False) for key in cells}
    phase_root = policy.pointer_root / PHASE_ID
    actual_paths = (
        {path.resolve(strict=False) for path in phase_root.rglob("*.pointer.json")}
        if phase_root.exists()
        else set()
    )
    missing = sorted(str(path) for path in expected_paths - actual_paths)
    extra = sorted(str(path) for path in actual_paths - expected_paths)
    if missing or extra:
        raise AdjudicationError(f"DEV pointer matrix mismatch: missing={missing} extra={extra}")
    loaded: dict[str, CellEvidence] = {}
    toolchain_hash: str | None = None
    toolchain: Mapping[str, Any] | None = None
    for key in cells:
        cell = load_cell_evidence(policy, key)
        if toolchain_hash is None:
            toolchain_hash = cell.toolchain_sha256
            toolchain = cell.toolchain
        elif cell.toolchain_sha256 != toolchain_hash or cell.toolchain != toolchain:
            raise AdjudicationError(f"toolchain closure drift at {key.cell_id}")
        loaded[key.cell_id] = cell
    if len(loaded) != 52:
        raise AdjudicationError(f"internal inventory cardinality drift: {len(loaded)}")
    payload = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": INVENTORY_TYPE,
        "status": "COMPLETE",
        "created_utc": created_utc,
        "protocol_id": policy.protocol_id,
        "phase_id": PHASE_ID,
        "freeze_identity": {
            "freeze_inputs_sha256": policy.freeze_inputs_sha256,
            "manifest_sha256": policy.manifest_sha256,
        },
        "matrix_contract": {
            "markets": [market.symbol for market in MARKETS],
            "variants": list(VARIANTS),
            "expected_cells": 52,
            "observed_cells": 52,
            "required_semantic_duplicate_runs_per_cell": 2,
            "duplicate_runs_counted_for_merit": 1,
        },
        "common_toolchain_sha256": toolchain_hash,
        "common_toolchain": toolchain,
        "cells": [loaded[key.cell_id].inventory_record() for key in cells],
    }
    return Inventory(payload, loaded)


def _cell(inventory: Inventory, symbol: str, variant: str) -> CellEvidence:
    market = MARKET_BY_SYMBOL[symbol]
    return inventory.cells[CellKey(market, variant).cell_id]


def _mandatory_cells(cell: CellEvidence) -> list[dict[str, Any]]:
    market = cell.key.market
    if market.symbol in {"EURUSD.DWX", "GBPUSD.DWX"}:
        rows: list[dict[str, Any]] = []
        for session in ("LONDON", "NEW_YORK"):
            for direction in ("LONG", "SHORT"):
                positions = tuple(
                    item
                    for item in cell.positions
                    if item.session == session and item.direction == direction
                )
                rows.append(
                    {
                        "cell": f"{market.symbol}|{session}|{direction}",
                        "metrics": aggregate_positions(positions).as_dict(),
                    }
                )
        return rows
    return [
        {
            "cell": f"{market.symbol}|{direction}",
            "metrics": aggregate_positions(
                item for item in cell.positions if item.direction == direction
            ).as_dict(),
        }
        for direction in ("LONG", "SHORT")
    ]


def _year_counts(positions: Iterable[Position], years: Sequence[int]) -> dict[str, int]:
    counts = Counter(item.new_york_exit.year for item in positions)
    return {str(year): counts[year] for year in years}


def _baseline_gate(
    *,
    sleeve: str,
    positions: tuple[Position, ...],
    member_positions: Mapping[str, tuple[Position, ...]],
    drawdown: Decimal,
) -> dict[str, Any]:
    metrics = aggregate_positions(positions)
    pf_floor = profit_factor_floor(metrics.trades) if metrics.trades else None
    checks: list[dict[str, Any]] = []

    def add(check_id: str, passed: bool, observed: Any, required: Any) -> None:
        checks.append(
            {
                "check_id": check_id,
                "status": "PASS" if passed else "FAIL",
                "observed": observed,
                "required": required,
            }
        )

    minimum_total = 10 if sleeve == "A" else 60
    add("minimum_total_trades", metrics.trades >= minimum_total, metrics.trades, minimum_total)
    annual: dict[str, Any] = {}
    for symbol, rows in sorted(member_positions.items()):
        market = MARKET_BY_SYMBOL[symbol]
        year_counts = _year_counts(rows, market.years)
        annual[symbol] = year_counts
        add(
            f"{symbol}_minimum_five_trades_each_touched_calendar_year",
            all(count >= 5 for count in year_counts.values()),
            year_counts,
            {str(year): 5 for year in market.years},
        )
        member_minimum = 10 if sleeve == "A" else 30
        add(
            f"{symbol}_minimum_member_trades",
            len(rows) >= member_minimum,
            len(rows),
            member_minimum,
        )
    add("cost_adjusted_net_positive", metrics.net > ZERO, money_text(metrics.net), "> 0.00")
    add(
        "small_sample_profit_factor_floor",
        pf_floor is not None and _pf_at_least(metrics, pf_floor),
        metrics.as_dict()["profit_factor"],
        decimal_text(pf_floor) if pf_floor is not None else "DEFINED_FOR_N_GT_0",
    )
    add(
        "maximum_drawdown_25_percent",
        drawdown <= MAX_DRAWDOWN,
        money_text(drawdown),
        f"<= {money_text(MAX_DRAWDOWN)}",
    )
    return {
        "sleeve": sleeve,
        "status": "PASS" if all(row["status"] == "PASS" for row in checks) else "FAIL",
        "metrics": metrics.as_dict(),
        "drawdown_usd": money_text(drawdown),
        "annual_trade_counts": annual,
        "checks": checks,
    }


def _plateau_gate(
    *,
    sleeve: str,
    variant_positions: Mapping[str, tuple[Position, ...]],
    center_baseline_status: str,
) -> dict[str, Any]:
    metrics = {variant: aggregate_positions(rows) for variant, rows in variant_positions.items()}
    center = metrics["center"]
    profitable = sum(1 for variant in VARIANTS if metrics[variant].net > ZERO)
    neighbours: list[dict[str, Any]] = []
    for variant in NEIGHBOURS:
        observed = metrics[variant]
        retention_pass = observed.trades * 10 >= center.trades * 7
        pf_pass = _pf_at_least(observed, Decimal("1.0"))
        neighbours.append(
            {
                "variant": variant,
                "status": "PASS" if retention_pass and pf_pass else "FAIL",
                "trade_count": observed.trades,
                "center_trade_count": center.trades,
                "trade_retention_exact_check": f"{observed.trades}*10 >= {center.trades}*7",
                "trade_retention_status": "PASS" if retention_pass else "FAIL",
                "profit_factor": observed.as_dict()["profit_factor"],
                "profit_factor_state": observed.profit_factor_state,
                "profit_factor_at_least_one_status": "PASS" if pf_pass else "FAIL",
            }
        )
    checks = {
        "center_binding_baseline": center_baseline_status == "PASS",
        "at_least_nine_of_thirteen_net_profitable": profitable >= 9,
        "all_twelve_neighbours_retain_70_percent_and_pf_at_least_one": all(
            row["status"] == "PASS" for row in neighbours
        ),
        "deployed_variant_remains_preregistered_center": True,
        "neighbour_rescue_forbidden": True,
    }
    return {
        "sleeve": sleeve,
        "status": "PASS" if all(checks.values()) else "FAIL",
        "selected_variant": "center",
        "profitable_variants": profitable,
        "variant_metrics": [
            {"variant": variant, "metrics": metrics[variant].as_dict()} for variant in VARIANTS
        ],
        "neighbours": neighbours,
        "checks": [
            {"check_id": name, "status": "PASS" if passed else "FAIL"}
            for name, passed in checks.items()
        ],
    }


@dataclass(frozen=True)
class Evaluation:
    status: str
    payload: Mapping[str, Any]


def evaluate_inventory(inventory: Inventory, *, created_utc: str) -> Evaluation:
    _parse_utc(created_utc, "evaluation created_utc")
    ndx_by_variant = {
        variant: _cell(inventory, "NDX.DWX", variant).positions for variant in VARIANTS
    }
    fx_by_variant = {
        variant: tuple(
            [
                *_cell(inventory, "GBPUSD.DWX", variant).positions,
                *_cell(inventory, "EURUSD.DWX", variant).positions,
            ]
        )
        for variant in VARIANTS
    }
    ndx_center = _cell(inventory, "NDX.DWX", "center")
    gbp_center = _cell(inventory, "GBPUSD.DWX", "center")
    eur_center = _cell(inventory, "EURUSD.DWX", "center")
    sleeve_a_baseline = _baseline_gate(
        sleeve="A",
        positions=ndx_center.positions,
        member_positions={"NDX.DWX": ndx_center.positions},
        drawdown=ndx_center.maximum_drawdown,
    )
    fx_center_positions = fx_by_variant["center"]
    pooled_drawdown = pooled_same_timestamp_drawdown(fx_center_positions)
    sleeve_b_drawdown = max(
        gbp_center.maximum_drawdown,
        eur_center.maximum_drawdown,
        pooled_drawdown,
    )
    sleeve_b_baseline = _baseline_gate(
        sleeve="B",
        positions=fx_center_positions,
        member_positions={
            "EURUSD.DWX": eur_center.positions,
            "GBPUSD.DWX": gbp_center.positions,
        },
        drawdown=sleeve_b_drawdown,
    )
    sleeve_a_plateau = _plateau_gate(
        sleeve="A",
        variant_positions=ndx_by_variant,
        center_baseline_status=sleeve_a_baseline["status"],
    )
    sleeve_b_plateau = _plateau_gate(
        sleeve="B",
        variant_positions=fx_by_variant,
        center_baseline_status=sleeve_b_baseline["status"],
    )
    binding_pass = all(
        row["status"] == "PASS"
        for row in (
            sleeve_a_baseline,
            sleeve_b_baseline,
            sleeve_a_plateau,
            sleeve_b_plateau,
        )
    )
    mandatory = [
        {
            "cell_id": key.cell_id,
            "selection_role": key.market.selection_role,
            "reported_subcells": _mandatory_cells(inventory.cells[key.cell_id]),
        }
        for key in expected_cells()
    ]
    gdax = [
        {
            "variant": variant,
            "metrics": _cell(inventory, "GDAXI.DWX", variant).metrics.as_dict(),
            "selection_effect": "NONE_TRANSPORT_DIAGNOSTIC_ONLY",
        }
        for variant in VARIANTS
    ]
    payload = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": EVIDENCE_TYPE,
        "status": "PASS" if binding_pass else "FAIL",
        "created_utc": created_utc,
        "phase_id": PHASE_ID,
        "matrix_status": "COMPLETE_52_OF_52",
        "duplicate_counting_policy": "REPORT_0_ONLY_AFTER_REPORT_0_REPORT_1_SEMANTIC_EQUALITY",
        "baseline_formula": {
            "minimum_trades_per_touched_calendar_year_per_required_symbol": 5,
            "profit_factor": "u=1.94/sqrt(N);d=u/sqrt(1+u^2);floor=max(1.10,(1+d)/(1-d));observed>=floor",
            "starting_equity_usd": money_text(STARTING_EQUITY),
            "maximum_drawdown_usd": money_text(MAX_DRAWDOWN),
            "pooled_drawdown_ordering": "EXACT_EXIT_TIMESTAMP_ATOMIC_GROUPS",
        },
        "binding_gates": {
            "sleeve_a_center": sleeve_a_baseline,
            "sleeve_b_center": sleeve_b_baseline,
            "sleeve_a_plateau": sleeve_a_plateau,
            "sleeve_b_plateau": sleeve_b_plateau,
        },
        "transport_diagnostic": {
            "symbol": "GDAXI.DWX",
            "may_be_zero_trade_or_losing": True,
            "never_affects_selection_or_plateau": True,
            "variants": gdax,
        },
        "mandatory_reported_cells": mandatory,
        "selected_configuration": {
            "sleeve_a": "center",
            "sleeve_b": "center",
            "neighbour_rescue_permitted": False,
        },
    }
    return Evaluation(payload["status"], payload)


def _publication_payloads(
    policy: Policy,
    inventory: Inventory,
    evaluation: Evaluation,
    *,
    created_utc: str,
) -> list[evidence_io.ArtifactPayload]:
    _parse_utc(created_utc, "publication created_utc")
    inventory_path = policy.output_root / "evidence" / "DEV.receipt_inventory.json"
    evidence_path = policy.output_root / "evidence" / "DEV.evidence.json"
    verdict_path = policy.output_root / "verdicts" / "DEV.verdict.json"

    inventory_bytes = evidence_io.canonical_json_bytes(inventory.payload)
    inventory_sha = evidence_io.sha256_bytes(inventory_bytes)
    inventory_sidecar = evidence_io.detached_bytes(inventory_sha, inventory_path.name)
    inventory_sidecar_sha = evidence_io.sha256_bytes(inventory_sidecar)

    evidence_payload = dict(evaluation.payload)
    evidence_payload["protocol_id"] = policy.protocol_id
    evidence_payload["freeze_identity"] = {
        "freeze_inputs_sha256": policy.freeze_inputs_sha256,
        "manifest_sha256": policy.manifest_sha256,
    }
    evidence_payload["inventory_binding"] = {
        "path": str(inventory_path.resolve(strict=False)),
        "size_bytes": len(inventory_bytes),
        "sha256": inventory_sha,
        "sidecar_path": str(Path(f"{inventory_path}.sha256").resolve(strict=False)),
        "sidecar_file_sha256": inventory_sidecar_sha,
    }
    evidence_payload["adjudicator_binding"] = evidence_io.file_binding(Path(__file__)).as_dict()
    evidence_bytes = evidence_io.canonical_json_bytes(evidence_payload)
    evidence_sha = evidence_io.sha256_bytes(evidence_bytes)
    evidence_sidecar = evidence_io.detached_bytes(evidence_sha, evidence_path.name)
    evidence_sidecar_sha = evidence_io.sha256_bytes(evidence_sidecar)

    verdict_payload = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": VERDICT_TYPE,
        "status": evaluation.status,
        "verdict": evaluation.status,
        "created_utc": created_utc,
        "protocol_id": policy.protocol_id,
        "phase_id": PHASE_ID,
        "freeze_identity": {
            "freeze_inputs_sha256": policy.freeze_inputs_sha256,
            "manifest_sha256": policy.manifest_sha256,
        },
        "inventory_binding": {
            "path": str(inventory_path.resolve(strict=False)),
            "size_bytes": len(inventory_bytes),
            "sha256": inventory_sha,
            "sidecar_path": str(Path(f"{inventory_path}.sha256").resolve(strict=False)),
            "sidecar_file_sha256": inventory_sidecar_sha,
        },
        "evidence_binding": {
            "path": str(evidence_path.resolve(strict=False)),
            "size_bytes": len(evidence_bytes),
            "sha256": evidence_sha,
            "sidecar_path": str(Path(f"{evidence_path}.sha256").resolve(strict=False)),
            "sidecar_file_sha256": evidence_sidecar_sha,
        },
        "publication_contract": {
            "exclusive_create_no_overwrite": True,
            "sidecar_before_authoritative_json": True,
            "input_graph_reloaded_immediately_before_publish": True,
            "verdict_json_is_final_commit_marker": True,
        },
    }
    verdict_bytes = evidence_io.canonical_json_bytes(verdict_payload)
    verdict_sha = evidence_io.sha256_bytes(verdict_bytes)
    verdict_sidecar = evidence_io.detached_bytes(verdict_sha, verdict_path.name)
    return [
        evidence_io.ArtifactPayload(Path(f"{inventory_path}.sha256"), inventory_sidecar),
        evidence_io.ArtifactPayload(inventory_path, inventory_bytes),
        evidence_io.ArtifactPayload(Path(f"{evidence_path}.sha256"), evidence_sidecar),
        evidence_io.ArtifactPayload(evidence_path, evidence_bytes),
        evidence_io.ArtifactPayload(Path(f"{verdict_path}.sha256"), verdict_sidecar),
        evidence_io.ArtifactPayload(verdict_path, verdict_bytes),
    ]


def publish_dev(
    policy: Policy,
    inventory: Inventory,
    evaluation: Evaluation,
    *,
    created_utc: str,
    fail_after: int | None = None,
) -> list[evidence_io.FileBinding]:
    """Publish inventory/evidence/verdict; the verdict JSON is always artifact six."""

    if inventory.payload.get("created_utc") != created_utc:
        raise AdjudicationError(
            "publication timestamp differs from the receipt inventory timestamp"
        )
    if evaluation.payload.get("created_utc") != created_utc:
        raise AdjudicationError(
            "publication timestamp differs from the adjudication evidence timestamp"
        )
    # Re-read the complete immutable graph immediately before staging.  This both
    # closes the load/evaluate/publish mutation window and prevents a caller from
    # supplying a hand-constructed Inventory or Evaluation object.
    current_inventory = build_inventory(policy, created_utc=created_utc)
    if evidence_io.canonical_payload_sha256(
        current_inventory.payload
    ) != evidence_io.canonical_payload_sha256(inventory.payload):
        raise AdjudicationError("receipt inventory changed before publication")
    current_evaluation = evaluate_inventory(
        current_inventory, created_utc=created_utc
    )
    if evidence_io.canonical_payload_sha256(
        current_evaluation.payload
    ) != evidence_io.canonical_payload_sha256(evaluation.payload):
        raise AdjudicationError("adjudication result changed before publication")
    return evidence_io.publish_exclusive_bundle(
        _publication_payloads(
            policy,
            current_inventory,
            current_evaluation,
            created_utc=created_utc,
        ),
        fail_after=fail_after,
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pointer-root", required=True, type=Path)
    parser.add_argument("--receipt-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    parser.add_argument("--freeze-inputs-sha256", required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--protocol-id", default=DEFAULT_PROTOCOL_ID)
    parser.add_argument("--created-utc", required=True)
    parser.add_argument("--no-publish", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        policy = Policy(
            pointer_root=args.pointer_root,
            receipt_root=args.receipt_root,
            output_root=args.output_root,
            freeze_inputs_sha256=args.freeze_inputs_sha256,
            manifest_sha256=args.manifest_sha256,
            protocol_id=args.protocol_id,
        )
        inventory = build_inventory(policy, created_utc=args.created_utc)
        evaluation = evaluate_inventory(inventory, created_utc=args.created_utc)
        published: list[dict[str, Any]] = []
        if not args.no_publish:
            published = [
                binding.as_dict()
                for binding in publish_dev(
                    policy,
                    inventory,
                    evaluation,
                    created_utc=args.created_utc,
                )
            ]
        print(
            json.dumps(
                {
                    "status": evaluation.status,
                    "integrity": "PASS",
                    "matrix": "COMPLETE_52_OF_52",
                    "published": published,
                },
                sort_keys=True,
            )
        )
        return 0 if evaluation.status == "PASS" else 1
    except (AdjudicationError, evidence_io.EvidenceIOError, OSError) as exc:
        print(
            json.dumps(
                {
                    "status": "REJECT",
                    "integrity": "FAIL",
                    "error_type": type(exc).__name__,
                    "error": str(exc),
                },
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
