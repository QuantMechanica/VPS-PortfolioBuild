"""Reproducible, hierarchy-capped portfolio resize analysis for Darwinex Zero.

The module is analysis-only.  It never writes presets, deploy manifests, or terminal
state.  A resize can only run from a SHA-pinned frozen stream bundle; volatile MT5
``Common\\Files`` discovery is intentionally unavailable here.

Risk units are explicit throughout:

* ``source_risk_pct`` and every allocation/cap are account *percentage points*
  (``1.0`` means one percent), not decimal returns.
* stream dollars are converted to return per one source-risk percentage point before
  applying the requested allocation;
* the equity curve compounds those scaled daily realized returns.

The resulting drawdown and VaR are useful closed-trade diagnostics, not an official
DARWIN quote-curve reproduction.  See ``docs/ops/DXZ_PORTFOLIO_RESIZE_REMEDIATION.md``.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .commission import CommissionModel, describe_model, load_model
    from .portfolio_common import (
        FrozenStreamBundle,
        Trade,
        key_label,
        load_frozen_stream_bundle,
        to_daily_pnl,
    )
    from .portfolio_freeze_gate import (
        sha256_file as gate_sha256_file,
        validate_admission_resize_freeze_gate,
    )
except ImportError:  # pragma: no cover - direct script execution
    from commission import CommissionModel, describe_model, load_model  # type: ignore
    from portfolio_common import (  # type: ignore
        FrozenStreamBundle,
        Trade,
        key_label,
        load_frozen_stream_bundle,
        to_daily_pnl,
    )
    from portfolio_freeze_gate import (  # type: ignore
        sha256_file as gate_sha256_file,
        validate_admission_resize_freeze_gate,
    )


Key = tuple[int, str]
CAP_DIMENSIONS = ("sleeve", "ea", "symbol", "mechanism", "asset_class")
DEFAULT_DARWIN_VAR_TARGET_PCT = 6.5
DEFAULT_D_LEVERAGE_CAP = 9.75
DEFAULT_VAR_WINDOW_SESSIONS = 21


class AllocationError(ValueError):
    """The requested allocation is invalid or cannot satisfy every cap."""


@dataclass(frozen=True)
class SleeveMeta:
    sleeve_id: str
    ea_id: int
    symbol: str
    mechanism: str
    asset_class: str

    @property
    def key(self) -> Key:
        return self.ea_id, self.symbol

    def group(self, dimension: str) -> str:
        if dimension == "sleeve":
            return self.sleeve_id
        if dimension == "ea":
            return str(self.ea_id)
        if dimension == "symbol":
            return self.symbol
        if dimension == "mechanism":
            return self.mechanism
        if dimension == "asset_class":
            return self.asset_class
        raise KeyError(dimension)


@dataclass(frozen=True)
class _Constraint:
    dimension: str
    group: str
    indices: tuple[int, ...]
    cap: float


@dataclass(frozen=True)
class AllocationResult:
    weights: dict[str, float]
    base_target: dict[str, float]
    target_total_risk_pct: float
    allocated_total_risk_pct: float
    cap_usage: dict[str, dict[str, dict[str, float | bool]]]
    iterations: int
    max_constraint_violation: float


def capped_proportional_allocation(
    base_scores: Mapping[str, float],
    target_total: float,
    caps: float | Mapping[str, float],
    *,
    tolerance: float = 1e-12,
) -> dict[str, float]:
    """Proportionally redistribute capped excess without losing target weight.

    This is the canonical replacement for ``min(cap, target * normalized_score)``.
    If the requested total exceeds aggregate capacity, it raises ``AllocationError``
    instead of emitting a short allocation while still labelling it with the target.
    """

    target = _finite_nonnegative(target_total, "target_total")
    scores = _validated_scores(base_scores)
    if target == 0.0:
        return {label: 0.0 for label in scores}
    if not scores:
        raise AllocationError("a positive target requires at least one base score")
    if isinstance(caps, Mapping):
        cap_by_label = {
            label: _finite_nonnegative(caps.get(label), f"caps[{label!r}]")
            for label in scores
        }
        extra = sorted(set(caps) - set(scores))
        if extra:
            raise AllocationError(f"caps contain unknown sleeves: {extra!r}")
    else:
        cap = _finite_nonnegative(caps, "cap")
        cap_by_label = {label: cap for label in scores}
    capacity = sum(cap_by_label.values())
    if capacity + tolerance < target:
        raise AllocationError(
            f"target_total={target:g} exceeds sleeve capacity={capacity:g}"
        )

    result = {label: 0.0 for label in scores}
    active = set(scores)
    remaining = target
    while active and remaining > tolerance:
        active_score = sum(scores[label] for label in active)
        if active_score <= 0.0:
            raise AllocationError("positive target cannot be assigned to zero-score sleeves")
        proposed = {
            label: remaining * scores[label] / active_score for label in active
        }
        saturated = [
            label
            for label in active
            if proposed[label] > cap_by_label[label] - result[label] + tolerance
        ]
        if not saturated:
            for label, value in proposed.items():
                result[label] += value
            remaining = 0.0
            break
        for label in sorted(saturated):
            room = max(0.0, cap_by_label[label] - result[label])
            result[label] += room
            remaining -= room
            active.remove(label)

    if remaining > tolerance:
        raise AllocationError(f"unable to allocate residual target {remaining:g}")
    _assert_total_and_bounds(result, target, cap_by_label, tolerance=max(tolerance, 1e-10))
    return result


def allocate_hierarchical(
    base_scores: Mapping[str, float],
    sleeves: Sequence[SleeveMeta],
    target_total_risk_pct: float,
    caps: Mapping[str, Any],
    *,
    tolerance: float = 1e-10,
    max_iterations: int = 50_000,
) -> AllocationResult:
    """Project a target allocation onto overlapping hierarchical cap constraints.

    Caps may be a number (one default for every group) or an object containing
    ``default`` and ``overrides``.  The five supported dimensions are sleeve, EA,
    symbol, mechanism, and asset class.  Overlapping constraints require more than
    sequential clipping; Dykstra projection finds a minimum-distortion feasible point
    while retaining the exact target sum.  Infeasible requests fail closed.
    """

    target = _finite_nonnegative(target_total_risk_pct, "target_total_risk_pct")
    sleeve_list = list(sleeves)
    if len({s.sleeve_id for s in sleeve_list}) != len(sleeve_list):
        raise AllocationError("sleeve_id values must be unique")
    if len({s.key for s in sleeve_list}) != len(sleeve_list):
        raise AllocationError("(ea_id, symbol) keys must be unique in a resize book")
    labels = [s.sleeve_id for s in sleeve_list]
    scores = _validated_scores(base_scores)
    if set(scores) != set(labels):
        raise AllocationError(
            f"base score/sleeve mismatch: missing={sorted(set(labels)-set(scores))!r}, "
            f"extra={sorted(set(scores)-set(labels))!r}"
        )
    if target > 0.0 and not sleeve_list:
        raise AllocationError("a positive target requires sleeves")
    unknown_dimensions = sorted(set(caps) - set(CAP_DIMENSIONS))
    if unknown_dimensions:
        raise AllocationError(f"unknown cap dimensions: {unknown_dimensions!r}")

    constraints = _build_constraints(sleeve_list, caps)
    if target == 0.0:
        zero = {label: 0.0 for label in labels}
        return AllocationResult(
            weights=zero,
            base_target=zero.copy(),
            target_total_risk_pct=0.0,
            allocated_total_risk_pct=0.0,
            cap_usage=_cap_usage(zero, sleeve_list, constraints),
            iterations=0,
            max_constraint_violation=0.0,
        )
    _necessary_capacity_checks(target, sleeve_list, constraints, tolerance)

    score_total = sum(scores.values())
    base_target = {label: target * scores[label] / score_total for label in labels}
    q = [base_target[label] for label in labels]
    x = list(q)

    # Dykstra's algorithm: project onto the target simplex and every group-cap
    # halfspace, carrying one correction vector per convex set.  Unlike iterative
    # clipping it handles constraints that overlap across EA/symbol/mechanism/asset.
    projectors: list[tuple[str, tuple[int, ...], float | None]] = [
        ("simplex", tuple(range(len(labels))), target)
    ]
    projectors.extend(("cap", c.indices, c.cap) for c in constraints)
    corrections = [[0.0] * len(labels) for _ in projectors]
    iterations = 0
    converged = False
    for iterations in range(1, max_iterations + 1):
        cycle_start = list(x)
        for projector_index, (kind, indices, bound) in enumerate(projectors):
            residual = corrections[projector_index]
            y = [x[i] + residual[i] for i in range(len(x))]
            if kind == "simplex":
                z = _project_simplex(y, float(bound))
            else:
                z = _project_group_halfspace(y, indices, float(bound))
            corrections[projector_index] = [y[i] - z[i] for i in range(len(x))]
            x = z
        change = max((abs(x[i] - cycle_start[i]) for i in range(len(x))), default=0.0)
        violation = _allocation_violation(x, target, constraints)
        if change <= tolerance and violation <= tolerance:
            converged = True
            break
    if not converged:
        violation = _allocation_violation(x, target, constraints)
        raise AllocationError(
            "hierarchical cap system is infeasible or did not converge "
            f"after {max_iterations} iterations (max violation {violation:.3g})"
        )

    # The last cap projection can leave floating noise around zero/sum.  One final
    # simplex/cap convergence at strict tolerance has already bounded it; preserve raw
    # doubles (no decimal rounding that could reintroduce a cap breach or lose weight).
    weights = {label: (0.0 if abs(x[i]) <= tolerance else float(x[i])) for i, label in enumerate(labels)}
    violation = _allocation_violation(list(weights.values()), target, constraints)
    if violation > max(tolerance * 10.0, 1e-8):
        raise AllocationError(f"post-allocation constraint violation {violation:.3g}")
    allocated = sum(weights.values())
    if abs(allocated - target) > max(tolerance * 10.0, 1e-8):
        raise AllocationError(
            f"post-allocation total {allocated:.12g} does not equal target {target:.12g}"
        )
    return AllocationResult(
        weights=weights,
        base_target=base_target,
        target_total_risk_pct=target,
        allocated_total_risk_pct=allocated,
        cap_usage=_cap_usage(weights, sleeve_list, constraints),
        iterations=iterations,
        max_constraint_violation=violation,
    )


def normalized_daily_returns_per_risk_pct(
    bundle: FrozenStreamBundle,
) -> dict[Key, dict[dt.date, float]]:
    """Convert net-of-cost stream dollars to return per 1 account-risk %-point."""

    output: dict[Key, dict[dt.date, float]] = {}
    for key, trades in bundle.streams.items():
        info = bundle.info[key]
        denominator = info.source_starting_capital * info.source_risk_pct
        output[key] = {
            day: pnl / denominator for day, pnl in to_daily_pnl(trades).items()
        }
    return output


def inverse_vol_scores(
    normalized: Mapping[Key, Mapping[dt.date, float]],
    *,
    min_sessions: int = 63,
) -> tuple[dict[Key, float], dict[Key, dict[str, float | int]]]:
    """Inverse-volatility scores on each sleeve's own live-span weekday calendar."""

    if min_sessions < 2:
        raise ValueError("min_sessions must be at least 2")
    scores: dict[Key, float] = {}
    diagnostics: dict[Key, dict[str, float | int]] = {}
    for key, series in normalized.items():
        if not series:
            raise AllocationError(f"empty frozen stream for {key_label(key)}")
        dates = _session_calendar(min(series), max(series), observed=set(series))
        values = [float(series.get(day, 0.0)) for day in dates]
        if len(values) < min_sessions:
            raise AllocationError(
                f"{key_label(key)} has only {len(values)} sessions; min_vol_sessions={min_sessions}"
            )
        std = _population_stddev(values)
        if not math.isfinite(std) or std <= 0.0:
            raise AllocationError(f"{key_label(key)} has zero/invalid daily volatility")
        scores[key] = 1.0 / std
        diagnostics[key] = {
            "volatility_per_1pct_risk": std,
            "volatility_sessions": len(values),
            "active_close_days": len(series),
        }
    return scores, diagnostics


