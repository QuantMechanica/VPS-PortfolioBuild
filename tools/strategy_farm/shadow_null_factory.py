#!/usr/bin/env python3
"""Selection-adjusted null audit for a declared strategy-trial cohort.

Input is a rectangular long-form CSV with ``date,trial_id,return``.  Every trial
must contain every date: silently dropping failed/short trials would make the
false-discovery estimate optimistic and is therefore refused.

The null removes each trial's observed mean, then moving-block bootstraps the
*joint* daily vector.  This preserves cross-trial dependence and within-block
serial structure while imposing zero in-sample alpha.  The selected winner is
compared with the distribution of the maximum Sharpe across the entire cohort;
trial-level empirical p-values also receive Benjamini-Hochberg q-values.

This is SHADOW_ONLY evidence.  It neither changes Q08 nor produces a gate verdict.
"""
from __future__ import annotations

import argparse
import csv
import dataclasses
import datetime as dt
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any, Iterable

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


SCHEMA = "qm.shadow-null-factory/v1"
LEDGER_SCHEMA = "qm.shadow-null-factory-ledger/v1"
SELECTION_RULE = "MAX_ANNUALIZED_SHARPE_THEN_TRIAL_ID"
NULL_MODEL = "JOINT_CENTERED_CIRCULAR_MOVING_BLOCK_BOOTSTRAP"
MIN_OBSERVATIONS = 60
MIN_TRIALS = 2
MIN_REPLICATIONS = 99


class NullFactoryError(ValueError):
    """The shadow experiment is incomplete, ambiguous, or not reproducible."""


@dataclasses.dataclass(frozen=True)
class Panel:
    dates: tuple[str, ...]
    trial_ids: tuple[str, ...]
    returns: np.ndarray
    source_path: str
    source_sha256: str
    source_context: dict[str, Any]


@dataclasses.dataclass(frozen=True)
class Experiment:
    annualization: int = 252
    block_length: int = 20
    replications: int = 1999
    seed: int = 20260824
    alpha: float = 0.05
    batch_size: int = 64


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _date_key(value: str) -> tuple[dt.datetime, str]:
    token = str(value or "").strip()
    if not token:
        raise NullFactoryError("blank date")
    try:
        parsed = dt.datetime.fromisoformat(token.replace("Z", "+00:00"))
    except ValueError as exc:
        raise NullFactoryError(f"date is not ISO-8601: {token!r}") from exc
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(dt.timezone.utc).replace(tzinfo=None)
    return parsed, token


def _is_timezone_aware_iso_datetime(value: str) -> bool:
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None


def load_panel(path: str | Path) -> Panel:
    """Load and fail-close on a non-rectangular or non-finite return panel."""
    source = Path(path).resolve()
    cells: dict[tuple[str, str], float] = {}
    date_keys: dict[str, dt.datetime] = {}
    trials: set[str] = set()
    with source.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        required = {"date", "trial_id", "return"}
        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            raise NullFactoryError(
                f"returns CSV requires columns {sorted(required)}"
            )
        for line_number, row in enumerate(reader, start=2):
            parsed_date, date = _date_key(row.get("date") or "")
            trial_id = str(row.get("trial_id") or "").strip()
            if not trial_id:
                raise NullFactoryError(f"blank trial_id at line {line_number}")
            try:
                value = float(row.get("return") or "")
            except (TypeError, ValueError) as exc:
                raise NullFactoryError(
                    f"invalid return at line {line_number}: {row.get('return')!r}"
                ) from exc
            if not math.isfinite(value):
                raise NullFactoryError(f"non-finite return at line {line_number}")
            key = (date, trial_id)
            if key in cells:
                raise NullFactoryError(
                    f"duplicate date/trial cell at line {line_number}: {key!r}"
                )
            cells[key] = value
            date_keys[date] = parsed_date
            trials.add(trial_id)

    dates = tuple(sorted(date_keys, key=lambda value: (date_keys[value], value)))
    trial_ids = tuple(sorted(trials))
    if len(dates) < MIN_OBSERVATIONS:
        raise NullFactoryError(
            f"insufficient synchronized observations: {len(dates)} < {MIN_OBSERVATIONS}"
        )
    if len(trial_ids) < MIN_TRIALS:
        raise NullFactoryError(
            f"insufficient trial cohort: {len(trial_ids)} < {MIN_TRIALS}"
        )
    expected = len(dates) * len(trial_ids)
    if len(cells) != expected:
        missing = [
            {"date": date, "trial_id": trial}
            for date in dates
            for trial in trial_ids
            if (date, trial) not in cells
        ]
        raise NullFactoryError(
            "return panel is not rectangular; missing cells include "
            + json.dumps(missing[:10], sort_keys=True)
        )
    matrix = np.asarray(
        [[cells[(date, trial)] for trial in trial_ids] for date in dates],
        dtype=np.float64,
    )
    if not np.isfinite(matrix).all():
        raise NullFactoryError("return matrix contains a non-finite value")
    return Panel(
        dates=dates,
        trial_ids=trial_ids,
        returns=matrix,
        source_path=str(source),
        source_sha256=_sha256(source),
        source_context={"kind": "rectangular_long_form_csv"},
    )


