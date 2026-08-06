---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-MEHLITZ-WTI-VRCAL-2026_S01
variant_id: BURAKOV-MEHLITZ-WTI-VRCAL-2026_S01
source_id: BURAKOV-MEHLITZ-WTI-VRCAL-2026
ea_id: QM5_20247
slug: wti-vr-calreg
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20247_wti-vr-calreg_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Julia S. Mehlitz; Benjamin R. Auer"
source_citation: "Burakov, Freidin, and Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Mehlitz and Auer (2024), The European Journal of Finance 30(8), 773-802, DOI 10.1080/1351847X.2023.2220118."
source_citations:
  - type: peer_reviewed_paper
    citation: "Burakov, D., Freidin, M., and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Official complete open paper https://www.econjournals.com/index.php/ijeep/article/view/6092; governed packet strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: primary_physical_season_direction
  - type: peer_reviewed_paper
    citation: "Mehlitz, J. S., and Auer, B. R. (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: "DOI https://doi.org/10.1080/1351847X.2023.2220118; complete open precursor Chapter 3 pp. 51-74 and Appendix C pp. 110-113; governed packet strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md"
    quality_tier: A
    role: primary_variance_ratio_memory_state
strategy_mechanic: monthly-wti-fixed-physical-season-direction-conditioned-by-q2-robust-variance-ratio-memory
sources:
  - "[[sources/BURAKOV-MEHLITZ-WTI-VRCAL-2026]]"
  - "[[sources/BURAKOV-WTI-HALLOWEEN-2018]]"
  - "[[sources/MEHLITZ-AUER-MEM-2024]]"
concepts:
  - "[[concepts/energy-calendar-seasonality]]"
  - "[[concepts/memory-enhanced-momentum]]"
  - "[[concepts/variance-ratio]]"
indicators:
  - "[[indicators/lo-mackinlay-variance-ratio]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, calendar-seasonality, memory-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202470000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 6-10 completed monthly WTI packages/year after thirty-three consecutive completed month ends; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING
q02_status: PENDING
review_focus: "Falsify a direct WTI physical-season sleeve whose direction is admitted only by a statistically significant monthly serial-dependence state, absent from the certified XAU/SP500/NDX/XNG book. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [consecutive_completed_months, robust_variance_ratio, fixed_significance_threshold, fixed_calendar_partition, memory_direction_matrix, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20247_wti_vr_calreg_g0.md: R1 governed complete-read tier-A memory and tier-B WTI seasonality lineages; R2 locked thirty-three-month-end reconstruction, q=2 robust variance-ratio statistic, two-sided 10% significance boundary, alternative-two November-May long / June-October short direction, persistence-follow/anti-persistence-reverse mapping, persisted monthly attempt, ATR stop, rollover, and stale exit; R3 registered XTIUSD.DWX D1 history; R4 deterministic native arithmetic only. Deterministic dedup scanned 4,304 registry rows and 421 canonical cards with CLEAN exact/fuzzy result; manual mechanic review is clean. The conjunction is a QM hypothesis and no source efficacy transfers."
---

# QM5_20247 WTI Variance-Ratio Calendar Regime

## Hypothesis

WTI's documented November-May versus June-October physical-season direction
should be actionable only when the latest thirty-two completed monthly returns
exhibit statistically significant short memory. In a persistent state, follow
the seasonal direction. In an anti-persistent state, reverse it. Insignificant
memory stays flat.

