# QM5_10514_mql5-frac-stop - Strategy Spec

**EA ID:** QM5_10514
**Slug:** mql5-frac-stop
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates confirmed H1 fractals only after the two-bar confirmation lag has fully closed. A long setup is valid when the latest confirmed upper fractal is above the previous confirmed upper fractal; it places a Buy Stop just above that fractal, with initial stop at the latest confirmed lower fractal. A short setup is the mirror image: the latest confirmed lower fractal must be below the previous confirmed lower fractal, then the EA places a Sell Stop just below it with stop at the latest confirmed upper fractal. Pending orders expire after a fixed bar lifetime, take-profit is 1.5R, and open positions trail their stop to the latest opposite confirmed fractal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_H1 | M1-MN1 | Timeframe used for confirmed fractal detection. |
| strategy_fractal_lookback_bars | 120 | 6-500 | Maximum closed bars scanned to find the two latest upper and lower fractals. |
| strategy_pending_buffer_points | 2 | 0-100 | Point buffer added beyond the trigger fractal for pending stop placement. |
| strategy_pending_lifetime_bars | 6 | 1-48 | Number of signal-timeframe bars before an unfilled pending stop is cancelled. |
| strategy_atr_period | 14 | 2-100 | ATR period used for the minimum stop-distance floor. |
| strategy_atr_floor_mult | 0.50 | 0.10-5.00 | Minimum SL distance as a multiple of ATR when the opposite fractal is too tight. |
| strategy_tp_rr | 1.50 | 0.25-10.00 | Fixed take-profit multiple of initial risk. |
| strategy_max_spread_points | 0 | 0-10000 | Optional spread filter; 0 disables the strategy-specific spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 primary FX basket member with DWX data available.
- GBPUSD.DWX - Card R3 primary FX basket member with DWX data available.
- USDJPY.DWX - Card R3 primary FX basket member with DWX data available.
- XAUUSD.DWX - Card R3 metals basket member with DWX data available.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid DWX build targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | hours to several days, depending on pending fill and fractal trailing |
| Expected drawdown profile | structural breakout stop risk bounded by opposite-fractal or ATR-floor distance |
| Regime preference | breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** forum / codebase
**Pointer:** Scriptor idea, Vladimir Karputov / barabashkakvn MQL5 code, Fractured Fractals, MQL5 CodeBase, published 2018-04-18, https://www.mql5.com/en/code/20127
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10514_mql5-frac-stop.md`

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
| v1 | 2026-05-28 | Initial build from card | 1f322176-3a09-4dc5-b5bb-e7fd13661f6d |
