from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:
    from .commission import describe_model, load_model
    from .portfolio_common import (
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        key_label,
        load_streams,
        read_candidates,
        to_daily_pnl,
    )
except ImportError:  # pragma: no cover - direct script execution
    from commission import describe_model, load_model  # type: ignore
    from portfolio_common import (  # type: ignore
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        key_label,
        load_streams,
        read_candidates,
        to_daily_pnl,
    )


DEFAULT_STARTING_CAPITAL = 100_000.0
DEFAULT_PHASE_HORIZON_DAYS = 60
DEFAULT_BLOCK_DAYS = 5
COMMISSION_BASIS = "worst_case_dxz_ftmo"
EPSILON = 1e-9


@dataclass(frozen=True)
class ChallengePhase:
    name: str
    profit_target_pct: float
    max_daily_loss_pct: float
    max_loss_pct: float
    min_trading_days: int


@dataclass(frozen=True)
class ChallengePreset:
    name: str
    timezone: str
    source_urls: tuple[str, ...]
    phases: tuple[ChallengePhase, ...]
    note: str


FTMO_2STEP = ChallengePreset(
    name="FTMO_2STEP",
    timezone="CE(S)T",
    source_urls=(
        "https://ftmo.com/en/trading-objectives/",
        "https://ftmo.com/en/how-it-works/",
    ),
    phases=(
        ChallengePhase(
            name="challenge",
            profit_target_pct=10.0,
            max_daily_loss_pct=5.0,
            max_loss_pct=10.0,
            min_trading_days=4,
        ),
        ChallengePhase(
            name="verification",
            profit_target_pct=5.0,
            max_daily_loss_pct=5.0,
            max_loss_pct=10.0,
            min_trading_days=4,
        ),
    ),
    note=(
        "Closed daily PnL approximation from Q08 streams. Intraday floating "
        "drawdown is not visible in these artifacts, so daily-loss breach risk "
        "is a lower-bound estimate."
    ),
)

PRESETS = {FTMO_2STEP.name: FTMO_2STEP}


def get_preset(name: str) -> ChallengePreset:
    try:
        return PRESETS[name.upper()]
    except KeyError as exc:
        raise ValueError(f"unknown prop challenge preset: {name}") from exc


def evaluate_phase(
    daily_pnl: Sequence[float],
    phase: ChallengePhase,
    *,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
) -> dict[str, Any]:
    if starting_capital <= 0.0:
        raise ValueError("starting_capital must be > 0")
    if phase.min_trading_days < 1:
        raise ValueError("min_trading_days must be >= 1")

    target_equity = starting_capital * (1.0 + phase.profit_target_pct / 100.0)
    daily_loss_limit = starting_capital * phase.max_daily_loss_pct / 100.0
    max_loss_floor = starting_capital * (1.0 - phase.max_loss_pct / 100.0)
    equity = starting_capital
    target_day: int | None = None
    max_closed_daily_loss_pct = 0.0
    max_total_loss_pct = 0.0

    for day_index, raw_pnl in enumerate(daily_pnl, start=1):
        pnl = float(raw_pnl)
        equity += pnl
        if pnl < 0.0:
            max_closed_daily_loss_pct = max(
                max_closed_daily_loss_pct,
                abs(pnl) / starting_capital * 100.0,
            )
        if equity < starting_capital:
            max_total_loss_pct = max(
                max_total_loss_pct,
                (starting_capital - equity) / starting_capital * 100.0,
            )

        if pnl <= -daily_loss_limit:
            return _phase_result(
                phase,
                passed=False,
                reason="daily_loss_breach",
                days=day_index,
                target_day=target_day,
                terminal_equity=equity,
                max_closed_daily_loss_pct=max_closed_daily_loss_pct,
                max_total_loss_pct=max_total_loss_pct,
            )
        if equity <= max_loss_floor:
            return _phase_result(
                phase,
                passed=False,
                reason="max_loss_breach",
                days=day_index,
                target_day=target_day,
                terminal_equity=equity,
                max_closed_daily_loss_pct=max_closed_daily_loss_pct,
                max_total_loss_pct=max_total_loss_pct,
            )

        if equity + EPSILON >= target_equity and target_day is None:
            target_day = day_index
        if target_day is not None and day_index >= phase.min_trading_days:
            return _phase_result(
                phase,
                passed=True,
                reason="passed",
                days=day_index,
                target_day=target_day,
                terminal_equity=equity,
                max_closed_daily_loss_pct=max_closed_daily_loss_pct,
                max_total_loss_pct=max_total_loss_pct,
            )

    return _phase_result(
        phase,
        passed=False,
        reason="target_not_reached",
        days=len(daily_pnl),
        target_day=target_day,
        terminal_equity=equity,
        max_closed_daily_loss_pct=max_closed_daily_loss_pct,
        max_total_loss_pct=max_total_loss_pct,
    )


