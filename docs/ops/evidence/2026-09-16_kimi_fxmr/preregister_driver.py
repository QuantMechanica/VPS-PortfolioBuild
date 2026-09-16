#!/usr/bin/env python3
"""Preregistration driver for QM-RESEARCH-2026-0005 (H-FXMR), run 2026-09-16.

Authority: interim OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-16
(strategy-engineering build of the fully mechanized H-FXMR card into V5 EA
QM5_41477; build-only, no pipeline phase, no gate verdict).

Freezes the H-FXMR hypothesis via tools/strategy_farm/research/preregister.py
before any validation run. The mechanical spec is the mechanized card
H_FXMR_card.md itself. The shared research-source ledger append is
intentionally skipped (ledger_path=None): this build is confined to the
kimi-fxmr worktree and must not write shared D:\\QM runtime state.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm" / "research"))

import preregister  # noqa: E402

ARTIFACT_DIR = REPO / "strategy-seeds" / "sources" / "QM-RESEARCH-2026-0005"
SPEC = ARTIFACT_DIR / "H_FXMR_card.md"

PARAMETER_RANGES = {
    "stretch_bars": [2, 4],
    "ema_period": [10, 20],
    "stretch_atr_mult": [0.5, 1.5],
    "atr_period": [10, 20],
    "stop_buffer_atr": [0.1, 0.5],
    "max_stop_atr": [1.5, 2.5],
    "target_r": [1.0, 1.5],
    "time_stop_bars": [8, 16],
    "risk_per_trade_pct": [0.20, 0.50],
    "daily_stop_pct": [-1.0, -1.0],
    "weekly_stop_pct": [-2.0, -2.0],
    "shock_atr_mult": [1.5, 2.5],
    "spread_median_mult": [1.25, 1.75],
    "london_start_hour_utc": [7, 8],
    "london_end_hour_utc": [10, 12],
    "ny_start_hour_utc": [12, 13],
    "ny_end_hour_utc": [15, 16],
    "london_flat_min_utc": [660, 720],
    "ny_flat_min_utc": [960, 1020],
    "friday_cutoff_min_utc": [780, 900],
    "skip_first_minutes": [0, 30],
    "max_positions_total": [2, 4],
    "max_trades_per_day": [2, 6],
    "news_blackout_minutes": [0, 120],
}

record = preregister.build_preregistration(
    research_id="QM-RESEARCH-2026-0005",
    hypothesis=(
        "Session-flat FX session mean reversion (H-FXMR): major FX pairs "
        "(EURUSD/GBPUSD/USDJPY) exhibit short-horizon overextension-reversion "
        "during the London (07-11 UTC) and New York (12-16 UTC) session "
        "windows. Entering on the M15 close back through a short EMA after an "
        "N-bar stretch (>= stretch_bars consecutive same-direction closes or "
        "close-vs-EMA distance > stretch_atr_mult x ATR), in the reversion "
        "direction, with the stop at the stretch extreme plus an ATR buffer, "
        "a fixed 1.0-1.5R target, a bounded time stop, a per-day trade cap "
        "and a mandatory session-flat flatten, yields positive out-of-sample "
        "expectancy while reducing worst-day loss and breach probability "
        "relative to the farm's FX swing baseline, with zero overnight "
        "exposure (swap ~ 0)."
    ),
    mechanical_spec=SPEC,
    parameter_ranges=PARAMETER_RANGES,
    discovery_sample={
        "campaign": "deterministic universe map of the farm's exercised universe "
        "(14,939 ea_id x symbol pairs; directive sec19/sec47 white-space projector)",
        "period": "farm work_items at Q02+ through 2026-09-16",
        "instruments": ["EURUSD", "GBPUSD", "USDJPY"],
    },
    validation_sample={
        "period": "2021-2024 held-out; never touched during discovery",
        "instruments": ["EURUSD", "GBPUSD", "USDJPY"],
    },
    holdout_logic=(
        "Discovery consumed only the deterministic universe map projection. "
        "2021-2024 is a frozen holdout: no metric, parameter selection, or "
        "kill decision may read it before the preregistered validation pass; "
        "any post-observation modification mints a new lineage version with a "
        "parent link (directive sec16 R-B)."
    ),
    expected_behaviour=(
        "Bounded by one entry per symbol per session window (2 windows/day) "
        "and the max_trades_per_day cap: roughly 18-28 trades/month/symbol, "
        "about 55-85 trades/month across the three FX symbols, with at least "
        "15 active days/month. Zero overnight exposure (swap ~ 0, no "
        "gap-through-stop); daily circuit breaker -1.0% and weekly -2.0% stop "
        "trading; session-flat by london_flat_min_utc / ny_flat_min_utc."
    ),
    success_criteria=(
        "OOS holdout net profit factor >= 1.20 after costs AND expectancy "
        ">= +0.10R/trade; Monte-Carlo P(hit -5% daily limit within 60d) <= 2% "
        "and simulated worst-day p95 <= 2.5% of equity at 0.25% risk; realized "
        "swap/rollover cost <= 10% of gross P&L; more than half of the "
        "+/-1-step parameter neighbourhood shows non-negative expectancy; "
        "every month has >= 10 active days; edge must not depend on a single "
        "symbol or a single session window."
    ),
    failure_criteria=(
        "Killed if: OOS holdout net profit factor < 1.20 after costs or "
        "expectancy < +0.10R/trade; Monte-Carlo P(hit -5% daily limit within "
        "60d) > 2% or simulated worst-day p95 > 2.5% of equity at 0.25% risk; "
        "realized swap/rollover cost > 10% of gross P&L; more than half of "
        "the +/-1-step parameter neighbourhood shows negative expectancy; any "
        "single month has < 10 active days; the per-day trade cap must be "
        "raised above 6 to clear the activity floor; or session-flat FX mean "
        "reversion does not reduce worst-day loss or breach probability "
        "relative to the FX swing baseline out of sample."
    ),
    known_risks=(
        "White-space motivation is not a pass record (universe map covers the "
        "exercised universe only; FX session rows there are nearly empty); FX "
        "news flow (ECB/BoE/BoJ/Fed) can gap stops inside a window; M15 mean "
        "reversion is regime-sensitive on trending macro days; .DWX modeled "
        "spreads near zero make the spread-median filter data-sensitive; news "
        "blackout depends on the MT5 native calendar being present and fresh; "
        "UTC/broker session mapping drifts across DST unless anchored via "
        "QM_DSTAware; high density sits near the scalp class boundary and is "
        "capped by max_trades_per_day."
    ),
    parent_version=None,
)

result = preregister.write_preregistration(ARTIFACT_DIR, record, ledger_path=None)
print(json.dumps({
    "record_sha256": record["record_sha256"],
    "mechanical_spec_sha256": record["mechanical_spec_sha256"],
    "version": record["version"],
    "preregistration_path": result["preregistration_path"],
    "already_present": result["already_present"],
    "ledger_append": "SKIPPED (worktree-confined build; no shared runtime state writes)",
}, indent=2, sort_keys=True))
