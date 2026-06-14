# QM5_10825_tv-macd-mtf - Strategy Spec

**EA ID:** QM5_10825
**Slug:** tv-macd-mtf
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (TradingView open-source strategy)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades MACD momentum on the chart timeframe. A long entry is allowed when MACD(12,26,9) crosses above its signal line or has a bullish histogram, H1 MACD direction is bullish, and the M30 anti-sideway filter confirms EMA(34) above EMA(89) with ATR(14) above the configured minimum. A short entry mirrors those rules. Each trade opens with a 2.0 ATR stop and 3.0 ATR target; open positions close early on a MACD reversal aligned with H1 direction or after 96 chart bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_macd_fast | 12 | 1-100 | Fast MACD EMA period. |
| strategy_macd_slow | 26 | 2-200 | Slow MACD EMA period; must exceed fast. |
| strategy_macd_signal | 9 | 1-100 | MACD signal smoothing period. |
| strategy_htf_tf | PERIOD_H1 | M15-D1 | Higher-timeframe MACD direction filter. |
| strategy_anti_sideway_tf | PERIOD_M30 | M15-H1 | Timeframe for EMA/ATR anti-sideway filter. |
| strategy_ema_fast | 34 | 1-200 | Fast EMA in the anti-sideway filter. |
| strategy_ema_slow | 89 | 2-400 | Slow EMA in the anti-sideway filter; must exceed fast. |
| strategy_atr_period | 14 | 1-100 | ATR period used by filter and brackets. |
| strategy_min_atr_points | 0.0 | 0.0+ | Minimum M30 ATR in symbol points. |
| strategy_min_ema_sep_points | 0.0 | 0.0+ | Minimum M30 EMA separation in symbol points. |
| strategy_atr_sl_mult | 2.0 | 0.1-10.0 | Initial stop distance in ATR multiples. |
| strategy_atr_tp_mult | 3.0 | 0.1-20.0 | Initial target distance in ATR multiples. |
| strategy_max_bars | 96 | 0-1000 | Optional max hold time in chart bars; 0 disables. |
| strategy_enable_long | true | true/false | Enables long entries. |
| strategy_enable_short | true | true/false | Enables short entries. |
| strategy_trade_start_hour | 0 | 0-23 | Optional broker-hour start for entry permission. |
| strategy_trade_end_hour | 24 | 0-24 | Optional broker-hour end for entry permission. |
| strategy_max_spread_points | 0.0 | 0.0+ | Optional max spread in points; 0 disables. |
| strategy_reversal_exit_enabled | true | true/false | Enables MACD reversal exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 primary P2 basket forex major.
- GBPUSD.DWX - card R3 primary P2 basket forex major.
- USDJPY.DWX - card R3 primary P2 basket forex major.
- XAUUSD.DWX - card R3 primary P2 basket gold market.
- GDAXI.DWX - DWX matrix DAX equivalent for the card's GER40.DWX entry.
- NDX.DWX - card R3 primary P2 basket US index.
- WS30.DWX - card R3 primary P2 basket US index.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; registered as GDAXI.DWX instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 and M30 |
| Multi-timeframe refs | H1 MACD direction; M30 EMA/ATR anti-sideway filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 140 |
| Typical hold time | Not stated in frontmatter; bounded by optional 96 M15 bars from the card. |
| Expected drawdown profile | Generic MTF momentum risk; over-parameterized scoring risk noted by the card. |
| Regime preference | Trend-following momentum with anti-chop filter. |
| Win rate target (qualitative) | Not stated in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/0VIgV9kM-Hungpixi-MACD-Enhanced-MTF-with-Signal-Filter-Anti-Sideway/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10825_tv-macd-mtf.md`

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
| v1 | 2026-06-14 | Initial build from card | 84cd9dc5-1c06-4e82-8fea-d9ef02572454 |
