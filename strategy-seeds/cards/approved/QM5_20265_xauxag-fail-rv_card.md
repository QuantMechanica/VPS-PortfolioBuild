---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-FAILRV-2026_S02
variant_id: SCHWEIKERT-CME-XAUXAG-FAILRV-2026_S02
source_id: SCHWEIKERT-CME-XAUXAG-FAIL-2026
ea_id: QM5_20265
slug: xauxag-fail-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20265_xauxag-fail-rv_card.md
execution_contract_status: DRAFT
created: 2026-08-07
created_by: Research+Development
last_updated: 2026-08-07
g0_status: APPROVED
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2017.11.010; governed review strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: primary_long_run_relation
  - type: peer_reviewed_paper
    citation: "Yaya, O. S., Vo, X. V., and Olayinka, H. A. (2021). Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach. Resources Policy 72, 102045."
    location: "DOI https://doi.org/10.1016/j.resourpol.2021.102045; governed review strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: supplemental_state_dependent_relation
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: primary_relative_value_carrier
strategy_mechanic: synchronized-d1-gold-silver-log-ratio-sixty-day-failed-channel-break-strict-reentry-reversion-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-FAIL-2026]]"
  - "[[sources/SCHWEIKERT-XAUXAG-RATIO-2026]]"
  - "[[sources/CME-GSR-SPREAD-2025]]"
concepts: [precious-metals-relative-value, failed-break-reversion, market-neutral-basket, structural-mean-reversion]
indicators: [log-price-ratio, rolling-range, arithmetic-mean, atr]
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, failed-break-reversion, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20265_XAU_XAG_FAILRV_D1
symbol: QM5_20265_XAU_XAG_FAILRV_D1
symbol_slot: 0
magic: 202650000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated five to fifteen completed XAU/XAG packages per full post-warm-up year; Q02 must prove at least five/year or retire."
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
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify an ordered failed-channel-break XAU/XAG package whose completed outside-to-inside event differs from outright XAU, breakout continuation, and every rolling ratio-extreme family; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, pre_event_channel, ordered_event, aggregate_fixed_risk, restart_attempt_state, friday_close_exception, magic_schema, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-07_qm5_20265_xauxag_fail_rv_g0.md: R1 two peer-reviewed DOI records plus a governed CME exchange carrier; R2 locked synchronized ratios, sixty pre-event channel observations, separate outside and strict-inside completed event bars, inverse sides, aggregate fixed risk, ATR stops, twenty-ratio convergence exit and stale exit; R3 registered XAUUSD.DWX and XAGUSD.DWX D1; R4 deterministic native arithmetic only. The checker covered 4,322 registry rows and 439 intake cards with no exact or fuzzy identity, and manual review distinguished continuation-channel, z-score, return-spread, OLS, quantile, C-MTAR, and median/MAD systems. No source efficacy, neutrality, or decorrelation transfers."
---

# QM5_20265 XAU/XAG Failed-Break Reversion

## Hypothesis

Gold and silver share precious-metals exposure but their relative price can
temporarily dislocate. A completed ratio break that cannot remain outside a
range fixed before the break is a falsifiable exhaustion event: fade the
failed relative move only after a separate completed bar has returned strictly
inside the old range.

