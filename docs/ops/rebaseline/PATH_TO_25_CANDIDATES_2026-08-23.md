# Path to 25 — Concrete Candidate Plan to the Terminal Optimization Gate

**Author:** Claude (Orchestrator, board-advisor) · **Date:** 2026-08-23 · **Branch:** `agents/board-advisor`
**Read-only.** Built from the read-only census (`rebaseline_census.py`) and the dry-run backfill
plan (`backfill_planner.py`). No DB write, no enqueue, no factory or T_Live mutation.
**Runtime contract today = v3** (`gate_manifest.v3.json`); v4 linear numbering is merged but
`READ_INERT` until the OWNER cutover flip (`OPEN_ITEMS_STATUS.md §0d`, row 13).

**Inputs (evidence):**
- Census: `docs/ops/rebaseline/DB_TEST_CENSUS_2026-08-23.md`, `D:/QM/reports/rebaseline/census_2026-08-23.csv`
- Backfill: `docs/ops/rebaseline/BACKFILL_PLAN_2026-08-23.md`, `D:/QM/reports/rebaseline/backfill_plan_2026-08-23.csv`
- Q09 dam: `docs/ops/evidence/2026-08-23_rb-q09-autoseal.md`
- Gate map: `docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md` §3
- This analysis: `D:/QM/reports/rebaseline/path_to_25_top80.csv` (per-gate status of the top 80)

**Gate vocabulary.** "Terminal optimization gate" = **v3 `Q16` Best-Settings Head-to-Head =
v4 `Q14`**. The census contiguity chain is `Q02→Q03→Q04→Q05→Q06→Q07→Q08→Q09→Q10→Q14→Q15→Q16`
(v3 storage names). Under v4 the same chain reads
`Q09 Baseline → Q10 News → Q11 Incumbent → Q12 Pattern → Q13 ParamOpt → Q14 Head-to-Head`
for the Phase-2 band. This document uses **v3 storage names** (the runtime today) and gives the
v4 equivalent on first use.

---

## 0 · Headline: the 25 target is not a throughput problem — it is a broken-gate problem

**Zero pairs have ever cleared the economic news gate, and the optimization fork has never run
to completion once.** Backfilling more strategies into the base does not produce a single
book-eligible candidate until two structural gates are proven passable. Measured facts:

| Fact | Value | Evidence |
|---|---:|---|
| (EA,Symbol) pairs total | 14,513 | census |
| Pairs contiguously valid ≥ Q08 (frozen baseline) | 26 | census |
| Pairs contiguously valid ≥ Q10 (incumbent) | 3 | census |
| **Pairs contiguously valid ≥ Q16 (terminal opt gate)** | **0** | census |
| `Q09_NEWS` economic PASS rows, all history | **0** | DB: 49 REVIEW_REQUIRED, 29 INFRA_FAIL, 18 PENDING_RUNNER, 1 CONFIG_LOCKED, 1 INVALID_EVIDENCE |
| `Q16` (v4 Q14 head-to-head) rows, all history | **0** | DB `work_items` |
| `Q15` (v4 Q13 param-opt) rows, all history | 1 (CHALLENGER_SPAWNED, not a PASS) | DB |
| `Q14` (v4 Q12 pattern) rows, all history | 14 (11 OPT_ELIGIBLE, 3 OPT_REJECTED — none a terminal PASS) | DB |

The path to 25 is therefore **sequenced, not parallel-scalable**: first make Q09 and the opt
fork demonstrably passable on a handful of pairs, then widen the base. Volume work before that
is premature and only deepens the pile at the Q09 dam.

---

## 1 · Ranking method

For every `(EA,Symbol)` pair I rank by **remaining work to the terminal gate**:

1. **Spine = the backfill plan CSV, not the raw census disposition.** The raw census
   dispositions the entire frontier cohort wrong (see §1.1); the backfill planner already
   corrects it. Rows with action `STOP_ECONOMIC_FAIL`, `STOP_NOT_APPLICABLE`, `SKIP_REUSABLE`
   (dedup), and `COMPILE_EA` are excluded — they are terminal or not new work.