def panel_from_booklab_package(path: str | Path) -> Panel:
    """Adapt a verified BookLab package without writing an intermediate CSV."""
    from tools.strategy_farm.portfolio.shadow_booklab import load_package

    package = load_package(path)
    return Panel(
        dates=package.dates,
        trial_ids=package.sleeve_ids,
        returns=np.asarray(package.matrix, dtype=np.float64),
        source_path=package.root,
        source_sha256=package.package_sha256,
        source_context={
            "kind": "q15_shadow_booklab_verified_package",
            "declared_sleeves": len(package.sleeve_ids) + len(package.exclusions),
            "analyzed_sleeves": len(package.sleeve_ids),
            "excluded_sleeves": len(package.exclusions),
            "exclusions": [
                {"sleeve": row.get("sleeve"), "reason": row.get("reason")}
                for row in package.exclusions
            ],
            "selection_warning": (
                "This is an incumbent roster, not the loser-inclusive Factory trial universe."
            ),
        },
    )


def _validate_experiment(experiment: Experiment, observations: int) -> None:
    if experiment.annualization <= 0:
        raise NullFactoryError("annualization must be positive")
    if not 1 <= experiment.block_length <= observations:
        raise NullFactoryError(
            f"block_length must be in [1,{observations}]"
        )
    if experiment.replications < MIN_REPLICATIONS:
        raise NullFactoryError(
            f"replications must be >= {MIN_REPLICATIONS}"
        )
    if not 0.0 < experiment.alpha < 1.0:
        raise NullFactoryError("alpha must be strictly between zero and one")
    if experiment.batch_size <= 0:
        raise NullFactoryError("batch_size must be positive")


def _sharpe(matrix: np.ndarray, annualization: int) -> np.ndarray:
    means = np.mean(matrix, axis=-2)
    std = np.std(matrix, axis=-2, ddof=1)
    scale = math.sqrt(annualization)
    with np.errstate(divide="ignore", invalid="ignore"):
        values = means / std * scale
    return values


def _bh_qvalues(p_values: np.ndarray) -> np.ndarray:
    count = len(p_values)
    order = np.argsort(p_values, kind="stable")
    ranked = p_values[order]
    adjusted = ranked * count / np.arange(1, count + 1, dtype=np.float64)
    adjusted = np.minimum.accumulate(adjusted[::-1])[::-1]
    adjusted = np.clip(adjusted, 0.0, 1.0)
    result = np.empty(count, dtype=np.float64)
    result[order] = adjusted
    return result


def _quantile(values: np.ndarray, probability: float) -> float:
    return float(np.quantile(values, probability, method="linear"))


def _ledger_expected(panel: Panel, experiment: Experiment) -> dict[str, Any]:
    return {
        "schema": LEDGER_SCHEMA,
        "returns_sha256": panel.source_sha256,
        "trial_ids": list(panel.trial_ids),
        "selection_rule": SELECTION_RULE,
        "null_model": NULL_MODEL,
        "annualization": experiment.annualization,
        "block_length": experiment.block_length,
        "replications": experiment.replications,
        "seed": experiment.seed,
        "alpha": experiment.alpha,
    }


