# Q10 News-Gate Unblock Plan — critical path to the first counted pair
**Auditor task (Wave 1) · 2026-09-02 · read-only · all claims file/DB-evidenced**
DB: `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro` (busy_timeout=30000). Census rerun output under
`scratchpad/wave1/census/census_2026-09-02.{csv,json}`. Survey scripts under `scratchpad/wave1/*.py`.

---

## 0 · Headline (read this first)

**The task's premise — "31 Q09-contiguous pairs each need Q10 news work" — is mostly false. The dominant blocker is a
census read-model bug, not missing news runs.**

Two classification bugs in `tools/strategy_farm/rebaseline_census.py` make the census (which
`book_build_guard` reads for `highest_contiguous_valid_gate`) disagree with the pipeline's own
advancement predicates:

1. **`CONFIG_LOCKED` is scored as STALE, not PASS.** `rebaseline_census.py:128` puts `CONFIG_LOCKED` in
   `STALE_CLS`. But `farmctl.py:456` `Q09_NEWS_SUCCESS_VERDICTS = frozenset({"CONFIG_LOCKED"})` and
   `farmctl.py:17611` cascades a `CONFIG_LOCKED` news result to the incumbent gate — **`CONFIG_LOCKED` is the
   news-gate PASS.** 13 of the 31 "Q09-contiguous" pairs already hold a done v4 `Q10_NEWS/CONFIG_LOCKED` row;
   the census hides it and reports them stuck at Q09.
2. **`Q08=FAIL_SOFT` is scored as ECON_FAIL.** `rebaseline_census.py:114` puts `FAIL_SOFT` in `ECON_FAIL`. But
   the news binder accepts it: `q09_news_runner.py:1169` `dependency["verdict"] not in {"PASS","FAIL_SOFT"}`.
   So a `FAIL_SOFT`-Q08 pair can seal and CONFIG_LOCK its Q10 (the pipeline advances it) while the census marks
   it economically dead at Q08.

**Recomputing the census with `CONFIG_LOCKED` treated as a pass (script `scratchpad/wave1/recompute.py`)
moves 13 pairs from Q09 to Q11/Q12 contiguous with ZERO new terminal work** — their real frontier is
Q12/Q13/Q14, not Q10. `10706/GBPUSD` jumps straight to **Q12-contiguous, frontier Q13** (observed Q14): it is
the single closest pair to counting toward 25, and it needs no news work at all.

The genuinely news-blocked pairs are a small minority (detailed in §3). The one structural fix that makes the
predicates agree is §6.

---

## 1 · The population, exactly

**31 Q09-contiguous pairs** (census `highest_contiguous_valid_gate=Q09`, `earliest_missing=Q10`), frontier_class:
STALE 18, INVALID 6, INFRA 3, MISSING 2, OTHER 2 — matches the CEO update. **+2 census-investment parents that
are NOT Q09-contiguous**: `21507/XAUUSD` and `13213/USDJPY` sit at census `hcvg=Q07, frontier=Q08, ECON_FAIL`
(their Q08 is `FAIL_SOFT`; see §5). Union = **33 target pairs**.

**29 pending `Q10_NEWS` rows** (`scratchpad/wave1/q10survey.py`), holds/class exactly as the CEO update:
- 13 `Q09_AWAITING_SEALED_PLAN` (7 `BIND_PLAN_FAILED` + 6 `VALIDATE_Q08_VINTAGE_FAILED`)
- 11 no-hold (6 vintage, 1 bind, 1 derive-lineage, 3 BOUND_RUNNABLE)
- 5 `NEWS_RUNNER_SPAWN_SILENT_ABORT` (all BOUND_RUNNABLE)

**Only 9 of the 33 target pairs even have a pending Q10 row.** The other 24 already have a *done* Q10 row
(CONFIG_LOCKED or REVIEW_REQUIRED) or none at all.

---

## 2 · Per-pair disposition (all 33 targets)

Groups are the action buckets. "Census fix" = the §6 structural change; needs no terminal time.

