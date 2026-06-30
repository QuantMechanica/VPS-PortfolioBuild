from __future__ import annotations

import argparse
import datetime as dt
import itertools
import json
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
    from .prop_challenge_sim import (
        DEFAULT_BLOCK_DAYS,
        DEFAULT_PHASE_HORIZON_DAYS,
        DEFAULT_STARTING_CAPITAL,
        combine_calendar_daily_pnl,
        daily_pnl_stats,
        evaluate_challenge,
        get_preset,
        simulate,
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
    from prop_challenge_sim import (  # type: ignore
        DEFAULT_BLOCK_DAYS,
        DEFAULT_PHASE_HORIZON_DAYS,
        DEFAULT_STARTING_CAPITAL,
        combine_calendar_daily_pnl,
        daily_pnl_stats,
        evaluate_challenge,
        get_preset,
        simulate,
    )


Key = tuple[int, str]
DEFAULT_RISK_SCALES = (1.0, 2.0, 3.0, 5.0, 8.0, 10.0, 15.0, 20.0)
DEFAULT_TOP_SINGLE_POOL = 12
DEFAULT_TOP_RESULTS = 25
DEFAULT_MAX_COMBO_SIZE = 3
DEFAULT_MIN_TRADE_COUNT = 50


def build_artifact(
    *,
    preset_name: str = "FTMO_2STEP",
    common_dir: Path = DEFAULT_COMMON_DIR,
    candidates_db: Path = DEFAULT_CANDIDATES_DB,
    all_streams: bool = False,
    selected_keys: list[Key] | None = None,
    risk_scales: Sequence[float] = DEFAULT_RISK_SCALES,
    runs: int = 300,
    block_days: int = DEFAULT_BLOCK_DAYS,
    seed: int = 0,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    phase_horizon_days: int = DEFAULT_PHASE_HORIZON_DAYS,
    max_combo_size: int = DEFAULT_MAX_COMBO_SIZE,
    top_single_pool: int = DEFAULT_TOP_SINGLE_POOL,
    top_results: int = DEFAULT_TOP_RESULTS,
    min_trade_count: int = DEFAULT_MIN_TRADE_COUNT,
    max_daily_breach_probability_pct: float = 5.0,
    max_max_loss_breach_probability_pct: float = 5.0,
) -> dict[str, Any]:
    if runs < 1:
        raise ValueError("runs must be >= 1")
    if block_days < 1:
        raise ValueError("block_days must be >= 1")
    if starting_capital <= 0.0:
        raise ValueError("starting_capital must be > 0")
    if phase_horizon_days < 1:
        raise ValueError("phase_horizon_days must be >= 1")
    if max_combo_size < 1:
        raise ValueError("max_combo_size must be >= 1")
    if top_single_pool < 1:
        raise ValueError("top_single_pool must be >= 1")
    if top_results < 1:
        raise ValueError("top_results must be >= 1")
    if min_trade_count < 1:
        raise ValueError("min_trade_count must be >= 1")

    scales = _validate_risk_scales(risk_scales)
    preset = get_preset(preset_name)
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
    keys = sorted(streams)
    if selected_keys is not None:
        missing = sorted(set(selected_keys) - set(keys))
        if missing:
            labels = ", ".join(key_label(key) for key in missing)
            raise ValueError(f"selected stream(s) not found: {labels}")

    daily_by_key = {key: to_daily_pnl(trades) for key, trades in streams.items()}
    trade_counts = {key: len(trades) for key, trades in streams.items()}

    single_results = [
        evaluate_candidate(
            [key],
            daily_by_key,
            trade_counts,
            preset_name=preset_name,
            risk_scales=scales,
            runs=runs,
            block_days=block_days,
            seed=seed,
            starting_capital=starting_capital,
            phase_horizon_days=phase_horizon_days,
            max_daily_breach_probability_pct=max_daily_breach_probability_pct,
            max_max_loss_breach_probability_pct=max_max_loss_breach_probability_pct,
            min_trade_count=min_trade_count,
        )
        for key in keys
    ]
    ranked_singles = sorted(single_results, key=_candidate_rank_tuple, reverse=True)
    pool_keys = [
        _parse_label(result["keys"][0])
        for result in ranked_singles[: min(top_single_pool, len(ranked_singles))]
    ]

    combo_results: list[dict[str, Any]] = []
    max_size = min(max_combo_size, len(pool_keys))
    for size in range(2, max_size + 1):
        for combo in itertools.combinations(pool_keys, size):
            combo_results.append(
                evaluate_candidate(
                    list(combo),
                    daily_by_key,
                    trade_counts,
                    preset_name=preset_name,
                    risk_scales=scales,
                    runs=runs,
                    block_days=block_days,
                    seed=seed,
                    starting_capital=starting_capital,
                    phase_horizon_days=phase_horizon_days,
                    max_daily_breach_probability_pct=max_daily_breach_probability_pct,
                    max_max_loss_breach_probability_pct=max_max_loss_breach_probability_pct,
                    min_trade_count=min_trade_count,
                )
            )

    ranked_combos = sorted(combo_results, key=_candidate_rank_tuple, reverse=True)
    all_ranked = sorted(single_results + combo_results, key=_candidate_rank_tuple, reverse=True)

    return {
        "phase": "Q_PROP_SPRINT_OPTIMIZER",
        "preset": preset.name,
        "rules": {
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
        },
        "basis": basis,
        "common_dir": str(common_dir),
        "commission_basis": "worst_case_dxz_ftmo",
        "commission_model": describe_model(model),
        "degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "starting_capital": _round_float(starting_capital),
        "risk_scales": [_round_float(value) for value in scales],
        "runs": runs,
        "block_days": block_days,
        "phase_horizon_days": phase_horizon_days,
        "seed": seed,
        "max_combo_size": max_combo_size,
        "top_single_pool": top_single_pool,
        "top_results": top_results,
        "min_trade_count": min_trade_count,
        "max_daily_breach_probability_pct": _round_float(max_daily_breach_probability_pct),
        "max_max_loss_breach_probability_pct": _round_float(max_max_loss_breach_probability_pct),
        "n_streams": len(keys),
        "n_single_results": len(single_results),
        "n_combo_results": len(combo_results),
        "single_pool": [result["keys"][0] for result in ranked_singles[: min(top_single_pool, len(ranked_singles))]],
        "top_singles": ranked_singles[:top_results],
        "top_combinations": ranked_combos[:top_results],
        "top_overall": all_ranked[:top_results],
    }


def evaluate_candidate(
    keys: Sequence[Key],
    daily_by_key: Mapping[Key, Mapping[dt.date, float]],
    trade_counts: Mapping[Key, int],
    *,
    preset_name: str,
    risk_scales: Sequence[float],
    runs: int,
    block_days: int,
    seed: int,
    starting_capital: float,
    phase_horizon_days: int,
    max_daily_breach_probability_pct: float,
    max_max_loss_breach_probability_pct: float,
    min_trade_count: int,
) -> dict[str, Any]:
    preset = get_preset(preset_name)
    combo_keys = tuple(keys)
    base_daily = combine_daily_pnl(combo_keys, daily_by_key)
    scale_results = []
    for scale in risk_scales:
        scaled_daily = [value * float(scale) for value in base_daily]
        observed = evaluate_challenge(
            scaled_daily,
            preset,
            starting_capital=starting_capital,
            phase_horizon_days=phase_horizon_days,
        )
        simulation = simulate(
            scaled_daily,
            preset,
            runs=runs,
            block_days=block_days,
            seed=seed,
            starting_capital=starting_capital,
            phase_horizon_days=phase_horizon_days,
        )
        block = simulation["block_bootstrap"]
        shuffle = simulation["day_order_shuffle"]
        block_pass = float(block["pass_probability_pct"])
        shuffle_pass = float(shuffle["pass_probability_pct"])
        daily_breach = max(
            float(block["daily_loss_breach_probability_pct"]),
            float(shuffle["daily_loss_breach_probability_pct"]),
        )
        max_loss_breach = max(
            float(block["max_loss_breach_probability_pct"]),
            float(shuffle["max_loss_breach_probability_pct"]),
        )
        phase1_pass = max(
            float(block["phase_pass_probability_pct"].get("challenge", 0.0)),
            float(shuffle["phase_pass_probability_pct"].get("challenge", 0.0)),
        )
        row = {
            "risk_scale": _round_float(scale),
            "observed": _compact_observed(observed),
            "robust_pass_probability_pct": _round_float(min(block_pass, shuffle_pass)),
            "avg_pass_probability_pct": _round_float((block_pass + shuffle_pass) / 2.0),
            "block_pass_probability_pct": _round_float(block_pass),
            "shuffle_pass_probability_pct": _round_float(shuffle_pass),
            "phase1_pass_probability_pct": _round_float(phase1_pass),
            "daily_loss_breach_probability_pct": _round_float(daily_breach),
            "max_loss_breach_probability_pct": _round_float(max_loss_breach),
            "target_not_reached_probability_pct": _round_float(
                max(
                    float(block["target_not_reached_probability_pct"]),
                    float(shuffle["target_not_reached_probability_pct"]),
                )
            ),
            "days_to_pass_p50": _round_float(
                max(
                    float(block["days_to_pass"]["p50"]),
                    float(shuffle["days_to_pass"]["p50"]),
                )
            ),
            "daily_pnl_stats": daily_pnl_stats(scaled_daily, starting_capital),
        }
        row["status"] = _scale_status(
            row,
            max_daily_breach_probability_pct=max_daily_breach_probability_pct,
            max_max_loss_breach_probability_pct=max_max_loss_breach_probability_pct,
        )
        scale_results.append(row)

    best = max(scale_results, key=_scale_rank_tuple)
    trade_count = sum(int(trade_counts.get(key, 0)) for key in combo_keys)
    return {
        "keys": [key_label(key) for key in combo_keys],
        "combo_size": len(combo_keys),
        "weights": [_round_float(1.0 / len(combo_keys)) for _ in combo_keys],
        "trade_count": trade_count,
        "min_trade_count": min_trade_count,
        "sample_status": "PASS" if trade_count >= min_trade_count else "LOW_SAMPLE",
        "n_days": len(base_daily),
        "base_daily_pnl_stats": daily_pnl_stats(base_daily, starting_capital),
        "best": best,
        "scale_results": scale_results,
    }


def combine_daily_pnl(
    keys: Sequence[Key],
    daily_by_key: Mapping[Key, Mapping[dt.date, float]],
) -> list[float]:
    if not keys:
        return []
    weight = 1.0 / len(keys)
    return combine_calendar_daily_pnl(keys, daily_by_key, [weight for _ in keys])


def write_artifact(artifact: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(artifact, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Rank FTMO sprint candidates from Q08 streams.")
    parser.add_argument("--preset", default="FTMO_2STEP", choices=["FTMO_2STEP"])
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument(
        "--keys",
        default=None,
        help="Comma-separated EA-symbol labels, e.g. 10430:NDX.DWX,10430:SP500.DWX.",
    )
    parser.add_argument(
        "--risk-scales",
        default=",".join(str(value).rstrip("0").rstrip(".") for value in DEFAULT_RISK_SCALES),
        help="Comma-separated PnL multipliers to evaluate.",
    )
    parser.add_argument("--runs", type=int, default=300)
    parser.add_argument("--block-days", type=int, default=DEFAULT_BLOCK_DAYS)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
    parser.add_argument("--phase-horizon-days", type=int, default=DEFAULT_PHASE_HORIZON_DAYS)
    parser.add_argument("--max-combo-size", type=int, default=DEFAULT_MAX_COMBO_SIZE)
    parser.add_argument("--top-single-pool", type=int, default=DEFAULT_TOP_SINGLE_POOL)
    parser.add_argument("--top-results", type=int, default=DEFAULT_TOP_RESULTS)
    parser.add_argument("--min-trade-count", type=int, default=DEFAULT_MIN_TRADE_COUNT)
    parser.add_argument("--max-daily-breach-probability-pct", type=float, default=5.0)
    parser.add_argument("--max-max-loss-breach-probability-pct", type=float, default=5.0)
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_ARTIFACT_DIR / "prop_challenge_ftmo_2step_sprint_optimizer.json",
        help="Artifact JSON path.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    artifact = build_artifact(
        preset_name=args.preset,
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        selected_keys=_parse_keys(args.keys),
        risk_scales=_parse_scales(args.risk_scales),
        runs=args.runs,
        block_days=args.block_days,
        seed=args.seed,
        starting_capital=args.starting_capital,
        phase_horizon_days=args.phase_horizon_days,
        max_combo_size=args.max_combo_size,
        top_single_pool=args.top_single_pool,
        top_results=args.top_results,
        min_trade_count=args.min_trade_count,
        max_daily_breach_probability_pct=args.max_daily_breach_probability_pct,
        max_max_loss_breach_probability_pct=args.max_max_loss_breach_probability_pct,
    )
    write_artifact(artifact, args.out)
    best = artifact["top_overall"][0]["best"] if artifact["top_overall"] else {}
    keys = ",".join(artifact["top_overall"][0]["keys"]) if artifact["top_overall"] else "none"
    print(
        f"wrote {args.out} streams={artifact['n_streams']} "
        f"combos={artifact['n_combo_results']} best={keys} "
        f"scale={best.get('risk_scale')} robust_pass={best.get('robust_pass_probability_pct')}%"
    )
    return 0


def _scale_status(
    row: Mapping[str, Any],
    *,
    max_daily_breach_probability_pct: float,
    max_max_loss_breach_probability_pct: float,
) -> str:
    daily_ok = float(row["daily_loss_breach_probability_pct"]) <= max_daily_breach_probability_pct
    max_loss_ok = float(row["max_loss_breach_probability_pct"]) <= max_max_loss_breach_probability_pct
    if not daily_ok or not max_loss_ok:
        return "RISK_TOO_HIGH"
    if float(row["robust_pass_probability_pct"]) > 0.0:
        return "SPRINT_CANDIDATE"
    if float(row["phase1_pass_probability_pct"]) > 0.0:
        return "PHASE1_ONLY"
    return "TOO_SLOW"


def _scale_rank_tuple(row: Mapping[str, Any]) -> tuple[float, ...]:
    risk_penalty = (
        float(row["daily_loss_breach_probability_pct"])
        + float(row["max_loss_breach_probability_pct"])
    )
    stats = row.get("daily_pnl_stats") or {}
    dependency = stats.get("best_day_dependency_pct")
    dependency_penalty = float(dependency) if dependency is not None else 100.0
    return (
        float(row["robust_pass_probability_pct"]),
        -risk_penalty,
        float(row["avg_pass_probability_pct"]),
        float(row["phase1_pass_probability_pct"]),
        -dependency_penalty,
        float(stats.get("total_net") or 0.0),
    )


def _candidate_rank_tuple(candidate: Mapping[str, Any]) -> tuple[float, ...]:
    return _scale_rank_tuple(candidate["best"])


def _compact_observed(observed: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "passed": bool(observed.get("passed")),
        "reason": observed.get("reason"),
        "failed_phase": observed.get("failed_phase"),
        "total_days": observed.get("total_days"),
    }


def _validate_risk_scales(scales: Sequence[float]) -> list[float]:
    values = sorted({float(value) for value in scales})
    if not values:
        raise ValueError("risk_scales must not be empty")
    if any(value <= 0.0 for value in values):
        raise ValueError("risk scales must be > 0")
    return values


def _parse_scales(raw: str | None) -> list[float]:
    if raw is None or raw.strip() == "":
        return list(DEFAULT_RISK_SCALES)
    return _validate_risk_scales([float(token.strip()) for token in raw.split(",")])


def _parse_keys(raw: str | None) -> list[Key] | None:
    if raw is None or raw.strip() == "":
        return None
    keys: list[Key] = []
    for token in raw.split(","):
        label = token.strip()
        keys.append(_parse_label(label))
    return keys


def _parse_label(label: str) -> Key:
    ea_id, separator, symbol = label.partition(":")
    if not separator or not ea_id or not symbol:
        raise ValueError(f"invalid key label {label!r}; expected EA_ID:SYMBOL")
    if ea_id.startswith("QM5_"):
        ea_id = ea_id.split("_", 2)[1]
    return int(ea_id), symbol


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


if __name__ == "__main__":
    raise SystemExit(main())
