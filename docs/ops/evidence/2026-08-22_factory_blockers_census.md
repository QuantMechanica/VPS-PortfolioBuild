# Factory Blockers Census — pre/post Factory OFF/ON

Read-only. DB `D:/QM/strategy_farm/state/farm_state.sqlite` (snapshot 2026-08-22T20:2x Z),
`farmctl health` at 2026-08-22T20:18:32Z. No mutations performed.

## TL;DR — the one finding OFF/ON will NOT fix

**The 5-min pump has been self-blocked (`PUMP_BLOCKED`, exit 86) since ≥18:38Z** because
its mandatory `codex_kill_safety_audit.py` gate finds a genuine Windows-destructive call in
**committed** code: `tools/strategy_farm/include_mirror.py:41` uses `os.kill(int(pid), 0)`
inside `_pid_exists`. On Windows `os.kill(pid, 0)` calls `TerminateProcess` — it *kills* the
target instead of probing it. The pump acquires its lock, runs the audit, the audit returns
non-zero, and `run_pump_task.py:78-82` aborts before ever reaching `farmctl pump`.

Consequence chain (all pump-owned work is frozen): p2→p3 promotion (`p2_pass_promoter`,
farmctl:17459), Codex build spawn, magic-resolver resync, stuck-proc reap, and
`_auto_commit_build_artifacts`. **A Factory OFF/ON will re-run the same audit on the same
committed file and re-block the pump** — OFF alone suspends the pump (returns 0), ON resumes
it into the same failing gate. The `include_mirror.py:41` fix must be committed for the pump
to breathe. Terminal worker fleet and the hourly SweepEnqueue task are NOT gated by this
audit and are running normally.