### Group A — already news-passed; census bug only (13 pairs) — **NO Q10 work**
`10145/XAU, 10513/XAU, 10706/GBP, 11422/USDCAD, 11881/GBP, 12849/XTI, 12855/XTI, 13054/XTI, 1537/XAG,
20048/XTI, 20266/XTI, 21505/XAG, 9641/WS30` — each holds a done `Q10_NEWS/CONFIG_LOCKED/v4` row
(`scratchpad/wave1/q10done.py`). After the census fix (recompute.py evidence):
- 12 advance to **Q11-contiguous** (frontier Q12).
- `10706/GBPUSD` advances to **Q12-contiguous** (frontier Q13, observed Q14) — closest to counting.
- Any pending/held Q10 row these pairs also carry (`10706` vintage-failed, `11422` spawn-abort, `20048`
  bind-failed) is **redundant** — supersede/ignore, do not rerun.

### Group B — Q08 vintage rerun needed (no CONFIG_LOCKED, pending vintage-failed)
`11288/USDJPY` (Q08=FAIL_SOFT, bindable), `13128/NDX` (Q07,Q08 both PASS), `11421/EURUSD` (**latest Q07 AND
Q08 are INFRA_FAIL** — the frontier evidence is broken; needs a clean Q07→Q08 re-pass, not just a vintage
refresh), `13213/USDJPY` (Q08=FAIL_SOFT — see §5).
Vintage errors captured verbatim, e.g. `11421`: `Q08 baseline setfile vintage mismatch: expected 373138c7…`
(the 2026-08-22 `gen_setfile` regen, commit `9355a64162`); `13128`: `expected edca7afab…`.

### Group C — Q07 lineage rerun needed (bind-failed, no CONFIG_LOCKED)
`13013/NDX` — `Q08 dependency has no Q07 lineage and no identity-bound Q07 predecessor could be authenticated`
(Q07,Q08 currently PASS but lineage not resolvable → rerun Q07 then Q08 on the current setfile/ex5).
(`20048/XTI` is *also* bind-failed but is in Group A — its CONFIG_LOCKED makes the pending row redundant.)

### Group G — no news rows at all (2 pairs)
`20188/USDJPY`, `21501/USDJPY` — census Q09-contiguous but **zero** `Q09_NEWS`/`Q10_NEWS` rows ever
(`q10done.py`: "NO NEWS ROWS AT ALL"). Q07,Q08 both PASS. The Q09→Q10 cascade never created the row. Fix:
governed `enqueue-news-expansions --pair-allowlist-csv` frontier backfill (§4), which creates the Q10 row and
lets the pump autoseal it (vintage should match — both were built on the current tree).

### Group H — done Q10 REVIEW_REQUIRED, no CONFIG_LOCKED (11 pairs) — split by reason (`final.py`)
`cell_execution_failed` (7, **rerun path**): `10123/XAU, 10142/SP500, 10146/AUDUSD, 11294/GDAXI, 12623/XAU,
12708/XAU, 41161/GBP`.
`control_or_policy_off_not_qualifiable` (4, **TERMINAL — document, cannot count**): `10128/XAU, 10183/XAU,
11881/SP500, 13036/GDAXI`. These are control/policy-off strategy variants the news gate cannot qualify; they
should be dropped from the 25-pair candidate pool, not reworked.

### Group I — census parents whose Q08 is FAIL_SOFT (2 pairs) — **waste flag**
`21507/XAUUSD`, `13213/USDJPY`. Both have live OPT_CENSUS programs (`41196`, `41097`; per audit_synthesis
2,565-cell pool) yet census scores them `ECONOMIC_FAIL` at Q08 (`FAIL_SOFT`). `21507` even holds a wasted
`Q10_NEWS/CONFIG_LOCKED`. Either they count (OWNER must ratify FAIL_SOFT as book-eligible → §6 divergence 2) or
their OPT_CENSUS spend (≈130–150 terminal-h each per audit_synthesis) is being burned on pairs that can never
reach 25.

---

## 3 · Answers to the five task questions

**(1) Which Q07/Q08 v4 reruns are required; does Q09 need re-running for the 11421 setfile-hash inconsistency?**
- Groups A + H(terminal) + most of G: **no Q07/Q08 rerun.** Group A is a census fix; Group-H `control_or_policy_off`
  is terminal.
