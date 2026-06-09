# QM5_10021_rw-fx-abs-mom — Strategy Spec

**EA ID:** QM5_10021
**Slug:** `rw-fx-abs-mom`
**Source:** `dcbac84f-6ecf-5d21-9630-50faa69306ec` (see `strategy-seeds/sources/dcbac84f-6ecf-5d21-9630-50faa69306ec/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each new D1 bar, compute absolute momentum as `Close[1] - Close[1 + formation_period]` (default 80 trading days). If momentum is positive and no long position is open, enter long at market. If momentum is negative and no short position is open, enter short at market. When the momentum sign flips on a new bar, close the existing position and open in the opposite direction on the next new bar after the close is confirmed. A catastrophic stop at 2.5 × ATR(14, D1) protects against adverse gaps; the primary exit is the momentum reversal signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_formation_period` | 80 | 20–200 | D1 bars used for momentum lookback: Close[1] - Close[1+N] |
| `strategy_atr_period` | 14 | 7–30 | ATR period for catastrophic stop loss distance |
| `strategy_atr_sl_mult` | 2.5 | 1.0–5.0 | ATR multiplier applied to stop loss distance |
| `strategy_max_spread_points` | 40 | 0–200 | Maximum spread in points allowed at entry; 0 = disable filter |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary card symbol; deep liquidity, tight spreads, strong trending behaviour
- `GBPUSD.DWX` — Major FX pair; uncorrelated trend regime to EUR
- `USDJPY.DWX` — Major FX pair; carry-driven trends complement pure momentum
- `AUDUSD.DWX` — Commodity-linked major; diversifies the basket with risk-on/off regime exposure

**Explicitly NOT for:**
- Index CFDs — absolute FX momentum captures currency flow, not equity risk premia

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~20 |
| Typical hold time | days to weeks |
| Expected drawdown profile | trend-following; moderate drawdowns during choppy/ranging markets |
| Regime preference | trend |
| Win rate target (qualitative) | low (large winners offset frequent small losses) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Source type:** paper/tutorial
**Pointer:** Robot Wealth, "Zorro Beginner Series - Coding Demonstration", https://media.robotwealth.com/wp-content/uploads/2020/04/21162311/Zorro-Beginner-Series-Coding-Demonstration.pdf
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10021_rw-fx-abs-mom.md`

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
| v1 | 2026-06-10 | Initial build from card | a76d4523-a68d-4c7b-881f-4d153de70a6d |
