---
card_schema_version: 2
type: strategy
strategy_id: KISS-RSJ-2025_XTI_TS_S03
variant_id: KISS-RSJ-2025_XTI_TS_S03
source_id: KISS-WTI-RSJ-REV-2026
ea_id: QM5_20289
slug: wti-rsj-rev
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20289_wti-rsj-rev_card.md
execution_contract_status: DRAFT
created: 2026-08-12
created_by: Research+Development
last_updated: 2026-08-12
g0_status: APPROVED
source_author: "Tamas Kiss; Igor Ferreira Batista Martins"
source_authors: "Tamas Kiss; Igor Ferreira Batista Martins"
source_citation: "Kiss and Ferreira Batista Martins (2025), Good Volatility, Bad Volatility and the Cross Section of Commodity Returns, Finance Research Letters 86 Part D, 108656, DOI 10.1016/j.frl.2025.108656."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Kiss, T., and Ferreira Batista Martins, I. (2025). Good Volatility, Bad Volatility and the Cross Section of Commodity Returns. Finance Research Letters 86 Part D, 108656."
    location: "DOI https://doi.org/10.1016/j.frl.2025.108656; complete-paper evidence strategy-seeds/sources/KISS-RSJ-2025/source.md; bounded extraction strategy-seeds/sources/KISS-WTI-RSJ-REV-2026/source.md"
    quality_tier: A
    role: primary_signed_semivariance_estimator_negative_premium_and_monthly_cadence
strategy_mechanic: monthly-wti-prior-complete-month-absolute-rsj-zero-pivot-reversal
sources:
  - "[[sources/KISS-WTI-RSJ-REV-2026]]"
concepts:
  - "[[concepts/realized-signed-semivariance]]"
  - "[[concepts/asymmetric-volatility-premium]]"
  - "[[concepts/crude-oil-structural-reversal]]"