Evidence: `D:/QM/strategy_farm/logs/pump_task_20260822T195301Z.log` (audit JSON,
`"safe": false`, unsafe=`include_mirror.py:_pid_exists:line:42`), and BLOCKED markers in the
five most recent pump logs (183801Z, 185801Z, 192301Z, 194301Z, 195301Z).
`include_mirror` is live: imported by `compile_work_items.py:19` (`running_terminal_names`,
`IncludeMirrorMutex`). Canonical safe pattern already exists: `health.py:728
_pid_alive_no_signal` (OpenProcess/GetExitCodeProcess, docstring literally "Never use
os.kill(pid, 0)") and `farmctl.py:8156 _pid_exists` (OpenProcess).

---

## 1) q02_stranded_exhausted_pairs — 270 pairs, FAIL

Cohort predicate reproduced from `health.chk_q02_stranded_exhausted_pairs` /
`classify_q02_stranded_pairs_report.COHORT_SQL` (≥12 INFRA_FAIL, no non-infra terminal
verdict, no pending/active successor).

**Newest INFRA_FAIL reason per stranded pair (n=270):**
- 195 `summary_missing_retries_exhausted`
- 24 `ONINIT_FAILED`, 15 `NO_HISTORY`, 11 `ACTIVE_TIMEOUT`, 8 `BARS_ZERO`,
  5 `REPORT_MISSING`, rest single-digit.

**`failure_class` already stamped (classify_summary_missing.py) on newest row per pair:**
- **182 `DETERMINISTIC_NO_SUMMARY`** (runner produced no summary — deterministic EA/build
  defect, NOT a transient), 75 `<unstamped>`, **9 `TRANSIENT`**, 3 `IN_FLIGHT`, 1 UNCLASSIFIED.
- Newest infra timestamp for every pair is **≤ 2026-08-13** — i.e. *before* the 2026-08-17
  infra wave. None of these pairs has been re-run since the wave landed.

**Are the causes fixed?** The 08-17 wave fixed stale-`.ex5`-voids-healthy-backtest,
`gen_setfile` exponent degradation, and host-slot-magic conflation — those are NOT the
dominant class here. 182/270 are deterministic no-summary; a blanket re-run would mostly
re-fail. Only the ~9 TRANSIENT (+ possibly the NO_HISTORY/BARS_ZERO cold-cache ones, now
covered by the WP-5 cold-cache retry in every runner) are genuine re-run candidates.

**Governed path available?** Yes: `tools/strategy_farm/requeue_stranded_infra.py`
(wave-disciplined: Wave 1 = exactly 5 rows, Wave 2 = exactly 25 behind a read-only PASS
receipt; default dry-run; poison sentinels LOG_BOMB/attempt_count≥floor refused). Flipping
the TRANSIENT subset back to pending is GRÜN (requeue-without-verdict, old row preserved).
Promoting the 182 DETERMINISTIC rows' verdict INFRA_FAIL→INVALID is explicitly OWNER-gated
(the tool refuses to; it is a separate decision) → GELB/ROT.

## 2) pending_artifact_binding_drift — 14 mismatches / 9 rows, FAIL

Detector `health.chk_pending_artifact_binding_drift` compares `expected_*_sha256` in each
pending payload against on-disk bytes; classes = all `CONTENT_CHANGED`.

**Which source changed** (recomputed sha, raw + LF/CRLF):
- `8abafefb QM5_10203 XAUUSD Q02`: setfile still matches; **`.mq5` changed** (03c56b→f69024,
  not line-endings).
- `48f156eb QM5_1443 EURUSD Q04`: setfile matches; **`.mq5` changed** (a3069d→b4d7a6).
- `c2ce418a QM5_10649 XAUUSD Q04`: **both setfile and `.mq5` changed**.
The drifting source is the EA **`.mq5` (a rebuild)**, not the generated setfile and not
line-ending noise.

The health headline of "9 rows" conflates holds: only **3** carry
`ARTIFACT_BINDING_CONTENT_CHANGED` (the three above). The rest are unrelated —
`824ca951/a0d6400a QM5_20181` = `FTMO_BOOK3_Q02_ISOLATED_ONLY`; `61f887b7/62156a75/ee0914f4
QM5_35005` = `REVIEW_NOT_COMPLETED_PIPELINE_ENTRY_BLOCKED`; `256846e2 QM5_20096` = UNHELD
(canary).

**Governed re-enqueue?** No mechanical rebind path for CONTENT_CHANGED. Detector hint:
"CONTENT_CHANGED/MISSING requires per-EA review and a governed successor from the final
build." → **GELB** (per-EA review, then a governed successor from the current build);
mechanically rebinding the stale hash would be ROT. Only LINE_ENDINGS_ONLY would be GRÜN,
and there are none.

## 3) codex_zero_activity / repo_dirty_build_guard — FAIL

Guard `farmctl._repo_dirty_status()` (798) runs `git status --porcelain=v1
--untracked-files=all`, classifies each entry via `_generated_ea_artifact_kind`; generated
EA artifacts (setfiles, scaffolds, specs, compiled binaries, card mirrors) are non-blocking,
**everything else blocks ALL builds** (a tracked/modified `.mq5` is source → blocks).

Live evaluation: **20 blocking of 1224 total** (1204 generated/ignored). Blocking classes:
`tracked_ea_source=6` (in-flight `.mq5`: QM5_12929/12930/1401/1402/36005/36007 — the three
router codex sessions + agy mid-build), `tools=6` (`agent_router.py`,
`build_q09_include_closure.py`, `farmctl.py`, 3 test files — the orchestrator's own
uncommitted Q09-closure work), `docs=3` (untracked evidence `.md`), `other=5`
(`build_identity.json`×3, `basket_manifest.json`, `artifacts/evidence_cohort_baseline.json`).

codex_zero_activity (0 builds/3h, 37 pending) is a **consequence** of the dirty tree, which
is a consequence of active in-flight work. `_auto_commit_build_artifacts` only commits
GENERATED artifacts, so it cannot clear source `.mq5` or tool edits anyway (and it is
pump-owned → also frozen, see TL;DR). **GRÜN:** orchestrator commits its own tool/test/doc
edits with explicit pathspecs; the running build sessions' `.mq5` commit as they finish. No
mutation for me.

## 4) pump_task.lock dead PID — self-heal CONFIRMED, pump then self-blocks

`run_pump_task.py:24-49`: `LOCK_STALE_SECONDS = 20*60 = 1200`. On `FileExistsError`, if
`time()-mtime > 1200` it unlinks and re-acquires. The health snapshot's orphan (PID 9000,
age 1497s) **has already been cleared**: the lock now holds PID 22028 with mtime 20:18:01Z,
written by the pump run logged as `pump_task_20260822T201801Z.log`. Both PID 9000 and 22028
are dead now (pump cycles are short-lived). **Self-heal works as designed.**

