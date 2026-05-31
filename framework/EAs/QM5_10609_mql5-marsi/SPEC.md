# QM5_10609_mql5-marsi - Strategy Spec

**EA ID:** QM5_10609
**Slug:** `mql5-marsi`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the MaRsi-Trigger trend state on completed H4 bars. The state is bullish when the fast MA is above the slow MA and/or the fast RSI is above the slow RSI, bearish when the combined comparison is negative, and neutral when the combined comparison nets to zero. It enters long when the latest closed bar turns bullish after the prior non-neutral bearish state, and enters short when the latest closed bar turns bearish after the prior non-neutral bullish state. Long positions close on bearish or neutral state; short positions close on bullish or neutral state; any position also closes after 16 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_timeframe` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for MaRsi state calculations. |
| `strategy_rsi_period` | `3` | `1+` | Fast RSI period from the MaRsi source indicator. |
| `strategy_rsi_price` | `PRICE_WEIGHTED` | MT5 applied price enum | Applied price for the fast RSI. |
| `strategy_rsi_long_period` | `13` | `1+` | Slow RSI period from the MaRsi source indicator. |
| `strategy_rsi_long_price` | `PRICE_MEDIAN` | MT5 applied price enum | Applied price for the slow RSI. |
| `strategy_ma_period` | `5` | `1+` | Fast moving-average period. |
| `strategy_ma_method` | `MODE_EMA` | MT5 MA method enum | Fast moving-average method. |
| `strategy_ma_price` | `PRICE_CLOSE` | MT5 applied price enum | Applied price for the fast moving average. |
| `strategy_ma_long_period` | `10` | `1+` | Slow moving-average period. |
| `strategy_ma_long_method` | `MODE_EMA` | MT5 MA method enum | Slow moving-average method. |
| `strategy_ma_long_price` | `PRICE_CLOSE` | MT5 applied price enum | Applied price for the slow moving average. |
| `strategy_signal_bar` | `1` | `1+` | Closed bar index used for entry and exit state. |
| `strategy_prior_state_lookback` | `128` | `1+` | Maximum bars scanned to find the prior non-neutral state. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.5` | `0+` | ATR multiplier for the catastrophic stop. |
| `strategy_max_hold_bars` | `16` | `0+` | Maximum completed H4 bars to hold; `0` disables. |
| `strategy_exit_on_neutral` | `true` | `true/false` | Whether neutral MaRsi state closes open positions. |

---

## 3. Symbol Universe

**Designed for:**
- `USDCHF.DWX` - source test symbol, directly available in the DWX matrix.
- `EURUSD.DWX` - liquid FX major matching the card's portable DWX FX baseline.
- `GBPUSD.DWX` - liquid FX major matching the card's portable DWX FX baseline.
- `XAUUSD.DWX` - DWX commodity symbol included in the card's target symbols.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data is available for build validation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Up to `16` H4 bars by fallback time stop. |
| Expected drawdown profile | Trend-state strategy with ATR catastrophic stop and no take-profit target. |
| Regime preference | trend-state-change |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/1129`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10609_mql5-marsi.md`

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
| v1 | 2026-05-31 | Initial build from card | 49934e18-60d1-451b-8363-9c7e3e0dc51b |
