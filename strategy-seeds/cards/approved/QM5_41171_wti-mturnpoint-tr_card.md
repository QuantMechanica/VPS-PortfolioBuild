---
card_schema_version: 2
type: strategy
strategy_id: MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026_S01
variant_id: MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026_S01
source_id: MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026
ea_id: QM5_41171
slug: wti-mturnpoint-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41171_wti-mturnpoint-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41171_wti_monthly_turning_point_persistence_trend_g0.md
source_approval: decisions/2026-08-26_wti_monthly_turning_point_persistence_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; W. Allen Wallis; Geoffrey H. Moore; Andrew Hart; Servet Martinez"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; W. Allen Wallis; Geoffrey H. Moore; Andrew Hart; Servet Martinez"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Wallis and Moore (1941), A Significance Test for Time Series Analysis, JASA 36(215), 401-409, DOI 10.1080/01621459.1941.10500577; Hart and Martinez, spgs 1.0-4, CRAN."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Wallis, W. A., and Moore, G. H. (1941). A Significance Test for Time Series Analysis. JASA 36(215), 401-409."
    location: "DOI 10.1080/01621459.1941.10500577; Crossref metadata; body not claimed completely read"
    quality_tier: A_record_only
    role: phase_frequency_and_turning_point_lineage
  - type: public_method_implementation
    citation: "Hart, A., and Martinez, S. spgs 1.0-4. CRAN."
    location: "public mirror commit 987257510f8b2a7ffe903d6b840021befbb4de58; complete relevant files in retrieval receipt"
    quality_tier: A_method_implementation
    role: exact_strict_turning_point_count_and_iid_null_moments
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI thirteen-month turning-point persistence source packet."
    location: "strategy-seeds/sources/MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_boundary_direction_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-thirteen-completed-month-end-strict-local-extrema-count-below-iid-null-mean-endpoint-direction-continuation
sources:
  - "[[sources/MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-path-persistence]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-price]]"
  - "[[indicators/strict-turning-point-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, turning-point-count, local-extrema, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
host_symbol: XTIUSD.DWX
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "About 5-8 completed XTIUSD positions/year after warm-up; centered prior 6/year; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 6
r1_track_record: PASS
r1_reasoning: "Peer-reviewed complete-read WTI continuation source, peer-reviewed Wallis-Moore method record, and complete pinned CRAN method files; the exact conjunction remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoint reconstruction, strict comparisons, count invariant, below-null-mean boundary, direction, attempt state, risk, stop, and exit are deterministic."
r3_data_available: PASS
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply all runtime inputs; continuous-CFD basis risk remains explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, comparisons, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 endpoints; TP<=7; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
force_build: true
g0_approval_reasoning: "R1 durable peer-reviewed WTI and Wallis-Moore lineage with pinned complete method files; R2 locked monthly strict-turning-point-count mechanic; R3 registered XTIUSD.DWX D1 route; R4 deterministic structural arithmetic only."
expected_pf: 1.05
expected_dd_pct: 20.0
---

# WTI Monthly Turning-Point Persistence Trend

## Hypothesis

WTI has a distinct physical-energy return driver absent from the stated
XAU/SP500/NDX/XNG book. At a monthly clock, a twelve-month directional move is
more credible when thirteen completed month-end closes contain fewer strict
local peaks and troughs than the iid null mean. The EA therefore follows the
oldest-to-newest WTI direction only when the integer turning-point count is
below that mean.

This is a falsifiable direct-crude trend hypothesis. It is not evidence that
the resulting stream is profitable or decorrelated. Q02 owns activity and
economics; downstream gates own robustness and portfolio overlap.

## Source Traceability And Claim Boundary

- Trading carrier and cadence: Moskowitz, Ooi, and Pedersen (2012), complete
  governed source packet `MOP-TSMOM-2012`, explicitly including NYMEX WTI and
  monthly own-price continuation.
- Statistical lineage: Wallis and Moore (1941), JASA, DOI
  `10.1080/01621459.1941.10500577`; bibliographic record only because the
  public article-body route was policy-deferred.
- Exact formula record: CRAN `spgs` 1.0-4 public mirror commit
  `987257510f8b2a7ffe903d6b840021befbb4de58`, complete files and hashes in the
  retrieval receipt.
- Governed extraction and OWNER source approval:
  `decisions/2026-08-26_wti_monthly_turning_point_persistence_trend_source_approval.md`.

The sources do not test the exact thirteen-endpoint sample, `TP<=7` trading
boundary, endpoint-direction conjunction, Darwinex continuous CFD, risk,
stop, spread, or lifecycle. No source performance statistic transfers.

## Non-Duplicate Decision

Canonical pre-allocation evidence:
`artifacts/qm5_wti_mturnpoint_tr_preallocation_dedup_20260826.json`. The
fail-closed scan covered 4,670 registry rows, 1,321 cards, and 45 Strategy Wiki
nodes and returned `CLEAN`.

Functional separation is load-bearing:

