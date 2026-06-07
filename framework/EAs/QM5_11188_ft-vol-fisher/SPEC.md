# QM5_11188_ft-vol-fisher - Strategy Spec

**EA ID:** QM5_11188
**Slug:** ft-vol-fisher
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long only on M5 closed bars after a large tick-volume spike. A long entry is allowed when the latest closed bar volume is greater than the 150-bar rolling mean times 4, close is below SMA(40), stochastic fast %D is above fast %K and above 1, RSI(14) is above 26, and normalized inverse Fisher RSI is below 5. The stop is ATR(14) times 2.0 below the market entry. The EA exits when RSI crosses above 74 while MACD(12,26,9) is below zero and MinusDI(14) is above 4, or when the ROI ladder is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_timeframe | PERIOD_M5 | PERIOD_M5 baseline | Closed-bar signal timeframe from the card. |
| strategy_volume_window | 150 | 20-300 | Rolling tick-volume mean window. |
| strategy_volume_mult | 4.0 | 1.0-8.0 | Minimum volume spike multiple. |
| strategy_sma_period | 40 | 10-100 | SMA period for the close-below-SMA filter. |
| strategy_rsi_period | 14 | 5-30 | RSI period used by entry, Fisher transform, and exit. |
| strategy_rsi_entry_min | 26.0 | 0-100 | Entry requires RSI above this level. |
| strategy_stoch_d_min | 1.0 | 0-100 | Entry requires stochastic %D above this level. |
| strategy_fisher_norm_max | 5.0 | 0-100 | Entry requires normalized inverse Fisher RSI below this level. |
| strategy_macd_fast | 12 | 2-50 | MACD fast EMA period for exit. |
| strategy_macd_slow | 26 | 5-100 | MACD slow EMA period for exit. |
| strategy_macd_signal | 9 | 2-50 | MACD signal period. |
| strategy_di_period | 14 | 5-50 | DMI period for MinusDI exit condition. |
| strategy_exit_rsi | 74.0 | 0-100 | Exit trigger RSI cross level. |
| strategy_exit_minusdi_min | 4.0 | 0-100 | Minimum MinusDI for baseline exit branch. |
| strategy_atr_period | 14 | 5-50 | ATR period for stop placement. |
| strategy_atr_sl_mult | 2.0 | 0.5-5.0 | ATR stop multiplier. |
| strategy_spread_stop_fraction | 0.08 | 0.01-0.25 | Blocks entries when spread exceeds this fraction of planned stop distance. |
| strategy_roi_0_pct | 5.0 | 0.1-20.0 | ROI exit threshold from entry through 19 minutes. |
| strategy_roi_20_pct | 4.0 | 0.1-20.0 | ROI exit threshold from 20 minutes. |
| strategy_roi_40_pct | 3.0 | 0.1-20.0 | ROI exit threshold from 40 minutes. |
| strategy_roi_80_pct | 2.0 | 0.1-20.0 | ROI exit threshold from 80 minutes. |
| strategy_roi_1440_pct | 1.0 | 0.1-20.0 | ROI exit threshold from 1440 minutes. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair from the card's R3 P2 basket; tick volume supports the volume-spike proxy.
- GBPUSD.DWX - liquid major FX pair from the card's R3 P2 basket; tick volume supports the volume-spike proxy.
- USDJPY.DWX - liquid major FX pair from the card's R3 P2 basket; tick volume supports the volume-spike proxy.
- XAUUSD.DWX - liquid metal symbol from the card's R3 P2 basket; tick volume supports the volume-spike proxy.

**Explicitly NOT for:**
- Crypto symbols - source strategy was crypto, but the card ports the implementation to DWX FX/metals only.
- Indices outside the card R3 basket - not part of the approved portable universe for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 400 |
| Typical hold time | Minutes to one day, based on the 0/20/40/80/1440 minute ROI ladder. |
| Expected drawdown profile | Mean-reversion drawdowns during persistent trend or low-volume regimes. |
| Regime preference | Volume-spike mean reversion with oscillator exhaustion. |
| Win rate target (qualitative) | medium |

Expected trade frequency: README reports 180 buys over 2018-01-10 to 2018-01-30 on crypto backtest data; this is high-cadence on M5 but FX session, spread, and news filters should reduce it materially. Conservative estimate 300-600 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy005.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11188_ft-vol-fisher.md`

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
| v1 | 2026-06-07 | Initial build from card | 4cc03330-2697-4cb1-aaa0-6c960c32e764 |
