---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_9M_S30
variant_id: MOP-TSMOM-2012_XTI_9M_S30
source_id: MOP-WTI-TSMOM9-2026
ea_id: QM5_20293
slug: wti-tsmom9m
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20293_wti-tsmom9m_card.md
execution_contract_status: DRAFT
created: 2026-08-12
created_by: Research+Development
last_updated: 2026-08-12
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-TSMOM9-2026/source.md"
    quality_tier: A
    role: primary_own_price_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-sign-of-exact-nine-completed-broker-month-log-return-one-month-hold
sources:
  - "[[sources/MOP-WTI-TSMOM9-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, time-series-momentum, exact-nine-month-return, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202930000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI packages/year after ten completed month ends because only exact-zero or invalid nine-month states stay flat; Q02 must prove at least five completed positions/year or retire."
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
q01_status: NOT_STARTED
q02_status: NOT_STARTED
review_focus: "Falsify a direct WTI exact nine-completed-month own-return carrier absent from the XAU/SP500/NDX/XNG book; separate completed-month continuity and a pure sign from the existing 189-D1 nine-month signal with threshold and three-month confirmation; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, exact_nine_month_orientation, no_confirmation_or_threshold, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-12_qm5_20293_wti_tsmom9m_g0.md: R1 one complete-read peer-reviewed WTI source; R2 fixed ten endpoints, exact nine-month log return, symmetric direction, monthly attempt/renewal, stop, and lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic. The canonical checker found no exact identity; eleven expected shared-source fuzzy matches were manually separated, especially the prior 189-D1 nine-month rule with threshold and three-month confirmation."
---

# QM5_20293 WTI Nine-Month Time-Series Momentum

## Hypothesis

WTI can sustain directional regimes while production, investment,
inventories, transport, refining, hedging, and demand adjust. The sign of the
exact return across nine completed broker months may capture a slower crude-
oil state than the one-to-six-month carriers while reacting sooner than the
twelve-month carrier.

WTI is a crude-oil carrier absent from the certified XAU, SP500, NDX, and XNG
book. That carrier difference does not prove decorrelation, profitability, or
portfolio suitability. Q02 owns density and baseline economics; unchanged
downstream gates, including Q09, own robustness and realized overlap.

## Source Traceability And Claim Boundary

The sole source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-TSMOM9-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper documenting monthly own-return continuation over
the first twelve lags and including WTI among its commodity futures.

The source does not report a standalone WTI nine-month result. The exact
horizon, Darwinex continuous CFD, broker-month reconstruction, fixed-dollar
sizing, ATR hard stop, spread cap, attempt ledger, and lifecycle controls are
transparent QM mechanizations. No source return, alpha, Sharpe ratio,
drawdown, WTI-specific result, trade count, cost, CFD equivalence, or
correlation statistic is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,358 EA-registry rows and 469 cards. It found
no exact identity and returned eleven expected fuzzy same-source or `tsmom`
matches for manual review.

- `QM5_12616_tsmom-9m-commodity-xtiusd` uses a 189-D1 approximation, a 1.5%
  neutral threshold, and a 63-D1 same-sign confirmation. This card uses ten
  exact completed broker-month endpoints, a zero-only neutral state, and no
  confirmation;
- `QM5_20187`, `QM5_20064`, `QM5_20055`, `QM5_20280`, `QM5_20059`, and
  `QM5_12603` use one-, two-, three-, four-, six-, or twelve-month states;
- `QM5_20281` uses twelve-month formation and a two-month odd-epoch hold;
- `QM5_20056` requires six/twelve-month agreement and `QM5_20258` votes
  one/three/twelve-month signs;
- regression, rank, robust-return, path, sign-run, weighted-return, calendar,
  event, XNG, XAU/XAG, index, and oscillator systems observe different state
  objects or carriers.

The ten endpoints, monthly continuity, exact `(C[0], C[9])` orientation,
absence of a confirmation or neutral band, symmetric sign direction,
consumed attempt, and monthly renewal are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_SHARED_SOURCE_FUZZY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202930000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: ten consecutive completed broker-month closes spanning exactly
  nine completed months.
- Holding clock: next broker-month boundary, with a forty-calendar-day stale
  guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and framework state only.

## Formula

