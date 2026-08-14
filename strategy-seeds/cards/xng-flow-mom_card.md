---
card_schema_version: 2
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XNG_S04
variant_id: ZHAO-ST-MOMREV-2026_XNG_S04
source_id: ZHAO-XNG-QUIETFLOW-2026
ea_id: QM5_21520
slug: xng-flow-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21520_xng-flow-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
g0_decision: decisions/2026-08-14_qm5_21520_xng_flow_mom_g0.md
source_author: "Shen Zhao; Yiyi Ding; Jianfeng Yu; Wenjin Kang"
source_authors: "Shen Zhao; Yiyi Ding; Jianfeng Yu; Wenjin Kang"
source_citation: "Zhao, Ding, Yu, and Kang (2026), Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets, SSRN 6425598, DOI 10.2139/ssrn.6425598."
source_citations:
  - type: academic_working_paper
    citation: "Zhao, S., Ding, Y., Yu, J., and Kang, W. (2026). Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets."
    location: "SSRN 6425598; DOI 10.2139/ssrn.6425598; bounded governed note at D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md"
    quality_tier: B
    role: weekly_residual_component_momentum_direction
strategy_mechanic: weekly-xng-five-day-return-continuation-only-when-same-window-native-tick-volume-ranks-at-or-below-25-percent-of-40-earlier-disjoint-five-bar-windows
sources:
  - "[[sources/ZHAO-XNG-QUIETFLOW-2026]]"
concepts:
  - "[[concepts/short-term-commodity-momentum]]"
  - "[[concepts/quiet-flow-proxy]]"
indicators:
  - "[[indicators/close-return]]"
  - "[[indicators/tick-volume-percentile]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, weekly-momentum, tick-volume-regime, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_21520_XNG_FLOW_MOM_D1
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 215200000
period: D1
timeframe: D1
expected_trade_frequency: "One consumed evaluation per broker week; a bottom-quartile tick-volume gate implies roughly 10-14 entries/year before execution gates. This is a prior, not test evidence."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_STARTED
review_focus: "Falsify a quiet native-tick-volume XNG weekly continuation driver distinct from the certified cumulative-RSI pullback; Q09 alone may establish realized decorrelation from XAU/SP500/NDX/XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_205_completed_bars, disjoint_five_bar_volume_windows, bottom_quartile_rank_cap, continuation_direction, consumed_week, risk_mode_dual, frozen_atr_stop, five_bar_hold, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized second XNG sleeve: R1 bounded attributable academic source and explicit retrieval limit; R2 locked weekly return, disjoint tick-volume rank, direction, lifecycle, stop, and risk; R3 native XNG D1 close/tick volume only; R4 deterministic non-trained arithmetic; exact dedup clean and source-family fuzzy neighbors manually separated."
---

# QM5_21520 XNG weekly quiet-flow momentum

## Hypothesis

The source reports that the residual component of weekly commodity returns
positively predicts the following week's return. QM cannot reproduce its
investor-position decomposition. This card tests a disclosed native-data
proxy: a five-D1 XNG move occurring in unusually quiet native tick volume may
be more residual-dominated and therefore continue during the following week.

The falsifiable edge follows the sign of the latest five-bar return only when
the same five bars' tick-volume sum ranks in the bottom quartile of 40 earlier,
non-overlapping five-bar windows. Average- and high-volume weeks remain flat.
This is not a claim that tick volume measures investor positions or that the
result is uncorrelated with the certified book.

## Source traceability and claim boundary

- Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin (2026), "Momentum and
  Reversal on the Short-Term Horizon: Evidence from Commodity Markets,"
  SSRN 6425598, DOI `10.2139/ssrn.6425598`.
- Canonical URL:
  `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598`.
- Bounded packet:
  `strategy-seeds/sources/ZHAO-XNG-QUIETFLOW-2026/source.md`.
- Retrieval boundary: governed metadata plus accessible abstract/methodology
  summaries; the deterministic 2026-08-14 router result was
  `DEFERRED:SOURCE_POLICY`, and no workaround was used.

