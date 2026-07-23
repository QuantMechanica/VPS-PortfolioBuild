# QM5_12517_hlhb-trend — Strategy Spec

**EA ID:** QM5_12517
**Slug:** `hlhb-trend`
**Source:** `3826b7f5-8cc3-536f-8093-ff36dd567ef4` (see `strategy-seeds/sources/3826b7f5-8cc3-536f-8093-ff36dd567ef4/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-23

---

## 1. Strategy Logic

HLHB Forex Trend-Catcher. On each closed H1 bar, compute EMA(5) and EMA(10) on
the median price. A fresh cross of EMA(5) above EMA(10) is the long trigger
event; a fresh cross below is the short trigger event. The cross must be
confirmed by RSI(10) being above its 50 centerline (long) or below it (short)
— read as a state, not a second crossing event, since two independent fresh
crossovers on the same bar essentially never coincide. Entries additionally
require ADX(14) >= 25 (toggleable, default on) confirming trend strength.
Exit is by whichever comes first: a 400-pip take profit, a 150-pip initial
stop that then trails at the same 150-pip distance once price moves
favourably, an opposite-direction EMA cross closing the position early, or
the framework's Friday end-of-week flat rule (no weekend exposure).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | 2-20 | Fast EMA period on median price |
| `strategy_ema_slow_period` | 10 | 5-50 | Slow EMA period on median price |
| `strategy_rsi_period` | 10 | 2-30 | RSI period used as the momentum confirmation state |
| `strategy_rsi_centerline` | 50.0 | 40-60 | RSI centerline; above = bull state, below = bear state |
| `strategy_use_adx_filter` | true | true/false | Enable/disable the ADX trend-strength filter (source toggle) |
| `strategy_adx_period` | 14 | 5-30 | ADX period for the trend-strength regime filter |
| `strategy_adx_min` | 25.0 | 15-40 | Minimum ADX value required to allow entry |
| `strategy_take_profit_pips` | 400 | 100-800 | Profit target distance in pips |
| `strategy_trailing_stop_pips` | 150 | 50-300 | Initial protective stop distance and trailing-stop step, in pips |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary source market (EUR/USD), direct DWX FX instrument.
- `GBPUSD.DWX` — secondary source market (GBP/USD), direct DWX FX instrument.

**Explicitly NOT for:**
- Indices/metals/crypto `.DWX` symbols — the HLHB system is an FX-major trend
  system per the source article; card R3 only clears EURUSD/GBPUSD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~50 |
| Typical hold time | hours to a few days (400-pip target / 150-pip trail) |
| Expected drawdown profile | trend-following whipsaw losses in choppy regimes, offset by trend runs |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3826b7f5-8cc3-536f-8093-ff36dd567ef4`
**Source type:** `forum`
**Pointer:** `https://web.archive.org/web/20191215105954/https://backtest-rookies.com/2019/03/28/tradingview-hlhb-forex-trend-catcher-system/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12517_hlhb-trend.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-23 | Rebuild in place: added missing Q08 MAE-sampling hook, fixed OnTick news-gate ordering to the 2026-07-02 canonical order, added ZeroMemory(req) | d2140649-2fa4-4392-b2e3-8587e5527f43 |
