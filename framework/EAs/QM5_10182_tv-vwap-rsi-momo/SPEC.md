# QM5_10182 tv-vwap-rsi-momo - Strategy Spec

**EA ID:** QM5_10182
**Slug:** tv-vwap-rsi-momo
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (`sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA mechanizes the approved TradingView VWAP-RSI momentum card as a trend-filtered momentum system on H1 bars by default. It builds a rolling 20-bar VWAP from typical price and tick volume, computes an RSI(14) on that VWAP series, smooths the RSI with EMA(3), and trades only in the direction of the SMA(50) versus SMA(100) trend filter.

Long entries require the long trend filter plus one of three VWAP-RSI triggers: reversal upward from below 35, cross above 50, or a shallow dip reentry after a prior 75-zone reading. Shorts mirror the same structure from above 65, below 50, or after a prior 25-zone reading. Exits are VWAP-RSI exhaustion turns or a 64-bar time stop; the initial stop is the tighter of a 4.0% price stop and 2.0 ATR(14).

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | M30-H1 baseline | Signal timeframe used for VWAP-RSI, SMA trend, ATR stop, and time stop. |
| `strategy_vwap_period` | 20 | 2-100 | Rolling VWAP lookback in bars. |
| `strategy_rsi_period` | 14 | 2-50 | RSI lookback applied to rolling VWAP values. |
| `strategy_rsi_ema_period` | 3 | 1-20 | EMA smoothing period for the VWAP-RSI. |
| `strategy_sma_fast_period` | 50 | 2-200 | Fast trend SMA period. |
| `strategy_sma_slow_period` | 100 | 3-300 | Slow trend SMA period. |
| `strategy_trigger_lookback` | 20 | 3-100 | Lookback window for shallow dip/reentry trigger state. |
| `strategy_atr_period` | 14 | 2-50 | ATR period used for the stop cap. |
| `strategy_atr_stop_mult` | 2.0 | 0.5-6.0 | ATR multiple for the maximum stop distance. |
| `strategy_percent_stop` | 4.0 | 0.5-10.0 | Static percent stop from source logic. |
| `strategy_max_spread_stop_fraction` | 0.15 | 0.0-0.5 | Blocks entry when spread exceeds this fraction of stop distance. |
| `strategy_time_stop_bars` | 64 | 1-300 | Maximum hold time in signal bars. |

## 3. Symbol Universe

Designed for:

- `NDX.DWX` - liquid index proxy for the source strategy's risk-on momentum target.
- `WS30.DWX` - second live-routable US index proxy to diversify index response.
- `GDAXI.DWX` - available DWX DAX proxy for the card's GER40-style index port.
- `XAUUSD.DWX` - liquid metal proxy included by the approved card's DWX port plan.
- `EURUSD.DWX` - major FX proxy included by the approved card's DWX port plan.

Explicitly NOT for:

- `GER40.DWX` - not present in the DWX symbol matrix; `GDAXI.DWX` is the registered replacement.
- Crypto symbols - the source originated in crypto, but no crypto `.DWX` symbol is available in the current matrix.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` in framework `OnTick` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 120 |
| Typical hold time | hours to several days, capped at 64 H1 bars by default |
| Expected drawdown profile | momentum pullback strategy with bounded fixed-risk stops |
| Regime preference | trending or momentum-continuation regimes |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/G9OpWCtf-Tideflow-VWAP-RSI-Momentum-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10182_tv-vwap-rsi-momo.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Added missing Q01 spec for Q02 recovery | task 4197afc3-6252-4200-8f75-7e747432f903 |
