---
card_schema_version: 2
type: strategy
strategy_id: MOP-PAPAILIAS-WTI-TRENDSIGN-2026_S01
variant_id: MOP-PAPAILIAS-WTI-TRENDSIGN-2026_S01
source_id: MOP-PAPAILIAS-WTI-TRENDSIGN-2026
ea_id: QM5_20244
slug: wti-trend-sign
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20244_wti-trend-sign_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Fotis Papailias; Jiadong Liu; Dimitrios D. Thomakos"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Papailias, Liu, and Thomakos (2021), Journal of Banking & Finance 124, 106063, DOI 10.1016/j.jbankfin.2021.106063."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Complete 23-page published paper; DOI https://doi.org/10.1016/j.jfineco.2011.11.003; governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: primary_cumulative_trend_and_cadence
  - type: peer_reviewed_paper
    citation: "Papailias, F., Liu, J., and Thomakos, D. D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, 106063."
    location: "Complete 83-page accepted manuscript including WTI tables; DOI https://doi.org/10.1016/j.jbankfin.2021.106063; governed packet strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md"
    quality_tier: A
    role: primary_binary_sign_state_and_threshold
strategy_mechanic: monthly-wti-12m-cumulative-return-and-12-month-binary-return-sign-concordance
sources:
  - "[[sources/MOP-PAPAILIAS-WTI-TRENDSIGN-2026]]"
  - "[[sources/MOP-TSMOM-2012]]"
  - "[[sources/PAPAILIAS-RSM-2021]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/return-signal-momentum]]"
  - "[[concepts/signal-concordance]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, return-sign-momentum, concordance, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202440000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 8-11 completed monthly WTI packages/year after thirteen consecutive completed month ends; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 9
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
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a direct WTI structural trend-concordance package whose cumulative twelve-month return and twelve-return binary-sign state must agree. Q09 alone may establish realized decorrelation from XAU/SP500/NDX/XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_completed_months, shared_formation_window, cumulative_trend_sign, return_sign_probability, concordance_gate, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20244_wti_trend_sign_g0.md: R1 two complete peer-reviewed source packets with explicit WTI membership; R2 locked thirteen-month-end reconstruction, cumulative twelve-month log-return sign, twelve binary monthly signs, fixed 0.40 threshold, strict concordance gate, persisted monthly attempt, ATR stop, monthly rollover, and stale exit; R3 registered XTIUSD.DWX D1 history; R4 deterministic native price arithmetic only. Deterministic dedup scanned 4,301 registry rows and 418 canonical cards with CLEAN exact/fuzzy result; manual mechanic review is clean. The agreement conjunction is a QM hypothesis and no source efficacy transfers."
---

# QM5_20244 WTI Trend / Return-Sign Concordance

## Hypothesis

WTI trends can reflect persistent supply, investment, hedging, inventory, and
risk-premium regimes. A cumulative return may be dominated by a few large
moves, while a binary monthly-sign state records path breadth without using
return magnitude. This card takes monthly WTI exposure only when those two
published structural states agree.

The direct crude-oil carrier is economically different from the certified
XAU, SP500, NDX, and XNG book. The card does not claim that the candidate is
decorrelated, profitable, or suitable for admission. Q02 owns density and
economics; unchanged Q09 alone may measure realized overlap after survival.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/MOP-PAPAILIAS-WTI-TRENDSIGN-2026/source.md`. Its two
complete-read parents are Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed
*Journal of Financial Economics* article, and Papailias, Liu, and Thomakos
(2021), a peer-reviewed *Journal of Banking & Finance* article. Both include
WTI futures.

The sources supply the cumulative own-return direction, twelve binary monthly
signs, fixed 0.40 sign-state threshold, and monthly formation/holding cadence.
They do not test their agreement on a standalone WTI CFD. The conjunction,
Darwinex continuous CFD, exact broker-month reconstruction, fixed dollar risk,
ATR hard stop, spread cap, and restart ledger are transparent QM hypotheses.
No source performance, volatility, trade-count, cost, drawdown, or correlation
statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,301 EA-registry rows and 418 cards and returned
`CLEAN`, with no exact identity and no fuzzy match above threshold. Manual
review resolves the nearest strategies:

- Pure WTI time-series-momentum EAs use one cumulative return without the
  twelve-return binary-sign agreement gate.
- `QM5_13150_wti-signmom` follows the binary-sign state in every month without
  cumulative-return confirmation.
- `QM5_20056_wti-dual-mom` agrees two cumulative horizons (63 D1 and 252 D1),
  not a cumulative return and the breadth of twelve separate monthly signs.
- `QM5_20222_wti-seas-sign` agrees the binary-sign state with a fixed calendar
  partition rather than WTI's own cumulative return.
- `QM5_20239_wti-pulltrend` requires a newest completed month to oppose an
  older non-overlapping trend; this card uses one common twelve-return window
  and requires concordance.
- `QM5_12567_cum-rsi2-commodity` is an XNG short-horizon oscillator pullback.

The common twelve-return formation window, cumulative log-return direction,
twelve binary signs, fixed 0.40 threshold, agreement-only entry,
disagreement-flat state, and monthly attempt clock are jointly load-bearing.
Verdict: `CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `202440000`.
- Decision clock: first processed D1 bar of each genuine broker-month
  transition.
- Formation: thirteen consecutive completed broker-month endpoints.
- Expected cadence: 8-11 completed packages/year after warm-up; retire below
  five per full post-warm-up year.
- Runtime data: native MT5 D1 time/close, ATR, spread, quotes, positions,
  deals, broker calendar, and contract metadata only.

## Formula

At the start of broker month `t`, define completed month-end closes in reverse
chronological order:

