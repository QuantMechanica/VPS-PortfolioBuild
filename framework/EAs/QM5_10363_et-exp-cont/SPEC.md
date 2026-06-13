# QM5_10363_et-exp-cont - Strategy Spec

**EA ID:** QM5_10363
**Slug:** et-exp-cont
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

On each D1 bar, the EA checks whether the current trading day is the Monday after standard third-Friday monthly expiration and skips holiday-shifted weeks unless the prior closed D1 bar is Friday. If so, it compares the most recent Friday close against the close `strategy_direction_lookback_bars` daily bars earlier. A positive move opens a long market position and a negative move opens a short market position, both with a protective stop at `strategy_atr_sl_mult * ATR(strategy_atr_period)`. The position is closed once `strategy_time_to_exit_bars` D1 bars have elapsed, or earlier by protective stop or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_time_to_exit_bars` | 7 | 1-20 | Number of D1 bars to hold before the time exit |
| `strategy_direction_lookback_bars` | 7 | 1-20 | D1 bars before expiration Friday close used for direction comparison |
| `strategy_atr_period` | 20 | 2-100 | ATR period used for the protective stop |
| `strategy_atr_sl_mult` | 2.5 | 0.5-10.0 | ATR multiple used for stop distance |
| `strategy_min_stop_spreads` | 4 | 1-20 | Entry is skipped when stop distance is below this many current spreads |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - direct S&P 500 custom-symbol port of the source S&P futures rule for backtest.
- `NDX.DWX` - liquid US large-cap index CFD analog for cross-index confirmation and live-routable coverage.
- `WS30.DWX` - liquid US large-cap index CFD analog for cross-index confirmation and live-routable coverage.

**Explicitly NOT for:**
- Non-index forex, metals, commodities, and single-stock symbols - the card limits the setup to the S&P/index basket.
- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` - these are not canonical DWX symbols in the approved matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | `7 D1 bars` |
| Expected drawdown profile | Low-cadence monthly calendar effect with sparse-sample risk |
| Regime preference | Momentum continuation after monthly options expiration |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/offshores-trading-journal.21184/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10363_et-exp-cont.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-13 | Initial build from card | 2ee2430c-081c-49cd-84e4-73eea675d40e |