def evaluate_challenge(
    daily_pnl: Sequence[float],
    preset: ChallengePreset = FTMO_2STEP,
    *,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    phase_horizon_days: int | None = DEFAULT_PHASE_HORIZON_DAYS,
) -> dict[str, Any]:
    if phase_horizon_days is not None and phase_horizon_days < 1:
        raise ValueError("phase_horizon_days must be >= 1")

    pnl = [float(value) for value in daily_pnl]
    offset = 0
    phases: list[dict[str, Any]] = []
    for phase in preset.phases:
        remaining = pnl[offset:]
        window = remaining if phase_horizon_days is None else remaining[:phase_horizon_days]
        result = evaluate_phase(window, phase, starting_capital=starting_capital)
        result["start_offset_days"] = offset
        result["end_offset_days"] = offset + int(result["days"])
        phases.append(result)
        if not result["passed"]:
            return {
                "passed": False,
                "reason": result["reason"],
                "failed_phase": phase.name,
                "total_days": offset + int(result["days"]),
                "phases": phases,
            }
        offset += int(result["days"])

    return {
        "passed": True,
        "reason": "passed",
        "failed_phase": None,
        "total_days": offset,
        "phases": phases,
    }


def build_artifact(
    *,
    preset_name: str = "FTMO_2STEP",
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    selected_keys: list[tuple[int, str]] | None = None,
    weights: list[float] | None = None,
    runs: int = 1000,
    block_days: int = DEFAULT_BLOCK_DAYS,
    seed: int = 0,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    risk_scale: float = 1.0,
    phase_horizon_days: int = DEFAULT_PHASE_HORIZON_DAYS,
) -> dict[str, Any]:
    if runs < 1:
        raise ValueError("runs must be >= 1")
    if block_days < 1:
        raise ValueError("block_days must be >= 1")
    if starting_capital <= 0.0:
        raise ValueError("starting_capital must be > 0")
    if risk_scale <= 0.0:
        raise ValueError("risk_scale must be > 0")
    if phase_horizon_days < 1:
        raise ValueError("phase_horizon_days must be >= 1")

    preset = get_preset(preset_name)
    requested_weights = _weights_by_key(selected_keys, weights)
    if selected_keys is not None:
        candidates = selected_keys
        basis = "specified_keys"
    elif all_streams:
        candidates = None
        basis = "all_q08_streams_uncertified"
    else:
        candidates = read_candidates(candidates_db)
        basis = "candidates"

    model = load_model()
    streams = load_streams(common_dir, candidates=candidates, commission_model=model)
    series_by_key = {key: to_daily_pnl(trades) for key, trades in streams.items()}
    keys = sorted(series_by_key)

    if selected_keys is not None:
        missing = sorted(set(selected_keys) - set(keys))
        if missing:
            labels = ", ".join(key_label(key) for key in missing)
            raise ValueError(f"selected stream(s) not found: {labels}")

    weight_vector = _weight_vector(keys, requested_weights)
    daily_pnl = [
        value * risk_scale
        for value in combine_calendar_daily_pnl(keys, series_by_key, weight_vector)
    ]
    observed = evaluate_challenge(
        daily_pnl,
        preset,
        starting_capital=starting_capital,
        phase_horizon_days=phase_horizon_days,
    )
    simulation = simulate(
        daily_pnl,
        preset,
        runs=runs,
        block_days=block_days,
        seed=seed,
        starting_capital=starting_capital,
        phase_horizon_days=phase_horizon_days,
    )

    return {
        "phase": "Q_PROP_CHALLENGE",
        "preset": preset.name,
        "rules": _preset_dict(preset),
        "basis": basis,
        "commission_basis": COMMISSION_BASIS,
        "commission_model": describe_model(model),
        "degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "starting_capital": _round_float(starting_capital),
        "risk_scale": _round_float(risk_scale),
        "runs": runs,
        "block_days": block_days,
        "phase_horizon_days": phase_horizon_days,
        "seed": seed,
        "n_series": len(keys),
        "n_days": len(daily_pnl),
        "keys": [key_label(key) for key in keys],
        "weights": [_round_float(value) for value in weight_vector],
        "daily_pnl_stats": daily_pnl_stats(daily_pnl, starting_capital),
        "observed": observed,
        "simulation": simulation,
    }