2. **Primary key = `highest_contiguous_valid_gate` descending** (most progress first).
3. **Secondary = remaining-gate-count ascending**, then **oldest pair first**.
4. Remaining hours = sum of phase medians for every gate from the frontier through Q16.

Result: **7,062 actionable candidates**. Distribution by contiguous frontier:

| frontier (v3 hcvg) | v4 name | actionable pairs | remaining gates to Q16 |
|---|---|---:|---:|
| Q10 | Q11 Incumbent | 3 | 3 (Q14,Q15,Q16) |
| Q08 | Q08 baseline dossier | 23 | 5 (Q09,Q10,Q14,Q15,Q16) |
| Q07 | Q07 multi-seed | 10 | 6 |
| Q06 | Q06 stress | 23 | 7 |
| Q05 | Q05 full-history | 10 | 8 |
| Q04 | Q04 walk-forward | 26 | 9 |
| Q03 | Q03 param sweep | 277 | 10 |
| Q02 | Q02 baseline screen | 5,073 | 11 |
| NONE | — | 1,617 | 12 |

The **top 80** (frontier Q10/Q08/Q07/Q06/Q05/Q04) are in
`D:/QM/reports/rebaseline/path_to_25_top80.csv` with per-gate remaining status, planner action,
binding state, and the exact `farmctl` command where one is bindable.

### 1.1 · Correction applied — the census buries the frontier cohort as "economic failures"

The 21 pairs the census reports as `highest_contiguous_valid_gate=Q08` are **all** dispositioned
`ECONOMIC_FAIL`. This is a **census artifact, not a real economic death.** Direct read-only check
of those 21 pairs' Q09 rows:

- **20 of 21** carry `Q09_PORTFOLIO = FAIL_PORTFOLIO`; 1 carries `Q09_PORTFOLIO = NEED_MORE_DATA`.
- Their economic lane `Q09_NEWS` carries **no economic verdict at all** — only PENDING_RUNNER,
  REVIEW_REQUIRED, INFRA_FAIL, and pending/active rows.

