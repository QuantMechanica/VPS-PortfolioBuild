---
strategy_id: MOP-TSMOM-2012_XTI_S10
source_id: MOP-TSMOM-2012
ea_id: QM5_20187
slug: wti-tsmom1m
status: APPROVED
g0_status: APPROVED
created: 2026-07-31
created_by: Research+Development
last_updated: 2026-07-31
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; Sections 3.1-3.2; Table 2 Panel B; Appendix A.4; governed complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: primary
markets: [commodities, energy, wti_crude]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
strategy_type_flags: [time-series-momentum, monthly-rebalance, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
expected_pf: 1.01
expected_dd_pct: 25.0
expected_trade_frequency: "Approximately twelve monthly WTI packages/year after warm-up; Q02 retires below five completed trades/year."
expected_trades_per_year_per_symbol: 12
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [risk_mode, friday_close_hold_semantics, restart_safe_attempt, source_to_cfd_basis, q02_frequency_floor]
target_modules: [QM_Common, QM_MagicResolver, QM_TradeManager, QM_NoTrade]
pipeline_phase: Q02
review_focus: "Adds directional WTI trend exposure to the XAU/SP500/NDX/XNG book using the missing source-declared one-month horizon. Q02 must falsify the futures-to-CFD translation and Q09 remains authoritative for realized correlation."
g0_approval_reasoning: "APPROVED under the OWNER 2026-07-31 commodity/energy sleeve mission: R1 complete 23-page peer-reviewed JFE source read with DOI and author-hosted PDF hash; R2 locked consecutive completed-month return sign, one-month hold, persisted attempt, fixed-risk ATR stop, and lifecycle guards; R3 registered native XTIUSD.DWX D1 carrier; R4 deterministic native arithmetic only. Exact dedup clean; source-horizon siblings and one-month cross-sectional reversal are manually distinct."
---

# QM5_20187 WTI One-Month Time-Series Momentum

## Hypothesis

WTI's own just-completed broker-calendar-month return can continue in the same
direction over the next month. On the first tradable D1 bar of a new month,
buy WTI after a positive completed monthly return and short WTI after a
negative completed monthly return, then renew at the next month boundary.

This is a directional WTI trend hypothesis. It adds an oil return driver that
is economically different from the current index/metal book and from the
book's XNG cumulative-RSI sleeve, but it does not claim realized decorrelation.
Q02 through Q09 remain authoritative.

## Source Traceability And Claim Boundary

Moskowitz, Ooi, and Pedersen (2012) study 58 liquid futures, including 24
commodities and NYMEX WTI. Section 3.2 defines time-series momentum by the sign
of each instrument's own prior `k`-month excess return, long positive and short
negative, held for `h` months. Table 2 Panel B explicitly includes the
one-month-lookback, one-month-hold commodity portfolio.

The paper does not report a WTI-only `k=1`, `h=1` result. It uses rolling
futures excess returns and inverse ex ante volatility sizing. This card uses a
Darwinex continuous CFD, completed month-end close-to-close log return,
framework fixed-risk sizing, and an ATR stop. Those are disclosed QM
translations. No source PF, drawdown, WTI-specific alpha, transaction-cost,
CFD-basis, or correlation statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation scan found no exact slug or strategy-ID
match and surfaced only horizon-family fuzzy matches. Manual mechanic review
resolved them:

- `QM5_20064_wti-tsmom2m` uses a completed 42-D1 return proxy; `QM5_20055`,
  `QM5_20059`, `QM5_12616`, and `QM5_12603` use 3/6/9/12-month trend states.
- `QM5_12709_commodity-reversal-1m` ranks four commodities and buys the loser
  while shorting the winner; this card follows WTI's own one-month sign.
- `QM5_20008_wti-month-ch3` requires a new three-month month-end high/low;
  `QM5_13150_wti-signmom` counts twelve separate monthly signs.
- `QM5_13100_wti-dmac16` compares a month-end close with a six-month mean;
  WTI calendar, inventory, expiry, weekday, and event EAs use different state.
- `QM5_12567_cum-rsi2-commodity` is a two-day cumulative-RSI pullback with a
  long-horizon price filter; this card has no oscillator or pullback logic.

The exact one-completed-calendar-month sign, same-direction mapping, and
one-month hold are jointly load-bearing. Reversing the sign or changing the
horizon recreates a sibling or a different source family.

## Markets, Timeframe, And Cadence

- Carrier: `XTIUSD.DWX`, D1, magic slot 0 only.
- Decision: the first tradable WTI D1 bar of every new broker month.
- Formation: the last two distinct, consecutive, completed broker-calendar
  month-end closes; current-month prices never enter the signal.
- Expected cadence: about twelve consumed attempts and nonzero-sign packages
  per complete post-warm-up year.
- Runtime data: MT5-native D1 OHLC, ATR, spread, broker calendar, positions,
  deal history, and terminal global state only.

## Rules

The following sections are the complete frozen baseline. No threshold,
confirmation filter, take-profit, parameter sweep, external feed, or
post-result rescue rule is authorized.

## Formula

Let `C1` be the close of the just-completed broker month and `C2` the close of
the preceding consecutive broker month:

`r1 = ln(C1 / C2)`

- `r1 > 0`: BUY `XTIUSD.DWX`.
- `r1 < 0`: SELL `XTIUSD.DWX`.
- `r1 = 0` or invalid/nonconsecutive history: remain flat for that month.

## 4. Entry Rules

1. Run only on `XTIUSD.DWX` D1 with `ea_id=20187`
   and `magic_slot_offset=0`.
2. Process lifecycle exits before entry-only gates.
3. Enter only on the first tradable D1 bar of a new broker-calendar month.
4. Persist the current month attempt before history, signal, spread, quote,
   news, ATR, stop, sizing, or order gates; never retry that month.
5. Reject if an open same-symbol/same-magic position or a current-month entry
   deal already exists.
6. Reconstruct exactly two consecutive completed month ends and apply the
   formula above.
7. Require spread in `[0, 1500]` points, valid ATR(20) on shift 1, a valid
   market quote, and a valid normalized stop.
8. Open one market BUY or SELL with no take-profit. The frozen hard stop is
   `3.5 * ATR(20,D1)` from entry.

## 5. Exit Rules

- Close the prior package on the first tradable D1 bar of the next broker
  month before considering renewal.
- Close any position older than 40 calendar days as a stale safety override.
- The broker hard stop is always authoritative.
- No take-profit, signal flip inside the month, Friday flattening, partial
  close, trail, or break-even rule exists.

## 6. Filters (No-Trade Module)

- Hard reject wrong symbol, timeframe, EA ID, or magic slot.
- Hard reject any input outside the frozen values below.
- Both news axes and the legacy news mode are OFF; the signal has no event
  dependency.
- Friday close is disabled because a full next-month hold is load-bearing.
- Framework kill switch and order/risk guards remain active.

## 7. Trade Management Rules

- One position maximum for the registered symbol and magic.
- Close only at month renewal, stale guard, framework safety action, or stop.
- The consumed-month marker survives restart; position/deal history provides
  a second no-reentry guard.
- No scale-in, pyramiding, grid, martingale, hedge, averaging, partial close,
  adaptive fit, or external runtime call.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_history_bars` | 80 | [80] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_max_hold_days` | 40 | [40] |
| `strategy_max_spread_points` | 1500 | [1500] |

All Q02 values are locked. The one-month horizon is source-declared before
testing; it is not an optimization sweep against the existing horizons.

## Risk

- Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- `RISK_FIXED` is the risk budget normalized by the frozen hard-stop distance
  through the V5 framework; it is not fixed notional exposure.
- `RISK_PERCENT` remains zero and no live setfile is authorized.
- Primary risks: trend reversal, monthly gaps, continuous-CFD roll/basis,
  financing, missing month-end history, high oil volatility, and source decay.

## Kill Criteria

- Retire below five completed trades per full post-warm-up year.
- Fail on zero trades, wrong sign, current-month leakage, nonconsecutive month
  endpoints, duplicate monthly entry, restart nondeterminism, missing stop,
  risk-mode mismatch, or governed PF/DD failure.
- Do not rescue failure with a threshold, oscillator, volatility regime,
  weekday/calendar filter, alternate horizon, or parameter sweep.

## Strategy Allowability Check

- [x] R1 reputable source: complete peer-reviewed JFE paper and durable hash.
- [x] R2 mechanical: fixed month endpoints, sign direction, renewal, attempt,
  stop, spread cap, and stale exit.
- [x] R3 testable: registered native `XTIUSD.DWX` D1 carrier.
- [x] R4 compliant: no trained model, banned indicator, grid, martingale,
  pyramiding, adaptive PnL fitting, or external runtime data.
- [x] Exact dedup clean; fuzzy horizon siblings manually resolved.

## Framework Alignment

- no_trade: exact carrier/ID/slot, frozen-input guard, framework safety gates.
- trade_entry: completed one-calendar-month return sign and restart-safe
  consumed attempt.
- trade_management: next-month renewal and forty-day stale close.
- trade_close: strategy close through the framework or the frozen broker stop.

## Safety Boundary

This authorization covers one card, deterministic ID/magic allocation, one
EA build, one `RISK_FIXED` backtest setfile, strict compilation, and one paced
Q02 enqueue. It does not authorize a live setfile, `T_Live`, AutoTrading, a
deploy manifest, portfolio admission, portfolio-gate edits, or a correlation
waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-31 | initial source-backed one-month WTI TSMOM candidate | Q02 | Q01 PASS; Q02 ENQUEUED, baseline pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-31 | APPROVED under OWNER commodity/energy sleeve mission | this card |
| Q01 Build Validation | 2026-07-31 | PASS: strict compile and V5 build check, 0 errors/warnings | `D:/QM/reports/framework/21/build_check_20260731_153245.json` |
| Q02 Baseline Screening | 2026-07-31 | ENQUEUED; baseline pending | work item `402dc257-b6bc-4ad5-b359-2156441513f0` |
