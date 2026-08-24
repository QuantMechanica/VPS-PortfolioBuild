#!/usr/bin/env python3
"""Q15 research laboratory for a SHA-bound synchronized daily-PnL package.

The lab compares frozen equal-weight and train-only inverse-volatility research
counterfactuals, correlation/tail structure, leave-one-out contributions, and a
joint moving-block bootstrap.  It never emits a book manifest, authoritative
weights, a Q15 verdict, or any deploy/live action.
"""
from __future__ import annotations

import argparse
import csv
import dataclasses
import datetime as dt
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any, Mapping

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from tools.strategy_farm.portfolio import concentration_tail  # noqa: E402


SCHEMA = "qm.q15-shadow-booklab/v1"
PACKAGE_SCHEMA = "qm_invvol_stage1_verification/v1"
DEFAULT_PACKAGE = Path(r"D:\QM\reports\portfolio\invvol_stage1_20260804")
MIN_DAYS = 60
MIN_SLEEVES = 2
_EA_RE = re.compile(r"QM5_(\d+)")


class ShadowBookLabError(ValueError):
    """The research package or frozen experiment is incomplete."""


@dataclasses.dataclass(frozen=True)
class Package:
    root: str
    package_sha256: str
    verification_sha256: str
    lineage_sha256: str
    dates: tuple[str, ...]
    sleeve_ids: tuple[str, ...]
    matrix: np.ndarray
    metadata: tuple[dict[str, Any], ...]
    exclusions: tuple[dict[str, Any], ...]
    bindings: tuple[dict[str, Any], ...]


@dataclasses.dataclass(frozen=True)
class LabConfig:
    annualization: int = 252
    train_fraction: float = 0.70
    downside_quantile: float = 0.20
    stress_quantile: float = 0.05
    bootstrap_runs: int = 1999
    bootstrap_block_days: int = 20
    bootstrap_seed: int = 20260824
    bootstrap_batch_size: int = 64


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _binding(path: Path, expected_sha256: str | None = None) -> dict[str, Any]:
    resolved = Path(path).resolve()
    if not resolved.is_file():
        raise ShadowBookLabError(f"bound file missing: {resolved}")
    observed = _sha256(resolved)
    if expected_sha256 and observed != str(expected_sha256).lower():
        raise ShadowBookLabError(
            f"SHA-256 mismatch for {resolved}: expected {expected_sha256}, observed {observed}"
        )
    return {
        "path": str(resolved),
        "sha256": observed,
        "size_bytes": resolved.stat().st_size,
    }


def _parse_daily(path: Path) -> tuple[tuple[str, ...], np.ndarray]:
    dates: list[str] = []
    values: list[float] = []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or len(reader.fieldnames) != 2 or "date" not in reader.fieldnames:
            raise ShadowBookLabError(f"daily CSV schema invalid: {path}")
        value_column = next(column for column in reader.fieldnames if column != "date")
        for line, row in enumerate(reader, start=2):
            date = str(row.get("date") or "").strip()
            try:
                dt.date.fromisoformat(date)
                value = float(row.get(value_column) or "")
            except (TypeError, ValueError) as exc:
                raise ShadowBookLabError(
                    f"invalid daily row {path}:{line}"
                ) from exc
            if not math.isfinite(value):
                raise ShadowBookLabError(f"non-finite daily value {path}:{line}")
            if dates and date <= dates[-1]:
                raise ShadowBookLabError(f"daily dates are not strictly increasing: {path}")
            dates.append(date)
            values.append(value)
    return tuple(dates), np.asarray(values, dtype=np.float64)


