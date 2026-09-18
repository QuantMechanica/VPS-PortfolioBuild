#!/usr/bin/env python3
"""Preregistration driver for QM-RESEARCH-2026-0002 (H-CW), run 2026-09-15.

Authority: OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-15 (interim
strategy-engineering build of the fully mechanized H-CW card into V5 EA
QM5_41475; build-only, no pipeline phase, no gate verdict).

Freezes the H-CW hypothesis via tools/strategy_farm/research/preregister.py
before any validation run. The mechanical spec is the mechanized card
H_CW_card.md itself. The shared research-source ledger append is intentionally
skipped (ledger_path=None): this build is confined to the kimi-hcw worktree
and must not write shared D:\\QM runtime state.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm" / "research"))

import preregister  # noqa: E402

ARTIFACT_DIR = REPO / "strategy-seeds" / "sources" / "QM-RESEARCH-2026-0002"
SPEC = ARTIFACT_DIR / "H_CW_card.md"

PARAMETER_RANGES = {
    "breakout_window_bars": [2, 4],
    "ema_period": [15, 30],
    "breakout_buffer_atr": [0.0, 0.05],
    "atr_period": [10, 20],
    "atr_stop_mult": [1.0, 1.0],
    "target_r": [1.5, 2.0],
    "time_stop_bars": [4, 8],
    "risk_per_trade_pct": [0.20, 0.50],
    "daily_stop_pct": [-1.0, -1.0],
    "weekly_stop_pct": [-2.0, -2.0],
    "shock_atr_mult": [1.5, 2.5],
    "spread_median_mult": [1.25, 1.75],
    "session_start_hour_utc": [13, 14],
    "session_end_hour_utc": [16, 17],
    "flatten_hour_utc": [20, 21],
    "friday_cutoff_hour_utc": [17, 18],
    "max_positions_total": [1, 3],
    "news_blackout_minutes": [0, 120],
}

record = preregister.build_preregistration(
    research_id="QM-RESEARCH-2026-0002",
    hypothesis=(
        "Session-flat cash-window index continuation (H-CW): equity-index CFDs "
        "(NDX/GDAXI/SP500) exhibit persistent intraday order flow during the "
        "cash-session overlap. Entering H1 breakouts of the first "
        "breakout_window_bars session bars, confirmed by position relative to a "
        "short EMA, strictly inside the 13-17 UTC cash window, with a 1.0xATR "
        "stop, a fixed R multiple target, a bounded time stop, shock/spread/news "
        "filters and a mandatory session-flat flatten, yields positive out-of-"
        "sample expectancy while reducing worst-day loss and breach probability "
        "relative to the farm's swing baseline."
    ),
    mechanical_spec=SPEC,
    parameter_ranges=PARAMETER_RANGES,
    discovery_sample={
        "campaign": "CAMP-2026-0001 deterministic OBSERVE projection of "
        "QuantMechanica backtest evidence (directive sec47/sec68 PHASE G)",
        "period": "2015-2020 in-sample economic runs (strategy taxonomy)",
        "instruments": ["NDX", "GDAXI", "SP500"],
    },
    validation_sample={
        "period": "2021-2024 held-out; never touched during discovery",
        "instruments": ["NDX", "GDAXI", "SP500"],
    },
    holdout_logic=(
        "Discovery consumed only the deterministic OBSERVE projection and "
        "2015-2020 in-sample runs. 2021-2024 is a frozen holdout: no metric, "
        "parameter selection, or kill decision may read it before the "
        "preregistered validation pass; any post-observation modification mints "
        "a new lineage version with a parent link (directive sec16 R-B)."
    ),
    expected_behaviour=(
        "At most one entry per symbol per day: roughly 18-22 trades/month/symbol, "
        "about 55-65 trades/month across the three index symbols, with at least "
        "12 active days/month. Zero overnight exposure (swap ~ 0, no gap-through-"
        "stop); daily circuit breaker -1.0% and weekly -2.0% stop trading; "
        "session-flat by flatten_hour_utc."
    ),
    success_criteria=(
        "OOS holdout net profit factor >= 1.20 after costs AND expectancy "
        ">= +0.10R/trade; Monte-Carlo P(hit -5% daily limit within 60d) <= 2% "
        "and simulated worst-day p95 <= 2.5% of equity at 0.25% risk; realized "
        "swap/rollover cost <= 10% of gross P&L; more than half of the +/-1-step "
        "parameter neighbourhood shows non-negative expectancy; every month has "
        ">= 8 active days; edge must not depend on a single symbol or single "
        "period."
    ),
    failure_criteria=(
        "Killed if: OOS holdout net profit factor < 1.20 after costs or "
        "expectancy < +0.10R/trade; Monte-Carlo P(hit -5% daily limit within "
        "60d) > 2% or simulated worst-day p95 > 2.5% of equity at 0.25% risk; "
        "realized swap/rollover cost > 10% of gross P&L; more than half of the "
        "+/-1-step parameter neighbourhood shows negative expectancy; any single "
        "month has < 8 active days; or session-flat index continuation does not "
        "reduce worst-day loss or breach probability relative to the swing "
        "baseline out of sample."
    ),
    known_risks=(
        "Symbol/period concentration (9-of-10 Q10 population is index intraday; "
        "edge may rest on one symbol or one regime); .DWX modeled spreads near "
        "zero make the spread-median filter data-sensitive; news blackout "
        "depends on the MT5 native calendar being present and fresh; UTC/broker "
        "session mapping drifts across DST unless anchored via QM_DSTAware; "
        "density target (>=12 active days/month) may fail in holiday-thinned "
        "months; moderate density sits near the scalp class boundary."
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
