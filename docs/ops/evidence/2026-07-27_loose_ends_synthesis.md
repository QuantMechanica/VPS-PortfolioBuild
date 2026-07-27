# Factory loose-ends — synthesis handover for OWNER

Date: 2026-07-27
Author: Claude (board-advisor lane)
Scope: closes out the loose-ends effort seeded by the volume census
(`docs/ops/evidence/2026-07-27_factory_loose_ends_census.md`, router task `621d3c75`)
plus the joint-EA fidelity gap (`QM5_20180`).
Branch: `agents/board-advisor`. Nothing in this effort was applied to the backlog,
touched the claim path, ran Factory OFF/ON, or touched T_Live.

**Read this first, because it reframes everything below:** the five fixes changed the
factory's **forward behaviour** and added **detection**. **Not one of them drained a
single backlog row.** The census headline volumes — 43k mislabelled Q02 rows, ~699
stranded tasks, 209 Q08 evidence-defect rows — are all still in the DB as of this
handover. Every fix delivered *mechanism + a dry-run projection of what would move* and
then **deliberately deferred the write** to OWNER, because applying any of them is a
capacity or credential decision, not a code decision. If you take one thing from this
document: the plumbing is fixed, the debt is not paid, and paying it is the set of
decisions in §3.

---

## 1. Census scoreboard (all 12 ranked findings)

| # | Finding | State | Evidence |
|---|---|---|---|
| 1 | 43,422 Q02 `summary_missing_retries_exhausted` = `INFRA_FAIL` | **PARTIALLY FIXED** — forward classifier live in `terminal_worker` (deterministic→INVALID, transient→INFRA_FAIL, fail-open); 43,736-row historical reclassifier **built, not applied**; verdict-promotion OWNER-gated | `2026-07-27_failure_classification_fix.md` §4-5 |
| 2 | Q02 `INFRA_FAIL` = 68.3% of all Q02 rows | **PARTIALLY FIXED** — same fix stops new mislabelling at the exhaustion boundary; the historical mass is unchanged until the reclassifier is applied | `2026-07-27_failure_classification_fix.md` §1-4 |
| 3 | Old pending tail: 1,458 >14d, 325 >30d | **DIAGNOSED + DETECTOR** — established as *deliberate priority-first ordering* (age is the last tie-break), **not** a claim-path defect and **not** the silent-skip starvation; `chk_pending_tail_age` now surfaces it (live WARN=1457). No drain lever was added | `2026-07-27_failure_classification_fix.md` §6-7 |
| 4 | `RECYCLE` has no router exit (430; 411 build_ea) | **MECHANISM FIXED, NOT APPLIED** — bounded `RECYCLE→TODO` (`recycle_count++`), `→BLOCKED` at cap 3. Applying re-queues 430 into the build lane = mass requeue → OWNER | `2026-07-27_state_machine_exits_fix.md` §3, §7 |
| 5 | `APPROVED` has no router exit (206) | **MECHANISM FIXED, NOT APPLIED** — type-aware: `build_ea→PIPELINE`, everything else→`PASSED` (for a research/review/ops card, APPROVED already *is* the accepted verdict — a blanket →PIPELINE would invent a new dead end) | `2026-07-27_state_machine_exits_fix.md` §2-3 |
| 6 | Q08 209/530 `INFRA_FAIL`; 70/189 streams lack `entry_time` | **PARTIALLY FIXED** — the evidence-defect `INFRA_FAIL` subset is addressed forward by the rank-7 fix; the `entry_time`-missing → FUND_SCORE `UNSCORABLE` gap (37% of streams) is **not** closed — it is acknowledged as *correct* behaviour, but FUND_SCORE screening remains blind on a third of streams | `2026-07-27_q08_evidence_defects_fix.md`; census §3 |
| 7 | Q08 `8.5 artifact_missing` (94) + `8.7 got=0` (81) | **PARTIALLY FIXED** — the two cohorts proven to be **one production/lineage cascade** (absent neighborhood artifact starves both), *not* structural inapplicability; a distinct non-punitive `NOT_APPLICABLE` sub-gate status is now threaded end-to-end for the genuine fixed-parameter case (live + tests). The 209 historical rows are **not** re-run; the `_guess_baseline_setfile` empty-template bug is deliberately left to the build lane | `2026-07-27_q08_evidence_defects_fix.md` §1-4 |
| 8 | `PIPELINE` has no router exit (59) | **MECHANISM FIXED, NOT APPLIED** — `PIPELINE→PASSED/FAILED` read strictly from `work_items` Q10/P8 (**never manufactured**); in-flight EAs are left in place. Dry-run: only 1 of 59 is movable, 58 are legitimately waiting on the pipeline | `2026-07-27_state_machine_exits_fix.md` §3, §7 |
| 9 | Directory used where a file artifact is expected (9 approved + 4 pipeline) | **FIXED FORWARD** — an existing directory is now refused in `artifact_path` at enqueue/update/close_review (validate on write). The guardrail-timeout *source* is closed; the 15 existing rows are not scrubbed | `2026-07-27_state_machine_exits_fix.md` §5 |
| 10 | 8 interactive scheduled jobs at `0x800710E0` | **PARTIALLY FIXED** — root cause established (`InteractiveToken` tasks queue forever against a `Disconnected` session). 1 was interactive **by accident** → moved to SYSTEM, **verified running** (rc=0). The self-heal path's silent parse bug (watchdog rejected `console session` evidence) is **fixed + committed + verified end-to-end** — the factory can heal worker shortages again. The other **7 tasks genuinely need the interactive session** (desktop/DPAPI/`G:` mount) and still queue → OWNER | `2026-07-27_interactive_task_selfheal_fix.md` §1-5 |
| 11 | Q09 latest-per-EA 53 FAIL / 25 PASS / 6 NMD | **NOT TOUCHED (correctly)** — Q09 is selective, not broken; a parallel finding confirmed the FTMO book fails Q09 *for correlation and Q09 is right* | census §3; commit `386321cdb` |
| 12 | `pipeline_run` requires capability `pipeline` no agent declares | **FIXED** — task type **retired** from the map (`enqueue_task` now raises); its one live row homes to `BLOCKED` via the reconciler. No agent was granted `pipeline` — that would authorise an AI to *manufacture* a pipeline verdict (Hard-Rule breach) | `2026-07-27_state_machine_exits_fix.md` §4 |

