# QM5_10087_mql5-cloud-rsi - Strategy Spec

**EA ID:** QM5_10087
**Slug:** mql5-cloud-rsi
**Source:** a120af9a-fb72-526c-bb80-d1d098a617b5 (see `sources/mql5-examples`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades a two-candle reversal pattern on H1. It buys when a bearish candle is followed by a bullish Piercing Line candle that opens below the prior low and closes above the prior candle midpoint, with RSI(1) below 40 on the completed signal candle. It sells when a bullish candle is followed by a bearish Dark Cloud Cover candle that opens above the prior high and closes below the prior candle midpoint, with RSI(1) above 60. Long positions close when RSI crosses downward through 70 or 30, and short positions close when RSI crosses upward through 30 or 70.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 1 | 1-10 | RSI period used for entry confirmation and exit crossings. |
| `strategy_buy_rsi_max` | 40.0 | 0-100 | Buy confirmation threshold; RSI must be below this value. |
| `strategy_sell_rsi_min` | 60.0 | 0-100 | Sell confirmation threshold; RSI must be above this value. |
| `strategy_exit_lower_level` | 30.0 | 0-100 | Lower RSI crossing level used for long and short exits. |
| `strategy_exit_upper_level` | 70.0 | 0-100 | Upper RSI crossing level used for long and short exits. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiplier for the protective stop distance. |
| `strategy_min_body_atr_mult` | 0.0 | 0.0-10.0 | Optional minimum first-candle body size as a fraction of ATR; 0.0 means any nonzero body. |
| `strategy_gap_tolerance_points` | 0 | 0-1000 | Optional fixed tolerance in points for the Piercing Line / Dark Cloud opening gap test. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional fixed spread filter in points; 0 disables the filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with OHLC and RSI availability in the DWX matrix.
- `GBPUSD.DWX` - card-listed major FX pair with OHLC and RSI availability in the DWX matrix.
- `USDJPY.DWX` - card-listed major FX pair with OHLC and RSI availability in the DWX matrix.
- `XAUUSD.DWX` - card-listed gold symbol with OHLC and RSI availability in the DWX matrix.

**Explicitly NOT for:**
- Symbols outside the card's target list - not registered for this EA and not part of the approved R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Expected trade frequency | Not specified in card frontmatter; inferred from 45 trades/year/symbol as intermittent H1 signals. |
| Typical hold time | Not specified in card frontmatter; exits are RSI threshold crossings or ATR stop. |
| Expected drawdown profile | Not specified in card frontmatter; fixed $1,000 risk per trade in baseline. |
| Regime preference | Mean-reversion candlestick reversal with oscillator confirmation. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** a120af9a-fb72-526c-bb80-d1d098a617b5
**Source type:** MQL5 article
**Pointer:** Artyom Trishkin, "Deconstructing examples of trading strategies in the client terminal", MQL5 Articles, 13 February 2025
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10087_mql5-cloud-rsi.md`

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
| v1 | 2026-06-11 | Initial build from card | b714c7b7-25f9-4674-a27d-5437e263e366 |
