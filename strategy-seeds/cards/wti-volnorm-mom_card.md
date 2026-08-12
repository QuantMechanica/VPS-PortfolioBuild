---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_VOLNORM12_S36
variant_id: MOP-TSMOM-2012_XTI_VOLNORM12_S36
source_id: MOP-WTI-VOLNORM-2026
ea_id: QM5_20288
slug: wti-volnorm-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20288_wti-volnorm-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-12
created_by: Research+Development
last_updated: 2026-08-12
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-VOLNORM-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_monthly_cadence_and_volatility_scaling_lineage
strategy_mechanic: monthly-wti-equal-mean-of-twelve-within-month-realized-daily-l2-normalized-log-returns
sources:
  - "[[sources/MOP-WTI-VOLNORM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/realized-path-normalization]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/realized-daily-l2-norm]]"
  - "[[indicators/atr]]"
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202880000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year after thirteen completed month ends and complete daily paths; Q02 must prove at least five completed positions/year or retire."
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
review_focus: "Falsify a direct WTI monthly trend whose twelve historical month returns are separately normalized by their own completed daily L2 paths and then weighted equally, unlike cumulative, path-efficiency, variance-ratio, volatility-gated, robust-location, and sign-vote neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, completed_daily_path_partition, endpoint_sum_identity, separate_month_l2_normalization, equal_month_weighting, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 one complete-read peer-reviewed WTI source; R2 exact endpoints, within-month daily paths, separate L2 norms, endpoint identities, equal-month mean, direction and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic with no trained output or prohibited signal indicator; canonical and manual dedup clean."
---

# QM5_20288 WTI Volatility-Normalized Monthly Trend

## Hypothesis

WTI can sustain slow directional regimes as production, capital investment,
inventories, transport, refining, hedging, and demand adjust. A cumulative
twelve-month return or an arithmetic mean of monthly returns can be dominated
by one high-volatility oil shock. This card instead gives every completed
broker month equal influence after scaling its endpoint return by the L2 norm
of its own completed daily path. Directionally coherent months retain more
influence than noisy months without changing the fixed trade-risk budget.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The single trading source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-VOLNORM-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper documenting monthly own-return continuation over
the first twelve lags, volatility-scaled positions, and WTI membership in the
commodity universe.

The source does not normalize each historical monthly return by its own
realized daily L2 path. That normalization and the equal-month mean are
transparent QM hypotheses. The Darwinex continuous CFD, broker-month path
reconstruction, fixed-dollar sizing, ATR hard stop, spread cap, attempt
ledger, and lifecycle controls are also QM mechanizations. No source return,
alpha, drawdown, WTI-specific result, trade count, cost, CFD equivalence, or
correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,353 EA-registry rows and 465 root cards. It
found no exact identity and no fuzzy match above threshold. Manual family
review separated the closest neighbors:

- `QM5_20274_wti-path-eff` divides one twelve-month net return by the L1 sum
  of twelve absolute monthly returns, then requires a fixed threshold. This
  card divides each month separately by its own daily L2 path, weights the
  twelve normalized months equally, and applies no threshold.
- `QM5_20245`, `QM5_20253`, `QM5_20256`, and `QM5_20257` estimate fixed-
  horizon variance-ratio memory states. They do not normalize twelve separate
  monthly endpoint returns by their realized daily paths.
- `QM5_13049_xti-1w-mom-vol` follows a five-day return only behind a separate
  low-volatility gate. It has neither the monthly normalized signal object nor
  the twelve-month equal-weight aggregate.
- Cumulative, raw-return median, trim/Winsor, iterative robust-location,
  recency-weighted, regression, rank, sign/run/vote, block, and skip-month
  systems use different functionals, observation units, or weights.

The twelve fixed broker-month intervals, completed daily paths, separate L2
denominator per month, endpoint-sum identity, equal normalized-month weights,
and sign of the final arithmetic mean are jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_PATH_AND_VOLATILITY_NEIGHBOR_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202880000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes plus every
  intervening completed D1 close-to-close return.
- Aggregation: twelve separately daily-L2-normalized monthly returns with one-
  twelfth weight each.
- Holding clock: next broker-month boundary, with a forty-calendar-day guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `C[0]..C[12]` be completed month-end closes
from months `t-13..t-1`, ordered oldest to newest. For month interval `m`, let
`P[m,0]=C[m]`, `P[m,n[m]]=C[m+1]`, and include each intervening completed D1
close in strict timestamp order:

```text
d[m,j] = ln(P[m,j+1] / P[m,j]), j = 0..n[m]-1
r[m]   = sum_j d[m,j]
e[m]   = ln(C[m+1] / C[m])
v[m]   = sqrt(sum_j d[m,j]^2)
u[m]   = r[m] / v[m]
score  = sum_m u[m] / 12
```

Require `15 <= n[m] <= 25`, `v[m] > 0`, finite arithmetic, and
`abs(r[m]-e[m]) <= 1e-10` for every month. BUY when `score > 0`. SELL when
`score < 0`. Exact zero or any invalid state remains flat. The score's
magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a cumulative return, sample standard deviation,
variance ratio, path-efficiency ratio, raw-return median, trimmed or
Winsorized mean, robust location, sign vote, regression, rank score, moving
average, oscillator, calendar direction, external series, or prior result.

