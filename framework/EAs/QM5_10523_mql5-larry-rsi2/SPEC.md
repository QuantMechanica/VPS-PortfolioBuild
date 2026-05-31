# QM5_10523_mql5-larry-rsi2 - Strategy Spec

**EA ID:** QM5_10523
**Slug:** `mql5-larry-rsi2`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed H1 bars. It opens a long position when the last close is above SMA(200) and RSI(2) closes below 6. It opens a short position when the last close is below SMA(200) and RSI(2) closes above 95. Long positions exit when the last close is above SMA(5); short positions exit when the last close is below SMA(5), with a 10 H1 bar time stop and fixed 30/60 pip SL/TP protection.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 2 | 1-50 | RSI lookback used for Connors-style extreme reversal entries. |
| `strategy_rsi_long_below` | 6.0 | 0-50 | Long entry threshold; RSI must close below this value. |
| `strategy_rsi_short_above` | 95.0 | 50-100 | Short entry threshold; RSI must close above this value. |
| `strategy_fast_sma_period` | 5 | 1-100 | Fast SMA used for mean-reversion exits. |
| `strategy_slow_sma_period` | 200 | 20-400 | Slow SMA used as the trend filter. |
| `strategy_stop_loss_pips` | 30 | 1-500 | Fixed-pip protective stop from the source baseline. |
| `strategy_take_profit_pips` | 60 | 1-1000 | Fixed-pip protective target from the source baseline. |
| `strategy_time_stop_bars` | 10 | 1-200 | Maximum H1 bars to hold a position before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Source page reports best results on EURUSD H1 and DWX has H1 FX data.
- `GBPUSD.DWX` - Liquid major FX pair suitable for the RSI2 FX mean-reversion pattern.
- `USDJPY.DWX` - Liquid major FX pair suitable for the RSI2 FX mean-reversion pattern.
- `XAUUSD.DWX` - DWX metal symbol listed in the approved card's P2 basket.

**Explicitly NOT for:**
- `SP500.DWX` - Not listed in the approved card's R3 basket for this FX/metals baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | `hours; capped at 10 H1 bars` |
| Expected drawdown profile | `Mean-reversion entries with fixed hard protection; losses cluster in persistent trends.` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/19503`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10523_mql5-larry-rsi2.md`

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
| v1 | 2026-05-29 | Initial build from card | 66c58bb5-c1a0-414d-8f82-e14d55245339 |
