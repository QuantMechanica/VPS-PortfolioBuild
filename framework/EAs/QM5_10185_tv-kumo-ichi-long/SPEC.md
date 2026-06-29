# QM5_10185_tv-kumo-ichi-long - Strategy Spec

**EA ID:** QM5_10185
**Slug:** `tv-kumo-ichi-long`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10185_tv-kumo-ichi-long.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-29

---

## 1. Strategy Logic

The EA is a long-only H1 Ichimoku pullback strategy. It computes Tenkan-sen, Kijun-sen, Senkou Span A, and Senkou Span B from closed H1 bars, requires price above the Kumo cloud, a green cloud, a recent pullback memory condition, and a D1 EMA bullish bias. Entry triggers when Tenkan crosses above Kijun or price reclaims Kijun after a pullback, with tick volume above its 20-bar average. Exits use the card's defensive close below the cloud plus a trailing stop based on the highest high over 5 bars minus 3 ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 only | Base signal timeframe from the card. |
| `strategy_bias_tf` | `PERIOD_D1` | D1 only | Higher-timeframe EMA bias timeframe. |
| `strategy_tenkan_period` | 9 | 2-50 | Ichimoku Tenkan lookback. |
| `strategy_kijun_period` | 26 | 5-100 | Ichimoku Kijun lookback. |
| `strategy_senkou_b_period` | 52 | 10-150 | Ichimoku Senkou Span B lookback. |
| `strategy_displacement` | 26 | 0-100 | Cloud displacement used for current-bar cloud comparison. |
| `strategy_setup_lookback` | 21 | 1-100 | Bars allowed for the Kijun/cloud pullback memory condition. |
| `strategy_daily_ema` | 200 | 20-400 | D1 EMA used for bullish bias. |
| `strategy_volume_sma` | 20 | 0-100 | Tick-volume SMA filter length; 0 disables the filter. |
| `strategy_trail_lookback` | 5 | 1-50 | Highest-high lookback for trailing stop. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop distance. |
| `strategy_trail_atr_mult` | 3.0 | 0.5-10.0 | ATR multiple subtracted from the trailing highest high. |
| `strategy_initial_atr_cap` | 2.5 | 0.5-10.0 | Maximum initial stop distance in ATR multiples. |

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` - liquid JPY cross with trend/pullback behaviour suitable for Ichimoku H1 logic.
- `GBPJPY.DWX` - higher-volatility JPY cross that broadens the FX sleeve beyond USD majors.
- `XAUUSD.DWX` - liquid metal CFD with persistent trend regimes.
- `NDX.DWX` - live-tradable US equity-index proxy for trend-following validation.
- `GDAXI.DWX` - available DAX custom symbol replacing the card's unavailable `GER40.DWX` label.

**Explicitly NOT for:**
- `GER40.DWX` - not present in the DWX symbol matrix; use `GDAXI.DWX`.
- `SP500.DWX` - not registered for this EA and backtest-only at the T6 gate.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` EMA bias |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_signal_tf)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 45 |
| Typical hold time | hours to several days |
| Expected drawdown profile | trend-following pullback losses cluster during sideways regimes |
| Regime preference | bullish trend / pullback continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView strategy script
**Pointer:** `https://www.tradingview.com/script/y3wPei2t-KumoTrade-Ichimoku-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10185_tv-kumo-ichi-long.md`

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
| v1 | 2026-06-29 | Initial build from card | `0a8ba6d1-862d-4670-88e5-417ecd9d3b86` |