**Joint-EA fidelity gap (ALSO OPEN): DIAGNOSED ONLY — and it produced a negative
result that matters more than the EA.** Sleeve-0 replay was run on reserved T9 and the
fidelity gate **correctly failed** (`match_rate = 0.914741` vs required `1.0`; 3 extra
trades, 107 unmatched joint, 104 unmatched gated) and the run was **correctly stopped**.
The load-bearing point: sleeve 0 (9936, host=USDJPY) opens through the **default
`QM_Entry` path and was asserted byte-identical to standalone**; the adversarial review
had certified this USDJPY-only case as "survives every attack." The run **falsified that
certification on the one case that was supposed to be safe.** Why it diverges is **NOT
ESTABLISHED** — it could be transcription drift in the lifted 9936 module, a
comparator/harvest key mismatch, or a genuine basket-mode ownership/emission perturbation
of even the host sleeve. Evidence: `2026-07-27_joint_backtest_run_EXECUTED.md`,
`2026-07-27_joint_backtest_ea_adversarial_review.md` (C1-C4 + "What survives" §7),
`2026-07-27_joint_backtest_verdict.md` §5-6.

---

## 2. What actually changed for the factory

**Can an EA now enter and either come out with a verdict or be retired with a reason?**
**Going forward — materially better in three places; the backlog — unchanged.**

Forward-going (live now):

- A **new** Q02 summary-missing exhaustion gets an honest cause
  (`verdict_reason=summary_missing:<subclass>`) and INVALID vs INFRA_FAIL is decided by
  evidence, fail-open — instead of the single graveyard label. (in `terminal_worker`)
- A **fixed-parameter** EA at Q08 lands a clean merit verdict via `NOT_APPLICABLE` at
  8.5/8.7 instead of a blocking INVALID that read as an un-satisfiable retry-owed
  INFRA_FAIL. (in the q08 sub-gates; top-level verdict set unchanged, so dashboards need
  no change)
