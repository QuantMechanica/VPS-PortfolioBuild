from __future__ import annotations

import argparse
import datetime as dt
import itertools
import json
import re
from html.parser import HTMLParser
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
DEFAULT_OPTIMIZER_ARTIFACT = DEFAULT_ARTIFACT_DIR / "prop_challenge_ftmo_2step_sprint_optimizer.json"
DEFAULT_ROUND24_SCALE_SWEEP_ARTIFACT = (
    DEFAULT_ARTIFACT_DIR / "prop_challenge_ftmo_combo_scale_sweep_round24_20260630.json"
)
DEFAULT_PROP_VALIDATION_ROOT = Path(r"D:\QM\reports\prop_ftmo_candidates_20260629")
DEFAULT_ROUND24_SCREEN_SCALES = (5.7, 5.8, 5.9, 6.0, 6.1)
DEFAULT_SCREEN_CANDIDATE_WEIGHTS = (0.01, 0.02, 0.03, 0.05, 0.08, 0.10)
DEFAULT_MAX_DAILY_BREACH_SCREEN_PCT = 5.0
DEFAULT_MAX_LOSS_BREACH_SCREEN_PCT = 5.0


class _HtmlTableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._in_cell = False
        self._cell_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        if tag == "tr":
            self._row = []
        elif tag in {"td", "th"} and self._row is not None:
            self._in_cell = True
            self._cell_parts = []

    def handle_data(self, data: str) -> None:
        if self._in_cell:
            self._cell_parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"td", "th"} and self._row is not None and self._in_cell:
            cell = " ".join("".join(self._cell_parts).split())
            self._row.append(cell)
            self._in_cell = False
            self._cell_parts = []
        elif tag == "tr" and self._row is not None:
            self.rows.append(self._row)
            self._row = None


def parse_mt5_report_daily_pnl(
    report_path: Path,
    *,
    expected_symbol: str | None = None,
    commission_model: Any | None = None,
) -> dict[str, Any]:
    """Parse native MT5 report.htm closing deals into full-calendar daily PnL.

    The Round24 artifacts were built from MT5 report closing deal rows, using
    profit + swap minus the larger of native round-trip close commission and the
    registry flat round-trip fallback. This keeps the new admission screen on
    the same report.htm basis.
    """
    rows = _report_rows(report_path)
    stats = _extract_report_stats(rows)
    period_start, period_end = _extract_period_dates(str(stats.get("period") or ""))
    model = commission_model if commission_model is not None else load_model()

    daily: dict[dt.date, float] = {}
    if period_start is not None and period_end is not None:
        daily = {
            period_start + dt.timedelta(days=offset): 0.0
            for offset in range((period_end - period_start).days + 1)
        }

    in_deals = False
    headers: list[str] = []
    closed_trades = 0
    symbols: set[str] = set()
    gross_profit = 0.0
    gross_loss = 0.0
    close_commission_total = 0.0
    fallback_commission_total = 0.0
    native_round_trip_commission_total = 0.0

    for row in rows:
        if len(row) == 1 and _normalize_cell(row[0]) == "deals":
            in_deals = True
            headers = []
            continue
        if not in_deals:
            continue
        if row and _normalize_cell(row[0]) == "time":
            headers = row
            continue
        if not headers or len(row) < len(headers):
            continue

        deal = dict(zip(headers, row))
        if _normalize_cell(deal.get("Direction", "")) != "out":
            continue
        symbol = str(deal.get("Symbol") or "").strip()
        if not symbol:
            continue
        if expected_symbol is not None and symbol != expected_symbol:
            continue

        close_time = _parse_report_datetime(str(deal.get("Time") or ""))
        profit = _parse_report_number(str(deal.get("Profit") or "0")) or 0.0
        swap = _parse_report_number(str(deal.get("Swap") or "0")) or 0.0
        close_commission = _parse_report_number(str(deal.get("Commission") or "0")) or 0.0
        volume = _parse_report_number(str(deal.get("Volume") or "0")) or 0.0
        native_round_trip_commission = 2.0 * abs(close_commission)
        fallback_commission = float(model.cost_round_trip(symbol, volume, None))
        commission_cost = max(native_round_trip_commission, fallback_commission)
        net = profit + swap - commission_cost

        symbols.add(symbol)
        closed_trades += 1
        close_commission_total += close_commission
        native_round_trip_commission_total += native_round_trip_commission
        fallback_commission_total += fallback_commission
        if profit > 0.0:
            gross_profit += profit
        elif profit < 0.0:
            gross_loss += profit
        daily[close_time.date()] = daily.get(close_time.date(), 0.0) + net

    if expected_symbol is not None and closed_trades == 0:
        raise ValueError(f"{report_path} has no closing deals for {expected_symbol}")
    if not daily and closed_trades > 0:
        trade_dates = sorted(daily)
        if trade_dates:
            daily = {day: daily.get(day, 0.0) for day in trade_dates}

    total_net = _round_float(sum(daily.values()))
    report_net = stats.get("net")
    net_delta = None
    if isinstance(report_net, (int, float)) and (expected_symbol is None or len(symbols) == 1):
        net_delta = _round_float(total_net - float(report_net))

    return {
        "report_path": str(report_path),
        "basis": "native_mt5_report_htm_closing_deals",
        "symbol": expected_symbol or (sorted(symbols)[0] if len(symbols) == 1 else None),
        "symbols": sorted(symbols),
        "period": stats.get("period"),
        "start_date": period_start.isoformat() if period_start is not None else None,
        "end_date": period_end.isoformat() if period_end is not None else None,
        "calendar_days": len(daily),
        "closed_trades": closed_trades,
        "daily_pnl": dict(sorted(daily.items())),
        "net": total_net,
        "report_net": report_net,
        "report_net_delta": net_delta,
        "gross_profit": _round_float(gross_profit),
        "gross_loss": _round_float(gross_loss),
        "pf": stats.get("pf"),
        "equity_drawdown": stats.get("equity_drawdown"),
        "equity_drawdown_pct": stats.get("equity_drawdown_pct"),
        "native_close_commission_total": _round_float(close_commission_total),
        "native_round_trip_commission_total": _round_float(native_round_trip_commission_total),
        "fallback_commission_total": _round_float(fallback_commission_total),
        "commission_model": describe_model(model),
    }


