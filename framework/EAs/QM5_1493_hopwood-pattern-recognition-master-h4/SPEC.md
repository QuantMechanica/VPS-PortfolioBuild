# QM5_1493_hopwood-pattern-recognition-master-h4 - Strategy Spec

**EA ID:** QM5_1493
**Slug:** hopwood-pattern-recognition-master-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades a closed H4 three-bar reversal pattern. Bar t-2 must be a strong directional candle, bar t-1 must be a small consolidation body that stays near the prior range, and bar t must reverse strongly in the opposite direction while RSI(14) re-enters from oversold or overbought. Long entries also require D1 close above D1 SMA(50); short entries require D1 close below D1 SMA(50). The EA enters at market on the H4 close, places a fixed structural ATR stop, partially exits 60% at 1.5 ATR, exits the remainder on an RSI(50) reversal, and time-stops positions that fail to reach TP1 after 18 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period used for body thresholds, SL, and TP1 distance. |
| `strategy_strong_move_atr_mult` | 1.0 | 0.5-3.0 | Minimum bar t-2 body size as ATR multiple. |
| `strategy_consolidation_body_atr_mult` | 0.5 | 0.1-1.5 | Maximum bar t-1 body size as ATR multiple. |
| `strategy_retracement_atr_mult` | 0.25 | 0.0-1.0 | Allowed bar t-1 range spillover around bar t-2. |
| `strategy_reversal_body_atr_mult` | 0.7 | 0.2-2.0 | Minimum bar t reversal body size as ATR multiple. |
| `strategy_rsi_period` | 14 | 5-50 | RSI period for extreme and exit gates. |
| `strategy_rsi_oversold` | 30.0 | 5-45 | Bullish RSI extreme and re-entry level. |
| `strategy_rsi_overbought` | 70.0 | 55-95 | Bearish RSI extreme and re-entry level. |
| `strategy_rsi_midline` | 50.0 | 40-60 | RSI level used for remaining-position exit. |
| `strategy_d1_sma_period` | 50 | 20-200 | D1 macro-bias SMA period. |
| `strategy_sl_atr_mult` | 1.5 | 0.5-5.0 | ATR distance added beyond consolidation-bar extreme for SL. |
| `strategy_tp1_atr_mult` | 1.5 | 0.5-5.0 | TP1 distance from entry as ATR multiple. |
| `strategy_tp1_close_fraction` | 0.60 | 0.10-0.90 | Fraction of position closed at TP1. |
| `strategy_time_stop_h4_bars` | 18 | 1-80 | H4 bars before closing positions that did not hit TP1. |
| `strategy_warmup_h4_bars` | 80 | 50-300 | Minimum H4 history before entries. |
| `strategy_pattern_reuse_bars` | 16 | 0-80 | Cooldown after a Hopwood pattern fires. |
| `strategy_spread_lookback_bars` | 20 | 5-64 | H4 bars used for median spread filter. |
| `strategy_spread_median_mult` | 1.5 | 0.5-5.0 | Maximum current spread as a multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major matching Hopwood's original forex focus.
- `GBPUSD.DWX` - FX major matching Hopwood's original forex focus.
- `USDJPY.DWX` - FX major matching Hopwood's original forex focus.
- `AUDUSD.DWX` - FX major matching Hopwood's original forex focus.
- `USDCAD.DWX` - FX major matching Hopwood's original forex focus.
- `NDX.DWX` - Liquid index CFD where OHLC/RSI/ATR reversal logic is portable.
- `WS30.DWX` - Liquid index CFD where OHLC/RSI/ATR reversal logic is portable.
- `GDAXI.DWX` - DAX index CFD included in the card's portable index basket.
- `UK100.DWX` - FTSE index CFD included in the card's portable index basket.
- `XAUUSD.DWX` - Commodity CFD with sufficient OHLC/RSI/ATR data for the pattern.
- `XTIUSD.DWX` - Commodity CFD with sufficient OHLC/RSI/ATR data for the pattern.

**Explicitly NOT for:**
- Non-DWX symbols - build, test, and registry discipline require canonical `.DWX` names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 close and D1 SMA(50) macro-bias filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Intraday to three days; TP1 before 18 H4 bars or full time-stop at 18 H4 bars |
| Expected drawdown profile | ATR-bounded reversal losses with partial-profit exits |
| Regime preference | Volatility-expansion reversal in the D1 trend direction |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1493_hopwood-pattern-recognition-master-h4.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1493_hopwood-pattern-recognition-master-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | ffdda76c-7990-4d17-887a-9247bd8d4f12 |
