# CODEX BRIEF 2026-08-02 — DXZ book substitution analysis (swap, not only add)

**Author:** Claude. **Implementer:** Codex (Sol, effort max). **Reviewer:** Claude.
**Authority:** OWNER 2026-08-02 („Vielleicht sind die XAUUSD Sleeves ja auch
besser, als die, die wir schon im Portfolio haben? Dann können wir diese
ersetzen bzw. tauschen oder auch ergänzen").

**Predecessor (APPROVED):** `docs/research/BOOK_EXPANSION_CANDIDATES_2026-08-02.md`
— it adjudicated *addition* only and found no admissible candidate. Reuse its
inputs, its `marginal_contribution_eval.py` machinery, its sealed incumbent
bundle and its vintage/lineage table verbatim; do not redo that work.

**Hard constraints:** read-only (farm DB `mode=ro`, no T_Live contact, no
manifest/queue/baseline/deploy mutation, no enqueue); factory keeps running;
explicit-pathspec commits; recommendation only.

## The question

Adding a sleeve and swapping one are different calculations. For every
candidate, evaluate replacing each *incumbent on the same symbol*:

- XAUUSD candidates `10145`, `10183`, `10128`, `10123` against the five
  incumbent XAU sleeves (`1556`, `10403`, `10513`, `12567`, `12989`);
- GDAXI candidates `13036`, `10938` against `10911` and `13301`;
- NDX candidates `13013`, `10692` against `13128` and `10440`;
- SP500 candidate `10142` against `11132`;
- XTIUSD candidate `20048` against `10919`.

`11422/USDCAD` and `1328/EURJPY` have no incumbent on their symbol — they are
addition-only and stay as adjudicated.

For each (candidate, incumbent) pair compute, on the same aligned windows and
the same 9.75 % total-risk budget as the predecessor: ΔSharpe, ΔMaxDD, Δworst
day, annualized net contribution, and the resulting book correlation profile,
each measured against the **unchanged 24-sleeve book** as baseline. Report the
swap as an improvement only when it beats both the baseline **and** the
simple-addition alternative from the predecessor.

## Required honesty conditions

- A swap inherits the candidate's vintage/lineage defects. State for every
  proposed swap what would have to be repaired first — a swap is never a
  shortcut around the admission chain.
- Removing an incumbent destroys live evidence and a kill-switch baseline. Name
  that cost explicitly per proposed removal (the incumbent's own Q10 status,
  KS coverage, and how long it has traded live).
- If no swap beats the baseline — which the predecessor's correlation figures
  (0.19–0.27 for the XAU candidates) suggest is likely — say so plainly. A
  clean negative is the expected and fully acceptable result.

## Deliverable

`docs/research/BOOK_SUBSTITUTION_2026-08-02.md`: the pair matrix, a ranked list
of any swap that genuinely beats the status quo (or an explicit statement that
none does), the removal cost per case, and the repair precondition per proposal.
Router task → REVIEW. Recommendation only; admission and removal are Claude
review plus OWNER authority.
