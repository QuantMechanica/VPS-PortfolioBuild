---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_EXPW12_S27
variant_id: MOP-TSMOM-2012_XTI_EXPW12_S27
source_id: MOP-WTI-EXPW-2026
ea_id: QM5_20279
slug: wti-expw-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20279_wti-expw-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-11
created_by: Research+Development
last_updated: 2026-08-11
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-EXPW-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-sign-of-twelve-exponential-recency-weighted-completed-monthly-log-returns-three-month-half-life
sources:
  - "[[sources/MOP-WTI-EXPW-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/exponential-recency-weighted-return]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/fixed-exponential-lag-weight]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, exponential-recency-weighting, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202790000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year after thirteen completed month ends because only exact-zero or invalid exponential-weighted states stay flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_QUEUED
review_focus: "Falsify a direct WTI monthly trend whose fixed base-two exponential kernel and three-month half-life differ from cumulative, exact-horizon, linear-weight, sign-vote, sorted-return, pairwise, price-regression, rank, calendar, and incumbent-XNG logic; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, chronological_log_return_orientation, fixed_exponential_weight_kernel, fixed_half_life, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-11_qm5_20279_wti_expw_mom_g0.md: R1 one complete-read peer-reviewed WTI source; R2 fixed thirteen endpoints, twelve adjacent returns, base-two weights, three-month half-life, normalization, direction, and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic. The canonical checker scanned 4,344 registry rows and 455 cards with no exact or fuzzy identity; linear-weight and robust same-source neighbors were manually separated."
---

# QM5_20279 WTI Exponential-Recency Return Momentum

## Hypothesis

WTI can sustain slow directional regimes as production, investment,
inventories, transport, refining, hedging, and demand adjust. Information from
recent completed months may decay smoothly rather than disappear at one
selected endpoint. A fixed exponential kernel therefore uses all twelve
monthly returns while assigning an explicit three-month information half-life.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The sole source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-EXPW-2026/source.md`. Its complete-read parent
is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of Financial
Economics* paper documenting monthly own-return continuation over the first
twelve lags and including WTI among its commodity futures.

The source does not use exponential recency weights or prescribe a half-life.
The exact kernel, Darwinex continuous CFD, broker-month reconstruction,
fixed-dollar sizing, ATR hard stop, spread cap, attempt ledger, and lifecycle
controls are transparent QM mechanizations. No source return, alpha, Sharpe
ratio, drawdown, WTI-specific result, trade count, cost, CFD equivalence, or
correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,344 EA-registry rows and 455 cards. It found
no exact identity and no fuzzy match above threshold. Manual mechanic review
resolves the family boundary:

- `QM5_20278` uses integer weights `1..12`; this rule uses a constant base-two
  decay rate whose weight halves every three completed months;
- `QM5_20269`, `QM5_20270`, and `QM5_20277` sort twelve returns before taking
  a median, trimmed mean, or Winsorized mean; this rule never sorts or clips;
- `QM5_20272` gives each of four quarterly signs one vote and discards return
  magnitude and distinct monthly recency;
- `QM5_20261`, `QM5_20264`, `QM5_20271`, `QM5_20274`, and `QM5_20276` use
  regression, rank, pairwise slope, path efficiency, or high-low state; and
- exact-horizon and nested-vote WTI systems use cumulative endpoints rather
  than twelve adjacent-return weights.

The thirteen endpoints, twelve adjacent intervals, age orientation, base two,
three-month half-life, normalization, direction, consumed attempt, and monthly
renewal are jointly load-bearing. Verdict:
`CLEAN_EXPONENTIAL_RECENCY_WEIGHTED_MONTHLY_RETURN_TREND`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202790000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes forming
  twelve chronological adjacent monthly log returns.
- Holding clock: next broker-month boundary, with a forty-calendar-day stale
  guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `C[0]..C[12]` be completed month-end closes from
months `t-13..t-1`, ordered oldest to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
age[i] = 11 - i
half_life = 3.0
w[i] = 2 ^ (-age[i] / half_life)
weight_total = sum(w[i]), i = 0..11
exp_weighted_mean = sum(w[i] * r[i]) / weight_total
```

