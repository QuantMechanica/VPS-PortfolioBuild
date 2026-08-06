---
card_schema_version: 2
type: strategy
strategy_id: SUENAGA-MEHLITZ-XNG-VRWIN-2026_S01
variant_id: SUENAGA-MEHLITZ-XNG-VRWIN-2026_S01
source_id: SUENAGA-MEHLITZ-XNG-VRWIN-2026
ea_id: QM5_20248
slug: xng-vr-window
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20248_xng-vr-window_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Hiroaki Suenaga; Aaron Smith; Jeffrey C. Williams; Julia S. Mehlitz; Benjamin R. Auer"
source_citation: "Suenaga, Smith, and Williams (2008), Journal of Futures Markets 28(5), 438-463, DOI 10.1002/fut.20317; Mehlitz and Auer (2024), The European Journal of Finance 30(8), 773-802, DOI 10.1080/1351847X.2023.2220118."
source_citations:
  - type: peer_reviewed_paper
    citation: "Suenaga, H., Smith, A., and Williams, J. C. (2008). Volatility Dynamics of NYMEX Natural Gas Futures Prices. Journal of Futures Markets 28(5), 438-463."
    location: "DOI https://doi.org/10.1002/fut.20317; complete author-hosted paper https://files.asmith.ucdavis.edu/2008_JFutMkt_SSW_NGfutures.pdf; governed packet strategy-seeds/sources/SUENAGA-XNG-SEASVOL-2008/source.md"
    quality_tier: B
    role: primary_natural_gas_physical_windows
  - type: peer_reviewed_paper
    citation: "Mehlitz, J. S., and Auer, B. R. (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: "DOI https://doi.org/10.1080/1351847X.2023.2220118; complete open precursor Chapter 3 pp. 51-74 and Appendix C pp. 110-113; governed packet strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md"
    quality_tier: A
    role: primary_variance_ratio_memory_state
strategy_mechanic: monthly-xng-latest-return-direction-conditioned-by-q2-robust-variance-ratio-memory-inside-physical-volatility-windows
sources:
  - "[[sources/SUENAGA-MEHLITZ-XNG-VRWIN-2026]]"
  - "[[sources/SUENAGA-XNG-SEASVOL-2008]]"
  - "[[sources/MEHLITZ-AUER-MEM-2024]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/memory-enhanced-momentum]]"
  - "[[concepts/variance-ratio]]"
indicators:
  - "[[indicators/lo-mackinlay-variance-ratio]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, volatility-seasonality, memory-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 202480000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 5-7 completed monthly XNG packages/year after thirty-three consecutive completed month ends; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 40.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify an XNG physical-season/memory stream whose monthly serial-dependence state and bidirectional mapping are structurally unlike the certified QM5_12567 two-day long-only oscillator. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_completed_months, robust_variance_ratio, fixed_significance_threshold, fixed_physical_windows, memory_direction_matrix, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20248_xng_vr_window_g0.md: two governed complete-read peer-reviewed source lineages; locked thirty-three-month-end reconstruction, q=2 robust variance-ratio statistic, two-sided 10% significance boundary, May-September plus November-January gate, latest-return direction, persistence-follow/anti-persistence-reverse mapping, persisted monthly attempt, ATR stop, rollover, and stale exit; registered XNGUSD.DWX D1 history; deterministic native arithmetic only. Dedup scanned 4,305 registry rows and 422 cards with no exact hit; the only fuzzy neighbor uses a different binary-sign-share mechanic and manual review is clean. The conjunction is a QM hypothesis and no source efficacy transfers."
---

# QM5_20248 XNG Variance-Ratio Physical Window

## Hypothesis

Natural gas should expose a distinct, low-frequency return stream when the
latest completed monthly direction is admitted only by statistically
significant short memory and only during the physical-market windows in which
natural-gas shock persistence and volatility are structurally elevated. In a
persistent state, follow the latest return; in an anti-persistent state,
reverse it; off-window or insignificant states stay flat.

