# Independent review: NNFX rebuild registrations + H1 engulfing retest, governed rollout

Task: `52728403-ca11-4170-8c0c-6130c900c536`. Scope: commits `958e6d991d`
("Recover NNFX build provenance and Retest magic allocations") and `41c271b988`
("Implement closed-bar engulfing retest and specify POC stop correction") on
`agents/codex-ftmo-recovery-20260922`. No edits made on that branch or on
`C:/QM/repo`; all git inspection used `git show`/read-only detached worktrees.

## Method

The `agents/codex-ftmo-recovery-20260922` worktree at `C:/QM/worktrees/` was
dirty (4,908 files changed, ~993k line deletions, set-file `build_hash`/
`set_version` values diverging from the committed source) and unsafe to use
for verification. Two disposable detached worktrees were created instead:
`C:/QM/task_runs/52728403-ca11-4170-8c0c-6130c900c536/verify_41c271b988`
(exact commit `41c271b988`) and `.../verify_baseline` (`696f389a02`, the
immediate pre-branch commit) for regression comparison. Both removed after
use; no state left outside `C:/QM/repo` DB mutations described below.

## 1. Source/evidence bindings — exact match, ACCEPTED

All four NNFX `compile_authority.json` files and the `QM5_9241` retest source
receipt bind an exact `sha256` of the checked-in `.mq5` against the evidence
JSON's own `source_sha256`/`mq5_sha256`. Verified independently (not trusting
the commit's own test suite):

| EA | mq5_sha256 (evidence) | Matches working copy | Matches later real compile |
|---|---|---|---|
| QM5_36001 | `3a77cdff...` | yes | yes (see §5) |
| QM5_36003 | `df2e5bcc...` | yes | yes |
| QM5_36004 | `8b292c0e...` | yes | yes |
| QM5_36008 | `54a9d8c5...` | yes | yes, real `COMPILE_OK` |
| QM5_9241 | `e8488384...` (retest_source_receipt.json) | yes | yes, real `COMPILE_OK` |

`.gitattributes` added under each touched EA dir (`*.mq5 text eol=lf`,
`sets/*.set text eol=lf`) — **LF persistence confirmed**, closing the CRLF
identity-drift class documented 2026-09-06/08-17.

## 2. TP1 idempotency (`QM5_36008`) — reviewed, ACCEPTED

`Strategy_TP1PartialState` (new) walks `HistoryDealGetTicket` scoped to the
exact `POSITION_IDENTIFIER` + framework magic, looking for a `DEAL_ENTRY_OUT`/
`_OUT_BY` deal — this is restart-safe (deal history, not a live position flag)
and magic/position-scoped (no cross-symbol or cross-strategy false positive).
`Strategy_ManageOpenPosition` now: (a) filters on `PositionGetString(POSITION_SYMBOL)
!= _Symbol` before touching a position (a real latent bug fix — the old code could
act on another symbol's position sharing the same magic slot), (b) on
`partial_state > 0` retries only `QM_TM_MoveSL` to `be_sl` and **never repeats
`QM_TM_PartialClose`**, even if price has retraced below the TP1 trigger. This
directly fixes the disclosed defect ("could repeatedly close half the remaining
position after TP1 succeeded"). No idempotency gap found.

## 3. QM5_9241 disclosed card conventions — reviewed, ACCEPTED

`SPEC.md` §1 discloses the touch/invalidation/wick-ratio/supersession
conventions; independently traced each one into `Strategy_EngulfDirection`,
`Strategy_Invalidated`, `Strategy_Retest`, `Strategy_EntrySignal` — all match.
One apparent regression on first read of the `OnTick` diff — the news-filter
block appears deleted from its old position — was **traced further in the
diff and found relocated**, not removed: it now runs after
`Strategy_ManageOpenPosition()`/exit-handling/`QM_IsNewBar`, gating only new
entries, while exits/management run every tick regardless of news state. This
is a correct, intentional narrowing of scope, not a blackout regression.
`retest_source_receipt.json` confirms "3 pytest tests passed... 19 [C#-translated
MQL] assertions" and binds the exact reviewed `mq5_sha256`.

## 4. Tests — reproduced independently

Run inside the clean detached worktree, not the dirty branch worktree:

- `test_nnfx_recovery_20260922.py` + `test_qm5_9241_retest.py` +
  `test_qm5_36004_review_rework.py` + `test_qm5_36008_rework_static.py`:
  **25/25 passed**.
- `test_compile_backlog_authorities.py` alone: **15 failed / 122 passed**,
  identical failing-test set to the `696f389a02` baseline run before this
  branch (**15 failed / 116 passed**) — confirms these are the pre-existing
  "partial worktree lacks unrelated historical source/evidence fixtures"
  failures the commit's own README discloses, not a regression. (A combined
  invocation with an unrelated file transiently showed 2 extra failures;
  traced to a Windows `MAX_PATH` overflow caused by this review's own deeply
  nested `C:/QM/task_runs/<task-id>/verify_.../scratch/...` tmp path, not a
  code defect — confirmed by running the same test alone, which passed.)

