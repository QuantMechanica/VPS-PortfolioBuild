# QM5_9238_mql5-hurst-ma-regime - Strategy Spec

**EA ID:** QM5_9238
**Slug:** mql5-hurst-ma-regime
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA computes a Hurst exponent with rescaled range analysis over `fast + slow` closed H4 closes. When Hurst is above 0.5 it treats the market as trending and trades in the direction of price relative to the slow moving average. When Hurst is below 0.5 it treats the market as mean reverting and trades away from the fast moving average. It ignores the Hurst deadband from 0.48 to 0.52, exits trend trades when price closes back through the slow average or Hurst crosses below 0.5, exits mean-reversion trades when price returns to the fast average or Hurst crosses above 0.5, and applies an 18-bar failsafe time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ma_period` | 20 | 2-200 | Fast SMA period used for mean-reversion entry and exit. |
| `strategy_slow_ma_period` | 80 | fast+1-400 | Slow SMA period used for trend entry and exit. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the initial stop distance. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple for initial stop placement. |
| `strategy_trend_rr` | 2.2 | >0 | Reward/risk take-profit multiple for trend trades and fallback mean-reversion trades. |
| `strategy_hurst_deadband_low` | 0.48 | 0.0-0.5 | Lower bound of the no-entry Hurst deadband. |
| `strategy_hurst_deadband_high` | 0.52 | 0.5-1.0 | Upper bound of the no-entry Hurst deadband. |
| `strategy_max_hold_bars` | 18 | 1-200 | Failsafe maximum holding period in H4 bars. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap in points; 0 disables the cap and allows zero-spread DWX tester quotes. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved liquid FX symbol with complete DWX OHLC and ATR data.
- `GBPJPY.DWX` - card-approved FX cross with complete DWX OHLC and ATR data.
- `XAUUSD.DWX` - card-approved metal symbol with complete DWX OHLC and ATR data.

**Explicitly NOT for:**
- Equity index and energy `.DWX` symbols - not listed by the approved card for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Up to 18 H4 bars, about 3 trading days maximum |
| Expected drawdown profile | Moderate fixed-risk drawdown from ATR stops and mixed trend/mean-reversion regimes |
| Regime preference | Trend when Hurst > 0.5; mean-revert when Hurst < 0.5 |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/15222
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9238_mql5-hurst-ma-regime.md`

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
| v1 | 2026-06-20 | Initial build from card | b96858f0-1de1-4dd0-b477-959aadd57d9f |
