# QM5_10471_mql5-ma-trend — Strategy Spec

**EA ID:** QM5_10471
**Slug:** mql5-ma-trend
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades the current H1 price against a simple moving average read from the last closed bar. It opens long when the current Ask is above the SMA value from bar 1, and opens short when the current Bid is below that same SMA value. It holds one position per symbol and magic number, closes a long when the short condition appears, and closes a short when the long condition appears. Each entry uses a 1.5 x ATR(14) stop and a fixed 2R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 50 | 1+ | SMA period used for the price-versus-MA signal. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for stop distance. |
| `strategy_atr_sl_mult` | 1.5 | >0 | Stop distance multiplier applied to ATR(14). |
| `strategy_take_profit_rr` | 2.0 | >0 | Take-profit distance in multiples of initial risk. |
| `strategy_max_spread_points` | 0 | 0+ | Optional maximum spread in points; 0 disables the strategy-specific spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid DWX FX major with native OHLC and MA/ATR inputs.
- `GBPUSD.DWX` — liquid DWX FX major with native OHLC and MA/ATR inputs.
- `USDJPY.DWX` — liquid DWX FX major with native OHLC and MA/ATR inputs.
- `USDCHF.DWX` — liquid DWX FX major with native OHLC and MA/ATR inputs.
- `USDCAD.DWX` — liquid DWX FX major with native OHLC and MA/ATR inputs.
- `AUDUSD.DWX` — liquid DWX FX major with native OHLC and MA/ATR inputs.
- `NZDUSD.DWX` — liquid DWX FX major with native OHLC and MA/ATR inputs.
- `XAUUSD.DWX` — liquid precious-metal DWX symbol explicitly named by the card.
- `SP500.DWX` — liquid US large-cap index proxy present in the DWX matrix.
- `NDX.DWX` — liquid US technology index proxy present in the DWX matrix.
- `WS30.DWX` — liquid US blue-chip index proxy present in the DWX matrix.
- `GDAXI.DWX` — liquid European index proxy present in the DWX matrix.
- `UK100.DWX` — liquid UK index proxy present in the DWX matrix.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — no broker/test data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | hours to days |
| Expected drawdown profile | Trend-following whipsaw risk during sideways price action. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase, "MA Trend - expert for MetaTrader 5", https://www.mql5.com/en/code/23589
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10471_mql5-ma-trend.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | cd172bf9-10d1-4087-a40c-f02f7c1c0a11 |
