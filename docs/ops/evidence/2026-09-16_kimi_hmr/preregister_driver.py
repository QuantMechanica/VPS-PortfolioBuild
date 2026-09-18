#!/usr/bin/env python3
"""Preregistration driver for QM-RESEARCH-2026-0006 (H-MR), run 2026-09-16.

Authority: OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-15 (interim
strategy-engineering build of the fully mechanized H-MR card into V5 EA
QM5_41476; build-only, no pipeline phase, no gate verdict).

Freezes the H-MR hypothesis via tools/strategy_farm/research/preregister.py
before any validation run. The mechanical spec is the mechanized card
H_MR_card.md itself. Unlike the H-CW build (whose id was campaign-minted and
whose ledger append was skipped), this id was minted by THIS lane through the
canonical research_source.py mint, so the canonical shared-ledger append for
the preregistration event is enabled (append-only ledger, canonical tooling
behaviour; the mint row is already present).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm" / "research"))

import preregister  # noqa: E402

ARTIFACT_DIR = REPO / "strategy-seeds" / "sources" / "QM-RESEARCH-2026-0006"
SPEC = ARTIFACT_DIR / "H_MR_card.md"
LEDGER = Path(r"D:\QM\reports\state\research_source_ledger.jsonl")

PARAMETER_RANGES = {
    "opening_range_bars": [2, 4],
    "ema_period": [15, 30],
    "breakout_buffer_atr": [0.0, 0.05],
    "atr_period": [10, 20],
    "atr_stop_mult": [0.5, 1.5],
    "min_target_r": [0.4, 0.8],
    "time_stop_bars": [4, 8],
    "risk_per_trade_pct": [0.20, 0.50],
    "daily_stop_pct": [-1.0, -1.0],
    "weekly_stop_pct": [-2.0, -2.0],
    "shock_atr_mult": [2.5, 4.0],
    "spread_median_mult": [1.25, 1.75],
    "session_start_hour_utc": [13, 14],
    "session_end_hour_utc": [16, 17],
    "flatten_hour_utc": [20, 21],
    "friday_cutoff_hour_utc": [17, 18],
    "max_positions_total": [1, 3],
    "news_blackout_minutes": [0, 120],
}

record = preregister.build_preregistration(
    research_id="QM-RESEARCH-2026-0006",
    hypothesis=(
        "Session-flat cash-open index mean reversion (H-MR): equity-index CFDs "
        "(NDX/GDAXI/SP500) over-extend at the cash open and revert toward the "
        "opening-auction reference when the first impulse fails. Entering H1 "
        "bars that pierce the opening-range extreme by breakout_buffer_atr x "
        "ATR and close back inside the range on the same bar, stretched vs a "
        "short EMA, strictly inside the 13-17 UTC cash window, with a stop "
        "beyond the failed-breakout extreme plus atr_stop_mult x ATR, a fixed "
        "opening-range-midpoint profit target gated by a min_target_r "
        "reward:risk eligibility floor, a bounded time stop, shock/spread/news "
        "filters and a mandatory session-flat flatten, yields positive out-of-"
        "sample expectancy while reducing worst-day loss and breach probability "
        "relative to the farm's swing baseline and complementing the H-CW "
        "continuation sibling (QM-RESEARCH-2026-0002)."
    ),
    mechanical_spec=SPEC,
    parameter_ranges=PARAMETER_RANGES,
    discovery_sample={
        "campaign": "Complement derivation to CAMP-2026-0001 (QM-RESEARCH-2026-0002 H-CW) under the OWNER interim strategy-engineering delegation",
        "period": "2018-2020 in-sample window (pilot fire count over a Dukascopy USATECHIDXUSD tick feed)",
        "instruments": ["NDX (USATECHIDXUSD proxy)", "GDAXI", "SP500"],
    },
    validation_sample={
        "period": "2021-2024 held-out; never touched during discovery",
        "instruments": ["NDX", "GDAXI", "SP500"],
    },
    holdout_logic=(
        "Discovery consumed only the H-CW campaign context, the pilot fire "
        "count on 2018-2020 data, and research-lane reasoning. 2021-2024 is a "
        "frozen holdout: no metric, parameter selection, or kill decision may "
        "read it before the preregistered validation pass; any post-observation "
        "modification mints a new lineage version with a parent link "
        "(directive sec16 R-B)."
    ),
    expected_behaviour=(
        "At most one entry per symbol per day. Pilot density on the NDX-class "
        "feed: roughly 2-5 trades/month/symbol, about 6-15 trades/month across "
        "the three index symbols, with at least 3 active days/month per symbol. "
        "Zero overnight exposure (swap ~ 0, no gap-through-stop); daily circuit "
        "breaker -1.0% and weekly -2.0% stop trading; session-flat by "
        "flatten_hour_utc."
    ),
    success_criteria=(
        "OOS holdout net profit factor >= 1.20 after costs AND expectancy "
        ">= +0.10R/trade; Monte-Carlo P(hit -5% daily limit within 60d) <= 2% "
        "and simulated worst-day p95 <= 2.5% of equity at 0.25% risk; realized "
        "swap/rollover cost <= 10% of gross P&L; more than half of the +/-1-step "
        "parameter neighbourhood shows non-negative expectancy; every month has "
        ">= 3 active days on a traded symbol; edge must not depend on a single "
        "symbol or single period."
    ),
    failure_criteria=(
        "Killed if: OOS holdout net profit factor < 1.20 after costs or "
        "expectancy < +0.10R/trade; Monte-Carlo P(hit -5% daily limit within "
        "60d) > 2% or simulated worst-day p95 > 2.5% of equity at 0.25% risk; "
        "realized swap/rollover cost > 10% of gross P&L; more than half of the "
        "+/-1-step parameter neighbourhood shows negative expectancy; any "
        "single month has < 3 active days on a traded symbol; or session-flat "
        "cash-open mean reversion does not reduce worst-day loss or breach "
        "probability relative to the swing baseline out of sample."
    ),
    known_risks=(
        "Pilot rests on ONE NDX-class proxy feed (not farm .DWX data); GDAXI/"
        "SP500 density is structural inference, not measured; the cash-open bar "
        "is naturally wide so the shock floor is data-sensitive across feeds; "
        "midpoint targets imply sub-1R rewards, so expectancy leans on hit rate "
        "and is sensitive to stop placement; news blackout depends on the MT5 "
        "native calendar being present and fresh; UTC/broker session mapping "
        "drifts across DST unless anchored via QM_DSTAware; density target may "
        "fail in holiday-thinned months; H-MR/H-CW correlation is unproven and "
        "the pair may concentrate risk in the same session window."
    ),
    parent_version=None,
)

result = preregister.write_preregistration(ARTIFACT_DIR, record, ledger_path=LEDGER)
print(json.dumps({
    "record_sha256": record["record_sha256"],
    "mechanical_spec_sha256": record["mechanical_spec_sha256"],
    "version": record["version"],
    "preregistration_path": result["preregistration_path"],
    "already_present": result["already_present"],
    "ledger_append": str(LEDGER),
}, indent=2, sort_keys=True))
