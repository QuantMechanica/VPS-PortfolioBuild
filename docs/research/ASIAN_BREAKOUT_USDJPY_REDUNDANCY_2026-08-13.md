# Asian Breakout (USDJPY, long-only) — Redundancy & Doctrine Verdict

**Date:** 2026-08-13 · **Author:** Claude (Opus) · **Task:** B1 (mailbox-intake triage)
**Verdict:** **REJECT** — same return source as `QM5_13213_balke-gmt3-range-breakout`
(USDJPY post-06:00 session-high breakout), with three *subtractive* filters. Does not
earn a build slot under orthogonality-over-addition. Cannot help the FTMO speed problem.

---

## 0. The source strategy (as described in intake)

Asian Breakout, USDJPY, **long-only**:
- 06:00 broker time, inspect **yesterday's closed D1**: body <= 40% of full range
  (a consolidation / small-body day) → arm.
- Buy level = **high of the last 6 closed H1 bars (00:00–06:00)**.
- Buy **stop** at that level (optional offset); execution on M1/tick.
- SL ~0.2% of price (or fixed pips), risk 1%.
- Move SL to break-even at +0.5% account profit or +1R.
- TP fixed RRR (1:2 or 1:3).
- Delete unfilled pending at 21:00; flat before weekend; news filter.

> The intake video's "vary parameters to avoid prop copy-trade detection" framing is
> **out of scope and disregarded** — that is provider rule-evasion, not method. Judged on
> mechanics only.

---

## 1. What is mechanically DIFFERENT from QM5_13213 — and is it a distinct source?

**QM5_13213 (verified from the .mq5, `Strategy_PopulateEntry` lines 311/315):** builds the
completed **03:00–06:00 GMT+3** H1 range and at 06:00 places **BOTH** a buy stop at the
range high **and** a sell stop at the range low (symmetric straddle). SL = opposite range
side; ATR(14,H1) band filter (0.4×–2.5×); **no fixed TP** — two-bar swing trail after
+1R; evening flat at 18:00. SPEC: `framework/EAs/QM5_13213_balke-gmt3-range-breakout/SPEC.md`.

| Axis | QM5_13213 (Balke) | Asian Breakout (source) | Verdict on the axis |
|---|---|---|---|
| **Entry trigger** | Break of the overnight-session **high** after 06:00 broker | Break of the overnight-session **high** after 06:00 broker | **IDENTICAL** — this is the return source |
| Range window | 03:00–06:00 (3 H1 bars) | 00:00–06:00 (6 H1 bars) | Overlapping tail; 13213's window is a subset. Cosmetic. |
| Direction | **Symmetric** (buy stop + sell stop) | **Long-only** | Real difference, but a *subtraction* — halves the opportunity set, no structural reason USDJPY Asian breakouts only pay long |
| Day precondition | ATR band filter (0.4–2.5×) | **D1 body ≤ 40% of range** (consolidation day) | Genuinely novel *vs 13213*, but a *frequency-thinning filter*, and the concept already exists in the cluster (Goodwin 11582, Singh 11385 gate on prior-D1) |
| Exit mgmt | 2-bar swing trail, no TP, 18:00 flat | Fixed 1:2/1:3 TP + BE move, 21:00 pending expiry | Different management of the *same* entry edge |
| SL | Opposite range side (structural) | ~0.2% / fixed pips | Parameter, not source |

**Conclusion (Q1):** The core return source — "break the overnight/Asian session **high**
on USDJPY shortly after the 06:00 broker roll" — is the **same edge as 13213's buy leg**.
The genuinely-new parts (D1-consolidation precondition, long-only asymmetry, fixed-RRR
exit) are **knobs on a variant, not a new return source**. It is the same edge with a
directional restriction, a day-filter, and a different exit. Same hours, same instrument,
same trigger.

### The cluster is already saturated (registry evidence)

This archetype is one of our most crowded. From `framework/registry/ea_id_registry.csv`:

