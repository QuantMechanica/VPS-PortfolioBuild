---
card_schema_version: 2
type: strategy
strategy_id: LIU-MTSM-2021_XNG_S02
variant_id: LIU-MTSM-2021_XNG_S02
source_id: LIU-MTSM-2021
ea_id: QM5_41244
slug: xng-tail-mtsm-s2
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41244_xng-tail-mtsm-s2_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41244_xng_tail_mtsm_s2_g0.md
source_approval: decisions/2026-08-31_xng_tail_mtsm_s2_source_approval.md
source_author: "Zhenya Liu; Shanglin Lu; Shixuan Wang"
source_authors: "Zhenya Liu; Shanglin Lu; Shixuan Wang"
source_citation: "Liu, Zhenya; Lu, Shanglin; and Wang, Shixuan (2021), Asymmetry, tail risk and time series momentum, International Review of Financial Analysis 78, 101938, DOI 10.1016/j.irfa.2021.101938."
source_citations:
  - type: peer_reviewed_complete_read_packet
    citation: "Liu, Z.; Lu, S.; and Wang, S. (2021). Asymmetry, tail risk and time series momentum. International Review of Financial Analysis 78, 101938."
    location: "strategy-seeds/sources/LIU-MTSM-2021/source.md"
    quality_tier: A_governed_complete
    role: thirty_day_momentum_five_day_partial_moments_eighty_percentile_regions_and_mtsm_s2_map
  - type: governed_source_approval
    citation: "QuantMechanica XNG Tail-MTSM S2 carrier-port source approval."
    location: "decisions/2026-08-31_xng_tail_mtsm_s2_source_approval.md"
    quality_tier: internal_governed_complete
    role: xng_port_risk_lifecycle_dedup_and_no_refit_boundary
strategy_mechanic: xng-d1-thirty-return-momentum-five-return-upper-lower-partial-moment-separate-80th-percentile-mtsm-s2-target-map-fixed-risk-friday-packages
sources:
  - "[[sources/LIU-MTSM-2021]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/asymmetric-partial-moments]]"
indicators:
  - "[[indicators/completed-d1-return-arithmetic]]"
  - "[[indicators/nearest-rank-order-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, time-series-momentum, asymmetric-tail-state, symmetric-long-short, low-frequency, friday-flat, atr-hard-stop]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412440000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_mtsm_s2_target
expected_trade_frequency: "Approximately 20-52 completed XNG positions per full post-warm-up year from D1 state changes plus framework Friday packages; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 30
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CARRIER_AND_SIZING_TRANSLATION
r1_reasoning: "A governed complete-read packet traces to a named-author, DOI-bearing, peer-reviewed IRFA paper and preserves the exact partial-moment MTSM-S2 state machine. The source is a Chinese commodity-futures portfolio study, not an XNG or CFD result; the carrier and fixed-risk translations are explicit."
r2_mechanical: PASS
r2_reasoning: "Exact D1 clock, completed returns, lookbacks, partial-moment arithmetic, excluded current observation, nearest-rank percentiles, S2 map, consumed label, no same-label reversal, fixed risk, frozen stop, spread ceiling, stale repair, and Friday closure are deterministic and locked."
r3_data_available: PASS
r3_qualification: COMMODITY_FUTURES_TO_XNG_CFD_PORT_AND_SESSION_RISK
r3_reasoning: "Registered XNGUSD.DWX D1 history and native MT5 OHLC, ATR, quotes, positions, deals, and persistent state provide every runtime input. Carrier transport, CFD basis, D1 labels, gaps, spreads, and Friday packaging remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed closes, arithmetic, sorting, nearest-rank order statistics, ATR risk control, quotes, positions, deals, and persistent state; no trained signal, banned signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid."
parameters_to_test: "Locked Q02 baseline only: 30 completed simple D1 returns; five-return upper/lower partial moments; 252 older observations; separate nearest-rank 80th percentiles; exact MTSM-S2 map; ATR(20,D1)*3.0 frozen stop; eight-day stale repair; 1500-point spread ceiling; current news PRE30_POST30/DXZ; Friday close broker hour 21."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_PRE30_POST30
news_compliance_profile: QM_NEWS_COMPLIANCE_DXZ
friday_close_enabled: true
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a second XNG return driver that is mechanically unrelated to certified QM5_12567: asymmetric squared-return tail states can override, reverse, or flatten a 30-D1 momentum target, whereas 12567 is a long-only cumulative-RSI2 pullback under a 200-D1 trend state. Verify exact completed-data indexing, percentile exclusion, S2 map, one-shot label, fixed risk, frozen stop, transition lifecycle, and Friday packages. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, completed_d1_only, partial_moment_arithmetic, percentile_no_leakage, exact_s2_map, restart_safe_attempt, risk_mode_dual, hard_stop_present, friday_close, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "Current OWNER mission plus decisions/2026-08-31_qm5_41244_xng_tail_mtsm_s2_g0.md: R1 passes with the governed complete-read Liu-Lu-Wang packet and explicit XNG/fixed-risk translation; R2 locks the full state and lifecycle; R3 uses registered native XNG D1 with carrier/session/CFD risk; R4 is deterministic native arithmetic only. Canonical dedup found only the intended WTI parent copies, manually resolved as a locked carrier port distinct from QM5_12567."
---