BUY when the weighted mean is positive. SELL when it is negative. Exact zero
or invalid state remains flat. The newest return has weight one, ages three,
six, and nine have weights one-half, one-quarter, and one-eighth, and signal
magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no parameter sweep and
no fallback to a cumulative return, single horizon, linear weight, sorted-
return statistic, pairwise statistic, sign vote, regression, rank, moving
average, oscillator, calendar direction, external series, or previous
pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20279`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. A flat, rejected, failed,
   stopped, or blocked outcome cannot retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from bounded D1
   history. Require the newest endpoint to be the immediately prior month and
   every older month key to be consecutive.
6. Keep endpoints oldest to newest; require positive finite closes and
   strictly increasing timestamps.
7. Calculate exactly twelve finite adjacent log returns from pairs `(0,1)`
   through `(11,12)` in chronological order. No reverse or skipped pair is
   allowed.
8. Give return `i` exact age `11-i`, compute `2^(-age/3.0)`, require finite
   positive weights and a finite positive total, then divide the weighted sum
   by that total. Buy when positive and sell when negative; exact zero stays
   flat.
9. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and fixed-risk sizing.
10. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth signal flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, nonpositive
  or nonfinite close, wrong adjacent pair or orientation, invalid logarithm,
  wrong age, invalid weight/total, zero signal, excessive spread, invalid
  quote, unavailable ATR, invalid stop, or invalid volume metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read futures curves, inventory, volume, open interest,
  files, APIs, analyst forecasts, trained outputs, optimizers, or portfolio
  results.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  positions and deal history. A marker from a future tester time is cleared so
  historical replay remains deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_return_months` | 12 | [12] | adjacent completed monthly returns |
| `strategy_half_life_months` | 3.0 | [3.0] | fixed base-two recency half-life |
| `strategy_history_bars_d1` | 800 | [800] | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Every endpoint, interval, age, base, half-life, direction, attempt, risk, and
lifecycle value is locked. Any change requires a new card and full pipeline
run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, and include
WTI in their commodity universe. They do not claim this exponential-recency
rule works, that three months is the correct half-life, that a continuous CFD
reproduces rolling futures, or that the candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, recent shock dominance, stale trends, hard-stop
slippage, and correlation with XNG or risk assets can dominate the premise.
Exponential weighting is a descriptive formation rule, not confidence.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on endpoint leakage, wrong chronology, reversed return orientation,
  wrong age, a base other than two, half-life other than three months, wrong-
  side entry, repeated monthly attempt, missing hard stop, hold beyond forty
  days, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing lookback, base, half-life, direction,
  entry clock, stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: one tier-A peer-reviewed source with DOI, complete-paper evidence,
  durable retrieval hash, and explicit WTI membership.
- [x] R2: fixed endpoints, returns, ages, base, half-life, normalization,
  direction, attempt, hard stop, rollover, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: deterministic logarithm, power, and fixed arithmetic; no trained
  model, prohibited signal indicator, external feed, grid, or martingale.
- [x] Dedup: no exact or fuzzy identity; all same-source mechanic neighbors are
  manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, exact
  exponential-recency weighted sum, spread/quote/ATR/stop checks, and one
  fixed-risk order.
- trade_management: malformed-state repair, prior-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a manual
backtest; live, demo, shadow, optimization, or stress setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio admission; portfolio-gate edit;
or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-11 | initial source-bounded WTI exponential-recency card | G0 | APPROVED |
| v1-q01 | 2026-08-11 | deterministic V5 build, strict compile, target validation, estimator reference vectors, and P1 artifact validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-11 | APPROVED | `decisions/2026-08-11_qm5_20279_wti_expw_mom_g0.md` |
| Q01 Build Validation | 2026-08-11 | PASS | `D:/QM/reports/compile/20260811_111716/summary.csv`; `D:/QM/reports/framework/21/build_check_20260811_111759.json`; `D:/QM/reports/pipeline/QM5_20279/P1/P1_QM5_20279_result.json` |
| Q02 Baseline Screening | - | NOT QUEUED | `XTIUSD.DWX` D1 only |
