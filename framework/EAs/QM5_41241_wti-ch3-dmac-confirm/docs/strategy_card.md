---
card_schema_version: 2
type: strategy
strategy_id: SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026_S01
variant_id: SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026_S01
source_id: SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026
ea_id: QM5_41241
slug: wti-ch3-dmac-confirm
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41241_wti-ch3-dmac-confirm_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41241_wti_ch3_dmac_confirmation_g0.md
source_approval: decisions/2026-08-31_wti_ch3_dmac_confirmation_source_approval.md
source_author: "Andrew C. Szakmary; Qian Shen; Subhash C. Sharma"
source_authors: "Andrew C. Szakmary; Qian Shen; Subhash C. Sharma"
source_citation: "Szakmary, Shen, and Sharma (2010), Trend-following trading strategies in commodity futures: A re-examination, Journal of Banking & Finance 34(2), 409-426, DOI 10.1016/j.jbankfin.2009.08.004."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Szakmary, A. C., Shen, Q., and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination. Journal of Banking & Finance 34(2), 409-426."
    location: "DOI 10.1016/j.jbankfin.2009.08.004; complete-manuscript review preserved by strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/source.md"
    quality_tier: A
    role: monthly_commodity_channel_and_dual_moving_average_rule_families_with_crude_oil_membership
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI CH3 and DMAC confirmation extraction."
    location: "strategy-seeds/sources/SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026/source.md"
    quality_tier: internal_governed_complete
    role: exact_month_endpoints_and_conjunction_risk_lifecycle_boundary
strategy_mechanic: latest-completed-wti-month-end-strict-prior-three-close-channel-breakout-and-same-direction-one-over-six-2p5pct-neutral-band-confirmation-monthly-renewal
sources:
  - "[[sources/SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026]]"
concepts:
  - "[[concepts/commodity-trend-following]]"
  - "[[concepts/month-end-price-channel]]"
  - "[[concepts/monthly-neutral-band]]"
indicators:
  - "[[indicators/completed-month-end-close]]"
  - "[[indicators/price-channel]]"
  - "[[indicators/arithmetic-mean-neutral-band]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, monthly-trend, price-channel, neutral-band-confirmation, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412410000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "Approximately 5-8 completed WTI positions per full year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_UNTESTED_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK
r1_reasoning: "One complete-reviewed, named-author, DOI-bearing, peer-reviewed commodity-futures study supplies both monthly parent rule families and explicit crude-oil membership. The AND conjunction and Darwinex CFD port are untested QM translations."
r2_mechanical: PASS
r2_reasoning: "Broker-month clock, exact six consecutive completed endpoints, strict prior-three channel, six-close arithmetic mean, exact 2.5% band, AND agreement, consumed attempt, fixed risk, hard stop, spread, and monthly renewal are deterministic and locked."
r3_data_available: PASS
r3_qualification: CONTINUOUS_FUTURES_CFD_BASIS_AND_MONTH_END_RECONSTRUCTION_RISK
r3_reasoning: "Registered XTIUSD.DWX D1 history plus native broker calendar, quote, position, deal, and terminal state supplies every runtime input. Futures roll, financing, gaps, history, and CFD basis remain binding."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed timestamps and closes, extrema, fixed arithmetic, comparisons, ATR risk controls, quotes, and execution state; no trained signal, prohibited runtime feed, grid, martingale, scale-in, or pyramid."
parameters_to_test: "Locked Q02 baseline only: six exact consecutive completed month ends; strict prior-three close channel; six-close arithmetic mean; symmetric 2.5% band; same-direction AND agreement; 300 D1 history bars; ATR(20)*4.0 frozen stop; 40-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED_PENDING
force_build: true
review_focus: "Falsify a direct-WTI monthly trend-consensus sleeve outside the certified XAU/SP500/NDX/XNG book. Verify six consecutive completed endpoints, strict CH3 state, six-close mean, exact band, AND relation, consumed month, fixed risk, frozen stop, and next-month renewal. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, six_consecutive_completed_month_ends, no_current_month_price, strict_prior_three_channel, arithmetic_six_close_mean, symmetric_2p5pct_band, same_direction_and_confirmation, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, continuous_futures_cfd_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41241_wti_ch3_dmac_confirmation_g0.md: R1 passes with one complete-reviewed peer-reviewed commodity-trend source supplying both parent rule families and crude-oil membership, with explicit conjunction/CFD translation risk; R2 locks calendar, endpoints, channel, mean, band, AND state, attempt, risk, stop, spread, and lifecycle; R3 binds the rule to registered WTI D1 history; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup is clean, and fixed fixtures prove a decision surface distinct from both built parents."
---