def daily_pnl_stats(daily_pnl: Sequence[float], starting_capital: float) -> dict[str, Any]:
    pnl = [float(value) for value in daily_pnl]
    if not pnl:
        return {
            "n_days": 0,
            "total_net": 0.0,
            "best_day": 0.0,
            "worst_day": 0.0,
            "best_day_dependency_pct": None,
            "worst_closed_daily_loss_pct": 0.0,
        }
    positive = [value for value in pnl if value > 0.0]
    best_day = max(pnl)
    worst_day = min(pnl)
    positive_sum = sum(positive)
    dependency = None if positive_sum <= 0.0 else best_day / positive_sum * 100.0
    return {
        "n_days": len(pnl),
        "total_net": _round_float(sum(pnl)),
        "best_day": _round_float(best_day),
        "worst_day": _round_float(worst_day),
        "mean_day": _round_float(sum(pnl) / len(pnl)),
        "profit_days": sum(1 for value in pnl if value > 0.0),
        "loss_days": sum(1 for value in pnl if value < 0.0),
        "best_day_dependency_pct": None if dependency is None else _round_float(dependency),
        "worst_closed_daily_loss_pct": _round_float(abs(min(worst_day, 0.0)) / starting_capital * 100.0),
    }


def simulate(
    daily_pnl: Sequence[float],
    preset: ChallengePreset,
    *,
    runs: int,
    block_days: int,
    seed: int,
    starting_capital: float,
    phase_horizon_days: int,
) -> dict[str, Any]:
    rng = random.Random(seed)
    pnl = [float(value) for value in daily_pnl]
    total_horizon = phase_horizon_days * len(preset.phases)

    block_results: list[dict[str, Any]] = []
    shuffle_results: list[dict[str, Any]] = []
    for _ in range(runs):
        block_path = _block_bootstrap(pnl, total_horizon, block_days, rng)
        block_results.append(
            evaluate_challenge(
                block_path,
                preset,
                starting_capital=starting_capital,
                phase_horizon_days=phase_horizon_days,
            )
        )

        shuffle_path = _shuffle_resample(pnl, total_horizon, rng)
        shuffle_results.append(
            evaluate_challenge(
                shuffle_path,
                preset,
                starting_capital=starting_capital,
                phase_horizon_days=phase_horizon_days,
            )
        )

    return {
        "block_bootstrap": summarize_results(block_results, preset),
        "day_order_shuffle": summarize_results(shuffle_results, preset),
    }


def summarize_results(results: Sequence[Mapping[str, Any]], preset: ChallengePreset) -> dict[str, Any]:
    total = len(results)
    if total == 0:
        return {
            "pass_probability_pct": 0.0,
            "daily_loss_breach_probability_pct": 0.0,
            "max_loss_breach_probability_pct": 0.0,
            "target_not_reached_probability_pct": 0.0,
            "days_to_pass": distribution([]),
            "reason_counts": {},
            "phase_pass_probability_pct": {phase.name: 0.0 for phase in preset.phases},
            "phase2_conditional_pass_probability_pct": 0.0,
        }

    reason_counts: dict[str, int] = {}
    days_to_pass: list[float] = []
    phase_pass_counts = {phase.name: 0 for phase in preset.phases}
    phase1_passes = 0
    phase2_passes = 0
    for result in results:
        reason = str(result.get("reason") or "unknown")
        reason_counts[reason] = reason_counts.get(reason, 0) + 1
        if result.get("passed"):
            days_to_pass.append(float(result.get("total_days") or 0.0))
        for phase_result in result.get("phases") or []:
            phase_name = str(phase_result.get("phase") or "")
            if phase_result.get("passed"):
                phase_pass_counts[phase_name] = phase_pass_counts.get(phase_name, 0) + 1
        phase_names = [str(p.get("phase") or "") for p in result.get("phases") or [] if p.get("passed")]
        if len(preset.phases) >= 1 and preset.phases[0].name in phase_names:
            phase1_passes += 1
        if len(preset.phases) >= 2 and preset.phases[1].name in phase_names:
            phase2_passes += 1

    return {
        "pass_probability_pct": _round_float(reason_counts.get("passed", 0) / total * 100.0),
        "daily_loss_breach_probability_pct": _round_float(
            reason_counts.get("daily_loss_breach", 0) / total * 100.0
        ),
        "max_loss_breach_probability_pct": _round_float(
            reason_counts.get("max_loss_breach", 0) / total * 100.0
        ),
        "target_not_reached_probability_pct": _round_float(
            reason_counts.get("target_not_reached", 0) / total * 100.0
        ),
        "days_to_pass": distribution(days_to_pass),
        "reason_counts": dict(sorted(reason_counts.items())),
        "phase_pass_probability_pct": {
            phase.name: _round_float(phase_pass_counts.get(phase.name, 0) / total * 100.0)
            for phase in preset.phases
        },
        "phase2_conditional_pass_probability_pct": _round_float(
            phase2_passes / phase1_passes * 100.0 if phase1_passes else 0.0
        ),
    }