- The self-heal loop **works again**: the SYSTEM watchdog spawns workers into the live
  (disconnected) session and now correctly records the heal instead of a false
  `heal_failed`. (verified end-to-end)
- A directory can **no longer be recorded** as an artifact; `pipeline_run` can no longer
  be enqueued. Two dead ends closed at source.

**Where an EA / task can still strand (name the paths):**

1. **The RECYCLE/APPROVED/PIPELINE exits are NOT autonomous.** They exist as a mechanism
   invoked by an explicit `reconcile-exits` call; they are **not** wired into the
   router's `run_once` tick and default to dry-run. So a **new** task landing in RECYCLE
   today still strands exactly as before until a human runs the command. "The exit
   exists" is true; "the router now drains them" is false.
2. **The 43,736 historical Q02 rows** still carry `INFRA_FAIL` and their honest cause is
   invisible until the reclassifier is applied.
3. **~699 tasks** (RECYCLE 431 / APPROVED 209 / PIPELINE 59) still sit in limbo; the
   exit was projected, not applied.
4. **209 historical Q08 `INFRA_FAIL` rows** are unchanged; only a re-run reclassifies
   them.
5. **7 of 8 interactive scheduled tasks** still queue at `0x800710E0` — this includes
   `AgyGovernor`, `MailboxSourceIntake`, `GeminiOrchestration`, and the two T_Live
   supervisors. Worker self-heal is restored, but the research/mailbox/agy-pacing lanes
   are still dead until OWNER acts. Residual: the watchdog's heaviest escalation
   (full-reset) still calls an `InteractiveToken` `FactoryON` task and would queue if it
   ever fired.
6. **The old >30-day tail** drains only when the frontier is idle *and* the recovery
   throttle permits (≤1 per window); on a permanently saturated fleet that can be
   effectively never.
7. **QM5_20180** is stranded at fidelity FAIL with an unexplained cause.

---

## 3. Decisions now waiting on OWNER

Each with volume, cost, and my recommendation. None can be taken as a code side effect.

### D1 — Transition the ~699 limbo tasks (exits now exist)

Dry-run of `agent_router.py reconcile-exits` against the live DB
(`2026-07-27_state_machine_exits_fix.md` §7):

| Move | Count | Cost | Recommendation |
|---|---:|---|---|
| `APPROVED→PASSED` (terminal-accepted: research/review/ops/triage) | 206 | **≈zero factory load** — no downstream pipeline exists for these types; PASSED is their real verdict | **APPLY** |
| `APPROVED→PIPELINE` (build_ea) | 3 | 3 builds → pipeline | **APPLY** (negligible) |
| `PIPELINE→PASSED` (closing verdict present) | 1 | zero | **APPLY**; leaves 58 correctly in-flight |
| `RECYCLE→TODO` (rebuild) | 430 (411 build_ea) | **floods the build lane** — a mass requeue and a capacity decision | **DO NOT bulk-apply** |

Recommended command sequence:
```
python tools/strategy_farm/agent_router.py reconcile-exits                                   # preview
python tools/strategy_farm/agent_router.py reconcile-exits --apply --state APPROVED --state PIPELINE   # clears 210, ~zero load
python tools/strategy_farm/agent_router.py reconcile-exits --apply --state RECYCLE --limit 20          # only in small OWNER-authorised batches
```
My recommendation: **apply APPROVED+PIPELINE now** (clears 210 with three trivial
builds), and for RECYCLE **triage before requeue** — the 25 fabricated-card precedent
was 19 retire / 4 unblock / 2 need-source, so most of the 411 builds likely belong in
`BLOCKED`/retired, not re-queued. Do **not** dump 430 builds into a 2,004-deep Q02.

### D2 — Apply the historical Q02 reclassifier (43,736 rows)

