---
card_schema_version: 2
type: strategy
strategy_id: MEHLITZ-AUER-MEM-2024_XTI_R6Q7_S03
variant_id: MEHLITZ-AUER-MEM-2024_XTI_R6Q7_S03
source_id: MEHLITZ-AUER-WTI-R6Q7-2026
ea_id: QM5_20256
slug: wti-vr6-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20256_wti-vr6-mom_card.md
execution_contract_status: DRAFT
created: 2026-08-07
created_by: Research+Development
last_updated: 2026-08-07
g0_status: APPROVED
source_authors: "Julia S. Mehlitz; Benjamin R. Auer"
source_citation: "Mehlitz, J. S. and Auer, B. R. (2024), Memory-enhanced momentum in commodity futures markets, The European Journal of Finance 30(8), 773-802, DOI 10.1080/1351847X.2023.2220118."
source_citations:
  - type: peer_reviewed_paper
    citation: "Mehlitz, Julia S. and Auer, Benjamin R. (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: "Sections 3.3.1-3.3.2 and Appendix C; DOI https://doi.org/10.1080/1351847X.2023.2220118; complete open precursor review recorded in strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md"
    quality_tier: A
    role: primary
strategy_mechanic: monthly-wti-six-month-return-sign-times-q7-heteroskedastic-robust-variance-ratio-memory-state
sources:
  - "[[sources/MEHLITZ-AUER-WTI-R6Q7-2026]]"
  - "[[sources/MEHLITZ-AUER-MEM-2024]]"
concepts:
  - "[[concepts/memory-enhanced-momentum]]"
  - "[[concepts/variance-ratio]]"
  - "[[concepts/wti-structural-trend-reversal]]"
indicators:
  - "[[indicators/lo-mackinlay-variance-ratio]]"
  - "[[indicators/six-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-momentum-reversal, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202560000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated five to nine completed WTI positions per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify the published WTI R6-q7 memory state as direct crude-oil exposure distinct from the certified XAU/SP500/NDX/XNG book; only Q09 may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, six_month_return, q7_variance_ratio, heteroskedastic_robust_variance, fixed_significance_threshold, memory_direction_matrix, restart_attempt_state, risk_mode, friday_close_exception, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-07_qm5_20256_wti_vr6_mom_g0.md: tier-A peer-reviewed complete-read source with explicit WTI and source-declared R6-q7 membership; locked 33 month ends, 32 returns, six-month ranking return, q7 lag/VR/robust weights, two-sided 10% threshold, continuation/reversal matrix, persisted monthly attempt, ATR stop, rollover, and stale exit; registered XTIUSD.DWX D1 route; deterministic native arithmetic only. Dedup scanned 4,313 registry rows and 430 cards, found no exact collision, and the expected R1-q2/R3-q4 source siblings were manually resolved."
---

# QM5_20256 WTI R6-q7 Memory-Enhanced Momentum

## Hypothesis

WTI's completed six-month direction may persist only when the latest 32
monthly returns exhibit statistically significant memory across the matching
six-lag horizon. In a significant anti-persistent state, the same six-month
move may instead reverse. Applying the source-declared `R6-q7` state to WTI
tests a slow crude-oil return stream whose carrier differs from the certified
index, gold, and natural-gas book.

