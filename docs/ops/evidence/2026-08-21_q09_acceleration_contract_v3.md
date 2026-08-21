# Q09_NEWS contract v3 (Weg A+B) — implementation HELD on live file collision

**Date:** 2026-08-21
**Branch:** `agents/board-advisor` · HEAD `b4fee34e8`
**Author:** Claude (board-advisor lane)
**Authorization:** GELB pre-approved exception — "Q09 acceleration Weg A+B (approved —
contract v3 in progress)" (`CLAUDE.md` › Ratified Rules). Scope is *how* Q09_NEWS
evidence is generated (cheaper), never *what* the gate decides.

---

## 0 · Status — STOPPED before writing code, by design

**No code was written and nothing was committed except this evidence doc.** Mid-task I
found that **two of the three files the task named as collision-stop triggers are being
edited live by other lanes in this shared checkout, in the exact functions v3 would
branch.** The task's standing instruction for that case is explicit:

> "if you find evidence mid-task that another lane is already editing
> `q09_news_contract.py`, `q09_news_runner.py`, or `farmctl.py`'s Q09-related sections,
> stop, do not fight over the file, and report the collision instead of forcing a merge."

So I stopped touching those files and instead used the session to (a) prove the collision
with hard evidence, (b) confirm the v3 design against the sealed contract, (c) locate and
verify the validation data on disk, and (d) write the full design + wiring spec below so
the serialized follow-up is fast and low-risk. This is a deliberate correct-partial
outcome, not an abandonment.

---

## 1 · The collision — evidence

Working-tree (uncommitted) modifications present at session start, all in the strategy_farm
tree, `git rev-parse --short HEAD = b4fee34e8`:

| File | mtime (UTC) | Δ | Owning lane / nature |
|---|---|---|---|
| `tools/strategy_farm/q09_news_runner.py` | 2026-08-21 18:10:16 | +111 / −5 | Q09-runner lane: failure-snapshot layout V1→V2 (`.log`→`.evidence` to survive `reports_log_purge.ps1`) **plus transient-reason retry routing inside `_production_dispatch_cell`** |
| `tools/strategy_farm/farmctl.py` | 2026-08-21 18:11:33 | +764 / −714 (56/−6 ignoring whitespace) | Task `5343f90a`: defect-block exclusion in `pump`/`_pump_unlocked`, **plus a whole-file CRLF renormalization** |
| `tools/strategy_farm/tests/test_q09_news_runner_v2.py` | 2026-08-21 18:11:45 | +202 / −0 | Q09-runner lane tests |
| `tools/strategy_farm/work_item_clean_view.py` | 2026-08-21 18:10:10 | — | Task `5343f90a` (`defect_block_predicate_sql`) |

Session wall-clock at discovery: **18:14:37 UTC** — the farmctl.py and test edits were
**< 3 minutes old** and `ListAgents` showed live peer sessions (`repo-0e` busy,
`claude-orchestration-3-ea`, `repo-4d`). This is active concurrent editing, not stale
leftovers. A Q09-runner commit also landed just before this window: `fa49b2c84`
"fix(q09-runner): continue-on-cell-failure + bounded per-cell retry (K=2)".

**Why this is a hard stop, not a mergeable overlap — the two v3 edit surfaces sit inside
the two functions being rewritten right now:**

1. **Runner branch point.** v3's "synthesize `full` from `selection`+`holdout` instead of
   a third tester pass" branches in `_production_dispatch_cell`
   (`q09_news_runner.py:2500`; the per-window loop the task cited at ~2500–2520/2569). The
   other lane just inserted transient-retry routing at `q09_news_runner.py:2586`
   (`_fail_summary_is_transient(summary_path)`) inside that same function. Two lanes
   restructuring the same dispatch function's control flow = guaranteed logical conflict.

2. **Pump wiring point.** The auto sealed-plan caller belongs exactly where the pump
   already marks a row awaiting a plan: `_mark_q09_awaiting_sealed_plan(...)` at
   `farmctl.py:17057`, inside `_pump_unlocked` (`farmctl.py:15495`). Task `5343f90a` is
   rewriting `_pump_unlocked`'s signature and query bodies right now. On top of that, that
   lane's edit **renormalized CRLF across the entire 24k-line farmctl.py** — so *any*
   textual edit I add would collide or, if committed, would sweep up their whole-file
   line-ending change. Forcing this is precisely the merge the instruction forbids.

`q09_news_contract.py` — the third named file and the true crux for Weg B (seed) and the
v3 schema/adjudicator branch — **is clean** (unmodified since 2026-07-29 19:09). The core
contract is free; only the two integration files are contended, and a v3 that can't be
integrated end-to-end (both integration files locked) is untestable, so proceeding on the
contract module alone would be a dead-ended partial.

---

## 2 · Design confirmed against the sealed contract (read-only)

### 2.1 Weg B forces a schema/adjudicator branch — it cannot be a quiet single-seed swap

