---
card_schema_version: 2
type: strategy
strategy_id: MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026_S01
variant_id: MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026_S01
source_id: MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026
ea_id: QM5_41169
slug: wti-foster-record-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41169_wti-foster-record-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41169_wti_monthly_foster_stuart_record_count_trend_g0.md
source_approval: decisions/2026-08-26_wti_monthly_foster_stuart_record_count_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; F. G. Foster; A. Stuart; Jorge Castillo-Mateo"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; F. G. Foster; A. Stuart; Jorge Castillo-Mateo"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Foster and Stuart (1954), Distribution-Free Tests in Time-Series Based on the Breaking of Records, JRSS B 16(1), 1-22, DOI 10.1111/j.2517-6161.1954.tb00143.x; Castillo-Mateo, Cebrian, and Asin (2023), RecordTest, Journal of Statistical Software 106(5), DOI 10.18637/jss.v106.i05."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Foster, F. G., and Stuart, A. (1954). Distribution-Free Tests in Time-Series Based on the Breaking of Records. JRSS B 16(1), 1-22."
    location: "DOI 10.1111/j.2517-6161.1954.tb00143.x; official Oxford Academic record; body not claimed completely read"
    quality_tier: A_record_only
    role: distribution_free_record_count_trend_lineage
  - type: peer_reviewed_public_method_implementation
    citation: "Castillo-Mateo, J., Cebrian, A. C., and Asin, J. (2023). RecordTest. Journal of Statistical Software 106(5), 1-28."
    location: "DOI 10.18637/jss.v106.i05; public RecordTest commit 463cca629cec54ed58dfe0f03140d29be6c8f2aa; complete relevant files in retrieval receipt"
    quality_tier: A_method_implementation
    role: exact_forward_d_and_strict_record_definitions
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI thirteen-month Foster-Stuart forward-record-count source packet."
    location: "strategy-seeds/sources/MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_threshold_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-thirteen-completed-month-end-foster-stuart-strict-forward-upper-minus-lower-record-count-absolute-two-continuation
sources:
  - "[[sources/MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-record-count-trend]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-price]]"
  - "[[indicators/foster-stuart-forward-record-d]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, foster-stuart, record-count, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 411690000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-8 completed WTI positions per full post-warm-up year after thirteen completed month ends and abs(forward upper records minus forward lower records)>=2; Q02 must prove at least five/year or retire."
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
review_focus: "Falsify a direct-WTI monthly record-frontier trend outside the stated XAU/SP500/NDX/XNG book. Verify thirteen consecutive completed month ends, strict running upper/lower records, count conservation, abs(d)>=2 direction, consume-first attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, thirteen_consecutive_completed_months, latest_close_per_month, strict_forward_record_frontiers, count_conservation, absolute_record_difference_two, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-26 and decisions/2026-08-26_qm5_41169_wti_monthly_foster_stuart_record_count_trend_g0.md: R1 PASS with complete-read peer-reviewed WTI evidence, official Foster-Stuart record, and complete peer-reviewed-package method files; R2 PASS locks thirteen endpoints, strict forward records, count conservation, d=2, attempt, risk, stop, and lifecycle; R3 PASS registered native WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native comparisons and counts only. Canonical dedup was CLEAN and two functional vectors separate it from endpoint, Mann-Kendall, Cox-Stuart, quarterly-vote, Spearman, and slope neighbors."
---

# QM5_41169 WTI Thirteen-Month Foster-Stuart Record-Count Trend

## Hypothesis

WTI can sustain slow directional regimes while production, investment,
inventory, transport, refining, hedging, and demand adjust. Endpoint returns
and fitted slopes summarize magnitude. This card instead asks whether the
formation path repeatedly breaks its running high more often than its running
low, or vice versa. It follows WTI only when the strict forward-record count
difference reaches two.

