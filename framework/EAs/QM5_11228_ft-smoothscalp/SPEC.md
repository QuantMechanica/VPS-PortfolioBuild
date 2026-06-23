# QM5_11228_ft-smoothscalp - Strategy Spec

**EA ID:** QM5_11228
**Slug:** ft-smoothscalp
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades a long-only M1 scalp reversal. On each closed M1 bar it requires the bar open below EMA(5) of low, ADX above 30, MFI below 30, stochastic K and D below 30, a bullish K-over-D stochastic cross, and CCI(20) below -150. It enters at the next bar's market price with an ATR(14) x 1.0 stop and a 1% ROI target. It closes early when CCI rises above 150 and either the bar open is above EMA(5) of high or stochastic K/D crosses above 70.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 5 | fixed from card | EMA period for low/high entry and exit bands |
| strategy_stoch_k_period | 5 | fixed from card | Fast stochastic K period |
| strategy_stoch_d_period | 3 | fixed from card | Fast stochastic D period |
| strategy_stoch_slowing | 3 | fixed from card | Fast stochastic slowing |
| strategy_adx_period | 14 | fixed platform default | ADX period used for trend-strength filter |
| strategy_mfi_period | 14 | fixed platform default | MFI period using MT5 tick volume |
| strategy_cci_period | 20 | fixed from card | CCI period for entry and exit |
| strategy_atr_period | 14 | fixed by MT5 baseline | ATR period for stop placement |
| strategy_atr_sl_mult | 1.0 | fixed by MT5 baseline | ATR multiple for stop placement |
| strategy_roi_pct | 1.0 | source ROI target | Percent target from entry price |
| strategy_adx_min | 30.0 | 25.0-35.0 | Minimum ADX for entry |
| strategy_mfi_max | 30.0 | 20.0-40.0 | Maximum MFI for entry |
| strategy_stoch_max | 30.0 | 20.0-40.0 | Maximum stochastic K and D for entry |
| strategy_cci_entry_max | -150.0 | -200.0--100.0 | Maximum CCI value for oversold entry |
| strategy_cci_exit_min | 150.0 | 100.0-200.0 | Minimum CCI value for discretionary exit |
| strategy_exit_stoch_level | 70.0 | fixed from card | Overbought stochastic crossing level for exit |
| strategy_warmup_bars | 100 | card minimum | Minimum indicator warmup depth |
| strategy_max_spread_stop_pct | 4.0 | card maximum | Maximum modeled spread as percent of planned stop distance |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card primary FX scalp basket member with DWX M1 tick data.
- GBPUSD.DWX - card primary FX scalp basket member with DWX M1 tick data.
- USDJPY.DWX - card primary FX scalp basket member with DWX M1 tick data.
- XAUUSD.DWX - card metal scalp basket member with DWX M1 tick data.

**Explicitly NOT for:**
- Non-DWX symbols - research and backtest artifacts must retain the `.DWX` suffix.
- Equity-index symbols - not listed in the approved R3 SmoothScalp basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | Minutes to intraday |
| Expected drawdown profile | High scalp-risk profile controlled by ATR stop and one-position-per-magic constraint |
| Regime preference | M1 oversold scalp reversal with ADX trend-strength filter |
| Win rate target (qualitative) | Medium to high, with small ROI target and bounded stop risk |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/SmoothScalp.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11228_ft-smoothscalp.md`

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
| v1 | 2026-06-23 | Initial build from card | a983834c-3253-4f75-85b2-8f32b91f8187 |