- `QM5_20273_wti-signrun-tr` retains the longest positive and negative runs
  and selects a unique run direction; this card retains only total direction
  reversals and takes side from the endpoints.
- `QM5_20264_wti-rank-trend` compares all 78 ordered endpoint pairs; this card
  compares only eleven overlapping local triples.
- `QM5_20274_wti-path-eff` keeps return magnitudes in a path ratio; this card
  discards magnitude after strict comparisons.
- `QM5_41169_wti-foster-record-tr` counts running records; this card counts
  local peaks and troughs that need not be records.
- `QM5_41170_wti-bartels-rank-tr` sums squared adjacent rank distances; this
  card assigns no ranks and counts only direction reversals.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback, not monthly WTI path-shape continuation.

The locked separation fixtures are:

- zero-based ranks `[8,4,1,7,9,10,3,12,6,0,5,2,11]`: `TP=7`, endpoint up,
  so this card buys; Bartels `NM=383`, Mann-Kendall `S=0`, Foster-Stuart
  `d=0`, and longest runs `L+=3,L-=2` all stay flat;
- zero-based ranks `[5,1,6,2,0,8,3,7,12,4,11,9,10]`: `TP=9`, so this card
  stays flat although the endpoint is up, Bartels `NM=309`, and Mann-Kendall
  `S=36`.

Verdict: `CLEAN_WTI_MONTHLY_TURNING_POINT_COUNT_LT_NULL_MEAN_ENDPOINT_TREND`.

## Markets, Timeframe, And Cadence

- Target symbol and only traded instrument: `XTIUSD.DWX`.
- Host symbol: `XTIUSD.DWX`; magic slot 0.
- Chart, signal, ATR, and tester timeframe: D1.
- Decision clock: first executable tick of a genuine new broker month, no
  later than 180 elapsed minutes after the raw current D1 bar open.
- Formation: exactly thirteen consecutive completed broker-month closes,
  ending with the immediately prior month and excluding the current month.
- Expected trade frequency: about 5-8 completed positions/year after warm-up,
  with a centered pre-result prior of 6/year and at most one consumed attempt
  per month.
- Maximum hold: first later broker month or forty calendar days.

## Formula

Let `C[0]..C[12]` be thirteen positive finite pairwise-distinct completed WTI
month-end closes in chronological order.

```text
TP = 0
for i = 1..11:
  peak   = C[i-1] < C[i] and C[i] > C[i+1]
  trough = C[i-1] > C[i] and C[i] < C[i+1]
  if peak or trough:
    TP += 1

require 0 <= TP <= 11
null_mean = 2*(13-2)/3 = 22/3
persistent = 3*TP < 22          # exactly TP <= 7

BUY  iff persistent and C[12] > C[0]
SELL iff persistent and C[12] < C[0]
FLAT otherwise
```

Equal closes fail closed. P-values, continuity correction, normal
approximations, significance claims, phase-duration chi-square, alternate
boundaries, fitted values, magnitude fallbacks, and direction reversal are
forbidden. A lower count never changes size.

## Rules

The EA implements one exact baseline. All invalid history or state consumes
the current broker month flat after persisting the attempt key. The current
month never contributes a signal close. Lifecycle repair runs before
entry-only gates.

### Source-defined rules

- a strict local peak or trough is a turning point;
- under an iid continuous null, the expected count is `2*(n-2)/3` and the
  variance is `(16*n-29)/90`;
- the count is a nonparametric ordered-series diagnostic;
- test a monthly WTI own-price continuation hypothesis with monthly renewal.

### QM interpretations

- use thirteen completed month ends and reject all ties;
- split at the null mean itself for density, not statistical significance;
- use the twelve-month endpoint comparison only for side;
- consume the month before all fallible gates;
- map to `XTIUSD.DWX`, fixed-dollar risk, ATR stop, spread cap, and deterministic
  lifecycle repair.

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
   bounded D1 buffer. Validate positivity, finiteness, pairwise distinction,
   endpoint month, chronology, and staleness.
7. Count strict local extrema over the eleven interior endpoints and require
   a count from zero through eleven.
8. Qualify only at `3*TP<22`; then buy on a rising endpoint or sell on a
   falling endpoint. Consume `3*TP>=22` flat.
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

- Exact host, D1, EA 41171, slot zero, active resolver identity, fixed-risk
  mode, news OFF/NONE, legacy news OFF, and Friday close OFF.
- Every strategy input is locked to the baseline; mismatch fails init.
- Uniform D1 label normalization, genuine month transition, 180-minute grace,
  thirteen consecutive endpoints, no ties, prior-month recency, count
  invariant, durable attempt, spread, quote, ATR, stop, and sizing all fail
  closed.
