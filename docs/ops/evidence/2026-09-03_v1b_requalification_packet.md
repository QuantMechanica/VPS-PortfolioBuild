# V1(b) requalification packet — the 5 Q09-anchored cohort members

- Kind: **evidence-only preparation packet.** It mints no queue row, no verdict, no hold, no
  supersede. It PREPARES the exact CEO commands for OWNER-DEC-Q12-ADMISSION Vorlage **V1(b)**
  (dossier `docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md` §5) so that
  at the Auffangregel deadline **2026-09-03 19:35Z** the CEO can execute (or defer) with full
  knowledge of what is actually runnable.
- Vorlage V1(b): *push the 5 Q09-anchored members first (they reuse a hash-bound Q08 and are the
  cheapest distance to Q14).*
- Admission source of the 5: `docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.md`
  (+ `.json` sidecar SHA-256 `42b0b680dd0680240a5e4e4eea8704ce75b053889906ff1f018f332440156b32`).
- DB: `D:\QM\strategy_farm\state\farm_state.sqlite`. **Read-only proof:** opened
  `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`; `PRAGMA query_only=1`;
  `PRAGMA quick_check=ok`. **Live snapshot marker** (max `work_items.updated_at`):
  `2026-09-03T15:14:49Z`. No queue/verdict/hold/supersede/work_item/portfolio state was written.
- Governed-tool reality resolved from `tools/strategy_farm/farmctl.py`,
  `phase_ids.py`, `rebaseline_census.py` in the merged worktree (HEAD after
  `git merge --ff-only agents/board-advisor` → `c55edd431c`).

---

## 0 · Bottom line for the CEO (read this first)

**V1(b) as literally worded — "push the 5 and they climb to Q14" — is NOT executable end-to-end
with the four governed forms today.** The live chain has moved well past the static 08-30 "Q09"
anchor, and the current census frontier of each member reveals that 4 of 5 are pinned behind two
infrastructure holds that are **not** among the four governed forms in scope:

| # | member | TF | current census frontier | next phase | governed action available now? | blocking hold (active) |
|---|---|---|---|---|---|---|
| 1 | QM5_1556 / XAUUSD | D1 | **Q10 (NEWS)** | Q10_NEWS | **No** | `Q09_AWAITING_SEALED_PLAN` on 2 pending Q10_NEWS rows |
| 2 | QM5_10403 / XAUUSD | D1 | **Q12 (opt-fork)** | Q12 | **No** | `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` on pending Q12 |
| 3 | QM5_10911 / GDAXI | H1 | **Q05 (INFRA_FAIL)** | Q05 | **YES — 1 enqueue-backtest** | (then lands on the Q12 hold) |
| 4 | QM5_11708 / EURUSD | D1 | **Q12 (opt-fork)** | Q12 | **No** | `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` on pending Q12 |
| 5 | QM5_12969 / USDJPY | M30 | **Q10 (NEWS)** | Q10_NEWS | partial (creates a *held* row only) | last Q10_NEWS = `REVIEW_REQUIRED`; NEWS gate needs sealed plan |

**The only fully governed, self-contained action available under the four forms is member #3
(QM5_10911/GDAXI): an append-only Q05 rerun of the INFRA_FAIL row.** Even that only advances
10911's contiguous census gate from Q04 → Q11; it then meets the same Q12 opt-fork hold as
#2/#4. **No member reaches Q14 through any action in this packet; the 25-counter stays at 5/25**
(matches the admission record and dossier: net cohort contribution today = 0).

The two real levers to unblock V1(b) are **outside** the four governed forms:
1. **NEWS-gate sealed run plan** (`farmctl bind-q09-plan`) — unblocks #1 and #5.
2. **Governed worker restart that loads the DL-089 matrix routing guard** (the Q12 holds carry
   `release_on_restart=1`) — unblocks #2, #4, and #3-after-Q05.

Both are separate CEO/OWNER decisions (worker restart touches the factory; the NEWS sealed plan
is the known 19–36-day / near-zero-service-rate bottleneck).

---

## 1 · The 5 members — exact identity (from the admission sidecar)

