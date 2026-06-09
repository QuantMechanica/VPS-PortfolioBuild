# QM5_10043_ff-50macd-4h - Strategy Spec

**EA ID:** QM5_10043
**Slug:** `ff-50macd-4h`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA checks the H4 MACD main line at the source decision hours 08:00, 12:00, 16:00, and 20:00 GMT/BST. It goes long when `MACD_main[1] - MACD_main[3] >= 50 points` and goes short when the same delta is `<= -50 points`. Each entry uses a fixed 30 pip stop and 45 pip target, moves the stop to breakeven after +30 pips, and closes early if the opposite MACD threshold appears before TP or SL.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 intended | Timeframe used for MACD, ATR, and prior-bar range checks. |
| `strategy_macd_fast` | `5` | 1-200 | Fast EMA period for MACD. |
| `strategy_macd_slow` | `13` | 2-300 | Slow EMA period for MACD; must be greater than fast. |
| `strategy_macd_signal` | `1` | 1-100 | MACD signal period from the source. |
| `strategy_macd_delta_points` | `50` | 1-1000 | Minimum MACD main-line change in symbol points. |
| `strategy_sl_pips` | `30` | 1-500 | Fixed stop-loss distance in pips. |
| `strategy_tp_pips` | `45` | 1-1000 | Fixed take-profit distance in pips. |
| `strategy_breakeven_trigger_pips` | `30` | 1-500 | Profit in pips required before moving SL to breakeven. |
| `strategy_breakeven_buffer_pips` | `0` | 0-100 | Pip buffer added to the breakeven stop. |
| `strategy_atr_period` | `14` | 1-200 | ATR period for the flat-bar filter. |
| `strategy_min_range_atr_mult` | `0.25` | 0.0-5.0 | Minimum prior H4 range as a multiple of ATR. |
| `strategy_max_spread_stop_fraction` | `0.15` | 0.0-1.0 | Maximum spread as a fraction of the fixed stop distance. |
| `strategy_decision_hour_1` | `8` | 0-23 | First source decision hour. |
| `strategy_decision_hour_2` | `12` | 0-23 | Second source decision hour. |
| `strategy_decision_hour_3` | `16` | 0-23 | Third source decision hour. |
| `strategy_decision_hour_4` | `20` | 0-23 | Fourth source decision hour. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - Source pair and primary R3 FX target.
- `EURUSD.DWX` - Major liquid FX pair in the card's R3 basket.
- `USDJPY.DWX` - Major liquid FX pair in the card's R3 basket.
- `EURJPY.DWX` - Major liquid FX cross in the card's R3 basket.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - The card defines pip-based FX exits and an H4 FX MACD trigger.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `44` |
| Expected trade frequency | H4 MACD-delta threshold checked four times per active trading day; conservative filtered estimate 30-60 trades/year/symbol. |
| Typical hold time | Intraday to a few H4 bars, bounded by 30 pip SL, 45 pip TP, breakeven, and Friday close. |
| Expected drawdown profile | Fixed-risk momentum strategy with losses bounded by the card's 30 pip stop. |
| Regime preference | Momentum breakout / volatility expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/33362-50-macd-4hour
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10043_ff-50macd-4h.md`

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
| v1 | 2026-06-09 | Initial build from card | 7cc176b8-3a25-44f4-8b79-b196a5d27e59 |