- Group B/C rerun set (append-only, current ex5 sha bound; `final.py` values, first-16 shown — operator computes
  full 64-hex at run time via `contract.sha256_file`):
  - `11288/USDJPY`: Q08 rerun of `0473327d` (currently FAIL_SOFT). ex5 `c9f20a0e…`.
  - `13128/NDX`: Q08 rerun of `91a6f7bc`. ex5 `59b9d165…`.
  - `13013/NDX`: Q07 rerun of `68875929` **then** Q08 rerun of `1090a9f7` (lineage broken). ex5 `bf2cc2ec…`.
  - `11421/EURUSD`: **full Q07→Q08 re-pass** — latest Q07 `cc5a96a7` and Q08 `9d183609` are both INFRA_FAIL.
    ex5 `9dd7facd…`.
- **Q09 re-run for the 839fb74b vs 7b87dbf2 inconsistency:** the census does NOT check cross-gate setfile
  consistency, so a Q09 re-run is **not required to advance the census**. But the CEO-noted 3-way setfile drift
  on `11421` (Q08-era `373138c7`, Q09-bound `839fb74b`, current `7b87dbf2`) means the pipeline lineage is
  genuinely inconsistent. For a *clean, reproducible* book pair the correct append-only sequence is
  Q07→Q08→Q09 on the current `7b87dbf2` setfile so one identity flows through the whole chain; the pump then
  auto-spawns a fresh Q10 bound to the new Q08. Recommend this only for pairs actually destined for the book
  (11421 is a census parent), not fleet-wide.

**(2) Will the existing pending Q10 row autoseal, or need manual bind-q09-plan?**
Autoseal is automatic once its inputs are valid. Mechanism (`farmctl.py:16541` `_spawn_q09_replacements_for_
regenerated_q08` + `:17268` `auto_seal_pending_q09_news`): when an **append-only Q08 rerun**
(`payload.append_only_rerun=1`) on the **same setfile_path** completes done PASS/FAIL_SOFT, the pump spawns a
NEW held `Q10_NEWS` child bound to the new Q08 (whose evidence now records the current hash), then
`bind_plan_to_work_item` re-validates `validate_q08_source_vintage` (`q09_news_runner.py:801`) — now matching —
and releases the row runnable. The old held child is superseded (`:17453`). **So no manual `bind-q09-plan` is
needed** for the vintage/lineage classes: fix the Q07/Q08 evidence and the pump does the rest. Manual
`bind-q09-plan --dry-run` (flag exists, `farmctl.py:29677`) is only a verification tool.

**(3) The 5 `NEWS_RUNNER_SPAWN_SILENT_ABORT` holds — governed release/requeue path.**
Source: `terminal_worker.py:5388` `_park_news_runner_abort` — a worker claimed the bound row, spawned the news
runner subprocess, found it not live (`bound_news_runner_process_not_live`), and parked the row back to
`pending` with hold `NEWS_RUNNER_SPAWN_SILENT_ABORT`, **`release_on_restart=0`** (`:5430`) so a worker restart
does NOT clear it. Rows: `10700/XAU, 11129/SP500, 11422/USDCAD, 11910/NZDUSD, 12710/XTI`. Of the targets:
`11422` is redundant (Group A CONFIG_LOCKED); `11129/SP500` is the only one on-path. The rows are still
BOUND_RUNNABLE (binding payload intact), so the governed path is: (a) inspect `payload.news_runner_spawn_abort.
log_path` to confirm the abort was transient (env/terminal), then (b) governed re-enqueue
`farmctl enqueue-backtest --append-only-rerun-of <id> --rerun-reason "news_runner_spawn_silent_abort transient
infra requeue"` (GREEN: re-enqueue of a no-verdict INFRA row, standing-authorization canonical path). A plain
hold clear is not exposed as a first-class command; the append-only rerun re-derives a clean bound row through
autoseal, which is the safe route.