# QM5_41244 XNG Tail-Managed Time-Series Momentum S2

## Hypothesis

Commodity time-series momentum can reverse when recent upside and downside
return energy becomes asymmetric. Liu, Lu, and Wang separate recent returns
into upper and lower partial moments and use their joint tail state to override
or neutralize a base momentum direction. This card transports that exact
MTSM-S2 state machine to natural gas without refitting its signal parameters.

The candidate adds a second XNG return driver to the certified
XAU/SP500/NDX/XNG book. It is not evidence of profitability, low correlation,
or portfolio value. Only unchanged downstream gates may establish those
outcomes.

## Source Traceability And Claim Boundary

The bounded source is the complete-read packet
`strategy-seeds/sources/LIU-MTSM-2021/source.md`, tracing to Liu, Lu, and Wang
(2021), *International Review of Financial Analysis* 78, article 101938, DOI
`10.1016/j.irfa.2021.101938`.

The source supports 30-day base momentum, five-day upper/lower partial moments,
recursive 80th-percentile tail regions, and the MTSM-S2 action map. It studies
a diversified Chinese commodity-futures universe with volatility targeting,
not natural gas, a single CFD, V5 fixed-dollar sizing, or Friday-flat packages.
No source performance statistic is imported as an XNG expectation.

## Rules

On each new exact `XNGUSD.DWX` D1 bar, use completed closes only. Sum the latest
30 simple returns, compute the latest five-return upper and lower partial
moments, compare each to its separate no-lookahead nearest-rank 80th percentile
from 252 older observations, and apply:

```text
both tails:      FLAT
LPM tail only:   LONG
UPM tail only:   SHORT
neither tail:    LONG when the 30-return sum is positive, SHORT otherwise
```

A valid nonzero flat-position target consumes the D1 label before quote,
spread, ATR, sizing, or submission checks. Never retry the consumed label.

## Markets And Timeframe

- Exact host and traded symbol: `XNGUSD.DWX`.
- Host, signal, ATR, and execution timeframe: D1.
- Symbol slot: 0; intended magic: `412440000`.
- Expected cadence: approximately 20-52 completed packages/year; Q02 must
  prove at least five in every full scored year.

## 4. Entry Rules

1. Require exact `XNGUSD.DWX`, D1, slot 0, EA ID 41244, and every locked input.
2. Run target calculation only for a new completed-data D1 decision.
3. Load positive finite completed closes sufficient for 30 momentum returns,
   the current five-return partial moments, and 252 older five-return windows.
4. For every return `r`, UPM contribution is `r*r` only when `r>0`; LPM
   contribution is `r*r` only when `r<0`; all other contributions are zero.
   Divide each five-observation sum by exactly five.
5. Exclude the current partial-moment observation. Sort the 252 older UPM and
   LPM samples separately and select each nearest-rank 80th percentile. A
   current value equal to or above its reference is in the tail.
6. Apply the exact S2 map above. Fail closed on invalid history, price,
   arithmetic, nonpositive reference, or unknown state.
7. Repair malformed owned exposure first. A same-side position is retained.
   An opposed position is closed and cannot reverse on the same D1 label; the
   new target must persist to a later label.
8. If flat with a nonzero target, persist the D1 attempt before quote, spread,
   ATR, sizing, or order submission. Reject crossed/negative quotes and a
   genuinely positive spread above 1,500 points; modeled zero spread is valid.
