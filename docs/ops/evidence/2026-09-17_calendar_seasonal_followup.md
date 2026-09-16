# Calendar/seasonal thesis-bank follow-up — Codex review

Task: `bc07fa0a-307f-49dc-8294-b67bbd3e0f39`  
Scope: documentation only; no card promotion, build, pipeline, or state change.

## Verification

- The source CSV contains 39 rows for 15 thesis IDs: 8 raw `PAPER_REFUTED`, 2
  raw `UNDERPOWERED`, 2 `PAPER_SURVIVES`, and 3 missing-export rows.
- The thesis-bank disposition rule is explicit: raw `n < 20` remains
  `UNDERPOWERED` in the CSV; CAL-05 is folded into the bank’s refuted tally
  because its preregistered IS sign is wrong (`-25.03 bp`), while CAL-06 stays
  an `UNDERPOWERED RESERVE` because its IS sign agrees (`+108.51 bp`) and it
  still requires 20 independent years. No thin sample is a survivor.
- The bank tally is therefore `PAPER_SURVIVES=2`, `UNDERPOWERED RESERVE=1`,
  `PAPER_REFUTED=9`, `DATA GAP=3`; the underlying CSV and falsification script
  were not changed.
- CAL-05, CAL-06, CAL-09, and CAL-12 each carry an explicit thesis-specific
  `UNSOURCED` marker. The general source list is not presented as evidence for
  those exact mechanisms.
- The CAL-06 review draft records the approximately 1 trade/year/symbol
  frequency ceiling, below the Q02 floor of 5 trades/year, and lists bounded
  widening options requiring preregistration and OWNER review.

## Files

- `docs/research/EDGE_THESES_CALENDAR_SEASONAL_2026-09-12.md`
- `docs/research/edge_lab/calendar_seasonal_falsification.csv`
- `D:/QM/strategy_farm/artifacts/cards_review/PENDING_EDGECAL06_xau-august-week.md`
- `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`

RESULT: `PASS` — citations/unsourced markers, disposition rule, tally, and
CAL-06 frequency ceiling are documented; no promotion or build was performed.
