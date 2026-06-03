# QM5_10569_mql5-supertrend_v2 - Strategy Spec

**EA ID:** QM5_10569
**Slug:** mql5-supertrend
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes a SuperTrend line from ATR and median price on the closed H4 bars. It enters long when the latest closed bar flips from bearish to bullish SuperTrend direction, and enters short when it flips from bullish to bearish. It keeps one active position per symbol and magic, closes on the opposite closed-bar SuperTrend flip, and otherwise relies on the framework stop, target, Friday close, news, and kill-switch exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H1-H6 tested downstream | Timeframe used for SuperTrend signal calculation. |
| `strategy_atr_period` | `14` | 5-50 | ATR lookback used inside SuperTrend and hard-stop sizing. |
| `strategy_st_mult` | `3.0` | 1.0-6.0 | ATR multiplier for the SuperTrend reversal bands. |
| `strategy_atr_sl_mult` | `2.0` | 0.5-6.0 | ATR multiple used for the initial hard stop. |
| `strategy_rr_target` | `1.5` | 0.5-5.0 | Reward-to-risk multiple used for the initial target. |
| `strategy_warmup_bars` | `160` | 50-500 | Closed bars used to initialise the SuperTrend state. |

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` - source test used EURJPY H4 and the card names it in the primary P2 basket.
- `EURUSD.DWX` - liquid major FX pair suitable for ATR-band trend reversal.
- `GBPUSD.DWX` - liquid major FX pair suitable for ATR-band trend reversal.
- `XAUUSD.DWX` - liquid metal CFD named in the primary P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not broker-testable in the DWX custom-symbol universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; exits are checked on `QM_IsNewBar(_Symbol, strategy_signal_tf)` when a position is open |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | Several H4 bars to multiple days, depending on SuperTrend reversal spacing |
| Expected drawdown profile | Trend-following reversal profile with whipsaws in sideways markets |
| Regime preference | trend-reversal / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase 15239
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10569_mql5-supertrend_v2.md`

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
| v1 | 2026-05-29 | Initial build from card | a2cfef80-7713-4a27-ab14-fcb0933e5302 |