The opposite-leg package seeks relative-value exposure and suppresses part of
the common metal direction. It is not a claim of dollar, beta, volatility,
factor, market, or portfolio neutrality. Q02 owns density and economics;
unchanged downstream gates and Q09 own robustness and realized book overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-FAIL-2026/source.md`. Its
peer-reviewed lineage supports a potentially state-dependent gold/silver
long-run relation. The governed CME packet supports the ratio-spread carrier.

None of the sources specifies a sixty-observation channel, a two-completed-bar
failed break, a strict re-entry rule, Darwinex CFDs, fixed-cash sizing, ATR
stops, or lifecycle controls. Those are transparent QM hypotheses. The
official-paper URL encountered during this task was policy-deferred; this card
uses no newly retrieved online content. No source return, alpha, Sharpe ratio,
drawdown, trade count, cost, CFD equivalence, neutrality, or portfolio
correlation is imported.

## Non-Duplicate Decision

The pre-allocation checker scanned 4,322 EA-registry rows and 439 intake cards
and returned `CLEAN`. No existing XAU/XAG card requires a completed ratio
outside a channel fixed from sixty earlier observations followed by a separate
completed ratio strictly back inside that same channel.

- `QM5_12724_cme-xauxag-brk` enters with an active ratio breakout and follows
  it. This card waits for a distinct re-entry bar and trades against the failed
  break.
- `QM5_12577` and `QM5_20157` use rolling ratio z-scores;
  `QM5_12862` uses a return-spread z-score.
- `QM5_20161`, `QM5_13205`, `QM5_20012`, and `QM5_20263` use rolling OLS,
  conditional quantiles, a published monthly C-MTAR state, and median/MAD
  extremes respectively.

The uncontaminated pre-event channel, outside-to-inside order, strict re-entry,
inverse direction, consumed event bar, and twenty-ratio convergence exit are
jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_FAMILY_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host: `XAUUSD.DWX` D1, slot 0, intended magic `202650000`.
- Second leg: `XAGUSD.DWX`, slot 1, intended magic `202650001`.
- Logical symbol: `QM5_20265_XAU_XAG_FAILRV_D1`.
- Entry formation: sixty-two synchronized completed D1 closes; shifts 3..62
  define the channel and shifts 2 then 1 define the ordered event.
- Exit formation: newest twenty synchronized completed D1 ratios.
- Expected cadence: five to fifteen completed packages per full post-warm-up
  year; retire below five.
- Q02 data window: `2018.07.02` through `2024.12.31`.
- Runtime data: Darwinex-native D1 time/close, ATR, spread, quote, position,
  deal, and contract metadata only.

## Formula

At completed D1 shift `k`, define:

```text
r[k]  = ln(XAU_close[k]) - ln(XAG_close[k])
r0    = r[1]
r1    = r[2]
upper = max(r[3], ..., r[62])
lower = min(r[3], ..., r[62])
mean20 = average(r[1], ..., r[20])
```

All paired timestamps must match exactly. All closes must be positive and all
arithmetic finite. Require `upper-lower > 1e-12`. Equality with either channel
boundary is not an outside break and is not a strict inside re-entry.

## Rules

These are the complete authorized baseline. There is no parameter sweep and
no fallback to a current channel breakout, z-score, OLS, quantile, robust
scale, oscillator, calendar direction, external series, or prior pipeline
result.

## 4. Entry Rules

1. Require EA ID 20265, exact XAU D1 host, slot 0, registered XAU/XAG legs,
   fixed risk/news/Friday contract, and every baseline input locked.
2. Evaluate entries only on a new host D1 bar after lifecycle repair and exits.
3. Align exactly sixty-two completed XAU and XAG D1 timestamps and calculate
   the frozen shifts-3..62 range plus shifts-2/1 event exactly as specified.
4. Reject any owned leg, invalid alignment/state, or already consumed newest
   event bar.
5. When `r1 > upper` and `lower < r0 < upper`, SELL XAU and BUY XAG.
6. When `r1 < lower` and `lower < r0 < upper`, BUY XAU and SELL XAG.
7. Consume the newest completed D1 event timestamp before spread, quote, ATR,
   sizing, or order checks; a rejection, failure, stop, or restart cannot retry
   that event.
8. Require XAU spread no greater than 1,500 points and XAG spread no greater
   than 3,000 points, executable quotes, completed ATR, and valid volume data.
9. Split one aggregate fixed-cash risk budget equally between legs after each
   leg's independent frozen `3.5*ATR(20,D1)` stop normalization. Open both legs
   or immediately close any orphan. No take-profit is used.

## 5. Exit Rules

1. On a new D1 bar, close a short-ratio package (SELL XAU / BUY XAG) when the
   newest completed ratio is at or below the arithmetic mean of the newest
   twenty synchronized completed ratios.
2. Close a long-ratio package (BUY XAU / SELL XAG) when the newest completed
   ratio is at or above that mean.
3. Close both legs on invalid synchronized exit state, missing/orphan leg,
   duplicate leg, wrong opposite-side composition, or missing hard stop.
4. Close after thirty elapsed calendar days.
5. Per-leg broker hard stops and the framework kill switch remain binding.
6. Friday close is disabled to preserve the multi-day relative convergence
   path. No signal flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, risk/news/Friday
  contract, or locked strategy inputs.
- Reject stale, missing, unsynchronized, nonpositive, nonfinite, or degenerate
  ratio state; a channel contaminated by an event bar; a non-strict re-entry;
  an owned package; a consumed event; excessive spread; invalid quote/ATR/
  stop/volume; or failed basket atomicity.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle repair
  and exits run before entry-only filters.
- Runtime may not read a futures chain, volume series, inventory, file, API,
  analyst forecast, trained output, or portfolio result.

## 7. Trade Management Rules

- Maintain exactly zero or two owned legs with opposite sides and valid hard
  stops. Any other composition is closed immediately.
- Maintain at most one attempt per completed strict-reentry event bar.
- Recover entry time from current position/deal state after restart.
- Evaluate the convergence mean only from synchronized completed bars.
- No randomness, adaptive PnL fit, external state, partial close, scale-in,
  grid, martingale, or pyramiding.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_channel_bars_d1` | 60 | [60] | pre-event ratio range |
