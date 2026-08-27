# DL-089 V7 pruning — floor-break measurement + amendment text (no activation)

- Router task: `4598b5eb-ff1f-4940-97a9-ead459dbb6a4` (ops_issue, claude, priority 70)
- Executed: 2026-08-27, from canonical checkout `C:/QM/repo` on `agents/board-advisor`
- Constraint honored: **DL-089 stays byte-sealed until an amendment file is written and
  OWNER-authorized separately; no census cell was skipped; this ticket implements
  nothing.**
- Context: `decisions/2026-08-27_owner_v5_no_buy_v7_pruning_ja.md` — OWNER already
  returned "V7: ja" (in-principle) on 2026-08-27, binding this ticket's output ("Ticket
  4598b5eb liefert Floor-Break-Messung + exakten Amendment-Text") as the scope the
  orchestrator must check the eventual amendment file against.

## 0. Premise correction (read this first)

The routed payload assumed **"100+ measured GBP cells"**. That premise is wrong and the
correction changes the headline number:

| What the payload assumed | What `farm_state.sqlite` actually holds |
|---|---|
| 100+ measured GBP cells, floor-break quote computable now | **13 GBPUSD.DWX cells measured** (1 program: `DL089_QM5_10706_GBPUSD_DWX_2019_2025`, 1085-cell plan, 1072 pending) |
| — | **91 USDJPY.DWX cells measured** (pilot program, DL-089 Nachtrag §7) — this is where the "100+" came from: 13 + 91 = 104 |
| — | **0 cells for any other GBP-prefixed symbol** — GBPJPY/GBPAUD/GBPCAD/GBPCHF/GBPNZD have no OPT_CENSUS work_items at all yet |

Query (rerunnable, read-only):
```sql
-- D:/QM/strategy_farm/state/farm_state.sqlite, mode=ro
SELECT symbol, status, COUNT(*) FROM work_items WHERE phase='OPT_CENSUS' GROUP BY symbol, status;
-- GBPUSD.DWX|done|13  GBPUSD.DWX|pending|1072  USDJPY.DWX|done|91  USDJPY.DWX|pending|994
```

## 1. Floor-Break-Quote (gemessen)

Method: `entry_trading_days` is **not stored** — it is derived per cell from the Q02
trade dump (`report.htm`) via `tools/strategy_farm/opt_census.py::cell_report()`. I
reran that derivation read-only against all 104 `done` OPT_CENSUS rows:

```python
# rerunnable — reuses opt_census.cell_report() unmodified, no writes
import sqlite3, json, sys; sys.path.insert(0, 'C:/QM/repo')
from pathlib import Path
from tools.strategy_farm import opt_census as census
c = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
rows = list(c.execute(
    "select symbol,payload_json,evidence_path from work_items "
    "where phase='OPT_CENSUS' and status='done'"))
breaks = 0
for sym, pj, ev in rows:
    p = json.loads(pj)
    cr = census.cell_report(Path(ev))
    if cr['entry_trading_days'] < 10:
        breaks += 1
print(len(rows), breaks)   # -> 104 0
```

**Result: 0 / 104 measured cells break the floor (0.0%).**

This number is **not yet informative** for the savings projection, for a structural
reason, not a lucky draw: every one of the 104 measured cells is **year 2019** — the
first census year for its arm (91 USDJPY arms × 1 year, 13 GBPUSD cells = 12 arms + 1
baseline × 1 year). No arm has a second measured year yet, so:

- The floor-break quote **cannot be distinguished from a per-arm, per-year base rate
  yet** — 104 independent (arm, year=2019) draws tell us the year-1 break rate is low,
  not the "at least one break across 7 years" rate the pruning amendment cares about.
- **Savings potential today: 0 cells** (no arm has broken yet, so nothing is prunable
  under the amendment right now). The 20–50% plausibility range in
  `docs/ops/DURCHSATZ_ANALYSE_40_TAGE_2026-08-27.md` §5.3 remains an unverified
  projection pending year-2+ data — I am not able to raise it to a measured number from
  what exists today, and did not degrade it into a false-precision estimate to satisfy
  the ticket's acceptance criterion.
- Recommendation: rerun this exact query once the pilot program (USDJPY, 91→ next
  batch) reports its second measured year per arm; that is the first point a genuine
  break-by-year-2 rate exists.

## 2. Amendment text (DL-089 addendum — draft, not filed)

Exact clause, matching the OWNER receipt's wording
(`decisions/2026-08-27_owner_v5_no_buy_v7_pruning_ja.md` §2) and grounded in the actual
selection code (`tools/strategy_farm/opt_census_select.py`):

> **DL-089 Amendment 1 (2026-08-27) — deterministic floor-break pruning.** Extends
> decision #3 ("Frequenz-Boden fail-closed"). Once a candidate arm's measured
> `entry_trading_days` for calendar year Y is `< activity_floor` (10, pro-rata per
> CEO-MP-#4), that arm's remaining declared census cells for years > Y are **not
> dispatched**. Each skipped cell gets an append-only `skipped_as_excluded` receipt
> recording: `cell_key`, the triggering `(arm, year=Y)` cell_key, and timestamp. The
> cell's identity stays declared in the ledger (`declared_trial_count` is unchanged —
> skip is a dispatch decision, not a trial-count deflation). Selection rule #2/#3/#4
> (consistency quorum, activity floor, anchored WF) stay byte-unchanged.