`adjudicate()` in `q09_news_contract.py` (`SCHEMA_VERSION = "q09-news-evidence/v2"`)
**hard-requires all five canonical seeds** `SEEDS = (42, 17, 99, 7, 2026)`:

- `q09_news_contract.py:342` — `if len(cells) != len(SEEDS) or {cell.seed for cell in cells} != set(SEEDS): raise`
- iterates `for seed in SEEDS` at lines 608, 618, 655, and emits `seed_set`,
  `setfile_sha256_by_seed`, `evidence_sha256_by_seed` keyed on all five (lines 689–691).

Therefore a v3 that runs only canonical seed **17** must go through the task-sanctioned
mechanism: **version-gate a `q09-news-evidence/v3` schema that a v3-aware adjudicator
accepts, producing verdicts through the identical `CANONICAL_VERDICTS` /
7-temporal × 4-compliance material-effect logic.** The v3 adjudicator branch is well
justified because seeds are inert: `CLAUDE.md` — "Q09_NEWS seeds are inert (RNG never
drawn when `qm_stress_reject_probability=0`): 40 cells = 8 configs." Seed 17 is the
canonical reference seed (steady-state cell `control_off__m0__c0__s17`, §1 of
`Q09_ACCELERATION.md`, and the seed underlying reference pilot `cba63d44`).

**Verdict-identity strategy (unchanged decision logic):** the cleanest mechanism is for
the v3 adjudicator to accept the single-seed cell set and **fan seed 17's evidence into
the five seed slots the v2 adjudicator math already consumes** (legitimate because the
five are byte-identical when RNG is never drawn). Then `_score_candidate`, the material-
effect escalation, and `CANONICAL_VERDICTS` selection run **unchanged** — the only new
code is the intake/validation gate, not the decision. This makes the required
verdict-identity test trivially true by construction *and* gives an explicit assertion
target (feed the same underlying trades through v2's 5-seed path and v3's 1-seed-fanned
path → assert identical verdict + identical `adjudication` block modulo the seed-provenance
metadata).

### 2.2 Weg A — the seam-reconstruction formula (from `Q09_ACCELERATION.md` §7.2, verified)

Windows: `selection` 2019-01-01…2023-12-31, `holdout` 2024-01-01…2025-12-31,
`full` = `selection ∪ holdout`, gapless seam at 2023-12-31/2024-01-01
(`WINDOW_NAMES` at `q09_news_runner.py:131`).

Reconstruction of `full` from the two half-window `raw/run_01/logger_sample.jsonl` streams
(daily `EQUITY_SNAPSHOT` events + full order lifecycle):

```
offset            = equity_end(selection) − equity_start(holdout)
equity_full(t)    = equity_selection(t)                     for t in selection
                  = equity_holdout(t) + offset              for t in holdout
net_profit_full   = net_profit(selection) + net_profit(holdout)      # additive
max_drawdown_full = max_drawdown over the concatenated equity_full series
```

Under fixed risk sizing (`RISK_FIXED` in backtest) the offset is a pure additive shift, so
peak/trough geometry across the seam is preserved.

**Measured residual (§7.2, two `CONTROL_OFF` cells of the same EA):**
- **max-drawdown: 17 072.73 vs 17 072.73 → 0.00 (0.000 %) — exact.**
- net profit: 11 410.77 concatenated vs 11 344.55 real full → 66.22 (**0.584 %**), from
  one position open across the year boundary (synthetically closed at the splice, reopened
  in `holdout`).

**§7.3 mandate honored in the design:** the v3 payload must **record the seam residual**,
not ignore it. Concrete v3 payload additions:
- `seam_reconstructed: true` (mandatory marker on every synthesized-`full` metric block).
- `seam_net_profit_error_abs` / `seam_net_profit_error_pct` when a per-EA reference full
  run exists to measure it (the delta is determinable exactly once per EA, §7.3); else
  `seam_net_profit_error_bound_pct` carrying the pilot-measured 0.58 % as a documented
  upper-bound proxy with `seam_error_source: "pilot_46409fc4_carry_forward"`.
- `full_window_synthesized: true` + provenance pointing at the two source window run dirs.

**Why the verdict is unaffected by the seam residual:** the residual hits net profit only,
is ~0.58 % on a two-decimal ratio comparison, and — decisively — Q09 compares the *same
EA with vs without* the news filter, so the seam error applies to both arms and cancels in
the material-effect delta the adjudicator scores.

---

## 3 · Validation data exists on disk — the comparison is reproducible NOW (no new pilot)

Confirmed a fully-populated per-window cell on disk (read-only):

```
D:\QM\reports\work_items\e323c2f7-6b8a-466f-9291-73dccfbe181a\q09_plan\cells\
    control_off__m0__c0__s17\runs\{selection,holdout,full}\QM5_11422\<ts>\logger_sample.jsonl
```

`EQUITY_SNAPSHOT` event counts (measured this session):

| window | EQUITY_SNAPSHOT |
|---|---:|
| selection | 1 295 |
| holdout | 501 |
| **sum** | **1 796** |
| **full (real)** | **1 796** |

