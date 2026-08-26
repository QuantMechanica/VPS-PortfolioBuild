---
card_schema_version: 2
type: strategy
strategy_id: MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026_S01
variant_id: MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026_S01
source_id: MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026
ea_id: QM5_41167
slug: wti-coxstuart-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41167_wti-coxstuart-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41167_wti_monthly_cox_stuart_paired_sign_trend_g0.md
source_approval: decisions/2026-08-26_wti_monthly_cox_stuart_paired_sign_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; D. R. Cox; Alan Stuart"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; D. R. Cox; Alan Stuart"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Cox and Stuart (1955), Some Quick Sign Tests for Trend in Location and Dispersion, Biometrika 42(1-2), 80-95, DOI 10.1093/biomet/42.1-2.80; NIST Dataplot Cox Stuart Test reference."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Cox, D. R., and Stuart, A. (1955). Some Quick Sign Tests for Trend in Location and Dispersion. Biometrika 42(1-2), 80-95."
    location: "DOI 10.1093/biomet/42.1-2.80; official Oxford Academic bibliographic record; body paywalled and not claimed completely read"
    quality_tier: A_record_only
    role: paired_sign_trend_lineage
  - type: official_statistical_implementation_reference
    citation: "NIST Dataplot, Cox Stuart Test."
    location: "https://itl.nist.gov/div898/software/dataplot/refman1/auxillar/coxstuar.htm; reviewed 2026-08-26"
    quality_tier: official_method_documentation
    role: exact_even_sample_pairing_and_sign_count
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI fourteen-month Cox-Stuart paired-sign source packet."
    location: "strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_threshold_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-fourteen-completed-month-end-cox-stuart-seven-lag-seven-paired-sign-five-of-seven-continuation
sources:
  - "[[sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-paired-sign-trend]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/cox-stuart-paired-sign-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, cox-stuart, paired-sign, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 411670000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-8 completed WTI positions per full post-warm-up year after fourteen completed month ends and a strict 5-of-7 paired-sign direction; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI monthly paired-sign trend outside the stated XAU/SP500/NDX/XNG book. Verify fourteen consecutive completed month ends, exact seven lag-seven Cox-Stuart pairs, strict tie rejection, five-sign direction, consume-first attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, fourteen_consecutive_completed_months, latest_close_per_month, chronological_log_prices, exact_seven_lag_seven_pairs, strict_no_tie_rule, five_of_seven_direction, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-26 and decisions/2026-08-26_qm5_41167_wti_monthly_cox_stuart_paired_sign_trend_g0.md: R1 PASS with complete-read peer-reviewed WTI trend evidence, official Cox-Stuart record, and complete NIST pairing description; R2 PASS locks fourteen endpoints, seven pairs, ties, 5-of-7 direction, attempt, risk, stop, and lifecycle; R3 PASS registered native WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. Canonical dedup was CLEAN and two functional vectors separate it from endpoint, Mann-Kendall, quarterly-vote, within-month-half, and robust-slope neighbors."
---

# QM5_41167 WTI Fourteen-Month Cox-Stuart Paired-Sign Trend

## Hypothesis

WTI can sustain slow directional regimes while production, investment,
inventory, transport, refining, hedging, and demand adjust. A single endpoint
return can be dominated by one move, while an all-pairs rank statistic gives
every cross-time comparison a vote. This card instead asks whether at least
five of seven fixed older/newer month-end pairs point in the same direction.
The statistic is distribution-free and discards magnitude after comparison.

