# Adversarial Review — slice `i5_orchestration_health`

Reviewer: Claude (adversarial, read-only except this file). Date 2026-09-15.
Patch: `scratchpad/patches_i/i5_orchestration_health.patch` (2388 lines).
Verdict: **ACCEPT_WITH_FIXES** — no blocking defect, no RED boundary crossed; two Major
accuracy corrections and one Minor design note before the orchestrator relies on the docs.

## What was verified GREEN

- **`git apply --check` clean** against current HEAD `4aaedf94db` (no conflicts).
- **Tests pass**: `pytest test_orchestration_health_readmodel.py test_stale_task_dispositions.py
  test_mission_control_v2_data.py -q` → **32 passed** (re-run from the worktree).
- **DB schema matches every query.** `agent_tasks`, `spawn_leases`,
  `agent_task_transition_ledger` columns all present; `required_skills_json`,
  `payload_json`, `verdict`, `assigned_agent`, `owner_pid`, `expires_at` etc. all exist.
- **Read-only DB access, no farm-DB writes.** Both new modules open sqlite with
  `?mode=ro` + `PRAGMA query_only=ON`. No `INSERT/UPDATE/DELETE/commit` in either module.
  `--apply` only shells `agent_router.py` (the sanctioned verb); the auditor ran only
  `--classify` (read-only). No task registered, no lane started.
- **Read-model determinism / idempotency.** Ran the generator twice to a temp output:
  content byte-identical **except** `generated_at_utc` and two live-measurement floats
  (`research_guard.scratch_free_gb`, `free_ram_gb`) that drift by bytes — genuine live
  disk/RAM readings, correctly measured not fabricated. All orchestration content
  (task states, throughput, stale, critic, routing, kimi, quota flags) is stable.
- **Classifier determinism + honesty.** Re-ran `--classify`: **399 rows** (326 TODO + 73
  BLOCKED), identical counts PARK 275 / KEEP 59 / COMMISSION 49 / CLOSE 16. Verified the 16
  CLOSE rows against the live DB: **16/16 genuinely carry an `owner-retire` marker** in
  payload/verdict. **0 "Way-to-25" keyword survivors** in TODO/BLOCKED — matches the MD's
  honest "CLOSE is driven by owner-retired ea_ids, not the abolished-doctrine keyword".
- **EVIDENCE_MISSING discipline.** `_critic_chain` / `_kimi_telemetry` / MC
  `load_orchestration_health` all emit `present:false` + `degraded_reason:"EVIDENCE_MISSING"`
  on absent inputs; the MC schema addition is an **optional, permissive** `object` property
  (not in `required`) — contract stays valid when the read-model is absent (test-covered).
- **No RED touches.** No gate-threshold/qualification redefinition, no
  T_Live/AutoTrading/FTMO-purchase/live-deployment logic, no sealed-artifact or dated-decision
  in-place edit, no secrets. `qualified pool` / `ftmo status` occurrences are descriptive prose.
- **Item-4 fix confirmed.** The quota-driven same-vendor critic reduction is truthfully
  recorded per-receipt AND now surfaced in Mission Control via
  `critic_chain.{cross_vendor_false,same_vendor_share,independence_degraded}` + health flag
  `critic_same_vendor:4/5`. Live read-model reproduces 5 completed / 4 same-vendor / degraded=true.

## Findings

### Major 1 — applier + disposition MD claim update-task "appends" a verdict; it OVERWRITES
`agent_router.py` `_update_task_once` executes `SET ... verdict=COALESCE(?, verdict) ...`
(line 2903). Because `--apply` always passes a non-null `--verdict`, COALESCE returns the
NEW value — the prior task-annotation verdict is **replaced, not appended**. The applier
docstring and `STALE_TASKS_DISPOSITION_2026-09-15.md` both assert "CLOSE/PARK use
`update-task`, which **appends** a verdict; existing verdicts … are untouched." That is
factually wrong. On `--allow-candidate-park` the 40 build_ea rows carrying
`PRECONDITION_HOLD_…MAGIC/REGISTRY` verdicts would lose that verdict text (their
`payload_json` detail is untouched, so it is recoverable — not a data-loss catastrophe, and
not the ROT "verdict/trade-stream" evidence class — but the safety claim as written misleads
the operator). Not blocking (no `--apply` run; task-annotation field, not a gate verdict or
trade stream; candidate-gated; reversible via re-enqueue). Fix: change "appends" →
"overwrites the task-lifecycle verdict annotation (payload_json and gate/trade evidence
untouched)" in both the module docstring and the disposition MD.

### Major 2 — `ORCHESTRATION_HEALTH_2026-09-15.md` §15/§17 narrative overstates vs its own read-model
The report says "Every number below is reproducible from `orchestration_health.json`", then
asserts states its cited source contradicts:
- §15: report "`fetch_status=ok` … plan Allegro, rolling-5h/7d used_ratio 0.0/0.0". Live
  `kimi_quota_state.json` + read-model: `fetch_status=auth_error` (`error:"token_stale"`),
  `plan:null`, rolling ratios `null`, reusing `last_ok` (Allegro/0.0). The auth_error stamp
  is 16:11Z; the read-model file was written 17:58Z, so the "ok" claim was already stale at
  write time.
- §17: report "`research_guard()` live: **allowed=true** … RAM 30 GB free … research is no
  longer indefinitely blocked". Live read-model: `allowed:false`,
  `reasons:["RAM_LOW:13.4GB<14.0GB free"]`, `free_ram_gb:13.35`. The guard is RAM-gated and
  currently blocking; "30 GB free" matches neither the floor (14 GB) nor the measurement.
RAM/token volatility explains drift after the snapshot, and the **machine read-model itself
is honest** (records auth_error + last_ok reuse, allowed=false + reason). The defect is the
static MD narrative presenting a transient/optimistic state as the settled "final state".
Fix: reconcile the §15/§17 prose to the read-model (auth_error/last_ok fallback; RAM-gated,
scratch-disk-unblocked-but-RAM-thin), or stamp both as RAM/token-volatile snapshots.

### Minor 1 — read-model surfaces null Kimi capacity during auth_error instead of last_ok
`_kimi_telemetry` reads `plan`/`rolling_*` from the top-level `q` (null during auth_error)
rather than falling back to `q.last_ok` for display. It honestly exposes
`quota_fetch_status:auth_error` + `last_ok_present:true`, so nothing is fabricated, but
Mission Control shows null capacity during a fallback window — slightly short of the §15
goal "show actual Kimi capacity". Consider surfacing `last_ok` ratios when the live fetch
is in fallback (clearly labelled as reused).

## Boundary / scope compliance
READ-ONLY honoured (only this review file written; generator/classifier re-runs went to
scratch temp outputs). No task registered, no lane started, no `--apply`, no farm-DB write.
`red_boundary_crossed = false` — the update-task verdict overwrite is the sanctioned
router lifecycle verb (GRÜN), not the ROT gate-verdict/trade-stream class.
