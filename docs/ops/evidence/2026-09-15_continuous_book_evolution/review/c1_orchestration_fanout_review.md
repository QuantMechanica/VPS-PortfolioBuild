# Adversarial review — slice `c1_orchestration_fanout`

Reviewer: board-advisor adversarial reviewer · 2026-09-15 · canonical repo `C:/QM/repo` @ HEAD `55fb2bf5fc`.
Scope: directive §24 (controlled parallelism) + §35 (Claude-lane fan-out fix); audits
`audit/claude_lane_fanout_defect.md`, `audit/quota_tasks_routing_resources.md`.
Patch reviewed: `…/scratchpad/patches_bc/c1_orchestration_fanout.patch` (read in full).
Method: read patch + report + directive + both audits; grepped canonical for renamed
symbols and API signatures; verified `git apply --check --3way` against canonical HEAD;
static analysis of control flow (no repo mutation — READ-ONLY review).

**Verdict: ACCEPT_WITH_FIXES.** The design is sound and matches the audit's chosen
least-invasive fix (additive `agent_task_exec:<id>` pid-owned lease on the existing
`spawn_leases` table, prompt hard-pin, idempotent slot dirs, release-on-exit/TTL). No RED
boundary is crossed. One blocking item (the PS1 hunk does not apply to canonical HEAD) and
two majors must be handled before the lane is re-raised to `--max-sessions 3`.

---

## RED boundary check (criterion 1) — CLEAR

- **Gate threshold / criterion change:** none. `agent_router.py` change is a **comment-only**
  docstring block above `DEFAULT_AGENT_REGISTRY`; every `max_parallel` value is unchanged
  (verified canonical: codex 5 @L577, claude 3 @L600, gemini 2 @L615, kimi 1 @L645, owner 0
  @L665 — the docstring's stated caps match reality exactly).
- **Qualification weakening / candidate-pool change:** none.
- **T_Live / AutoTrading / purchase / evidence-rewrite:** none touched. No verdict, work_item,
  or trade-stream write. Verdicts continue to come only from pipeline evidence.
- **Token / credential exposure:** none. New code uses `os.getpid()`, `socket.gethostname()`,
  `uuid.uuid4().hex` only. No secret is read, logged, or committed.
- **Farm DB write:** the fix writes an **additive** `agent_task_exec:<id>` row to
  `spawn_leases` — the same coordination table the router (`agent_task:*`) and the
  headless-session lease (`headless_orchestration:*`) already use, explicitly sanctioned by
  the audit ("additive lease key … No schema change") and covered by GRÜN infra-repair
  authority (does not touch verdict logic). This is a runtime coordination write, not an
  evidence/verdict write. The router's `agent_task:*` path is left untouched (regression-
  guarded by `test_exec_lease_key_is_distinct_from_router_lease`). **Not a RED violation.**
  Tests write only to a monkeypatched tmp DB (`FARM_ROOT` → `tmp_path`), never the live DB.

`red_boundary_crossed = false`.

---

## Directive fidelity (criterion 2)

- **§35 fan-out fix — DONE and correct in design.** Launcher claims a distinct pid-owned
  exec-lease per intended slot BEFORE spawning; spawns one slot per won lease; pins the id
  into env (`QM_ASSIGNED_TASK_ID`) and prompt; `--max-sessions` is now an upper bound, not an
  N×M multiplier; skips with `no_unpinned_claude_task` when every eligible task is already
  pinned (safe throughput failure, never a duplicate). Matches audit Change 1–4 and ticket
  `3e0c8b83` acceptance criteria.
