# Evening synthesis for OWNER — 2026-07-27

Author: Claude (board-advisor worktree)
Scope: the whole day's effort — the FTMO multi-symbol joint book, the log-bomb family,
the pending-tail "age" work, and Codex's progress-aware reaper. Every load-bearing
number below is quoted with a file:line or a live read-only DB query. Where a step
failed its gate, that is stated as the outcome, not smoothed over.

---

## 0. One-paragraph answer

The multi-symbol FTMO book still has **no real joint measurement**. All three multi-symbol
steps correctly GATE-STOPPED because step 1 — proving the runner sleeve is bit-faithful
inside the joint EA — never completed on a terminal. The one joint run that did finish
(QM5_20180) **failed its fidelity gate at match_rate 0.914741 vs a required 1.0**, and the
adversarial review found the real, undiagnosed cause: entries are faithful, exits are
systematically late. Separately, we **cannot certify** that the book's numbers (0.641 and
the rest) still hold on today's binaries — the current-tree control backtest failed to
complete twice. On the factory side the news is genuinely good: the log-bomb "family" is a
proven reclassifier mislabel (0 broken EAs), the fix is committed, and Codex's
progress-aware reaper **has landed**. The single thread running through every failure is
that **no measurement backtest could be brought to completion on a terminal a persistent
worker could reclaim** — the exact hazard the session was warned about and repeated.

---

## 1. THE BOOK — is there a real joint measurement?

**No. There is no true joint equity path, no breach counts, no correlations, and no
FUND_SCORE computed from joint equity. Every one of those is NOT ESTABLISHED.**

### What actually ran

Only one joint backtest completed, and it failed its admission gate
(`2026-07-27_joint_backtest_run_EXECUTED.md:13-27`):

```json
{ "joint_trades": 1255, "gated_trades": 1252, "matched": 1148,
  "unmatched_joint": 107, "unmatched_gated": 104, "match_rate": 0.914741 }
```

Required admission is `match_rate == 1.0`; observed **0.914741**, an 8.53 pp shortfall.
Per protocol, execution stopped after sleeve 0. Worse, this run used the **pre-repair**
EA (QM5_20180, not the repaired QM5_20181) diffed against a **stale 2026-07-14 archived**
stream — so even the one number is joint-vs-stale-archive, not the diff step 1 was meant
to produce.

Steps 2 and 3 then did the correct thing and **refused to stack satellites on an unproven
scaffold** (`2026-07-27_multisym_step2_EXECUTED.md:6-7`,
`2026-07-27_multisym_step3_EXECUTED.md:8-11`): no satellite enabled, no terminal reserved,
no measurement run. The step-1 EXECUTED doc **does not exist**
(`ls .../2026-07-27_multisym_step1_EXECUTED.md` → absent); the report tree
`D:/QM/reports/joint_20181/` is empty of results (only a stray control `tester.ini`).

### The real cause (found by the adversarial review, not by any "diagnosis")

The named `2026-07-27_joint_ea_fidelity_diagnosis.md` was **never written** (git log empty)
— its absence is itself a finding. The review reconstructed the mechanism directly from the
two on-disk streams (`2026-07-27_diagnose_fixes_adversarial_review.md:69-116`):

- **1148 / 1252 trades are bit-identical** on entry, close, net and volume → same data,
  model and commission; not a comparator artifact.
- Of the 107 unmatched joint trades, **78 share the same entry_time and volume** as an
  unmatched gated trade and differ only on the exit; **77 closed later, 0 earlier** — a
  one-directional, systematic exit lag. Example: `entry=1510651994`, gated closes at
  net -579.92, joint holds ~1.4 h longer and closes at -1022.03.

**Entries are faithful; the exit/position-management wrapper drifts late.** One bug class,
narrow and investigable — but real, and it means the "same-symbol sleeves are faithful"
premise the book leans on is false for the exit path.

### What "0.641" actually is