Composite candidate key = `(ea_id, symbol, q11_work_item_id)`. All 5 are the `current_anchor_2026_09_03 = Q09` members of the audited-16 set (admission sidecar members #1, #3, #9, #17, #24).

| # | ea_id | symbol | TF | class | anchor Q08 row (verdict/vclass, contract) | Q11/portfolio row (q11_work_item_id) | edge slug |
|---|---|---|---|---|---|---|---|
| 1 | QM5_1556 | XAUUSD.DWX | D1 | Q09 | `ea0cd059-07f1-47c0-ab19-42d97f49fa04` FAIL_SOFT/PASS, v4 | `e241bacd-5681-4172-a785-a475fd25140b` | aa-zak-mom12 |
| 2 | QM5_10403 | XAUUSD.DWX | D1 | Q09 | `7fd4caf6-b599-4833-a431-a132a404b60b` FAIL_SOFT/PASS, v4 | `e12845b9-04fe-4d97-af43-93d37268f2f4` | et-turtle20x |
| 3 | QM5_10911 | GDAXI.DWX | H1 | Q09 | `55256268-50f8-4d94-8d9a-83652c64b013` FAIL_SOFT/PASS, v4 | `545758f3-e272-447c-985b-6976fe06c6ac` | grimes-complex-pb |
| 4 | QM5_11708 | EURUSD.DWX | D1 | Q09 | `861577c0-2a5b-42a2-9a6a-2ea9cfb9caf5` FAIL_SOFT/PASS, v4 | `790edb77-fe2d-4ba8-8127-0c8e5cfb5d33` | anon-market-squeeze-d1 |
| 5 | QM5_12969 | USDJPY.DWX | M30 | Q09 | `f14ad921-721e-413d-a2de-6506ceaf8483` FAIL_SOFT/PASS, v4 | `de65a075-6bd9-49c9-a775-624a32fc4214` | usdjpy-gotobi-nakane |

`FAIL_SOFT` at Q08 is a PASS-class outcome for contiguity (OWNER receipt 2026-09-02 / DL082-EXT
Option D; `rebaseline_census.GATE_SCOPED_PASS = {"Q08": {"FAIL_SOFT"}}`), which is exactly why
these 5 anchor at Q09 (the hash-bound Q08 is reusable).

---

## 2 · Binding re-verification — none re-enters at Q02

Current-repo EX5 SHA-256 recomputed in the canonical checkout `C:\QM\repo` against the value bound
on the admission DB rows. **All 5 still MATCH** in the merged tree → all 5 stay Q09-anchored; **none
re-enters at Q02 on a new identity.** (If any had drifted, the fallback would have been
`farmctl seed-fresh-q02` — it is **not** invoked for any of the 5; see §6.)

| # | member | current repo EX5 SHA-256 | DB-bound (admission) | verdict |
|---|---|---|---|---|
| 1 | QM5_1556/XAUUSD | `0962ca65776fd05e76f7ab5f27e838a72cb79a7359a029e2f47ef61a9ae7c88e` | `0962ca65…7c88e` | **MATCH** |
| 2 | QM5_10403/XAUUSD | `f927f07f46579bbb9a1bdcfdb7caa9b246e9d7555935fbb878f7fc01afbf7ab3` | `f927f07f4657…` | **MATCH** |
| 3 | QM5_10911/GDAXI | `5199e260020b8ada81437401338e641e4f778579e58af147f2bace1c7ef9dce1` | `5199e260020b…` | **MATCH** |
| 4 | QM5_11708/EURUSD | `baff181fe3c9b5abf404231603f8117f4d2cf9d792c69de7014732a3b6e96d25` | `baff181fe3c9…` | **MATCH** |
| 5 | QM5_12969/USDJPY | `938a35aa6b6dff54ec0e94a4a253a71730e63f9347b91877da786ec395715f06` | `938a35aa6b6d…` | **MATCH** |

Setfiles for all 5 exist on disk (paths in the admission sidecar `setfile_path`).

---

## 3 · Current live chain state per member (census-authoritative)

"Frontier" = `rebaseline_census.summarise_pair` **earliest missing prerequisite** = the first gate
on the census chain `Q02…Q08→Q09→Q10(NEWS)→Q11→Q12→Q13→Q14` that lacks a `done`+PASS-class row.
`HCVG` = highest contiguous valid gate. The census maps the NEWS storage phase `Q10_NEWS`→gate
`Q10`, legacy incumbent `Q10`→gate `Q11`, and the terminal requalification gate is `Q14`.
`Q10_NEWS` success verdict = `CONFIG_LOCKED`.

### 3.1 — QM5_1556 / XAUUSD (D1) — frontier **Q10 (NEWS)**, HCVG Q09
- Q02–Q09 valid on current binary (Q09 v4 done PASS `b9ae4345…`, `7a686cb4…`).
- Gate Q10 (NEWS) has **no `CONFIG_LOCKED`**: only legacy Q09_NEWS INFRA_FAIL (`a122a2e9`, `8419449d`),
  Q09_NEWS `REVIEW_REQUIRED` (`9d3506f1`, `08be2fce`), and **two pending Q10_NEWS rows**
  `d81d9ea8-b802-4c38-8fc9-8bdbab6ef75c` and `72992810-aaf1-4fa8-9c12-c778bda0ae87` (both created
  2026-09-03T15:05Z) — **both carry an ACTIVE `Q09_AWAITING_SEALED_PLAN` hold** ("Q09_NEWS is not
  claimable until a sealed run plan is hash-bound"). The legacy `Q10` PASS row (`6cd290c6`) remaps
  to gate Q11 and does not satisfy Q10(NEWS).
- **Next phase:** Q10_NEWS. **Not advanceable by the four forms** (needs `bind-q09-plan`).
- **Anomaly:** the two 15:05Z pending Q10_NEWS rows are a duplicate autoseal (same phase, same
  setfile, 5 s apart). Flag for the news lane; see §6 for why a supersede is *out of scope* here.

### 3.2 — QM5_10403 / XAUUSD (D1) — frontier **Q12 (opt-fork)**, HCVG Q11
- Q10_NEWS `CONFIG_LOCKED` (`40ff1e14…`, done 2026-08-30) and Q11 PASS (`c0f80418…`) are both valid
  on the current binary → contiguity clears the strategy chain.
- Gate Q12 has one pending opt-fork row `559ec02f-af4e-5237-8467-df1683dcb8e8` under an **ACTIVE
  `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` hold** (`release_on_restart=1`).
- **Next phase:** Q12 (pattern-filter WF program). **Not advanceable by the four forms** — Q12 is
  not a cascade backtest phase, and the pending row is held pending the DL-089 worker rollout.

### 3.3 — QM5_10911 / GDAXI (H1) — frontier **Q05 (INFRA_FAIL)**, HCVG Q04  ← the one governed case
- **Discrepancy vs the static 08-30 "Q09" anchor:** although Q08 is hash-bound reusable and
  Q09/Q10_NEWS(`CONFIG_LOCKED` `b3957bc9`)/Q11(`5b48d44d`) are all valid, the contiguous census
  chain **breaks far below, at Q05** — both Q05 rows are INFRA_FAIL (`17622470` done INFRA_FAIL
  2026-07-03; `f4ac4d5c` failed INFRA_FAIL 2026-08-02), no PASS. So HCVG = Q04, frontier = Q05.
- Q06–Q11 already carry valid rows, so a single valid **Q05 PASS advances HCVG Q04 → Q11** (the
  census counts any PASS row per gate; it does not require single-binary continuity below the
  frontier). 10911 then meets the **same Q12 opt-fork hold** (pending Q12 `96239586…`, held).
- Legacy Q14 `OPT_ELIGIBLE` rows (`b2daa1b1`, `99d58e96`, 2026-08-13) are `OTHER`-class, not a
  terminal requalification verdict — they do **not** count toward Q14.
- **Next phase:** Q05 — **advanceable by `enqueue-backtest` (append-only rerun).** Predecessor =
  Q04 done PASS `538405f6-3e5e-4072-9c04-336fa3164fae` (canonical GDAXI H1 backtest.set). Newest
  Q05 terminal target = `f4ac4d5c-2034-4083-b50d-7fd2af518917` (same setfile, terminal, unclaimed →
  valid append-only target). Command in §4.

### 3.4 — QM5_11708 / EURUSD (D1) — frontier **Q12 (opt-fork)**, HCVG Q11
- Cleanest tail: Q10_NEWS `CONFIG_LOCKED` (`afbcaf57…`, 2026-09-03T01:03Z) and Q11 PASS
  (`83ea8b70…`, 2026-09-03T01:20Z) both current-binary valid.
- Gate Q12 has one pending opt-fork row `9102ff97-a450-5cd3-8e13-0f61144ffa5d` under an **ACTIVE
  `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` hold** (`release_on_restart=1`).
- **Next phase:** Q12. **Not advanceable by the four forms** (same as 10403).

### 3.5 — QM5_12969 / USDJPY (M30) — frontier **Q10 (NEWS)**, HCVG Q09
- Q02–Q09 valid (Q09 v4 done PASS `c38e2fbf…`). Gate Q10(NEWS) has **no `CONFIG_LOCKED`**: newest
  Q10_NEWS terminal is `b87b967f-7bee-4e8b-8551-99f1fda068f1` **done `REVIEW_REQUIRED`** (INVALID
  class, 2026-08-27) plus a `SUPERSEDED` row (`5b3d7bb3`); the only pending row is Q09_NEWS
  `acb3592c…`. Legacy `Q10` PASS (`1c4ceb5b`) remaps to Q11.
- **Next phase:** Q10_NEWS (re-adjudication to `CONFIG_LOCKED`). A governed `enqueue-backtest
  --phase Q10_NEWS` *will create a row* but that row is auto-stamped with
  `Q09_AWAITING_SEALED_PLAN` (`farmctl.py:_mark_q09_awaiting_sealed_plan`, line 27330) — it is
  **inert until `bind-q09-plan`** supplies a sealed run plan. So this is at best a partial action.

---

## 4 · Exact CEO commands (governed forms only, in order)

All commands run from the canonical repo (`cd C:/QM/repo`), never a worktree
(`feedback_farmctl_run_from_canonical_repo`). Reason strings are pre-filled per the V1(b)
Auffangregel template. Prepare-only — the CEO runs them.

### 4.1 — QM5_10911 / GDAXI  ▶ THE ONE RUNNABLE GOVERNED COMMAND
```
cd C:/QM/repo
python tools/strategy_farm/farmctl.py enqueue-backtest \
  --ea QM5_10911 --phase Q05 \
  --from-work-item-id 538405f6-3e5e-4072-9c04-336fa3164fae \
  --append-only-rerun-of f4ac4d5c-2034-4083-b50d-7fd2af518917 \
  --expected-current-ex5-sha256 5199e260020b8ada81437401338e641e4f778579e58af147f2bace1c7ef9dce1 \
  --rerun-reason "OWNER-DEC-Q12-ADMISSION V1(b) Auffangregel 2026-09-03 19:35Z: requalify Q09-anchored 10911/GDAXI; census frontier is Q05 INFRA_FAIL (f4ac4d5c) on current binary 5199e260; append-only rerun preserves the terminal INFRA row; Q06-Q11 already valid so a Q05 PASS lifts HCVG Q04->Q11."
```
- Expected success: creates one new `pending` Q05 row (append-only; `f4ac4d5c` preserved).
- Possible governed refusals to expect (each is self-explaining JSON): `cache_history_below_required_oos_window`
  (Q05 OOS window not yet in cache — cold-cache transient, self-heals on retry; do **not** re-import
  .DWX history); `append_only_rerun_target_mismatch_or_not_terminal` (only if `f4ac4d5c` gets claimed
  meanwhile); a binding refusal if the current repo EX5/setfile no longer matches `5199e260…`.
- **After Q05 PASS:** 10911's frontier becomes **Q12** → it joins the Q12 opt-fork hold cohort
  (§4.4). No further governed backtest step advances it.

### 4.2 — QM5_1556 / XAUUSD  ▶ NO GOVERNED COMMAND APPLIES
- Frontier is Q10_NEWS with **two pending rows already present and held**. There is **no terminal
  Q10_NEWS row** to cite as `--append-only-rerun-of`, and a plain enqueue would return
  `already_pending_or_active` (open pending row `72992810`/`d81d9ea8`, same setfile). So no
  enqueue-backtest form is constructible.
- **Out-of-scope unblock (CEO/news lane):** hash-bind a sealed run plan to the pending row, e.g.
  `python tools/strategy_farm/farmctl.py bind-q09-plan --work-item-id 72992810-aaf1-4fa8-9c12-c778bda0ae87 --plan <sealed_plan.json> --plan-file-sha256 <sha> [--dry-run]`.
  **Not one of the four forms — flagged, not prepared for execution.**

### 4.3 — QM5_12969 / USDJPY  ▶ ENQUEUE CREATES A HELD ROW ONLY (partial)
```
cd C:/QM/repo
python tools/strategy_farm/farmctl.py enqueue-backtest \
  --ea QM5_12969 --phase Q10_NEWS \
  --from-work-item-id c38e2fbf-8fbb-4c79-b66a-b51cbe4378af \
  --append-only-rerun-of b87b967f-7bee-4e8b-8551-99f1fda068f1 \
  --expected-current-ex5-sha256 938a35aa6b6dff54ec0e94a4a253a71730e63f9347b91877da786ec395715f06 \
  --rerun-reason "OWNER-DEC-Q12-ADMISSION V1(b) Auffangregel 2026-09-03 19:35Z: re-adjudicate Q09-anchored 12969/USDJPY NEWS gate; last Q10_NEWS (b87b967f) is REVIEW_REQUIRED not CONFIG_LOCKED; append-only rerun preserves it, binary 938a35aa."
```
- Expected: creates one `pending` Q10_NEWS row **auto-stamped `Q09_AWAITING_SEALED_PLAN`** → inert
  until a sealed plan binds (`bind-q09-plan`, out of scope). So run this **only if** the CEO also
  intends to drive the NEWS sealed-plan lane; otherwise it just parks another held row.

### 4.4 — QM5_10403 & QM5_11708 (and 10911 after §4.1)  ▶ NO GOVERNED COMMAND APPLIES
- Frontier is **Q12** (opt-fork). `enqueue-backtest --phase Q12` returns
  `"Phase Q12 is not a cascade phase. Supported cascade phases: (Q04…Q11,…)"` — Q12/Q13/Q14 are the
  optimization branch, not backtest cascade phases.
- The pending Q12 rows already exist and are **held** (`Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING`,
  `release_on_restart=1`): `559ec02f` (10403), `9102ff97` (11708), `96239586` (10911).
- **Out-of-scope unblock (CEO):** a governed worker restart that loads the DL-089 matrix routing
  guard clears these holds on restart and lets the pattern-WF program (the "measurement sibling")
  claim them. **Not one of the four forms — flagged, not prepared.**

### 4.5 — Optional governed queue-order lever (`mark-priority-track`, GRÜN)
Valid but **conditional**: `mark-priority-track` only sets `payload.priority_track=true` on a
PENDING row (queue order; never status/verdict). It does **not** override an active hold, so it only
takes effect once the corresponding hold clears. Prepared for the Q12 rows if the CEO restarts the
DL-089 worker (so these three are serviced first when they become claimable):
```
python tools/strategy_farm/farmctl.py mark-priority-track --work-item-id 559ec02f-af4e-5237-8467-df1683dcb8e8 --reason "OWNER-DEC-Q12-ADMISSION V1(b): prioritise 10403/XAU Q12 opt-fork once DL-089 hold releases"
python tools/strategy_farm/farmctl.py mark-priority-track --work-item-id 9102ff97-a450-5cd3-8e13-0f61144ffa5d --reason "OWNER-DEC-Q12-ADMISSION V1(b): prioritise 11708/EUR Q12 opt-fork once DL-089 hold releases"
python tools/strategy_farm/farmctl.py mark-priority-track --work-item-id 96239586-47c0-5fe2-8ef5-3d29910cc47c --reason "OWNER-DEC-Q12-ADMISSION V1(b): prioritise 10911/GDAXI Q12 opt-fork once DL-089 hold releases"
```

---

## 5 · Expected cost and 25-counter contribution

Grounded in `docs/ops/Q09_PILOT_COST.md`, `Q09_AUTOPILOT_CELL_TIMEOUT_SEC=10800` (3 h/cell),
dispatch `timeout_hours=6.0` per ordinary phase, and the 2026-08-17 NEWS-closure evidence.

| gate class | mechanism | tester cost | operative constraint |
|---|---|---|---|
| ordinary full-history backtest (Q05/Q06/Q07/Q09/Q11) | `enqueue-backtest` cascade | ≤ ~6 tester-h budget/run; D1 minutes-scale, H1/M30 heavier | none material (backtests are never throttled) |
| **Q10_NEWS (NEWS gate)** | news-gate service + sealed plan | 40 cells (DXZ/RESEARCH) or **145 cells (FTMO)** × up to 3 h/cell | **19–36 CALENDAR days**, near-zero service rate — the dominant cost; needs `bind-q09-plan` |
| Q12→Q13→Q14 (opt-fork) | DL-089 pattern-WF matrix + param opt + head-to-head | multi-cell census (~40 cells, pilot order) per member | currently **held** (`Q12_DL089…`), releases on governed worker restart |

Per member, remaining path to Q14 = **{Q10_NEWS, Q11, Q12(program + measurement sibling), Q13, Q14}**:

- **1556/XAU:** needs Q10_NEWS → Q11 → Q12 → Q13 → Q14. **No current measurement sibling.** Cost is
  dominated by the NEWS gate (19–36 days) then a full opt-fork. Adds to counter: **not until Q14.**
- **10403/XAU:** has Q10_NEWS+Q11; needs Q12 → Q13 → Q14. **No current measurement sibling.** Cost =
  one opt-fork (held). Adds to counter: **not until Q14.**
- **10911/GDAXI:** needs Q05 (one governed backtest, cheap) → then Q12 → Q13 → Q14. Carries a
  **legacy Q14 OPT_ELIGIBLE opt_card** (`opt_track/OPT-10911-GDAXI-VOL-REGIME-FILTER-…`, 2026-08-13)
  but that is not a current v4 measurement sibling. Adds to counter: **not until Q14.**
- **11708/EUR:** has Q10_NEWS+Q11; needs Q12 → Q13 → Q14. **No current measurement sibling.** Cost =
  one opt-fork (held). Adds to counter: **not until Q14.**
- **12969/USDJPY:** needs Q10_NEWS(→CONFIG_LOCKED) → Q11 → Q12 → Q13 → Q14. **No current
  measurement sibling.** Cost dominated by the NEWS gate. Adds to counter: **not until Q14.**

**Counter today:** `book_build_guard qualified_pairs = 5/25`, `allowed=false` (dossier §2 /
admission §"Counter state", re-verified this session; the 5 qualified are `10706/GBP`, `11421/EUR`,
`11422/USDCAD`, `13054/XTI`, `1537/XAG` — **none of the V1(b) five**). Executing everything in this
packet moves **0** members to Q14 today, so the counter stays **5/25**. V1(b)'s value is to *start*
the tail, not to add a qualified pair this session.

---

## 6 · Blockers and the exact refusal to expect

| member | blocker | exact refusal / gate |
|---|---|---|
| 1556/XAU | NEWS gate held; duplicate pending Q10_NEWS; no terminal Q10_NEWS to rerun | plain enqueue → `already_pending_or_active` (`72992810`); no `--append-only-rerun-of` target exists; hold `Q09_AWAITING_SEALED_PLAN` (active) |
| 10403/XAU | Q12 is opt-fork, not a cascade phase; pending Q12 held | `enqueue-backtest --phase Q12` → `"Phase Q12 is not a cascade phase…"`; hold `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` (active) |
| 10911/GDAXI | none for the Q05 step; Q12 held afterward | Q05 command runnable (§4.1); watch for `cache_history_below_required_oos_window` (cold-cache, self-heals) |
| 11708/EUR | Q12 opt-fork; pending Q12 held | same as 10403 |
| 12969/USDJPY | NEWS gate: enqueue creates a row auto-held for a sealed plan | new Q10_NEWS row stamped `Q09_AWAITING_SEALED_PLAN`; inert without `bind-q09-plan` |

**Not blockers (verified):** no member has a missing setfile (all 5 setfiles exist); no member's
rows are superseded (`work_item_supersedes` empty for all 183 rows across the 5); no universe/
tradability mismatch for the enqueues (10911 GDAXI.DWX `canonical_name_verified`; the Q05 rerun uses
the canonical H1 backtest.set). Purged evidence is not on any of these frontier paths.

**`seed-fresh-q02`:** **not applicable to any of the 5** — every EX5 MATCHes the DB-bound value
(§2), so none is a pre-execution-binding source needing a fresh Q02 seed.

**`work_item_supersedes.py record`:** **not applicable within the stated scope.** The task authorizes
it "only for unclaimable stale-identity pending rows." The only duplicate is 1556's pair of pending
Q10_NEWS rows (`d81d9ea8`, `72992810`) — but both are **current-identity (v4)**, not stale-identity,
so superseding one would be outside the authorized use. It is flagged here for the CEO/news lane as a
duplicate-autoseal anomaly, **not** prepared as a command.

---

## 7 · Provenance & mutation statement

- **Inputs:** `docs/ops/evidence/2026-09-03_q12-admission_39b77657_execution.{md,json}` (the 5 member
  identities, Q08 anchors, portfolio rows, DB-bound hashes); `docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md` §5 (V1(b));
  `docs/ops/Q09_PILOT_COST.md` (NEWS-gate cost).
- **Tooling read (behaviour, not mutated):** `tools/strategy_farm/farmctl.py`
  (`enqueue_cascade_backtest_for_ea`, the append-only guards `append_only_rerun_already_exists` /
  `already_pending_or_active` / `append_only_rerun_target_mismatch_or_not_terminal`, the NEWS
  read-only guard, `_mark_q09_awaiting_sealed_plan`, `mark-priority-track`, `seed-fresh-q02`),
  `phase_ids.py` (advancement table; cascade tops out at Q11=INCUMBENT),
  `rebaseline_census.py` (frontier / HCVG).
- **DB:** `D:\QM\strategy_farm\state\farm_state.sqlite`, opened `mode=ro`, `PRAGMA query_only=1`,
  `quick_check=ok`; live snapshot marker `2026-09-03T15:14:49Z`. EX5 SHA-256 recomputed from
  `C:\QM\repo` working copy.
- **Mutation statement:** this packet created/changed **no** queue row, verdict, hold, supersede,
  work_item, portfolio_candidate, gate threshold, trade stream, or T_Live/live state. It only READ
  the live DB and repo and WROTE this file under `docs/ops/evidence/`. Every command in §4 is
  **prepared for the CEO to run**, not executed here. Accompanies `docs/ops/OPEN_ITEMS_STATUS.md`
  per the Stehende Vollmacht.


## CEO verification notes (2026-09-03 15:40Z, workflow wf_f51ea7e6-bee)

Adversarial verifier: packet stands on every decision-bearing claim. Two
corrections for the record:

- Section 3.1 "anomaly": QM5_1556's two pending Q10_NEWS rows d81d9ea8 and
  72992810 were created 2026-08-23T16:25Z and 2026-08-30T07:25Z (a week apart),
  not 5 s apart at 15:05Z; the seconds-apart event was an updated_at re-touch
  by the 15:20Z autoseal wave after the packet snapshot. No command changes.
- The Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING hold does NOT gate the census
  service: 28 of 30 pending Q12 rows carry it (live query 15:33Z), including
  QM5_21507/XAUUSD whose program is 546/1085 cells into its census. The K=8
  program slots, not the hold, decide when 10403/11708/10911 enter the census.
  "Needs a governed worker restart" is therefore not a precondition.
- QM5_12969 label: directory is the "-fix" variant; hash and sidecar path are
  correct.