- Lifecycle repair is never delayed by an entry-only gate.
- Runtime cannot read futures curves, inventory, volume, open interest,
  external files, APIs, forecasts, trained outputs, portfolio results, or
  prior pipeline verdicts.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411710000`.
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
| `strategy_max_turning_points` | 7 | locked inclusive |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

No parameter sweep, tie treatment, boundary change, direction flip, alternate
sample, p-value gate, fallback signal, volatility filter, seasonal filter, or
ensemble gate is authorized after results.

## Framework Execution Overrides

- Friday close: disabled to preserve the approved full-month hold.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Kill switch: framework-first and never bypassed.
- Forced session flatten: none beyond next-month and stale repair.

## Exit Precedence

1. Framework kill switch and broker hard stop.
2. Malformed/duplicate/wrong-side owned-position repair.
3. First later normalized broker month.
4. Forty-day stale repair.
5. No source signal reversal, target, Friday, or news exit exists.

## Runtime Data Dependencies

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
- Turning-point count below the boundary never alters size.
- No live, demo, shadow, stress, or optimization preset is authorized.
- Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
  direction-only information loss, no-tie rejection, hard-stop slippage,
  density below floor, and realized overlap with energy or risk assets.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete-read peer-reviewed WTI evidence, peer-reviewed Wallis-Moore record, and complete pinned CRAN method files; article body and exact trading conjunction untested. |
| R2 | PASS | Clock, endpoint order, strict comparisons, count invariant, boundary, direction, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native WTI D1 supplies every runtime input; Q02 owns density, cost, and CFD sufficiency. |
| R4 | PASS | Native deterministic comparisons and state only; no trained signal, banned indicator, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than five completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest close, stale
  newest endpoint, nonchronological timestamps, or mixed label offsets;
- endpoint count other than 13, an accepted equal close, turning-point count
  outside 0..11, entry at `TP>=8`, or wrong endpoint side;
- same-month retry, missing hard stop, wrong risk mode, wrong spread ceiling,
  late entry, or missed month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, comparison rule, boundary,
  direction, risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## Falsification And Requalification

Any change to the thirteen-month formation, strict local-extrema definition,
`TP<=7` boundary, endpoint direction, broker-month normalization, consumed
attempt, spread ceiling, risk mode, stop, or exit clock creates a new execution
contract and requires a new binary, stream reconciliation, Q02 restart, and
full portfolio requalification. Unresolved history-label, comparison, or
lifecycle ambiguity is `BLOCKED`, never filled in by Development.

## 10. Execution And State Contract

- The D1 decision clock supports only raw-current-date labels and a uniformly
  applied raw-plus-one-day convention; mixed offsets fail closed.
- A month is consumed before all fallible gates. Terminal global state and
  deal history prevent a restart retry.
- The current month contributes no signal close.
- Position repair and month rollover run every tick before entry-only gates.
- Logs expose decision month, label offset, endpoint count/times, turning-point
  count, endpoint direction, and state without credentials.

## 11. Portfolio Interaction

This direct physical-energy carrier is intended to diversify the stated
XAU/SP500/NDX/XNG book. Its monthly local-extrema path-persistence driver is
mechanically different from the incumbent XNG cumulative-RSI pullback and
from metal and index sleeves. Those are design facts only. No ex-ante or
realized correlation is claimed, and no portfolio gate, threshold, incumbent,
manifest, or admission state changes under this card. Q09 owns the first
realized overlap verdict; later portfolio phases remain OWNER-governed.

## 12. Validation Plan

1. Schema-lint both canonical and EA card copies.
2. Independently reproduce strict peak/trough counting, tie rejection,
   monotone `TP=0`, alternating `TP=11`, the boundary at 7/8, endpoint side,
   and both separation fixtures.
3. Validate thirteen consecutive month keys, year rollover, latest-close
   selection, current-month exclusion, staleness, label conventions, grace,
   attempt order, and lifecycle repair.
4. Require zero-error/zero-warning compile, build guardrails, exact symbol
   scope, active registry identity, active magic row, and source-fresh EX5.
5. Enqueue exactly one `XTIUSD.DWX` D1 Q02 row after fresh Q01 and independent
   review PASS. Enqueue does not launch a manual tester or authorize work
   beyond the CPU ceiling.
6. Retire below the five-per-year floor or on nonpositive governed economics.

## 13. Framework Alignment

- no_trade: exact EA ID, symbol, timeframe, magic slot, risk, news, Friday,
  stress, and locked strategy-input validation.
- trade_entry: month clock, consume-first attempt, exact completed endpoints,
  strict local-extrema count, `3*TP<22`, endpoint direction,
  spread/quote/ATR/stop validation, and fixed-risk request.
- trade_management: malformed or wrong-side repair, entry-month direction
  reconstruction, next-month exit, and stale repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## 14. Safety Boundary

This card authorizes one non-live V5 build and one paced Q02 enqueue after Q01
and review PASS. It does not authorize a manual backtest, `T_Live`,
AutoTrading, deploy or live manifest, live/demo/shadow/stress/optimization
preset, portfolio-gate change, portfolio admission, threshold change,
correlation waiver, terminal process control, or claim that the strategy is
certified.

## Revision History

| Version | Date | Reason | Phase | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-26 | initial source-bounded WTI turning-point persistence card | G0 | APPROVED |
