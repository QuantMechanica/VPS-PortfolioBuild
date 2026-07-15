# Decision: per-EA DD ceiling 15% -> 25% at norm risk (portfolio-level 10% stays the target)

- Date: 2026-07-15
- Status: accepted
- Owner: OWNER (ratified in chat, 2026-07-15 morning)
- Affected: `framework/scripts/q05_stress_medium.py` (DD_PCT_MAX, imported by Q06),
  `framework/scripts/p2_baseline.py` (Q02_DD_PCT_MAX)
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