def closed_trade_portfolio_metrics(
    normalized: Mapping[Key, Mapping[dt.date, float]],
    allocations_pct: Mapping[Key, float],
    *,
    starting_capital: float,
    darwin_var_target_pct: float = DEFAULT_DARWIN_VAR_TARGET_PCT,
    d_leverage_cap: float = DEFAULT_D_LEVERAGE_CAP,
    var_window_sessions: int = DEFAULT_VAR_WINDOW_SESSIONS,
) -> dict[str, Any]:
    """Compounded realized-close equity and DXZ-oriented historical risk proxies."""

    capital = _positive(starting_capital, "starting_capital")
    target_var = _positive(darwin_var_target_pct, "darwin_var_target_pct")
    dlev_cap = _positive(d_leverage_cap, "d_leverage_cap")
    if var_window_sessions < 2:
        raise ValueError("var_window_sessions must be at least 2")
    if set(normalized) != set(allocations_pct):
        raise ValueError("normalized series and allocation keys must match exactly")
    observed = {day for series in normalized.values() for day in series}
    if not observed:
        raise ValueError("portfolio metrics require at least one close day")
    dates = _session_calendar(min(observed), max(observed), observed=observed)
    returns = [
        sum(
            float(normalized[key].get(day, 0.0)) * float(allocations_pct[key])
            for key in sorted(normalized)
        )
        for day in dates
    ]
    if any(value <= -1.0 for value in returns):
        worst = min(returns)
        raise AllocationError(
            f"scaled closed-trade session return reaches {worst:.2%}; account would be insolvent"
        )

    equity = [capital]
    for value in returns:
        equity.append(equity[-1] * (1.0 + value))
    final_equity = equity[-1]
    max_dd = _max_drawdown_pct(equity)
    years = max((dates[-1] - dates[0]).days / 365.25, 0.0)
    cagr = None
    if years > 0.0 and final_equity > 0.0:
        cagr = ((final_equity / capital) ** (1.0 / years) - 1.0) * 100.0
    sharpe = _annualized_sharpe(returns)
    rolling = _rolling_compounded_returns(returns, var_window_sessions)
    var95 = _historical_var_loss_pct(rolling, 0.95)
    es95 = _historical_expected_shortfall_loss_pct(rolling, 0.95)
    calendar_month_returns = _calendar_period_returns(dates, returns)
    calendar_var95 = _historical_var_loss_pct(list(calendar_month_returns.values()), 0.95)

    if var95 > 0.0:
        multiplier = target_var / var95
        limited = min(multiplier, dlev_cap)
        fill = min(100.0, var95 * dlev_cap / target_var * 100.0)
    else:
        multiplier = None
        limited = None
        fill = 0.0
    return {
        "equity_basis": "daily_compounded_realized_closes_only",
        "starting_capital": capital,
        "final_equity": final_equity,
        "net_profit": final_equity - capital,
        "total_return_pct": (final_equity / capital - 1.0) * 100.0,
        "cagr_pct": cagr,
        "annualized_sharpe_closed_trade": sharpe,
        "max_drawdown_realized_close_only_pct": max_dd,
        "worst_session_return_pct": min(returns) * 100.0,
        "n_sessions": len(dates),
        "n_active_close_days": len(observed),
        "n_calendar_months": len(calendar_month_returns),
        "first_session": dates[0].isoformat(),
        "last_session": dates[-1].isoformat(),
        "dxz_var_proxy": {
            "method": f"historical overlapping {var_window_sessions}-session compounded returns",
            "confidence": 0.95,
            "observations": len(rolling),
            "monthly_var_95_loss_pct": var95,
            "monthly_expected_shortfall_95_loss_pct": es95,
            "calendar_month_var_95_loss_pct": calendar_var95,
            "darwin_var_target_pct": target_var,
            "raw_multiplier_to_target": multiplier,
            "d_leverage_cap_assumption": dlev_cap,
            "d_leverage_limited_multiplier": limited,
            "target_fill_at_d_leverage_cap_pct": fill,
            "official_darwin_metric": False,
        },
    }