9. Attach one frozen normalized `3.0 * ATR(20,D1)` broker hard stop and no
   target. Use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`.

## 5. Exit Rules

- On a new D1 decision, close when state is unknown, target is flat, or target
  opposes the owned side.
- Close duplicate, wrong-symbol, wrong-magic, invalid-side, invalid-volume,
  invalid-open-price, or stopless owned exposure immediately.
- Close after eight elapsed calendar days as a survivor repair.
- Framework Friday close at broker hour 21 remains authoritative.
- No same-label reversal, target, trailing stop, break-even move, partial exit,
  or signal-magnitude sizing.

## 6. Filters (No-Trade Module)

- Exact symbol/timeframe/slot/EA and exact parameter locks.
- Current news temporal/compliance axes are `PRE30_POST30` / `DXZ`; legacy news
  mode is OFF.
- History, return, partial-moment, percentile, state, quote, spread, ATR,
  sizing, stop, position, and attempt checks fail closed.
- Framework kill switch, news gate, connection protection, and Friday closure
  remain authoritative.

## 7. Trade Management Rules

- Own at most one exact-carrier position under magic `412440000`.
- Run malformed-state and stale repair before entry-only gates.
- Preserve the original broker hard stop; never widen, trail, or remove it.
- Persist the last attempted D1 label across restart. A stop-out, rejection,
  failed sizing, or failed submission never retries that label.
- No reverse on the label used to close an opposed position.
- No pending order, scale-in, pyramid, grid, martingale, adaptive PnL rule,
  external runtime input, trained signal, or portfolio-state dependency.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| parameter | value | role |
|---|---:|---|
| `strategy_momentum_days` | 30 | base simple-return sum |
| `strategy_partial_moment_days` | 5 | UPM/LPM window |
| `strategy_percentile_history` | 252 | older reference observations |
| `strategy_tail_percentile` | 80.0 | separate nearest-rank references |
| `strategy_atr_period` | 20 | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_max_hold_days` | 8 | survivor repair only |
| `strategy_max_spread_points` | 1500 | entry ceiling |

Changing the carrier, lookbacks, percentile method, tail equality, target map,
risk, stop, spread, lifecycle, or news/Friday behavior requires a new source
decision and card. There is no after-result rescue parameter.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xng_tail_mtsm_s2_preallocation_dedup_20260831.json` found no
exact identity across 4,743 registry rows, 1,381 cards, and 45 Strategy Wiki
nodes. Its two fuzzy matches are the approved and flat card copies of the
intended `QM5_13108` WTI parent.

This is a locked XNG carrier port. No XNG card uses upper/lower partial moments
plus the four-region S2 map. Certified `QM5_12567` instead buys cumulative-RSI2
pullbacks inside a 200-D1 uptrend and never targets short from an asymmetric
tail state.

Verdict:
`FUZZY_MATCH_RESOLVED_LOCKED_XNG_CARRIER_PORT_DISTINCT_FROM_QM5_12567`.

## Risk

This is a high-risk transport. The source's diversified Chinese-futures
evidence, volatility targeting, and recursive history do not establish XNG
CFD economics. Carrier basis, natural-gas gaps, D1 labels, fixed risk, a
bounded 252-observation reference, spreads, and Friday packaging can eliminate
the effect. `expected_pf=1.01` and cadence are queue-ordering priors only.

Q02 must retire the unchanged baseline on zero positions, fewer than five in
any full scored year, nonpositive governed economics, invalid risk mode,
future leakage, wrong partial-moment arithmetic, wrong percentile exclusion,
wrong S2 action, duplicate attempt, same-label reversal, missing stop,
malformed lifecycle, or nondeterminism. Q09 alone may measure overlap with
`QM5_12567` and the certified book.

Only one `RISK_FIXED` backtest setfile is authorized. No live, demo, shadow,
stress, or optimization preset; AutoTrading action; `T_Live`; deploy or live
manifest; portfolio-gate edit; portfolio admission; decorrelation claim; or
correlation waiver is authorized.

## Framework Alignment

- no_trade: exact host, slot, parameters, persistent attempt, framework kill
  switch, news, Friday, and fail-closed validation.
- trade_entry: completed-data 30/5/252/80 S2 target, no-lookahead percentile,
  quote/spread/ATR gates, fixed-risk request, and one-shot D1 label.
- trade_management: malformed-state repair plus new-D1 flat/opposed closure,
  same-side retention, no same-label reversal, and eight-day stale repair.
- trade_close: owned tickets close through the framework transaction manager;
  the frozen broker hard stop and framework Friday closure are backstops.

## Falsification And Pipeline Status

Passing Q02 would establish only executable baseline evidence. It would not
validate source-to-XNG transport, profitability, robustness, low correlation,
or portfolio admission.

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-31 | APPROVED_SOURCE | `decisions/2026-08-31_xng_tail_mtsm_s2_source_approval.md` |
| G0 | 2026-08-31 | APPROVED | `decisions/2026-08-31_qm5_41244_xng_tail_mtsm_s2_g0.md` |
| Q01 | 2026-08-31 | PENDING | build not yet recorded |
| Q02 | 2026-08-31 | NOT_ENQUEUED | requires strict Q01 PASS and clear CPU window |