- **§24 controlled parallelism — no arbitrary permanent cap invented (GOOD).** The implementer
  correctly did **not** raise any `max_parallel`, because both audits say so
  (`quota_tasks_routing_resources.md`: "Routing config — no change required";
  `claude_lane_fanout_defect.md`: re-raise Claude only to its existing 3 after the fix). This
  is faithful to §24 *and* to §8 ("Do not replace the old static caps with another arbitrary
  set of permanent caps"). Reason recorded in the registry docstring; kimi pinned at 1, owner
  at 0. The task's "raise on lanes the audit marked eligible" is satisfied vacuously — the
  audit marked none eligible.
- **§3 installer interim mitigation — DONE.** `-ClaudeMaxSessions` param (default 1) with a
  dated `SUPERSEDED 2026-09-15` marker; re-register command listed in `notes_for_orchestrator`.
  This is a real default-value change, **not** a silent no-op warning.
- **Silent no-op check:** the skip branch (`no_unpinned_claude_task`) is a genuine early
  return with a logged reason, not a swallowed warning. The exec-lease acquisition is
  fail-closed at the per-lease layer (`fail_open_on_error=False`). No silent no-op found in
  the fan-out mechanism itself — but see M1 for the fail-*open* candidate-query branch.

---

## Correctness (criterion 3)

- **API compatibility — verified.** `agent_scopes.acquire_spawn_lease` /`renew_spawn_lease`
  /`release_spawn_lease` exist in canonical with signatures matching every call
  (`agent_scopes.py:224,275,301`). Steal is TTL-only via `ON CONFLICT … WHERE
  spawn_leases.expires_at <= excluded.acquired_at`. Imports `dt`, `os`, `socket`, `uuid`,
  `ThreadPoolExecutor` all present in the launcher.
- **Backward-compatible callers — verified.** The new optional params on `agent_env`,
  `build_prompt`, `run_agent_slot`, `_refresh_headless_ownership` default to `None`. Grep of
  canonical confirms the only callers are the launcher itself + the test stubs (which the
  patch updates in `test_codex_model_tiers.py`). `farmctl.py`/`mailbox_source_intake.py`
  `build_prompt` are unrelated same-named functions. No broken caller.
- **Early-return lease release — correct.** The worktree-fail (`:1012`) and lock-skip
  (`:1024`) branches sit BEFORE the main `try/finally`, so the explicit
  `release_task_exec_lease(exec_lease)` added to each is required and correct; the `finally`
  covers the execution path. Double-release (slot `finally` + parent backstop `finally`) is
  idempotent (owner-scoped DELETE, guarded on `session_token`). No leak, no double-free bug.
- **Non-claude lanes unchanged** — `session_count` forced to 1 for `agent != "claude"`;
  `exec_leases` stays `[]`; slots get `None` pins. Codex/gemini/kimi paths byte-equivalent.
- **Windows paths / JSON:** clean. Test uses `Path(r"C:\does\not\exist.flag")`; no path issue.

---

## Findings

### BLOCKING

**B1 — The PS1 hunk (§3 deliverable) does not apply to canonical HEAD; the patch base is stale.**
`git apply --check --3way` reports: *"Applied patch to
`tools/strategy_farm/install_agent_orchestration_scheduled_tasks.ps1` **with conflicts**"*
(the two `.py` files and the test file apply cleanly). Cause: the patch base blob
`ad781a6eb5` has `    [switch]$RunNow` as the **last** param with **no trailing comma** and
no `-IncludeKimi`; canonical HEAD has `    [switch]$RunNow,` (trailing comma) followed by the
`-IncludeKimi` param (added by the Kimi integration that post-dates worktree base
`ab9c2f1e09`). The `-ClaudeMaxSessions` insertion hunk therefore conflicts.
Consequence: a plain `git apply` rejects the PS1 hunk (§3 mitigation never lands); a forced
`--3way` leaves conflict markers inside a PowerShell file (syntactically broken installer).
**Must fix before apply:** rebase the PS1 hunk onto canonical — insert `[int]$ClaudeMaxSessions
= 1` into the current param block (keeping `[switch]$RunNow,` and `-IncludeKimi` intact) and
apply the `$definitions` claude-line change (`MaxSessions = $ClaudeMaxSessions`) which itself
applies cleanly. Trivial, localized; core code files are unaffected.
Evidence: `git cat-file -p ad781a6eb5` vs `install_agent_orchestration_scheduled_tasks.ps1:1-12`.

### MAJOR

**M1 — Fail-*open* candidate-query branch does not clamp `session_count`, re-opening the
fan-out when `--max-sessions > 1`.** In `_run_agent_with_session_lease`, the exec-lease claim
runs only `if candidate_status == "ok"`. If `_quota_lane_candidates("claude")` returns
`db_missing`/`db_error:*` (a transient error is plausible under the saturated host — D: at
6% free), `exec_leases` stays `[]` **and `session_count` is left unchanged (up to 3)**. The
`try` block then spawns `session_count` **unpinned** sessions (`exec_leases[slot-1] if
exec_leases else None` → `None`) — i.e. the exact task-agnostic fan-out the slice removes.
The report claims this branch "fail[s] OPEN to a single task-agnostic session," but the code
never sets `session_count = 1` there. Masked today because §3 ships the interim default
`--max-sessions 1`; it bites the moment the lane is re-raised to 3. **Fix before re-raising:**
on `candidate_status != "ok"` for the claude lane, force `session_count = 1` (single
task-agnostic session, as the report intends) or treat it as `no_actionable_work`. Note the
per-lease acquire is already fail-closed; only this outer guard is fail-open.
Evidence: patch hunk `_run_agent_with_session_lease` (`if candidate_status == "ok":` with no
`else` clamp); `run_agent_orchestration_task.py:1837-1843,1922-1924` (`_quota_lane_candidates`
returns `db_missing`/`db_error:*`/`ok`).

**M2 — Single-session semantics silently change from "drain all IN_PROGRESS" to "one task
per cycle"; undocumented throughput reduction.** The old generic prompt (cycle §2–§3)
instructs one session to "Repeat task handling until … IN_PROGRESS … returns an empty list"
— a single `--max-sessions 1` session drains the whole assigned claude backlog per 15-min
cycle. The pinned prompt says "Work ONLY task `<id>` … Do NOT loop over other tasks … stop
taking work." Combined with the §3 interim default of 1, the claude headless lane now
completes **at most one task per 15-min cycle**, not the full IN_PROGRESS list. The audit
anticipated "slower drain" for the single-threaded interim but described looping-all, not
one-per-cycle. This is a real behavior change the report does not call out. **Fix:** document
the new per-cycle throughput characteristic (and that re-raising `--max-sessions` restores
concurrent drain, one task per session), or have the launcher pin more than one lease to a
single session if that is desired. Not a correctness bug; a throughput/behavior regression
worth an explicit decision.

### MINOR

- **m1 — steal is TTL-only, not "expiry + pid liveness" as the task worded.** The slice
  follows the *audit's* design (release on clean exit; TTL expiry as the crash fail-safe),
  which is defensible, but the task text said "stale-lease steal by expiry + pid liveness"
  and the implementation never probes owner-pid liveness (a dead owner's task is held the
  full 30-min TTL). The test comment "stolen by pid liveness fail-safe (expiry)"
  (`test_crashed_owner_lease_is_stolen_after_ttl`) mislabels TTL expiry as pid liveness —
  correct the comment. Acceptable as-is per the audit; note the semantic gap.
- **m2 — `_quota_lane_candidates("claude")` is queried twice per cycle** (once inside
  `_quota_lane_check` @1941, once in the new claude block), an extra DB read per launcher run.
  Negligible, but could reuse the candidate list already computed.
- **m3 — dangling decision citation.** The new comments cite `OWNER-DEC-CBE-20260915`, but
  `decisions/2026-09-15_owner_continuous_book_evolution.md` does not yet exist in canonical
  (it is another slice's §69 deliverable; the id currently appears only in sibling review/
  report artifacts). Ensure that decision record lands so the citation resolves.
- **m4 — `no_unpinned_claude_task` skip reason can fire for benign unassigned-only backlog.**
  The claim filters to `assigned` tasks; if `claude_work_available()` reports `any_work` from
  unassigned BACKLOG/TODO rows while no *assigned* task exists, the lane skips with
  `no_unpinned_claude_task`. Harmless (the router assigns later), but the reason label reads
  like a contention event rather than "nothing assigned yet."

---

## Tests (criterion 4)

- The §70 / audit-outline tests are **present and meaningful** in
  `tests/test_run_agent_orchestration_fanout.py` (8 tests): distinct-task claim before spawn;
  `--max-sessions 3` bound to a disjoint 3-set from 5 tasks; second launcher cannot reclaim a
  pinned task (helper + end-to-end, asserts `skipped`/`no_unpinned_claude_task`/no slots);
  crashed owner stolen only after the 30-min TTL (29 min → False, 31 min → True); owner tuple
  persisted + clean release removes the row; exec key distinct from router key; pinned prompt
  names one task and drops the "for every IN_PROGRESS" loop; env export present for claude,
  absent for codex. Lease-layer tests exercise the real tmp `spawn_leases` (not over-mocked).
- **Coverage gap (ties to M1):** no test asserts the fail-open branch (`candidate_status !=
  "ok"`) spawns at most one session — precisely the path M1 leaves unsafe. Add one.
- Test/impl signatures verified compatible with canonical (`_run_agent_with_session_lease`
  arity, `GATED_AGENTS = {"codex","claude"}`, stubbed gates). Summary line
  "196 passed in 31.41s" is plausible; **not independently re-run here** (running requires
  applying the patch, out of scope for a READ-ONLY review). The `test_codex_model_tiers.py`
  stub-lambda updates are correct (new optional arg threaded through).

## Docs (criterion 5)

- Comments are English, dated, and mark supersession without deleting history: the PS1 keeps
  the old OWNER-2026-06-09 comment and adds a dated `SUPERSEDED 2026-09-15` note; the registry
  and prompt add cited `OWNER-DEC-CBE-20260915 §24/§35` blocks; `build_prompt` retains the
  generic branch alongside the pinned branch. Report is thorough and honestly lists the
  not-done items (Kimi lane N/A on this base; live re-registration = ops boundary).
- The report's claim that the fail-open branch degrades to a single session (see M1) is
  **inaccurate** vs the code — correct the report when fixing M1.

## Recommended next steps
1. (B1) Rebase the PS1 `-ClaudeMaxSessions` hunk onto canonical HEAD; re-verify `git apply
   --check`.
2. (M1) Clamp `session_count = 1` on `candidate_status != "ok"` for the claude lane; add the
   regression test; correct the report wording.
3. (M2) Document the one-task-per-cycle single-session behavior (or intentionally revise it).
4. Keep the §3 interim `--max-sessions 1` default until M1/M2 are resolved and the fan-out
   suite has one clean week, then re-register with `-ClaudeMaxSessions 3`.