## 5. Governed compile rollout — executed to the limit of headless authority

DB state before any action: 5 `COMPILE_EA` rows already existed under hold
`COMPILE_EA_WORKER_ROLLOUT_PENDING`, already carrying **real** (non-fabricated)
recheck/compile attempts from before this task was routed:

| EA | Row | Result | Cause |
|---|---|---|---|
| QM5_36008 | `34293ad6...` | **COMPILE_OK** (real `build_check`/MetaEditor PASS, ex5 `46701c2e...`) | fresh module on T9 |
| QM5_9241 | `b3482782...` | **COMPILE_OK** (ex5 `1190ae3d...`) | fresh module on T6 |
| QM5_36001 | `5f2e60ea...` | `COMPILE_FAIL` / `CANDIDATE_RECHECK_REFUSED:SOURCE_REPAIR_AUTHORITY_INVALID` | stale module on T1 |
| QM5_36003 | `d04e9c6e...` | same | stale module on T3 |
| QM5_36004 | `955c2542...` | same | stale module on T2 |

Root cause of the 3 failures confirmed from `compile_evidence.json`:
`compile_work_items_module_loaded_mtime_ns` on the claiming worker predates
`compile_work_items_module_current_disk_mtime_ns` (the file mtime of the
merged `958e6d991d` registrations, `2026-09-22T05:39:59Z`) — the worker's
in-memory module is older than the registration it needs. This is the
documented "veraltete Worker-Module" class (OPEN_ITEMS_STATUS 2026-09-06/09-12),
**not a source or logic defect**. `mq5_sha256` in every refusal still matches
the registered/committed source exactly — no drift.

Actions taken this cycle (all reversible, evidenced, GRÜN-authorized worker/
queue operations, no gate/registry/live mutation):

1. `farmctl.py enqueue-compile <label> --source-repair-authority <same authority>`
   for the 3 refused EAs → append-only successor rows `24dd10fe-...` (36001),
   `e931b311-...` (36003), `8e5efc70-...` (36004). Predecessor rows kept as
   evidence, not deleted or overwritten.
2. `release_compile_wave.py --work-item-ids <the 3> ` dry-run, then `--apply`
   (backup `farm_state_before_compile_wave_20260922T070046Z_d6fd94a2.sqlite`,
   factory mutation lock acquired/released cleanly).
3. Retry landed on T5/T8 — **also stale** (same diagnostic signature, older
   `loaded_mtime_ns`) — refused again, same class, no new failure mode.
4. Attempted the governed reload tool, `reload_idle_workers.py --terminals T1
   T2 T3 T4 T5 T7 T8 T10`: it hard-refuses with `An existing nonzero
   interactive session is required` — a deliberate safety gate against
   headless/scheduled sessions restarting live factory workers. Did not
   attempt to bypass it (would violate "no manual codex/agy exec sessions
   while factory automation runs" / worker-restart discipline).

**Outstanding, handed to the next interactive Claude/OWNER session:**
`python tools/strategy_farm/reload_idle_workers.py --terminals T1 T2 T3 T4 T5
T7 T8 T10 --apply` (idle-only, staggered, receipt-only unless `--apply`, never
stops an active worker/terminal), then one more `enqueue-compile
--source-repair-authority ...` + `release_compile_wave.py --apply` cycle for
QM5_36001/36003/36004. No further action needed for QM5_36008/QM5_9241 —
already `done`/`COMPILE_OK`.

## 6. Guardrails checked

- Q02 hold `18865d7c-baba-43d3-8327-2ffc2896a1f3` (QM5_36008) — **unchanged**
  (`phase=Q02, status=pending, verdict=NULL`); no second canary created.
- No `Q02` row exists yet for `QM5_9241` or a new one for `QM5_36008` —
  correct, since smoke (`run_smoke.ps1`, explicitly "operator-run") and
  `intake-first-q02` were not attempted in this headless cycle.
- No fabricated `Build PASS`: every verdict above traces to a real
  `compile_evidence.json` (MetaEditor exit codes, `build_check` report paths,
  real `ex5_sha256`) or a real refusal with root cause, never asserted.
- No registry, gate-contract, T_Live, AutoTrading, or live/paid Challenge
  action taken.

## Verdict

**ACCEPT** commits `958e6d991d` and `41c271b988` — source/evidence bindings
exact, LF persistence correct, TP1 idempotency fix correct, QM5_9241 card
fidelity confirmed, tests reproduce as claimed net of pre-existing unrelated
fixture gaps. Governed rollout ceremony executed via the deterministic tool
path (`enqueue-compile --source-repair-authority` + `release_compile_wave.py`,
dry-run before apply, backed up) to the limit of headless authorization;
2/5 compiles are real and terminal (`QM5_36008`, `QM5_9241`); 3/5
(`QM5_36001/36003/36004`) are blocked purely by stale compile-worker modules
on T1/T2/T3/T5/T8, requiring one interactive-session idle-only reload to
finish — not a defect in the reviewed commits.