indicators:
  - "[[indicators/realized-semivariance]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, realized-semivariance, asymmetric-volatility, time-series-reversal, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202890000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year after a complete prior month because only exact-zero or invalid RSJ states stay flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02_ENQUEUED
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify an outright WTI monthly reversal driven by the absolute balance of upside and downside realized semivariance, unlike the existing XTI/XNG and XAU/XAG relative-rank baskets, ordinary return trend/reversal, calendar, event, and XNG RSI neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [complete_broker_month_reconstruction, within_month_return_inclusion, rsj_normalization, absolute_zero_pivot, reversal_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete-read peer-reviewed commodity-RSJ source with explicit WTI membership; R2 exact prior-month daily returns, semivariances, normalized zero-pivot reversal direction and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic with no trained output or prohibited signal indicator; no exact identity and source-family fuzzy neighbors manually resolved."
---

# QM5_20289 WTI Signed-Semivariance Reversal

## Hypothesis

Commodity producers and consumers hedge asymmetrically around gains and
losses, so the balance between upside and downside realized variance can alter
the next required futures risk premium. This card tests a single-WTI time-
series carrier of the source's negative RSJ relation: buy after the prior
complete month was dominated by downside semivariance and sell after it was
dominated by upside semivariance.

The direct crude-oil carrier and monthly asymmetric-volatility clock differ
from the certified XAU, SP500, NDX, and XNG book. That does not prove
decorrelation, profitability, or portfolio suitability. Q02 owns density and
baseline economics; unchanged downstream gates, including Q09, own robustness
and realized overlap.

## Source Traceability And Claim Boundary

The single trading source of record is the governed bounded packet
`strategy-seeds/sources/KISS-WTI-RSJ-REV-2026/source.md`. Its complete-read
parent is Kiss and Ferreira Batista Martins (2025), a peer-reviewed *Finance
Research Letters* paper defining normalized signed semivariance, documenting
a negative cross-sectional RSJ premium, and including WTI among 36 commodity
futures.

The paper does not test an absolute zero-pivot time-series rule. The zero
pivot, outright WTI direction, log-return choice, Darwinex continuous CFD,
broker-month reconstruction, fixed-dollar sizing, ATR hard stop, spread cap,
attempt ledger, and lifecycle controls are transparent QM hypotheses and
mechanizations. No source return, alpha, drawdown, WTI-specific result, trade
count, cost, CFD equivalence, or correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,354 EA-registry rows and 466 root cards. It
found no exact identity and two expected source-family fuzzy matches. Manual
family review separated the closest neighbors:

- `QM5_13129_energy-rsj` ranks simultaneous XTI and XNG values, buys the lower
  rank, shorts the higher rank, and maintains a two-leg package. This card has
  one WTI state, no rank or orphan, and trades absolute RSJ around zero. The
  parent's negative Q02 economics and Q04 failure are disclosed, not repaired
  or inherited.
- `QM5_20234_xauxag-rsj` is a paired precious-metal rank carrier with two
  magics and equal risk halves; it neither carries outright WTI nor maps
  absolute RSJ around zero.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only RSI pullback
  above a slow filter, not a monthly normalized signed-semivariance state.
- WTI cumulative, sign, regression, rank, robust-location, path-efficiency,
  variance-ratio, ordinary reversal, calendar, event, and breakout EAs use
  different information objects, directions, or clocks.

The one complete month, within-month log returns, normalized semivariance
difference, fixed zero pivot, low-RSJ long/high-RSJ short time-series map,
outright WTI carrier, and monthly lifecycle are jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_CROSS_SECTIONAL_TO_TIME_SERIES_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202890000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: adjacent D1 log returns wholly contained in the immediately
  preceding complete broker month.
- Holding clock: next broker-month boundary, with a forty-calendar-day guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

For adjacent positive finite D1 closes whose two timestamps both lie in the
immediately preceding broker month:

```text
r[d]     = ln(close[d] / close[d-1])
RV_plus  = sum(r[d]^2 where r[d] > 0)
RV_minus = sum(r[d]^2 where r[d] < 0)
total    = RV_plus + RV_minus
RSJ      = (RV_plus - RV_minus) / total
```

Require 15 through 25 returns, positive finite total variance, finite RSJ, and
`-1-1e-12 <= RSJ <= 1+1e-12`. BUY when `RSJ < 0`; SELL when `RSJ > 0`; exact
zero or invalid state remains flat. The score's magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a cross-sectional rank, raw return, cumulative
return, RSI, moving average, oscillator, calendar direction, external series,
or previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20289`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Load bounded completed-D1 history. Select the immediately prior broker
   month and include a return only when both adjacent bar timestamps belong to
   that month. Reject current-month leakage, boundary-crossing returns, gaps,
   duplicates, non-increasing time, or a nonconsecutive prior month.
6. Require 15 through 25 adjacent returns. Positive and negative returns add
   their squares to separate sums; exact-zero returns add to neither sum but
   remain counted observations.
7. Require finite nonnegative semivariances and positive total variance.
   Compute their normalized difference and require the result in `[-1,1]`
   within `1e-12`.
8. Buy when RSJ is negative and sell when positive; exact zero stays flat. Do
   not rank, demean, annualize, threshold-fit, follow the RSJ sign, or size risk
   from its magnitude.
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
6. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive month state, current-month leakage, boundary-
  crossing return, observation count outside 15-25, nonpositive close,
  nonfinite return, nonpositive total variance, RSJ outside bounds, exact-zero
  signal, excessive spread, invalid quote, unavailable ATR, invalid stop, or
  invalid metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, analyst forecast, trained output, optimizer result, or
  portfolio state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a prior-run marker
  so historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_months` | 1 | [1] | immediately prior complete broker month |
| `strategy_min_return_observations` | 15 | [15] | minimum contained D1 log returns |
| `strategy_max_return_observations` | 25 | [25] | maximum contained D1 log returns |
| `strategy_rsj_tolerance` | 1e-12 | [1e-12] | normalized-statistic bound tolerance |
| `strategy_history_bars_d1` | 80 | [80] | bounded D1 month reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values and the month selection, return inclusion, log-return formula,
semivariance normalization, zero pivot, reversal direction, entry clock, risk,
stop, hold, and no-retry policy are locked. Any change requires a new card and
pipeline.

## Author Claims

Kiss and Ferreira Batista Martins define RSJ, document a negative RSJ premium
across commodity-futures portfolios, and include WTI in their universe. They
do not claim that absolute zero predicts WTI, that a continuous CFD reproduces
collateralized futures, or that this candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, one-month reversal failure, volatility clustering,
hard-stop slippage, session-boundary sensitivity, and correlation with XNG or
risk assets can dominate the premise. The existing XTI/XNG source-family
carrier produced negative Q02 economics and later failed Q04; this adverse
evidence is disclosed and no efficacy transfers.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong month selection, boundary-crossing or current-month returns,
  wrong return orientation, count outside 15-25, negative semivariance,
  nonpositive total, missing normalization, alternate pivot, trend-following
  direction, repeated attempt, hold beyond forty days, missing hard stop,
  invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing window, pivot, estimator, direction,
  entry clock, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | One Tier-A peer-reviewed trading source with DOI, complete-paper evidence, durable packet hash, and explicit WTI membership. |
| R2 | PASS | Fixed prior month, contained returns, semivariances, normalization, pivot, direction, attempt, hard stop, rollover, and stale exit. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 plus native V5 execution state only. |
| R4 | PASS | Deterministic arithmetic only; no trained model, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; cross-sectional RSJ baskets and all WTI
  neighbors were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, prior-month D1 reconstruction,
  contained returns, RSJ reversal state, spread/quote/ATR/stop checks, and one
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
| v1 | 2026-08-12 | initial source-bounded WTI absolute-RSJ reversal card | G0 | APPROVED |
| v2 | 2026-08-12 | initial V5 implementation and validation | Q01 | PASS |
| v3 | 2026-08-12 | paced baseline handoff below factory CPU ceiling | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20289_wti_rsj_rev_g0.md` |
| Q01 Build Validation | 2026-08-12 | PASS | `D:/QM/reports/compile/20260812_074558/summary.csv`; `D:/QM/reports/framework/21/build_check_20260812_074442.json`; `D:/QM/reports/pipeline/QM5_20289/P1/P1_QM5_20289_result.json` |
| Q02 Baseline Screening | 2026-08-12 | ENQUEUED; pending at immediate readback, attempt 0, no verdict | work item `41d6f237-cc5e-46ec-8048-1722c398a110`; `docs/ops/evidence/2026-08-12_qm5_20289_wti_rsj_rev_q01_q02_enqueue.md` |