def _filter_daily_pnl(
    mapping: Mapping[dt.date, float],
    from_date: dt.date | None,
    to_date: dt.date | None,
) -> dict[dt.date, float]:
    """Return a copy of *mapping* keeping only dates within [from_date, to_date].

    None bounds are treated as open (no restriction on that side).
    """
    if from_date is None and to_date is None:
        return dict(mapping)
    return {
        day: value
        for day, value in mapping.items()
        if (from_date is None or day >= from_date) and (to_date is None or day <= to_date)
    }


def build_round24_candidate_screen_artifact(
    *,
    candidate_ea_id: str,
    candidate_symbol: str,
    candidate_report: Path | None = None,
    round24_artifact_path: Path = DEFAULT_ROUND24_SCALE_SWEEP_ARTIFACT,
    candidate_report_root: Path = DEFAULT_PROP_VALIDATION_ROOT,
    candidate_weights: Sequence[float] = DEFAULT_SCREEN_CANDIDATE_WEIGHTS,
    risk_scales: Sequence[float] = DEFAULT_ROUND24_SCREEN_SCALES,
    runs: int | None = None,
    block_days: int | None = None,
    seed: int = 0,
    seeds: Sequence[int] | None = None,
    starting_capital: float | None = None,
    phase_horizon_days: int | None = None,
    trim_mode: str = "proportional",
    trim_key: str | None = None,
    force_confirm: bool = False,
    max_daily_breach_probability_pct: float = DEFAULT_MAX_DAILY_BREACH_SCREEN_PCT,
    max_max_loss_breach_probability_pct: float = DEFAULT_MAX_LOSS_BREACH_SCREEN_PCT,
    pnl_from_date: dt.date | None = None,
    pnl_to_date: dt.date | None = None,
) -> dict[str, Any]:
    round24 = _load_json(round24_artifact_path)
    candidate_key = _parse_label(f"{candidate_ea_id}:{candidate_symbol}")
    candidate_label = _artifact_label(candidate_key)
    lead_labels = [str(label) for label in round24["keys"]]
    lead_keys = [_parse_label(label) for label in lead_labels]
    if candidate_key in lead_keys:
        raise ValueError(f"{candidate_label} is already present in the Round24 lead")

    lead_weights = [float(value) for value in round24["weights"]]
    if len(lead_keys) != len(lead_weights):
        raise ValueError("Round24 artifact keys/weights length mismatch")

    source_reports = dict(round24.get("source_reports") or {})
    daily_by_key: dict[Key, Mapping[dt.date, float]] = {}
    source_report_stats: dict[str, dict[str, Any]] = {}
    for label, key in zip(lead_labels, lead_keys):
        report = source_reports.get(label)
        if not report:
            raise ValueError(f"Round24 source report missing for {label}")
        parsed = parse_mt5_report_daily_pnl(Path(report), expected_symbol=key[1])
        filtered = _filter_daily_pnl(parsed["daily_pnl"], pnl_from_date, pnl_to_date)
        if (pnl_from_date is not None or pnl_to_date is not None) and len(filtered) < 30:
            raise ValueError(
                f"pnl window filter leaves {len(filtered)} days (< 30) for lead leg {label}"
            )
        daily_by_key[key] = filtered
        source_report_stats[label] = _compact_report_parse(parsed)

    resolved_candidate_report = candidate_report or find_latest_candidate_report(
        candidate_key,
        candidate_report_root,
    )
    candidate_parse = parse_mt5_report_daily_pnl(
        resolved_candidate_report,
        expected_symbol=candidate_key[1],
    )
    candidate_filtered = _filter_daily_pnl(candidate_parse["daily_pnl"], pnl_from_date, pnl_to_date)
    if (pnl_from_date is not None or pnl_to_date is not None) and len(candidate_filtered) < 30:
        raise ValueError(
            f"pnl window filter leaves {len(candidate_filtered)} days (< 30) for candidate {candidate_label}"
        )
    daily_by_key[candidate_key] = candidate_filtered

    screen_runs = int(runs if runs is not None else round24.get("runs_per_seed") or 5000)
    screen_block_days = int(block_days if block_days is not None else round24.get("block_days") or DEFAULT_BLOCK_DAYS)
    screen_starting_capital = float(
        starting_capital if starting_capital is not None else round24.get("starting_capital") or DEFAULT_STARTING_CAPITAL
    )
    screen_phase_horizon_days = int(
        phase_horizon_days
        if phase_horizon_days is not None
        else round24.get("phase_horizon_days") or DEFAULT_PHASE_HORIZON_DAYS
    )
    confirm_seeds = [int(value) for value in (seeds if seeds is not None else round24.get("seeds") or [0, 1, 2, 3, 4])]
    scales = _validate_risk_scales(risk_scales)
    weights_to_try = _validate_risk_scales(candidate_weights)
    benchmark = _round24_benchmark(
        round24,
        max_daily_breach_probability_pct=max_daily_breach_probability_pct,
        max_max_loss_breach_probability_pct=max_max_loss_breach_probability_pct,
    )
    preset_name = str(round24.get("preset") or "FTMO_2STEP")

    screen_results: list[dict[str, Any]] = []
    for candidate_weight in weights_to_try:
        case_keys = [*lead_keys, candidate_key]
        case_weights = _append_candidate_weight(
            lead_keys,
            lead_weights,
            candidate_weight,
            trim_mode=trim_mode,
            trim_key=trim_key,
        )
        for scale in scales:
            row = _evaluate_weighted_case(
                case_keys,
                case_weights,
                daily_by_key,
                preset_name=preset_name,
                risk_scale=scale,
                runs=screen_runs,
                block_days=screen_block_days,
                seed=seed,
                starting_capital=screen_starting_capital,
                phase_horizon_days=screen_phase_horizon_days,
                max_daily_breach_probability_pct=max_daily_breach_probability_pct,
                max_max_loss_breach_probability_pct=max_max_loss_breach_probability_pct,
            )
            row["candidate_weight"] = _round_float(candidate_weight)
            row["case_note"] = f"round24_plus_{candidate_label}_{_round_float(candidate_weight)}"
            row["keys"] = [_artifact_label(key) for key in case_keys]
            row["weights"] = [_round_float(value) for value in case_weights]
            screen_results.append(row)

    screen_results.sort(key=lambda row: _screen_rank_tuple(row), reverse=True)
    selected_seed0 = screen_results[0] if screen_results else None
    seed0_beats = bool(selected_seed0 and _screen_row_beats_benchmark(selected_seed0, benchmark))

    confirmation = None
    if selected_seed0 is not None and (seed0_beats or force_confirm):
        confirm_rows = [
            _evaluate_weighted_case(
                [_parse_label(label) for label in selected_seed0["keys"]],
                [float(value) for value in selected_seed0["weights"]],
                daily_by_key,
                preset_name=preset_name,
                risk_scale=float(selected_seed0["risk_scale"]),
                runs=screen_runs,
                block_days=screen_block_days,
                seed=confirm_seed,
                starting_capital=screen_starting_capital,
                phase_horizon_days=screen_phase_horizon_days,
                max_daily_breach_probability_pct=max_daily_breach_probability_pct,
                max_max_loss_breach_probability_pct=max_max_loss_breach_probability_pct,
            )
            for confirm_seed in confirm_seeds
        ]
        for confirm_seed, row in zip(confirm_seeds, confirm_rows):
            row["seed"] = int(confirm_seed)
        confirmation = {
            "case_note": selected_seed0["case_note"],
            "keys": selected_seed0["keys"],
            "weights": selected_seed0["weights"],
            "risk_scale": selected_seed0["risk_scale"],
            "runs_per_seed": screen_runs,
            "seeds": confirm_seeds,
            "seed_results": confirm_rows,
            "summary": _summarize_confirm_rows(confirm_rows),
        }

    verdict, verdict_reason = _admission_verdict(
        selected_seed0=selected_seed0,
        seed0_beats=seed0_beats,
        confirmation=confirmation,
        benchmark=benchmark,
        max_daily_breach_probability_pct=max_daily_breach_probability_pct,
        max_max_loss_breach_probability_pct=max_max_loss_breach_probability_pct,
    )
    deltas = _screen_deltas(
        confirmation["summary"] if confirmation else selected_seed0,
        benchmark,
    )

    return {
        "phase": "Q_PROP_ROUND24_ADMISSION_SCREEN",
        "basis": "native_mt5_report_htm_closing_deals",
        "pnl_from_date": pnl_from_date.isoformat() if pnl_from_date is not None else None,
        "pnl_to_date": pnl_to_date.isoformat() if pnl_to_date is not None else None,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "preset": preset_name,
        "round24_artifact": str(round24_artifact_path),
        "benchmark": benchmark,
        "candidate": {
            "key": candidate_label,
            "ea_id": candidate_key[0],
            "symbol": candidate_key[1],
            "report": _compact_report_parse(candidate_parse),
        },
        "lead": {
            "keys": lead_labels,
            "weights": [_round_float(value) for value in lead_weights],
            "source_reports": source_reports,
            "source_report_stats": source_report_stats,
        },
        "screen": {
            "seed": seed,
            "runs": screen_runs,
            "block_days": screen_block_days,
            "phase_horizon_days": screen_phase_horizon_days,
            "starting_capital": _round_float(screen_starting_capital),
            "risk_scales": [_round_float(value) for value in scales],
            "candidate_weights": [_round_float(value) for value in weights_to_try],
            "trim_mode": trim_mode,
            "trim_key": trim_key,
            "results": screen_results,
            "selected_seed0": selected_seed0,
            "seed0_beats_round24_bar": seed0_beats,
        },
        "confirmation": confirmation,
        "verdict": verdict,
        "verdict_reason": verdict_reason,
        "deltas_vs_round24": deltas,
    }


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