def write_artifact(artifact: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(artifact, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Simulate prop-firm challenge survival from Q08 streams.")
    parser.add_argument("--preset", default="FTMO_2STEP", choices=sorted(PRESETS))
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument(
        "--keys",
        default=None,
        help="Comma-separated EA-symbol labels, e.g. 10430:NDX.DWX,10430:SP500.DWX.",
    )
    parser.add_argument(
        "--weights",
        default=None,
        help="Comma-separated weights matching --keys. Omit for equal weights.",
    )
    parser.add_argument("--runs", type=int, default=1000)
    parser.add_argument("--block-days", type=int, default=DEFAULT_BLOCK_DAYS)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
    parser.add_argument("--risk-scale", type=float, default=1.0)
    parser.add_argument("--phase-horizon-days", type=int, default=DEFAULT_PHASE_HORIZON_DAYS)
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_ARTIFACT_DIR / "prop_challenge_ftmo_2step.json",
        help="Artifact JSON path.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    selected_keys = _parse_keys(args.keys)
    weights = _parse_weights(args.weights)
    artifact = build_artifact(
        preset_name=args.preset,
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        selected_keys=selected_keys,
        weights=weights,
        runs=args.runs,
        block_days=args.block_days,
        seed=args.seed,
        starting_capital=args.starting_capital,
        risk_scale=args.risk_scale,
        phase_horizon_days=args.phase_horizon_days,
    )
    write_artifact(artifact, args.out)
    block = artifact["simulation"]["block_bootstrap"]
    print(
        f"wrote {args.out} preset={artifact['preset']} "
        f"series={artifact['n_series']} days={artifact['n_days']} "
        f"block_pass={block['pass_probability_pct']}%"
    )
    return 0


def _phase_result(
    phase: ChallengePhase,
    *,
    passed: bool,
    reason: str,
    days: int,
    target_day: int | None,
    terminal_equity: float,
    max_closed_daily_loss_pct: float,
    max_total_loss_pct: float,
) -> dict[str, Any]:
    return {
        "phase": phase.name,
        "passed": passed,
        "reason": reason,
        "days": days,
        "target_day": target_day,
        "terminal_equity": _round_float(terminal_equity),
        "max_closed_daily_loss_pct": _round_float(max_closed_daily_loss_pct),
        "max_total_loss_pct": _round_float(max_total_loss_pct),
        "profit_target_pct": _round_float(phase.profit_target_pct),
        "max_daily_loss_pct": _round_float(phase.max_daily_loss_pct),
        "max_loss_pct": _round_float(phase.max_loss_pct),
        "min_trading_days": phase.min_trading_days,
    }


def _preset_dict(preset: ChallengePreset) -> dict[str, Any]:
    return {
        "name": preset.name,
        "timezone": preset.timezone,
        "source_urls": list(preset.source_urls),
        "note": preset.note,
        "phases": [
            {
                "name": phase.name,
                "profit_target_pct": _round_float(phase.profit_target_pct),
                "max_daily_loss_pct": _round_float(phase.max_daily_loss_pct),
                "max_loss_pct": _round_float(phase.max_loss_pct),
                "min_trading_days": phase.min_trading_days,
            }
            for phase in preset.phases
        ],
    }


def combine_calendar_daily_pnl(
    keys: Sequence[tuple[int, str]],
    series_by_key: Mapping[tuple[int, str], Mapping[dt.date, float]],
    weights: Sequence[float],
) -> list[float]:
    if len(keys) != len(weights):
        raise ValueError("weights must contain one value per key")
    if len(weights) == 0:
        return []
    dates = calendar_dates_for_series(series_by_key.values())
    return [
        sum(
            float(series_by_key.get(key, {}).get(day, 0.0)) * float(weights[col])
            for col, key in enumerate(keys)
        )
        for day in dates
    ]


def calendar_dates_for_series(series: Iterable[Mapping[dt.date, float]]) -> list[dt.date]:
    present = sorted({day for values in series for day in values})
    if not present:
        return []
    start = present[0]
    end = present[-1]
    return [start + dt.timedelta(days=offset) for offset in range((end - start).days + 1)]


def _block_bootstrap(
    pnl: Sequence[float],
    sample_days: int,
    block_days: int,
    rng: random.Random,
) -> list[float]:
    if not pnl or sample_days <= 0:
        return []
    sampled: list[float] = []
    while len(sampled) < sample_days:
        start = rng.randrange(len(pnl))
        for offset in range(block_days):
            sampled.append(float(pnl[(start + offset) % len(pnl)]))
            if len(sampled) == sample_days:
                break
    return sampled


def _shuffle_resample(pnl: Sequence[float], sample_days: int, rng: random.Random) -> list[float]:
    if not pnl or sample_days <= 0:
        return []
    sampled: list[float] = []
    while len(sampled) < sample_days:
        batch = [float(value) for value in pnl]
        rng.shuffle(batch)
        need = sample_days - len(sampled)
        sampled.extend(batch[:need])
    return sampled


def distribution(values: Sequence[float]) -> dict[str, float]:
    if not values:
        return {"p5": 0.0, "p50": 0.0, "p95": 0.0, "mean": 0.0}
    ordered = sorted(float(value) for value in values)
    return {
        "p5": _round_float(_percentile(ordered, 5.0)),
        "p50": _round_float(_percentile(ordered, 50.0)),
        "p95": _round_float(_percentile(ordered, 95.0)),
        "mean": _round_float(sum(ordered) / len(ordered)),
    }


def _weights_by_key(
    keys: list[tuple[int, str]] | None,
    weights: list[float] | None,
) -> dict[tuple[int, str], float] | None:
    if keys is None:
        if weights is not None:
            raise ValueError("--weights requires --keys")
        return None
    if weights is None:
        return None
    if len(keys) != len(weights):
        raise ValueError("--weights must contain one value per --keys entry")
    return dict(zip(keys, weights))


def _weight_vector(
    keys: list[tuple[int, str]],
    requested_weights: dict[tuple[int, str], float] | None,
) -> list[float]:
    if not keys:
        return []
    if requested_weights is None:
        return [1.0 / len(keys) for _ in keys]
    return [float(requested_weights[key]) for key in keys]


def _parse_keys(raw: str | None) -> list[tuple[int, str]] | None:
    if raw is None or raw.strip() == "":
        return None
    keys: list[tuple[int, str]] = []
    for token in raw.split(","):
        label = token.strip()
        ea_id, separator, symbol = label.partition(":")
        if not separator or not ea_id or not symbol:
            raise ValueError(f"invalid key label {label!r}; expected EA_ID:SYMBOL")
        if ea_id.startswith("QM5_"):
            ea_id = ea_id.split("_", 2)[1]
        keys.append((int(ea_id), symbol))
    return keys


def _parse_weights(raw: str | None) -> list[float] | None:
    if raw is None or raw.strip() == "":
        return None
    return [float(token.strip()) for token in raw.split(",")]


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


def _percentile(ordered_values: Sequence[float], percentile: float) -> float:
    if len(ordered_values) == 1:
        return float(ordered_values[0])
    position = (percentile / 100.0) * (len(ordered_values) - 1)
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return float(ordered_values[int(position)])
    lower_value = float(ordered_values[lower])
    upper_value = float(ordered_values[upper])
    return lower_value + (upper_value - lower_value) * (position - lower)


if __name__ == "__main__":
    raise SystemExit(main())