**(4) The 3 bound hold-free rows never claimed — why, and the exact fix.**
Rows `11147/SP500 (06b9c0f8)`, `12580/AUDUSD (aece4bcc)`, `13059/…basket (86cccb8a)` — BOUND_RUNNABLE, no hold,
never claimed. **Cause = claim-selector ranking, not a defect in the row.** The selector
(`farmctl.py:1465 pending_claim_order_sql`) sorts `priority_track` before phase rank. OPT_CENSUS frontier rows
carry `priority_track=true` + `opt_census_frontier_priority=true` (`:1571`, `:1609`); a bound Q10 row is not
priority_track. In the cold-path term `priority_track*10 + phase_rank − age` (`:1492`) the `*10` dominates, so
a priority OPT_CENSUS row (term ≈ Q04-rank − age) always beats a non-priority Q10 row (term ≈ 10 + Q10-rank −
age); with 5,469 pending OPT_CENSUS rows there is always a claimable one. Under the top-down selector
(`:1433 _topdown_gate_rank_sql`, active iff env `QM_TOPDOWN_GATE_PRIORITY_ENABLED=1` — not set in any launcher
I could find, so cold path is the live default) it is even starker: optimization phases rank 0, `Q10_NEWS`
ranks 2.
- **Cold-path fix (live default): set `priority_track=true` on the 3 rows** (GREEN payload/priority edit; standing
  authorization "queue order/priority changes, no deletions"). Then term = 0 + Q10-rank − age, and Q10-rank <
  Q04-rank (downstream-first) so they beat OPT_CENSUS. This works ONLY on the cold path.
- **Top-down contingency:** `priority_track` is insufficient (opt still wins the gate sub-rank). The fix there is
  a selector **ordering change** — a new `_bound_news_runnable_rank` column (0 when `phase='Q10_NEWS'` AND the
  dispatch binding is present, else 1) inserted in the ORDER BY immediately after `_priority_track_rank`, so a
  completed-prerequisite bound news row drains ahead of OPT_CENSUS. GREEN queue-order change, but it interacts
  with OWNER-DEC-TOPDOWN-PRIORITY-20260828 → note to OWNER. NB: none of these 3 are target/census-parent pairs,
  so this is queue hygiene, not critical path.

**(5) The 67 REVIEW_REQUIRED done Q10 rows — split by reason (`scratchpad/wave1/review2.py`).**
- `cell_execution_failed` **31** → **rerun path**: individual cells died mid-run; append-only rerun of the
  Q10_NEWS row (or its failed cells) re-executes them. Transient-infra class.
- `expanded_7x4_matrix_required` **25** → handled by the pump's `enqueue-news-expansions`
  (`news_gate_service.py:60 verified_expansion_adjudication` authenticates the aggregate; `farmctl.py:29682`
  builds append-only 7×4 child rows). Default read-only; `--apply` to create rows. YES — the pump handles it;
  it just has to be run (currently read-only-only usage).
- `control_or_policy_off_not_qualifiable` **9** → **TERMINAL**: strategy is a control/policy-off variant the
  news gate structurally cannot qualify. Document and drop from candidate pool.
- 2 aggregate-missing (evidence file gone → rerun).
(Group-H target subset breakdown in §2: 7 rerun, 4 terminal.)

---

## 4 · Command list (dry-run-verified where a flag exists; NONE applied)

All `enqueue-backtest` reruns are append-only (old row preserved as evidence). `enqueue-backtest` has **no
`--dry-run`**; safety comes from `--append-only-rerun-of` (never mutates the cited row) + the census recompute
already run. Compute the full 64-hex ex5 sha at run time.

