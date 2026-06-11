# QM5_12367_tmom-single-ma - Strategy Spec

**EA ID:** QM5_12367
**Slug:** tmom-single-ma
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `ThewindMom/151-trading-strategies`, `src/strategies/stocks/single_ma.py`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA evaluates one completed D1 bar at a time after at least 60 D1 bars are available. It computes a selected moving average of close prices, defaulting to SMA(20), and treats a close above the average as a long state and a close below the average as a short state. It opens long when the completed close is above the moving average and opens short when the completed close is below it; existing positions are closed when the completed close crosses to the opposite side of the same moving average. Each entry uses a hard stop at 2.0 * ATR(14) from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for close, moving average, warmup, and ATR reads. |
| `strategy_ma_type` | `STRATEGY_MA_SMA` | `STRATEGY_MA_SMA`, `STRATEGY_MA_EMA` | Moving average type for the close-vs-MA state rule. |
| `strategy_ma_period` | `20` | `>= 1` | Moving average lookback period from the source default. |
| `strategy_warmup_bars` | `60` | `>= strategy_ma_period + 2` | Minimum closed D1 history required before entries can fire. |
| `strategy_atr_period` | `14` | `>= 1` | ATR lookback used for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | ATR multiple used to place the protective stop. |
| `strategy_min_distance_pct` | `0.0` | `>= 0` | Optional P3 flat-whipsaw gate; `0.0` disables it, `0.05` requires close-vs-MA distance of at least 0.05%. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major in the card's R3 portable D1 close-price basket.
- `GBPUSD.DWX` - liquid FX major in the card's R3 portable D1 close-price basket.
- `USDJPY.DWX` - liquid FX major in the card's R3 portable D1 close-price basket.
- `XAUUSD.DWX` - liquid metal CFD in the card's R3 portable D1 close-price basket.
- `GER40.DWX` - DAX index CFD in the card's R3 portable D1 close-price basket and present in the DWX symbol matrix.
- `NDX.DWX` - Nasdaq 100 index CFD in the card's R3 portable D1 close-price basket.
- `WS30.DWX` - Dow 30 index CFD in the card's R3 portable D1 close-price basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester data universe does not support them.
- `SP500.DWX` - card marks it optional backtest-only, so it is not part of this P2 required registration basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `16` |
| Expected trade frequency | `D1 single-MA state/cross strategy; conservative estimate 8-24 completed trades/year/symbol.` |
| Typical hold time | Multi-day trend hold until a completed D1 close crosses the opposite side of the moving average. |
| Regime preference | Trend-following, moving-average, threshold-entry, signal-reversal-exit, ATR-hard-stop, long-short. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** public GitHub repository
**Pointer:** `https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/stocks/single_ma.py`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12367_tmom-single-ma.md`

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
| v1 | 2026-06-11 | Initial build from card | 06ed8397-bd3a-4671-8ede-11903c9620f9 |