def mae_coverage_diagnostics(
    bundle: FrozenStreamBundle,
    allocations_pct: Mapping[Key, float],
) -> dict[str, Any]:
    """Report single-trade MAE coverage; never present it as portfolio drawdown."""

    total = sum(len(trades) for trades in bundle.streams.values())
    covered = 0
    scaled_mae_pct: list[float] = []
    entry_covered = 0
    for key, trades in bundle.streams.items():
        info = bundle.info[key]
        factor = float(allocations_pct[key]) / info.source_risk_pct
        for trade in trades:
            if trade.entry_time is not None:
                entry_covered += 1
            if trade.mae_acct is None:
                continue
            covered += 1
            scaled_mae_pct.append(
                float(trade.mae_acct) / info.source_starting_capital * factor * 100.0
            )
    return {
        "trades": total,
        "mae_trades": covered,
        "mae_coverage_pct": (covered / total * 100.0) if total else 0.0,
        "entry_time_coverage_pct": (entry_covered / total * 100.0) if total else 0.0,
        "worst_scaled_single_trade_mae_pct": min(scaled_mae_pct) if scaled_mae_pct else None,
        "portfolio_overlap_aggregation_available": False,
        "note": (
            "MAE has no timestamp and cannot reconstruct simultaneous floating PnL; "
            "the value above is a single-trade diagnostic only."
        ),
    }


