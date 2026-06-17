# QM5_11073_adj-ma-cross — Strategy Spec

**EA ID:** QM5_11073
**Slug:** `adj-ma-cross`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (EarnForex "Adjustable MA", https://github.com/EarnForex/Adjustable-MA)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EA trades a fast/slow EMA crossover on the close of each D1 bar (EarnForex
"Adjustable MA"). It goes long when the fast EMA (period 20) crosses above the
slow EMA (period 22) on the last closed bar AND the two EMAs are separated by at
least MinDiff points; it goes short on the mirror condition (fast crosses below
slow, slow minus fast ≥ MinDiff). The primary exit is signal reversal: an
opposite EMA cross closes the open position and the same cross opens the new
side (close-and-reverse). A catastrophic ATR(20) × 3 hard stop bounds each trade
for testing; the source uses no take-profit (exit is by reversal). One position
per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 20 | 2-200 | Fast EMA period (source Period_1, PRICE_CLOSE) |
| `strategy_ema_slow_period` | 22 | 3-300 | Slow EMA period (source Period_2, PRICE_CLOSE) |
| `strategy_min_diff_points` | 3 | 0-100 | Min fast/slow EMA separation to confirm the cross, in points (source MinDiff × _Point) |
| `strategy_atr_period` | 20 | 5-50 | ATR period for the catastrophic hard stop |
| `strategy_atr_mult` | 3.0 | 1.0-6.0 | Catastrophic stop distance = mult × ATR (entry ∓ this) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, deep liquidity, clean trending D1 swings.
- `GBPUSD.DWX` — major FX pair, trends well on D1, suits MA-cross.
- `USDJPY.DWX` — major FX pair; MinDiff/ATR scale correctly via SYMBOL_POINT/ATR on 3-digit quotes.
- `USDCAD.DWX` — major FX pair, commodity-linked USD trend persistence.

**Explicitly NOT for:**
- Index/metal `.DWX` symbols — card targets the FX basket only; cross behaviour
  and MinDiff calibration are tuned for FX point scaling.

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
| Trades / year / symbol | `24` (card: 18-35 range) |
| Typical hold time | `days to weeks` (D1 trend leg, reversal exit) |
| Expected drawdown profile | `chop/whipsaw losses in ranging regimes; catastrophic ATR×3 caps tail` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low` (trend-following: few large winners, many small losers) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `forum` (open-source EA repository + article)
**Pointer:** `https://github.com/EarnForex/Adjustable-MA` (article: https://www.earnforex.com/metatrader-expert-advisors/Adjustable-MA/)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11073_adj-ma-cross.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