This is not the certified `QM5_12567` edge: that strategy buys a two-day
cumulative-RSI pullback. This card is monthly, bidirectional, calendar-gated,
and based on an explicit serial-dependence test. It does not claim
profitability, decorrelation, or admission. Q02 owns density and economics;
unchanged Q09 alone may measure realized overlap after survival.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/SUENAGA-MEHLITZ-XNG-VRWIN-2026/source.md`. Its parents
are Suenaga, Smith, and Williams (2008), a complete peer-reviewed natural-gas
volatility paper, and Mehlitz and Auer (2024), a peer-reviewed commodity-memory
paper with a complete open precursor.

Suenaga et al. supply the early-May/late-September and early-November/mid-
January physical-volatility timing, translated transparently to full broker
months May-September and November-January. Mehlitz and Auer supply the
32-month `q=2` robust variance-ratio test, fixed two-sided 10% critical value,
latest-return direction, and persistence/anti-persistence follow/reverse
matrix. Neither paper tests the combined XNG rule. The continuous CFD, broker-
month proxy, fixed dollar risk, ATR hard stop, spread cap, and restart ledger
are QM hypotheses. No source performance, count, cost, drawdown, or portfolio
statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,305 EA-registry rows and 422 cards. It found no
exact identity and only the expected fuzzy neighbor `QM5_20242`. Manual review
resolves the relevant strategies:

- `QM5_20242_xng-rsm-window` uses a twelve-month binary non-negative-return
  share and fixed `0.40` direction threshold. It has no variance-ratio state,
  significance test, latest-return base direction, or anti-persistent reversal.
- `QM5_13134_energy-vr-mom` is the year-round WTI carrier of the memory rule and
  has no XNG physical-window state.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG oscillator
  pullback with no calendar or monthly-memory inputs.
- `QM5_20052_xng-seas-trend` uses 126 D1 magnitude return in the source windows,
  not a serial-dependence state.
- `QM5_13116_xng-signmom` is year-round sign momentum without either gate.

The two physical windows, thirty-two-return robust `q=2` test, fixed critical
value, latest-return base direction, continuation/reversal mapping, and
eligible-month attempt clock are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XNGUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `202480000` after registry approval.
- Decision clock: first processed D1 bar of each genuine broker-month
  transition.
- Formation: thirty-three consecutive completed broker-month endpoints,
  defining thirty-two chronological monthly log returns.
- Eligible months: `{5,6,7,8,9,11,12,1}`; `{2,3,4,10}` are flat.
- Expected cadence: 5-7 completed packages/year after warm-up; retire below
  five per full post-warm-up year.
- Runtime: native MT5 D1 time/close, ATR, spread, quotes, positions, deals,
  broker calendar, and contract metadata only.

## Formula

At the start of eligible broker month `t`, let chronological completed monthly
log returns be `r_0 ... r_31`, derived from thirty-three consecutive month-end
closes. Define:

```text
mean       = average(r_0 ... r_31)
S          = sum((r_i - mean)^2), i=0...31
rho_1      = sum((r_i - mean)(r_i-1 - mean), i=1...31) / S
VR(2)      = 1 + rho_1
robust_se  = sqrt(sum((r_i - mean)^2(r_i-1 - mean)^2, i=1...31) / S^2)
z          = (VR(2) - 1) / robust_se
base_dir   = sign(r_31)
```

- If the current month is off-window: flat.
- If `abs(z) <= 1.64485362695147` or `base_dir == 0`: flat.
- If `z > 1.64485362695147`: trade `base_dir` (persistence follows).
- If `z < -1.64485362695147`: trade opposite `base_dir`
  (anti-persistence reverses).
- Invalid, incomplete, nonconsecutive, or zero-variance history: flat and fail
  closed.

## Rules

The rules below are the complete authorized Q02 baseline. Signal parameters
are locked; no direction, threshold, horizon, month, carrier, or retry sweep is
authorized.

## 4. Entry Rules

1. Require exact EA ID `20248`, `XNGUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Exit immediately when the current broker month is off-window.
4. In an eligible month, persist the month as consumed before history, signal,
   spread, quote, news, stop, sizing, or order gates. A flat, rejected, failed,
   stopped, or blocked attempt cannot retry during that month.
5. Reject an owned position or any same-month entry deal for the magic.
6. Reconstruct exactly thirty-three consecutive completed month-end closes
   from a bounded D1 buffer. Require the newest endpoint to belong to the month
   immediately preceding the current month.
7. Form thirty-two chronological monthly log returns and compute the `q=2`
   robust statistic exactly as specified.
8. Enter only on significant memory and nonzero latest return. Follow the
   latest return when `z` is positive and reverse it when `z` is negative.
9. Require spread in `[0,1500]` points, a valid executable quote, completed
   `ATR(20,D1)`, valid stop geometry, and valid V5 fixed-risk sizing.
10. Open at most one market position with a frozen `3.0 * ATR(20,D1)` hard
    stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk.