def build_resize_report(
    config: Mapping[str, Any],
    bundle: FrozenStreamBundle,
    *,
    commission_model: CommissionModel | None = None,
    config_path: Path | None = None,
    config_sha256: str | None = None,
) -> dict[str, Any]:
    """Build a complete analysis-only resize report from already verified inputs."""

    if config.get("schema_version") != 1:
        raise ValueError("resize config schema_version must be 1")
    sleeves = _parse_sleeves(config.get("sleeves"))
    keys = [sleeve.key for sleeve in sleeves]
    if set(keys) != set(bundle.streams):
        raise ValueError(
            f"config/frozen-stream key mismatch: missing={sorted(set(keys)-set(bundle.streams))!r}, "
            f"extra={sorted(set(bundle.streams)-set(keys))!r}"
        )
    caps = config.get("caps")
    if not isinstance(caps, Mapping):
        raise AllocationError("caps object is required")
    missing_dimensions = [dimension for dimension in CAP_DIMENSIONS if dimension not in caps]
    if missing_dimensions:
        raise AllocationError(
            f"resize config must explicitly cap every hierarchy dimension; missing={missing_dimensions!r}"
        )

    normalized = normalized_daily_returns_per_risk_pct(bundle)
    min_sessions = int(config.get("min_vol_sessions", 63))
    scores_by_key, vol_diagnostics = inverse_vol_scores(normalized, min_sessions=min_sessions)
    scores = {s.sleeve_id: scores_by_key[s.key] for s in sleeves}
    allocation = allocate_hierarchical(
        scores,
        sleeves,
        float(config["target_total_risk_pct"]),
        caps,
    )
    allocations_by_key = {s.key: allocation.weights[s.sleeve_id] for s in sleeves}
    metrics = closed_trade_portfolio_metrics(
        normalized,
        allocations_by_key,
        starting_capital=float(config.get("starting_capital", 100_000.0)),
        darwin_var_target_pct=float(
            config.get("darwin_var_target_pct", DEFAULT_DARWIN_VAR_TARGET_PCT)
        ),
        d_leverage_cap=float(config.get("d_leverage_cap", DEFAULT_D_LEVERAGE_CAP)),
        var_window_sessions=int(config.get("var_window_sessions", DEFAULT_VAR_WINDOW_SESSIONS)),
    )
    model = commission_model
    commission_payload: dict[str, Any] | None = None
    if model is not None:
        commission_payload = describe_model(model)
        try:
            commission_payload["registry_sha256"] = _sha256_file(model.registry_path)
        except OSError:
            commission_payload["registry_sha256"] = None

    stream_rows = []
    for sleeve in sleeves:
        info = bundle.info[sleeve.key]
        diag = vol_diagnostics[sleeve.key]
        stream_rows.append(
            {
                "sleeve_id": sleeve.sleeve_id,
                "ea_id": sleeve.ea_id,
                "symbol": sleeve.symbol,
                "mechanism": sleeve.mechanism,
                "asset_class": sleeve.asset_class,
                "risk_percent": allocation.weights[sleeve.sleeve_id],
                "base_uncapped_risk_percent": allocation.base_target[sleeve.sleeve_id],
                "source_starting_capital": info.source_starting_capital,
                "source_risk_pct": info.source_risk_pct,
                "stream_sha256": info.sha256,
                "stream_path": str(info.path),
                "trade_count": info.trade_count,
                **diag,
            }
        )

    return {
        "schema_version": 1,
        "status": "ANALYSIS_ONLY_OWNER_REVIEW",
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "deployment_action": "NONE",
        "auto_apply": False,
        "weighting": "inverse_volatility_on_normalized_per_risk_returns",
        "risk_unit": "account_percent_points",
        "target_total_risk_pct": allocation.target_total_risk_pct,
        "allocated_total_risk_pct": allocation.allocated_total_risk_pct,
        "target_preserved": math.isclose(
            allocation.target_total_risk_pct,
            allocation.allocated_total_risk_pct,
            rel_tol=0.0,
            abs_tol=1e-8,
        ),
        "allocation_solver": {
            "method": "dykstra_projection_over_target_simplex_and_hierarchical_caps",
            "iterations": allocation.iterations,
            "max_constraint_violation": allocation.max_constraint_violation,
        },
        "cap_usage": allocation.cap_usage,
        "metrics": metrics,
        "mae_diagnostics": mae_coverage_diagnostics(bundle, allocations_by_key),
        "sleeves": stream_rows,
        "provenance": {
            "config_path": str(config_path.resolve()) if config_path is not None else None,
            "config_sha256": config_sha256,
            "stream_manifest_path": str(bundle.manifest_path),
            "stream_manifest_sha256": bundle.manifest_sha256,
            "frozen_root": str(bundle.frozen_root),
            "commission_model": commission_payload,
        },
        "limitations": {
            "mark_to_market_equity_available": False,
            "intraday_quote_curve_available": False,
            "open_position_overlap_floating_pnl_available": False,
            "official_darwin_risk_engine_reproduction": False,
            "closed_trade_timestamp": "exit_time_utc",
            "summary": (
                "Equity is reconstructed from net-of-cost realized closes and compounded "
                "at a constant risk-percent allocation. It omits floating PnL between entry "
                "and exit, gaps before a close, intraday portfolio overlap, margin/D-Leverage "
                "path, and Darwinex's quote-curve risk adjustment. Therefore realized-close "
                "drawdown and the 21-session VaR are screening proxies, not deploy limits or "
                "official DARWIN statistics."
            ),
        },
    }