Grounding for the "not dispatched" mechanism, so the eventual implementer has a
concrete starting point (this ticket does not touch these files):
- `opt_census_select.py::evaluate_arm()` (line 128) already iterates `years` in
  ascending order and returns `admissible=False` **immediately** on the first year
  whose cell is either missing (`cell is None`) or floor-breaking
  (`cell.entry_days < activity_floor`) — it does not distinguish the two. A skipped
  cell that is simply never inserted into `matrix[direction][pid][year]` therefore
  produces the identical `ArmEval` as a cell that was actually run and broke the floor.
  No synthetic cell/value needs to be fabricated.
- The gating change needed is in `_census_specs()` / `_build_matrix()` /
  `_handle_enqueued()` (lines 537–608): today `_handle_enqueued` blocks
  (`waiting=True`) until every declared spec resolves to OK or INFRA. The amendment
  needs a third resolution class (`SKIPPED_EXCLUDED`) that satisfies this gate without
  ever being dispatched to the tester queue, plus the actual OPT_CENSUS
  work-item-creation/dispatch path (not read in this ticket) must stop creating
  `pending` rows for cells downstream of a confirmed break.

## 3. Null-information-loss proof

Claim: skipping arm A's cells for years > Y (after a confirmed floor break at year Y)
changes no arm's final admissibility or ranking versus running them.

Proof, from the code as it exists today (not a new invariant introduced by the
amendment):

1. `evaluate_arm(arm_cells, baseline_cells, years, ...)` iterates `years` — which is
   always an **anchored, contiguous, ascending** range starting at the census start
   year (WF windows in `census.WF_WINDOWS` are anchored: `select_years` for window *k*
   is `[start_year .. start_year + k]`, never a discontiguous or descending set; the
   full-census admissibility check uses the same full ascending range 2019–2025).
2. The loop body is: for each `year` in that ascending order, if the cell is absent OR
   breaks the floor, `return ArmEval(admissible=False, ...)` **immediately** — no later
   `year` in the list is ever inspected once this fires.
3. The census itself measures years in ascending order per arm (walk-forward: you
   cannot have a 2023 result without having first executed up through 2023). So the
   first year at which `evaluate_arm` would encounter "missing or breaking" is, by
   construction, the same year the pruning amendment identifies as the break — years
   after Y were never going to be inspected by step 2 regardless of whether they exist.
4. Therefore: for every window whose `select_years` includes Y (which is every window,
   since Y ≤ the window's own end year for an anchored range including Y), the
   admissibility verdict is `False` whether the arm's post-Y cells were run or skipped.
   For windows that end **before** Y, admissibility depends only on years ≤ that
   window's end, which the skip never touches (they were already measured, unaffected).

Consequence: `qualifies` (§2 selection) and `select_direction`'s ranking (which only
ever sorts over `admissible and qualifies` arms) are bit-for-bit identical whether the
post-break cells are run or skipped. The skip removes only work whose outcome was
already fully determined by step 2/3 above — this is what "deterministic, informational
zero-cost" means concretely in this codebase, not an assumption.

Caveat (must be in the amendment, not silently assumed): this proof depends on
`select_years` always being ascending-anchored-from-start. If a future WF redesign ever
scores a *non-contiguous* or *reverse* year window, the short-circuit argument in step 2
breaks and the amendment would need to be re-derived — worth one sentence in the filed
amendment so it doesn't silently rot.

## 4. OWNER template

**Status: OWNER has already returned "V7: ja" (in-principle) on 2026-08-27** —
`decisions/2026-08-27_owner_v5_no_buy_v7_pruning_ja.md`, binding text: the receipt
explicitly names this ticket (`4598b5eb`) as the deliverable and instructs the
orchestrator to check the produced amendment text (§2 above) against the receipt scope
before implementation proceeds. Filing this template anyway for the audit trail /
in case the text below needs a second look:

```
OWNER-DEC-DL089-PRUNING-AMENDMENT-TEXT-REVIEW-20260827

Amendment text (§2 above) reviewed against receipt scope:
[ ] JA — text matches scope; implementation + tests may proceed (flag/review-gated
    activation as usual)
[ ] NEIN — text deviates from scope; do not implement; feedback: ____
[ ] VERTAGT — wait for more floor-break data (§1) before filing the amendment

Floor-break quote at time of this review: 0/104 (all year-1 only; not yet a valid
estimate of the multi-year break rate — see §1).
```

## Evidence

- `D:/QM/strategy_farm/state/farm_state.sqlite` — `work_items` table, `phase='OPT_CENSUS'`
  (read-only queries above, rerunnable).
- `decisions/DL-089_pattern_filter_wf_census_v3.md` — sealed rule #3 (frequency floor),
  quoted verbatim in §2.
- `decisions/2026-08-27_owner_v5_no_buy_v7_pruning_ja.md` — OWNER receipt binding this
  ticket.
- `docs/ops/DURCHSATZ_ANALYSE_40_TAGE_2026-08-27.md` §5.3 — origin of the 20–50%
  projection corrected in §1.
- `tools/strategy_farm/opt_census_select.py` — code cited in §2/§3 (read-only, not
  modified).

## What this ticket does NOT do

No file under `decisions/DL-089*` was created or modified. No code in
`tools/strategy_farm/opt_census*.py` was modified. No census cell was skipped, held, or
had its dispatch state changed. No `--apply`/write path was executed anywhere in this
ticket.
