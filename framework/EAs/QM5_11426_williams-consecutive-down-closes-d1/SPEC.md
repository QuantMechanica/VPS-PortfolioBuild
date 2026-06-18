# QM5_11426_williams-consecutive-down-closes-d1 — Strategy Spec

**EA ID:** QM5_11426
**Slug:** `williams-consecutive-down-closes-d1`
**Source:** `bb9e26af-ebd1-5a26-b1a8-cc4d78835f03` (Larry Williams, Inner Circle Workshop Trading Method)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Larry Williams short-term mean-reversion on the daily chart. The setup STATE is
read deterministically from the last few CLOSED daily bars: two consecutive lower
closes (`Close[1] < Close[2] < Close[3]`) with the upper shadow contracting
(`High[1]-Close[1] < High[2]-Close[2]`, signalling decelerating bearish pressure),
while the medium-term bias stays positive (`Close[1] > Close[31]`, i.e. still above
the close 30 bars ago). When all conditions hold, the entry EVENT is a single
day-only BUYSTOP placed at `Open[0] + (High[1]-Close[1])`: the trade is taken only
if price resumes upward through the prior upper-shadow distance. The stop is the
signal-day low minus one pip (capped at 80 pips) and the target is
`entry + 2 × (High[1]-Close[1])`. A mirror SHORT setup uses two higher closes, a
contracting lower shadow, a negative bias, and a SELLSTOP at `Open[0] - (Close[1]-Low[1])`.
The pending order is cancelled at the end of the current bar if it does not fill
(day-only). Gapless-safe: all references use prior CLOSE/shadow, never a gap or range.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_consec_closes` | 2 | 2-3 | Number of consecutive lower (long) / higher (short) closes required |
| `strategy_trend_lookback` | 30 | 20-50 | Medium-term bias lookback: compare `Close[1]` to `Close[1+lookback]` |
| `strategy_use_shadow_filter` | true | true/false | Require the signal-day shadow to be contracting vs the prior bar |
| `strategy_tp_mult` | 2.0 | 1.5-3.0 | Take-profit distance = mult × signal-day shadow distance |
| `strategy_sl_cap_pips` | 80 | 40-120 | Hard cap on stop distance from entry, in pips |
| `strategy_spread_cap_pips` | 25.0 | 10-40 | Skip entry if spread is wider than this (fail-open on .DWX zero spread) |
| `strategy_enable_short` | true | true/false | Enable the mirror short setup |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean D1 OHLC for shadow/close arithmetic.
- `GBPUSD.DWX` — liquid major with adequate daily range for the shadow trigger.
- `USDJPY.DWX` — major with distinct daily mean-reversion behaviour.
- `AUDUSD.DWX` — commodity major adding regime diversification.
- `USDCAD.DWX` — commodity major adding regime diversification.

**Explicitly NOT for:**
- Index/CFD symbols — the card specifies an FX basket; pip scaling and the
  shadow-distance entry are calibrated for FX, not indices.

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
| Trades / year / symbol | ~20 |
| Typical hold time | 1-5 days |
| Expected drawdown profile | Shallow; mean-reversion with capped per-trade stop (≤80 pips) |
| Regime preference | mean-revert (pullback within positive medium-term bias) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `bb9e26af-ebd1-5a26-b1a8-cc4d78835f03`
**Source type:** book
**Pointer:** Larry Williams, "Inner Circle Workshop Trading Method" (local PDF, see card frontmatter)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11426_williams-consecutive-down-closes-d1.md`

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
| v1 | 2026-06-18 | Initial build from card | pending-stop day-only entry, FX basket |