```
# --- STRUCTURAL FIX FIRST (no terminal time): §6 census patch, then re-run book_build_guard ---
#   edit rebaseline_census.py; python tools/strategy_farm/rebaseline_census.py   # regenerates census + md
#   python tools/strategy_farm/book_build_guard.py --status --venue both        # verify new qualified count

# --- Group B/C: Q07/Q08 append-only reruns on current setfile/ex5 (pump then autoseals Q10) ---
python tools/strategy_farm/farmctl.py enqueue-backtest --phase Q08 \
  --append-only-rerun-of 0473327d... --rerun-reason "Q10 unblock: 11288 Q08 vintage refresh (gen_setfile 9355a64162)" \
  --expected-current-ex5-sha256 <sha256 of QM5_11288_...ex5>          # 11288/USDJPY
python tools/strategy_farm/farmctl.py enqueue-backtest --phase Q08 \
  --append-only-rerun-of 91a6f7bc... --rerun-reason "Q10 unblock: 13128 Q08 vintage refresh" \
  --expected-current-ex5-sha256 <sha256 QM5_13128_...ex5>            # 13128/NDX
python tools/strategy_farm/farmctl.py enqueue-backtest --phase Q07 \
  --append-only-rerun-of 68875929... --rerun-reason "Q10 unblock: 13013 Q07 lineage rebuild" \
  --expected-current-ex5-sha256 <sha256 QM5_13013_...ex5>            # 13013/NDX Q07 (then Q08 1090a9f7 after PASS)
python tools/strategy_farm/farmctl.py enqueue-backtest --phase Q07 \
  --append-only-rerun-of cc5a96a7... --rerun-reason "Q10 unblock: 11421 clean Q07 re-pass (latest INFRA_FAIL)" \
  --expected-current-ex5-sha256 <sha256 QM5_11421_...ex5>            # 11421/EURUSD Q07 (then Q08 9d183609)

# --- Group G: create missing Q10 rows for Q09-valid pairs (read-only first, then --apply) ---
#   build a 2-row CSV ea_id,symbol for 20188/USDJPY and 21501/USDJPY
python tools/strategy_farm/farmctl.py enqueue-news-expansions --pair-allowlist-csv <csv>          # DRY (default)
python tools/strategy_farm/farmctl.py enqueue-news-expansions --pair-allowlist-csv <csv> --apply  # apply

# --- Group H cell_execution_failed (7): append-only rerun of the Q10_NEWS row ---
python tools/strategy_farm/farmctl.py enqueue-backtest --phase Q10_NEWS \
  --append-only-rerun-of <q10_row_id> --rerun-reason "cell_execution_failed transient rerun" \
  --expected-current-ex5-sha256 <sha>     # x7 (10123,10142,10146,11294,12623,12708,41161)

# --- expanded_7x4_matrix_required backlog (25 rows fleet-wide): pump expansion ---
python tools/strategy_farm/farmctl.py enqueue-news-expansions            # DRY (default, read-only)
python tools/strategy_farm/farmctl.py enqueue-news-expansions --apply    # apply

# --- SPAWN_SILENT_ABORT requeue (on-path: 11129/SP500) ---
python tools/strategy_farm/farmctl.py enqueue-backtest \
  --append-only-rerun-of 745671a4... --rerun-reason "news_runner_spawn_silent_abort transient infra requeue"

# --- bound-starved 3 rows (cold-path fix): set priority_track=true (queue-order edit, GREEN) ---
#   (peripheral; not census parents — do after the above)
```

**Terminal-neutral / no-action:** Group A (13), Group H control_or_policy_off (4), all redundant pending rows on
Group A pairs.

---

## 5 · Ordered priority (census-investment pairs first) + terminal-hour estimate

Medians per task: Q07 1.6h, Q08 1.4h, Q10 ~27h.

| Rank | Pair | Group | Action | Terminal-h |
|---|---|---|---|---|
| 0 | **census patch (§6)** | — | code fix; unlocks 13 pairs to Q11/Q12 | **0** |
| 1 | 10706/GBPUSD | A→Q12 | census fix only → needs Q13,Q14 (analytic) | 0 (news) |
| 2 | 11421/EURUSD | B | Q07 1.6 + Q08 1.4 + Q10 27 (INFRA_FAIL rebuild) | ~30 |
| 3 | 20266/XTI, 1537/XAG, 13054/XTI, 11881/GBP, 21505/XAG, 20048/XTI, 12849/XTI, 12855/XTI, 9641/WS30, 10145/XAU, 10513/XAU, 11422/USDCAD | A→Q11 | census fix only → Q12 frontier | 0 (news) |
| 4 | 21507/XAU, 13213/USDJPY | I | OWNER FAIL_SOFT ruling (§6 div. 2); else Q08 re-pass ~1.4+27 | 0 or ~28 ea |
| 5 | 11288/USDJPY, 13128/NDX, 13013/NDX | B/C | Q07/Q08 rerun + Q10 | ~28–30 ea |
| 6 | 20188/USDJPY, 21501/USDJPY | G | news-expansion backfill → Q10 | ~27 ea |
| 7 | 10123,10142,10146,11294,12623,12708,41161 | H-rerun | Q10 cell rerun | ~27 ea (partial) |
| — | 10128,10183,11881/SP500,13036 | H-terminal | drop from pool | 0 |