2. Close immediately in February-April or October.
3. Close after forty elapsed calendar days as a stale guard.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the monthly hold spans weekends.
6. No intramonth reversal, target, trail, break-even, partial close, scale-in,
   grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, unlocked input,
  invalid month key, non-boundary bar, off-window month, consumed attempt,
  owned exposure, same-month entry history, missing or nonconsecutive
  endpoints, nonpositive close, invalid logarithm, zero variance, invalid
  robust standard error, insignificant memory, zero latest return, excessive
  spread, invalid quote, unavailable ATR, or invalid stop.
- Both news axes are locked OFF for the native-price baseline. Lifecycle exits
  are processed before entry-only gates.
- Runtime may not read a futures curve, storage release, weather, volume, open
  interest, file, API, analyst input, trained output, or portfolio result.

## 7. Trade Management Rules

- Preserve the original broker stop; do not move it.
- Close prior-month, off-window, or forty-day-stale owned XNG exposure before
  evaluating a new entry.
- Maintain at most one position and one consumed attempt per eligible broker
  month. Restart recovery combines a persistent marker with owned position and
  deal history; a future-dated tester marker is deleted at initialization.
- No randomness, adaptive fit, external state, partial close, scale-in, or
  pyramiding.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_vr_window_months` | 32 | [32] | robust memory-test window |
| `strategy_vr_q` | 2 | [2] | published short-memory order |
| `strategy_significance_z` | 1.64485362695147 | [1.64485362695147] | published two-sided 10% boundary |
| `strategy_summer_start_month` | 5 | [5] | first monthly summer-window proxy |
| `strategy_summer_end_month` | 9 | [9] | last monthly summer-window proxy |
| `strategy_winter_start_month` | 11 | [11] | first monthly winter-window proxy |
| `strategy_winter_end_month` | 1 | [1] | last monthly winter-window proxy |
| `strategy_history_bars` | 1200 | [1200] | bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | XNG entry spread ceiling |

## Author Claims

Suenaga et al. document seasonal variation in natural-gas volatility and shock
persistence. Mehlitz and Auer document a significant-memory continuation /
reversal matrix for commodity futures. Neither claims that their intersection
improves natural-gas returns, that full broker months reproduce the physical
windows, that a continuous CFD reproduces futures, or that this card
diversifies the QM book. Q02 and later gates are the only strategy evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: XNG gaps, financing, roll behavior, weather
shocks, and futures-to-CFD basis can dominate a slow signal; the memory test may
be sparse or unstable; the full-month window proxy is coarse; anti-persistent
reversal can oppose a powerful physical shock; stops reduce density; and a
second XNG carrier may correlate with the incumbent book.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on an off-window entry, nonconsecutive endpoint, wrong robust statistic,
  wrong latest-return or memory mapping, wrong-side entry, repeat monthly
  attempt, hold beyond forty days, missing hard stop, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing window, `q`, critical value, months,
  direction matrix, carrier, entry clock, stop, hold, spread cap, or retry
  policy.

## Strategy Allowability Check

- [x] R1: two named-author peer-reviewed sources with complete-read records,
  durable evidence, and direct natural-gas / commodity scope.
- [x] R2: fixed completed-month endpoints, robust `q=2` statistic, critical
  value, physical windows, direction matrix, persisted attempt, hard stop,
  rollover, and stale exit.
- [x] R3: registered `XNGUSD.DWX` D1 and native V5 execution state only.
- [x] R4: deterministic logarithm/calendar/statistic/ATR arithmetic; no
  prohibited trained model, banned signal indicator, external feed, grid, or
  martingale.
- [x] Dedup: no exact hit; expected fuzzy neighbor manually resolved cleanly.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, news/Friday contract, and
  cheap parameter guards.
- trade_entry: monthly attempt persistence, physical-window gate,
  thirty-three endpoint reconstruction, robust memory statistic, direction
  matrix, spread/quote/ATR/stop checks, and one order.
- trade_management: prior-month, off-window, and stale exits before entry-only
  gates.
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
| v1 | 2026-08-06 | initial source-bounded XNG memory/window card and strict build | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20248_xng_vr_window_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | strict compile `framework/build/compile/20260806_111821/QM5_20248_xng-vr-window.compile.log`; build check `D:/QM/reports/framework/21/build_check_20260806_111926.json` |
| Q02 Baseline Screening | 2026-08-06 | NOT_ENQUEUED | pending Q01 and paced-fleet ceiling |