def build_resize_report_from_files(
    config_path: Path,
    stream_manifest_path: Path,
    freeze_gate_path: Path,
) -> dict[str, Any]:
    config_file = Path(config_path).resolve(strict=True)
    config = json.loads(config_file.read_text(encoding="utf-8"))
    sleeves = _parse_sleeves(config.get("sleeves"))
    model = load_model()
    bundle = load_frozen_stream_bundle(
        Path(stream_manifest_path),
        expected_keys=[s.key for s in sleeves],
        commission_model=model,
    )
    config_sha = _sha256_file(config_file)
    commission_sha = gate_sha256_file(model.registry_path.resolve(strict=True))
    gate = validate_admission_resize_freeze_gate(
        Path(freeze_gate_path),
        purpose="resize",
        actual_inputs={
            "resize_config_sha256": config_sha,
            "stream_manifest_sha256": bundle.manifest_sha256,
            "commission_registry_sha256": commission_sha,
        },
        actual_stream_sha256={
            key_label(key): info.sha256 for key, info in bundle.info.items()
        },
    )
    report = build_resize_report(
        config,
        bundle,
        commission_model=model,
        config_path=config_file,
        config_sha256=config_sha,
    )
    report["freeze_gate"] = gate.as_dict()
    report["provenance"]["freeze_gate"] = gate.as_dict()
    return report