This direct crude-oil carrier adds a serial-dependence/calendar interaction
absent from the certified XAU, SP500, NDX, and XNG book. The card does not claim
profitability, decorrelation, or admission. Q02 owns density and economics;
unchanged Q09 alone may measure realized overlap after survival.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-MEHLITZ-WTI-VRCAL-2026/source.md`. Its parents
are Burakov, Freidin, and Solovyev (2018), a complete open peer-reviewed WTI
seasonality paper, and Mehlitz and Auer (2024), a peer-reviewed commodity
memory paper with a complete open precursor. Both explicitly cover WTI.

Burakov et al. supply the alternative-two November-May positive / June-October
negative WTI return partition. Mehlitz and Auer supply the 32-month `q=2`
robust variance-ratio test, fixed two-sided 10% critical value,
persistence/anti-persistence distinction, and follow/reverse matrix. Neither
paper tests the physical-season direction inside that memory matrix. The
conjunction, Darwinex continuous CFD, broker-month reconstruction, fixed dollar
risk, ATR hard stop, spread cap, and restart ledger are transparent QM
hypotheses. No source performance, count, drawdown, cost, or correlation
statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,304 EA-registry rows and 421 cards and returned
`CLEAN`, with no exact identity and no fuzzy match above threshold. Manual
review resolves the nearest strategies:

- `QM5_13134_energy-vr-mom` applies the same `q=2` memory state to only the
  immediately completed one-month return sign. This card uses the current
  physical-season direction.
- `QM5_20245_wti-vr-rsm` applies the memory state to twelve-month binary sign
  breadth and a fixed probability threshold, not a calendar state.
- `QM5_20015_wti-halloween-winter` is unconditional November-May long and flat
  otherwise, with no memory test or anti-persistent reversal.
- `QM5_20046_wti-halloween-ls` is an unconditional November-April long /
  May-October short alternative-one carrier, with neither this calendar
  boundary nor the memory test.
- `QM5_20222_wti-seas-sign` requires calendar/sign-breadth agreement and cannot
  reverse a valid season direction from observed anti-persistence.
- `QM5_20227`, `QM5_20231`, and `QM5_20241` use latest-month, cumulative
  twelve-month, and 52-week-anchor states rather than serial dependence.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator pullback.

The thirty-two-return robust `q=2` test, fixed significance threshold,
alternative-two month direction, persistence-follow / anti-persistence-reverse
matrix, and monthly attempt clock are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `202470000` after registry approval.
- Decision clock: first processed D1 bar of each genuine broker-month
  transition.
- Formation: thirty-three consecutive completed broker-month endpoints,
  defining thirty-two chronological monthly log returns.
- Calendar state: LONG in current months `{11,12,1,2,3,4,5}` and SHORT in
  `{6,7,8,9,10}` before the memory mapping.
- Expected cadence: 6-10 completed packages/year after warm-up; retire below
  five per full post-warm-up year.
- Runtime: native MT5 D1 time/close, ATR, spread, quotes, positions, deals,
  broker calendar, and contract metadata only.

## Formula

At the start of broker month `t`, let chronological completed monthly log
returns be `r_0 ... r_31`, derived from thirty-three consecutive month-end
closes. Define:

```text
mean       = average(r_0 ... r_31)
S          = sum((r_i - mean)^2), i=0...31
rho_1      = sum((r_i - mean)(r_i-1 - mean), i=1...31) / S
VR(2)      = 1 + rho_1
robust_se  = sqrt(sum((r_i - mean)^2(r_i-1 - mean)^2, i=1...31) / S^2)
z          = (VR(2) - 1) / robust_se
season_dir = LONG in November-May; SHORT in June-October
```

- If `abs(z) <= 1.64485362695147`: flat.
- If `z > 1.64485362695147`: trade `season_dir` (persistence follows).
- If `z < -1.64485362695147`: trade opposite `season_dir`
  (anti-persistence reverses).
- Invalid, incomplete, nonconsecutive, or zero-variance history: flat and fail
  closed.

## Rules

The rules below are the complete authorized Q02 baseline. Signal parameters
are locked; no direction, threshold, horizon, calendar, carrier, or retry sweep
is authorized.

## 4. Entry Rules

1. Require exact EA ID `20247`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order gates. A flat, rejected, failed, stopped,
   or blocked attempt cannot retry during that month.
4. Reject an owned position or any same-month entry deal for the magic.
5. Reconstruct exactly thirty-three consecutive completed month-end closes
   from a bounded D1 buffer. Require the newest endpoint to belong to the month
   immediately preceding the current month.
6. Form thirty-two chronological monthly log returns and compute the `q=2`
   robust statistic exactly as specified.
7. Enter only on significant memory. Follow the current calendar direction
   when `z` is positive and reverse it when `z` is negative.
8. Require spread in `[0,1500]` points, a valid executable quote, completed
   `ATR(20,D1)`, valid stop geometry, and valid V5 fixed-risk sizing.
9. Open at most one market position with a frozen `3.0 * ATR(20,D1)` hard stop
   and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk.
2. Close after forty elapsed calendar days as a stale guard.
3. Close an owned WTI position that belongs to a prior broker month or breaches
   the stale guard.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the monthly hold spans weekends.
6. No intramonth reversal, target, trail, break-even, partial close, scale-in,
   grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, unlocked input,
  invalid month key, non-boundary bar, consumed attempt, owned exposure,
  same-month entry history, missing or nonconsecutive endpoints, nonpositive
  close, invalid logarithm, zero variance, invalid robust standard error,
  insignificant memory, excessive spread, invalid quote, unavailable ATR, or
  invalid stop.
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
- No randomness, adaptive fit, external state, grid, martingale, partial close,
  scale-in, or pyramiding.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_vr_window_months` | 32 | [32] | robust memory-test window |