The direct crude-oil carrier is economically different from the stated XAU,
SP500, NDX, and XNG book. That is a diversification hypothesis, not proof of
low correlation, profitability, or portfolio suitability. Q02 owns density
and baseline economics; unchanged downstream gates, including Q09, own
robustness and realized overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md`,
SHA-256 `7E0D0F9595CCBDB2CA2B2FEDD02BE2E969CC129CE293C48F44C42BDDC9CBC629`,
authorized by
`decisions/2026-08-26_wti_monthly_cox_stuart_paired_sign_trend_source_approval.md`
and committed at `4501c361a9` before card extraction.

Moskowitz, Ooi, and Pedersen supply WTI membership, own-price continuation
lineage, and monthly cadence. Cox and Stuart supply peer-reviewed paired-sign
trend lineage. The complete official NIST reference supplies the exact even-
sample half-to-half pairing. The original Cox-Stuart body is paywalled and is
not represented as completely read. None of the records tests this WTI-only
5-of-7 threshold, continuous CFD, or fixed-dollar execution contract.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, WTI-only result, CFD equivalence, statistical significance,
decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,666 registry
rows, 1,317 cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy
match. The receipt is
`artifacts/qm5_wti_coxstuart_tr_preallocation_dedup_20260826.json`, SHA-256
`60CFBF3306A8EC69CD34B439D8EDFF300B05BB644E705D89224FAE0C94ABE8B7`.

Manual review fixes a new statistic:

- `QM5_20264_wti-rank-trend` compares all 78 ordered pairs among thirteen
  endpoints and requires `abs(S)>=28`; this card compares only seven fixed
  half-sample pairs among fourteen endpoints and counts five strict signs.
- `QM5_20272_wti-qtrvote-tr` votes four non-overlapping three-month block
  returns; this card votes seven lag-seven paired differences.
- `QM5_41114_wti-mhalfagree-mom` splits daily returns inside one completed
  month; this card reads only fourteen completed month ends.
- `QM5_41165_wti-mrobust3-agree-tr` computes three magnitude-sensitive slopes;
  this card computes no slope and discards magnitude after comparison.
- On `[0,8,3,7,10,2,4,6,13,11,12,9,5,1] * 0.01` log-price ranks, this card
  buys 5/7 while the latest-thirteen Mann-Kendall score is `2`, the endpoint
  falls, and quarterly blocks split 2/2.
- On `[12,4,0,3,7,8,13,2,5,1,9,6,10,11] * 0.01`, this card is flat at 4/3
  while the latest-thirteen Mann-Kendall score is `30`, the endpoint rises,
  and three quarterly blocks rise.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly WTI paired-sign continuation.

Verdict: `CLEAN_WTI_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_TREND`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`.
- Signal and execution timeframe: D1.
- Decision clock: first executable tick of a genuine broker-month transition,
  no later than 180 elapsed minutes after the raw current D1 bar open.
- Formation: latest close in each of the immediately prior fourteen
  consecutive completed broker months; current month excluded.
- Hold: until the first tick in a later broker month; forty days is stale
  repair.
- One consumed attempt and at most one owned position per broker month.
- Expected pre-result density: five to eight completed positions per full
  post-warm-up year; retire below five in any full year.

## Formula

For chronological completed-month closes `C[0]..C[13]`:

```text
y[i] = ln(C[i]), i = 0..13

for i = 0..6:
  d[i] = y[i+7] - y[i]
  require finite(d[i]) and d[i] != 0

positive = count(d[i] > 0)
negative = count(d[i] < 0)
require positive + negative == 7

BUY  iff positive >= 5
SELL iff negative >= 5
FLAT otherwise
```

Every endpoint appears in exactly one comparison. Every pair spans seven
month indexes. Difference magnitude, the winning count beyond five, and any
derived probability never change risk.

The 5-of-7 boundary is fixed before market testing. Under a fair independent-
sign thought experiment only, 58/128 sign vectors qualify, or 45.3125%, for
5.4375 expected monthly decisions/year. This is not a WTI independence,
frequency, significance, or profitability claim.

## Rules

- `ea_id=41167`, exact `XTIUSD.DWX`, D1, slot 0, magic `411670000`.
- Consume the normalized broker month before every fallible entry gate.
- Use exactly fourteen consecutive completed month keys and the latest close
  in each. The newest endpoint must be the immediately prior month and at most
  ten calendar days stale.
