# QM5_9995_tv-halftrend-channel-reversal - Strategy Spec

**EA ID:** QM5_9995
**Slug:** tv-halftrend-channel-reversal
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the TradingView HalfTrend channel reversal on closed H1 bars. It keeps a two-state trend machine initialized to downtrend, tracks the lowest high during down legs and highest low during up legs, and flips when the N-bar high/low SMA and an ATR-derived hysteresis threshold confirm the reversal. A flip to up opens long; a flip to down opens short. An opposite flip closes the existing position and opens the new direction, with ATR(14)-based initial stop and optional ATR take-profit/time stop inputs defaulted off.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_amplitude` | 2 | 1+ | HalfTrend N-bar high/low and SMA lookback. |
| `strategy_halftrend_atr_period` | 100 | 1+ | ATR period used for the HalfTrend hysteresis threshold. |
| `strategy_channel_dev` | 2.0 | 0+ | Multiplier in `channel_dev * ATR(period) / 2 / 100`. |
| `strategy_sl_atr_period` | 14 | 1+ | ATR period used for initial stop placement. |
| `strategy_sl_atr_mult` | 1.5 | >0 | Initial stop distance in ATR multiples. |
| `strategy_tp_atr_mult` | 0.0 | 0+ | Optional ATR take-profit multiple; 0 disables TP. |
| `strategy_regime_filter_enabled` | false | true/false | Optional ATR regime filter from the card's P3 sweep. |
| `strategy_regime_lag_bars` | 20 | 1+ | ATR lag bars for the optional regime filter. |
| `strategy_time_stop_bars` | 0 | 0+ | Optional max H1 holding bars; 0 disables time stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-targeted liquid FX major for instrument-agnostic HalfTrend reversal.
- `GBPUSD.DWX` - card-targeted liquid FX major for H1 channel reversal.
- `USDJPY.DWX` - card-targeted liquid FX major for H1 channel reversal.
- `XAUUSD.DWX` - card-targeted gold CFD with native DWX history.
- `XTIUSD.DWX` - card-targeted oil CFD with native DWX history.
- `NDX.DWX` - card-targeted Nasdaq 100 index CFD with DWX history.
- `WS30.DWX` - card-targeted Dow 30 index CFD with DWX history.
- `SP500.DWX` - supplementary S&P 500 custom symbol for backtest-only validation.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable or non-canonical S&P 500 variants; `SP500.DWX` is the available custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | roughly 3-4 trading days between HalfTrend flips; optional 72 H1 bar cap is available but off by default |
| Expected drawdown profile | bounded by the ATR(14) initial stop on each trade |
| Regime preference | channel-reversal and trend-flip behavior in non-dead volatility regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView popular Pine script
**Pointer:** https://www.tradingview.com/script/U1SJ8ubc-HalfTrend/ and `artifacts/cards_approved/QM5_9995_tv-halftrend-channel-reversal.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9995_tv-halftrend-channel-reversal.md`

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
| v1 | 2026-06-25 | Initial build from card | 1c4fb433-149e-427e-813d-ade456465756 |