| `strategy_exit_mean_bars_d1` | 20 | [20] | completed-ratio convergence center |
| `strategy_range_epsilon` | 1e-12 | [1e-12] | degenerate-range boundary |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard stop |
| `strategy_max_hold_days` | 30 | [30] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |

Changing any window, event order, boundary, direction, risk split, stop, hold,
spread cap, retry rule, or carrier requires a new card and full pipeline.

## Author Claims

The sources support testing a state-dependent gold/silver relative-price
relationship and identify the ratio as an intermarket spread. They do not
claim that this failed-break event works, that the locked parameters are
optimal, that two CFDs reproduce a futures spread, or that the package
diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Risk is high: XAU/XAG basis,
spread and financing asymmetry, legging, gap risk, stop mismatch, continued
breakouts after re-entry, structural ratio breaks, sparse events, and residual
common metal or risk-asset beta can dominate the premise. Opposite legs do not
prove neutrality.

## Kill Criteria

- Retire on zero packages or fewer than five completed packages per full
  post-warm-up year.
- Fail on timestamp mismatch, channel contamination, outside-to-outside entry,
  non-strict re-entry, wrong sides, repeated event entry, orphan exposure,
  aggregate fixed-risk breach, missing hard stop, hold beyond thirty days,
  invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the channel, event order, side, exit mean,
  stop, hold, spread cap, retry contract, or carrier.

## Strategy Allowability Check

- [x] R1: two peer-reviewed DOI records and one governed CME carrier packet.
- [x] R2: fixed alignment, pre-event channel, ordered event, sides, risk,
  stops, and exits.
- [x] R3: registered XAU/XAG D1 and native V5 execution state only.
- [x] R4: deterministic extrema and arithmetic; no trained model, banned
  signal indicator, external feed, grid, or martingale.
- [x] Dedup: no exact/fuzzy identity or XAU/XAG failed-break mechanic; closest
  families manually resolved.

## Framework Alignment

- no_trade: exact host/slot, locked inputs, fixed risk/news/Friday contract,
  and cheap parameter guards.
- trade_entry: synchronized ratio load, frozen pre-event range, ordered
  outside-to-inside event, persisted event attempt, spread/quote/ATR/volume
  checks, and atomic two-leg fixed-risk open.
- trade_management: atomicity/stop repair, completed-ratio mean convergence,
  invalid-state close, and thirty-day stale exit.
- trade_close: basket close helper, per-leg broker hard stops, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a manual
backtest; live, demo, shadow, optimization, or stress setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio admission; portfolio-gate edit;
or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-07 | initial XAU/XAG failed-break reversion card | G0 | APPROVED |
| v1 | 2026-08-07 | deterministic V5 build and strict compile | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-07 | APPROVED | `decisions/2026-08-07_qm5_20265_xauxag_fail_rv_g0.md` |
| Q01 Build Validation | 2026-08-07 | PASS | `docs/ops/evidence/2026-08-07_qm5_20265_xauxag_fail_rv_q01_q02_enqueue.md` |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |
