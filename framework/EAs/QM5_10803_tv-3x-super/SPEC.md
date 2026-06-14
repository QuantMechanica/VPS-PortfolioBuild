# QM5_10803_tv-3x-super - Strategy Spec

**EA ID:** QM5_10803
**Slug:** tv-3x-super
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA computes three Supertrend states from closed bars using fast, medium, and slow ATR settings. It opens long when the fast Supertrend flips bullish while the medium and slow Supertrends are bullish, and opens short when the fast Supertrend flips bearish while the medium and slow Supertrends are bearish. It exits an open long when the fast Supertrend flips bearish and exits an open short when the fast Supertrend flips bullish. Each entry uses a 2.0 x ATR(14) stop and no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_atr_period` | 7 | 1-200 | ATR length for the trigger Supertrend. |
| `strategy_medium_atr_period` | 10 | 1-200 | ATR length for the first confirming Supertrend. |
| `strategy_slow_atr_period` | 14 | 1-200 | ATR length for the second confirming Supertrend. |
| `strategy_fast_multiplier` | 2.0 | 0.1-20.0 | ATR multiplier for the trigger Supertrend. |
| `strategy_medium_multiplier` | 3.0 | 0.1-20.0 | ATR multiplier for the first confirming Supertrend. |
| `strategy_slow_multiplier` | 4.0 | 0.1-20.0 | ATR multiplier for the second confirming Supertrend. |
| `strategy_stop_atr_period` | 14 | 1-200 | ATR length used for the baseline entry stop. |
| `strategy_stop_atr_mult` | 2.0 | 0.1-20.0 | ATR multiplier used for the baseline entry stop. |
| `strategy_supertrend_warmup_bars` | 160 | 40-500 | Closed-bar history used to seed the Supertrend state. |
| `strategy_trade_window_enabled` | false | true/false | Optional card-permitted trade-window filter. |
| `strategy_trade_start_hour` | 0 | 0-23 | Broker-hour start when the optional trade window is enabled. |
| `strategy_trade_end_hour` | 24 | 0-24 | Broker-hour end when the optional trade window is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with continuous OHLC for Supertrend and ATR.
- `GBPUSD.DWX` - liquid FX major with continuous OHLC for Supertrend and ATR.
- `USDJPY.DWX` - liquid FX major with continuous OHLC for Supertrend and ATR.
- `XAUUSD.DWX` - liquid metal symbol with matrix-verified OHLC; card listed XAUUSD without suffix.
- `GDAXI.DWX` - matrix-valid DAX proxy for the card's `GER40.DWX` basket entry.
- `NDX.DWX` - liquid US index CFD suitable for trend-following tests.
- `WS30.DWX` - liquid US index CFD suitable for trend-following tests.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tick-data guarantee.

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
| Trades / year / symbol | 35 |
| Typical hold time | hours to days |
| Expected drawdown profile | Lower-to-moderate cadence trend-following drawdowns during sideways markets. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/AT5cKZ2M-3x-Supertrend-for-Vietnamese-stock-market-and-vn30f1m/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10803_tv-3x-super.md`

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
| v1 | 2026-06-14 | Initial build from card | da22c5e2-fa30-4723-b4fe-5f2c5c492b1f |
