# QM5_11910_larry-williams-18ma-2outside-bars-d1 - Strategy Spec

**EA ID:** QM5_11910
**Slug:** `larry-williams-18ma-2outside-bars-d1`
**Source:** `c2f8e3d5-4a91-5b67-9c48-a3b7d6e4f2c9` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

The EA trades a D1 Larry Williams breakout rule. A long setup forms when the last two closed daily bars both have lows above the 18-day SMA and neither bar is an inside bar; the entry is a breakout above the higher high of those two bars plus one pip. A short setup mirrors the rule below the SMA, with exits by ATR stop, ATR target, close back across the 18-day SMA, or a 30-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ma_period` | 18 | 5-80 | Daily SMA period for trend filtering and MA-cross exit. |
| `strategy_atr_period` | 14 | 5-80 | Daily ATR period for stop and target distance. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-6.0 | ATR multiple for initial stop distance. |
| `strategy_target_atr_mult` | 4.0 | 0.5-10.0 | ATR multiple for fixed take-profit distance. |
| `strategy_order_validity` | 5 | 1-20 | Number of D1 bars that a breakout setup remains valid. |
| `strategy_time_stop_bars` | 30 | 1-80 | Maximum D1 bars to hold a position. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card universe.
- `GBPUSD.DWX` - liquid major FX pair in the card universe.
- `USDJPY.DWX` - liquid major FX pair in the card universe.
- `USDCAD.DWX` - liquid major FX pair in the card universe.
- `USDCHF.DWX` - liquid major FX pair in the card universe.
- `AUDUSD.DWX` - liquid major FX pair in the card universe.
- `NZDUSD.DWX` - liquid major FX pair in the card universe.
- `EURJPY.DWX` - liquid major FX cross in the card universe.
- `GBPJPY.DWX` - liquid major FX cross in the card universe.
- `AUDJPY.DWX` - liquid major FX cross in the card universe.

**Explicitly NOT for:**
- Non-DWX symbols - the farm only backtests registered `.DWX` history symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `15` |
| Typical hold time | Several days to six weeks |
| Expected drawdown profile | Trend-breakout whipsaws during range-bound FX regimes. |
| Regime preference | Daily trend continuation and breakout follow-through. |
| Win rate target (qualitative) | Medium-low with positive reward-to-risk. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c2f8e3d5-4a91-5b67-9c48-a3b7d6e4f2c9`
**Source type:** `seminar manual`
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11910_larry-williams-18ma-2outside-bars-d1.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11910_larry-williams-18ma-2outside-bars-d1.md`

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
| v1 | 2026-07-08 | Initial repair from approved card | f601517d-3f99-4a0d-9aaa-6231778ee113 |
