---
card_schema_version: 2
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XTI_S05
variant_id: ZHAO-ST-MOMREV-2026_XTI_S05
source_id: ZHAO-WTI-FLOWSWITCH-2026
ea_id: QM5_21521
slug: wti-flow-switch
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21521_wti-flow-switch_card.md
execution_contract_status: APPROVED
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
g0_decision: decisions/2026-08-14_qm5_21521_wti_flow_switch_g0.md
source_author: "Shen Zhao; Yiyi Ding; Jianfeng Yu; Wenjin Kang"
source_authors: "Shen Zhao; Yiyi Ding; Jianfeng Yu; Wenjin Kang"
source_citation: "Zhao, Ding, Yu, and Kang (2026), Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets, SSRN 6425598, DOI 10.2139/ssrn.6425598."
source_citations:
  - type: academic_working_paper
    citation: "Zhao, S., Ding, Y., Yu, J., and Kang, W. (2026). Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets."
    location: "SSRN 6425598; DOI 10.2139/ssrn.6425598; bounded governed note at D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md"
    quality_tier: B
    role: weekly_residual_momentum_and_speculative_flow_reversal_directions
strategy_mechanic: weekly-wti-five-day-return-followed-in-bottom-quartile-and-faded-in-top-quartile-of-40-earlier-disjoint-five-bar-native-tick-volume-windows-with-middle-half-flat
sources:
  - "[[sources/ZHAO-WTI-FLOWSWITCH-2026]]"
concepts:
  - "[[concepts/short-term-commodity-momentum]]"
  - "[[concepts/short-term-commodity-reversal]]"
  - "[[concepts/flow-regime-switch]]"
indicators:
  - "[[indicators/close-return]]"
  - "[[indicators/tick-volume-percentile]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, weekly-momentum, weekly-reversal, tick-volume-regime, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_21521_WTI_FLOW_SWITCH_D1
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 215210000
period: D1
timeframe: D1
expected_trade_frequency: "One consumed evaluation per broker week; two disjoint quartile tails imply roughly 20-26 eligible entries/year before execution gates. This is a prior, not test evidence."
expected_trades_per_year_per_symbol: 23
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: READY
review_focus: "Falsify a WTI weekly two-tail flow proxy that switches between continuation and reversal without importing the certified index/metal drivers; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_205_completed_bars, disjoint_five_bar_volume_windows, two_tail_rank_boundaries, middle_half_flat, tail_direction_map, consumed_week, risk_mode_dual, frozen_atr_stop, five_bar_hold, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized new WTI sleeve: R1 bounded attributable academic source and explicit retrieval limit; R2 locked weekly return, disjoint tick-volume rank, ternary direction map, lifecycle, stop, and risk; R3 native WTI D1 close/tick volume only; R4 deterministic non-trained arithmetic; exact dedup clean and source-family fuzzy neighbors manually separated."
---

# QM5_21521 WTI weekly flow-regime switch

## Hypothesis

The source reports that the residual component of weekly commodity returns
positively predicts the following week's return, while its speculative-flow
component reverses. QM cannot reproduce the investor-position decomposition.
This card tests one disclosed native-data proxy on WTI: quiet five-D1 moves
may be more residual-dominated and continue, while unusually active moves may
be more flow-dominated and reverse.

The falsifiable edge follows the latest five-bar WTI return only when the
same window's native tick-volume sum ranks in the bottom quartile of 40
earlier, non-overlapping five-bar windows. It fades the return only in the top
quartile and consumes the middle half flat. This is not a claim that tick
volume measures investor positions or that the return stream is uncorrelated
with the certified book.

## Source traceability and claim boundary

- Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin (2026), "Momentum and
  Reversal on the Short-Term Horizon: Evidence from Commodity Markets,"
  SSRN 6425598, DOI `10.2139/ssrn.6425598`.
- Canonical URL:
  `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598`.
- Bounded packet:
  `strategy-seeds/sources/ZHAO-WTI-FLOWSWITCH-2026/source.md`.
- Retrieval boundary: governed metadata plus accessible abstract/methodology
  summaries; the deterministic 2026-08-14 router result was
  `DEFERRED:SOURCE_POLICY`, and no workaround was used.

The source supports only the weekly residual-momentum and speculative-flow
reversal directions. It does not supply the tick-volume proxy, WTI carrier,
quartile thresholds, middle state, ATR stop, spread ceiling, hold, trade
count, return, or correlation claim.

## Rules

### Market, clock, and data

- Host and trade only `XTIUSD.DWX` on D1, slot 0, magic `215210000`.
- Use only completed D1 `close`, `time`, and native `tick_volume` fields.
- Evaluate on a new D1 bar only when the framework `PERIOD_W1` key changes.
- Persist the new week before every fallible gate. Exactly one attempt is
  allowed per week across restarts, stop-outs, and order failures.
- Require exactly `40 * 5 + 5 = 205` completed bars, strictly descending
  timestamps, positive finite closes, and positive tick volume.

### Entry

With series index 0 equal to the latest completed D1 bar:

```text
weekly_return = Close[0] / Close[5] - 1
current_volume = sum(TickVolume[0..4])

for j in 0..39:
    baseline_volume[j] = sum(TickVolume[5 + 5*j .. 9 + 5*j])

volume_rank = 100 * count(baseline_volume <= current_volume) / 40
```

- If `volume_rank <= 25` and `weekly_return > 0`, buy WTI.
- If `volume_rank <= 25` and `weekly_return < 0`, sell WTI.
- If `volume_rank >= 75` and `weekly_return > 0`, sell WTI.
- If `volume_rank >= 75` and `weekly_return < 0`, buy WTI.
- Ties are included in the empirical count. A zero return or rank strictly
  between 25 and 75 consumes the week flat.
- Apply the standard two-axis news gate and reject above 400 spread points.
- Place one market order with fixed-dollar risk, a frozen
  `2.75 * ATR(14,D1)` hard stop, and no take-profit.

### Exit and management

- Close after five completed D1 bars from entry.
- Broker hard stop and framework Friday close remain authoritative.
- No opposite-signal exit, neutral-band exit, target, trail, break-even,
  partial close, scale-in, grid, martingale, pyramid, or same-week re-entry.
- Wrong symbol/timeframe/ID/slot, unlocked inputs, malformed history,
  invalid ATR/spread/quote/stop, duplicate exposure, or risk-contract breach
  fails closed.

## Parameters to test

Q02 uses the defaults. Ranges are predeclared for a later governed sweep only
and do not authorize rescue tuning after baseline failure.

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_vol_lookback` | 40 | [26, 40, 60] | earlier disjoint five-bar volume windows |
| `strategy_low_rank_cap` | 25 | [15, 25, 33] | maximum quiet-volume rank |
| `strategy_high_rank_floor` | 75 | [67, 75, 85] | minimum active-volume rank |
| `strategy_atr_period` | 14 | [10, 14, 20] | completed-D1 hard-stop estimator |
| `strategy_atr_sl_mult` | 2.75 | [2.0, 2.75, 3.5] | frozen stop multiple |
| `strategy_max_hold_bars` | 5 | [3, 5, 7] | completed-D1 time stop |
| `strategy_max_spread_points` | 400 | [250, 400, 700] | entry execution ceiling |

The five-bar formation, disjoint baseline, native tick-volume field, both
quartile boundaries, middle-flat state, tail direction map, weekly cadence,
and one-attempt rule are locked.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS | One attributable paper, URL, DOI, bounded material, retrieval status, and explicit proxy gap are preserved. |
| R2 | PASS | Entry, ternary direction, exit, stop, risk, lifecycle, and invalid-state behavior are deterministic. |
| R3 | PASS | WTI D1 close and native tick volume are in MT5; no COT, position, file, API, or external feed is required. |
| R4 | PASS | Fixed native arithmetic only; no trained output, PnL adaptation, grid, martingale, or scale-in. |

## Non-duplicate boundary

- `QM5_12567_cum-rsi2-commodity` is long-only short-horizon cumulative-RSI
  pullback with a slow trend filter. This card is weekly, symmetric, raw-
  return based, and gated by disjoint native tick-volume rank.
- `QM5_13049_xti-1w-mom-vol` and `QM5_13050_xti-1w-rev-vol` require return-
  magnitude thresholds and realized-volatility ranks and permit signal exits.
  This card has none of those mechanics.
- `QM5_21504_xng-flowrev` admits only the upper tail and fades XNG;
  `QM5_21520_xng-flow-mom` admits only the lower tail and continues XNG. This
  WTI card maps both disjoint tails to opposite directions in one locked
  ternary state machine and explicitly consumes the middle half flat.
- Existing WTI trend, seasonality, EIA-event, expiry, carry, relative-value,
  and robust-momentum builds do not use this two-tail volume-state switch.

Dedup verdict:
`CLEAN_WTI_WEEKLY_TWO_TAIL_FLOW_REGIME_SWITCH_AFTER_SOURCE_FAMILY_REVIEW`.

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, CFD roll/basis, tick-volume instability, two-tail churn, and the
  unproven mapping from tick volume to source components are material kill
  risks.
- Retire below five completed trades per full post-warm-up year or on
  nonpositive governed economics. Do not move the quartile boundaries or
  change either tail's direction to manufacture a pass.
- Fail on overlap between current and baseline windows, inclusion of the
  current window in its baseline, real-volume substitution, daily retry,
  wrong tail direction, middle-rank entry, missing stop, wrong risk mode, or
  nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot and locked inputs; completed history,
  chronology, close, tick-volume, rank, position, risk, spread, quote, stop,
  and persistent-attempt guards.
- trade_entry: cached two-tail direction, one fixed-risk WTI order, and a
  frozen ATR hard stop.
- trade_management: completed-D1-bar time stop with no modification logic.
- trade_close: framework close helper, broker hard stop, and Friday close.

## Safety boundary

This card authorizes only a branch build, strict compile/Q01, one D1 backtest
setfile, and one paced non-live Q02 handoff if CPU capacity permits. It does
not authorize a manual backtest; live/demo/shadow/stress/optimization setfile;
AutoTrading; `T_Live`; deploy or live manifest; portfolio-gate mutation;
portfolio admission; or correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial WTI two-tail tick-volume flow-regime switch card | G0 | APPROVED; build pending |
| v2 | 2026-08-14 | implement locked WTI two-tail switch and fixed-risk lifecycle | Q01 | PASS; Q02 ready |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_qm5_21521_wti_flow_switch_g0.md`; bounded source packet |
| Q01 Build Validation | 2026-08-14 | PASS | strict compile 0/0; scoped build check 0 failures/0 warnings; nine reference tests PASS |
| Q02 Baseline Screening | 2026-08-14 | READY | paced enqueue requires available CPU capacity |
