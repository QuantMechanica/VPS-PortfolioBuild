---
card_schema_version: 2
ea_id: QM5_41144
slug: eurusd-quarter-end-benchmark-fix-hedge-flow
type: strategy
status: DRAFT
g0_status: APPROVED
created: 2026-08-24
created_by: Codex
family: calendar_seasonality
mechanism: fx_benchmark_fix_rebalancing
source_id: MELVIN-PRINS-LONDON-FIX-2015
source_citation: "Michael Melvin and John Prins (2015), Equity Hedging and Exchange Rates at the London 4 p.m. Fix, Journal of Financial Markets 22, 50-72, DOI 10.1016/j.finmar.2014.11.001."
source_url: https://doi.org/10.1016/j.finmar.2014.11.001
target_symbols: [EURUSD.DWX]
primary_target_symbols: [EURUSD.DWX]
timeframe: M15
period: M15
single_symbol_only: true
declared_parameter_count: 3
expected_trade_frequency: UNKNOWN_Q02_MEASURES
ml_required: false
r1_track_record: TIER_A
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
r1_reasoning: "source_id present with a peer-reviewed, DOI-bearing citation (Melvin & Prins 2015, Journal of Financial Markets)."
r2_reasoning: "Fixed quarter-end calendar, exact 14:00 London trigger, index-return-sign direction rule, ATR stop and fixed flatten time are fully deterministic."
r3_reasoning: "EURUSD.DWX is a registered DWX carrier with M15 history testable on T1-T10."
r4_reasoning: "No ML/adaptive logic; one position per magic; card explicitly forbids re-entry, post-fix fade, overnight hold, grid, martingale, and averaging."
pipeline_phase: G0
g0_approval_reasoning: "G0 cross-approval Claude 2026-08-24: orthogonal wave 2 (Codex-built, Opus G0 review APPROVE_G0; docs/research/ORTHOGONAL_WAVE2_2026-08-24.md)"
last_updated: 2026-08-24
expected_trades_per_year_per_symbol: 100
---

# EURUSD.DWX Quarter-End Benchmark-Fix Hedge Flow

## Hypothesis

International equity managers adjust currency hedges at the London 16:00 benchmark fix. The paper finds that equity appreciation predicts associated currency depreciation before the end-of-month fix. This card uses completed GDAXI.DWX month-to-date return as the observable direction proxy for EURUSD.DWX on quarter-end dates. The economic mechanism is a mandatory benchmark hedge flow. The single-index proxy is a QM translation, not a paper result.

Refutation criterion: Refute if the pre-fix direction is not stable and positive after costs in post-2015 data, if the local-equity sign is wrong, or if any apparent return is earned outside the fixed window.

## Source

- Michael Melvin and John Prins (2015), Equity Hedging and Exchange Rates at the London 4 p.m. Fix, Journal of Financial Markets 22, 50-72, DOI 10.1016/j.finmar.2014.11.001.
- Primary source: https://doi.org/10.1016/j.finmar.2014.11.001
- OWNER-authorized bounded synthesis: `docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md` and ticket `rb-orthogonal-strategies`.
- No paper statistic, profitability estimate, or portfolio property is transferred to this card. Q02 and later gates measure the implementation.

## Market and timeframe

- Target symbol: `EURUSD.DWX` (registered DWX carrier).
- Literal execution timeframe: `M15`.
- Closed bars only; all cross-series reads require exact completed timestamps.
- Backtest risk mode is `RISK_FIXED > 0` with `RISK_PERCENT = 0`.

## Rules

### Entry

1. Eligible dates are only March, June, September and December month-ends, using a Europe/London holiday and DST-aware calendar.
2. At 14:00 London, compute completed month-to-date return of GDAXI.DWX from its prior-month final close to its latest completed M15 close.
3. If the return is positive, SELL EURUSD.DWX; if negative, BUY EURUSD.DWX; exact zero consumes the date flat.
4. Submit once at the first executable M15 bar at or after 14:00 London and persist the consumed date before submission.

### Exit

1. Install a hard stop 2.0 completed H1 ATR(14) from fill and never widen it.
2. Flatten on the final M15 bar ending at or before the 16:00 London fix; do not trade the post-fix reversal in this card.

### No-trade rules

- Fail closed on a missing/ambiguous holiday or DST calendar, missing local-index bars, stale news data, invalid ATR, symbol metadata, or excessive framework spread.
- Skip when a relevant high-impact event would overlap the owned window.
- No re-entry, post-fix fade, overnight hold, grid, martingale, averaging, scale-in, or direction fitting.

## Risk

- Size from actual fill to the initial hard stop using fixed baseline risk; reject invalid stop/tick-value/volume geometry.
- One position per symbol and magic. Daily and total account loss controls remain framework-authoritative.
- Kill-switch: when the framework kill switch, account-risk freeze, symbol-trading disable, or ownership-integrity fault is active, block entries and flatten owned exposure at the first safe executable point; broker protective stops remain active.
- No live use, `T_Live`, AutoTrading, deploy manifest, build, registry allocation, backtest enqueue, or portfolio admission is authorized by this draft.

## Declared parameters (3)

- `entry_lead_minutes` = `120`
- `atr_period_h1` = `14`
- `hard_stop_atr` = `2.0`

These are frozen drafting defaults. There is no undeclared optimizer surface; changing the rule clock, direction, carrier, event set, or lifecycle creates a new card.

## Duplicate and orthogonality guard

G0 must compare against QM5_10763, QM5_12973, QM5_20034 and QM5_32007; the pre-fix flow must not be confused with a post-fix fade.

This card is one carrier hypothesis inside a mechanism-class batch, not evidence that the four batch cards are four independent return sources. G0 must reject duplicates, and later portfolio gates alone may establish orthogonality.