| `strategy_vr_q` | 2 | [2] | published short-memory order |
| `strategy_significance_z` | 1.64485362695147 | [1.64485362695147] | published two-sided 10% boundary |
| `strategy_winter_start_month` | 11 | [11] | first alternative-two winter month |
| `strategy_winter_end_month` | 5 | [5] | last alternative-two winter month |
| `strategy_history_bars` | 1200 | [1200] | bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

## Author Claims

Burakov et al. document an alternative-two WTI winter/summer return split, and
Mehlitz and Auer document a significant-memory continuation/reversal matrix;
both source universes cover WTI. Neither claims that conditioning the calendar
state on memory improves WTI, that a continuous CFD reproduces futures, or that
this card diversifies the QM book. Q02 and later gates are the only strategy
evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, rolls, financing, and
futures-to-CFD basis can dominate a slow signal; the memory test may be sparse
or unstable; the pre-2017 seasonal split may decay; anti-persistent reversal
can oppose the physical season at turning points; stops reduce density; and
direct crude exposure may correlate with the incumbent book.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on a nonconsecutive endpoint, wrong robust statistic, wrong calendar
  direction, wrong memory mapping, wrong-side entry, repeat monthly attempt,
  hold beyond forty days, missing hard stop, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing window, `q`, critical value, calendar,
  direction matrix, carrier, entry clock, stop, hold, spread cap, or retry
  policy.

## Strategy Allowability Check

- [x] R1: two named-author peer-reviewed sources with complete-read records,
  durable evidence, and explicit WTI scope.
- [x] R2: fixed completed-month endpoints, robust `q=2` statistic, critical
  value, calendar state, direction matrix, persisted attempt, hard stop,
  rollover, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 and native V5 execution state only.
- [x] R4: deterministic logarithm/calendar/statistic/ATR arithmetic; no
  prohibited trained model, banned signal indicator, external feed, grid, or
  martingale.
- [x] Dedup: deterministic CLEAN plus manual neighbor resolution.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, news/Friday contract, and
  cheap parameter guards.
- trade_entry: monthly attempt persistence, thirty-three endpoint
  reconstruction, robust memory statistic, calendar state, direction matrix,
  spread/quote/ATR/stop checks, and one order.
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
| v1 | 2026-08-06 | initial source-bounded WTI memory/calendar card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20247_wti_vr_calreg_g0.md` |
| Q01 Build Validation | - | PENDING | - |
| Q02 Baseline Screening | - | PENDING | - |