def find_latest_candidate_report(
    candidate_key: Key,
    report_root: Path = DEFAULT_PROP_VALIDATION_ROOT,
) -> Path:
    ea_id, symbol = candidate_key
    if not report_root.exists():
        raise FileNotFoundError(f"candidate report root does not exist: {report_root}")
    ea_dir_pattern = f"QM5_{ea_id}"
    candidates: list[Path] = []
    for report in report_root.glob(f"**/{ea_dir_pattern}/**/raw/run_*/report.htm"):
        try:
            parsed = parse_mt5_report_daily_pnl(report, expected_symbol=symbol)
        except Exception:
            continue
        if parsed["closed_trades"] > 0:
            candidates.append(report)
    if not candidates:
        raise FileNotFoundError(f"no report.htm found for {_artifact_label(candidate_key)} under {report_root}")
    candidates.sort(key=lambda path: path.stat().st_mtime, reverse=True)
    return candidates[0]


def _evaluate_weighted_case(
    keys: Sequence[Key],
    weights: Sequence[float],
    daily_by_key: Mapping[Key, Mapping[dt.date, float]],
    *,
    preset_name: str,
    risk_scale: float,
    runs: int,
    block_days: int,
    seed: int,
    starting_capital: float,
    phase_horizon_days: int,
    max_daily_breach_probability_pct: float,
    max_max_loss_breach_probability_pct: float,
) -> dict[str, Any]:
    preset = get_preset(preset_name)
    base_daily = combine_calendar_daily_pnl(keys, daily_by_key, weights)
    scaled_daily = [value * float(risk_scale) for value in base_daily]
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
    target_not_reached = max(
        float(block["target_not_reached_probability_pct"]),
        float(shuffle["target_not_reached_probability_pct"]),
    )
    row = {
        "risk_scale": _round_float(risk_scale),
        "seed": int(seed),
        "observed_days": observed.get("total_days"),
        "observed_passed": bool(observed.get("passed")),
        "observed_reason": observed.get("reason"),
        "block_pass_probability_pct": _round_float(block_pass),
        "shuffle_pass_probability_pct": _round_float(shuffle_pass),
        "robust_pass_probability_pct": _round_float(min(block_pass, shuffle_pass)),
        "daily_loss_breach_probability_pct": _round_float(daily_breach),
        "max_loss_breach_probability_pct": _round_float(max_loss_breach),
        "target_not_reached_probability_pct": _round_float(target_not_reached),
        "daily_pnl_stats_unscaled": daily_pnl_stats(base_daily, starting_capital),
        "daily_pnl_stats_scaled": daily_pnl_stats(scaled_daily, starting_capital),
    }
    row["status"] = (
        "CLEAN"
        if daily_breach <= max_daily_breach_probability_pct
        and max_loss_breach <= max_max_loss_breach_probability_pct
        else "BREACHY"
    )
    return row