def load_package(root: str | Path = DEFAULT_PACKAGE) -> Package:
    """Load the published data substrate and verify every consumed byte."""
    package_root = Path(root).resolve()
    verification_path = package_root / "verification.json"
    verification_binding = _binding(verification_path)
    verification = json.loads(verification_path.read_text(encoding="utf-8-sig"))
    if verification.get("schema") != PACKAGE_SCHEMA:
        raise ShadowBookLabError(
            f"verification must declare {PACKAGE_SCHEMA}"
        )
    output_hashes = verification.get("output_sha256")
    if not isinstance(output_hashes, dict):
        raise ShadowBookLabError("verification output_sha256 map missing")

    lineage_path = package_root / "lineage.csv"
    lineage_binding = _binding(lineage_path, output_hashes.get("lineage.csv"))
    summary_binding = _binding(
        package_root / "summary.csv", output_hashes.get("summary.csv")
    )
    with lineage_path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ShadowBookLabError("lineage.csv has no sleeves")

    seen: set[str] = set()
    included_metadata: list[dict[str, Any]] = []
    exclusions: list[dict[str, Any]] = []
    daily_bindings: list[dict[str, Any]] = []
    dates: tuple[str, ...] | None = None
    series: list[np.ndarray] = []
    for row in rows:
        sleeve = str(row.get("sleeve") or "").strip()
        if not sleeve or sleeve in seen:
            raise ShadowBookLabError(f"blank or duplicate sleeve in lineage: {sleeve!r}")
        seen.add(sleeve)
        relative = f"daily/{sleeve}_daily_returns.csv"
        daily_path = package_root / relative
        expected = output_hashes.get(relative)
        if not expected:
            raise ShadowBookLabError(f"verification has no daily hash for {sleeve}")
        daily_binding = _binding(daily_path, str(expected))
        row_expected = str(row.get("daily_csv_sha256") or "").lower()
        if row_expected and row_expected != daily_binding["sha256"]:
            raise ShadowBookLabError(f"lineage daily hash mismatch for {sleeve}")
        declared_path = str(row.get("daily_csv") or "").strip()
        if declared_path and Path(declared_path).resolve() != daily_path.resolve():
            raise ShadowBookLabError(f"lineage daily path mismatch for {sleeve}")
        daily_bindings.append({"sleeve": sleeve, **daily_binding})

        metadata = {
            "sleeve": sleeve,
            "ea_id": str(row.get("ea_id") or "").strip(),
            "symbol": str(row.get("host_symbol") or "").strip().upper(),
            "timeframe": str(row.get("timeframe") or "").strip().upper(),
            "magic": str(row.get("magic") or "").strip(),
            "source_phase": str(row.get("source_phase") or "").strip(),
            "work_item_id": str(row.get("work_item_id") or "").strip(),
            "work_item_verdict": str(row.get("work_item_verdict") or "").strip(),
            "lineage_status": str(row.get("status") or "").strip().upper(),
        }
        if metadata["lineage_status"] != "EXTRACTED":
            exclusions.append({
                **metadata,
                "reason": str(row.get("reason") or "").strip(),
                "daily_binding": daily_binding,
            })
            continue
        sleeve_dates, values = _parse_daily(daily_path)
        if dates is None:
            dates = sleeve_dates
        elif sleeve_dates != dates:
            raise ShadowBookLabError(f"daily grid differs for {sleeve}")
        included_metadata.append(metadata)
        series.append(values)

    if dates is None or len(dates) < MIN_DAYS:
        raise ShadowBookLabError("package has insufficient synchronized daily history")
    if len(series) < MIN_SLEEVES:
        raise ShadowBookLabError("package has insufficient extracted sleeves")
    matrix = np.column_stack(series)
    if not np.isfinite(matrix).all():
        raise ShadowBookLabError("package matrix contains non-finite values")
    declared = int((verification.get("checks") or {}).get("manifest_declared_and_actual_sleeves") or 0)
    extracted = int((verification.get("checks") or {}).get("extracted_sleeves") or 0)
    if declared != len(rows) or extracted != len(series):
        raise ShadowBookLabError(
            "verification sleeve counts differ from lineage/daily evidence"
        )

    package_identity = {
        "verification": verification_binding["sha256"],
        "lineage": lineage_binding["sha256"],
        "summary": summary_binding["sha256"],
        "daily": {row["sleeve"]: row["sha256"] for row in daily_bindings},
    }
    package_sha = hashlib.sha256(
        (json.dumps(package_identity, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    ).hexdigest()
    return Package(
        root=str(package_root),
        package_sha256=package_sha,
        verification_sha256=verification_binding["sha256"],
        lineage_sha256=lineage_binding["sha256"],
        dates=dates,
        sleeve_ids=tuple(row["sleeve"] for row in included_metadata),
        matrix=matrix,
        metadata=tuple(included_metadata),
        exclusions=tuple(exclusions),
        bindings=tuple([
            {"role": "verification", **verification_binding},
            {"role": "lineage", **lineage_binding},
            {"role": "summary", **summary_binding},
            *({"role": "daily", **row} for row in daily_bindings),
        ]),
    )


def _validate_config(config: LabConfig, days: int) -> int:
    if config.annualization <= 0:
        raise ShadowBookLabError("annualization must be positive")
    if not 0.5 <= config.train_fraction < 1.0:
        raise ShadowBookLabError("train_fraction must be in [0.5,1.0)")
    split = int(math.floor(days * config.train_fraction))
    if split < MIN_DAYS or days - split < MIN_DAYS:
        raise ShadowBookLabError("train or holdout segment has fewer than 60 days")
    if not 0 < config.stress_quantile < config.downside_quantile < 0.5:
        raise ShadowBookLabError("stress/downside quantiles are invalid")
    if config.bootstrap_runs < 99:
        raise ShadowBookLabError("bootstrap_runs must be >=99")
    if not 1 <= config.bootstrap_block_days <= days - split:
        raise ShadowBookLabError("bootstrap block length is invalid for holdout")
    if config.bootstrap_batch_size <= 0:
        raise ShadowBookLabError("bootstrap_batch_size must be positive")
    return split


def _max_drawdown(values: np.ndarray) -> float:
    curve = np.cumsum(values, dtype=np.float64)
    peak = np.maximum.accumulate(np.concatenate((np.asarray([0.0]), curve)))[1:]
    return float(np.max(peak - curve)) if len(curve) else 0.0


def _series_metrics(values: np.ndarray, annualization: int) -> dict[str, Any]:
    data = np.asarray(values, dtype=np.float64)
    mean = float(np.mean(data))
    std = float(np.std(data, ddof=1)) if len(data) > 1 else 0.0
    sharpe = mean / std * math.sqrt(annualization) if std > 0 else None
    q05 = float(np.quantile(data, 0.05, method="linear"))
    tail = data[data <= q05]
    active = data[data != 0.0]
    return {
        "days": len(data),
        "active_days": int(np.count_nonzero(data)),
        "total_pnl_risk_units": round(float(np.sum(data)), 8),
        "annualized_mean_pnl": round(mean * annualization, 8),
        "annualized_vol_pnl": round(std * math.sqrt(annualization), 8),
        "annualized_sharpe": None if sharpe is None else round(sharpe, 8),
        "max_drawdown_pnl": round(_max_drawdown(data), 8),
        "worst_day_pnl": round(float(np.min(data)), 8),
        "var_95_loss_pnl": round(max(0.0, -q05), 8),
        "cvar_95_loss_pnl": round(max(0.0, -float(np.mean(tail))), 8),
        "active_day_hit_rate": (
            None if len(active) == 0 else round(float(np.mean(active > 0)), 8)
        ),
    }


def _inverse_vol_weights(train: np.ndarray) -> np.ndarray:
    volatility = np.std(train, axis=0, ddof=1)
    if np.any(~np.isfinite(volatility)) or np.any(volatility <= 0):
        raise ShadowBookLabError("inverse-volatility weights require positive train volatility")
    inverse = 1.0 / volatility
    return inverse / np.sum(inverse)


def _weighted(matrix: np.ndarray, weights: np.ndarray) -> np.ndarray:
    return np.asarray(matrix @ weights, dtype=np.float64)


def _weight_concentration(
    sleeve_ids: tuple[str, ...], weights: np.ndarray
) -> dict[str, Any]:
    hhi = float(np.sum(weights * weights))
    ranked = sorted(
        ({"sleeve": sleeve, "weight": round(float(weight), 10)}
         for sleeve, weight in zip(sleeve_ids, weights)),
        key=lambda row: (-row["weight"], row["sleeve"]),
    )
    return {
        "hhi": round(hhi, 10),
        "effective_sleeves": round(1.0 / hhi, 8),
        "largest_weight": ranked[0],
        "top_5_weight_share": round(sum(row["weight"] for row in ranked[:5]), 10),
        "weights": ranked,
    }


def _correlation(matrix: np.ndarray) -> np.ndarray:
    if matrix.shape[0] < 2:
        return np.full((matrix.shape[1], matrix.shape[1]), np.nan)
    with np.errstate(invalid="ignore", divide="ignore"):
        return np.corrcoef(matrix, rowvar=False)


def _correlation_diagnostics(
    package: Package,
    equal_portfolio: np.ndarray,
    config: LabConfig,
) -> dict[str, Any]:
    downside_cut = float(np.quantile(equal_portfolio, config.downside_quantile))
    stress_cut = float(np.quantile(equal_portfolio, config.stress_quantile))
    masks = {
        "all_days": np.ones(len(equal_portfolio), dtype=bool),
        "downside_days": equal_portfolio <= downside_cut,
        "stress_days": equal_portfolio <= stress_cut,
    }
    matrices = {name: _correlation(package.matrix[mask]) for name, mask in masks.items()}
    pair_rows = []
    for left in range(len(package.sleeve_ids)):
        for right in range(left + 1, len(package.sleeve_ids)):
            pair_rows.append({
                "left": package.sleeve_ids[left],
                "right": package.sleeve_ids[right],
                "correlation": {
                    name: (
                        None if not math.isfinite(float(matrix[left, right]))
                        else round(float(matrix[left, right]), 8)
                    )
                    for name, matrix in matrices.items()
                },
                "joint_active_days": int(np.sum(
                    (package.matrix[:, left] != 0.0) & (package.matrix[:, right] != 0.0)
                )),
            })
    worst_stress = sorted(
        pair_rows,
        key=lambda row: (
            -float(row["correlation"]["stress_days"])
            if row["correlation"]["stress_days"] is not None else math.inf,
            row["left"], row["right"],
        ),
    )[:15]
    per_sleeve = []
    for index, sleeve in enumerate(package.sleeve_ids):
        per_sleeve.append({
            "sleeve": sleeve,
            **{
                f"max_{name}_correlation": (
                    None if not values else round(max(values), 8)
                )
                for name, matrix in matrices.items()
                for values in [[
                    float(matrix[index, other])
                    for other in range(len(package.sleeve_ids))
                    if other != index and math.isfinite(float(matrix[index, other]))
                ]]
            },
        })
    return {
        "regime_definition": {
            "downside_quantile": config.downside_quantile,
            "stress_quantile": config.stress_quantile,
            "downside_cutoff_pnl": round(downside_cut, 8),
            "stress_cutoff_pnl": round(stress_cut, 8),
            "downside_days": int(np.sum(masks["downside_days"])),
            "stress_days": int(np.sum(masks["stress_days"])),
            "regime_source": "equal_weight_full_roster_daily_pnl",
        },
        "matrices": {
            name: [
                [None if not math.isfinite(float(value)) else round(float(value), 8) for value in row]
                for row in matrix
            ]
            for name, matrix in matrices.items()
        },
        "worst_15_stress_pairs": worst_stress,
        "per_sleeve": per_sleeve,
    }


def _classifications(package: Package) -> dict[str, Any]:
    assets, asset_binding = concentration_tail.load_asset_classes()
    rows: list[dict[str, Any]] = []
    fallback_count = 0
    for metadata in package.metadata:
        match = _EA_RE.fullmatch(metadata["ea_id"])
        if match is None:
            raise ShadowBookLabError(f"invalid EA id in package: {metadata['ea_id']!r}")
        key = (int(match.group(1)), metadata["symbol"])
        try:
            family = concentration_tail.family_fingerprints(
                concentration_tail.REPO_ROOT, [key]
            )[key]
            family_source = "canonical_registry_or_ea_slug"
        except Exception as exc:
            family = f"ea_{key[0]}"
            family_source = f"fallback_unique_ea:{type(exc).__name__}"
            fallback_count += 1
        rows.append({
            **metadata,
            "ea_id_int": key[0],
            "asset_class": assets.get(metadata["symbol"], "unknown"),
            "family": family,
            "family_source": family_source,
        })
    return {
        "rows": rows,
        "family_fallback_count": fallback_count,
        "asset_matrix_binding": asset_binding,
    }


def _group_exposure(
    classifications: list[dict[str, Any]],
    weights: np.ndarray,
) -> dict[str, list[dict[str, Any]]]:
    output: dict[str, list[dict[str, Any]]] = {}
    for dimension in ("symbol", "asset_class", "family", "timeframe"):
        groups: dict[str, float] = {}
        for row, weight in zip(classifications, weights):
            key = str(row.get(dimension) or "unknown")
            groups[key] = groups.get(key, 0.0) + float(weight)
        output[dimension] = [
            {"key": key, "weight_share": round(value, 10)}
            for key, value in sorted(groups.items(), key=lambda item: (-item[1], item[0]))
        ]
    return output


def _leave_one_out(
    package: Package,
    weights: np.ndarray,
    annualization: int,
) -> list[dict[str, Any]]:
    baseline = _series_metrics(_weighted(package.matrix, weights), annualization)
    rows = []
    for index, sleeve in enumerate(package.sleeve_ids):
        reduced = np.delete(weights, index)
        reduced /= np.sum(reduced)
        metrics = _series_metrics(
            np.delete(package.matrix, index, axis=1) @ reduced,
            annualization,
        )
        base_sharpe = baseline["annualized_sharpe"]
        reduced_sharpe = metrics["annualized_sharpe"]
        rows.append({
            "sleeve": sleeve,
            "weight": round(float(weights[index]), 10),
            "sharpe_change_if_removed": (
                None if base_sharpe is None or reduced_sharpe is None
                else round(reduced_sharpe - base_sharpe, 8)
            ),
            "max_drawdown_change_if_removed": round(
                metrics["max_drawdown_pnl"] - baseline["max_drawdown_pnl"], 8
            ),
            "total_pnl_change_if_removed": round(
                metrics["total_pnl_risk_units"] - baseline["total_pnl_risk_units"], 8
            ),
            "research_flag": (
                "REMOVAL_IMPROVES_SHARPE"
                if (
                    base_sharpe is not None and reduced_sharpe is not None
                    and reduced_sharpe > base_sharpe
                ) else "CONTRIBUTES_OR_NEUTRAL"
            ),
        })
    return sorted(
        rows,
        key=lambda row: (
            -(
                row["sharpe_change_if_removed"]
                if row["sharpe_change_if_removed"] is not None else -math.inf
            ),
            row["sleeve"],
        ),
    )


def _distribution(values: np.ndarray) -> dict[str, float]:
    return {
        "p05": round(float(np.quantile(values, 0.05)), 8),
        "p50": round(float(np.quantile(values, 0.50)), 8),
        "p95": round(float(np.quantile(values, 0.95)), 8),
        "mean": round(float(np.mean(values)), 8),
    }


def _joint_bootstrap(
    holdout: np.ndarray,
    weights: np.ndarray,
    config: LabConfig,
) -> dict[str, Any]:
    days = holdout.shape[0]
    blocks = math.ceil(days / config.bootstrap_block_days)
    offsets = np.arange(config.bootstrap_block_days, dtype=np.int64)
    rng = np.random.default_rng(config.bootstrap_seed)
    sharpes = np.empty(config.bootstrap_runs)
    totals = np.empty(config.bootstrap_runs)
    drawdowns = np.empty(config.bootstrap_runs)
    tail_losses = np.empty(config.bootstrap_runs)
    written = 0
    while written < config.bootstrap_runs:
        batch = min(config.bootstrap_batch_size, config.bootstrap_runs - written)
        starts = rng.integers(0, days, size=(batch, blocks), endpoint=False)
        indices = (starts[:, :, None] + offsets[None, None, :]) % days
        indices = indices.reshape(batch, -1)[:, :days]
        pnl = holdout[indices, :] @ weights
        means = np.mean(pnl, axis=1)
        std = np.std(pnl, axis=1, ddof=1)
        sharpes[written:written + batch] = means / std * math.sqrt(config.annualization)
        totals[written:written + batch] = np.sum(pnl, axis=1)
        curve = np.cumsum(pnl, axis=1)
        peaks = np.maximum.accumulate(
            np.concatenate((np.zeros((batch, 1)), curve), axis=1), axis=1
        )[:, 1:]
        drawdowns[written:written + batch] = np.max(peaks - curve, axis=1)
        q05 = np.quantile(pnl, 0.05, axis=1, method="linear")
        for row in range(batch):
            tail_losses[written + row] = max(
                0.0, -float(np.mean(pnl[row, pnl[row] <= q05[row]]))
            )
        written += batch
    return {
        "estimator": "joint_circular_moving_block_bootstrap_of_holdout_daily_vector",
        "runs": config.bootstrap_runs,
        "block_days": config.bootstrap_block_days,
        "seed": config.bootstrap_seed,
        "sleeves_bootstrapped_independently": False,
        "annualized_sharpe": _distribution(sharpes),
        "total_pnl_risk_units": _distribution(totals),
        "max_drawdown_pnl": _distribution(drawdowns),
        "cvar_95_loss_pnl": _distribution(tail_losses),
        "probability_total_pnl_positive": round(float(np.mean(totals > 0)), 8),
        "probability_sharpe_positive": round(float(np.mean(sharpes > 0)), 8),
    }


def _yearly_metrics(
    dates: tuple[str, ...], values: np.ndarray, annualization: int
) -> list[dict[str, Any]]:
    years = sorted({date[:4] for date in dates})
    rows = []
    date_array = np.asarray(dates)
    for year in years:
        mask = np.char.startswith(date_array, year)
        rows.append({"year": year, **_series_metrics(values[mask], annualization)})
    return rows


def analyze_package(
    package: Package,
    config: LabConfig = LabConfig(),
) -> dict[str, Any]:
    split = _validate_config(config, len(package.dates))
    train = package.matrix[:split]
    holdout = package.matrix[split:]
    equal = np.full(len(package.sleeve_ids), 1.0 / len(package.sleeve_ids))
    inverse_vol = _inverse_vol_weights(train)
    classifications = _classifications(package)
    equal_full = _weighted(package.matrix, equal)
    inverse_full = _weighted(package.matrix, inverse_vol)
    inverse_holdout = _weighted(holdout, inverse_vol)

    sleeve_metrics = []
    for index, metadata in enumerate(classifications["rows"]):
        sleeve_metrics.append({
            **metadata,
            "full": _series_metrics(package.matrix[:, index], config.annualization),
            "train": _series_metrics(train[:, index], config.annualization),
            "holdout": _series_metrics(holdout[:, index], config.annualization),
        })
    sleeve_metrics.sort(
        key=lambda row: (
            -(
                row["holdout"]["annualized_sharpe"]
                if row["holdout"]["annualized_sharpe"] is not None else -math.inf
            ),
            row["sleeve"],
        )
    )

    return {
        "schema": SCHEMA,
        "mode": "Q15_SHADOW_RESEARCH_ONLY",
        "status": "DATA_READY_WITH_GAPS" if package.exclusions else "DATA_READY",
        "gate_eligible": False,
        "book_manifest_emitted": False,
        "production_book_decision": "REFUSED_BY_SHADOW_MODE",
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
        "source": {
            "root": package.root,
            "package_sha256": package.package_sha256,
            "verification_sha256": package.verification_sha256,
            "lineage_sha256": package.lineage_sha256,
            "declared_sleeves": len(package.sleeve_ids) + len(package.exclusions),
            "analyzed_sleeves": len(package.sleeve_ids),
            "excluded_sleeves": len(package.exclusions),
            "exclusions": list(package.exclusions),
            "days": len(package.dates),
            "start": package.dates[0],
            "end": package.dates[-1],
            "unit": "daily_pnl_eur_risk_units_at_RISK_FIXED_1000",
            "bindings": list(package.bindings),
        },
        "experiment": {
            **dataclasses.asdict(config),
            "split_index": split,
            "train_start": package.dates[0],
            "train_end": package.dates[split - 1],
            "holdout_start": package.dates[split],
            "holdout_end": package.dates[-1],
            "weight_rules": [
                "equal_weight_frozen",
                "inverse_sample_volatility_estimated_on_train_only_no_caps",
            ],
        },
        "research_counterfactuals": {
            "equal_weight": {
                "concentration": _weight_concentration(package.sleeve_ids, equal),
                "full": _series_metrics(equal_full, config.annualization),
                "train": _series_metrics(equal_full[:split], config.annualization),
                "holdout": _series_metrics(equal_full[split:], config.annualization),
            },
            "train_inverse_volatility": {
                "concentration": _weight_concentration(package.sleeve_ids, inverse_vol),
                "group_exposure": _group_exposure(classifications["rows"], inverse_vol),
                "full": _series_metrics(inverse_full, config.annualization),
                "train": _series_metrics(inverse_full[:split], config.annualization),
                "holdout": _series_metrics(inverse_holdout, config.annualization),
                "yearly": _yearly_metrics(package.dates, inverse_full, config.annualization),
            },
        },
        "classification": classifications,
        "sleeves": sleeve_metrics,
        "correlation": _correlation_diagnostics(package, equal_full, config),
        "leave_one_out": _leave_one_out(package, inverse_vol, config.annualization),
        "holdout_joint_bootstrap": _joint_bootstrap(holdout, inverse_vol, config),
        "interpretation": {
            "weights": "Research counterfactuals only; not proposed or deployable stop-risk weights.",
            "leave_one_out": "Positive sharpe_change_if_removed is a review flag, not an exclusion instruction.",
            "missing_sleeve": "The non-extractable sleeve remains explicit and prevents a complete 24-sleeve claim.",
            "q15": "No >=25 terminally requalified candidate pool or OWNER order is asserted by this lab.",
        },
    }


def render_markdown(report: Mapping[str, Any]) -> str:
    source = report["source"]
    inv = report["research_counterfactuals"]["train_inverse_volatility"]
    equal = report["research_counterfactuals"]["equal_weight"]
    bootstrap = report["holdout_joint_bootstrap"]
    lines = [
        "# Q15 Shadow BookLab",
        "",
        f"Status: **{report['status']} / SHADOW ONLY**",
        "",
        f"Evidence: {source['analyzed_sleeves']}/{source['declared_sleeves']} sleeves, "
        f"{source['days']} synchronized days ({source['start']} to {source['end']}).",
        "",
        "| Counterfactual | Holdout Sharpe | Holdout max DD (risk PnL) | Holdout total PnL |",
        "|---|---:|---:|---:|",
        f"| Equal weight | {equal['holdout']['annualized_sharpe']} | "
        f"{equal['holdout']['max_drawdown_pnl']} | {equal['holdout']['total_pnl_risk_units']} |",
        f"| Train inverse vol | {inv['holdout']['annualized_sharpe']} | "
        f"{inv['holdout']['max_drawdown_pnl']} | {inv['holdout']['total_pnl_risk_units']} |",
        "",
        f"Joint holdout bootstrap: P(total PnL > 0) = "
        f"{bootstrap['probability_total_pnl_positive']}; Sharpe P05/P50/P95 = "
        f"{bootstrap['annualized_sharpe']['p05']} / "
        f"{bootstrap['annualized_sharpe']['p50']} / "
        f"{bootstrap['annualized_sharpe']['p95']}.",
        "",
        "No book manifest, gate verdict, deployment action, or AutoTrading action was produced.",
        "",
    ]
    return "\n".join(lines)


def build_report(
    package_root: str | Path = DEFAULT_PACKAGE,
    config: LabConfig = LabConfig(),
) -> dict[str, Any]:
    return {"generated_at_utc": _utc_now(), **analyze_package(load_package(package_root), config)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--package", type=Path, default=DEFAULT_PACKAGE)
    parser.add_argument("--annualization", type=int, default=252)
    parser.add_argument("--train-fraction", type=float, default=0.70)
    parser.add_argument("--downside-quantile", type=float, default=0.20)
    parser.add_argument("--stress-quantile", type=float, default=0.05)
    parser.add_argument("--bootstrap-runs", type=int, default=1999)
    parser.add_argument("--bootstrap-block-days", type=int, default=20)
    parser.add_argument("--bootstrap-seed", type=int, default=20260824)
    parser.add_argument("--bootstrap-batch-size", type=int, default=64)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--markdown", type=Path)
    args = parser.parse_args(argv)
    config = LabConfig(
        annualization=args.annualization,
        train_fraction=args.train_fraction,
        downside_quantile=args.downside_quantile,
        stress_quantile=args.stress_quantile,
        bootstrap_runs=args.bootstrap_runs,
        bootstrap_block_days=args.bootstrap_block_days,
        bootstrap_seed=args.bootstrap_seed,
        bootstrap_batch_size=args.bootstrap_batch_size,
    )
    try:
        report = build_report(args.package, config)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"SHADOW_BOOKLAB_REFUSED: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(render_markdown(report), encoding="utf-8")
    print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = [
    "LabConfig", "Package", "ShadowBookLabError", "analyze_package",
    "build_report", "load_package", "render_markdown",
]