- Compute exactly the seven pairs `(0,7)` through `(6,13)`. No alternate
  pairing, skipped pair, tie deletion, dynamic threshold, or magnitude weight
  is permitted.
- Require at least five strict signs in one direction. A tie anywhere or a
  4/3 split is flat.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

On every new D1 bar, in this order:

1. Require exact EA ID, symbol, D1 period, risk mode, framework inputs, and all
   locked strategy inputs.
2. Repair malformed owned exposure and process month/stale exits before entry.
3. Normalize the raw current-bar date under one uniform label convention and
   require a genuine new month within 180 elapsed minutes of raw bar open.
4. Persist the current `yyyymm` in terminal global state before history,
   signal, news, spread, quote, ATR, sizing, margin, or order checks.
5. Reject an owned position or a same-magic entry deal already recorded in the
   current broker month.
6. Reconstruct exactly fourteen consecutive completed month-end closes from a
   bounded D1 buffer. Reverse into strict chronological order and validate
   positivity, finiteness, endpoint month, chronology, and staleness.
7. Calculate exactly seven `ln(C[i+7])-ln(C[i])` values. Reject any zero,
   nonfinite result, wrong pair count, or endpoint reuse.
8. Buy only with at least five positive differences and sell only with at
   least five negative differences. A 4/3 split consumes the month flat.
9. Require spread no greater than 1,500 points, valid quotes, finite completed-
   bar ATR, a valid frozen stop distance, and successful fixed-risk sizing.
10. Submit one slot-zero market order with a frozen broker hard stop and no
    target. A reject never retries the month.

## 5. Exit Rules

Exit or repair at the first applicable condition:

1. Framework kill switch.
2. Broker hard stop frozen at entry.
3. Any duplicate, wrong-symbol, wrong-magic, wrong-side, invalid-volume, or
   stopless owned position.
4. First tick whose normalized broker month differs from the entry month.
5. Forty calendar days after entry as stale-position repair.

There is no target, trail, break-even move, partial exit, Friday close, news
exit, opposite-signal exit, scale-in, or same-month re-entry.

## 6. Filters And No-Trade Contract

- Exact host, D1, EA 41167, slot zero, active resolver identity, fixed-risk
  mode, news OFF/OFF, legacy news OFF, and Friday close OFF.
- Every strategy input is locked to the baseline; mismatches fail init.
- Uniform D1 label normalization, genuine month transition, 180-minute grace,
  fourteen consecutive endpoints, prior-month recency, exact pairs, no ties,
  5-of-7 count, durable attempt, spread, quote, ATR, stop, and sizing all fail
  closed.