- **QM5_13213** balke-gmt3-range-breakout (USDJPY) — the direct twin.
- **QM5_11582** goodwin-asian-session-breakout-usdjpy-h1 — **near-identical**: reads prior
  D1, **direction-gates** the session breakout, stop orders, fixed SL, EOD flat. The
  source's "D1 precondition + session-high breakout" is a re-flavoured 11582 (Goodwin gates
  on D1 *direction*; the source gates on D1 *body/range ratio*).
- **QM5_11463** goodwin-j-session-high-breakout-usdjpy.
- **QM5_11385 / 11561 / 11909** Singh "Good Morning Asia" USDJPY-D1 (D1-candle direction).
- **QM5_9936** ff-range-breakout-gmt3-h1 (Balke base), **QM5_1142** usdjpy-time-range-breakout.
- **QM5_20148** usdjpy-pretokyo-straddle, **QM5_20107** asian-range-straddle,
  **QM5_13210** mulham-asian-sweep-london, plus 11373/11762/11849/11874 USDJPY daily-range
  breakouts.

We do not lack USDJPY session-breakout coverage. We have a dozen.

---

## 2. Orthogonality-over-addition — does it earn a build slot?

**No. Straight verdict: it does not.**

The ratified doctrine (`docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md`,
long-term plan `feedback_longterm_plan_ratified_2026-08-03`) is **orthogonality over
addition**: every new build slot must add a return source the book does not already carry.
The current build slate is deliberately populated with *non-overlapping* families —
vol-gated index short, market intraday momentum, gap-fade, GSR spread, carry-unwind,
session-clock FX — precisely to avoid piling onto saturated axes.

Decisive fact from the pipeline (farm_state DB, `work_items` for `QM5_13213`/USDJPY.DWX):

```
Q02 PASS · Q04 PASS_SOFT · Q05 PASS · Q06 PASS · Q07 PASS · Q10 PASS
Q08 FAIL_SOFT · Q09_PORTFOLIO **FAIL_PORTFOLIO** (2026-07-25) · now Q14 OPT_ELIGIBLE
```

13213 **passed the standalone gates and then died at the PORTFOLIO gate (Q09_PORTFOLIO)** —
it was rejected for *redundancy against the existing book*, not for lacking edge. (Note:
the task brief recalled a "Q05 drawdown" death; the DB shows Q05 actually PASSED — the
drawdown was the walkforward *concern* (`BALKE_RANGE_BREAKOUT_WALKFORWARD_2026-07-14.md`,
MaxDD ≈ −$20k OOS on USDJPY, XAU −$40k), but the *pipeline* killer was portfolio redundancy
at Q09.) A more-restrictive long-only clone of an EA that already failed the redundancy
gate would compound exactly the concentration that killed it. This is the textbook case the
doctrine exists to refuse.

**Verdict:** REJECT for a build slot.

---

## 3. Does it help the FTMO speed problem?

**No — it makes the wrong shape, and it is far too slow.**

FTMO blocker = **speed**: 0/19 sleeves reach FUND_SCORE ≥ 1.0, best 0.96 against ~19
required, and speed is sizing-invariant (`project_qm_ftmo_speed_doctrine_2026-07-26`). The
fix needs **density motors** (~150–220 trades/yr, steady small-worst-day medians).

**Realistic frequency estimate for the source, anchored to 13213's measured tape:**
13213 (symmetric, no D1 precondition) took **~187 trades/yr** on USDJPY (795 OOS trades /
~4.25 yr, walkforward doc). The source applies **three** subtractive filters to that base:

1. **Long-only** → ≈ ×0.5 → ~90/yr.
2. **D1 body ≤ 40% of range** (only small-body/consolidation days; ~30–40% of days)
   → ≈ ×0.35 → ~30/yr.
3. Buy stop must actually **fill** (high must break) — trims further.

**Estimate: ~25–45 trades/year.** Even generously ≤ ~50/yr. That is **~4–8× too slow**
for a density motor and ~19× short of the FUND_SCORE speed requirement. Worse, the fixed
1:2/1:3 RRR profile (low base rate, lumpy 2–3R winners) is the *opposite* of the
steady-median, small-worst-day shape FUND_SCORE rewards. **It could never clear the speed
bar.** No flattery: this is a low-frequency directional bet, not a speed sleeve.