0.641 is **not** a joint number. It is the **stream-stitched** OOS FUND_SCORE for the
composed set `{9936:USDJPY, 10145:XAUUSD, 13301:GDAXI}` — individual sleeve equity streams
concatenated, assuming zero cross-sleeve interaction
(`2026-07-27_runner_satellite_composition.md:19`: IS 0.654 / OOS 0.641 / IS wDD 2.506% /
OOS wDD 3.464%). The joint run was supposed to test whether that stitch survives real
co-execution. It never got the chance.

Individually scored sleeves top out well below 1.0
(`2026-07-27_fund_score_gate.md:23-44`): best is **9936:USDJPY = 0.4085**; of 192 streams
only 15 are scored, 70 are `UNSCORABLE:entry_time_incomplete`, 107 are
`UNSCORABLE:challenge_engine_ineligible`.

**Which step failed its gate and what it means:** step 1 (runner bit-fidelity) never
completed → step 2 (add 10145) inadmissible → step 3 (add 13301 + full-book FTMO
accounting) inadmissible. The book's joint viability — equity path, −5%/−10% breach counts,
sleeve correlations, joint FUND_SCORE — is unmeasured. We do not know whether this book
passes an FTMO challenge because we have never run it as one book.

---

## 2. THE VINTAGE QUESTION — do the numbers still stand on today's binaries?

**NOT ESTABLISHED. This is the load-bearing unknown, and it gates everything in §1.**

- The book's numbers rest on archived Q08 streams generated by a **2026-07-14-vintage**
  EX5 (9936: 330,340 bytes, SHA-256 `a1de7a7b…d44e868ca`,
  `2026-07-27_evidence_vintage_check.md:19-23`).
- The **current** build is 2026-07-27, different bytes (363,810 bytes, SHA-256
  `7ea6234d…4bed0929f`, `:35-42`). A byte difference is not itself a functional failure —
  but it must be measured, not assumed.
- The current-tree control backtest to test equivalence **failed to complete twice**:
  19% progress then `"some error after pass finished"`, no report, T2 reclaimed by its
  worker within ~3 minutes (`2026-07-27_evidence_vintage_check.md:54-58`;
  `2026-07-27_timer_fidelity_curve.md:39-51`).
- Every requested comparison is therefore **NOT ESTABLISHED**: match rate, trade-count
  delta, net-P&L delta, med60 / |wDay| / wDD_p90 deltas, FUND_SCORE delta
  (`2026-07-27_evidence_vintage_check.md:62-83`).

**Meaning:** we are quoting 0.641 (and the whole sleeve table) off binaries we have not
re-validated against the current tree. Until one current-tree 9936 control completes and
diffs clean against the archived stream, the book numbers are provisional. This is the
first thing to fix, because a joint measurement built on a stale-vintage base would be
unattributable even if it ran.

---

## 3. THE FACTORY

### 3a. Log-bomb family — 139 EAs / 4,236 rows

- **EAs fixed in place: 0 — and that is the correct outcome, not an abort.** The family is
  a **reclassifier false-positive**: 0 of 4,236 rows carry any genuine log-bomb kill
  artifact; the stamp rested purely on `attempt_count >= 99`, a sentinel ~8 other
  exhaustion causes also set (`2026-07-27_logbomb_family_diagnosis.md:12-33, 56-70`;
  `2026-07-27_logbomb_family_fixed.md:12-34`).
- **Rows belonging to fixed EAs: 0** (no EA was broken). **Rows the real remediation
  addresses: 4,236 / 4,236** via a one-line reclassifier fix (commit `8e0e81f47`, requires
  a genuine kill marker instead of bare `attempt_count>=99`). Dry-run drops `log_bomb` to
  **0**; all 4,236 re-bucket to their true classes (`2026-07-27_logbomb_family_fixed.md:107-137`).
