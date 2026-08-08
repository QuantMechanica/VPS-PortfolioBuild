---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XNG_MK12_S17
variant_id: MOP-TSMOM-2012_XNG_MK12_S17
source_id: MOP-XNG-RANKTREND-2026
ea_id: QM5_20267
slug: xng-rank-trend
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20267_xng-rank-trend_card.md
execution_contract_status: DRAFT
created: 2026-08-08
created_by: Research+Development
last_updated: 2026-08-08
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-XNG-RANKTREND-2026/source.md"
    quality_tier: A
    role: primary_own_price_trend_and_monthly_cadence
strategy_mechanic: monthly-xng-thirteen-month-end-mann-kendall-pairwise-rank-trend-with-fixed-score-gate
sources:
  - "[[sources/MOP-XNG-RANKTREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/rank-trend]]"
  - "[[concepts/natural-gas-structural-trend]]"
indicators:
  - "[[indicators/mann-kendall-score]]"
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, structural-trend, rank-statistic, path-consistency, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 202670000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 5-9 completed monthly XNG positions/year after thirteen completed month ends; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a slow symmetric XNG ordinal path-trend whose all-pairs ordering ignores return magnitude and differs from the certified QM5_12567 daily RSI pullback; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, chronological_pair_orientation, tie_rejection, fixed_rank_boundary, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-08_qm5_20267_xng_rank_trend_g0.md: R1 complete-read peer-reviewed natural-gas source lineage; R2 fixed all-pairs score and lifecycle; R3 registered XNG D1; R4 deterministic native arithmetic. Exact XNG identity is dedup-clean and the same-source WTI carrier is a locked, parameter-pure template."
---

# QM5_20267 XNG Pairwise Rank Trend

## Hypothesis

Natural gas can sustain slow directional regimes as weather, storage,
production, LNG flows, infrastructure, fuel switching, and demand adjust. A
twelve-month endpoint return can be dominated by one jump, while an OLS path
gate remains sensitive to the magnitudes and squared residuals of extreme gas
moves. This card instead asks whether newer monthly endpoints tend to rank
above or below older endpoints across every pair.

The candidate deliberately uses a slow, symmetric monthly trend state rather
than `QM5_12567`'s long-only daily RSI(2) pullback. That mechanical difference
does not prove decorrelation, profitability, or portfolio suitability. Q02 owns
density and economics; unchanged downstream gates, including Q09, own
robustness and realized overlap with the certified XNG sleeve and the rest of
the XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The source of record is the governed bounded packet
`strategy-seeds/sources/MOP-XNG-RANKTREND-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper that documents monthly own-return continuation
through twelve lags and includes natural gas in its commodity-futures universe.

The source does not use a Mann-Kendall statistic or an ordinal score gate. The
all-pairs rank path, fixed threshold, Darwinex continuous CFD, broker-month
reconstruction, no-tie rule, fixed-dollar sizing, ATR hard stop, spread cap,
attempt ledger, and lifecycle controls are transparent QM mechanizations. No
source return, alpha, Sharpe ratio, drawdown, trade count, cost, CFD equivalence,
or correlation statistic is imported.

## Non-Duplicate Decision

The 2026-08-08 pre-allocation review found no `xng-rank-trend` slug,
`MOP-TSMOM-2012_XNG_MK12_S17` identity, or XNG Mann-Kendall/all-pairs rank rule
in the EA registry, intake cards, approved cards, decisions, or source packets.
`QM5_20264_wti-rank-trend` is the same locked statistic on WTI; it is the
parameter-pure implementation template, not an XNG build or a certified port.

The nearest XNG systems use one endpoint return, adjacent monthly-return signs,
votes across cumulative-return horizons, OLS slope plus `R^2`, moving averages,
channels, variance ratios, calendar states, events, or daily oscillators. In
particular:

- `QM5_20262_xng-lr-trend` uses log-price OLS slope and an `R^2` gate, so return
  magnitudes and squared residuals are load-bearing.
- `QM5_20259_xng-mom-vote` votes on one-, three-, and twelve-month cumulative
  return signs.
- `QM5_13116_xng-signmom` counts adjacent monthly-return signs.
- `QM5_12804_xng-tsmom12m-atr` uses one endpoint return plus an ATR/price
  corridor.
- `QM5_12567_cum-rsi2-commodity` uses a daily, long-only two-day RSI pullback,
  slow alignment filter, and five-bar maximum hold.

None compares all 78 chronological endpoint pairs while discarding move
magnitude. The XNG carrier, thirteen endpoints, all-pairs ordering, no-tie
rule, integer score, fixed `abs(S) >= 28` boundary, consumed attempt, and
monthly renewal are jointly load-bearing. Verdict:
`CLEAN_XNG_IDENTITY_WITH_LOCKED_CROSS_CARRIER_TEMPLATE`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XNGUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202670000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes.
- Holding clock: next broker-month boundary, with a forty-calendar-day stale
  guard.
- Expected cadence: five to nine completed positions per full post-warm-up
  year; retire below five.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `P_0..P_12` be completed month-end closes from
months `t-13..t-1`, ordered oldest to newest. Require positive finite closes
and no exact ties. Define:

```text
S = sum(sign(P_j - P_i)) for all 0 <= i < j <= 12
tau = S / 78
```

There are exactly 78 pairs. Continue only when `abs(S) >= 28`. BUY when
`S > 0`; SELL when `S < 0`. A weak, tied, malformed, or unavailable state
consumes the month flat. The fixed boundary corresponds to a continuity-
corrected no-tie normal score of approximately 1.647 for thirteen observations;
it is not selected from a QM result.

## Rules

These are the complete authorized baseline. There is no parameter sweep and no
fallback to endpoint return, adjacent-sign count, OLS, a moving average,
oscillator, calendar direction, external series, or previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20267`, `XNGUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. No retry is allowed that month.
4. Reject an owned position or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from bounded D1
   history. Require the newest endpoint to be the immediately prior month and
   every older key to be consecutive.
6. Keep endpoints oldest to newest; require positive finite and pairwise-
   distinct closes; calculate all 78 chronological pair comparisons.
7. Continue only when `abs(S) >= 28`; use the sign of `S` as order direction.
8. Require spread in `[0,3000]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and valid fixed-risk sizing.
9. Open at most one market position with a frozen `3.5 * ATR(20,D1)` hard stop
   and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of each new broker
   month before considering replacement risk.