`Q09_PORTFOLIO` is **informational only** (OWNER E1 2026-08-22; v4 proposal §3 — "never a
pre-confirmation abort"). `rebaseline_census.py:canonical_gate` collapses `Q09_NEWS` and
`Q09_PORTFOLIO` into one `Q09` gate, so a `FAIL_PORTFOLIO` row makes `frontier_class=ECON_FAIL`
→ `disposition=ECONOMIC_FAIL`, wrongly declaring the whole frontier cohort dead. The **backfill
planner does not make this mistake** (`backfill_planner.py:494-523`): it caps the frontier at
Q08 and re-targets the economic `Q09_NEWS` lane. This plan follows the planner, which is why the
23 Q08-frontier pairs re-appear as the near-terminal cohort. **Recommended fix:** teach the
census to ignore `Q09_PORTFOLIO` for contiguity (a one-line class change), so the census MD stops
reporting 21 phantom economic deaths. Filed as a follow-up ticket below.

The symmetric masking also affects the **3 Q10-valid pairs** (`QM5_10706/GBPUSD`,
`QM5_11421/EURUSD`, `QM5_11422/USDCAD`): each earned its Q09 credit via `Q09_PORTFOLIO=PASS_PORTFOLIO`
while its `Q09_NEWS` lane is REVIEW_REQUIRED/INFRA/PENDING. So even the three closest pairs have a
**masked Q09_NEWS hole** — none has genuinely cleared the economic news gate.

---

## 2 · Top 80 — exact missing rows per gate, actions, hours

Full per-candidate detail is in `path_to_25_top80.csv`. Aggregate view of the top 80:

### 2.1 · Missing-row demand per gate (how many of the top 80 still need each gate)

| gate (v3) | v4 name | top-80 pairs still needing it | phase-median h/run | est. total h (median) |
|---|---|---:|---:|---:|
| Q05 | Q05 full-history | 11 | 0.6056 | 6.7 |
| Q06 | Q06 stress | 21 | 0.3203 | 6.7 |
| Q07 | Q07 multi-seed | 44 | 1.3092 | 57.6 |
| Q08 | Q08 dossier | 54 | 1.2914 | 69.7 |
| Q09 | **Q10 News (the dam)** | 77 | 0.3192 *(unreliable — see §2.3)* | ≥ 200 (real) |
| Q10 | Q11 Incumbent | 77 | ~0 | unknown |
| Q14 | Q12 Pattern | 80 | ~0 (never passed) | unknown |
| Q15 | Q13 ParamOpt | 80 | ~0 (1 row ever) | unknown |
| Q16 | Q14 Head-to-Head | 80 | ~0 (0 rows ever) | unknown |

Every one of the top 80 must pass Q09, Q14, Q15, and Q16 — the four gates that have never
produced a production PASS. **That is the wall, not the backtest compute.**

### 2.2 · Cumulative factory hours (median-based, serial sum)

| candidates (frontier-first) | cumulative remaining hours (median) | distinct EAs |
|---:|---:|---:|
| 25 | 7.0 | 25 |
| 40 | 35.1 | 38 |
| 60 | 93.8 | 55 |
| 80 | 165.3 | 73 |

These numbers are **misleadingly small** for the first 26 candidates because their remaining
gates (Q09,Q10,Q14,Q15,Q16) all carry ~0 phase medians — those gates barely or never completed,
so there is no honest historical duration. Treat §2.2 as a **lower bound that is wrong at exactly
the gates that matter.** The real cost lives in §2.3 and §3.

### 2.3 · Why the Q09/opt medians are ~0 and what a real run costs

- `Q09` median 0.3192 h is drawn from historical work-items that were mostly **incomplete**
  (first-cell aborts) — it is not the cost of a real contract-v3 run. A real v3 run is
  **8 configurations × up to 3 h cell-timeout** (`--cell-timeout-sec 10800`,
  `2026-08-23_rb-q09-autoseal.md`). Across free terminals the 8 cells parallelize, so wall time
  per pair ≈ one 3 h wave; compute ≈ up to 24 terminal-hours per pair. **If the adjudication
  finds a material news effect, the pair expands to the 7×4 = 28-cell matrix** (much heavier) and
  returns REVIEW_REQUIRED, not PASS.
- `Q10/Q14/Q15/Q16` medians are ~0 because the opt fork has essentially never run (§0). Their
  real cost is **unknown** and must be measured on the first production runs (§3, GELB new-lever
  budget applies to any new Q15 param sweep).

---

## 3 · Structural blockers on the path (ranked by leverage)

### B1 — The Q09_NEWS dam (highest leverage; the single true dam)
- **0 economic PASS in all history** across 52 pairs (`OPEN_ITEMS_STATUS.md §10-17`; DB confirms
  49 REVIEW_REQUIRED / 29 INFRA_FAIL / 18 PENDING_RUNNER / 1 CONFIG_LOCKED / 1 INVALID_EVIDENCE).
- Contract v3 (1 physical seed 17 + seam-reconstructed full window) is now **executable** —
  the design-only gap is closed (`2026-08-23_rb-q09-autoseal.md` §"Code defects fixed").
- **We do not yet know that any strategy can pass it.** Until one non-material 8-config v3 run
  reaches `CONFIG_LOCKED`/PASS on a real pair, the whole 25 target has **no proven yield rate.**
  This is the #1 thing to de-risk.

### B2 — The 9 autoseal holds need Q07/Q08 regeneration, not release
- 9 active `Q09_AWAITING_SEALED_PLAN` holds (DB confirmed). Every one is a **genuine
  Q07/Q08/source-vintage defect**, not a code frontier bug: 5 Q08 identity/hash mismatches,
  1 include-closure vintage drift, 2 missing durable Q07 aggregates, 1 missing Q07 predecessor
  (`2026-08-23_rb-q09-autoseal.md` per-hold table). **Zero `RELEASE_AFTER_FIX` rows** — none
  releases by re-running the sealer. The fix is to **regenerate the Q07/Q08 evidence** (Codex
  rebuild + rerun), then the planner binds the Q09 plan. Pairs affected include
  QM5_10847/GDAXI, QM5_12989/XAUUSD, QM5_13128/NDX, QM5_12847/NDX, QM5_10706/GBPUSD,
  QM5_12623/XAUUSD, QM5_11294/GDAXI, QM5_10815/GDAXI, QM5_1567/EURUSD.

### B3 — Pattern / param-opt / head-to-head have never run in production
- `Q14`(v4 Q12 pattern) 14 rows, none a terminal PASS; `Q15`(v4 Q13 param-opt) 1 row
  (CHALLENGER_SPAWNED); `Q16`(v4 Q14 head-to-head) **0 rows ever**. The DL-089 pattern-filter
  selection and the head-to-head adjudication have **never executed end-to-end in the factory.**
- The 3 Q10-valid pairs sit at the `Q14` frontier with `OPT_ELIGIBLE` opt-cards but no gate PASS.
  These 3 are the natural **first production run of the opt fork** — commissioning them proves
  the Q14→Q15→Q16 machinery before any batch depends on it.

### B4 — 12% replacement / activity criteria pending
- The **12%-threshold replacement** is GELB "once the cohort stands" (`CLAUDE.md` Stehende
  Vollmacht); the activity criterion (≥10 entry-days/scored-year) is ratified but the **partial-year
  pro-rata** is still pending OWNER (`docs/ops/ACTIVITY_CRITERION.md §R`). Both bear on which
  pairs actually qualify at the portfolio/book stage; neither blocks the per-pair Q09→Q16 path,
  but both must resolve before a 25-count is declared "book-ready."

### B5 — Compile build-gate class `EA_INDICATOR_BUFFER_UNBOUNDED`
- 102 `COMPILE_FAIL` work-items; the live monitor flags a real EA-defect class
  `EA_INDICATOR_BUFFER_UNBOUNDED` (QM5_41109-41111) and `CANDIDATE_RECHECK_REFUSED` (QM5_9913)
  (`BACKTEST_MONITOR_2026-08-23.md`; 11 payloads carry the marker). The T6/T7/T9/DEV1
  MetaEditor-profile stdlib defect is already fixed (`2026-08-23_rb-compile-profiles.md`), so
  remaining compile failures are **true EA defects** requiring a Codex repair ticket, not infra.
  These never become backtest commands (planner keeps them `UNKNOWN`).

---

## 4 · Tranche 1 — exact `--apply` proposal (GELB item; needs OWNER go)

**Critical constraint discovered:** the frontier is **enqueue-blocked, not enqueue-ready.** Of
1,471 enqueue-eligible rows in the whole plan, **only 10 fall within the first 1,000 ranks** — the
frontier cohort mostly cannot be auto-enqueued because it is (a) held for Q07/Q08 regeneration
(B2), (b) `q09_news_prerequisite_in_flight` (already pending/active — must not be re-enqueued),
(c) `q09_news_manual_review_required` (REVIEW_REQUIRED → `UNKNOWN`, needs adjudication/7×4), or
(d) binding-incomplete (no bound build/setfile/window hashes). The 1,461 remaining eligible rows
are **deep-field Q03/Q02 fills** (ranks 1,546+).

`backfill_planner.py --apply` has **no row filter beyond `--max-rows N` + the active-symbol cap
(3)**; it walks the plan in frontier-first order and takes the first N enqueue-eligible rows.
Because the frontier eligibility runs out after 10 rows, tranche 1 must be **two explicit steps**:

### Tranche 1A — frontier probe (recommended first; ~7 factory hours)
```
python tools/strategy_farm/backfill_planner.py \
  --census-csv D:/QM/reports/rebaseline/census_2026-08-23.csv \
  --apply --i-understand-append-only --max-rows 10
```
This enqueues exactly the 10 frontier-most eligible rows (verified from the plan CSV):

| rank | EA | symbol | target | v4 | action | reason |
|---:|---|---|---|---|---|---|
| 14 | QM5_13036 | GDAXI.DWX | Q09 | Q10 News | RERUN_INFRA | invalid_evidence_at_q09_news |
| 16 | QM5_13301 | GDAXI.DWX | Q09 | Q10 News | RERUN_INFRA | invalid_evidence_at_q09_news |
| 17 | QM5_20048 | XTIUSD.DWX | Q09 | Q10 News | RERUN_INFRA | invalid_evidence_at_q09_news |
| 212 | QM5_13013 | NDX.DWX | Q07 | Q07 | RERUN_INFRA | non_economic_failure_at_prereq |
| 224 | QM5_20085 | XAUUSD.DWX | Q07 | Q07 | RERUN_INFRA | " |
| 225 | QM5_20085 | EURUSD.DWX | Q07 | Q07 | RERUN_INFRA | " |
| 227 | QM5_11294 | NDX.DWX | Q07 | Q07 | RERUN_INFRA | " |
| 245 | QM5_41039 | (XAU_XAG_MFLOWDIV_D1) | Q06 | Q06 | RERUN_INFRA | " |
| 246 | QM5_11881 | SP500.DWX | Q06 | Q06 | RERUN_INFRA | " |
| 366 | QM5_11403 | EURUSD.DWX | Q05 | Q05 | RERUN_INFRA | " |

**Why:** 3 of these directly attack the Q09 dam (B1) with the now-executable v3 runner; the other
7 advance Q05/Q06/Q07-frontier pairs one gate toward the Q08 baseline that feeds Q09. All are
append-only INFRA reruns (old rows preserved as evidence). GDAXI appears twice — within the
active-symbol cap of 3, safe. This tranche is cheap (~7 h) and its whole purpose is to **prove
the enqueue→run→verdict path works under the rebaseline and to get the first honest Q09 verdict.**

### Tranche 1B — base widening (only after 1A verdicts land; stays ≤300 rows)
```
python tools/strategy_farm/backfill_planner.py \
  --census-csv D:/QM/reports/rebaseline/census_2026-08-23.csv \
  --apply --i-understand-append-only --max-rows 200
```
`--max-rows 200` = the 10 frontier rows above **plus** ~190 deep Q03/Q04 fills (`FILL_MISSING`/
`RERUN_INFRA`), cumulative ≈ **1,050 factory hours** (eligible-cum 200 = 1,048.6 h). This does
**not** advance the 25 target directly; it refills the Q03→Q08 base so the frontier does not
starve once Q09/opt are proven. Hold it until 1A returns at least one Q09 verdict — spending
1,000 h to deepen the base before the dam is proven passable is the exact premature-scaling
mistake §0 warns against. A 300-row cap adds ~100 more Q03 fills (~1,606 h); I recommend 200.

### Monitoring checkpoints for tranche 1
1. **After enqueue:** confirm append-only — every new row is a fresh child; no terminal verdict
   overwritten (`git`-clean plan, `--append-only-rerun-of` present on every RERUN_INFRA).
2. **T+3 min loop:** `BACKTEST_MONITOR_2026-08-23.md` cadence — watch for `INFRA_FAIL` recurrence
   vs genuine EA defects; a re-INFRA on the 3 Q09 rerun rows means the Q07/Q08 vintage is still
   stale (B2) and the pair needs regeneration, not rerun.
3. **First Q09 verdict:** the decisive checkpoint. Outcomes: `CONFIG_LOCKED`/PASS (dam breakable —
   proceed to scale), `REVIEW_REQUIRED` + material effect (needs 7×4 expansion — heavier), or
   INFRA (B2 regeneration path). Record which in a follow-up evidence file.
4. **Symbol cap & active-lock:** confirm no pair with an in-flight row was re-enqueued
   (planner guards this, but verify against `agent_tasks`).
5. **Quota:** backtests are never throttled, but the Q07/Q08 **regeneration** rebuilds are Codex
   work — pace against the weekly limit (`quota_governor.py`).

---

## 5 · Realistic timeline (~10 terminals, phase medians)

The compute is not the constraint; the never-passed gates are. Phased plan:

**Phase A — De-risk the two dead gates (est. 3-7 days wall).**
- Run tranche 1A. Get the first honest **Q09 verdict** on ≥1 real pair. In parallel, commission
  the **opt fork** (Q10→Q14→Q15→Q16) on the 3 Q10-valid pairs — the first-ever production run of
  pattern/param-opt/head-to-head. Codex regenerates Q07/Q08 for ~5-10 of the 9 autoseal holds.
- **Exit criterion:** at least one pair traverses Q09→Q16 end-to-end (or a clear, documented
  reason it cannot). Until this, do not scale.

**Phase B — Push the near-terminal cohort (est. 1-2 weeks, gated on Phase A yield).**
- The 26 near-terminal pairs (23 at Q08 + 3 at Q10) each need only Q09+Q10+opt. With 10 terminals,
  Q09's 8-cell runs parallelize (~1 wave / 3 h wall per pair; ~200 cells ≈ 20-30 h wall batched).
  Q10/opt cost is measured in Phase A.
- **Yield risk dominates:** if Q09's economic pass rate is (say) ~40%, 26 Q08-valid pairs yield
  ~10 terminal candidates — **short of 25.** Then the base must supply more Q08-valid pairs.

**Phase C — Refill the base to cover attrition (parallel, weeks).**
- Advance the Q06/Q07 layer (33 pairs, ~7-58 h/gate median) and the Q03/Q04 deep field
  (303 pairs) via tranche 1B and successors, frontier-first, so the Q08 frontier does not starve.
  Q03 is the expensive layer (5.57 h/run × 277 pairs ≈ 1,544 h ≈ ~6-7 wall-days on 10 terminals).

**Bottom line.** *If* Q09 proves passable at a healthy rate and the opt fork works on first
commission, **25-through-terminal is a ~3-4 week effort.** *If* Q09's economic pass rate is low —
plausible, given 0 passes in all history — the binding constraint becomes the **supply of
Q08-valid strategies**, and 25 could take materially longer, requiring the Q03→Q08 base to be
driven much deeper. The next concrete decision is not "how many rows to backfill" but **"can any
strategy pass Q09?"** — which tranche 1A answers for ~7 factory hours.

---

## 6 · Decision queue (OWNER, ≤5)

1. **Tranche 1A go** (`--max-rows 10`, ~7 h, append-only frontier probe incl. 3 Q09 reruns).
   GELB — reversible; recommend go. *Auffangregel applies if no answer in 12 h.*
2. **9 autoseal holds → Q07/Q08 regeneration** (Codex rebuild wave), not manual release
   (B2; matches `OPEN_ITEMS_STATUS §0d` queue item 4).
3. **Commission the opt fork** on the 3 Q10-valid pairs as the first production Q14/Q15/Q16 run
   (new Q15 param-sweep = GELB new-lever: needs hypothesis + parameter count).
4. **Tranche 1B** (`--max-rows 200`, ~1,050 h base-widening) — hold until 1A returns a Q09 verdict.
5. **Census Q09_PORTFOLIO fix** (§1.1): teach `rebaseline_census.py` to exclude the informational
   portfolio lane from contiguity so the census stops reporting 21 phantom economic deaths — a
   Codex one-line-class ticket (GRÜN infra repair, verdict logic untouched).

## 7 · Deliverables

- This plan: `docs/ops/rebaseline/PATH_TO_25_CANDIDATES_2026-08-23.md`
- Top-80 per-gate CSV: `D:/QM/reports/rebaseline/path_to_25_top80.csv`
- Recompute (read-only): `python tools/strategy_farm/rebaseline_census.py` then
  `python tools/strategy_farm/backfill_planner.py` (dry-run) regenerate the two input CSVs; this
  document's ranking is a read-only re-sort of `backfill_plan_2026-08-23.csv` over the corrected
  (Q09_PORTFOLIO-aware) frontier.