# QM5_41241 WTI CH3 / DMAC Confirmation

## Hypothesis

A WTI monthly closing breakout may carry stronger trend information when the
same completed close also lies outside a slower six-month neutral band. This
candidate trades only the intersection of the source's three-month closing
channel and one-over-six-month 2.5% DMAC states, then renews after one broker
month.

This is a direct WTI structural diversification candidate outside the
certified XAU/SP500/NDX/XNG carrier set. It is not evidence of profitability,
low correlation, or portfolio value. Only unchanged downstream gates may
establish those outcomes.

## Source Traceability And Claim Boundary

The source lineage is Szakmary, Shen, and Sharma (2010),
"Trend-following trading strategies in commodity futures: A re-examination,"
*Journal of Banking & Finance* 34(2), 409-426, DOI
`10.1016/j.jbankfin.2009.08.004`.

Complete-read evidence and the bounded extraction are preserved in:

- `strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/source.md`, SHA-256
  `9E082864F7F6C85E88720FC7DC24674A8BE77C68C3479D441C7709B726691727`;
- `strategy-seeds/sources/SZAKMARY-WTI-DMAC16-2010/source.md`, SHA-256
  `3F27E3A48EBA504DA98FAD487B8F0DA3135E40D4BC15B19C6156A286E987BCC6`;
  and
- `strategy-seeds/sources/SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026/source.md`.

The paper supplies the monthly channel and dual-moving-average families and
includes crude oil. It does not test their AND intersection, a single WTI
zero comparison, Darwinex CFD data, fixed-dollar risk, the ATR stop, the
operational attempt ledger, or book correlation. No source statistic is an
expected result for this card.

## Rules

On the first executable D1 tick after a genuine `XTIUSD.DWX` broker-month
transition, close the prior package and consume the new `yyyymm` attempt.
Reconstruct exactly six consecutive completed broker-month closes, newest
first, without current-month leakage.

```text
channel = BUY  if C0 > max(C1,C2,C3)
          SELL if C0 < min(C1,C2,C3)
          FLAT otherwise

mean6 = (C0+C1+C2+C3+C4+C5)/6
dmac  = BUY  if C0 > mean6*1.025
        SELL if C0 < mean6*0.975
        FLAT otherwise

signal = BUY  only when channel=BUY  and dmac=BUY
         SELL only when channel=SELL and dmac=SELL
         FLAT otherwise
```

Every comparison is strict. Missing endpoints, invalid arithmetic,
disagreement, equality, or either flat state consumes the month without an
entry. An accepted position carries one frozen hard stop and closes at the
next broker-month boundary.

## Markets And Timeframe

- Exact host and traded symbol: `XTIUSD.DWX`.
- Host, signal, and execution timeframe: D1.
- Symbol slot: 0; registered magic: `412410000`.
- Decision cadence: once per broker month.
- Expected cadence: approximately 5-8 completed packages per full year; Q02
  must prove at least five in every full scored year.

## 4. Entry Rules

1. Run only after a new D1 bar is observed and the current and prior D1 bar
   belong to consecutive different broker months.
2. Before any fallible entry gate, persist the current `yyyymm` attempt. Deal
   history and the persistent state must both prevent restart re-entry.
3. Read a bounded 300-bar D1 buffer and collect the final completed close of
   each of the latest six consecutive completed broker months. Require a
   current-month bar confirming completion, distinct month keys, ordered
   timestamps, and positive finite values.
4. Compute the strict CH3 and DMAC states exactly as specified under Rules.
   Enter only on equal nonzero states.
5. Reject invalid/crossed quotes, a negative spread, or a genuinely positive
   spread above 1,500 points. A modeled zero spread is valid.
6. Use BUY at the current ask or SELL at the current bid. Attach one frozen
   `4.0 * ATR(20,D1)` normalized broker hard stop. No take-profit is allowed.
7. Risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1` in the backtest preset. Signal magnitude does not size
   risk.

## 5. Exit Rules

- At the first executable D1 tick in the next broker month, close the old
  package before evaluating the new entry-only gates, even if direction would
  repeat.
- Close a survivor at 40 elapsed calendar days.
- Close duplicate, wrong-symbol, invalid-side, wrong-magic, or stopless owned
  exposure immediately.
- The frozen broker stop remains active intramonth.
- No target, trailing stop, break-even move, partial exit, intramonth signal,
  or discretionary exit is permitted.

## 6. Filters (No-Trade Module)

- Exact symbol/timeframe/slot guard: `XTIUSD.DWX`, D1, slot 0.
- Exact parameter lock: six completed closes, CH3, arithmetic mean6, 2.5%
  band, ATR(20)*4.0, 40-day repair, and 1,500-point spread ceiling.
- Both current news axes and legacy news mode are OFF. Framework kill-switch
  checks remain authoritative.
- Framework Friday flattening is OFF because the one-month structural hold
  spans weekends.
- History, endpoint, arithmetic, quote, spread, ATR, position, and attempt
  checks fail closed.

## 7. Trade Management Rules

- At most one owned position and one consumed attempt per broker month.
- Renewal closes the old package rather than carrying it into another month.
- No retry after a flat state, invalid gate, rejected submission, or stop-out.
- No scale-in, pyramid, grid, martingale, partial close, adaptive parameter,
  external runtime input, trained signal, or portfolio-state dependency.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| parameter | value | role |
|---|---:|---|
| `strategy_channel_months` | 3 | source-tested prior-close channel |
| `strategy_mean_months` | 6 | source-tested long average |
| `strategy_band_pct` | 2.5 | source-tested symmetric neutral band |
| `strategy_history_bars_d1` | 300 | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | frozen D1 hard-stop estimate |
| `strategy_atr_stop_multiple` | 4.0 | hard-stop distance |
| `strategy_max_hold_days` | 40 | survivor repair only |
| `strategy_max_spread_points` | 1500 | entry ceiling |

Changing a horizon, band, mean, strictness, AND relation, risk, stop, hold, or
spread requires a new source decision and card. There is no after-result
rescue parameter.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_ch3_dmac_confirm_preallocation_dedup_20260831.json`,
SHA-256
`B61748E06968490A41476ED976043288A5C49046244B04EBFF0394B44364DF40`,
is clean across 4,740 registry identities, 1,378 cards, and 45 Strategy Wiki
nodes.

The built CH3 parent trades `[103,100,99,98,120,120]` long while the built
DMAC parent reads it short; this card stays flat. The DMAC parent trades
`[110,111,109,108,80,80]` long while CH3 and this card remain flat. All three
buy `[120,110,105,100,95,90]` and sell its descending counterpart. This
candidate therefore has a strict intersection decision surface and a monthly
renewal contract not shared by the continuous-state DMAC parent.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_MONTHLY_CH3_BREAKOUT_AND_DMAC16_NEUTRAL_BAND_CONFIRMATION_SLEEVE`.

## Risk

This is a high-risk research carrier. WTI gaps, false trends, sparse signals,
broker month labels, financing, futures rolls, and continuous-CFD basis can
invalidate the translation. `expected_pf=1.01` and the 5-8/year cadence are
queue-ordering priors, not evidence.

Q02 must retire the unchanged baseline on zero positions, fewer than five in
any full scored year, nonpositive governed economics, invalid risk mode,
wrong endpoints, wrong signal, repeated entry, missing stop, wrong renewal,
or nondeterminism. Q09 alone may measure realized overlap with the certified
book.

Only one `RISK_FIXED` backtest setfile is authorized. No live, demo, shadow,
stress, or optimization preset; AutoTrading action; `T_Live`; deploy or live
manifest; portfolio gate edit; portfolio admission; decorrelation claim; or
correlation waiver is authorized.

## Framework Alignment

- no_trade: exact host, slot, parameters, framework kill switch, and fail-
  closed validation.
- trade_entry: month transition, persistent attempt, six completed endpoints,
  exact CH3/DMAC AND state, quote/spread/ATR gates, and fixed-risk request.
- trade_management: malformed-state repair, next-month close, and 40-day
  survivor repair before entry-only gates.
- trade_close: owned tickets close through the framework transaction manager;
  the broker hard stop is the intramonth backstop.

## Falsification And Pipeline Status

Passing Q02 would establish only executable baseline evidence. It would not
validate source-to-CFD equivalence, profitability, robustness, low
correlation, or portfolio admission. Any downstream change to the mechanic
requires a full new chain.

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-31 | APPROVED_SOURCE | `decisions/2026-08-31_wti_ch3_dmac_confirmation_source_approval.md` |
| G0 | 2026-08-31 | APPROVED | `decisions/2026-08-31_qm5_41241_wti_ch3_dmac_confirmation_g0.md` |
| Q01 | 2026-08-31 | PASS | `e08c9f5b-6da5-41b9-8de3-85f37691cba0`; strict build check and compiler PASS, zero compiler errors/warnings |
| Q02 | 2026-08-31 | ENQUEUED_PENDING | `bd5768f5-dbb7-437b-acda-717d071fb5df`; final CPU window below 97% ceiling |
