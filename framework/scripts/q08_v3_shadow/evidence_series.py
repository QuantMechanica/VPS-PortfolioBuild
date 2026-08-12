"""Fail-closed return-series contracts for future Q08 v3 evidence.

This module is deliberately side-effect free and is not wired into Q08 v2 or
any farm runner.  It solves one narrow evidence problem: every statistic must
operate on an explicitly bounded, zero-filled calendar axis.  Sparse active-day
samples are therefore never silently treated as a complete daily return series.

Only the Python standard library is used so the contract can be replayed in
minimal audit environments.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import math
import random
import re
from dataclasses import dataclass
from enum import Enum
from typing import Any, Iterable, Sequence


RETURN_PANEL_SCHEMA_VERSION = "q08_evidence_return_panel/v1"
BLOCK_BOOTSTRAP_SCHEMA_VERSION = "q08_evidence_block_bootstrap/v1"


class EvidenceSeriesError(ValueError):
    """Raised when evidence cannot safely form a complete return series."""


class CalendarBasis(str, Enum):
    WEEKDAY_252 = "WEEKDAY_252"
    ALL_DAYS_365 = "ALL_DAYS_365"

    @property
    def annualization_periods(self) -> int:
        return 252 if self is CalendarBasis.WEEKDAY_252 else 365


class ValueKind(str, Enum):
    RETURN = "RETURN"
    PNL = "PNL"


def _finite_number(value: object, *, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise EvidenceSeriesError(f"{field} must be a finite number")
    resolved = float(value)
    if not math.isfinite(resolved):
        raise EvidenceSeriesError(f"{field} must be a finite number")
    return resolved


def _strict_date(value: object, *, field: str) -> dt.date:
    if isinstance(value, dt.datetime):
        raise EvidenceSeriesError(f"{field} must be a date without a time")
    if isinstance(value, dt.date):
        return value
    if not isinstance(value, str):
        raise EvidenceSeriesError(f"{field} must be an ISO date")
    try:
        resolved = dt.date.fromisoformat(value)
    except ValueError as exc:
        raise EvidenceSeriesError(f"{field} must be an ISO date") from exc
    if value != resolved.isoformat():
        raise EvidenceSeriesError(f"{field} must use canonical YYYY-MM-DD form")
    return resolved


def _canonical_sha256(payload: object) -> str:
    encoded = json.dumps(
        payload,
        ensure_ascii=True,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


@dataclass(frozen=True, slots=True)
class ReferenceCapital:
    """Capital basis bound to an immutable source artifact.

    ``source_sha256`` is the digest of the external manifest, report, or
    configuration that authorises the amount.  The derived ``binding_sha256``
    makes the exact amount/currency/source tuple visible in downstream evidence.
    """

    amount: float
    currency: str
    source_id: str
    source_sha256: str

    def __post_init__(self) -> None:
        amount = _finite_number(self.amount, field="reference capital amount")
        if amount <= 0.0:
            raise EvidenceSeriesError("reference capital amount must be > 0")
        if not isinstance(self.currency, str) or not re.fullmatch(
            r"[A-Z]{3}", self.currency
        ):
            raise EvidenceSeriesError("reference capital currency must be ISO-style A-Z{3}")
        if (
            not isinstance(self.source_id, str)
            or not self.source_id
            or self.source_id != self.source_id.strip()
        ):
            raise EvidenceSeriesError("reference capital source_id must be non-empty and trimmed")
        if not isinstance(self.source_sha256, str) or not re.fullmatch(
            r"[0-9a-f]{64}", self.source_sha256
        ):
            raise EvidenceSeriesError("reference capital source_sha256 must be lowercase SHA-256")
        object.__setattr__(self, "amount", amount)

    @property
    def binding_sha256(self) -> str:
        return _canonical_sha256(
            {
                "amount": self.amount,
                "currency": self.currency,
                "source_id": self.source_id,
                "source_sha256": self.source_sha256,
            }
        )

    def to_dict(self) -> dict[str, object]:
        return {
            "amount": self.amount,
            "currency": self.currency,
            "source_id": self.source_id,
            "source_sha256": self.source_sha256,
            "binding_sha256": self.binding_sha256,
        }


@dataclass(frozen=True, slots=True)
class DailyObservation:
    day: dt.date
    value: float

    def __post_init__(self) -> None:
        object.__setattr__(self, "day", _strict_date(self.day, field="observation day"))
        object.__setattr__(
            self,
            "value",
            _finite_number(self.value, field="observation value"),
        )


@dataclass(frozen=True, slots=True)
class SleeveInput:
    sleeve_id: str
    value_kind: ValueKind
    observations: tuple[DailyObservation, ...]
    reference_capital: ReferenceCapital | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.sleeve_id, str) or not re.fullmatch(
            r"[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}", self.sleeve_id
        ):
            raise EvidenceSeriesError("sleeve_id must be a stable non-empty token")
        try:
            kind = (
                self.value_kind
                if isinstance(self.value_kind, ValueKind)
                else ValueKind(self.value_kind)
            )
        except (TypeError, ValueError) as exc:
            raise EvidenceSeriesError("value_kind must be RETURN or PNL") from exc
        try:
            observations = tuple(self.observations)
        except TypeError as exc:
            raise EvidenceSeriesError("observations must be an iterable") from exc
        if any(not isinstance(item, DailyObservation) for item in observations):
            raise EvidenceSeriesError("observations must contain DailyObservation values")
        if kind is ValueKind.PNL and not isinstance(
            self.reference_capital, ReferenceCapital
        ):
            raise EvidenceSeriesError(
                "PNL observations require a hash-bound reference capital"
            )
        if kind is ValueKind.RETURN and self.reference_capital is not None:
            raise EvidenceSeriesError(
                "RETURN observations must not carry a reference capital"
            )
        object.__setattr__(self, "value_kind", kind)
        object.__setattr__(self, "observations", observations)


@dataclass(frozen=True, slots=True)
class SleeveReturnSeries:
    sleeve_id: str
    source_value_kind: ValueKind
    reference_capital: ReferenceCapital | None
    observed_day_count: int
    zero_filled_day_count: int
    returns: tuple[float, ...]
    sharpe_annualized: float | None

    def __post_init__(self) -> None:
        if not isinstance(self.sleeve_id, str) or not re.fullmatch(
            r"[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}", self.sleeve_id
        ):
            raise EvidenceSeriesError("sleeve_id must be a stable non-empty token")
        if not isinstance(self.source_value_kind, ValueKind):
            raise EvidenceSeriesError("source_value_kind must be RETURN or PNL")
        if self.source_value_kind is ValueKind.PNL and not isinstance(
            self.reference_capital, ReferenceCapital
        ):
            raise EvidenceSeriesError("PNL return series requires reference capital")
        if self.source_value_kind is ValueKind.RETURN and self.reference_capital is not None:
            raise EvidenceSeriesError("RETURN series must not carry reference capital")
        if (
            isinstance(self.observed_day_count, bool)
            or not isinstance(self.observed_day_count, int)
            or self.observed_day_count < 0
        ):
            raise EvidenceSeriesError("observed_day_count must be a non-negative integer")
        if (
            isinstance(self.zero_filled_day_count, bool)
            or not isinstance(self.zero_filled_day_count, int)
            or self.zero_filled_day_count < 0
        ):
            raise EvidenceSeriesError("zero_filled_day_count must be a non-negative integer")
        returns = tuple(
            _finite_number(value, field=f"returns[{index}]")
            for index, value in enumerate(self.returns)
        )
        if self.observed_day_count + self.zero_filled_day_count != len(returns):
            raise EvidenceSeriesError("series day counts do not match return length")
        sharpe = self.sharpe_annualized
        if sharpe is not None:
            sharpe = _finite_number(sharpe, field="sharpe_annualized")
        object.__setattr__(self, "returns", returns)
        object.__setattr__(self, "sharpe_annualized", sharpe)

    @property
    def series_sha256(self) -> str:
        return _canonical_sha256(
            {
                "sleeve_id": self.sleeve_id,
                "source_value_kind": self.source_value_kind.value,
                "reference_capital": (
                    None
                    if self.reference_capital is None
                    else self.reference_capital.to_dict()
                ),
                "observed_day_count": self.observed_day_count,
                "zero_filled_day_count": self.zero_filled_day_count,
                "returns": list(self.returns),
            }
        )

    def to_dict(self) -> dict[str, object]:
        return {
            "sleeve_id": self.sleeve_id,
            "source_value_kind": self.source_value_kind.value,
            "reference_capital": (
                None
                if self.reference_capital is None
                else self.reference_capital.to_dict()
            ),
            "observed_day_count": self.observed_day_count,
            "zero_filled_day_count": self.zero_filled_day_count,
            "returns": list(self.returns),
            "sharpe_annualized": self.sharpe_annualized,
            "series_sha256": self.series_sha256,
        }


@dataclass(frozen=True, slots=True)
class ReturnPanel:
    calendar_basis: CalendarBasis
    coverage_start: dt.date
    coverage_end: dt.date
    axis: tuple[dt.date, ...]
    sleeves: tuple[SleeveReturnSeries, ...]

    def __post_init__(self) -> None:
        if not isinstance(self.calendar_basis, CalendarBasis):
            raise EvidenceSeriesError("calendar_basis must be a CalendarBasis")
        start = _strict_date(self.coverage_start, field="coverage_start")
        end = _strict_date(self.coverage_end, field="coverage_end")
        expected_axis = calendar_axis(
            coverage_start=start,
            coverage_end=end,
            calendar_basis=self.calendar_basis,
        )
        axis = tuple(
            _strict_date(day, field=f"axis[{index}]")
            for index, day in enumerate(self.axis)
        )
        if axis != expected_axis:
            raise EvidenceSeriesError(
                "panel axis is not the complete selected-calendar coverage axis"
            )
        sleeves = tuple(self.sleeves)
        if not sleeves or any(
            not isinstance(sleeve, SleeveReturnSeries) for sleeve in sleeves
        ):
            raise EvidenceSeriesError("panel requires SleeveReturnSeries values")
        sleeve_ids = [sleeve.sleeve_id for sleeve in sleeves]
        if len(set(sleeve_ids)) != len(sleeve_ids):
            raise EvidenceSeriesError("panel has duplicate sleeve_id")
        for sleeve in sleeves:
            if len(sleeve.returns) != len(axis):
                raise EvidenceSeriesError("panel sleeves are not aligned to the source axis")
            expected_sharpe = annualized_sharpe(
                sleeve.returns,
                calendar_basis=self.calendar_basis,
            )
            if expected_sharpe is None:
                if sleeve.sharpe_annualized is not None:
                    raise EvidenceSeriesError("series Sharpe does not match the panel calendar")
            elif sleeve.sharpe_annualized is None or not math.isclose(
                sleeve.sharpe_annualized,
                expected_sharpe,
                rel_tol=1e-12,
                abs_tol=1e-15,
            ):
                raise EvidenceSeriesError("series Sharpe does not match the panel calendar")
        object.__setattr__(self, "coverage_start", start)
        object.__setattr__(self, "coverage_end", end)
        object.__setattr__(self, "axis", axis)
        object.__setattr__(self, "sleeves", tuple(sorted(sleeves, key=lambda item: item.sleeve_id)))

    @property
    def annualization_periods(self) -> int:
        return self.calendar_basis.annualization_periods

    @property
    def axis_sha256(self) -> str:
        return _canonical_sha256(
            {
                "calendar_basis": self.calendar_basis.value,
                "coverage_start": self.coverage_start.isoformat(),
                "coverage_end": self.coverage_end.isoformat(),
                "axis": [day.isoformat() for day in self.axis],
            }
        )

    @property
    def panel_sha256(self) -> str:
        return _canonical_sha256(
            {
                "schema_version": RETURN_PANEL_SCHEMA_VERSION,
                "axis_sha256": self.axis_sha256,
                "sleeve_series_sha256": [
                    sleeve.series_sha256 for sleeve in self.sleeves
                ],
            }
        )

    def to_dict(self) -> dict[str, object]:
        return {
            "schema_version": RETURN_PANEL_SCHEMA_VERSION,
            "calendar_basis": self.calendar_basis.value,
            "annualization_periods": self.annualization_periods,
            "coverage_start": self.coverage_start.isoformat(),
            "coverage_end": self.coverage_end.isoformat(),
            "axis": [day.isoformat() for day in self.axis],
            "axis_sha256": self.axis_sha256,
            "panel_sha256": self.panel_sha256,
            "sleeves": [sleeve.to_dict() for sleeve in self.sleeves],
        }


@dataclass(frozen=True, slots=True)
class BootstrapSleevePath:
    sleeve_id: str
    returns: tuple[float, ...]

    def __post_init__(self) -> None:
        if not isinstance(self.sleeve_id, str) or not re.fullmatch(
            r"[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}", self.sleeve_id
        ):
            raise EvidenceSeriesError("bootstrap sleeve_id must be a stable token")
        object.__setattr__(
            self,
            "returns",
            tuple(
                _finite_number(value, field=f"bootstrap returns[{index}]")
                for index, value in enumerate(self.returns)
            ),
        )

    def to_dict(self) -> dict[str, object]:
        return {"sleeve_id": self.sleeve_id, "returns": list(self.returns)}


@dataclass(frozen=True, slots=True)
class BlockBootstrapPath:
    replicate: int
    source_indices: tuple[int, ...]
    sleeves: tuple[BootstrapSleevePath, ...]

    def __post_init__(self) -> None:
        if (
            isinstance(self.replicate, bool)
            or not isinstance(self.replicate, int)
            or self.replicate < 0
        ):
            raise EvidenceSeriesError("replicate must be a non-negative integer")
        indices = tuple(self.source_indices)
        if not indices or any(
            isinstance(index, bool) or not isinstance(index, int) or index < 0
            for index in indices
        ):
            raise EvidenceSeriesError("source_indices must be non-negative integers")
        sleeves = tuple(self.sleeves)
        if not sleeves or any(
            not isinstance(sleeve, BootstrapSleevePath) for sleeve in sleeves
        ):
            raise EvidenceSeriesError("bootstrap path requires sleeve paths")
        if len({sleeve.sleeve_id for sleeve in sleeves}) != len(sleeves):
            raise EvidenceSeriesError("bootstrap path has duplicate sleeve_id")
        if any(len(sleeve.returns) != len(indices) for sleeve in sleeves):
            raise EvidenceSeriesError("bootstrap sleeve paths are not aligned")
        object.__setattr__(self, "source_indices", indices)
        object.__setattr__(self, "sleeves", tuple(sorted(sleeves, key=lambda item: item.sleeve_id)))

    def to_dict(self) -> dict[str, object]:
        return {
            "replicate": self.replicate,
            "source_indices": list(self.source_indices),
            "sleeves": [sleeve.to_dict() for sleeve in self.sleeves],
        }


@dataclass(frozen=True, slots=True)
class BlockBootstrapResult:
    source_axis_sha256: str
    source_panel_sha256: str
    source_axis_length: int
    seed: int
    block_length: int
    sample_length: int
    paths: tuple[BlockBootstrapPath, ...]

    def __post_init__(self) -> None:
        for field, value in (
            ("source_axis_sha256", self.source_axis_sha256),
            ("source_panel_sha256", self.source_panel_sha256),
        ):
            if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value):
                raise EvidenceSeriesError(f"{field} must be lowercase SHA-256")
        for field, value, minimum in (
            ("source_axis_length", self.source_axis_length, 1),
            ("block_length", self.block_length, 2),
            ("sample_length", self.sample_length, 1),
        ):
            if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
                raise EvidenceSeriesError(f"{field} must be an integer >= {minimum}")
        if isinstance(self.seed, bool) or not isinstance(self.seed, int):
            raise EvidenceSeriesError("seed must be an integer")
        if self.block_length > self.source_axis_length:
            raise EvidenceSeriesError("block_length must not exceed source_axis_length")
        paths = tuple(self.paths)
        if not paths:
            raise EvidenceSeriesError("bootstrap result requires at least one path")
        if tuple(path.replicate for path in paths) != tuple(range(len(paths))):
            raise EvidenceSeriesError("bootstrap replicate indexes must be contiguous")
        for path in paths:
            if len(path.source_indices) != self.sample_length:
                raise EvidenceSeriesError("bootstrap path length does not match sample_length")
            if any(index >= self.source_axis_length for index in path.source_indices):
                raise EvidenceSeriesError("bootstrap source index exceeds source axis")
        object.__setattr__(self, "paths", paths)

    def to_dict(self) -> dict[str, object]:
        return {
            "schema_version": BLOCK_BOOTSTRAP_SCHEMA_VERSION,
            "method": "MOVING_BLOCK",
            "source_axis_sha256": self.source_axis_sha256,
            "source_panel_sha256": self.source_panel_sha256,
            "source_axis_length": self.source_axis_length,
            "seed": self.seed,
            "block_length": self.block_length,
            "sample_length": self.sample_length,
            "replicate_count": len(self.paths),
            "paths": [path.to_dict() for path in self.paths],
        }


def calendar_axis(
    *,
    coverage_start: dt.date | str,
    coverage_end: dt.date | str,
    calendar_basis: CalendarBasis | str,
) -> tuple[dt.date, ...]:
    """Build the complete, deterministic evidence axis."""

    start = _strict_date(coverage_start, field="coverage_start")
    end = _strict_date(coverage_end, field="coverage_end")
    if end < start:
        raise EvidenceSeriesError("coverage_end must not precede coverage_start")
    try:
        basis = (
            calendar_basis
            if isinstance(calendar_basis, CalendarBasis)
            else CalendarBasis(calendar_basis)
        )
    except (TypeError, ValueError) as exc:
        raise EvidenceSeriesError(
            "calendar_basis must be WEEKDAY_252 or ALL_DAYS_365"
        ) from exc

    days: list[dt.date] = []
    cursor = start
    while cursor <= end:
        if basis is CalendarBasis.ALL_DAYS_365 or cursor.weekday() < 5:
            days.append(cursor)
        cursor += dt.timedelta(days=1)
    if not days:
        raise EvidenceSeriesError("coverage contains no dates for the selected calendar")
    return tuple(days)


def annualized_sharpe(
    returns: Sequence[float], *, calendar_basis: CalendarBasis | str
) -> float | None:
    """Sample-standard-deviation Sharpe over the *complete* supplied axis."""

    try:
        basis = (
            calendar_basis
            if isinstance(calendar_basis, CalendarBasis)
            else CalendarBasis(calendar_basis)
        )
    except (TypeError, ValueError) as exc:
        raise EvidenceSeriesError(
            "calendar_basis must be WEEKDAY_252 or ALL_DAYS_365"
        ) from exc
    values = tuple(
        _finite_number(value, field=f"returns[{index}]")
        for index, value in enumerate(returns)
    )
    if len(values) < 2:
        return None
    mean = math.fsum(values) / len(values)
    variance = math.fsum((value - mean) ** 2 for value in values) / (len(values) - 1)
    if variance <= 0.0:
        return None
    result = mean / math.sqrt(variance) * math.sqrt(basis.annualization_periods)
    if not math.isfinite(result):
        raise EvidenceSeriesError("annualized Sharpe is non-finite")
    return result


def build_return_panel(
    *,
    coverage_start: dt.date | str,
    coverage_end: dt.date | str,
    calendar_basis: CalendarBasis | str,
    sleeves: Iterable[SleeveInput],
) -> ReturnPanel:
    """Synchronise sparse sleeve evidence on one full zero-filled axis."""

    start = _strict_date(coverage_start, field="coverage_start")
    end = _strict_date(coverage_end, field="coverage_end")
    try:
        basis = (
            calendar_basis
            if isinstance(calendar_basis, CalendarBasis)
            else CalendarBasis(calendar_basis)
        )
    except (TypeError, ValueError) as exc:
        raise EvidenceSeriesError(
            "calendar_basis must be WEEKDAY_252 or ALL_DAYS_365"
        ) from exc
    axis = calendar_axis(
        coverage_start=start,
        coverage_end=end,
        calendar_basis=basis,
    )
    axis_set = set(axis)
    try:
        inputs = tuple(sleeves)
    except TypeError as exc:
        raise EvidenceSeriesError("sleeves must be an iterable") from exc
    if not inputs:
        raise EvidenceSeriesError("at least one sleeve is required")
    if any(not isinstance(sleeve, SleeveInput) for sleeve in inputs):
        raise EvidenceSeriesError("sleeves must contain SleeveInput values")
    sleeve_ids = [sleeve.sleeve_id for sleeve in inputs]
    if len(set(sleeve_ids)) != len(sleeve_ids):
        raise EvidenceSeriesError("duplicate sleeve_id")

    series: list[SleeveReturnSeries] = []
    for sleeve in sorted(inputs, key=lambda item: item.sleeve_id):
        by_day: dict[dt.date, float] = {}
        for observation in sleeve.observations:
            if observation.day in by_day:
                raise EvidenceSeriesError(
                    f"sleeve {sleeve.sleeve_id!r} has duplicate day "
                    f"{observation.day.isoformat()}"
                )
            if observation.day < start or observation.day > end:
                raise EvidenceSeriesError(
                    f"sleeve {sleeve.sleeve_id!r} observation lies outside coverage"
                )
            if observation.day not in axis_set:
                raise EvidenceSeriesError(
                    f"sleeve {sleeve.sleeve_id!r} observation is outside the "
                    f"{basis.value} axis"
                )
            value = observation.value
            if sleeve.value_kind is ValueKind.PNL:
                assert sleeve.reference_capital is not None
                value /= sleeve.reference_capital.amount
            by_day[observation.day] = _finite_number(
                value,
                field=f"return for {sleeve.sleeve_id} on {observation.day.isoformat()}",
            )
        returns = tuple(by_day.get(day, 0.0) for day in axis)
        series.append(
            SleeveReturnSeries(
                sleeve_id=sleeve.sleeve_id,
                source_value_kind=sleeve.value_kind,
                reference_capital=sleeve.reference_capital,
                observed_day_count=len(by_day),
                zero_filled_day_count=len(axis) - len(by_day),
                returns=returns,
                sharpe_annualized=annualized_sharpe(
                    returns,
                    calendar_basis=basis,
                ),
            )
        )
    return ReturnPanel(
        calendar_basis=basis,
        coverage_start=start,
        coverage_end=end,
        axis=axis,
        sleeves=tuple(series),
    )


def moving_block_bootstrap(
    panel: ReturnPanel,
    *,
    seed: int,
    block_length: int,
    replicate_count: int,
    sample_length: int | None = None,
) -> BlockBootstrapResult:
    """Joint moving-block bootstrap over the complete panel axis.

    A block length of one is rejected deliberately: that would reduce the
    operation to IID day resampling.  One shared index path is applied to every
    sleeve in each replicate, preserving contemporaneous cross-sleeve structure.
    """

    if not isinstance(panel, ReturnPanel):
        raise EvidenceSeriesError("panel must be a ReturnPanel")
    if isinstance(seed, bool) or not isinstance(seed, int):
        raise EvidenceSeriesError("seed must be an integer")
    if isinstance(block_length, bool) or not isinstance(block_length, int):
        raise EvidenceSeriesError("block_length must be an integer")
    if block_length < 2:
        raise EvidenceSeriesError(
            "block_length must be >= 2; IID day resampling is not permitted"
        )
    source_length = len(panel.axis)
    if block_length > source_length:
        raise EvidenceSeriesError("block_length must not exceed the source axis")
    if isinstance(replicate_count, bool) or not isinstance(replicate_count, int):
        raise EvidenceSeriesError("replicate_count must be an integer")
    if replicate_count < 1:
        raise EvidenceSeriesError("replicate_count must be >= 1")
    resolved_sample_length = source_length if sample_length is None else sample_length
    if isinstance(resolved_sample_length, bool) or not isinstance(
        resolved_sample_length, int
    ):
        raise EvidenceSeriesError("sample_length must be an integer")
    if resolved_sample_length < 1:
        raise EvidenceSeriesError("sample_length must be >= 1")
    if any(len(sleeve.returns) != source_length for sleeve in panel.sleeves):
        raise EvidenceSeriesError("panel sleeves are not aligned to the source axis")

    rng = random.Random(seed)
    max_start = source_length - block_length
    paths: list[BlockBootstrapPath] = []
    for replicate in range(replicate_count):
        indices: list[int] = []
        while len(indices) < resolved_sample_length:
            start = rng.randrange(max_start + 1)
            take = min(block_length, resolved_sample_length - len(indices))
            indices.extend(range(start, start + take))
        source_indices = tuple(indices)
        paths.append(
            BlockBootstrapPath(
                replicate=replicate,
                source_indices=source_indices,
                sleeves=tuple(
                    BootstrapSleevePath(
                        sleeve_id=sleeve.sleeve_id,
                        returns=tuple(sleeve.returns[index] for index in source_indices),
                    )
                    for sleeve in panel.sleeves
                ),
            )
        )
    return BlockBootstrapResult(
        source_axis_sha256=panel.axis_sha256,
        source_panel_sha256=panel.panel_sha256,
        source_axis_length=source_length,
        seed=seed,
        block_length=block_length,
        sample_length=resolved_sample_length,
        paths=tuple(paths),
    )


__all__ = [
    "BLOCK_BOOTSTRAP_SCHEMA_VERSION",
    "RETURN_PANEL_SCHEMA_VERSION",
    "BlockBootstrapPath",
    "BlockBootstrapResult",
    "BootstrapSleevePath",
    "CalendarBasis",
    "DailyObservation",
    "EvidenceSeriesError",
    "ReferenceCapital",
    "ReturnPanel",
    "SleeveInput",
    "SleeveReturnSeries",
    "ValueKind",
    "annualized_sharpe",
    "build_return_panel",
    "calendar_axis",
    "moving_block_bootstrap",
]
