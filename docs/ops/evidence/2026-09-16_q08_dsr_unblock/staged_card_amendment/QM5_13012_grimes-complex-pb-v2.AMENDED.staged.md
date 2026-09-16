---
ea_id: QM5_13012
slug: grimes-complex-pb-v2
strategy_id: exit-surgery-10911
type: strategy
source_id: exit-surgery-10911
source_citation: "Adam H. Grimes, How to trade Complex Consolidations, 2014-11-06, https://www.adamhgrimes.com/trade-complex-consolidations/; Fundamental Trading Patterns, https://www.adamhgrimes.com/fundamental-trading-patterns/"
sources:
  - "[[sources/adam-grimes-blog]]"
concepts:
  - "[[concepts/complex-pullback]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
target_symbols: [GDAXI.DWX]
period: H1
expected_trade_frequency: "Second-leg pullback continuation on GDAXI H1; conservative estimate 20-45 trades/year/symbol. Surgery v2 tests the GDAXI sleeve with extended max-hold ceiling."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-04
g0_approval_reasoning: "Tier-A exit-surgery v2 (docs/research/EXIT_SURGERY_SCAN_2026-07-04.md, §3.4). Parent QM5_10911 is GDAXI live sleeve with hold-gradient WR 27%->72% (+45pp). Single surgical parameter change: strategy_max_hold_bars 30->60 (30h->60h). R1-R4 inherited from parent (all PASS). Entry logic, exits, stop, sizing unchanged. Pipeline judges the delta."
---

# Grimes Complex Pullback Second-Leg Continuation v2 (exit surgery)

## Source
- Source: [[sources/adam-grimes-blog]]
- Citation: Adam H. Grimes, "How to trade Complex Consolidations", 2014-11-06, https://www.adamhgrimes.com/trade-complex-consolidations/
- Supplemental: "Fundamental Trading Patterns", https://www.adamhgrimes.com/fundamental-trading-patterns/
- Source location: Complex consolidation article defines a trend, first pullback, failed first resumption, second pullback leg, and eventual with-trend break.

## Mechanics

### Entry
- Evaluate on H1 close.
- Long:
  - Trend filter: EMA(50) slope positive and Close > EMA(50).
  - Thrust: a 20-bar high occurred within the last 20 bars with range >= 1.0 * ATR(14).
  - First pullback: price closes down at least 0.8 * ATR(14) from the thrust high but remains above EMA(50).
  - Failed first resumption: price closes above the prior bar high, then within the next 5 bars closes back below that trigger bar low.
  - Second-leg trigger: after the failure, enter long when price breaks above the highest high of the failed resumption leg.
- Short:
  - Mirror the rules for a downtrend, first bounce, failed downside resumption, and break below the failed leg low.

### Exit
- Target 1 = 1.5R.
- Exit on close through EMA(20) against the trade after entry.
- **v2 surgical change: Time exit after 60 H1 bars (60 hours).** Parent used 30 bars (30h). See Exit Surgery Provenance below.

### Stop Loss
- Long stop below the second pullback swing low minus 0.2 * ATR(14).
- Short stop above the second pullback swing high plus 0.2 * ATR(14).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default percent risk if approved.

### Additional filters
- Do not take a complex pullback if the second leg closes beyond EMA(50), because trend integrity is suspect.
- Require at least 8 bars between original thrust and final entry to avoid duplicating the simple pullback card.
- One active position per symbol/magic.

## Concepts
- [[concepts/complex-pullback]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and full article URLs are cited; same source as parent QM5_10911. |
| R2 Mechanical | PASS | Single surgical parameter change (strategy_max_hold_bars 30->60); all entry/exit/stop mechanics retained verbatim from parent. |
| R3 DWX-testbar | PASS | GDAXI.DWX H1 covered in the .DWX history matrix; same symbol as the parent's Q08 evidence run. |
| R4 No ML | PASS | Fixed rules; no ML/adaptive/grid/martingale. Unchanged from parent. |

## R3
Surgery scope: GDAXI.DWX H1 only. Parent QM5_10911 supports EURUSD/GBPUSD/XAUUSD/GER40 basket; v2 targets only the GDAXI sleeve where the hold-gradient evidence was measured.

## Pipeline history
- G0: 2026-07-04, APPROVED (exit-surgery classification).

## Exit Surgery Provenance

**Scan:** `docs/research/EXIT_SURGERY_SCAN_2026-07-04.md`, §3.4 (QM5_10911/GDAXI).

**Evidence:**
- 296 trades, avg hold 12.5h, exit dist: TIME_MGMT 44%, SL 21%, TP 25%, OTHER 9%.
- Hold-time gradient (WR): 27% (<2h) → 32% (2-8h) → 45% (8-24h) → **72% (1-3d)**.
- The 1-3d bucket (43 trades, WR 72%, avg net +487): TIME_MGMT×29/43 (67%) = trades killed at the 30h ceiling.
- WR +45pp gradient and avg_net delta of +808 confirm the 30h ceiling amputates winners.

**Killer mechanic:** `strategy_max_hold_bars = 30` on H1 = 30h hard ceiling. Trades that need 30-72h to mature are forced out at 30h while in profit.

**Surgical delta:** `strategy_max_hold_bars` 30 → 60 (60h hard ceiling). All other parameters and logic unchanged.

**Precedent:** Same class as QM5_12989/12990 (10940/10939 surgery pairs). Pipeline judges the delta; live swap only after Q08 PASS_SOFT + portfolio re-admission + OWNER manifest.

## Related strategies
- [[strategies/QM5_10911_grimes-complex-pb]] - parent EA (GDAXI live sleeve, Q08 FAIL_SOFT).
- [[strategies/QM5_10910_grimes-pullback]] - simpler first-leg continuation entry.

## Lessons Learned
- TBD during pipeline run.

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact GDAXI.DWX/H1 configuration used by Q08 (set file `QM5_13012_grimes-complex-pb-v2_GDAXI.DWX_H1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_13012",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "13012",
    "qm_friday_close_enabled": "true",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "0",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "14",
    "strategy_ema_exit_period": "20",
    "strategy_ema_trend_period": "50",
    "strategy_failure_window_bars": "5",
    "strategy_max_hold_bars": "60",
    "strategy_min_thrust_to_entry_bars": "8",
    "strategy_pullback_atr_mult": "0.80",
    "strategy_stop_buffer_atr_mult": "0.20",
    "strategy_target_r_mult": "1.50",
    "strategy_thrust_lookback_bars": "20",
    "strategy_thrust_prior_high_bars": "20",
    "strategy_thrust_range_atr_mult": "1.00"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "a8cd800abedf28d015f40b4a15cc78450258c9fba2e63bc8654d194d2484cae2",
  "symbol": "GDAXI.DWX",
  "timeframe": "H1"
}
```