- Lifecycle repair is never delayed by an entry-only gate.
- Runtime cannot read futures curves, inventory, volume, open interest,
  external files, APIs, analyst forecasts, trained outputs, portfolio results,
  or prior pipeline verdicts.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411670000`.
- Persist the last attempted `yyyymm` across restart; initialization may clear
  only a future/prior-run tester residue.
- Manage malformed, later-month, stale, and kill-switch exits on every tick
  before entry evaluation.
- Freeze the original hard stop; never widen, trail, remove, or replace it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Parameter | Baseline | Range |
|---|---:|---|
| `strategy_endpoint_count` | 14 | locked |
| `strategy_pair_count` | 7 | locked |
| `strategy_signs_required` | 5 | locked |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

No parameter sweep, tie deletion, direction flip, alternate pair span,
majority threshold, magnitude weight, fallback signal, volatility filter,
seasonal filter, or ensemble gate is authorized after results.

## Source-Defined Rules And QM Interpretations

Moskowitz, Ooi, and Pedersen supply monthly own-return continuation and WTI
carrier lineage. Cox-Stuart and NIST supply ordered half-sample pairing and
sign-count lineage. QM fixes fourteen endpoints, seven pairs, the 5-of-7
density boundary, continuous-CFD calendar, consumed attempt, fixed risk,
spread cap, hard stop, rollover, and stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and a
terminal-persistent attempt marker. No external runtime dataset exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Stop: frozen `3.5*ATR(20,D1)` from the last completed bar at entry.
- Maximum entry spread: 1,500 points.
- One position and one attempt per broker month.
- Pair magnitude and sign-count strength never alter size.
- No live, demo, shadow, stress, or optimization preset is authorized.
- Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
  overlapping economic horizons, stale paired signs, hard-stop slippage,
  density below floor, and realized overlap with energy or risk assets.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | One governed source ID backed by complete-read peer-reviewed WTI evidence, an official peer-reviewed method record, and complete NIST pairing documentation; exact trading rule untested. |
| R2 | PASS | Clock, endpoint order, seven pairs, ties, count, direction, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native WTI D1 supplies every runtime input; Q02 owns density, cost, and CFD sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than five completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest close, stale
  newest endpoint, nonchronological timestamps, or mixed label offsets;
- endpoint count other than 14, pair count other than 7, wrong pair indexes,
  endpoint reuse, nonfinite logarithm/difference, accepted tie, wrong positive
  or negative count, entry on a 4/3 split, or wrong trade side;
- same-month retry, missing hard stop, wrong risk mode, wrong spread ceiling,
  late entry, or missed month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, pairing, ties, threshold,
  direction, risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## 10. Execution And State Contract

- The D1 decision clock supports only raw-current-date labels and a uniformly
  applied raw-plus-one-day convention; mixed offsets fail closed.
- A month is consumed before all fallible gates. Terminal global state and
  deal history prevent a restart retry.
- The current month contributes no signal close.
- Position repair and month rollover run every tick before new-entry gates.
- Logs expose decision month, label offset, endpoint count/times, seven pair
  signs, positive/negative counts, direction, and state without credentials.

## 11. Portfolio Interaction

This direct physical-energy carrier is intended to diversify the stated
XAU/SP500/NDX/XNG book. Its monthly paired-sign path driver is mechanically
different from the incumbent XNG cumulative-RSI pullback and from metal and
index sleeves. Those are design facts only. No ex-ante or realized correlation
is claimed, and no portfolio gate, threshold, incumbent, manifest, or
admission state changes under this card. Q09 owns the first realized overlap
verdict; Q15+ remain manual OWNER gates under the current v4 pipeline.

## 12. Validation Plan

1. Schema-lint both canonical and EA card copies.
2. Independently reproduce all seven pair indexes, ties, counts, the two
   separation vectors, a monotone BUY vector, and a monotone SELL vector.
3. Validate fourteen consecutive month keys, year rollover, latest-close
   selection, current-month exclusion, staleness, label conventions, grace,
   attempt order, and lifecycle repair.
4. Require zero-error/zero-warning compile, build guardrails, exact symbol
   scope, active registry identity, active magic row, and source-fresh EX5.
5. Enqueue exactly one `XTIUSD.DWX` D1 Q02 row after fresh Q01 PASS. Enqueue
   does not launch a manual tester or authorize work beyond the CPU ceiling.
6. Retire below the five-per-year floor or on nonpositive governed economics.

## 13. Framework Alignment

- no_trade: exact EA ID, symbol, timeframe, magic slot, risk, news, Friday,
  stress, and locked strategy-input validation.
- trade_entry: month clock, consume-first attempt, exact completed endpoints,
  seven paired differences, tie rejection, 5-of-7 direction,
  spread/quote/ATR/stop validation, and fixed-risk request.
- trade_management: malformed or wrong-side position repair, next-month exit,
  and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## 14. Safety Boundary

This card authorizes one non-live V5 build and one paced Q02 enqueue after Q01
PASS. It does not authorize a manual backtest, `T_Live`, AutoTrading, deploy
or live manifest, live/demo/shadow/stress/optimization preset, portfolio-gate
change, portfolio admission, threshold change, correlation waiver, terminal
process control, or claim that the strategy is certified.

## Revision History

| Version | Date | Reason | Phase | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-26 | initial source-bounded WTI Cox-Stuart paired-sign card | G0 | APPROVED |
