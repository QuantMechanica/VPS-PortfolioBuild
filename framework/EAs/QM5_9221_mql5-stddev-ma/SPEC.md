# QM5_9221_mql5-stddev-ma - Strategy Spec

**EA ID:** QM5_9221
**Slug:** `mql5-stddev-ma`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades H1 volatility expansion after a closed bar. Standard Deviation(20) must be higher than its previous closed-bar value, and the last closed close must be above SMA(20) for a long or below SMA(20) for a short. Entries are sent at the next bar through the framework market entry path. Exits occur when price crosses back through SMA(20), when Standard Deviation falls for two consecutive closed bars, or when the trade has been open for 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stddev_period` | 20 | 2-200 | Standard Deviation lookback on closed H1 bars. |
| `strategy_sma_period` | 20 | 2-200 | SMA side filter and SMA exit lookback. |
| `strategy_atr_period` | 14 | 2-200 | ATR lookback for initial stop distance. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiple used for initial stop loss. |
| `strategy_take_rr` | 1.8 | 0.1-10.0 | Initial take-profit multiple of stop risk. |
| `strategy_max_hold_bars` | 36 | 1-500 | Failsafe time exit in H1 bars. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional wide-spread cap in points; 0 leaves the framework/default spread convention in force. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with complete DWX OHLC data.
- `XAUUSD.DWX` - card-listed gold symbol with complete DWX OHLC data.
- `GDAXI.DWX` - card-listed DAX index symbol with complete DWX OHLC data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build only registers the card-stated DWX symbols verified in the matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Up to 36 H1 bars by card time stop. |
| Expected drawdown profile | Volatility-expansion trend following with ATR-defined initial risk and fixed 1.8R target. |
| Regime preference | Volatility expansion with trend-following side filter. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by Standard Deviation", MQL5 Articles, 2022-07-18, https://www.mql5.com/en/articles/11185
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9221_mql5-stddev-ma.md`

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
| v1 | 2026-06-26 | Initial build from card | 0f9a46c1-d64b-4fd8-be0b-7a6de4f8faab |
