# QM5_10467_mql5-bol-rsi-ma - Strategy Spec

**EA ID:** QM5_10467
**Slug:** `mql5-bol-rsi-ma`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

This EA trades H1 Bollinger Band mean reversion only when the D1 trend filter agrees with the direction. It buys on the next bar after the last closed H1 candle closes below the lower Bollinger Band, RSI(14) is below 30, and the last closed D1 candle is above the D1 SMA. It sells on the mirrored condition above the upper Bollinger Band with RSI above 70 and the last closed D1 candle below the D1 SMA. Exits occur when price touches the Bollinger middle band, when an opposite setup appears, or when the broker-side 1.5 ATR stop / 2R target is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 2+ | Bollinger Band period on the chart timeframe. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger Band standard-deviation multiplier. |
| `strategy_rsi_period` | 14 | 2+ | RSI lookback period on the chart timeframe. |
| `strategy_rsi_oversold` | 30.0 | 0-100 | Long threshold for oversold RSI. |
| `strategy_rsi_overbought` | 70.0 | 0-100 | Short threshold for overbought RSI. |
| `strategy_d1_ma_period` | 200 | 2+ | D1 SMA period used as the trend filter. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback period for the stop distance. |
| `strategy_atr_sl_mult` | 1.5 | >0 | Stop-loss distance in ATR multiples. |
| `strategy_rr_tp` | 2.0 | >0 | Broker-side take-profit multiple of initial risk. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card primary baseline symbol and the source's H1 example market.
- `GBPUSD.DWX` - Liquid USD major suitable for Bollinger/RSI FX mean reversion.
- `USDJPY.DWX` - Liquid USD major suitable for Bollinger/RSI FX mean reversion.
- `USDCHF.DWX` - Liquid USD major suitable for Bollinger/RSI FX mean reversion.
- `USDCAD.DWX` - Liquid USD major suitable for Bollinger/RSI FX mean reversion.
- `AUDUSD.DWX` - Liquid USD major suitable for Bollinger/RSI FX mean reversion.
- `NZDUSD.DWX` - Liquid USD major suitable for Bollinger/RSI FX mean reversion.
- `XAUUSD.DWX` - Card explicitly includes XAUUSD after liquid DWX FX majors.

**Explicitly NOT for:**
- `SP500.DWX` - The approved card targets FX majors and XAUUSD, not equity indices.
- `XTIUSD.DWX` - The approved card does not include energy commodities.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` close and SMA trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | `hours to several H1 bars, until middle-band touch or 2R TP` |
| Expected drawdown profile | `Mean-reversion sleeve with ATR-capped single-trade risk` |
| Regime preference | `mean-reversion with trend-filter confirmation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase strategy`
**Pointer:** `https://www.mql5.com/en/code/32695`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10467_mql5-bol-rsi-ma.md`

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
| v1 | 2026-05-28 | Initial build from card | f25468ee-68b9-4a7e-b1ee-e721e571332d |