BUT recovery is hollow: every acquiring pump immediately hits `PUMP_BLOCKED` (see TL;DR), so
the lock churns but no pump work runs. The lock is a non-issue; the audit gate is the issue.

## 5) Q09 wave pilot ba24e7a3 (QM5_11294) — 0/40 receipts, STALLED

- `ba24e7a3` (QM5_11294 / XAUUSD Q09_NEWS) is `active`, claimed by **T4 at 2026-08-22
  13:22:37Z**. Receipts now: **0 occurrences, 0 cells** (`q09_news_cell_occurrences` /
  `q09_news_cells`). Target 40/40 → **0/40**.
- The T4 worker log `terminal_worker_T4.log` **froze at the claim** (mtime 13:22:37Z, last
  line = `claimed ... ba24e7a3`, 7h ago); work_item `updated_at` frozen at 13:24Z. This is
  the stalest of all 8 active Q09 claims (others updated 15:xx–20:24Z). Looks like a
  hung/stuck claim, not a long-running measurement making silent progress.
- All 8 active Q09 rows currently show occ=0. The v2 reference `cba63d44` (QM5_11294 XAUUSD)
  = 23 occ / 19 cells (partial). 41 rows sit `done/REVIEW_REQUIRED`; 27 pending, 25
  failed INFRA_FAIL, 18 done/PENDING_RUNNER.
- **GRÜN:** the Factory OFF/ON restarts the worker fleet and releases the stale T4 claim; on
  ON the pilot re-claims and restarts. If it does not re-progress, canonical requeue
  (`enqueue-backtest --append-only-rerun-of ba24e7a3`). The wave stays gated until 40/40.
- Related: `q09_sealed_plan_hold_age` FAIL (14 holds >6h) and the QM5_12969-class autoseal
  closure drift (`QM_MagicResolver.mqh` regen invalidating a matching EX5 closure) — the
  orchestrator's in-progress fix to `build_q09_include_closure.py` is one of the uncommitted
  files in item 3.

## 6) OPT_CENSUS QM5_41097 — 1020 pending cells; does NOT starve the funnel

- Rows: **1020 OPT_CENSUS pending**, 65 done, 1 COMPILE_EA pending, 1 Q02 done. Per-cell
  wall cap `timeout_seconds = 7200` (2h) from payload. Worst-case terminal budget =
  1020 × 2h = **≤ 2040 terminal-hours**; interleaved across the fleet, on the order of
  ~200h wall worst case (done-cell created→updated median 406min is queue-wait-inflated, not
  runtime — treat 2h cap as the bound).
- **Starvation?** No, by design. Worker-selection priority (farmctl ~1239-1383):
  `priority = priority_track*10 + phase_rank - whole_age_weeks`, lower sorts first.
  OPT_CENSUS is pinned to **Q04's tier-6 rank** and is **never `priority_track`**, so its
  effective term equals an ordinary Q04 row. Every downstream funnel phase (Q05…Q10 at ranks
  5…0) and every priority_track row drains **first**; OPT_CENSUS only interleaves with
  ordinary Q04 and out-ages Q02. Comment in code is explicit: "must INTERLEAVE with the
  funnel, not run ahead of it and not starve it." → informational, no action.

## 7) Scheduled tasks LastTaskResult=1 — one-line cause each

- **QM_Public_Snapshot_Hourly** (rc=1, hourly): `public snapshot publication refused by
  incident guard ... holds=[STALE_BUILD_RESULT_AUTO_Q02_BYPASS:88ba4560]`. The public-data
  guard is fail-closed on any active Q02-bypass hold; exactly **1** active
  (`88ba4560 QM5_20172 XTIUSD`, verdict `BLOCKED_STALE_BUILD_RESULT`, held since 2026-07-29).
  Guard working as designed; the stale hold's release touches bypass semantics → **GELB/ROT**
  (not an infra bug). Log: `C:/Windows/Temp/qm_public_snapshot.log`.
- **QM_StrategyFarm_Cockpit_2min** (rc=1): `AttributeError: 'NoneType' object has no
  attribute 'write'` at `render_cockpit_v2.py:858` (`sys.stderr.write(...)`). Under
  `pythonw.exe` `sys.stderr` is `None`; the v2 renderer writes to it on an error path. Real
  code bug, **GRÜN** infra fix (guard `sys.stderr` before write / route to log file); no
  verdict logic. Log: `D:/QM/reports/state/render_cockpit_v2_error.log`.
- **QM_StrategyFarm_MailboxSourceIntake_Daily** (rc=1): Codex analyst chunks timed out
  (`returncode 124`, "codex chunk timed out at 600s") / earlier "managed Codex capacity full
  (1/1)"; leads left retryable. Throttle/capacity, not a defect — self-heals when Codex
  capacity frees. **GRÜN/parked.** Log:
  `D:/QM/reports/sourcing_intake/mailbox_source_intake_run_log.jsonl`.

## 8) unenqueued_eas_count (6) & p2_pass_no_p3 (9) — cascade split: sweep alive, pump frozen

- **Two engines.** (a) Pump-owned `p2_pass_promoter` (farmctl:17459) → **frozen** with the
  rest of the pump (TL;DR); the 9 profitable Q02-PASS-without-Q03 will not drain until the
  pump unblocks (health hint "next pump cycle ≤5 min should promote them" is currently
  false). (b) `QM_StrategyFarm_SweepEnqueue_Hourly` (rc=0, ran 21:52:52) +
  `QM_StrategyFarm_UnbuiltCardsDisposition_Hourly` (rc=0, 22:00) + terminal worker fleet →
  **healthy**, independent of the audit gate.
- **The 6 "unenqueued":** 3 have literally NO work_items (QM5_11561, QM5_11731, QM5_11570) —
  genuinely never enqueued; the healthy SweepEnqueue should pick them up if they pass its
  predicates (registry active, setfile+ex5 on disk, tradeable symbol) — if they persist it's
  a per-EA predicate miss, not a stuck cascade. The other 3 (QM5_12512, 10050, 12507) already
  HAVE Q02 rows incl. pending → the health list is a stale snapshot for those.
- Net: the funnel's per-symbol dispatch and hourly re-enqueue are alive; only the pump-owned
  promotions/builds are stuck — the same root as the TL;DR.

---

## Action ledger

### GRÜN (autonomous — infra repair / requeue / priority; report after)
1. **Fix `include_mirror.py:41`** — replace `os.kill(int(pid),0)` with the OpenProcess probe
   (`health._pid_alive_no_signal` pattern). Unblocks the pump. Blast radius: include-mirror
   mutex stale-recovery liveness check only; no verdict logic. **Must be committed before/with
   the OFF/ON or the pump stays blocked.** (Orchestrator commits.)
2. **Fix `render_cockpit_v2.py:858`** — guard `sys.stderr is None` under pythonw. Clears the
   Cockpit_2min rc=1. (Orchestrator commits.)
3. **Commit the dirty tree** (orchestrator's own `agent_router.py` / `farmctl.py` /
   `build_q09_include_closure.py` + tests + evidence) with explicit pathspecs → clears
   repo_dirty_build_guard, restores the Codex build lane.
4. **ba24e7a3 stale T4 claim** — released by the OFF/ON worker restart; if it does not
   re-progress, `enqueue-backtest --append-only-rerun-of ba24e7a3` (old row preserved).
5. **Requeue the ~9 TRANSIENT stranded pairs** via `requeue_stranded_infra.py` Wave 1
   (dry-run → snapshot → apply, Factory OFF + quiescent).
6. Pump lock: no action (self-healed).

### GELB (pre-approved on condition / needs a Vorlage)
- 182 DETERMINISTIC_NO_SUMMARY stranded pairs: propose INFRA_FAIL→INVALID reclassification
  (OWNER-gated; `classify_summary_missing.py --apply` is the tool, verdict promotion is the
  separate decision).
- 3 CONTENT_CHANGED binding-drift rows (QM5_10203/1443/10649): per-EA review + governed
  successor from the current build; no mechanical rebind.

### ROT (OWNER only)
- Release of the `STALE_BUILD_RESULT_AUTO_Q02_BYPASS` hold 88ba4560 (Q02-bypass semantics →
  gates the public snapshot).
- Any gate-threshold / contract-criterion change; Q09 gate criteria; overwriting the 41
  Q09 REVIEW_REQUIRED verdicts. (Closing those reviews is the orchestrator's own duty.)