The direct crude-oil carrier is economically different from the stated XAU,
SP500, NDX, and XNG book. That is a diversification hypothesis, not proof of
low correlation, profitability, or portfolio suitability. Q02 owns density
and baseline economics; unchanged downstream gates, including Q09, own
robustness and realized overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026/source.md`,
authorized by
`decisions/2026-08-26_wti_monthly_foster_stuart_record_count_trend_source_approval.md`
and committed at `97221b5cc` before card extraction.

Moskowitz, Ooi, and Pedersen supply WTI membership, own-price continuation,
and monthly cadence. Foster and Stuart supply peer-reviewed record-count trend
lineage. The complete relevant `RecordTest` files supply the strict forward
upper/lower definitions and unweighted `d` formula. The original 1954 body is
not represented as completely read. None of the records tests this WTI-only
thirteen-endpoint threshold, continuous CFD, or fixed-dollar execution
contract.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, WTI-only result, CFD equivalence, significance,
decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,668 registry
rows, 1,319 cards, and 45 Strategy Wiki nodes. It found no exact or fuzzy
match. The receipt is
`artifacts/qm5_wti_foster_record_tr_preallocation_dedup_20260826.json`,
SHA-256 `BB0661A74BC9F28E2D292DDF49A01E131289A0054DB895B3FB76F54255AF7891`.

Manual review fixes a new statistic:

- `QM5_20264_wti-rank-trend` compares all ordered endpoint pairs; this card
  compares each endpoint only with the running high and low.
- `QM5_20261_wti-lr-trend` and robust-slope cards retain magnitude and fitted
  geometry; this card retains only strict record events.
- `QM5_41167_wti-coxstuart-tr` compares seven fixed lag-seven pairs among
  fourteen endpoints; this card uses thirteen endpoints and no fixed pairs.
- `QM5_10473_mql5-spearman` trades H4 FX rank-correlation zero crossings;
  this card uses neither a correlation coefficient nor a crossing event.
- Rank vector `[1,8,2,6,9,10,4,12,5,13,11,0,3,7]` makes this card buy from
  the latest thirteen at `d=2`, while endpoint, Mann-Kendall, Cox-Stuart,
  quarterly-vote, and OLS neighbors do not buy.
- Rank vector `[1,2,0,7,4,3,13,10,9,8,11,6,5,12]` makes this card flat at
  `d=1`, while those endpoint, Mann-Kendall, Cox-Stuart, quarterly-vote, and
  OLS neighbors buy.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly WTI record-count continuation.

Verdict: `CLEAN_WTI_MONTHLY_FOSTER_STUART_FORWARD_RECORD_D2_TREND`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`.
- Signal and execution timeframe: D1.
- Decision clock: first executable tick of a genuine broker-month transition,
  no later than 180 elapsed minutes after the raw current D1 bar open.
- Formation: latest close in each of the immediately prior thirteen
  consecutive completed broker months; current month excluded.
- Hold: until the first tick in a later broker month; forty days is stale
  repair.
- One consumed attempt and at most one owned position per broker month.
- Expected pre-result density: five to eight completed positions per full
  post-warm-up year; retire below five in any full year.

## Formula

For chronological completed-month closes `C[0]..C[12]`:

```text
running_high = C[0]
running_low  = C[0]
upper = lower = neutral = 0

for i = 1..12:
  if C[i] > running_high:
    upper += 1
    running_high = C[i]
  else if C[i] < running_low:
    lower += 1
    running_low = C[i]
  else:
    neutral += 1

require upper + lower + neutral == 12
d = upper - lower
BUY  iff d >= 2
SELL iff d <= -2
FLAT otherwise
```

Comparisons are strict. Equality is neutral and never a weak record. Record
magnitude and excess count beyond the threshold never alter risk. Across all
`13!` distinct-rank permutations, 47.5975508224% have `abs(d)>=2`, implying
5.7117060987 monthly decisions/year. This is a non-empirical density prior,
not a WTI independence, significance, frequency, or profitability claim.

## Rules

- `ea_id=41169`, exact `XTIUSD.DWX`, D1, slot 0, magic `411690000`.
- Consume the normalized broker month before every fallible entry gate.
- Use exactly thirteen consecutive completed month keys and the latest close
  in each; the newest endpoint must be the immediately prior month and no more
  than ten calendar days stale.