At the start of month `t`, let `C[0]..C[9]` be ten consecutive completed
month-end closes, ordered oldest to newest, with `C[9]` from month `t-1`:

```text
nine_month_return = ln(C[9] / C[0])
```

BUY when positive, SELL when negative, and remain flat when exactly zero or
invalid. Interior endpoints prove consecutive calendar coverage. Signal
magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no parameter sweep and
no fallback to 189 D1 bars, a three-month confirmation, neutral threshold,
different horizon, sign vote, return average, sort, clipping, regression,
moving average, oscillator, calendar direction, external series, or previous
pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20293`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current decision month before history, signal, spread, quote,
   news, stop, sizing, or order checks. A flat, rejected, failed, stopped, or
   blocked outcome cannot retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Reconstruct exactly ten completed month-end closes from bounded D1
   history. Require the newest endpoint to be the immediately prior month and
   every older month key to be consecutive.
6. Keep endpoints oldest to newest; require positive finite closes and
   strictly increasing timestamps.
7. Calculate one finite log return `ln(C[9]/C[0])`. Buy when positive and sell
   when negative; exact zero stays flat.
8. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and fixed-risk sizing.
9. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
   hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed/nonconsecutive endpoints, current-month leakage, nonpositive or
  nonfinite close, reversed endpoint orientation, invalid logarithm, zero
  signal, excessive spread, invalid quote, unavailable ATR, invalid stop, or
  invalid volume metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read futures curves, inventory, volume, open interest,
  files, APIs, analyst forecasts, trained outputs, optimizers, or portfolio
  results.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  positions and deal history. A marker from a future tester time is cleared so
  historical replay remains deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_return_months` | 9 | [9] | exact completed broker-month interval |
| `strategy_history_bars_d1` | 500 | [500] | bounded endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

Every endpoint, horizon, direction, attempt, risk, and lifecycle value is
locked. Any change requires a new card and full pipeline run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, report continuation across the first twelve monthly lags, and include
WTI in their commodity universe. They do not claim this nine-month WTI CFD
rule works, that nine months is optimal, that a continuous CFD reproduces
rolling futures, or that the candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, trend reversals, hard-stop slippage, and
correlation with XNG or risk assets can dominate the premise. The nine-month
return is a formation rule, not confidence or a sizing input.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on endpoint leakage, missing/interpolated/nonconsecutive months,
  reversed return orientation, a horizon other than nine completed months,
  any confirmation or neutral band, wrong-side entry, repeated monthly
  attempt, missing hard stop, hold beyond forty days, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing lookback, direction, entry clock, stop,
  hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: one tier-A peer-reviewed source with DOI, complete-paper evidence,
  durable retrieval hash, and explicit WTI membership.
- [x] R2: fixed endpoints, continuity, horizon, direction, attempt, hard stop,
  rollover, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: deterministic logarithm and comparison; no trained model,
  prohibited signal indicator, external feed, grid, or martingale.
- [x] Dedup: no exact identity; expected same-source fuzzy matches are
  manually separated from the prior confirmed/thresholded nine-month rule.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, ten-endpoint reconstruction, exact
  nine-month return sign, spread/quote/ATR/stop checks, and one fixed-risk
  order.
- trade_management: malformed-state repair, prior-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a
manual backtest; live, demo, shadow, optimization, or stress setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio admission;
portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-12 | initial source-bounded WTI nine-month card | G0 | APPROVED |
| v1-q01 | 2026-08-12 | deterministic V5 build, strict compile, target validation, exact-return reference vectors, and P1 artifact validation | Q01 | PASS |
| v1-q02-hold | 2026-08-12 | binding factory sample reached the seven-terminal CPU ceiling; no enqueue or backtest | Q01 | NOT_ENQUEUED_CPU_CEILING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-12 | APPROVED | `decisions/2026-08-12_qm5_20293_wti_tsmom9m_g0.md` |
| Q01 Build Validation | 2026-08-12 | PASS | `D:/QM/reports/compile/20260812_181052/summary.csv`; `D:/QM/reports/framework/21/build_check_20260812_181142.json`; `D:/QM/reports/pipeline/QM5_20293/P1/P1_QM5_20293_result.json` |
| Q02 Baseline Screening | 2026-08-12 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-12_qm5_20293_wti_tsmom9m_q01_cpu_stop.md` |