def validate_ledger(
    ledger_path: str | Path | None,
    panel: Panel,
    experiment: Experiment,
) -> dict[str, Any]:
    if ledger_path is None:
        return {
            "status": "MISSING",
            "gate_eligible": False,
            "reason": "No pre-evaluation ledger was supplied.",
            "expected_contract": _ledger_expected(panel, experiment),
            "required_provenance": {
                "attestation": "SPEC_FROZEN_BEFORE_SHADOW_EVALUATION",
                "cohort_attestation": "ALL_DECLARED_SEARCH_TRIALS_INCLUDED",
                "cohort_definition": "<durable non-empty search-universe definition>",
                "frozen_at_utc": "<ISO-8601 timestamp>",
            },
        }
    path = Path(ledger_path).resolve()
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    expected = _ledger_expected(panel, experiment)
    mismatches = {
        key: {"expected": value, "observed": payload.get(key)}
        for key, value in expected.items()
        if payload.get(key) != value
    }
    attested = payload.get("attestation") == "SPEC_FROZEN_BEFORE_SHADOW_EVALUATION"
    cohort_attested = (
        payload.get("cohort_attestation") == "ALL_DECLARED_SEARCH_TRIALS_INCLUDED"
    )
    cohort_definition = str(payload.get("cohort_definition") or "").strip()
    frozen_at = str(payload.get("frozen_at_utc") or "").strip()
    frozen_at_valid = bool(frozen_at) and _is_timezone_aware_iso_datetime(frozen_at)
    if (
        mismatches
        or not attested
        or not cohort_attested
        or not cohort_definition
        or not frozen_at_valid
    ):
        detail = {
            "mismatches": mismatches,
            "spec_attestation_valid": attested,
            "cohort_attestation_valid": cohort_attested,
            "cohort_definition_present": bool(cohort_definition),
            "frozen_at_valid": frozen_at_valid,
        }
        raise NullFactoryError("ledger validation failed: " + json.dumps(detail, sort_keys=True))
    return {
        "status": "VERIFIED",
        "gate_eligible": False,
        "reason": "The frozen shadow specification matches the returns and experiment.",
        "path": str(path),
        "sha256": _sha256(path),
        "frozen_at_utc": frozen_at,
        "cohort_attestation": payload["cohort_attestation"],
        "cohort_definition": cohort_definition,
    }


def analyze_panel(
    panel: Panel,
    experiment: Experiment = Experiment(),
    *,
    ledger_path: str | Path | None = None,
) -> dict[str, Any]:
    """Run the joint moving-block null and return a deterministic JSON model."""
    if panel.returns.ndim != 2 or panel.returns.shape != (
        len(panel.dates),
        len(panel.trial_ids),
    ):
        raise NullFactoryError(
            "panel matrix shape does not match its date/trial identifiers"
        )
    if not np.isfinite(panel.returns).all():
        raise NullFactoryError("panel matrix contains a non-finite value")
    observations, trial_count = panel.returns.shape
    _validate_experiment(experiment, observations)
    observed = _sharpe(panel.returns, experiment.annualization)
    if not np.isfinite(observed).all():
        invalid = [
            panel.trial_ids[index]
            for index, value in enumerate(observed)
            if not math.isfinite(float(value))
        ]
        raise NullFactoryError(
            f"zero-variance or invalid observed Sharpe for trials: {invalid}"
        )

    # Stable tie-break: trial IDs are sorted, np.argmax returns the first maximum.
    selected_index = int(np.argmax(observed))
    centered = panel.returns - np.mean(panel.returns, axis=0, keepdims=True)
    rng = np.random.default_rng(experiment.seed)
    null_max = np.empty(experiment.replications, dtype=np.float64)
    marginal_exceedances = np.zeros(trial_count, dtype=np.int64)
    blocks = math.ceil(observations / experiment.block_length)
    offsets = np.arange(experiment.block_length, dtype=np.int64)

    written = 0
    while written < experiment.replications:
        batch = min(experiment.batch_size, experiment.replications - written)
        starts = rng.integers(0, observations, size=(batch, blocks), endpoint=False)
        indices = (
            starts[:, :, None] + offsets[None, None, :]
        ) % observations
        indices = indices.reshape(batch, -1)[:, :observations]
        sampled = centered[indices, :]
        null_sharpes = _sharpe(sampled, experiment.annualization)
        if not np.isfinite(null_sharpes).all():
            raise NullFactoryError("null bootstrap produced a non-finite Sharpe")
        null_max[written:written + batch] = np.max(null_sharpes, axis=1)
        marginal_exceedances += np.sum(
            null_sharpes >= observed[None, :], axis=0
        ).astype(np.int64)
        written += batch

    denominator = experiment.replications + 1.0
    marginal_p = (marginal_exceedances + 1.0) / denominator
    fwer_p = np.asarray(
        [
            (1.0 + np.sum(null_max >= value)) / denominator
            for value in observed
        ],
        dtype=np.float64,
    )
    bh_q = _bh_qvalues(marginal_p)
    null_cutoff = _quantile(null_max, 1.0 - experiment.alpha)

    rows = []
    for index, trial_id in enumerate(panel.trial_ids):
        rows.append({
            "trial_id": trial_id,
            "annualized_sharpe": round(float(observed[index]), 8),
            "marginal_empirical_p": round(float(marginal_p[index]), 8),
            "bh_q": round(float(bh_q[index]), 8),
            "maxT_fwer_p": round(float(fwer_p[index]), 8),
            "bh_discovery": bool(bh_q[index] <= experiment.alpha),
            "fwer_discovery": bool(fwer_p[index] <= experiment.alpha),
            "selected": index == selected_index,
        })
    rows.sort(key=lambda row: (-row["annualized_sharpe"], row["trial_id"]))
    selected = next(row for row in rows if row["selected"])
    ledger = validate_ledger(ledger_path, panel, experiment)
    fwer_discoveries = sum(row["fwer_discovery"] for row in rows)
    bh_discoveries = sum(row["bh_discovery"] for row in rows)
    return {
        "schema": SCHEMA,
        "mode": "SHADOW_ONLY_NON_GATE",
        "gate_eligible": False,
        "decision": (
            "SELECTION_SURVIVES_JOINT_NULL"
            if selected["maxT_fwer_p"] <= experiment.alpha
            else "SELECTION_NOT_DISTINGUISHABLE_FROM_SEARCH_LUCK"
        ),
        "input": {
            "path": panel.source_path,
            "sha256": panel.source_sha256,
            "observations": observations,
            "trials": trial_count,
            "start": panel.dates[0],
            "end": panel.dates[-1],
            "rectangular_panel": True,
            "source_context": panel.source_context,
            "loser_inclusion_attestation": (
                "LEDGER_ATTESTED_ALL_DECLARED_SEARCH_TRIALS_INCLUDED"
                if ledger["status"] == "VERIFIED"
                else "UNATTESTED_REQUIRES_REVIEW"
            ),
        },
        "experiment": {
            **dataclasses.asdict(experiment),
            "selection_rule": SELECTION_RULE,
            "null_model": NULL_MODEL,
            "standard_deviation": "sample_ddof_1",
            "joint_day_sampling": True,
            "per_trial_mean_removed_before_resampling": True,
        },
        "ledger": ledger,
        "selected": selected,
        "multiplicity": {
            "alpha": experiment.alpha,
            "bh_discoveries": bh_discoveries,
            "maxT_fwer_discoveries": fwer_discoveries,
            "null_max_sharpe": {
                "mean": round(float(np.mean(null_max)), 8),
                "median": round(_quantile(null_max, 0.5), 8),
                "p90": round(_quantile(null_max, 0.90), 8),
                "p95": round(_quantile(null_max, 0.95), 8),
                "p99": round(_quantile(null_max, 0.99), 8),
                "alpha_cutoff": round(null_cutoff, 8),
            },
            "selected_sharpe_minus_null_median_max": round(
                selected["annualized_sharpe"] - _quantile(null_max, 0.5), 8
            ),
        },
        "trials": rows,
        "limitations": [
            "This audits selection across the supplied return cohort, not every upstream Factory gate.",
            "A missing frozen ledger cannot prove that losing or aborted trials were included.",
            (
                "A verified cohort attestation is a bound provenance claim; this tool "
                "cannot independently prove external completeness."
            ),
            "The circular moving-block model preserves dependence only up to the supplied block length.",
            "No Q08 threshold, verdict, queue row, candidate pool, or book is changed.",
        ],
    }


def build_report(
    returns_path: str | Path | None = None,
    experiment: Experiment = Experiment(),
    *,
    ledger_path: str | Path | None = None,
    booklab_package: str | Path | None = None,
) -> dict[str, Any]:
    if (returns_path is None) == (booklab_package is None):
        raise NullFactoryError(
            "supply exactly one of returns_path or booklab_package"
        )
    panel = (
        load_panel(returns_path)
        if returns_path is not None
        else panel_from_booklab_package(booklab_package)  # type: ignore[arg-type]
    )
    report = analyze_panel(
        panel, experiment, ledger_path=ledger_path
    )
    return {"generated_at_utc": _utc_now(), **report}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--returns", type=Path)
    inputs.add_argument("--booklab-package", type=Path)
    parser.add_argument("--ledger", type=Path)
    parser.add_argument("--annualization", type=int, default=252)
    parser.add_argument("--block-length", type=int, default=20)
    parser.add_argument("--replications", type=int, default=1999)
    parser.add_argument("--seed", type=int, default=20260824)
    parser.add_argument("--alpha", type=float, default=0.05)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    experiment = Experiment(
        annualization=args.annualization,
        block_length=args.block_length,
        replications=args.replications,
        seed=args.seed,
        alpha=args.alpha,
        batch_size=args.batch_size,
    )
    try:
        report = build_report(
            args.returns,
            experiment,
            ledger_path=args.ledger,
            booklab_package=args.booklab_package,
        )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"NULL_FACTORY_REFUSED: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = [
    "Experiment", "NullFactoryError", "Panel", "analyze_panel", "build_report",
    "load_panel", "panel_from_booklab_package", "validate_ledger",
]
