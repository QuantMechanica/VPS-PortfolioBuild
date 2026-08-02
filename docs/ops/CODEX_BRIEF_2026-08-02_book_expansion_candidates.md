# CODEX BRIEF 2026-08-02 — DXZ book expansion: adjudicate the 12 off-book Q10 passes

**Author:** Claude. **Implementer:** Codex (Sol, effort max). **Reviewer:** Claude.
**Authority:** OWNER 2026-08-02 („prüfen, ob es noch weitere Sleeves gibt, die
das Buch verbessern?").

**Hard constraints:** factory keeps running; no T_Live contact, no deploy, no
baseline generation, no book manifest edit — this ticket produces a *ranked
recommendation only*; read-only against the farm DB; explicit-pathspec commits.

## Starting facts (verified by Claude 2026-08-02, re-verify them)

The live DXZ book holds 24 sleeves. A DB census of `phase='Q10' AND
status='done' AND verdict='PASS'` returns 40 rows covering 12 distinct
(ea, symbol) identities that are **not** in the live book:

| candidate | symbol | last Q10 PASS |
|---|---|---|
| 13036 | GDAXI | 2026-07-26 |
| 1328 | EURJPY | 2026-07-26 |
| 10142 | SP500 | 2026-07-26 |
| 10692 | NDX | 2026-07-26 |
| 10938 | GDAXI | 2026-07-26 |
| 11422 | USDCAD | 2026-07-25 |
| 10145 | XAUUSD | 2026-07-24 |
| 20048 | XTIUSD | 2026-07-22 |
| 10183 | XAUUSD | 2026-07-21 |
| 10128 | XAUUSD | 2026-07-20 |
| 13013 | NDX | 2026-07-20 |
| 10123 | XAUUSD | 2026-07-20 |

Current book symbol concentration: XAUUSD 5, EURUSD 4, GBPUSD 2, GDAXI 2,
NDX 2, USDJPY 2, AUDUSD 2, SP500/AUDCAD/XTIUSD/XNGUSD/EURGBP 1 each.
**EURJPY and USDCAD are symbols the book does not trade at all.**

## Required adjudication (a Q10 PASS alone admits nothing)

For every candidate, in this order — a failure at any step ends that candidate
with a stated reason:

1. **Vintage:** was the Q10 PASS produced by the EA's *current* binary? Stale
   evidence disqualifies until re-run (the 2026-08-01 FTMO inventory already
   flagged e.g. 10145 as "evidence predates current build"). State the hashes.
2. **Gate lineage completeness:** full Q02→Q10 chain present and current on that
   binary. The same inventory flagged missing Q02/Q03 evidence for 10183 and a
   missing Q03 pass for 13036 — verify, do not assume.
3. **Build cleanliness / registry:** clean build, exact magic-row identity, set
   file with `RISK_FIXED>0` and `RISK_PERCENT=0` for backtest lineage.
4. **Portfolio contribution — the decisive criterion.** Per the portfolio-first
   admission doctrine and DL-083 (effective correlation budget 0.15 strong /
   0.40 refuse), compute each candidate's *marginal* contribution to the
   existing 24-sleeve book: correlation against the book's shared-equity trace,
   effect on book-level drawdown and return significance, and whether it adds a
   genuinely new exposure. A standalone-strong sleeve that duplicates existing
   XAUUSD exposure may add nothing — say so.
5. **Cost realism:** venue cost model applied; no sleeve admitted on
   spread-inclusive optimism.

## Deliverable

`docs/research/BOOK_EXPANSION_CANDIDATES_2026-08-02.md`:
- one row per candidate with the verdict at each step and the marginal
  portfolio numbers;
- a **ranked shortlist** of what would actually improve the book, with the
  reason each earns its slot (diversification vs expectancy);
- an explicit "adds nothing" list with reasons;
- for anything blocked only by stale vintage or a missing gate: the exact
  enqueue commands to fix it (for Claude to run), with machine-time estimates.

Router task → REVIEW. Recommendation only; admission is Claude review + OWNER.