```text
M0 ... M12 = consecutive closes at the ends of months t-1 ... t-13
r_i         = ln(M_i / M_i+1), i = 0 ... 11
trend       = sum(r_i) = ln(M0 / M12)
P           = count(r_i >= 0) / 12

trend_direction = LONG if trend > 0, SHORT if trend < 0, FLAT if trend == 0
sign_direction  = LONG if P >= 0.40, SHORT otherwise
```

- Both directions LONG: BUY WTI.
- Both directions SHORT: SELL WTI.
- Disagreement, exact-zero trend, missing/nonconsecutive endpoints,
  nonpositive closes, or invalid arithmetic: consume the month flat.

## Rules

The rules below are the complete authorized Q02 baseline. Signal parameters
are locked; no direction, threshold, horizon, carrier, calendar, or retry sweep
is authorized.

## 4. Entry Rules

1. Require exact EA ID `20244`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order gates. A flat, rejected, failed,
   stopped, or blocked attempt cannot retry during that month.
4. Reject an owned position or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen consecutive completed month-end closes from a
   bounded D1 buffer and require the newest endpoint to belong to the month
   immediately preceding the current month.
6. Calculate the twelve monthly returns, cumulative trend, non-negative count,
   and probability exactly as specified. Enter only when both directions
   agree.
7. Require spread in `[0,1500]` points, a valid executable quote, completed
   `ATR(20,D1)`, valid stop geometry, and valid V5 fixed-risk sizing.
8. Open at most one market position with a frozen `3.5 * ATR(20,D1)` hard stop
   and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk.
2. Close after forty elapsed calendar days as a stale guard.
3. Close an owned WTI position that belongs to a prior broker month or breaches
   the stale guard.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source cadence holds through weekends.
6. No intramonth reversal, target, trail, break-even, partial close, scale-in,
   grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, unlocked input,
  invalid month key, non-boundary bar, consumed attempt, owned exposure,
  same-month entry history, missing or nonconsecutive endpoints, nonpositive
  close, invalid logarithm, direction disagreement, excessive spread, invalid
  quote, unavailable ATR, or invalid stop.
- Both news axes are locked OFF for the native-price baseline. Lifecycle exits
  are processed before entry-only gates.
- Runtime may not read a futures curve, inventory release, volume, open
  interest, file, API, analyst input, trained output, or portfolio result.

## 7. Trade Management Rules

- Preserve the original broker stop; do not move it.
- Close older-month or forty-day-stale owned WTI exposure before evaluating a
  new entry.
- Maintain at most one position and one consumed attempt per broker month.
  Restart recovery combines a persistent marker with owned position and deal
  history; a future-dated tester marker is deleted at initialization.
- No randomness, adaptive fit, external state, grid, martingale, partial
  close, scale-in, or pyramiding.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | [12] | common trend and sign-state interval |
| `strategy_positive_threshold` | 0.40 | [0.40] | published fixed sign-state threshold |
| `strategy_history_bars` | 500 | [500] | bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

## Author Claims

The sources document time-series momentum and return-signal momentum across
liquid futures and identify WTI in their commodity universes. They do not claim
that agreeing the signals improves WTI entries, that a continuous CFD
reproduces futures, or that this card diversifies the QM book. Q02 and later
gates are the only strategy evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, roll/basis effects, and financing
can dominate a slow signal; sign breadth can agree with a weak cumulative move;
the filter may not reduce tail risk; stop-outs reduce density; and direct crude
exposure may correlate with the incumbent book. Papailias et al.'s adverse WTI
drawdown comparison is not hidden.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on a nonconsecutive endpoint, wrong probability, wrong cumulative
  return, disagreement entry, wrong-side entry, repeat monthly attempt, hold
  beyond forty days, missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing horizons, sign encoding, threshold,
  direction, carrier, entry clock, stop, hold, spread cap, or retry policy.

## Strategy Allowability Check

- [x] R1: two peer-reviewed named-author sources with DOI, complete-paper
  records, durable evidence, and explicit WTI membership.
- [x] R2: fixed completed-month endpoints, both state formulas, strict
  concordance, persisted attempt, hard stop, rollover, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 and native V5 execution state only.
- [x] R4: deterministic logarithm/calendar/ATR arithmetic; no prohibited
  trained model, banned signal indicator, external feed, grid, or martingale.
- [x] Dedup: deterministic CLEAN plus manual neighbor resolution.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked input, news/Friday contract, and
  cheap parameter guards.
- trade_entry: monthly attempt persistence, thirteen endpoint reconstruction,
  both trend states, agreement, spread/quote/ATR/stop checks, and one order.
- trade_management: older-month and stale exits before entry-only gates.
- trade_close: broker hard stop, framework kill switch, and deterministic
  management closes.

## Safety Boundary

This card authorizes only research, build, strict compile, and non-live paced
pipeline handoff. It does not authorize a manual backtest; live, demo, shadow,
optimization, or stress setfile; AutoTrading; `T_Live`; deploy or T_Live
manifest; portfolio admission; portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial source-bounded WTI trend/sign concordance card and strict build | Q01 | PASS |
| v1.1 | 2026-08-06 | paced Q02 handoff stopped at binding 7/7 factory-terminal ceiling | Q01 | READY_NOT_ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20244_wti_trend_sign_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | strict compile `framework/build/compile/20260806_082948/QM5_20244_wti-trend-sign.compile.log`; build check `D:/QM/reports/framework/21/build_check_20260806_083052.json` |
| Q02 Baseline Screening | 2026-08-06 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-06_qm5_20244_wti_trend_sign_q01_cpu_stop.md` |