def _append_candidate_weight(
    lead_keys: Sequence[Key],
    lead_weights: Sequence[float],
    candidate_weight: float,
    *,
    trim_mode: str,
    trim_key: str | None,
) -> list[float]:
    candidate_weight = float(candidate_weight)
    if candidate_weight <= 0.0 or candidate_weight >= 1.0:
        raise ValueError("candidate weights must be between 0 and 1")
    if trim_mode == "proportional":
        weights = [float(weight) * (1.0 - candidate_weight) for weight in lead_weights]
    elif trim_mode == "single":
        target_key = _parse_label(trim_key) if trim_key else lead_keys[_largest_weight_index(lead_weights)]
        weights = [float(weight) for weight in lead_weights]
        try:
            idx = list(lead_keys).index(target_key)
        except ValueError as exc:
            raise ValueError(f"trim key {_artifact_label(target_key)} is not in the Round24 lead") from exc
        if weights[idx] <= candidate_weight:
            raise ValueError(
                f"candidate weight {candidate_weight} is too large to trim from {_artifact_label(target_key)}"
            )
        weights[idx] -= candidate_weight
    else:
        raise ValueError("trim_mode must be 'proportional' or 'single'")
    weights.append(candidate_weight)
    total = sum(weights)
    if total <= 0.0:
        raise ValueError("screen weights sum to zero")
    return [weight / total for weight in weights]