- Use strict forward records only, starting from the oldest close as both
  frontiers. Equality is neutral and `upper + lower + neutral` must equal 12.
- Buy only at `upper-lower>=2`, sell only at `upper-lower<=-2`, and consume
  the remaining states flat.
- Both news axes, legacy news mode, and Friday close are OFF.

## Source-defined rules

- Monthly WTI own-price continuation and one-month renewal come from
  Moskowitz, Ooi, and Pedersen.
- The unweighted forward Foster-Stuart location statistic is forward-upper
  record indicators minus forward-lower record indicators.
- A strict upper record exceeds every prior observation; a strict lower
  record is below every prior observation; the first trivial upper and lower
  records cancel.

The sources do not define the thirteen-month sample, threshold two, CFD
calendar, entry grace, stop, spread cap, fixed-dollar sizing, or stale repair.

## QM interpretations

- Variant `MOP-FOSTER-STUART-WTI-MRECORD-TREND-2026_S01` fixes thirteen
  immediately prior completed month ends and excludes the current month.
- It omits both cancelling trivial records from reported counts, uses strict
  records, treats equality as neutral, and requires count conservation.
- It follows `d` only at `abs(d)>=2`; it does not calculate or claim a
  Foster-Stuart p-value.
- It maps the experiment to `XTIUSD.DWX`, broker calendar months, a consumed
  attempt, `RISK_FIXED=1000`, a frozen ATR stop, and next-month renewal.
- These choices are immutable for Q02 and carry no source performance claim.

## 4. Entry Rules

On every new D1 bar, in this order:

1. Require exact EA ID, symbol, D1 period, risk mode, framework inputs, and all
   locked strategy inputs.
2. Repair malformed owned exposure and process month/stale exits before entry.
3. Normalize the raw current-bar date under one uniform label convention and
   require a genuine new month within 180 elapsed minutes of raw bar open.
4. Persist the current `yyyymm` before history, signal, news, spread, quote,
   ATR, sizing, margin, or order gates.
5. Reject an owned position or same-magic entry deal already recorded in the
   current broker month.
6. Reconstruct exactly thirteen consecutive completed month-end closes from a
   bounded D1 buffer. Validate positivity, finiteness, endpoint month,
   chronology, and staleness.
7. Calculate strict forward upper, lower, and neutral counts; reject wrong
   count conservation or an invalid running frontier.
8. Buy only at `d>=2`, sell only at `d<=-2`, and consume `abs(d)<2` flat.
9. Require spread no greater than 1,500 points, valid quotes, finite
   completed-bar ATR, a valid frozen stop distance, and fixed-risk sizing.
10. Submit one slot-zero market order with a frozen hard stop and no target.
    A reject never retries the month.

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

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41169, slot zero, active resolver identity, fixed-risk
  mode, news OFF/OFF, legacy news OFF, and Friday close OFF.
- Every strategy input is locked to the baseline; mismatch fails init.
- Uniform D1 label normalization, genuine month transition, 180-minute grace,
  thirteen consecutive endpoints, prior-month recency, strict records, count
  conservation, durable attempt, spread, quote, ATR, stop, and sizing all fail
  closed.
