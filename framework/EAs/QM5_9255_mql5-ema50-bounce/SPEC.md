# QM5_9255_mql5-ema50-bounce - Strategy Spec

**EA ID:** QM5_9255
**Slug:** mql5-ema50-bounce
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades a closed-bar rejection of EMA(50) on M15. A long setup requires the last closed candle to dip below EMA(50) with its low and close back above EMA(50); a short setup requires the last closed candle to pierce above EMA(50) with its high and close back below EMA(50). Entries are market orders on the next bar, with one framework-managed position per magic number. Exits occur by fixed TP, stop loss, opposite EMA interaction, the 32-bar time stop, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 50 | 1+ | EMA period on close used for trend bias and bounce interaction. |
| `strategy_fixed_sl_points` | 300 | 1+ | Source fixed stop distance in MT5 points. |
| `strategy_fixed_tp_points` | 600 | 1+ | Source fixed take-profit distance in MT5 points. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the stop-loss floor. |
| `strategy_atr_sl_mult` | 1.5 | >0 | Minimum stop distance multiplier applied to ATR(14). |
| `strategy_max_hold_bars` | 32 | 1+ | Failsafe position age in M15 bars before strategy exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed major FX pair with OHLC and EMA support in the DWX matrix.
- `GBPUSD.DWX` - Card-listed major FX pair with OHLC and EMA support in the DWX matrix.
- `GDAXI.DWX` - DWX DAX equivalent for the card's `GER40.DWX`, which is not present in the matrix.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated symbol, but not present in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Up to 32 M15 bars, about 8 hours. |
| Expected drawdown profile | Intraday fixed-risk pullback system; drawdown should cluster during choppy EMA whipsaws. |
| Regime preference | Trend-following pullback / EMA rejection. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** article
**Pointer:** https://www.mql5.com/en/articles/21283
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9255_mql5-ema50-bounce.md`

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
| v1 | 2026-06-25 | Initial build from card | 88450a8c-e838-450f-9c3f-d621d392cdf7 |