## 4. Entry Rules

1. Require exact EA ID `20288`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Load a bounded completed-D1 history and reconstruct exactly thirteen
   consecutive month-end closes. Require the newest endpoint to be the
   immediately prior broker month, positive finite closes, increasing
   timestamps, and no current-month leakage.
6. Partition every close-to-close D1 return between adjacent endpoints into
   exactly one of twelve month intervals. Each interval must contain fifteen
   to twenty-five returns with no gap, overlap, duplication, or omission.
7. For each interval compute the direct endpoint log return, chronological
   daily log-return sum, and square root of the undemeaned sum of squared daily
   returns. Reject nonfinite values, a nonpositive norm, or endpoint identity
   error above `1e-10`.
8. Divide each monthly sum by only its own L2 norm, add all twelve normalized
   states with equal weight, and divide by exactly twelve. Do not annualize,
   demean, clip, threshold, rank, vote, or scale risk by the result.
9. Buy when the mean is positive and sell when negative; exact zero stays
   flat. No alternate statistic or direction is allowed.
10. Require spread in `[0,1500]` points, executable quote, completed
    `ATR(20,D1)`, valid point/digit/volume metadata, and fixed-risk sizing.
11. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
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
  malformed/nonconsecutive endpoints, current-month leakage, invalid path
  partition, interval count outside fifteen to twenty-five, nonpositive price,
  invalid daily return, nonpositive L2 norm, endpoint identity failure,
  exact-zero signal, excessive spread, invalid quote, unavailable ATR, invalid
  stop, or invalid metadata.
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
| `strategy_return_months` | 12 | [12] | fixed normalized broker-month intervals |
| `strategy_min_daily_returns` | 15 | [15] | minimum close-to-close returns per interval |
| `strategy_max_daily_returns` | 25 | [25] | maximum close-to-close returns per interval |
| `strategy_endpoint_tolerance` | 1e-10 | [1e-10] | daily-sum versus endpoint-return identity |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 path reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values plus endpoint and interval counts, daily-return inclusion,
undemeaned L2 formula, endpoint identity, equal-month weighting, direction,
entry clock, risk, stop, hold, and no-retry policy are locked. Any change
requires a new card and pipeline.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, use ex-ante
volatility-scaled positions, and identify WTI in their commodity universe.
They do not claim this historical within-month normalization works, that a
continuous CFD reproduces rolling futures, or that the candidate diversifies
the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, stale slow trends, hard-stop slippage, monthly path
gaps, sensitivity to daily-session construction, and correlation with XNG or
risk assets can dominate the premise. Equal normalized-month weights do not
guarantee edge, stationarity, or neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  wrong daily-pair orientation, overlap/omission, interval count outside
  fifteen to twenty-five, demeaning or annualization, nonpositive L2 norm,
  endpoint identity error, unequal month weight, alternate threshold or
  statistic, wrong-side entry, repeated attempt, hold beyond forty days,
  missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing horizon, path normalization, interval
  bounds, weighting, direction, entry clock, stop, hold, spread, retry, or
  carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | One canonical Tier-A peer-reviewed trading source with DOI, complete-paper evidence, durable retrieval hash, and explicit WTI membership. |
| R2 | PASS | Fixed endpoints, daily paths, L2 normalization, identity check, equal mean, direction, attempt, hard stop, rollover, and stale exit. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 plus native V5 execution state only. |
| R4 | PASS | Deterministic logarithm, addition, multiplication, square root, and division; no trained model, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact or fuzzy identity; path-efficiency, variance-ratio,
  weekly low-volatility, robust-location, and other WTI neighbors were
  manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, completed D1 path reconstruction,
  month partition, endpoint identities, separate L2 normalizations, equal
  mean, spread/quote/ATR/stop checks, and one fixed-risk order.
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
| v1 | 2026-08-12 | initial source-bounded WTI volatility-normalized monthly trend card | G0 | APPROVED |
| v1-q01 | 2026-08-12 | deterministic V5 build, strict compile, target validation, and volatility-normalized statistic vectors | Q01 | PASS |
| v1-q02 | 2026-08-12 | one paced current-binary WTI handoff below the factory CPU ceiling | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20288_wti_volnorm_mom_g0.md` |
| Q01 Build Validation | 2026-08-12 | PASS | `D:/QM/reports/compile/20260812_060749/summary.csv`; `D:/QM/reports/framework/21/build_check_20260812_060748.json`; `D:/QM/reports/pipeline/QM5_20288/P1/P1_QM5_20288_result.json` |
| Q02 Baseline Screening | 2026-08-12 | ENQUEUED; pending at immediate readback, attempt 0, no verdict | work item `9714bc6b-d11d-485e-b359-6e6cfa2c2ec5`; `docs/ops/evidence/2026-08-12_qm5_20288_wti_volnorm_mom_q01_q02_enqueue.md` |