def _largest_weight_index(weights: Sequence[float]) -> int:
    return max(range(len(weights)), key=lambda idx: float(weights[idx]))


def _round24_benchmark(
    artifact: Mapping[str, Any],
    *,
    max_daily_breach_probability_pct: float = DEFAULT_MAX_DAILY_BREACH_SCREEN_PCT,
    max_max_loss_breach_probability_pct: float = DEFAULT_MAX_LOSS_BREACH_SCREEN_PCT,
) -> dict[str, Any]:
    clean_summaries: list[dict[str, Any]] = []
    for result in artifact.get("results") or []:
        summary = dict(result.get("summary") or {})
        if not summary:
            continue
        summary["risk_scale"] = result.get("risk_scale")
        if (
            float(summary.get("max_daily_loss_breach_probability_pct") or 0.0)
            <= max_daily_breach_probability_pct
            and float(summary.get("max_max_loss_breach_probability_pct") or 100.0)
            <= max_max_loss_breach_probability_pct
        ):
            clean_summaries.append(summary)
    if not clean_summaries:
        raise ValueError("Round24 artifact does not contain clean result summaries within the breach guards")
    best = max(clean_summaries, key=_benchmark_rank_tuple)
    return {
        "risk_scale": best.get("risk_scale"),
        "min_robust_pass_probability_pct": _round_float(float(best["min_robust_pass_probability_pct"])),
        "mean_robust_pass_probability_pct": _round_float(float(best["mean_robust_pass_probability_pct"])),
        "max_daily_loss_breach_probability_pct": _round_float(
            float(best.get("max_daily_loss_breach_probability_pct") or 0.0)
        ),
        "max_max_loss_breach_probability_pct": _round_float(float(best["max_max_loss_breach_probability_pct"])),
        "mean_target_not_reached_probability_pct": _round_float(
            float(best["mean_target_not_reached_probability_pct"])
        ),
    }


def _benchmark_rank_tuple(summary: Mapping[str, Any]) -> tuple[float, ...]:
    return (
        float(summary.get("min_robust_pass_probability_pct") or 0.0),
        float(summary.get("mean_robust_pass_probability_pct") or 0.0),
        -float(summary.get("max_max_loss_breach_probability_pct") or 100.0),
        -float(summary.get("mean_target_not_reached_probability_pct") or 100.0),
    )


def _screen_rank_tuple(row: Mapping[str, Any]) -> tuple[float, ...]:
    return (
        1.0 if row.get("status") == "CLEAN" else 0.0,
        float(row.get("robust_pass_probability_pct") or 0.0),
        -float(row.get("target_not_reached_probability_pct") or 100.0),
        -float(row.get("max_loss_breach_probability_pct") or 100.0),
        float(row.get("daily_pnl_stats_unscaled", {}).get("total_net") or 0.0),
    )


def _screen_row_beats_benchmark(row: Mapping[str, Any], benchmark: Mapping[str, Any]) -> bool:
    return (
        row.get("status") == "CLEAN"
        and float(row.get("robust_pass_probability_pct") or 0.0)
        > float(benchmark["min_robust_pass_probability_pct"])
        and float(row.get("target_not_reached_probability_pct") or 100.0)
        < float(benchmark["mean_target_not_reached_probability_pct"])
        and float(row.get("max_loss_breach_probability_pct") or 100.0)
        <= float(benchmark["max_max_loss_breach_probability_pct"])
    )


def _summarize_confirm_rows(rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    if not rows:
        return {
            "min_robust_pass_probability_pct": 0.0,
            "mean_robust_pass_probability_pct": 0.0,
            "max_daily_loss_breach_probability_pct": 0.0,
            "max_max_loss_breach_probability_pct": 0.0,
            "mean_target_not_reached_probability_pct": 0.0,
        }
    robust = [float(row.get("robust_pass_probability_pct") or 0.0) for row in rows]
    target = [float(row.get("target_not_reached_probability_pct") or 0.0) for row in rows]
    daily = [float(row.get("daily_loss_breach_probability_pct") or 0.0) for row in rows]
    max_loss = [float(row.get("max_loss_breach_probability_pct") or 0.0) for row in rows]
    return {
        "min_robust_pass_probability_pct": _round_float(min(robust)),
        "mean_robust_pass_probability_pct": _round_float(sum(robust) / len(robust)),
        "max_daily_loss_breach_probability_pct": _round_float(max(daily)),
        "max_max_loss_breach_probability_pct": _round_float(max(max_loss)),
        "mean_target_not_reached_probability_pct": _round_float(sum(target) / len(target)),
    }


def _admission_verdict(
    *,
    selected_seed0: Mapping[str, Any] | None,
    seed0_beats: bool,
    confirmation: Mapping[str, Any] | None,
    benchmark: Mapping[str, Any],
    max_daily_breach_probability_pct: float,
    max_max_loss_breach_probability_pct: float,
) -> tuple[str, str]:
    if selected_seed0 is None:
        return "REJECT", "no screen rows produced"
    if confirmation is None:
        if seed0_beats:
            return "REJECT", "seed-0 beat Round24 but confirmation was not run"
        return "REJECT", "seed-0 screen did not beat the Round24 bar"

    summary = confirmation["summary"]
    daily_loss = float(summary["max_daily_loss_breach_probability_pct"])
    max_loss = float(summary["max_max_loss_breach_probability_pct"])
    improves = (
        float(summary["min_robust_pass_probability_pct"])
        > float(benchmark["min_robust_pass_probability_pct"])
        and float(summary["mean_robust_pass_probability_pct"])
        > float(benchmark["mean_robust_pass_probability_pct"])
        and float(summary["mean_target_not_reached_probability_pct"])
        < float(benchmark["mean_target_not_reached_probability_pct"])
        and max_loss <= min(
            float(benchmark["max_max_loss_breach_probability_pct"]),
            max_max_loss_breach_probability_pct,
        )
        and daily_loss <= max_daily_breach_probability_pct
    )
    if improves:
        return "ADMIT", "confirmed screen improves Round24 robust pass and target coverage within max-loss guard"
    if daily_loss <= max_daily_breach_probability_pct and max_loss <= max_max_loss_breach_probability_pct:
        return "BACKUP", "confirmed screen is clean but does not improve the Round24 bar"
    if daily_loss > max_daily_breach_probability_pct:
        return "REJECT", "confirmed screen breaches the daily-loss guard"
    return "REJECT", "confirmed screen breaches the max-loss guard"


def _screen_deltas(row: Mapping[str, Any] | None, benchmark: Mapping[str, Any]) -> dict[str, Any]:
    if row is None:
        return {}
    mapping = {
        "min_robust_pass_probability_pct": "min_robust_pass_probability_pct",
        "mean_robust_pass_probability_pct": "mean_robust_pass_probability_pct",
        "max_daily_loss_breach_probability_pct": "max_daily_loss_breach_probability_pct",
        "max_max_loss_breach_probability_pct": "max_max_loss_breach_probability_pct",
        "mean_target_not_reached_probability_pct": "mean_target_not_reached_probability_pct",
    }
    if "robust_pass_probability_pct" in row:
        mapping = {
            "robust_pass_probability_pct": "min_robust_pass_probability_pct",
            "max_loss_breach_probability_pct": "max_max_loss_breach_probability_pct",
            "daily_loss_breach_probability_pct": "max_daily_loss_breach_probability_pct",
            "target_not_reached_probability_pct": "mean_target_not_reached_probability_pct",
        }
    deltas: dict[str, Any] = {}
    for row_key, benchmark_key in mapping.items():
        if row_key in row and benchmark_key in benchmark:
            deltas[row_key] = _round_float(float(row[row_key]) - float(benchmark[benchmark_key]))
    return deltas


def _compact_report_parse(parsed: Mapping[str, Any]) -> dict[str, Any]:
    keys = [
        "report_path",
        "basis",
        "symbol",
        "symbols",
        "period",
        "start_date",
        "end_date",
        "calendar_days",
        "closed_trades",
        "net",
        "report_net",
        "report_net_delta",
        "gross_profit",
        "gross_loss",
        "pf",
        "equity_drawdown",
        "equity_drawdown_pct",
        "native_round_trip_commission_total",
        "fallback_commission_total",
    ]
    return {key: parsed.get(key) for key in keys}


def _report_rows(report_path: Path) -> list[list[str]]:
    text = _read_report_text(report_path)
    parser = _HtmlTableParser()
    parser.feed(text)
    return parser.rows


def _read_report_text(report_path: Path) -> str:
    if not report_path.exists():
        raise FileNotFoundError(report_path)
    raw = report_path.read_bytes()
    encodings: list[str] = []
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        encodings.append("utf-16")
    if raw.startswith(b"\xef\xbb\xbf"):
        encodings.append("utf-8-sig")
    if _looks_utf16le(raw):
        encodings.append("utf-16-le")
    encodings.extend(["utf-8-sig", "utf-8", "utf-16", "utf-16-le"])

    for encoding in dict.fromkeys(encodings):
        try:
            text = raw.decode(encoding)
        except UnicodeError:
            continue
        if "<" in text or "Period" in text or "Deals" in text:
            return text
    return raw.decode("utf-8", errors="replace")


def _looks_utf16le(raw: bytes) -> bool:
    if len(raw) < 4:
        return False
    sample = raw[: min(len(raw), 512)]
    odd_nuls = sample[1::2].count(0)
    even_nuls = sample[0::2].count(0)
    return odd_nuls > len(sample) // 8 and odd_nuls > even_nuls * 2


def _extract_report_stats(rows: Sequence[Sequence[str]]) -> dict[str, Any]:
    period = _cell_after(rows, "Period")
    equity_dd_text = _cell_after(rows, "Equity Drawdown Maximal")
    stats = {
        "expert": _cell_after(rows, "Expert"),
        "symbol": _cell_after(rows, "Symbol"),
        "period": period,
        "net": _parse_report_number(_cell_after(rows, "Total Net Profit") or ""),
        "gross_profit": _parse_report_number(_cell_after(rows, "Gross Profit") or ""),
        "gross_loss": _parse_report_number(_cell_after(rows, "Gross Loss") or ""),
        "pf": _parse_report_number(_cell_after(rows, "Profit Factor") or ""),
        "total_trades": _parse_report_int(_cell_after(rows, "Total Trades") or ""),
        "equity_drawdown": _parse_report_number(equity_dd_text or ""),
        "equity_drawdown_pct": _parse_percent(equity_dd_text or ""),
    }
    return stats


def _cell_after(rows: Sequence[Sequence[str]], label: str) -> str | None:
    target = _normalize_cell(label)
    for row in rows:
        for idx, cell in enumerate(row[:-1]):
            if _normalize_cell(cell) == target:
                return row[idx + 1]
    return None


def _extract_period_dates(period: str) -> tuple[dt.date | None, dt.date | None]:
    match = re.search(
        r"\((\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})\)",
        period,
    )
    if not match:
        return None, None
    return (
        dt.datetime.strptime(match.group(1), "%Y.%m.%d").date(),
        dt.datetime.strptime(match.group(2), "%Y.%m.%d").date(),
    )


def _parse_report_datetime(raw: str) -> dt.datetime:
    return dt.datetime.strptime(raw.strip(), "%Y.%m.%d %H:%M:%S").replace(tzinfo=dt.UTC)


def _parse_report_number(raw: str) -> float | None:
    match = re.search(r"-?[\d\s\xa0,.]+", raw)
    if not match:
        return None
    value = match.group(0).replace("\xa0", " ").strip()
    value = value.replace(" ", "")
    if "," in value and "." in value:
        value = value.replace(",", "")
    elif "," in value:
        value = value.replace(",", ".")
    try:
        return float(value)
    except ValueError:
        return None


def _parse_report_int(raw: str) -> int | None:
    value = _parse_report_number(raw)
    return None if value is None else int(value)


def _parse_percent(raw: str) -> float | None:
    matches = re.findall(r"\((-?[\d\s\xa0,.]+)%\)", raw)
    if not matches:
        return None
    return _parse_report_number(matches[-1])


def _normalize_cell(raw: str) -> str:
    return re.sub(r"\s+", " ", raw.strip().rstrip(":").lower())


def _load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def _artifact_label(key: Key) -> str:
    return f"QM5_{key[0]}:{key[1]}"


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
    parser.add_argument(
        "--screen-candidate",
        nargs="+",
        metavar=("EA_ID", "SYMBOL"),
        help="Screen one report.htm-validated candidate against the Round24 lead, e.g. QM5_10494 XAUUSD.DWX or QM5_10494:XAUUSD.DWX.",
    )
    parser.add_argument(
        "--candidate-report",
        type=Path,
        default=None,
        help="Fresh candidate report.htm. If omitted, the latest matching report under --candidate-report-root is used.",
    )
    parser.add_argument("--candidate-report-root", type=Path, default=DEFAULT_PROP_VALIDATION_ROOT)
    parser.add_argument("--round24-artifact", type=Path, default=DEFAULT_ROUND24_SCALE_SWEEP_ARTIFACT)
    parser.add_argument(
        "--candidate-weights",
        default=",".join(str(value).rstrip("0").rstrip(".") for value in DEFAULT_SCREEN_CANDIDATE_WEIGHTS),
        help="Comma-separated overlay weights for --screen-candidate.",
    )
    parser.add_argument(
        "--screen-risk-scales",
        default=",".join(str(value).rstrip("0").rstrip(".") for value in DEFAULT_ROUND24_SCREEN_SCALES),
        help="Comma-separated risk scales for the Round24 admission screen.",
    )
    parser.add_argument("--screen-runs", type=int, default=None)
    parser.add_argument(
        "--screen-seeds",
        default=None,
        help="Comma-separated confirmation seeds. Defaults to the Round24 artifact seeds.",
    )
    parser.add_argument("--trim-mode", choices=["proportional", "single"], default="proportional")
    parser.add_argument("--trim-key", default=None, help="EA:SYMBOL key to trim when --trim-mode single is used.")
    parser.add_argument("--confirm-always", action="store_true")
    parser.add_argument("--force-confirm", action="store_true", dest="confirm_always")
    parser.add_argument(
        "--pnl-from-date",
        default=None,
        help="Filter PnL to dates >= YYYY-MM-DD (inclusive). Applies to all lead and candidate legs.",
    )
    parser.add_argument(
        "--pnl-to-date",
        default=None,
        help="Filter PnL to dates <= YYYY-MM-DD (inclusive). Applies to all lead and candidate legs.",
    )
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
        default=DEFAULT_OPTIMIZER_ARTIFACT,
        help="Artifact JSON path.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.screen_candidate:
        candidate_key = _parse_screen_candidate(args.screen_candidate)
        candidate_ea_id, candidate_symbol = _artifact_label(candidate_key).split(":", 1)
        artifact = build_round24_candidate_screen_artifact(
            candidate_ea_id=candidate_ea_id,
            candidate_symbol=candidate_symbol,
            candidate_report=args.candidate_report,
            round24_artifact_path=args.round24_artifact,
            candidate_report_root=args.candidate_report_root,
            candidate_weights=_parse_scales(args.candidate_weights),
            risk_scales=_parse_scales(args.screen_risk_scales),
            runs=args.screen_runs,
            block_days=args.block_days,
            seed=args.seed,
            seeds=_parse_ints(args.screen_seeds),
            starting_capital=args.starting_capital,
            phase_horizon_days=args.phase_horizon_days,
            trim_mode=args.trim_mode,
            trim_key=args.trim_key,
            force_confirm=args.confirm_always,
            max_daily_breach_probability_pct=args.max_daily_breach_probability_pct,
            max_max_loss_breach_probability_pct=args.max_max_loss_breach_probability_pct,
            pnl_from_date=dt.date.fromisoformat(args.pnl_from_date) if args.pnl_from_date else None,
            pnl_to_date=dt.date.fromisoformat(args.pnl_to_date) if args.pnl_to_date else None,
        )
        out_path = args.out
        if out_path == DEFAULT_OPTIMIZER_ARTIFACT:
            stamp = dt.datetime.now(dt.UTC).strftime("%Y%m%d_%H%M%S")
            safe_key = artifact["candidate"]["key"].replace(":", "_").replace(".", "_")
            out_path = DEFAULT_ARTIFACT_DIR / f"prop_challenge_ftmo_round24_admission_{safe_key}_{stamp}.json"
        write_artifact(artifact, out_path)
        selected = artifact.get("confirmation") or artifact["screen"].get("selected_seed0") or {}
        summary = selected.get("summary", selected)
        print(
            f"{artifact['verdict']} {artifact['candidate']['key']} wrote {out_path} "
            f"reason={artifact['verdict_reason']} "
            f"min_robust={summary.get('min_robust_pass_probability_pct', summary.get('robust_pass_probability_pct'))} "
            f"mean_robust={summary.get('mean_robust_pass_probability_pct', 'n/a')} "
            f"max_loss_breach={summary.get('max_max_loss_breach_probability_pct', summary.get('max_loss_breach_probability_pct'))} "
            f"target_not_reached={summary.get('mean_target_not_reached_probability_pct', summary.get('target_not_reached_probability_pct'))} "
            f"deltas={artifact['deltas_vs_round24']}"
        )
        return 0

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


def _parse_ints(raw: str | None) -> list[int] | None:
    if raw is None or raw.strip() == "":
        return None
    return [int(token.strip()) for token in raw.split(",") if token.strip()]


def _parse_screen_candidate(tokens: Sequence[str]) -> Key:
    if len(tokens) == 1:
        return _parse_label(tokens[0])
    if len(tokens) == 2:
        return _parse_label(f"{tokens[0]}:{tokens[1]}")
    raise ValueError("--screen-candidate expects EA_ID SYMBOL or EA_ID:SYMBOL")


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
