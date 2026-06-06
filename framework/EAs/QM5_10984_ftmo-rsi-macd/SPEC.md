# QM5_10984_ftmo-rsi-macd - Strategy Spec

**EA ID:** QM5_10984
**Slug:** ftmo-rsi-macd
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades H1 synchronized RSI and MACD reversals. A long entry requires RSI(14) to have crossed back above 30 within the last three closed bars, a bullish MACD(12,26,9) signal-line cross on the current closed bar, and the confirming candle closing above its midpoint. A short entry mirrors this with RSI crossing back below 70, a bearish MACD cross, and a close below the candle midpoint. The stop is placed beyond the RSI extreme sequence with an ATR buffer, the target is 2.0R, and open trades close early on an opposite MACD cross or after 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 only | Base timeframe for all RSI, MACD, ATR, and OHLC reads. |
| `strategy_rsi_period` | 14 | >1 | RSI period. |
| `strategy_rsi_oversold` | 30.0 | 0-100 | Long recovery threshold. |
| `strategy_rsi_overbought` | 70.0 | 0-100 | Short recovery threshold. |
| `strategy_rsi_signal_lookback` | 3 | >=1 | Closed bars allowed for the RSI recovery cross. |
| `strategy_rsi_sequence_max_bars` | 3 | >=1 | Bars scanned for the RSI extreme sequence used by the stop. |
| `strategy_macd_fast` | 12 | >0 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | >0 | MACD signal EMA period. |
| `strategy_macd_confirm_bars` | 2 | >=0 | Bars after the RSI recovery during which MACD may confirm. |
| `strategy_atr_period` | 14 | >0 | ATR period for stop and volatility filter. |
| `strategy_atr_percentile_bars` | 250 | >=10 | ATR history used for the 20th percentile filter. |
| `strategy_min_atr_percentile` | 0.20 | 0-1 | Minimum ATR percentile; below this, entries are skipped. |
| `strategy_stop_atr_buffer_mult` | 0.25 | >=0 | ATR buffer beyond the RSI extreme sequence. |
| `strategy_min_stop_atr_mult` | 0.80 | >0 | Minimum stop distance in ATR units. |
| `strategy_max_stop_atr_mult` | 2.50 | > min | Maximum stop distance in ATR units; wider setups are skipped. |
| `strategy_take_profit_r` | 2.0 | >0 | Fixed R-multiple target. |
| `strategy_time_exit_bars` | 36 | >0 | Maximum H1 bars to hold before strategy exit. |
| `strategy_spread_median_bars` | 20 | >=1 | Closed bars used for the median spread filter. |
| `strategy_spread_median_mult` | 1.50 | >0 | Current spread must be at most this multiple of the median. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed major FX symbol with DWX data availability.
- `GBPUSD.DWX` - Card-listed major FX symbol with DWX data availability.
- `USDJPY.DWX` - Card-listed major FX symbol with DWX data availability.
- `XAUUSD.DWX` - Card-listed liquid metal symbol with DWX data availability.

**Explicitly NOT for:**
- Non-DWX symbols - Research and backtest artifacts must keep the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker or custom-symbol tick evidence.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Intraday to 36 H1 bars; earlier on opposite MACD cross or 2R target. |
| Expected drawdown profile | Fixed-risk reversal system with skipped low-volatility and high-spread regimes. |
| Regime preference | Momentum reversal with indicator confluence. |
| Win rate target (qualitative) | Medium. |
| Expected trade frequency | H1 RSI extreme recovery plus MACD cross within two bars should be moderately active; conservative estimate 35-80 trades/year/symbol. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO, "10 Steps to Building a Trading Strategy", 2025-09-05, https://ftmo.com/en/blog/10-steps-to-building-a-trading-strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10984_ftmo-rsi-macd.md`

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
| v1 | 2026-06-06 | Initial build from card | 642e4836-e3be-4102-97fa-3fd35b35c721 |