def _parse_sleeves(rows: Any) -> list[SleeveMeta]:
    if not isinstance(rows, list) or not rows:
        raise ValueError("sleeves must be a non-empty list")
    sleeves: list[SleeveMeta] = []
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping):
            raise ValueError(f"sleeves[{index}] must be an object")
        try:
            ea_id = int(row["ea_id"])
            symbol = str(row["symbol"]).strip()
            mechanism = str(row["mechanism"]).strip()
            asset_class = str(row["asset_class"]).strip()
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError(f"sleeves[{index}] is missing required metadata") from exc
        if not symbol or not mechanism or not asset_class:
            raise ValueError(f"sleeves[{index}] metadata may not be empty")
        sleeve_id = str(row.get("sleeve_id") or key_label((ea_id, symbol))).strip()
        if not sleeve_id:
            raise ValueError(f"sleeves[{index}].sleeve_id may not be empty")
        sleeves.append(SleeveMeta(sleeve_id, ea_id, symbol, mechanism, asset_class))
    if len({s.sleeve_id for s in sleeves}) != len(sleeves):
        raise ValueError("duplicate sleeve_id in config")
    if len({s.key for s in sleeves}) != len(sleeves):
        raise ValueError("duplicate (ea_id, symbol) in config")
    return sleeves


def _build_constraints(
    sleeves: Sequence[SleeveMeta], caps: Mapping[str, Any]
) -> list[_Constraint]:
    constraints: list[_Constraint] = []
    for dimension in CAP_DIMENSIONS:
        if dimension not in caps:
            continue
        groups: dict[str, list[int]] = {}
        for index, sleeve in enumerate(sleeves):
            label = sleeve.group(dimension)
            if not label:
                raise AllocationError(f"empty {dimension} metadata for {sleeve.sleeve_id}")
            groups.setdefault(label, []).append(index)
        default, overrides = _parse_cap_rule(caps[dimension], dimension)
        unknown_overrides = sorted(set(overrides) - set(groups))
        if unknown_overrides:
            raise AllocationError(
                f"{dimension} cap overrides reference absent groups: {unknown_overrides!r}"
            )
        for group, indices in sorted(groups.items()):
            cap = overrides.get(group, default)
            if cap is None:
                continue
            constraints.append(_Constraint(dimension, group, tuple(indices), cap))
    return constraints


