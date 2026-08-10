# QM5_11504_goodwin-kangaroo-tail-d1 — Strategy Spec

**EA ID:** QM5_11504
**Slug:** `goodwin-kangaroo-tail-d1`
**Source:** `2a126283-6905-5bb7-903a-cccd5f2b533f`
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

The "Kangaroo Tail" is a 3-bar swing pattern read on the last three closed D1 bars.
For a long setup, the middle bar (shift 2) must print the lowest low of the three —
a local minimum "tail." For a short setup, the middle bar must print the highest
high of the three — a local maximum tail. On the new bar, the EA places a stop
pending order at the most-recent completed bar's extreme: a BuyStop at its high
(long) or a SellStop at its low (short), so price must resume in the reversal
direction to trigger a fill. The pending order expires at end-of-day if unfilled.
A continuation-skip filter voids the setup if the signal bar closed more than
`strategy_filter_pct`% beyond the tail bar's close in the adverse direction, and
no new entries are placed when the signal bar is a Friday. Stops sit at the
signal bar's opposite extreme; targets are a fixed `strategy_rr` multiple of the
stop distance. Positions are time-exited after `strategy_max_hold_bars` D1 bars
if neither SL nor TP has closed them first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_rr` | 2.0 | 1.0–3.0 | TP distance as a multiple of the SL distance (card: 2:1). |
| `strategy_filter_pct` | 0.5 | 0–1.0 % | Continuation-skip threshold: void the setup if the signal bar's close moved beyond this % of the tail bar's close in the adverse direction (source: "skip if Bar3 close beyond Bar2 close by >0.5%"). |
| `strategy_sl_cap_pips` | 100 | 1–100 pips | Skip the setup if the structural stop distance exceeds this cap (card P2 cap). |
| `strategy_spread_cap_pips` | 30 | 1–30 pips | Blocks only a genuinely positive modeled spread above the card's cap; zero-spread DWX ticks remain eligible. |
| `strategy_max_hold_bars` | 3 | 1–10 D1 bars | Fallback maximum holding period when SL/TP has not closed the position (card: "max hold 3 D1 bars"). |
| `strategy_block_friday` | true | true / false | Blocks new entries when the signal bar (shift 1) is a Friday (card: "no Friday entry"). |

Framework-level risk, news, Friday-close, seed, stress, and portfolio inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `USDJPY.DWX` — source-specified pair for the Kangaroo Tail 3-bar D1 pattern.
- `EURUSD.DWX` — card-authorized liquid major-FX expansion using the same daily price-action rule.
- `GBPUSD.DWX` — card-authorized liquid major-FX expansion using the same daily price-action rule.

**Explicitly NOT for:**

- Non-FX `.DWX` symbols — the card's 100-pip stop cap and 30-pip spread cap are calibrated to major-FX price scales, not index/metal/energy scales.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (single-consume, default symbol/period) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 25 |
| Trade frequency | approximately 2 entries per month per symbol |
| Typical hold time | up to 3 D1 bars (time-exit fallback), often closed sooner by SL/TP |
| Expected drawdown profile | Reversal entries can whipsaw during strong trend continuation despite the continuation-skip filter; each loss remains bounded by the structural D1 stop. |
| Regime preference | Swing-low / swing-high reversal conditions after a 3-bar exhaustion tail. |
| Win rate target (qualitative) | medium; the 2:1 reward/risk does not require a high hit rate |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2a126283-6905-5bb7-903a-cccd5f2b533f`
**Source type:** self-published strategy guidebook
**Pointer:** local source record `sources/goodwin-beat-the-markets-strategy-guidebook`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11504_goodwin-kangaroo-tail-d1.md`.

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
| v1 | 2026-08-10 | Initial build from card; rebuilt in-place from a 2026-06-18 partial (mq5/ex5 with no SPEC.md/setfiles) to align OnTick wiring with the current framework skeleton (Q08 MAE-sampling first line, 2026-07-02 news-gate-below-management ordering) | `1a64bebe-8c6e-4b5a-9d00-5c58f9f7f931` |