Payload-only, reversible, drift-guarded, **zero claim-path/routing impact, no requeue**;
it only makes the honest cause visible (12,535 DETERMINISTIC / 26,651 SUPERSEDED /
4,517 IN_FLIGHT / 33 TRANSIENT). The tool defers to a quiescent window by convention.
Cost: a 43k-row local SQLite write, reversible via snapshot. **Recommendation: APPLY** in
the next quiescent window — it changes no verdict and no queue, only the diagnosis.
A *further* OWNER-gated step is promoting the 12,535 DETERMINISTIC rows' stored verdict
from `INFRA_FAIL`→`INVALID` so a future sweep can never re-run known defects.

### D3 — Re-run any reclassified failures?

- **Q02:** of the 43,736, only **33 are genuinely transient** (0.1%); 26,651 already
  have verdicts and 12,535 are deterministic defects. Re-running any material fraction
  swamps a 2,004-row queue. **Recommendation: re-run essentially none** (at most the 33,
  only if a terminal is idle).
- **Q08:** the **209 historical `INFRA_FAIL` rows** would, on re-run, reclassify genuine
  fixed-parameter cards to clean merit verdicts and clear the mis-resolved-setfile cases.
  Q08 is expensive (neighborhood + PBO). **Recommendation: re-run selectively as capacity
  allows**, not as a bulk requeue.

### D4 — The 7 interactive tasks

Options (`2026-07-27_interactive_task_selfheal_fix.md` §5): (a) build one **SYSTEM
"interactive dispatcher"** that launches each job into the live session via the now-proven
`run_in_console_session.ps1` transport — the systemic fix, covers 4-5 tasks; (b) quick-win
**`AgyGovernor` via a `Password` principal** (needs OWNER to supply the qm-admin password;
S4U/SYSTEM cannot decrypt its DPAPI credential). **Recommendation: authorise (a); do (b)
as the immediate quick-win.** The two T_Live supervisors stay untouched (hard constraint);
a SYSTEM counterpart already runs — confirm coverage.

### D5 — The joint EA (QM5_20180)

Decide whether to spend the diagnosis time on the `0.914741` sleeve-0 divergence. It is
**evidence about whether a gated sleeve's logic can be lifted out of its own EA at all**
— a question that governs the entire joint-book approach, not just this EA. **My
recommendation: diagnose it before any further FTMO joint-EA work**, because the surviving
"faithful" case was the whole justification and it just failed.

---

## 4. What got worse or riskier

- **New foot-gun: `reconcile-exits --apply --state RECYCLE`** dumps 430 tasks (411 builds)
  into the queue in one call. The command is bounded (`--limit`) but the unbounded form
  exists. This is the single most dangerous new lever.
- **New vocabulary consumers must learn:**
  - Q02 `verdict_reason=summary_missing:<subclass>` and payload `failure_class`/
    `failure_subclass` (the old single `final_failure` label is preserved for back-compat,
    so existing surveys still run — but anyone *counting causes* must learn the split).
  - Q08 sub-gate status **`NOT_APPLICABLE`** and `summary.n_not_applicable`. Top-level
    verdicts are unchanged, so only sub-gate-detail readers are affected.
  - New task-exit reasons (`approved_accepted_terminal`, `recycle_requeue`,
    `pipeline_closing_verdict_pass`, …) and a **retired task type** — any future caller
    that enqueues `pipeline_run` now hits a raised error (there were zero callers).
- **New standing amber on the health dashboard:** three new checks
  (`chk_pending_tail_age` WARN=1457, `chk_agent_task_state_stranded` WARN=699,
  `chk_q02_summary_missing_unclassified` OK) will read as persistent WARN until the
  backlog is drained. Operators must learn these are the *known inherited tail*, not new
  fire; FAIL thresholds sit above today's tail so genuine regrowth still escalates.
- **New checks in hot-ish paths:** a directory-`stat` on every task write (cheap; only an
  *existing* directory is refused, not-yet-written paths pass). The Q02 classifier runs
  only at the exhaustion boundary and the Q08 NA logic only in sub-gate evaluation —
  **neither is in the claim path, which was left untouched by every fix.** MT5 saturation
  is unaffected.

---

## 5. What this effort got wrong or left unfinished (unsparing)