def _parse_cap_rule(value: Any, dimension: str) -> tuple[float | None, dict[str, float]]:
    if isinstance(value, Mapping):
        unknown = sorted(set(value) - {"default", "overrides"})
        if unknown:
            raise AllocationError(f"{dimension} cap rule has unknown keys: {unknown!r}")
        default_raw = value.get("default")
        default = (
            None
            if default_raw is None
            else _finite_nonnegative(default_raw, f"caps.{dimension}.default")
        )
        override_raw = value.get("overrides", {})
        if not isinstance(override_raw, Mapping):
            raise AllocationError(f"caps.{dimension}.overrides must be an object")
        overrides = {
            str(group): _finite_nonnegative(cap, f"caps.{dimension}.overrides[{group!r}]")
            for group, cap in override_raw.items()
        }
        return default, overrides
    return _finite_nonnegative(value, f"caps.{dimension}"), {}


def _necessary_capacity_checks(
    target: float,
    sleeves: Sequence[SleeveMeta],
    constraints: Sequence[_Constraint],
    tolerance: float,
) -> None:
    by_dimension: dict[str, list[_Constraint]] = {}
    for constraint in constraints:
        by_dimension.setdefault(constraint.dimension, []).append(constraint)
    for dimension, rows in by_dimension.items():
        covered = {index for row in rows for index in row.indices}
        if len(covered) != len(sleeves):
            continue  # one or more groups are intentionally uncapped
        capacity = sum(row.cap for row in rows)
        if capacity + tolerance < target:
            raise AllocationError(
                f"target {target:g} exceeds aggregate {dimension} cap capacity {capacity:g}"
            )


def _cap_usage(
    weights: Mapping[str, float],
    sleeves: Sequence[SleeveMeta],
    constraints: Sequence[_Constraint],
) -> dict[str, dict[str, dict[str, float | bool]]]:
    labels = [s.sleeve_id for s in sleeves]
    usage: dict[str, dict[str, dict[str, float | bool]]] = {
        dimension: {} for dimension in CAP_DIMENSIONS
    }
    for constraint in constraints:
        allocated = sum(float(weights[labels[index]]) for index in constraint.indices)
        usage[constraint.dimension][constraint.group] = {
            "allocated_risk_pct": allocated,
            "cap_risk_pct": constraint.cap,
            "utilization_pct": (allocated / constraint.cap * 100.0)
            if constraint.cap > 0.0
            else (0.0 if allocated == 0.0 else float("inf")),
            "binding": math.isclose(allocated, constraint.cap, rel_tol=0.0, abs_tol=1e-8),
        }
    return usage


def _project_simplex(values: Sequence[float], total: float) -> list[float]:
    """Euclidean projection onto {x >= 0, sum(x) = total}."""

    if not values:
        if total == 0.0:
            return []
        raise AllocationError("cannot project a positive total onto an empty simplex")
    ordered = sorted((float(value) for value in values), reverse=True)
    cumulative = 0.0
    rho = 0
    for index, value in enumerate(ordered, start=1):
        cumulative += value
        theta = (cumulative - total) / index
        if value - theta > 0.0:
            rho = index
    if rho == 0:
        # total=0 is the only valid case; caller validates non-negative total.
        return [0.0] * len(values)
    theta = (sum(ordered[:rho]) - total) / rho
    projected = [max(float(value) - theta, 0.0) for value in values]
    # Correct one ulp-scale residual without arbitrary decimal rounding.
    residual = total - sum(projected)
    if residual:
        index = max(range(len(projected)), key=projected.__getitem__)
        projected[index] += residual
    return projected


def _project_group_halfspace(
    values: Sequence[float], indices: Sequence[int], cap: float
) -> list[float]:
    projected = [float(value) for value in values]
    group_sum = sum(projected[index] for index in indices)
    if group_sum <= cap:
        return projected
    correction = (group_sum - cap) / len(indices)
    for index in indices:
        projected[index] -= correction
    return projected


def _allocation_violation(
    values: Sequence[float], target: float, constraints: Sequence[_Constraint]
) -> float:
    violation = abs(sum(values) - target)
    violation = max(violation, max((-value for value in values), default=0.0))
    for constraint in constraints:
        group_sum = sum(values[index] for index in constraint.indices)
        violation = max(violation, group_sum - constraint.cap)
    return max(0.0, violation)


def _validated_scores(base_scores: Mapping[str, float]) -> dict[str, float]:
    scores: dict[str, float] = {}
    for raw_label, raw_score in base_scores.items():
        label = str(raw_label)
        if not label:
            raise AllocationError("base score labels may not be empty")
        try:
            score = float(raw_score)
        except (TypeError, ValueError) as exc:
            raise AllocationError(f"invalid base score for {label!r}") from exc
        if not math.isfinite(score) or score <= 0.0:
            raise AllocationError(f"base score for {label!r} must be finite and > 0")
        scores[label] = score
    return scores


