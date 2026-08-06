---
card_schema_version: 2
type: strategy
strategy_id: SUENAGA-PAPAILIAS-XNG-SEASRSM-2026_S01
variant_id: SUENAGA-PAPAILIAS-XNG-SEASRSM-2026_S01
source_id: SUENAGA-PAPAILIAS-XNG-SEASRSM-2026
ea_id: QM5_20242
slug: xng-rsm-window
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20242_xng-rsm-window_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Hiroaki Suenaga; Aaron Smith; Jeffrey C. Williams; Fotis Papailias; Jiadong Liu; Dimitrios D. Thomakos"
source_citation: "Suenaga, Smith, and Williams (2008), Journal of Futures Markets 28(5), 438-463; Papailias, Liu, and Thomakos (2021), Journal of Banking & Finance 124, 106063."
source_citations:
  - type: peer_reviewed_paper
    citation: "Suenaga, H., Smith, A., and Williams, J. C. (2008). Volatility Dynamics of NYMEX Natural Gas Futures Prices. Journal of Futures Markets 28(5), 438-463."
    location: "Complete 26-page governed review at strategy-seeds/sources/SUENAGA-XNG-SEASVOL-2008/source.md; DOI https://doi.org/10.1002/fut.20317"
    quality_tier: A
    role: physical_volatility_windows
  - type: peer_reviewed_paper
    citation: "Papailias, F., Liu, J., and Thomakos, D. D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, 106063."
    location: "Complete accepted manuscript and appendices governed at strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md; DOI https://doi.org/10.1016/j.jbankfin.2021.106063"
    quality_tier: A
    role: monthly_return_sign_direction
strategy_mechanic: monthly-xng-source-volatility-window-gated-twelve-completed-month-return-sign-probability-momentum
sources:
  - "[[sources/SUENAGA-PAPAILIAS-XNG-SEASRSM-2026]]"
concepts:
  - "[[concepts/natural-gas-seasonal-volatility]]"
  - "[[concepts/return-sign-momentum]]"
indicators:
  - "[[indicators/completed-month-return-sign]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, seasonal-volatility-window, return-sign-momentum, monthly-rebalance, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 202420000
period: D1
timeframe: D1
expected_trade_frequency: "Eight eligible monthly XNG packages/year after thirteen completed month-end closes; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
review_focus: "Falsify an XNG return-sign trend held only during source-defined physical volatility windows. It is neither the incumbent RSI pullback nor either parent alone; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_completed_months, binary_sign_definition, fixed_probability_threshold, source_window_gate, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20242_xng_rsm_window_g0.md: R1 two governed peer-reviewed complete-read source lineages with explicit natural-gas applicability; R2 locked May-September and November-January gate, twelve completed monthly binary signs, fixed 0.40 threshold, persisted monthly attempt, ATR stop, rollover, and stale exit; R3 registered XNGUSD.DWX D1; R4 deterministic native arithmetic only. Deterministic dedup scanned 4,299 registry rows and 416 canonical cards with CLEAN exact/fuzzy result; manual parent review is clean. The conjunction is a QM hypothesis and no source efficacy transfers."
---

# QM5_20242 XNG Seasonal Return-Sign Momentum Window

## Hypothesis

Natural-gas storage constraints and recurring demand cycles concentrate price
discovery in two physical-market volatility windows. Monthly return direction
can separately persist even when magnitudes are noisy. Applying a fixed
return-sign momentum state only during those windows may produce a slow XNG
return stream that differs from the certified book's two-day RSI pullback.