- 122/139 hold real gate verdicts → variant only, never edit in place. One genuine latent
  bomb exists — QM5_10923, an unguarded per-tick `MoveSL` — but it too holds real verdicts,
  so it gets a variant with a monotonic-guard recipe, not an in-place edit
  (`:139-161`).

  **Live-DB caveat (verified this evening, contradicts the docs).** Both
  `failure_classification_fix.md:120-150,225-231` and `logbomb_family_fixed.md:163-180`
  state the bulk write was **deferred / blocked by the sandbox**. The live DB says
  otherwise: **43,736 rows already carry `failure_class`** (SUPERSEDED 26,651 /
  DETERMINISTIC_NO_SUMMARY 12,547 / IN_FLIGHT 4,504 / TRANSIENT 34 — matching the "dry-run
  only" projection), and **4,236 still carry the buggy `failure_subclass=log_bomb`**
  (read-only query, `D:/QM/strategy_farm/state/farm_state.sqlite`,
  `failure_class_evidence=historical_reclassify:db_join`). So the **buggy** classifier's
  output is live; the **corrected** re-apply that would zero `log_bomb` has **not** run. The
  router adversarial review at ~17:00 verified 0 stamped rows
  (`2026-07-27_router_fixes_adversarial_review.md:124-133`), so the apply landed after that.
  The mislabel is reversible (payload-only, journaled) but it is currently in the live DB,
  not "deferred."

### 3b. Age escalation — live?

There is **no age-escalation lever, by deliberate design** — and that is the right call.
The old pending tail (1,458 rows >14d, oldest `created_at` 2026-05-23) was investigated and
found to be **neither a claim-path defect nor the silent-skip starvation**
(`2026-07-27_failure_classification_fix.md:152-181`): claim ordering is intentionally
priority-first with **age as the final tie-break**, and 86.8% of the tail is
`recovery_class` (sorts dead last, idle-capped by the ratified Operating-Rule-22 throttle).
1,222/1,387 were `updated_at` within 2 days — they are visited every cycle then
deprioritised, not ignored.

What went **live** is **visibility, not escalation**: `chk_pending_tail_age` (health.py,
15-min cadence) surfaces the tail; first live run **WARN value=1457**
(`:184-196`). **Review:** the router adversarial review put this fix through six attacks
(throughput, fail-open, silent-skip, mass-mutation, state-machine, vocabulary) and it
**SURVIVES all six** — no claim-path change, no bulk mutation at review time
(`2026-07-27_router_fixes_adversarial_review.md:18-27, 220-229`). The MEDIUM-LOW findings
(F1–F7) are apply-time hazards, none blocking.

### 3c. Reaper — landed or still in progress?

**Landed and committed.** Commit `850784f97` "fix(farm): make active reaper
progress-aware" is on this branch. Codex's router task `371a7dc0` is **state=REVIEW**,
verdict **PASS**: "progress-aware reaper committed 850784f97; 11 focused tests pass;
historical retained cohort 161/558 progressed" (live `agent_tasks` read).

Mechanism (`2026-07-27_progress_aware_reaper.md:9-42`): binds terminal evidence to the
work-item UUID in the tester.ini launch line, reads only that terminal's subsequent
`AutoTesting processing N %` records, and reaps after **20 minutes without a percentage
increase** — replacing the fixed **45-minute** wall-clock kill that pre-empted still-running
two-hour Q02 children. It fails open when evidence is missing inside the child's budget and
keeps an absolute ceiling ≥10 min beyond `timeout_seconds`. Materiality of the old defect:
of the retained bound cohort, **161/558 = 28.85%** had advanced above 0% before their log
ended — i.e. progress-at-kill was real, not theoretical.

Not-yet-done: the task is in **REVIEW**, not closed to APPROVED. It is committed and tested;
formal Builder≠Approver close-out is outstanding (Claude reviews Codex's; one command).

### 3d. Projected effect on the 814 released pairs

OWNER released **814** stranded Q02 pairs (of 1,246; ~432 held back by the tool's
poison floor) — staged 50 then 764, factory left running, both stages reversible
(`2026-07-27_stranded_requeue_executed.md:8-48`). Expected yield, stated honestly: the
canary resolved **2 PASS / 1 ZERO_TRADES / 5 fresh INFRA_FAIL** of 8 → ~25% recovery, so
**~200 real verdicts** should be expected from 814, not 814 (`:50-57`). Pending rose
2,039 → 2,853 (live now **2,829**). These pairs **do not jump the queue** (age is the last
tie-break), so they drain behind the frontier.

The reaper is the piece that **protects** this cohort: full Q02 runs need 90–100 min and
were being killed at 45; with `850784f97` a genuinely progressing run now survives. The
open risk is that **the 5 fresh canary INFRA_FAILs are undiagnosed** — they failed *after*
the June cause was fixed, so they carry a current fault; diagnosing them would lift the
yield of everything released (`:69-75`).

---

## 4. WHAT REMAINS BROKEN — ranked, with the single next action

1. **No real joint measurement (the whole point).** Step 1 runner bit-fidelity never
   completed because no terminal reservation was honored at claim time (both controls died
   to worker reclaim at 19%). **Next:** run the runner-only joint QM5_20181 replay **and** a
   same-vintage standalone 9936 control to completion on a terminal a worker cannot reclaim —
   a genuinely off-queue ad-hoc `terminal64 /portable /config:<ini> ShutdownTerminal=1` run,
   not `run_smoke` onto a worker lane — then diff (a) with `compare_joint_replay.py`.

2. **Vintage of the book numbers unverified.** Current-tree 9936 control never completed
   (§2). Same blocker as #1. **Next:** complete one current-tree 9936 backtest off-queue and
   diff vs `9936_USDJPY_DWX.jsonl`; only then are 0.641 and the sleeve table certified on
   today's binaries.

3. **Joint EA exit-path fidelity defect (real, evidenced, undiagnosed as a doc).** 77/77
   late exits on a faithful entry path. **Next:** write the actual fidelity diagnosis —
   diff the sleeve-0 exit path (session-close / cancel-hour / trailing cadence under the
   joint OnInit) against standalone 9936 on the 78 same-entry trades; forbid any downstream
   doc from treating the gap as explained until it exists.

4. **Buggy log-bomb classification is live in the DB, not deferred.** 4,236 rows still carry
   `failure_subclass=log_bomb`; 43,736 carry the pre-fix `failure_class`. **Next:** in an
   OWNER-approved quiescent window run the **corrected** `classify_summary_missing.py --apply`
   (payload-only, reversible) to zero `log_bomb` and re-bucket; confirm a revert journal
   exists for the earlier apply.

5. **Reaper task not formally closed.** `371a7dc0` is REVIEW / verdict PASS. **Next:**
   `agent_router.py close-review 371a7dc0 --state APPROVED` (Claude closes Codex's build).

6. **Self-heal never observed end-to-end.** The watchdog parse fix is real, but
   `worker_dedupe_heal` count in the log is **0** and the one heal trigger was a spurious
   `0/9` in a healthy factory; catastrophic escalation still delegates to an InteractiveToken
   task that returns `0x800710E0` while disconnected
   (`2026-07-27_diagnose_fixes_adversarial_review.md:172-216`). **Next:** track the
   InteractiveToken escalation (`factory_watchdog.ps1:1064,1168`) as the remaining self-heal
   gap; stop describing self-heal as "verified end-to-end" until a real shortage heals.

7. **5 fresh stranded-canary failures undiagnosed** (gate the ~200-verdict yield of the 814).
   **Next:** diagnose the 5 post-June-fix INFRA_FAILs before the 814 burn tester time; if the
   fresh-fail rate matches the canary's ~60%, stop and diagnose rather than let 814 burn.

---

## 5. WHAT THIS SESSION GOT WRONG — the handover

A future session must not repeat these. They are specific and each has a concrete tell.

1. **It cited a diagnosis that was never written, and never reconciled a falsified
   prediction.** `joint_backtest_verdict.md` called match_rate 1.0 the "load-bearing,
   expected result"; the run returned 0.914741 and nothing joined the two documents; the
   named `joint_ea_fidelity_diagnosis.md` does not exist in git or on disk
   (`2026-07-27_diagnose_fixes_adversarial_review.md:34-67`). **Rule:** never cite a
   diagnosis by filename without confirming it exists; when a load-bearing prediction is
   falsified, reconcile it in writing before building downstream.

2. **Docs claimed a 43k-row DB write was deferred/blocked while it had in fact landed.**
   `failure_classification_fix.md` §5/§10 and `logbomb_family_fixed.md` §5 say "not
   applied" / "blocked by sandbox"; the live DB shows 43,736 rows stamped and 4,236 still
   mislabeled `log_bomb` (§3a, verified this evening). **Rule:** verify live DB state
   against any "deferred" claim before trusting it, and check for the reversal journal; the
   anti-pattern the reviews hunt (label without behaviour / verified-by-own-doc) bit the
   authors' own bookkeeping here.

3. **It launched measurement backtests onto terminals a persistent worker could reclaim.**
   The vintage control and both step-1 controls went through `run_smoke` onto factory-worker
   lanes; the worker reclaimed the lane at 19% every time (three deaths on record). The hard
   constraint is explicit: measurement runs go **off-queue** via a raw `terminal64 /portable
   /config:<ini>` with `ShutdownTerminal=1`, on a terminal nothing can reclaim — never a
   work-item queue, never a lane a worker owns. **This is the single root cause of both
   §1 and §2 being NOT ESTABLISHED.** **Rule:** if a persistent worker can touch the
   terminal, it is not a valid measurement lane.

4. **It called self-heal "verified end-to-end" from a phantom event.** No real heal fired;
   the cited proof was a point-in-time `0/9` process-scan miss in a factory that was
   draining normally (`diagnose_fixes_adversarial_review.md:172-208`). **Rule:** "verified"
   requires an observed success event, not a guarded run against a shortage that never
   existed.

5. **(Minor, self-corrected.)** The stranded canary was first reported as 3/3 recovery, then
   corrected to ~25% (commit `2a4ad62fe`). The self-correction is good practice; the initial
   over-optimistic read is the thing to avoid — resolve the canary before quoting a rate.

### What went right (so the handover is balanced)

The diagnostic discipline was strong where it mattered: the log-bomb family was correctly
refused as a false-positive rather than "fixed" into phantom repairs; the reclassifier,
progress-aware reaper, Q02 failure classification, Q08 NA boundary, and watchdog parse are
real code changes that survived adversarial review; and the multi-symbol steps **honored
their gates** and stopped rather than manufacturing an unattributable joint number. The book
is unproven, but it is unproven *honestly* — no fabricated equity path was produced.

---

## Evidence index

- Joint run fail: `2026-07-27_joint_backtest_run_EXECUTED.md:13-27,108-124`.
- Gate stops: `2026-07-27_multisym_step2_EXECUTED.md:6-48`;
  `2026-07-27_multisym_step3_EXECUTED.md:8-66,137-163`.
- Exit-lag mechanism + missing diagnosis: `2026-07-27_diagnose_fixes_adversarial_review.md:34-130,172-216`.
- 0.641 provenance: `2026-07-27_runner_satellite_composition.md:19,59`;
  sleeve scores `2026-07-27_fund_score_gate.md:23-44`.
- Vintage: `2026-07-27_evidence_vintage_check.md:19-83`; `2026-07-27_timer_fidelity_curve.md:39-51`.
- Log-bomb: `2026-07-27_logbomb_family_diagnosis.md:12-70`;
  `2026-07-27_logbomb_family_fixed.md:12-34,107-180`; fix commit `8e0e81f47`.
- Age/tail: `2026-07-27_failure_classification_fix.md:152-196`;
  review `2026-07-27_router_fixes_adversarial_review.md:18-27,124-133,220-229`.
- Reaper: `2026-07-27_progress_aware_reaper.md:9-70`; commit `850784f97`; task `371a7dc0`
  (REVIEW / PASS).
- 814 release: `2026-07-27_stranded_requeue_executed.md:8-75`.
- Live DB (read-only `D:/QM/strategy_farm/state/farm_state.sqlite`, 2026-07-27 evening):
  pending 2,829; `failure_class` stamped 43,736 (SUPERSEDED 26,651 / DETERMINISTIC 12,547 /
  IN_FLIGHT 4,504 / TRANSIENT 34); `failure_subclass=log_bomb` 4,236; agent_tasks
  RECYCLE 433 / PASSED 229 / PIPELINE 61 / BLOCKED 37 / APPROVED 6 / REVIEW 2 / FAILED 1.