**selection + holdout = full, exactly** — the §7.1 additive identity reproduces on live
disk for a *different* EA (QM5_11422) than the doc's QM5_11294 example, strengthening it.
This means the Weg-A reconstruction-vs-real-full comparison can be re-derived offline for
this cell (and every other completed cell with all three window run dirs), yielding the
measured tolerance the acceptance criterion wants **without a 24h factory pilot**. Reference
v2 pilot `cba63d44` and §7 pilot `46409fc4` both have `cells/…/runs` trees on disk as well.

**I did not run the numeric reconstruction comparison** because doing it properly means
adding the v3 reconstruction code (a `q09_news_runner.py`/new-module edit) and its unit
harness — both in or adjacent to the collided runner file. That is step 1 of the follow-up,
and the data to validate it against is confirmed present.

---

## 4 · The sealed-plan auto-caller — wiring spec (gap confirmed)

Today `bind_q09_run_plan` (`farmctl.py:21133`) is **only** reachable from the manual CLI
(`bind-q09-plan`, dispatch at `farmctl.py:24831`). The pump already *marks* rows awaiting a
plan but **never seals one** — grep of HEAD shows no auto-caller; the pump comment records
"2026-08-18 four triples were scan-eligible and none was sealed". Call sites of
`_mark_q09_awaiting_sealed_plan`: `farmctl.py:17057` (in `_pump_unlocked`), `:20947`,
`:21012`, `:21052`. This is the ≤368h "sealed-plan hold" starvation: nothing calls the CLI.

**Planned wiring (fail-closed):** immediately after `_mark_q09_awaiting_sealed_plan` in
`_pump_unlocked`, for each Q09_NEWS row that is eligible and has no sealed plan yet, call
`bind_q09_run_plan(...)` with the same deterministic inputs a human CLI run uses, inside
the existing `SAVEPOINT q09_contract_promotion` so a bind failure rolls back and leaves the
row **held, not fabricated**. If plan generation cannot be done deterministically/safely for
a row (missing precondition, non-deterministic input, contract error), catch and leave the
row awaiting-sealed-plan — never invent a plan. This must not become a second evidence-
integrity bypass.

**This insertion point is inside `_pump_unlocked`, which Task `5343f90a` is rewriting right
now** — hence held until that lands and the file is quiescent.

---

## 5 · Acceptance-critical invariants (to be enforced by the held implementation)

- v2 stays default/production; v3 is opt-in only (a flag or explicit schema selection,
  never a default flip) until proven.
- `cba63d44` and its verdict/raw data are never touched.
- No other gate (Q02–Q13) contract/threshold/criteria touched; no recompiles; no
  verdict/trade-stream overwrites.
- v3 decision logic byte-identical to v2 given equivalent underlying evidence — enforced by
  the fan-to-5-seeds construction (§2.1) and an explicit verdict-identity test.

---

## 6 · What's NOT done (all of the code) — follow-up, once files are quiescent

1. `q09_news_contract.py` (clean now): add `q09-news-evidence/v3` schema + v3-aware
   adjudicator branch that accepts a single canonical-seed cell set (fan seed 17 → 5 slots)
   and routes through the unchanged `CANONICAL_VERDICTS` logic; add `seam_reconstructed`
   and seam-error fields to the v3 payload contract.
2. `q09_news_runner.py` (**collided — wait**): behind an opt-in v3 flag, dispatch only seed
   17 and synthesize the `full`-window metric block from `selection`+`holdout` via the §2.2
   formula instead of a third tester pass; stamp `seam_reconstructed: true` + error bound.
   Prefer isolating the pure reconstruction math in a **new module** (`q09_news_seam.py`) so
   the runner edit is a thin call — smaller collision surface.
3. `farmctl.py` (**collided — wait**): wire the fail-closed auto sealed-plan caller (§4).
4. Tests (new files preferred, plus additions mirroring
   `tests/test_q09_news_runner_v2.py` style): seam-math unit test against a synthetic
   fixture with a known closed-form answer; v3 schema round-trip; **v2↔v3 verdict-identity**
   on shared underlying data; confirm `test_q09_news_runner_v2.py`,
   `test_q09_news_farmctl_integration.py`, `test_q09_live_news_diagnostic.py` still pass.
5. Validation: run the offline reconstruction comparison against the confirmed
   `e323c2f7 / QM5_11422 / control_off__m0__c0__s17` cell (§3) and record the measured
   tolerance (expected ~0.58 % net-profit, ~0 % max-DD).

**Recommended next step:** orchestrator serializes — let the Q09-runner lane and Task
`5343f90a` land and commit, confirm `q09_news_runner.py` + `farmctl.py` are quiescent, then
re-dispatch this task. `q09_news_contract.py` work (item 1) + the new `q09_news_seam.py`
module and its unit tests (part of item 2/4) could proceed in parallel *now* since they
touch no contended file — but I did not start them, to keep this session a clean,
reviewable collision report rather than a half-integrated change against two moving files.