This is direct natural-gas exposure, not a claim of profitability or portfolio
decorrelation. Q02 owns density and economics; the unchanged Q09 gate alone
may measure realized overlap after survival.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/SUENAGA-PAPAILIAS-XNG-SEASRSM-2026/source.md`.
Suenaga, Smith, and Williams supply only the May-September and November-January
natural-gas volatility windows. Papailias, Liu, and Thomakos supply the fixed
twelve-month binary-sign probability and `q=0.40` direction rule.

Neither paper tests this intersection, a Darwinex continuous CFD, broker-month
translation, fixed dollar risk, ATR stop, costs, financing, or the QM book.
No source performance, volatility, drawdown, trade-count, or correlation
statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,299 registry rows and 416 cards and returned
`CLEAN` with no exact identity or fuzzy hit. Manual review resolves the closest
systems:

- `QM5_13116_xng-signmom` uses the same RSM0.4 direction all year and has no
  seasonal-volatility gate.
- `QM5_20052_xng-seas-trend` uses the source windows but takes direction from
  one 126-D1 magnitude return with a two-percent deadband; it does not count
  completed monthly signs.
- `QM5_20162` and `QM5_20164` use winter or summer daily 21/84-SMA stacks and
  slope filters, not monthly RSM probability.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback
  below a moving-average filter.
- Storage, freeze, LNG, expiry, weekday, monthly contrarian, breakout, carry,
  and paired-energy EAs use different information objects or clocks.

The fixed two-window calendar, twelve binary completed-month signs, fixed 0.40
threshold, off-window flat state, and monthly lifecycle are jointly
load-bearing. Removing the window recreates QM5_13116; replacing the binary
sign distribution with an endpoint magnitude recreates QM5_20052. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XNGUSD.DWX`.
- Timeframe: D1; magic slot 0; allocated magic `202420000`.
- Decision clock: first processed D1 bar of every broker-month transition.
- Eligible decision months: May-September and November-January.
- Formation: thirteen consecutive completed broker-month closes producing
  twelve binary monthly return signs.
- Expected cadence: eight completed packages/year after warm-up; retire below
  five per full post-warm-up year.
- Runtime data: native MT5 D1 OHLC, broker calendar, ATR, spread, executable
  quotes, positions, deals, and contract metadata only.

## Formula

At the start of month `t`, let `M[0]` be the close of `t-1` and `M[12]` the
close of `t-13`. For `k=0..11`:

```text
v[k] = 1 when M[k] >= M[k+1], otherwise 0
P    = sum(v[k]) / 12
```

- In May-September or November-January, BUY when `P >= 0.40`.
- In those months, SELL when `P < 0.40`.
- In February-April and October, or with invalid/nonconsecutive history,
  consume the month flat.

Equality is non-negative, matching the source definition. There is no return
magnitude, RSI, moving average, breakout, external event, adaptive threshold,
or trained state.

## Rules

The following rules are the complete frozen Q02 baseline. No threshold,
window, direction, lookback, carrier, or retry sweep is authorized.

## 4. Entry Rules

