# QM5_10002_ff-sisyphus-2ma-rsi-d1 - Strategy Spec

**EA ID:** QM5_10002
**Slug:** `ff-sisyphus-2ma-rsi-d1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades a daily trend-pullback reversal on liquid USD majors. On each
closed D1 bar it compares price with EMA(200) for trend, EMA(5) for short-term
pullback, and RSI(2) for exhaustion.

A long entry is opened when the previous close is above EMA(200), below EMA(5),
and RSI(2) is below 5. A short entry is opened when the previous close is below
EMA(200), above EMA(5), and RSI(2) is above 95. Positions exit when the next
closed candle touches the EMA(5) side specified by the source, or after a
15-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 5 | 3-10 | Pullback and signal-exit EMA period |
| `strategy_trend_ema_period` | 200 | 100-250 | Primary D1 trend filter period |
| `strategy_rsi_period` | 2 | 2-5 | Short-horizon RSI exhaustion period |
| `strategy_rsi_long_threshold` | 5.0 | 2.0-10.0 | Maximum RSI value for long pullback entries |
| `strategy_rsi_short_threshold` | 95.0 | 90.0-98.0 | Minimum RSI value for short pullback entries |
| `strategy_atr_period` | 14 | 10-20 | ATR period for protective stop and range filter |
| `strategy_atr_sl_mult` | 2.5 | 1.5-3.5 | Protective stop distance in ATR units |
| `strategy_atr_percentile_bars` | 252 | 120-300 | D1 ATR sample window for the high-volatility skip |
| `strategy_atr_percentile_limit` | 90.0 | 80.0-95.0 | ATR percentile above which new entries are skipped |
| `strategy_time_stop_bars` | 15 | 5-25 | Maximum holding period in D1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source-relevant USD major with deep D1 history.
- `GBPUSD.DWX` - source-relevant USD major with deep D1 history.
- `AUDUSD.DWX` - source-relevant USD major with deep D1 history.
- `USDJPY.DWX` - source-relevant USD major with deep D1 history.
- `USDCAD.DWX` - source-relevant USD major with deep D1 history.
- `USDCHF.DWX` - source-relevant USD major with deep D1 history.

**Explicitly NOT for:**
- `SP500.DWX` - the card is a ForexFactory USD-major FX pullback strategy.
- `XAUUSD.DWX` - gold is outside the source's FX-major basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | 1-15 D1 bars |
| Expected drawdown profile | Mean-reversion pullbacks can cluster losses in persistent trends |
| Regime preference | Trend-filtered mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** Sis.yphus, "A Proven Simple Strategy (2MAs, 1 RSI)", ForexFactory, 2016, https://www.forexfactory.com/thread/574065-a-proven-simple-strategy-2mas-1-rsi
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10002_ff-sisyphus-2ma-rsi-d1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-26 | Initial spec backfill for existing approved build | task 041de22a |