**Aggregate news terminal-hours to clear the genuine backlog:** ~11 pairs × ~27h ≈ **300 terminal-h** worst-case
(most Group-H reruns are partial-cell, so real cost is lower), **plus ~5–6 Q07/Q08 reruns ≈ 15h**. **But 13 of
the 33 pairs (incl. the front-runner 10706) need 0 news hours** — the census patch is worth more than the entire
news backlog. The true bottleneck to the FIRST counted pair is downstream Q12/Q13/Q14 (Q12 ≈ 130–150 terminal-h/
pair per audit_synthesis), not Q10.

---

## 6 · The one structural fix (census predicate ⇄ pipeline predicate)

**Change `rebaseline_census.py`, not the gates.** The census is a *classifier of existing evidence* (its own
docstring: "Thresholds are NOT redefined here"). It has drifted out of sync with the pipeline's ratified
advancement predicates. Two edits:

1. **Primary (unambiguous bug):** move `CONFIG_LOCKED` from `STALE_CLS` (`:128`) into `PASS_ECON` (`:100`).
   `vclass` checks `PASS_ECON` first (`:169`), so the reclassification is clean. Justification: the news gate
   already ratified `CONFIG_LOCKED` as success (`farmctl.py:456 Q09_NEWS_SUCCESS_VERDICTS`, cascade `:17611`).
   Effect (verified, `recompute.py`): `by_highest_contiguous_valid_gate` gains Q11:12, Q12:1; 13 pairs advance;
   qualified-pair candidate frontier moves from Q10 to Q12/Q13. This is a read-model correctness fix (GREEN in
   spirit) but it **moves the `book_build_guard` headline count that feeds OWNER-DEC-A1**, so surface it to OWNER
   as a fix, not a threshold change. It does not by itself make any pair terminal (all land at Q11/Q12, below the
   Q14 terminal-requalification gate).

2. **Secondary (genuine divergence — OWNER ruling, do NOT self-resolve):** `Q08=FAIL_SOFT`. The news binder
   accepts it (`q09_news_runner.py:1169`) so the pipeline advances FAIL_SOFT-Q08 pairs (21507, 13213 have live
   OPT_CENSUS and even CONFIG_LOCKED), while the census scores them ECON_FAIL. This is a real gate-semantics
   question — should a soft-Davey-fail pair count toward the book? — and touches sealed criteria (ROT). Two
   self-consistent resolutions: (a) OWNER ratifies FAIL_SOFT as book-eligible → add `FAIL_SOFT` to census
   `PASS_ECON` AND keep the binder as-is; or (b) OWNER holds the line → the **binder** should reject FAIL_SOFT
   Q08 (tighten `q09_news_runner.py:1169` to `{"PASS"}`), and OPT_CENSUS on 21507/13213 stops as wasted spend.
   Default until OWNER rules: census-strict (b) — do not count FAIL_SOFT pairs; flag their OPT_CENSUS as at-risk.

**Which one changes: the census (edit 1) unilaterally; the binder-vs-census FAIL_SOFT split (edit 2) waits on
OWNER.** After edit 1, the census's Q10 validity predicate and the pipeline's news-success predicate agree, and
the 24 pairs that currently look "Q10-blocked" but are actually news-passed stop generating redundant autoseal
churn.

---

## 7 · Risks / caveats
- `enqueue-backtest` has no `--dry-run`; every rerun here is append-only (cited row preserved) — that is the
  safety mechanism. I applied nothing.
- The top-down selector's live state could not be confirmed from a launcher (`QM_TOPDOWN_GATE_PRIORITY_ENABLED`
  is defined only in `farmctl.py`, set in no `.ps1` I found) — the cold-path fixes assume the default. Verify the
  pump's actual env before relying on the priority_track fix for item (4).
- The census patch changes a number OWNER watches (qualified_pairs). It is a bug fix, but must be reported, not
  slipped in.
- FAIL_SOFT (edit 2) is ROT-adjacent — not a CEO call.
