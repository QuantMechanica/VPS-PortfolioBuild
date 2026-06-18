# QM5_11431_lien-xtreme-fade-bb-adx-m15 — Strategy Spec

**EA ID:** QM5_11431
**Slug:** `lien-xtreme-fade-bb-adx-m15`
**Source:** `df524d6c-e7a3-5ab9-a4f5-212ac0f1134b` (see `strategy-seeds/sources/df524d6c-e7a3-5ab9-a4f5-212ac0f1134b/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A mean-reversion fade that only trades inside a non-trending range. Two Bollinger
Bands share the same 20-period SMA: an outer "extreme" band at 3 sigma and an
inner "standard" band at 2 sigma. The setup is a two-bar sequence on the freshly
closed M15 bars. SHORT: the close two bars ago printed above the 3-sigma upper
band (a statistically extreme move), the most recent closed bar came back below
the 2-sigma upper band (reversion has begun), and ADX(14) on that bar is below 25
(the market is not trending). The EA then sells at market. LONG is the mirror:
close two bars ago below the 3-sigma lower band, last closed bar back above the
2-sigma lower band, ADX(14) below 25, buy at market. The stop is placed one pip
beyond the 3-sigma band of the most recent closed bar (capped at 25 pips of
distance) and the take-profit is two times that stop distance. There is no
time-based or discretionary exit — the position is held until the stop or target
is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 15-25 | Bollinger SMA period shared by both bands |
| `strategy_bb_outer_stddev` | 3.0 | 2.5-3.5 | Outer "extreme" band deviation (sigma) |
| `strategy_bb_inner_stddev` | 2.0 | 1.5-2.5 | Inner "standard" band deviation (sigma) |
| `strategy_adx_period` | 14 | 7-21 | ADX period for the range filter |
| `strategy_adx_max` | 25.0 | 20-30 | Trade only while ADX is below this (non-trending) |
| `strategy_sl_buffer_pips` | 1.0 | 0-5 | Stop placed this many pips beyond the outer band |
| `strategy_sl_cap_pips` | 25.0 | 10-40 | Hard cap on stop distance (card P2 cap) |
| `strategy_rr_target` | 2.0 | 1.5-2.5 | Take-profit at this multiple of stop distance |
| `strategy_spread_cap_pips` | 12.0 | 5-20 | Block only if spread exceeds this (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; ranges cleanly, well-suited to BB mean reversion.
- `GBPUSD.DWX` — liquid major with frequent intraday range behaviour on M15.
- `USDJPY.DWX` — liquid major; the pip-scaled SL/TP and SL cap handle its 3-digit quoting.
- `AUDUSD.DWX` — liquid commodity-linked major that spends much time range-bound.
- `USDCAD.DWX` — liquid major; oil-driven ranges fit the low-ADX fade premise.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols (NDX, WS30, XAUUSD, etc.) — the card is a FX
  major mean-reversion strategy; the 3-sigma extreme statistics and ADX range
  filter were calibrated on FX, not on trendier index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~80` |
| Typical hold time | `hours (intraday M15; held to 2R TP or SL)` |
| Expected drawdown profile | `clustered losers when a range breaks into a trend; ADX<25 filter limits this` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `df524d6c-e7a3-5ab9-a4f5-212ac0f1134b`
**Source type:** `book`
**Pointer:** `Kathy Lien & Boris Schlossberg, "Battle-Tested Forex Strategies" (local PDF in strategy archive)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11431_lien-xtreme-fade-bb-adx-m15.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
