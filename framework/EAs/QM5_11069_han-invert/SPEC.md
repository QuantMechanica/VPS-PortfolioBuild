# QM5_11069_han-invert — Strategy Spec

**EA ID:** QM5_11069
**Slug:** `han-invert`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex "Heiken Ashi Naive", https://github.com/EarnForex/Heiken-Ashi-Naive)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Trades the inverted EarnForex "Heiken Ashi Naive" rule on completed D1 bars.
Heiken Ashi candles are reconstructed deterministically from raw OHLC over a
bounded 60-bar closed-bar window, recomputed once per new D1 bar. A short fires
when the last completed HA candle (shift 1) is bullish with no lower wick, its
body is longer than the prior HA body, and the HA candle before it (shift 2) is
also bullish — because the strategy runs in inverted mode, this bullish
continuation signal opens a SHORT. Symmetrically, a bearish HA candle with no
upper wick, a longer body, and a preceding bearish HA candle opens a LONG. The
position is closed on the inverted close signal: a long exits when HA[1] and
HA[2] are both bullish and HA[1] has no lower wick; a short exits when both are
bearish and HA[1] has no upper wick. A catastrophic ATR(20)×3 hard stop bounds
risk (the source places no hard SL); there is no fixed take-profit — the HA
close signal manages the exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ha_window` | 60 | 20-250 | Bounded closed-bar window for deterministic HA reconstruction |
| `strategy_wick_tol_pct` | 0.0001 | 0.0-0.01 | "No wick" equality tolerance as % of price (HALow==HAOpen) |
| `strategy_atr_period` | 20 | 5-50 | ATR period for the catastrophic hard stop |
| `strategy_atr_sl_mult` | 3.0 | 1.0-6.0 | Catastrophic stop distance = mult × ATR |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — source's original D1 test market; primary basket leg
- `GBPUSD.DWX` — liquid major, same D1 HA continuation behaviour
- `USDJPY.DWX` — liquid major; pip-scaling handled by framework stop helpers
- `USDCAD.DWX` — liquid major, completes the card's R3 four-pair basket

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card specifies D1 FX majors only; HA naive
  inversion was validated on EUR/USD, not on gapless index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~30` |
| Typical hold time | `several days (D1 swing)` |
| Expected drawdown profile | `moderate; bounded by ATR(20)×3 catastrophic stop` |
| Regime preference | `mean-revert (inverted continuation signal)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum` (EarnForex GitHub repository + article)
**Pointer:** https://github.com/EarnForex/Heiken-Ashi-Naive
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11069_han-invert.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | board-advisor worktree |