def _assert_total_and_bounds(
    allocation: Mapping[str, float],
    target: float,
    caps: Mapping[str, float],
    tolerance: float,
) -> None:
    total = sum(allocation.values())
    if abs(total - target) > tolerance:
        raise AllocationError(f"allocation total {total:g} != target {target:g}")
    breaches = {
        label: value - caps[label]
        for label, value in allocation.items()
        if value > caps[label] + tolerance
    }
    if breaches:
        raise AllocationError(f"allocation cap breaches: {breaches!r}")


def _session_calendar(
    first: dt.date, last: dt.date, *, observed: set[dt.date]
) -> list[dt.date]:
    days: list[dt.date] = []
    current = first
    while current <= last:
        if current.weekday() < 5 or current in observed:
            days.append(current)
        current += dt.timedelta(days=1)
    return days


def _population_stddev(values: Sequence[float]) -> float:
    if not values:
        return 0.0
    mean = sum(values) / len(values)
    return math.sqrt(sum((value - mean) ** 2 for value in values) / len(values))


def _annualized_sharpe(values: Sequence[float]) -> float | None:
    if len(values) < 2:
        return None
    std = _population_stddev(values)
    if std <= 0.0:
        return None
    return sum(values) / len(values) / std * math.sqrt(252.0)


def _max_drawdown_pct(equity: Sequence[float]) -> float:
    peak = 0.0
    max_drawdown = 0.0
    for value in equity:
        peak = max(peak, float(value))
        if peak > 0.0:
            max_drawdown = max(max_drawdown, (peak - float(value)) / peak * 100.0)
    return max_drawdown


def _rolling_compounded_returns(values: Sequence[float], window: int) -> list[float]:
    if len(values) < window:
        return []
    output: list[float] = []
    for end in range(window, len(values) + 1):
        compounded = 1.0
        for value in values[end - window : end]:
            compounded *= 1.0 + float(value)
        output.append(compounded - 1.0)
    return output


def _calendar_period_returns(
    dates: Sequence[dt.date], values: Sequence[float]
) -> dict[str, float]:
    compounded: dict[str, float] = {}
    for day, value in zip(dates, values):
        label = f"{day.year:04d}-{day.month:02d}"
        compounded[label] = compounded.get(label, 1.0) * (1.0 + float(value))
    return {label: value - 1.0 for label, value in sorted(compounded.items())}


def _historical_var_loss_pct(values: Sequence[float], confidence: float) -> float:
    if not values:
        return 0.0
    quantile = _quantile(values, 1.0 - confidence)
    return max(0.0, -quantile * 100.0)


def _historical_expected_shortfall_loss_pct(
    values: Sequence[float], confidence: float
) -> float:
    if not values:
        return 0.0
    threshold = _quantile(values, 1.0 - confidence)
    tail = [float(value) for value in values if float(value) <= threshold]
    return max(0.0, -(sum(tail) / len(tail)) * 100.0) if tail else 0.0


def _quantile(values: Sequence[float], probability: float) -> float:
    if not values:
        raise ValueError("quantile requires observations")
    if not 0.0 <= probability <= 1.0:
        raise ValueError("probability must be in [0, 1]")
    ordered = sorted(float(value) for value in values)
    position = probability * (len(ordered) - 1)
    lower = int(math.floor(position))
    upper = int(math.ceil(position))
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * fraction


def _finite_nonnegative(value: Any, label: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise AllocationError(f"{label} must be a finite non-negative number") from exc
    if not math.isfinite(number) or number < 0.0:
        raise AllocationError(f"{label} must be a finite non-negative number")
    return number


def _positive(value: Any, label: str) -> float:
    number = _finite_nonnegative(value, label)
    if number <= 0.0:
        raise ValueError(f"{label} must be > 0")
    return number


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True, help="resize config JSON")
    parser.add_argument(
        "--stream-manifest", type=Path, required=True, help="SHA-pinned frozen stream manifest"
    )
    parser.add_argument(
        "--freeze-gate",
        type=Path,
        required=True,
        help="PASS truth-chain gate bound to every input SHA",
    )
    parser.add_argument("--out", type=Path, required=True, help="analysis JSON output")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    # All validation, including truth-chain PASS and every content SHA, occurs before
    # the output directory or file is touched.  A failed gate therefore cannot create
    # a misleading new book artifact.
    report = build_resize_report_from_files(
        args.config, args.stream_manifest, args.freeze_gate
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"analysis only: allocated {report['allocated_total_risk_pct']:.6f}% "
        f"across {len(report['sleeves'])} sleeves; wrote {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