---

## 4. Is any part disallowed? Kill-list + Q02 economics

- **Kill list (SMC/ICT/FVG/order block/BOS/ChoCh, Wyckoff, Hurst, ML):** the source uses
  the word *"imbalance day"*, which is ICT/SMC vocabulary — but here it is operationalised
  purely as **D1 body ≤ 40% of the candle's high-low range**, a mechanical candle-geometry
  filter (same class as an NR-day / small-body / doji filter; cf. Singh's 3-pip doji skip,
  `bandy-nr7-inside-day-breakout`). It is **not** an ICT fair-value-gap, not an order block,
  not BOS/ChoCh, no Wyckoff, no Hurst, no ML. **Mechanics clear the kill list.** Flag the
  terminology only: any card must define the precondition as a body/range ratio, never as
  an "imbalance/FVG."
- **Q02 economics floor (≥ 5 trades/yr):** at ~25–45/yr it clears the *floor* comfortably.
  But the operative test is **useful** frequency, not the floor. As a DXZ diversifier
  ~25–45/yr is marginal-but-tolerable (the orthogonal slate carries the GSR spread at
  ~18/yr, carry-unwind ~12/yr). The problem is not the floor — it is that this frequency
  buys us a **redundant** source. Clearing Q02 does not rescue a duplicate.

---

## Final verdict — REJECT

**REJECT. It duplicates `QM5_13213_balke-gmt3-range-breakout` (and the 11582 Goodwin
Asian-session breakout): the USDJPY post-06:00 session-**high** breakout.** The three
distinguishing knobs — long-only, D1-consolidation precondition, fixed-RRR exit — are a
*more restrictive* re-parameterisation of an edge that already **failed the portfolio
redundancy gate (Q09_PORTFOLIO)**. It adds no orthogonal return source, it cannot help the
FTMO speed problem (~25–45 trades/yr, wrong PnL shape), and it lands in our single most
saturated archetype.

**Not even BUILD-AS-VARIANT of 13213 as a new EA_ID / new build slot.** If OWNER wants to
learn whether the **D1-consolidation gate** and **long-only asymmetry** rescue the drawdown
tail that sank 13213, that is precisely a **challenger parameterisation of the existing
13213 inside the Q14→Q16 optimization track (DL-084)** — where 13213 already sits as
`OPT_ELIGIBLE` — not a new mechanisation. Recommended action: **decline the build; log the
D1-gate + long-only idea as an optional 13213 challenger variant for the optimization
track, no new slot.**

---

## Evidence index

- `framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5`
  — lines 311/315: symmetric buy-stop + sell-stop (proves 13213 is *not* long-only).
- `framework/EAs/QM5_13213_balke-gmt3-range-breakout/SPEC.md` — 03:00–06:00 window, ATR
  band, 2-bar trail, 18:00 flat.
- `docs/research/BALKE_RANGE_BREAKOUT_WALKFORWARD_2026-07-14.md` — ~187 trades/yr, PF 1.20
  OOS, MaxDD ≈ −$20k (USDJPY) / −$40k (XAU).
- `framework/EAs/QM5_11582_goodwin-asian-session-breakout-usdjpy-h1/SPEC.md` — near-twin:
  prior-D1 gate + session breakout, stop orders, EOD flat.
- `framework/EAs/QM5_11385_mario-singh-good-morning-asia-usdjpy-d1/SPEC.md` — D1 body/doji
  filter precedent (small-body geometry, not FVG).
- `framework/registry/ea_id_registry.csv` — the USDJPY/Asian-session breakout cluster
  (13213, 11582, 11463, 11385/11561/11909, 9936, 1142, 20148, 20107, 13210, 11373/11762/11849/11874).
- farm_state DB (read-only) `work_items` QM5_13213/USDJPY.DWX — Q05 PASS, **Q09_PORTFOLIO
  FAIL_PORTFOLIO**, now Q14 OPT_ELIGIBLE.
- `docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md` — orthogonality-over-addition slate.