1. **Nothing was applied. The census numbers have not moved.** Five "fixes" plus a
   diagnosis, and the DB still holds 43,736 mislabelled Q02 rows, ~699 stranded tasks,
   209 Q08 evidence-defect rows, and 1,457 old-pending rows. Forward behaviour improved;
   accumulated debt is exactly where the census found it. An OWNER skimming "5 fixes"
   could believe the volumes dropped — they did not. This is the honest headline.
2. **The state-machine exits are not autonomous.** The dead ends are closed only for a
   human who runs `reconcile-exits`. A new task entering RECYCLE today strands as before.
   Wiring a *bounded, throttled* exit into `run_once` was out of scope and remains the
   real completion of finding 4/5/8.
3. **The joint-EA sleeve-0 divergence is undiagnosed — and it is the effort's most
   important negative result.** The adversarial review certified USDJPY-only as faithful;
   the run falsified that on the first, supposedly byte-identical sleeve
   (`0.914741`, 3 extra trades). Until the cause is known — module transcription drift vs
   comparator/harvest key mismatch vs basket-mode host perturbation, all NOT ESTABLISHED —
   the "lift a gated sleeve into a joint EA" pattern is **not validated even for the easy
   case**, and the whole joint-book premise is on hold.
4. **Rank 6 was largely sidestepped.** The `entry_time`-missing → 37%-of-streams
   `UNSCORABLE` FUND_SCORE gap (and, per MEMORY, multi-day positions rendered invisible
   because `entry_time` is discarded) was acknowledged as "correct UNSCORABLE" rather than
   fixed at production. The rank-7 fix only touches the 8.5/8.7 evidence-defect subset.
5. **The historical Q02 split is DB-inference, not per-row log evidence.** Only 474 of
   43,736 run logs survived the pruners (1.1%); the DETERMINISTIC/SUPERSEDED/IN_FLIGHT
   classification rests on the payload + `work_items` DB-join for ~99% of rows. It is
   well-argued and spot-checked (the 474 surviving logs corroborate it), but it is
   inference for the mass, not a log read.
6. **The Q08 `_guess_baseline_setfile` bug persists.** The resolver can pick a param-less
   `_backtest.set` template over a populated sibling (case 11124), so some historical
   "setfile defect" INVALIDs are false and will remain until the build lane materialises
   card defaults into the template. Deliberately left, but real.
7. **Three Q08 tests (`test_cascade_real_phase_runners`) fail** — attributed to
   pre-existing environmental subprocess-spawn failures, identical on unmodified code.
   Plausible, but it means the NA fix's end-to-end phase-runner path was not exercised in
   CI on this host.
8. **Rank 3 got a detector, not a lever.** Reframing the old tail as "deliberate ordering"
   is defensible, but OWNER still has no sanctioned way to force-drain the genuinely
   abandoned >30-day rows on a saturated fleet — the recovery throttle may never reach
   them.

---

## Status / evidence / risk / next step

- **Status.** Loose-ends census closed out; 5 forward fixes + 3 health detectors landed
  and committed; joint-EA fidelity gate ran and correctly failed. **Zero backlog rows
  transitioned; claim path, T_Live, Factory OFF/ON all untouched.**
- **Evidence.** `2026-07-27_factory_loose_ends_census.md`,
  `2026-07-27_failure_classification_fix.md`, `2026-07-27_state_machine_exits_fix.md`,
  `2026-07-27_q08_evidence_defects_fix.md`, `2026-07-27_interactive_task_selfheal_fix.md`,
  `2026-07-27_joint_backtest_run_EXECUTED.md`,
  `2026-07-27_joint_backtest_ea_adversarial_review.md`,
  `2026-07-27_joint_backtest_verdict.md`. Commits `c6b8a855a`, `6b750263c`, `20f5ff6dd`,
  `b4c70c442`, `3e811661a`, `e808e2d9c`.
- **Risk.** The only material new risk is an unbounded `reconcile-exits --apply --state
  RECYCLE` flooding the build lane; use `--limit`. The joint-book approach is unvalidated
  until the sleeve-0 divergence is explained.
- **Recommended next step.** Take D1 (apply APPROVED+PIPELINE now, triage RECYCLE),
  schedule D2 (Q02 reclassifier) for the next quiescent window, and diagnose the QM5_20180
  sleeve-0 divergence (D5) before any further joint-EA work.
