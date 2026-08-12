# Decision: per-EA DD ceiling 15% -> 25% at norm risk (portfolio-level 10% stays the target)

- Date: 2026-07-15
- Status: accepted
- Owner: OWNER (ratified in chat, 2026-07-15 morning)
- Affected: `framework/scripts/q05_stress_medium.py` (DD_PCT_MAX, imported by Q06),
  `framework/scripts/p2_baseline.py` (Q02_DD_PCT_MAX),
  `framework/scripts/q10_confirmation.py` (DD_PCT_MAX) — **added 2026-07-25, see amendment below**
- Supersedes: the 15% component of the 2026-06-09 conservative recalibration
  (DL-071/072/073). PF floors, trade floors, correlation/robustness gates unchanged.

## Rationale (OWNER)

A single EA's drawdown at normalized risk (RISK_FIXED 1000 on 100k) is not the book's
drawdown. Book construction (Q09 admission + VaR weighting) combines decorrelated
sleeves whose equity curves flatten in sum — the LIVE DXZ book runs 23 sleeves at
book-DD 3.3% while individual sleeves exceed that. Equity investing accepts deep
per-asset DD phases for the same reason. Per-EA ceilings therefore filter too early at
15%: an EA with solid PF and ≤25% norm-risk DD is book-practicable at appropriate
weight. The portfolio target remains **<10% book DD** — enforced at the portfolio
layer (Q09/Q11), not per sleeve. Precedent: the OOS gate was already relaxed
(2/3-positive-periods logic) on the same portfolio-compensation argument.

## Rule

- Q02 baseline, Q05 (gross full-history) and Q06 (HARSH) DD ceiling: **25%** of
  starting equity at RISK_FIXED 1000. PF floor and min-trades unchanged.
- Correlation (8.1), robustness sub-gates, and Q09 portfolio admission stay strict —
  they are what makes the compensation argument valid.
- Book-level: <10% combined DD remains binding at admission/weighting.

## Guard rails / honesty

- This is NOT a general "gates are advisory" reframing. OWNER floated treating gates
  as research scoring; that larger redesign is a separate design task (see chat
  2026-07-15). This decision changes exactly one number, with the portfolio rationale.
- Historical dd_above_ceiling FAILs with dd<=25 are revived by requeue (audit trail:
  the old verdicts stay recorded).

## Amendment 2026-07-25 — Q10 was missed

OWNER raised this in chat 2026-07-25 ("wir hatten die Grenzen zwischenzeitlich aber schon
auf 25% DD erhöht"). Correct: `q10_confirmation.py` still carried `DD_PCT_MAX = 15.0`.

Why it was missed rather than deliberately kept strict: **Q10 had never been executed when
this decision was written.** The first Q10 aggregate on the box is dated 2026-07-20
(`D:/QM/reports/work_items/.../QM5_10123/Q10/XAUUSD_DWX/aggregate.json`), five days after
the ratification. The affected-files list was assembled from the gates that were actually
emitting `dd_above_ceiling` verdicts; Q10 emitted none because it was not running.

Leaving it at 15 made two gates contradict each other on effectively the same measurement —
Q05 is gross full-history, Q10 is the full-history confirmation, same window, same baseline
commission, no stress:

| EA / symbol | Q05 dd | Q05 @25 | Q10 dd | Q10 @15 | Q10 @25 |
|---|---:|---|---:|---|---|
| QM5_13213 / USDJPY | 21.50 | PASS | 22.80 | FAIL | PASS |
| QM5_10706 / GBPUSD | 19.63 | PASS | 19.93 | FAIL | PASS |

Q10 is therefore aligned to 25.0. This applies the existing decision to a gate that was
invisible when it was taken; it does not extend the decision's scope. PF floor (1.0) and the
min-trades floor are unchanged and were already consistent across Q05/Q06/Q10.

Consequence: the two 2026-07-24 Q10 FAILs above are void and were re-run under the correct
ceiling — see `docs/ops/evidence/2026-07-25_q10_first_confirmation_of_the_live_book.md`.