This is a falsifiable single-source port, not a profitability or decorrelation
claim. Q02 owns density and baseline economics. Q09 alone may measure book
overlap after the candidate survives all preceding gates.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/MEHLITZ-AUER-WTI-R6Q7-2026/source.md`. Its completely
reviewed parent records Mehlitz and Auer's peer-reviewed article and complete
open precursor chapter. The source explicitly includes WTI, links the
six-month ranking return to `q=7`, estimates the robust variance-ratio state
over 32 monthly observations, uses a fixed two-sided 10% threshold, and maps
persistence to continuation and anti-persistence to reversal.

The source does not test a standalone Darwinex continuous CFD, D1-derived
broker month ends, fixed cash risk, ATR stops, spread caps, the attempt ledger,
or the QM portfolio. No source PF, return, Sharpe ratio, drawdown, trade count,
WTI-specific result, neutrality, or correlation statistic transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker found no exact collision and the two
expected fuzzy source siblings. Manual review fixes the boundary:

- `QM5_13134_energy-vr-mom` is `R1-q2`: one-month return sign, one lag,
  `VR(2)=1+rho(1)`, and one robust term.
- `QM5_20253_wti-vr3-mom` is `R3-q4`: three-month return sign, three lags,
  weights `1.5/1.0/0.5`, and three robust terms.
- `QM5_20256` is `R6-q7`: six-month return sign, six lags, weights
  `12/7,10/7,8/7,6/7,4/7,2/7`, and their six squared robust weights.
- `QM5_20059_wti-tsmom6m` follows the six-month sign without a memory
  estimator, significance gate, anti-persistence reversal, or flat state.
- `QM5_20056_wti-dual-mom` agrees two cumulative horizons rather than testing
  the serial dependence of the return path.
- `QM5_20245_wti-vr-rsm` combines `q=2` memory with twelve binary monthly
  signs, not the cumulative source-matched `R6-q7` pair.

The ranking horizon, lag set, variance-ratio weights, robust weights, and
resulting direction path are jointly load-bearing. No current EA implements
the WTI `R6-q7` specification. Verdict:
`CLEAN_AFTER_EXPECTED_FUZZY_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; intended magic `202560000` after deterministic allocation.
- Decision clock: first processed D1 bar of each genuine broker-month
  transition.
- Formation: 33 consecutive completed broker-month endpoints defining 32
  chronological monthly log returns.
- Ranking state: cumulative latest six completed monthly log returns.
- Expected cadence: five to nine completed packages/year after warm-up; retire
  below five per full post-warm-up year.
- Runtime data: native MT5 D1 time/close, ATR, spread, quotes, positions, deal
  history, broker calendar, and contract metadata only.

## Formula

From chronological completed monthly log returns `r[0]..r[31]`, let
`d[t]=r[t]-mean(r)` and `SSE=sum(d[t]^2)`. For `k=1..6`:

```text
rho[k]   = sum(d[t] * d[t-k], t=k..31) / SSE
delta[k] = sum(d[t]^2 * d[t-k]^2, t=k..31) / SSE^2
w[k]     = 2 * (7-k) / 7
VR(7)    = 1 + sum(w[k] * rho[k], k=1..6)
theta(7) = sum(w[k]^2 * delta[k], k=1..6)
z_vr     = (VR(7)-1) / sqrt(theta(7))
R6       = sum(r[t], t=26..31)
```

Require `abs(z_vr)>1.64485362695147`. Set the trade direction to
`sign(R6)*sign(z_vr)`: persistence continues the six-month direction and
anti-persistence reverses it. Zero `R6`, an insignificant state, or invalid
arithmetic is flat.

## Rules

The following rules are the complete authorized Q02 baseline. There is no
signal-parameter sweep.

## 4. Entry Rules

1. Require exact EA ID `20256`, `XTIUSD.DWX` D1, slot 0, registered magic, and
   every baseline input locked to its declared value.
2. Evaluate only on a new D1 bar that opens a genuine new broker month; use
   completed bars only.
3. Reconstruct exactly 33 consecutive completed broker-month-end closes from
   bounded D1 history. Require positive prices, strictly increasing endpoint
   timestamps, no missing broker month, and the newest endpoint in the
   immediately preceding broker month.
4. Form exactly 32 chronological monthly log returns. Compute the mean,
   centered deviations, `SSE`, lag-one through lag-six autocorrelations, the
   fixed `q=7` weight vector, and the six robust variance terms.
5. Require finite positive `SSE` and `theta`, then require
   `abs(z_vr)>1.64485362695147`.
6. Compute `R6` as the sum of the latest six monthly log returns. A zero
   ranking return remains flat.
7. BUY when `sign(R6)*sign(z_vr)>0`; SELL when it is below zero. Persist the
   broker month as consumed after signal qualification but before news,
   spread, quote, stop, sizing, or order gates. A rejected, failed, or stopped
   qualified signal cannot retry that month.
8. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid stop geometry, volume metadata, and no owned exposure.
9. Attach one frozen `3.5*ATR(20,D1)` hard stop, size through the V5 fixed-risk
   layer, and open exactly one position. There is no take-profit.
10. An insignificant or invalid statistical state stays flat and records the
    evaluated month so restart cannot re-evaluate a partial history state.

## 5. Exit Rules

1. Close the current package on the first processed D1 bar of the next broker
   month before considering the new month's state.
2. Close after 35 elapsed calendar days as a stale guard.
3. Immediately flatten a duplicate, wrong-symbol, wrong-magic, wrong-direction,
   or missing-stop owned state.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because a valid monthly package may span weekends.
6. No intramonth signal reversal, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact `XTIUSD.DWX` D1 slot 0 or on unlocked inputs.
- Require consecutive completed month endpoints, positive closes, valid
  logarithms, nonzero return and robust variance, registered magic, valid
  attempt state, acceptable spread, executable quote, ATR, stop, and volume
  metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures curve, external file/API, inventory, volume,
  open interest, analyst input, trained output, optimizer result, or portfolio
  state.

## 7. Trade Management Rules

- The EA may own exactly one `XTIUSD.DWX` position under slot 0.
- Month-transition and stale exits run before any entry-only news gate.
- Restart recovery combines a terminal-persistent evaluated-month marker with
  owned position and deal history; future-dated tester state is cleared.
- A broker stop, failed qualified order, or lifecycle exit cannot cause a
  same-month retry.
- No randomness, adaptive fit, external state, partial close, scale-in, or
  pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_monthly_returns` | 32 | [32] | robust memory sample |
| `strategy_ranking_months` | 6 | [6] | source ranking horizon |
| `strategy_vr_q` | 7 | [7] | source-matched variance-ratio order |
| `strategy_significance_z` | 1.64485362695147 | [1.64485362695147] | source two-sided 10% boundary |
| `strategy_history_bars` | 1200 | [1200] | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | order deviation |

Changing the ranking horizon, `q`, lag set, weights, critical value, memory
window, direction matrix, carrier, stop, holding clock, or retry policy
requires a new card and full pipeline run.

## Author Claims

Mehlitz and Auer define memory-enhanced momentum across commodity futures,
explicitly include WTI, and declare the `R6-q7` configuration. They do not
claim that a standalone Darwinex WTI CFD port is profitable, frequent enough,
or diversifying. Q02 and later gates are the only strategy evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: a 33-month warm-up, significance-gate
sparsity, six-lag estimator noise, single-energy concentration, CFD roll and
financing, gaps, hard-stop slippage, and post-publication decay may dominate
the intended state. Direct crude exposure is economically different from the
incumbent assets but does not guarantee low realized portfolio correlation.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on missing or nonconsecutive endpoints, wrong R6 orientation, wrong
  lag/weight set, wrong robust statistic, entry without a significant state,
  wrong continuation/reversal map, repeated month attempt, missing hard stop,
  invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a horizon, lag order, threshold,
  direction, stop, hold, spread cap, or retry policy.

## Strategy Allowability Check

- [x] R1: tier-A peer-reviewed source with complete-read open precursor; WTI
  and `R6-q7` are explicit.
- [x] R2: fixed endpoints, formulas, lag/weight set, threshold, direction,
  risk, hard stop, attempt state, rollover, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 route; no external runtime data.
- [x] R4: deterministic logarithm/calendar/statistic/ATR arithmetic; no banned
  signal indicator, adaptive fit, grid, martingale, or pyramid.
- [x] Dedup: no exact collision; expected source siblings manually resolved.

## Framework Alignment

- no_trade: exact symbol/D1/EA/slot, locked inputs, news/Friday contract,
  magic, and cheap parameter guards.
- trade_entry: month-end reconstruction, `R6-q7` statistic, persisted attempt,
  spread/quote/ATR/stop checks, sizing, and one order.
- trade_management: owned-state validation, next-month close, stale close, and
  malformed-state repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, build, strict compile/Q01, one non-live
`RISK_FIXED` backtest setfile, and one paced Q02 handoff. It does not authorize
a manual backtest; live, demo, shadow, stress, or optimization setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio admission;
portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-07 | initial source-bounded WTI R6-q7 card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-07 | APPROVED | `decisions/2026-08-07_qm5_20256_wti_vr6_mom_g0.md` |
| Q01 Build Validation | 2026-08-07 | NOT_RUN | pending deterministic allocation and build |
| Q02 Baseline Screening | 2026-08-07 | NOT_ENQUEUED | pending Q01 PASS and paced-fleet capacity |