The source supports only the weekly residual-component momentum direction.
It does not supply the tick-volume proxy, XNG carrier, 25% threshold, ATR
stop, spread ceiling, hold, trade count, return, or correlation claim.

## Rules

### Market, clock, and data

- Host and trade only `XNGUSD.DWX` on D1, slot 0, magic `215200000`.
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

- Require `volume_rank <= 25`, with ties included in the empirical count.
- If `weekly_return > 0`, buy XNG.
- If `weekly_return < 0`, sell XNG.
- If return is zero, rank is above the cap, data are invalid, or an owned
  position exists, consume the week flat.
- Apply the standard two-axis news gate and reject above 600 spread points.
- Place one market order with fixed-dollar risk, a frozen
  `2.5 * ATR(14,D1)` hard stop, and no take-profit.

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
| `strategy_vol_percentile_cap` | 25 | [15, 25, 33] | maximum empirical quiet-volume rank |
| `strategy_atr_period` | 14 | [10, 14, 20] | completed-D1 hard-stop estimator |
| `strategy_atr_sl_mult` | 2.5 | [2.0, 2.5, 3.0, 3.5] | frozen stop multiple |
| `strategy_max_hold_bars` | 5 | [3, 5, 7] | completed-D1 time stop |
| `strategy_max_spread_points` | 600 | [300, 600, 1000] | entry execution ceiling |

The five-bar formation, disjoint baseline, native tick-volume field, lower-
tail gate, continuation direction, weekly cadence, and one-attempt rule are
locked.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS | One attributable paper, URL, DOI, bounded material, retrieval status, and explicit proxy gap are preserved. |
| R2 | PASS | Entry, direction, exit, stop, risk, lifecycle, and invalid-state behavior are deterministic. |
| R3 | PASS | XNG D1 close and native tick volume are in MT5; no COT, position, file, API, or external feed is required. |
| R4 | PASS | Fixed native arithmetic only; no trained output, PnL adaptation, grid, martingale, or scale-in. |

## Non-duplicate boundary

- `QM5_12567_cum-rsi2-commodity` is long-only short-horizon cumulative-RSI
  pullback with a slow trend filter. This card is symmetric weekly raw-return
  continuation gated by native tick-volume rank.
- `QM5_13101_xng-1w-mom-vol` requires a return-size threshold and low
  realized-volatility rank and permits a signal exit. This card has none of
  those mechanics; its only signal conditioner is quiet tick volume.
- `QM5_21504_xng-flowrev` admits the upper volume tail and fades. This card
  admits the disjoint lower tail and continues. Eligible weeks and directions
  are deliberately complementary, not duplicated.
- `QM5_21505_xag-weekly-lowvol-momentum` remains an unbuilt silver allocation
  and supplies no XNG implementation or evidence.

Dedup verdict:
`CLEAN_XNG_WEEKLY_QUIET_FLOW_MOMENTUM_AFTER_SOURCE_FAMILY_REVIEW`.

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Natural-gas gaps, CFD roll/basis, tick-volume instability, sparse entries,
  and the unproven mapping from low tick volume to the residual component are
  material kill risks.
- Retire below five completed trades per full post-warm-up year or on
  nonpositive governed economics. Do not loosen the gate or change formation
  or direction to manufacture frequency.
- Fail on overlap between current and baseline windows, inclusion of the
  current window in its baseline, real-volume substitution, daily retry,
  wrong direction, missing stop, wrong risk mode, or nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot and locked inputs; completed history,
  chronology, close, tick-volume, rank, position, risk, spread, quote, stop,
  and persistent-attempt guards.
- trade_entry: cached weekly continuation direction, one fixed-risk XNG order,
  and a frozen ATR hard stop.
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
| v1 | 2026-08-14 | initial XNG bottom-quartile tick-volume weekly continuation card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_qm5_21520_xng_flow_mom_g0.md`; bounded source packet |
| Q01 Build Validation | - | PENDING | build not yet started |
| Q02 Baseline Screening | - | NOT STARTED | paced enqueue requires Q01 PASS and available CPU capacity |