1. Require exact EA ID `20242`, `XNGUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry gates and evaluate only on a genuine
   broker-month transition.
3. Persist the current month as consumed before season, history, signal,
   spread, quote, news, stop, sizing, or order gates. A flat, rejected,
   failed, stopped, blocked, or restarted month cannot retry.
4. Reject an owned position or current-month entry deal for the magic.
5. Permit exposure only in May-September and November-January.
6. Reconstruct exactly thirteen consecutive completed broker-month endpoints,
   require the newest endpoint to be the month immediately before the
   decision month, and require positive finite closes.
7. Count each of the twelve returns as non-negative when the newer close is
   greater than or equal to the older close. Divide by exactly twelve.
8. BUY when probability is at least `0.40`; otherwise SELL.
9. Require spread in `[0,3000]` points, valid executable quote, completed
   `ATR(20,D1)`, and valid normalized stop geometry.
10. Open at most one market position with a frozen `3.5 * ATR(20,D1)` hard
    stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement exposure.
2. Close immediately when a position is observed in an ineligible month.
3. Close after forty elapsed calendar days as a stale guard.
4. Close any wrong-symbol or wrong-side owned position immediately.
5. Broker hard stops and the framework kill switch remain authoritative.
6. Friday close is disabled because the monthly source hold spans weekends.
7. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong host, timeframe, EA ID, slot, unlocked input,
  non-boundary bar, consumed month, owned exposure, same-month entry history,
  off-window month, missing or nonconsecutive endpoints, invalid close,
  invalid probability, excessive spread, invalid quote, unavailable ATR, or
  invalid stop.
- Both news axes and the legacy mode are locked OFF. Lifecycle exits precede
  every entry-only gate.
- Runtime may not read POTS/GARCH output, weather, storage, EIA releases,
  volume, open interest, futures curves, files, APIs, analyst input, trained
  output, or portfolio results.

## 7. Trade Management Rules

- Preserve the original broker stop; never move it.
- Close older-month, off-window, wrong-side, wrong-symbol, or stale exposure
  before evaluating a new entry.
- Maintain at most one owned position and one consumed attempt per broker
  month. Restart recovery combines a persistent marker with position and deal
  history; future-dated tester state is cleared at initialization.
- No randomness, adaptive fit, external state, grid, martingale, partial
  close, scale-in, or pyramiding.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | [12] | completed binary-sign window |
| `strategy_positive_threshold` | 0.40 | [0.40] | fixed source RSM threshold |
| `strategy_summer_first_month` | 5 | [5] | first spring/summer volatility month |
| `strategy_summer_last_month` | 9 | [9] | final spring/summer volatility month |
| `strategy_winter_first_month` | 11 | [11] | first winter volatility month |
| `strategy_winter_last_month` | 1 | [1] | final winter volatility month |
| `strategy_history_bars` | 500 | [500] | bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale monthly guard |
| `strategy_max_spread_points` | 3000 | [3000] | XNG entry spread ceiling |

## Author Claims

The volatility paper documents seasonally concentrated natural-gas futures
volatility. The RSM paper defines return-sign momentum and explicitly includes
natural gas. Neither claims this conjunction is profitable on
`XNGUSD.DWX`, improves diversification, or survives costs.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: XNG gaps and financing can dominate a slow
signal; a volatility window is not a return-premium guarantee; the 0.40 rule
can remain persistently long; season gating may reduce density; the futures-to-
CFD basis is material; and a second XNG sleeve can correlate with QM5_12567.

Retire below five completed packages/year, on nonpositive governed economics,
or on later portfolio-correlation rejection.

## Kill Criteria

- Fail on a wrong-window entry, wrong binary-sign definition, wrong threshold,
  nonconsecutive endpoint, repeat monthly attempt, missing hard stop, hold
  beyond forty days, risk-mode mismatch, or nondeterminism.
- Do not rescue failure by changing months, threshold, horizon, direction,
  stop, hold, spread cap, retry policy, or carrier.
- No structural-difference claim may waive Q09 realized-correlation evidence.

## Strategy Allowability Check

- [x] R1: two named-author peer-reviewed sources with DOIs and durable
  complete-read records.
- [x] R2: fixed source windows, twelve binary signs, fixed 0.40 threshold,
  persisted attempt, hard stop, rollover, and stale exit.
- [x] R3: registered `XNGUSD.DWX` D1 and native V5 execution state only.
- [x] R4: deterministic calendar/comparison/counting/division/ATR arithmetic;
  no prohibited trained model, banned indicator, external feed, grid, or
  martingale.
- [x] Dedup: deterministic CLEAN plus manual parent and neighbor resolution.

## Framework Alignment

- no_trade: exact XNG/D1/EA/slot, frozen input, news/Friday, and cheap
  parameter guards.
- trade_entry: persistent month consumption, source-window gate, thirteen
  endpoint reconstruction, twelve binary signs, spread/quote/ATR/stop checks,
  and one fixed-risk order.
- trade_management: monthly, off-window, wrong-side, wrong-symbol, and stale
  exits before entry-only gates.
- trade_close: broker hard stop, framework kill switch, and deterministic
  management closes.

## Safety Boundary

This card authorizes only branch-local research, deterministic allocation,
build, strict compile, one `RISK_FIXED` backtest setfile, and one paced Q02
enqueue. It does not authorize a manual backtest; live, demo, shadow,
optimization, or stress setfile; AutoTrading; `T_Live`; deploy or T_Live
manifest; portfolio admission; portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial source-bounded XNG seasonal RSM card | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20242_xng_rsm_window_g0.md` |
| Q01 Build Validation | - | PENDING | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

