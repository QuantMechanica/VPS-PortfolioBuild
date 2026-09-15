# Adversarial review — slice `x1_bc_followups`

Reviewer: board-advisor adversarial reviewer · 2026-09-15 · canonical repo `C:/QM/repo` @ HEAD
`4ad7ab7016` (= the slice's declared worktree base; no rebase drift).
Scope: follow-ups from `review/c1_orchestration_fanout_review.md` (M1, M2, m1) and
`review/b2_portfolio_caps_review.md` (MAJOR-1, MAJOR-3) plus CBE bookkeeping.
Authority: OWNER-DEC-CBE-20260915 (`decisions/2026-09-15_owner_continuous_book_evolution.md`,
landed `a5453d3b94`).
Patch: `…/scratchpad/patches_defg/x1_bc_followups.patch` (1006 lines, 8 files), read in full.
Method: read patch + report + directive + decision record + both source reviews; verified
`git apply --check` against canonical HEAD; grepped canonical for every API/symbol the patch
depends on and confirmed signatures; **ran the slice's tests** in the implementer worktree;
verified cited commit ids and the runtime scheduled-task claim. READ-ONLY except this file.

**Verdict: ACCEPT.** Every M/MAJOR item the slice was commissioned to close is closed
correctly and with meaningful regression tests. Patch applies cleanly, tests pass, no
unauthorized RED boundary is crossed. `red_boundary_crossed = true` for one item —
the `book_reoptimizer` correlation-cap reclassification — which is **explicitly
OWNER-authorized (§7/§8), value-preserving, and recorded**, exactly as the sibling `b2`
slice handled the identical change class. Only minor notes remain; none block apply.

---

## Verification performed

- `git apply --check` on canonical HEAD `4ad7ab7016`: **applies cleanly, exit 0** (all 8 files).
  HEAD equals the declared base, so there is no stale-base risk (contrast c1 B1, which was a
  PS1 file this slice deliberately does not touch).
- **Tests re-run** in the implementer worktree `wf_4fa62b18-d2d-6`:
  - `test_run_agent_orchestration_fanout.py` + `test_book_reoptimizer_advisory_corr.py`:
    **17 passed** (12 fanout + 5 reopt).
  - Regression subset `test_agent_orchestration_lock, _heartbeat, _kimi, dual_book_builders,
    concentration_tail, portfolio_correlation, codex_model_tiers`: **194 passed, 1 skipped**
    (the 1 skip is the pre-existing DXZ-panel skip, as reported).
- API compatibility confirmed against canonical: `acquire_task_exec_lease` returns
  `(bool, dict)` (patch destructures `acquired, lease`); `claim_task_exec_leases(agent,
  ids, limit, *, owner_pid=...)` returns a lease list; `run_agent_slot(...)` positional
  arity matches the chain call; `release_task_exec_lease(lease)` present.
  `risk_diagnostics.build({}, dependence_panel=…, correlation_warnings=…)` and
  `portfolio_correlation.dependence_panel_entry(a, b, pairwise_correlation=r, reference=…)`
  signatures match; `risk_diagnostics.SUPERSEDING_DECISION` / `RISK_DIAGNOSTICS_SCHEMA` exist.
- Confirmed `select_under_aggregate_control` code already emits `ADMITTED_CORRELATION_WARN`
  (landed `589858dc66`) while the pre-patch docstring still said `CLUSTER_CORRELATION_EXCLUDED`
  — so MAJOR-1 is a real stale-docstring fix and the rewrite makes doc match code.
- Verified **every commit id** cited in the OPEN_ITEMS bookkeeping resolves and its subject
  matches the claim: `6019af7a17`/`6ed8ec872e`/`55fb2bf5fc` (Phase A), `a5453d3b94`
  (decision + guard + manifest drift), `589858dc66` (caps advisory), `7139ccf959`
  (research guard), `81718ab2be` (kimi telemetry), `ac2db161ef` (exec leases),
  `4ad7ab7016` (base). No invented ids.
- Verified the runtime claim in `KIMI_INTEGRATION_ARCHITECTURE.md`: scheduled task
  `QM_StrategyFarm_KimiOrchestration_15min` genuinely exists (`Get-ScheduledTask` → State
  `Ready`). The doc's "installed" status is honest.

## RED boundary check

`red_boundary_crossed = TRUE` — one contract-criterion reclassification, **authorized and
recorded**; every other RED line is untouched.

- **`book_reoptimizer.py` pairwise-correlation `--max-corr 0.50` hard cut → ADVISORY.** This
  is the same ROT-class correlation-cap family (audit F6) that `b2` converted for the FTMO
  builder. It is authorized by OWNER-DEC-CBE-20260915 §7/§8 ("the fixed pairwise correlation
  limit … must no longer be treated as absolute Hard Rules"), whose §7 note explicitly requires
  a dated decision record for the correlation relaxation — that record (`a5453d3b94`) exists and
  names this conversion. **Value-preserving:** 0.50 is retained as the advisory reference; the
  new opt-in `--hard-max-corr` (default `None`) reproduces the old hard cut for experiments.
  Recorded in the module docstring, inline comments, `correlation_policy` block, and the slice
  report. Not a silent reclassification; not a violation.
- **`build_book_ftmo.py` change is docstring-only** (lines 252-264) — no behavior change.
- **No other RED touch.** The patch does **not** edit `book_build_guard.py`,
  `gate_manifest.v4.json`, `ftmo_probability_contract.v1.json`, the installer PS1, any gate
  threshold, or the qualification predicate. No T_Live / AutoTrading / FTMO-purchase / live-
  deployment surface (the OPEN_ITEMS section reaffirms these stay ROT/OWNER-only). No verdict,
  work_item, or trade-stream write. No evidence rewrite — all doc edits are additive dated
  sections; history preserved. No credential/secret. The only farm-DB write is the additive
  `agent_task_exec:<id>` exec-lease coordination row, unchanged from the c1-landed design and
  already sanctioned there as GRÜN infra coordination (not a verdict write).

## Directive / task fidelity

- **(1) M1 fail-closed — DONE, matches the task's stated preference.** The x1 task said "pick
  fail-closed with a logged reason unless a test pins the other." On `candidate_status != "ok"`
  the claude lane now returns `skipped` / reason `claude_candidate_query_unavailable` and spawns
  nothing, closing the fail-*open* N×M re-entry c1 M1 identified. Regression test
  `test_candidate_query_failure_fails_closed_no_unpinned_spawn` asserts zero slots spawned.
- **(1) M2 drain — DONE.** A session, after finishing its task, leases the NEXT eligible task
  under a serialized claim lock with `claimed_ids` dedup, draining sequentially until no
  unpinned task remains, `max_tasks_per_session` (env > policy > default 4) is hit, or the run
  time budget expires. Concurrency stays disjoint (never two sessions on one task). Tests cover
  single-session drain, the per-session cap, and no-double-work under 3-way concurrency; the
  renamed `…_concurrent_sessions_and_drains_disjoint` test asserts all 5 tasks drained exactly
  once with `max_sessions == 3`. `max_sessions` now reports the real concurrent count;
  `tasks_worked` added. Restores the throughput c1 M2 flagged as lost under `--max-sessions 1`.
- **(1) m1 test-comment fix — DONE.** The mislabeled "pid liveness" comment is corrected to
  TTL-expiry-only semantics.
- **(2) MAJOR-1 docstring — DONE and accurate** (admit-with-WARN; `CLUSTER_CORRELATION_UNVERIFIED`
  kept fail-closed; account risk budget = remaining hard guard). Matches the landed code.
- **(3) MAJOR-3 reoptimizer advisory — DONE.** Greedy Sharpe selection retained; correlation no
  longer excludes; `--hard-max-corr` opt-in added (default None); output gains a
  `correlation_policy` block and a `risk_diagnostics` block built via `risk_diagnostics.build`
  reusing `portfolio_correlation.dependence_panel_entry` — the same shape as the FTMO builder
  (schema `qm.risk-diagnostics/v1` respected). 5 new tests.
- **(4) OPEN_ITEMS_STATUS — DONE, RESULT-oriented,** with verified commit ids, the interim
  `--max-sessions 1` mitigation + its exit criterion, RAM-44 hold, Kimi lane task, and the
  Kimi `auth_error` telemetry state, D–H in progress / I queued.
- **(5) KIMI_INTEGRATION_ARCHITECTURE annex — DONE and honest** (scheduled task verified present).

## Findings

**Blocking:** none.

**Major:** none. (The deferred items — c1 B1 re-registration to `-ClaudeMaxSessions 3`, and
b2 MAJOR-2 trade-overlap/downside into the dependence panel — are correctly out of this slice's
named scope and documented as ops/Phase-E follow-ups; the reoptimizer panel stays
correlation-only, consistent with the FTMO builder.)

**Minor (notes):**
- **m1 — drain time-budget overshoot.** The chain checks `time.monotonic() >= deadline` only
  *between* tasks; a task already started runs its full per-task `timeout_minutes`, so a chain
  can overshoot the run budget by up to one task duration (worst case ≈ 2× `timeout_minutes`).
  Bounded by the per-task timeout and `max_tasks_per_session`; acceptable for a throughput lane,
  but worth noting for scheduler-cadence assumptions.
- **m2 — per-cycle claude spend rises.** One session now spawns up to `max_tasks_per_session`
  (default 4) claude processes per 15-min cycle instead of one. This is the intended throughput
  restoration and is quota-gated upstream (`_quota_lane_candidates` returns only eligible tasks;
  `CLAUDE_DISABLED.flag` / budget policy still gate), so it is not a quota bypass — but the
  interim `--max-sessions 1` no longer implies "≤1 claude call per cycle."
- **m3 — `book_reoptimizer` output is a free-form OWNER decision report** (`D:\QM\reports\
  book_reopt\reopt.json`), not a schema-validated shared read-model; the added `correlation_policy`
  / `risk_diagnostics` fields are additive and reuse the canonical `risk_diagnostics` shape, so
  no consumer schema is broken. The reoptimizer was not executed in this slice (reads the live
  farm DB / streams) — consistent with the report's "no runtime artifacts written"; the
  diagnostics structure is covered by unit tests instead. No invented numbers.
- **m4 — `_quota_lane_candidates("claude")` is now queried once more per drain step** (inside
  the serialized `_claim_next`), an extra DB read per leased task. Negligible; carried over from
  the c1 m2 note.

## Conclusion

The slice closes c1 M1/M2/m1 and b2 MAJOR-1/MAJOR-3 correctly, with real regression tests that
I re-ran green (17 slice + 194 regression). The patch applies cleanly to canonical HEAD, every
API it depends on matches, and the bookkeeping is honest (all commit ids and the Kimi scheduled
task verified). The single RED-class touch (book_reoptimizer correlation → advisory) is
OWNER-authorized under §7/§8, value-preserving, and recorded — the same disposition the b2 slice
received. **ACCEPT.**
