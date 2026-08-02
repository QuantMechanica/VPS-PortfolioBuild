---
strategy_id: MOP-TSMOM-2012_XNG_S11
source_id: MOP-TSMOM-2012
ea_id: QM5_20204
slug: xng-tsmom1m
type: strategy
status: APPROVED
g0_status: APPROVED
created: 2026-08-02
created_by: Research+Development
last_updated: 2026-08-02
execution_contract_ref: strategy-seeds/cards/approved/QM5_20204_xng-tsmom1m_card.md
strategy_mechanic: monthly-one-completed-calendar-month-xng-return-sign-time-series-momentum
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; Sections 3.1-3.2; Table 2 Panel B; Appendix A.4; governed complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: primary
sources:
  - "[[sources/MOP-TSMOM-2012]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/commodity-trend-premium]]"
indicators:
  - "[[indicators/completed-month-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, time-series-momentum, monthly-rebalance, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
period: D1
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
expected_trade_frequency: "Approximately twelve monthly natural-gas packages/year after the two-completed-month warm-up; Q02 retires below five completed trades/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_QUEUED
review_focus: "Falsify a slow symmetric XNG trend carrier whose completed-month sign and month-long hold differ from the certified QM5_12567 two-day RSI pullback; unchanged Q09 alone decides realized book correlation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, friday_close_hold_semantics, restart_safe_attempt, source_to_cfd_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER authorization decisions/2026-08-02_qm5_20204_xng_tsmom1m_g0.md: R1 PASS complete peer-reviewed JFE source; R2 PASS locked completed-month sign, monthly hold, persisted attempt, fixed-risk ATR stop and lifecycle; R3 PASS registered XNG D1 route; R4 PASS deterministic native arithmetic only. Exact dedup clean; fuzzy horizon, direction, and carrier siblings manually resolved."
---

# QM5_20204 XNG One-Month Time-Series Momentum

## Hypothesis

Natural gas can continue in the direction of its just-completed
broker-calendar-month return because production, storage, transport, hedging,
and demand shocks adjust over time. On the first tradable D1 bar of each month,
buy after a positive completed monthly return and short after a negative one,
then renew at the next month boundary.

This is a slow, symmetric trend hypothesis rather than the certified book's
short-horizon XNG oscillator pullback. Different logic does not prove low
realized correlation; Q02 through Q09 remain authoritative.

## Source Traceability And Claim Boundary

Moskowitz, Ooi, and Pedersen (2012) study 58 liquid futures, including a
24-contract commodity group containing natural gas. Section 3.2 defines
time-series momentum by the sign of an instrument's own past `k`-month excess
return, long positive and short negative, held for `h` months. Table 2 Panel B
explicitly reports the commodity-futures `k=1`, `h=1` family.

The paper does not report a natural-gas-only `k=1`, `h=1` result. It uses
rolled futures excess returns and inverse ex-ante volatility sizing. This card
uses a Darwinex continuous CFD, completed month-end close-to-close log return,
framework fixed-risk sizing, and an ATR hard stop. No source PF, drawdown,
XNG-specific alpha, transaction-cost, CFD-basis, or correlation result is
imported.

## Non-Duplicate Decision

The deterministic pre-allocation scan found no exact slug or strategy-ID
collision and surfaced expected fuzzy family matches. Manual review resolves
them:

- `QM5_12567_cum-rsi2-commodity` uses a two-day cumulative RSI(2), SMA(200)
  alignment, long pullback entry, and at most five D1 holding bars. This card
  has no oscillator, is symmetric, and holds to the next month boundary.
- `QM5_20063_xng-tsmom3m` uses 63 completed D1 bars; `QM5_12804` uses 252 D1
  bars plus a volatility corridor. This card reconstructs exactly one
  completed broker-calendar month and has no participation corridor.
- `QM5_20054_xng-1m-contr` fades the completed one-month sign under Mishra and
  Smyth's contrarian hypothesis. This card follows the sign under the JFE
  time-series-momentum hypothesis; direction is load-bearing.
- `QM5_20187_wti-tsmom1m` is the source-pure WTI carrier. This card tests the
  natural-gas carrier and changes only the symbol-specific spread ceiling.
- `QM5_20051_energy-xmom1` ranks XTI versus XNG and manages two opposite legs;
  this card compares XNG with zero and owns no companion leg.

The exact XNG carrier, one-completed-calendar-month information object,
same-direction mapping, and one-month lifecycle are jointly load-bearing.

## Markets, Timeframe, And Cadence

- Carrier: exact `XNGUSD.DWX`, D1, magic slot 0.
- Decision: first genuine XNG D1 bar of a new broker month.
- Formation: the latest two distinct consecutive completed broker-month
  closes; current-month prices never enter the signal.
- Expected cadence: approximately twelve consumed attempts and nonzero-sign
  packages per complete post-warm-up year.
- Runtime: native MT5 D1 OHLC, ATR, spread, broker calendar, positions, deal
  history, and persisted framework state only.

## Formula

Let `C1` be the close of the just-completed broker month and `C2` the close of
the preceding consecutive broker month:

`r1 = ln(C1 / C2)`

- `r1 > 0`: BUY `XNGUSD.DWX`.
- `r1 < 0`: SELL `XNGUSD.DWX`.
- `r1 = 0` or invalid/nonconsecutive history: consume the month and stay flat.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
frozen baseline. There is no parameter sweep or alternate direction test.

## 4. Entry Rules

1. Require exact `XNGUSD.DWX`, D1, `ea_id=20204`, and magic slot 0.
2. Process lifecycle exits before entry-only gates and evaluate only on the
   first genuine D1 bar of a new broker month.
3. Persist the month attempt before history, signal, spread, quote, news,
   stop, sizing, or order gates. A restart, rejection, stop, or flat signal
   cannot retry that month.
4. Reject if an owned position or current-month entry deal already exists.
5. Reconstruct the two consecutive completed month-end closes and apply the
   formula above without current-month leakage.
6. Require a spread in `[0, 3000]` points, valid `ATR(20)` on shift 1, a valid
   market quote, and a valid normalized stop.
7. Open one market BUY or SELL with no take-profit. The frozen hard stop is
   `3.5 * ATR(20,D1)` from entry.

## 5. Exit Rules

1. Close the prior package on the first genuine D1 bar of the next broker
   month before considering renewal.
2. Close any position aged at least 40 calendar days as a stale safety repair.
3. The broker hard stop and framework kill switch remain authoritative.
4. There is no take-profit, intramonth signal flip, Friday flattening, partial
   close, trailing stop, break-even move, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed on wrong symbol, timeframe, EA ID, magic slot, or unlocked
  framework/strategy inputs.
- Fail closed on invalid or nonconsecutive history, nonpositive price, invalid
  logarithm, ATR, quote, stop, spread, attempt state, or existing exposure.
- Both news axes and legacy news mode are OFF for Q02. Lifecycle exits are
  never delayed by entry-only checks.
- Friday close is OFF because the source hold is a full month.
- No futures curve, storage, weather, inventory, COT, CSV, API, analyst input,
  discretionary switch, or trained output is read at runtime.

## 7. Trade Management Rules

- One position maximum for the registered symbol and magic.
- The consumed-month terminal marker plus position/deal history blocks restart
  and post-stop re-entry.
- Manage month renewal and the forty-day stale close on every new D1 bar.
- No scale-in, pyramid, grid, martingale, averaging, partial close, adaptive
  fit, external runtime signal, or cross-symbol state.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_history_bars` | 80 | [80] | bounded completed-month reconstruction |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale repair |
| `strategy_max_spread_points` | 3000 | [3000] | XNG entry spread ceiling |

The WTI S10 execution contract is ported without signal or risk changes; only
the carrier-specific spread ceiling differs. No baseline sweep is authorized.

## Author Claims

The paper supports a one-month-lookback, one-month-hold time-series-momentum
family for pooled commodity futures. It does not claim this single-XNG CFD
translation is profitable, stable, or uncorrelated to the current book.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is normalized through the frozen hard-stop
distance, not fixed notional exposure. Primary risks are sharp natural-gas
reversals, gaps, monthly endpoint availability, continuous-CFD roll/basis and
financing, stop-outs, source decay, and realized correlation with QM5_12567.

## Kill Criteria

Retire below five completed trades per full post-warm-up year or on nonpositive
Q02 economics. Fail on wrong sign, current-month leakage, nonconsecutive
endpoints, duplicate monthly entry, restart nondeterminism, missing hard stop,
risk-mode mismatch, or any governed PF/DD breach. Do not rescue failure with a
threshold, oscillator, volatility corridor, alternate horizon, opposite
direction, stop retune, or parameter sweep.

## Strategy Allowability Check

- [x] R1: peer-reviewed JFE paper, DOI, author-hosted complete text, durable
  retrieval hash, and explicit natural-gas source membership.
- [x] R2: fixed completed-month endpoints, same-sign mapping, monthly renewal,
  persisted attempt, fixed-risk stop, spread cap, and stale guard.
- [x] R3: registered native `XNGUSD.DWX` D1 route.
- [x] R4: deterministic price/calendar/ATR arithmetic only; no prohibited
  model, external runtime feed, grid, martingale, or pyramiding.
- [x] Expected cadence exceeds the five-per-year Q02 floor.
- [x] Exact dedup clean; fuzzy family siblings manually resolved.

## Framework Alignment

- no_trade: exact route, locked inputs, history, spread, ATR, quote, stop,
  position, deal, and attempt guards.
- trade_entry: completed one-calendar-month log-return sign and restart-safe
  consumed attempt.
- trade_management: next-month renewal and forty-day stale close.
- trade_close: framework strategy close or frozen broker hard stop.

## Safety Boundary

No live/demo/shadow setfile, AutoTrading action, `T_Live` mutation, deploy or
T_Live manifest, portfolio admission, portfolio-gate edit, KPI claim,
correlation waiver, manual backtest, or certification is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-02 | initial source-backed XNG one-month TSMOM card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-02 | APPROVED; R1-R4 PASS | `decisions/2026-08-02_qm5_20204_xng_tsmom1m_g0.md` |
| Q01 Build Validation | - | PENDING | `framework/EAs/QM5_20204_xng-tsmom1m/` |
| Q02 Baseline Screening | - | NOT_QUEUED | `XNGUSD.DWX` |