2. Close after forty elapsed calendar days as a stale guard.
3. Broker hard stops and the framework kill switch remain authoritative.
4. Friday close is disabled because the source-aligned hold spans weekends.
5. No intramonth signal flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, nonpositive or
  nonfinite close, any exact tie, weak score, excessive spread, invalid quote,
  unavailable ATR, invalid stop, or invalid volume metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, analyst forecast, trained output, or portfolio result.

## 7. Trade Management Rules

- Maintain at most one XNG position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future/prior-run
  marker so historical runs remain deterministic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| param | default | authorized values | role |
|---|---:|---|---|
| `strategy_rank_points` | 13 | [13] | completed month-end observations |
| `strategy_min_abs_score` | 28 | [28] | fixed no-tie pairwise score boundary |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 3000 | [3000] | XNG entry spread ceiling |

The endpoint count, chronological pair orientation, tie rule, score, threshold,
direction, entry clock, risk, stop, hold, and no-retry policy are locked.
Changing any of them requires a new card and full pipeline run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures and include natural gas in their commodity universe. They do not claim
that this rank-trend rule works, that score 28 is optimal, that a continuous CFD
reproduces futures, or that the candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: XNG gaps, CFD roll/basis and financing,
weather shocks, single-name concentration, sparse qualified paths, stale rank
trends, hard-stop slippage, and overlap with the existing XNG sleeve can
dominate the premise. The rank score ignores move magnitude and is not a
forecast-confidence guarantee.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  an accepted tie, incorrect pair score, entry with `abs(S) < 28`, wrong-side
  entry, repeated monthly attempt, hold beyond forty days, missing hard stop,
  invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing lookback, score threshold, direction,
  entry clock, stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: PASS. One tier-A peer-reviewed source with DOI, complete-paper
  evidence, and natural-gas membership.
- [x] R2: PASS. Fixed endpoints, all-pairs score, tie rule, threshold,
  direction, attempt, hard stop, rollover, and stale exit.
- [x] R3: PASS. Registered `XNGUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: PASS. Deterministic comparison, integer, calendar, and ATR arithmetic;
  no trained model, banned signal indicator, external feed, grid, or martingale.
- [x] Dedup: no exact XNG identity; expected WTI template and XNG trend-family
  neighbors manually resolved.

## Framework Alignment

- no_trade: exact XNG/D1/EA/slot, locked inputs, fixed risk/news/Friday contract,
  and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, all-pairs
  rank-score calculation, spread/quote/ATR/stop checks, and one fixed-risk order.
- trade_management: prior-month and stale exits before entry-only gates.
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
| v1 | 2026-08-08 | initial source-bounded XNG pairwise rank-trend card | G0 | APPROVED |
| v1-q01 | 2026-08-08 | deterministic V5 build, strict compile, and build validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-08 | APPROVED | `decisions/2026-08-08_qm5_20267_xng_rank_trend_g0.md` |
| Q01 Build Validation | 2026-08-08 | PASS | `D:/QM/reports/framework/21/build_check_20260808_200406.json`; `D:/QM/reports/pipeline/QM5_20267/P1/P1_QM5_20267_result.json` |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |
