# QM5_10276_whc-rsi-bb - Strategy Spec

**EA ID:** QM5_10276
**Slug:** `whc-rsi-bb`
**Source:** `1b906e79-c619-5a61-90db-ee19ac95a19f` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA is a long-only daily mean-reversion system. It opens a market buy after a closed D1 bar when RSI(14) is below 30 and the close is at or below the lower Bollinger Band(20, 2). It closes the long when RSI(14) rises above 70 or the closed D1 price is at or above the upper Bollinger Band(20, 2). Because the source has no explicit stop loss, the EA adds the card-requested catastrophic stop at 2.0 x ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for RSI, Bollinger, and ATR reads. |
| `strategy_rsi_period` | `14` | `> 1` | RSI lookback period. |
| `strategy_rsi_oversold` | `30.0` | `0-100` | Entry threshold; long only when RSI is below this value. |
| `strategy_rsi_overbought` | `70.0` | `0-100` | Exit threshold; close long when RSI is above this value. |
| `strategy_bb_period` | `20` | `> 1` | Bollinger Band lookback period. |
| `strategy_bb_deviation` | `2.0` | `> 0` | Bollinger Band standard-deviation multiplier. |
| `strategy_atr_period` | `14` | `> 1` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | ATR multiplier for the catastrophic stop distance. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - DWX Nasdaq 100 index CFD for large-cap index mean reversion.
- `WS30.DWX` - DWX Dow 30 index CFD for large-cap index mean reversion.
- `SP500.DWX` - DWX S&P 500 custom symbol for backtest-only large-cap index coverage.
- `XAUUSD.DWX` - DWX gold metal instrument matching the card's metal portability note.
- `XAGUSD.DWX` - DWX silver metal instrument matching the card's metal portability note.
- `EURUSD.DWX` - Major FX pair with daily OHLC history for RSI and Bollinger indicators.
- `GBPUSD.DWX` - Major FX pair with daily OHLC history for RSI and Bollinger indicators.
- `USDJPY.DWX` - Major FX pair with daily OHLC history for RSI and Bollinger indicators.
- `AUDUSD.DWX` - Major FX pair with daily OHLC history for RSI and Bollinger indicators.
- `USDCAD.DWX` - Major FX pair with daily OHLC history for RSI and Bollinger indicators.
- `USDCHF.DWX` - Major FX pair with daily OHLC history for RSI and Bollinger indicators.
- `NZDUSD.DWX` - Major FX pair with daily OHLC history for RSI and Bollinger indicators.

**Explicitly NOT for:**
- `XNGUSD.DWX` - Energy commodity; the card names metals, not all commodities.
- `XTIUSD.DWX` - Energy commodity; the card names metals, not all commodities.

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
| Expected trade frequency | not specified in card frontmatter |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter |
| Regime preference | mean-revert |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository source
**Pointer:** `whchien/ai-trader`, `ai_trader/backtesting/strategies/classic/rsi.py`, class `RsiBollingerBandsStrategy`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10276_whc-rsi-bb.md`

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
| v1 | 2026-06-12 | Initial build from card | d1f9089d-2c4d-4b01-99d0-256912380147 |
