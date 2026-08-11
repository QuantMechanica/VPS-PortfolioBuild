---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_HUBER12_S33
variant_id: MOP-TSMOM-2012_XTI_HUBER12_S33
source_id: MOP-WTI-HUBER-2026
ea_id: QM5_20285
slug: wti-huber-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20285_wti-huber-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-12
created_by: Research+Development
last_updated: 2026-08-12
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_and_monthly_cadence
  - type: peer_reviewed_statistics_paper
    citation: "Huber, P. J. (1964). Robust Estimation of a Location Parameter. The Annals of Mathematical Statistics 35(1), 73-101."
    location: "DOI https://doi.org/10.1214/aoms/1177703732"
    quality_tier: A
    role: bounded_influence_location_lineage_only
strategy_mechanic: monthly-wti-fixed-step-huber-m-location-of-twelve-completed-monthly-log-returns
sources:
  - "[[sources/MOP-WTI-HUBER-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/huber-m-location]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, robust-location, bounded-influence, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202850000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year after thirteen completed month ends because only nonpositive-MAD, exact-zero, or invalid states stay flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct WTI monthly robust trend whose fixed-scale 32-step Huber re-centering differs from cumulative, median, trim, Winsor, MAD-cap, quartile-trimean, pairwise-pseudomedian, sign/vote/run, recency-weighted, regression, rank, path-efficiency, and skip-month estimators; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, chronological_log_return_orientation, even_sample_median, even_sample_mad, mad_normalization, frozen_huber_delta, residual_weight_equation, exactly_32_updates, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-12_qm5_20285_wti_huber_mom_g0.md: R1 one complete-read peer-reviewed WTI trading source plus bounded-influence statistical lineage; R2 fixed thirteen endpoints, twelve adjacent returns, median/MAD, scale, tuning, weights, 32 updates, direction, and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic. The canonical checker found no exact identity and manual review separated the Winsor fuzzy match and closest MAD-cap system."
---

# QM5_20285 WTI Fixed-Step Huber Return Trend

## Hypothesis

WTI can sustain slow directional regimes as production, capital investment,
inventories, transport, refining, hedging, and demand adjust. A cumulative
twelve-month return can be dominated by one oil shock; fixed trimming or
capping changes observations without re-estimating the center. This card tests
a bounded-influence return location that repeatedly re-centers its weights
while freezing a pre-declared robust scale.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. That does not prove decorrelation,
profitability, or portfolio suitability. Q02 owns density and baseline
economics; unchanged downstream gates, including Q09, own robustness and
realized overlap.

## Source Traceability And Claim Boundary

The trading source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper documenting monthly own-return continuation over
the first twelve lags and including WTI among its commodity futures.

Huber (1964) supplies statistical lineage for bounded-influence location only.
Neither paper tests this exact statistic. The scale normalization, tuning,
fixed update count, Darwinex continuous CFD, broker-month reconstruction,
fixed-dollar sizing, ATR hard stop, spread cap, attempt ledger, and lifecycle
controls are transparent QM mechanizations. No source return, alpha, Sharpe
ratio, drawdown, WTI-specific result, trade count, cost, CFD equivalence, or
correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,350 EA-registry rows and 461 root cards. It
found no exact identity and surfaced one shared-source fuzzy match:

- `QM5_20277_wti-winsor-mom` replaces fixed order-statistic tails once and
  takes one mean; it has no data-scaled influence weights or re-centering;
- `QM5_20282_wti-madcap-mom` freezes the median as a three-raw-MAD cap center,
  clips observations once, and takes an equal-weight mean; this card freezes
  only `delta` and changes weights around the evolving location for 32 steps;
- `QM5_20269`, `QM5_20270`, and `QM5_20283` use a raw median, fixed trim, and
  quartile trimean; and
- cumulative, pairwise-pseudomedian, sign/vote/run, weighting, regression,
  rank, path-efficiency, and skip-month systems use different functionals or
  endpoint objects.

The two sorts, even-sample median/MAD, `1.4826` normalization, `1.5` tuning,
frozen delta, residual-dependent weights, exactly 32 re-centering updates,
exact-zero rejection, consumed attempt, and monthly renewal are jointly
load-bearing. Verdict:
`CLEAN_AFTER_WINSOR_AND_MADCAP_MECHANIC_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202850000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes forming
  twelve chronological adjacent monthly log returns.
- Signal state: sign of the locked 32-step Huber reweighted location.
- Holding clock: next broker-month boundary, with a forty-calendar-day guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `C[0]..C[12]` be completed month-end closes
from months `t-13..t-1`, ordered oldest to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
s = sort_ascending(r)
m = (s[5] + s[6]) / 2
d[i] = abs(r[i] - m)
a = sort_ascending(d)
MAD = (a[5] + a[6]) / 2
delta = 1.5 * 1.4826 * MAD

mu[0] = m
for j = 0..31:
  residual = abs(r[i] - mu[j])
  w[i] = 1 if residual <= delta else delta / residual
  mu[j+1] = sum(w[i] * r[i]) / sum(w[i])
```

BUY when `mu[32] > 0`. SELL when `mu[32] < 0`. An exact-zero, nonpositive-
MAD, or invalid state remains flat. The statistic's magnitude never scales
risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a cumulative return, arithmetic mean, raw median,
trimmed mean, Winsorized mean, MAD-capped mean, quartile trimean, pairwise
pseudomedian, sign statistic, vote, regression, rank, moving average,
oscillator, calendar direction, external series, or previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20285`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from bounded D1
   history; require the newest endpoint to be the immediately prior month and
   every older month key to be consecutive.
6. Keep endpoints oldest to newest; require positive finite closes and
   strictly increasing timestamps. Compute exactly twelve adjacent finite log
   returns from pairs `(0,1)` through `(11,12)`.
7. Sort a copy and set the even median from indexes 5 and 6. Sort the twelve
   absolute deviations from that median and set raw MAD from indexes 5 and 6.
8. Reject nonpositive or invalid MAD. Freeze
   `delta = 1.5 * 1.4826 * MAD`; initialize `mu` at the median.
9. Run exactly 32 updates. At each update weight residuals inside delta by 1
   and outside delta by `delta/residual`, then set `mu` to the weighted return
   mean. Reject invalid/nonpositive total weight or invalid new location.
10. Buy when final `mu` is positive and sell when negative; exact zero stays
    flat. No early convergence exit or alternate center is allowed.
11. Require spread in `[0,1500]` points, executable quote, completed
    `ATR(20,D1)`, valid point/digit/volume metadata, and fixed-risk sizing.
12. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
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
  malformed or nonconsecutive endpoints, current-month leakage, nonpositive
  close, invalid return, wrong sort/median/MAD, nonpositive scale, mutable
  delta, wrong weight/update, exact-zero signal, excessive spread, invalid
  quote, unavailable ATR, invalid stop, or invalid metadata.
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
| `strategy_return_months` | 12 | [12] | adjacent completed monthly returns |
| `strategy_huber_tuning` | 1.5 | [1.5] | fixed normalized influence threshold |
| `strategy_mad_normalizer` | 1.4826 | [1.4826] | fixed raw-MAD scale normalization |
| `strategy_huber_steps` | 32 | [32] | exact re-centering update count |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values and the endpoint/return counts, median/MAD convention, scale,
weight equation, update ordering, direction, entry clock, risk, stop, hold,
and no-retry policy are locked. Any change requires a new card and pipeline.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, and identify
WTI in their commodity universe. Huber documents a robust location family.
The authors do not claim this exact estimator works, that a continuous CFD
reproduces rolling futures, or that the candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, stale historical trends, hard-stop slippage,
small-sample scale instability, and correlation with XNG or risk assets can
dominate the premise. Bounded influence is descriptive and does not guarantee
stable edge or neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  wrong adjacent pairs or orientation, wrong median/MAD/scale, mutable delta,
  wrong weight formula, update count other than 32, fallback after exact zero,
  wrong-side entry, repeated attempt, hold beyond forty days, missing hard
  stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing horizon, estimator, tuning, normalizer,
  iteration count, direction, entry clock, stop, hold, spread, retry, or
  carrier.

## Strategy Allowability Check

- [x] R1: PASS. Tier-A peer-reviewed trading source with DOI, complete-paper
  evidence, durable retrieval hash, and explicit WTI membership; statistical
  lineage is separately bounded.
- [x] R2: PASS. Fixed endpoints, returns, median/MAD, constants, weights,
  update count, direction, attempt, hard stop, rollover, and stale exit.
- [x] R3: PASS. Registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: PASS. Deterministic logarithm, sorting, and fixed arithmetic; no
  trained model, prohibited signal indicator, external feed, grid, or
  martingale.
- [x] Dedup: no exact identity; Winsor and MAD-cap neighbors plus other robust
  and trend estimators were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, adjacent
  returns, median/MAD, fixed-step Huber location, spread/quote/ATR/stop checks,
  and one fixed-risk order.
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
| v1 | 2026-08-12 | initial source-bounded WTI fixed-step Huber card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20285_wti_huber_mom_g0.md` |
| Q01 Build Validation | - | NOT_RUN | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |
