# QM5_10898_muranno-bb-adx - Strategy Spec

**EA ID:** QM5_10898
**Slug:** `muranno-bb-adx`
**Source:** `6facee24-8a58-5bbf-88e9-38d44291db50` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades Bollinger Band mean reversion only when ADX(14) shows a non-trending range regime. On the close of the current chart bar, a long setup requires ADX(14) below 25, price below the lower Bollinger Band(20, 2), and RSI(5) crossing upward out of oversold. A short setup mirrors the rule at the upper band with RSI(5) crossing downward out of overbought.

The EA enters at the next bar open using a market order. It exits a long when price reaches the upper Bollinger Band, RSI(5) crosses above 70, or the position has been open for 24 bars; shorts exit at the lower band, RSI(5) below 30, or the same time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 2+ | Bollinger Band lookback period. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger Band standard-deviation multiplier. |
| `strategy_adx_period` | 14 | 2+ | ADX lookback period for range regime. |
| `strategy_adx_entry_max` | 25.0 | >0 | Maximum ADX allowed for entry. |
| `strategy_adx_skip_level` | 30.0 | >0 | Hard skip level if range regime is gone before entry. |
| `strategy_rsi_period` | 5 | 2+ | RSI period for cross-out trigger and exit. |
| `strategy_rsi_oversold` | 30.0 | 0-100 | Oversold threshold for long entries and short exits. |
| `strategy_rsi_overbought` | 70.0 | 0-100 | Overbought threshold for short entries and long exits. |
| `strategy_atr_period` | 14 | 1+ | ATR period for stop distance. |
| `strategy_atr_sl_mult` | 1.2 | >0 | ATR multiplier for baseline stop loss. |
| `strategy_stop_cap_pips` | 35 | 1+ | Maximum stop distance in pips for major forex pairs. |
| `strategy_spread_cap_fraction` | 0.20 | >0 | Maximum spread as a fraction of stop distance. |
| `strategy_time_exit_bars` | 24 | 1+ | Maximum holding time in bars. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 forex basket member with native DWX M15 data.
- `GBPUSD.DWX` - card R3 forex basket member with native DWX M15 data.
- `USDJPY.DWX` - card R3 forex basket member with native DWX M15 data.
- `AUDUSD.DWX` - card R3 forex basket member with native DWX M15 data.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use the `.DWX` suffix.
- Non-forex symbols - the stop cap is specified in pips for major forex pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Up to 24 M15 bars, about 6 hours maximum. |
| Expected drawdown profile | Mean-reversion losses cluster when a range expands into trend. |
| Regime preference | Range-regime Bollinger mean reversion with ADX below 25 and RSI(5) trigger. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6facee24-8a58-5bbf-88e9-38d44291db50`
**Source type:** book
**Pointer:** James Muranno, Mechanical Day Trading Strategies, local PDF `G:\My Drive\QuantMechanica\Ebook\PDF resources\Mechanical Day Trading Strategi - James Muranno.pdf`, pp. 52-55.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10898_muranno-bb-adx.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-14 | Initial build from card | d43508ab-8385-4c64-a201-a83bb7cbbb11 |