- Lifecycle repair is never delayed by an entry-only gate.
- Runtime cannot read futures curves, inventory, volume, open interest,
  external files, APIs, forecasts, trained outputs, portfolio results, or
  prior pipeline verdicts.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411690000`.
- Persist the last attempted `yyyymm` across restart; initialization may clear
  only a future/prior-run tester residue.
- Manage malformed, later-month, stale, and wrong-side exposure on every tick
  before entry-only gates.
- Recompute the entry-month direction from completed history for state repair;
  never use current-month price in that validation.
- Freeze the original hard stop; never widen, trail, remove, or replace it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Parameter | Baseline | Range |
|---|---:|---|
| `strategy_endpoint_count` | 13 | locked |
| `strategy_record_threshold` | 2 | locked |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

No parameter sweep, weak-record mode, direction flip, alternate sample,
dynamic threshold, p-value gate, fallback signal, volatility filter, seasonal
filter, or ensemble gate is authorized after results.

## Framework execution overrides

- Friday close: disabled to preserve the approved full-month hold.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Kill switch: framework-first and never bypassed.
- Forced session flatten: none beyond next-month and stale repair.

## Exit precedence

1. Framework kill switch and broker hard stop.
2. Malformed/duplicate/wrong-side owned-position repair.
3. First later normalized broker month.
4. Forty-day stale repair.
5. No source signal reversal, target, Friday, or news exit exists.

## Runtime data dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and one
terminal-persistent attempt marker. Signal and chart timeframe are both D1.
The broker calendar is authoritative; no DST conversion or external finite
dataset exists. Tester account currency is supplied by MT5 risk sizing.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Stop: frozen `3.5*ATR(20,D1)` from the last completed bar at entry.
- Maximum entry spread: 1,500 points.
- One position and one attempt per broker month.
- Record magnitude and excess `d` never alter size.
- No live, demo, shadow, stress, or optimization preset is authorized.
- Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
  record sensitivity to a single old extreme, hard-stop slippage, density
  below floor, and realized overlap with energy or risk assets.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete-read peer-reviewed WTI evidence, official Foster-Stuart record, and complete exact-method files from a peer-reviewed public package; exact trading rule untested. |
| R2 | PASS | Clock, endpoint order, strict records, count conservation, threshold, direction, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native WTI D1 supplies every runtime input; Q02 owns density, cost, and CFD sufficiency. |
| R4 | PASS | Native deterministic comparisons and state only; no trained signal, banned indicator, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than five completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest close, stale
  newest endpoint, nonchronological timestamps, or mixed label offsets;
- endpoint count other than 13, non-strict record classification, weak-record
  acceptance, wrong upper/lower/neutral count, broken conservation, wrong `d`,
  entry at `abs(d)<2`, or wrong trade side;
- same-month retry, missing hard stop, wrong risk mode, wrong spread ceiling,
  late entry, or missed month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, records, threshold, direction,
  risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## Falsification and requalification

Any change to the thirteen-month formation, strict record definitions,
threshold two, direction, broker-month normalization, consumed attempt,
spread ceiling, risk mode, stop, or exit clock creates a new execution
contract and requires a new binary, stream reconciliation, Q02 restart, and
full portfolio requalification. Unresolved history-label, count, or lifecycle
ambiguity is `BLOCKED`, never filled in by Development.

## 10. Execution And State Contract

- The D1 decision clock supports only raw-current-date labels and a uniformly
  applied raw-plus-one-day convention; mixed offsets fail closed.
- A month is consumed before all fallible gates. Terminal global state and
  deal history prevent a restart retry.
- The current month contributes no signal close.
- Position repair and month rollover run every tick before entry-only gates.
- Logs expose decision month, label offset, endpoint count/times, upper/lower/
  neutral counts, `d`, direction, and state without credentials.

## 11. Portfolio Interaction

This direct physical-energy carrier is intended to diversify the stated
XAU/SP500/NDX/XNG book. Its monthly record-frontier path driver is
mechanically different from the incumbent XNG cumulative-RSI pullback and
from metal and index sleeves. Those are design facts only. No ex-ante or
realized correlation is claimed, and no portfolio gate, threshold, incumbent,
manifest, or admission state changes under this card. Q09 owns the first
realized overlap verdict; Q15+ remain manual OWNER gates.

## 12. Validation Plan

1. Schema-lint both canonical and EA card copies.
2. Independently reproduce strict record frontiers, equality-neutral behavior,
   count conservation, monotone BUY/SELL vectors, both separation vectors,
   and the exact `13!` density count.
3. Validate thirteen consecutive month keys, year rollover, latest-close
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
  strict record frontiers, count conservation, `d=2` direction,
  spread/quote/ATR/stop validation, and fixed-risk request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, next-month exit, and stale repair before entry-only gates.
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
| v1 | 2026-08-26 | initial source-bounded WTI Foster-Stuart record-count card | G0 | APPROVED |
