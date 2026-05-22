# Strategy Farm — Remediation Plan

Date: 2026-05-22
Status: ACTIVE PLAN
Author: Claude (operation lead)
Basis: end-to-end analysis of the strategy farm (pipeline, sourcing/build,
orchestration/health) — 2026-05-22.

## Context

The farm is well-engineered but **is not producing its product.** Mission =
5 distinct Q11-PASS EAs; current = **0**, with **0 P3+ PASS verdicts in 12h+**.
Meanwhile the front-half holds ~1,600 "approved" Strategy Cards (of which
`ready_approved_cards` = **0** — all blocked) and a 10-terminal factory runs
flat out. The machine measures motion (MT5 saturation, card volume), not
output. Five structural problems cause the 0-output state; this plan sequences
the fix.

Discipline rules that bind the whole plan:
- **Do not loosen any gate** (Q08/Q11 stay hard real-evidence) to move numbers.
- **Keep `Model=4`** (every real tick) — OWNER decision 2026-05-22.
- **Do not start a later phase before its gate is green** (see Sequencing).

## Success definition

The farm is "fixed" when: at least one EA travels card → G0 → build → P2 →
… → Q11 with **real evidence at every gate**; `p_pass_stagnation` is OK; the
cockpit headline tracks gate-advancement, not saturation; and the hygiene
health checks are green.

---

## WS-0 — Prove the pipeline (P2 → first real verdict)  ·  GATE

**Problem #2 — P2 is the wall.** Real-tick 6-year D1 backtests exceed the
timeout; nothing reaches P3+. The pre-screen policy (task `a6a0679b`) is
implemented but **unproven**.

**Owner:** Claude verifies; Codex fixes whatever the pre-screen surfaces.

**Actions:**
- Watch the next P2 **pre-screen** runs (6-month window, `Model=4`, ≤30 min)
  complete and emit a real `PASS / FAIL / ZERO_TRADES` verdict — not
  `timeout-INVALID`.
- Confirm a pre-screen PASS requeues for the full run, and the full run
  completes inside the raised timeout (2–4h tester cap, 360-min dispatcher cap).
- Target EAs already queued: QM5_10075 / 10076 / 10079 / 10260 / 2001.

**Key files:** `tools/strategy_farm/farmctl.py` (P2 prescreen logic ~2705–2750,
verdict derivation ~1317), `framework/registry/tester_defaults.json`.

**Acceptance:** ≥1 EA produces a real P2 verdict under the new policy;
`p_pass_stagnation` clears, or is explained by genuine strategy FAILs (not
timeouts/INVALID).

**This is the gate.** WS-2 and WS-3 do not start until WS-0 is green.

---

## WS-1 — Hygiene & de-risking  ·  START NOW (parallel, low risk)

**Problem #5 — no garbage collection.** Cruft accumulates everywhere; the
branch has diverged badly.

**Owner:** Codex.

**Actions:**
- **1a — Commit & merge.** Commit today's uncommitted working tree (~13 modified
  + 3 new + 2 deleted files — already routed via Codex window prompt). Then
  reconcile `agents/board-advisor` with `origin/main` (**224 commits behind**) —
  rebase/merge-forward so the work lands in `main`.
- **1b — GC loop.** Fold a cleanup pass into `QM_StrategyFarm_Repair_Hourly` (or
  a new daily task): delete logs >7d, archive/delete stale `queue/*.md` prompts
  (~21 MB), remove orphaned `framework/registry/ea_id_registry.csv.*.tmp` files.
- **1c — Freeze generic card production.** Disable the `agent_router.py`
  replenishment that spawns generic `research_strategy` tasks — the
  reservoir gate (`ready < 5`) is meaningless against a 1,600-card backlog.
  Triage/retire the stale generic research tasks that keep re-surfacing in
  REVIEW. The Edge Lab is the input model now (WS-4).

**Key files:** `tools/strategy_farm/agent_router.py` (replenish ~410–472),
`tools/strategy_farm/run_pump_task.py` / repair path.

**Acceptance:** working tree committed; branch ≤ a small, known delta from
`main`; GC sweep runs and disk/cruft checks are green; no new generic
`research_strategy` tasks created.

---

## WS-2 — Fix the evidence / verdict taxonomy

**Problem #3 — `INVALID` is a garbage bin.** Timeout, worker death,
no-real-ticks, retries-exhausted and malformed reports all collapse into one
verdict — a broken strategy is indistinguishable from a crashed terminal. This
violates the "evidence over claims" Hard Rule.

**Owner:** Codex implements; Claude reviews the taxonomy design.

**Actions:**
- Split `INVALID` into `INFRA_FAIL` (timeout / worker or terminal death /
  no-real-ticks / malformed report — **does not count against the strategy**,
  eligible for a clean retry) vs genuine strategy verdicts (`FAIL`,
  `ZERO_TRADES`, `MIN_TRADES_NOT_MET`).
- Separate the retry budget: infra failures get clean retries; strategy
  verdicts are terminal. Today one infra fail + two timeouts burns the budget.
- Carry **evidence provenance** on the verdict (real-MT5 vs phase-runner vs
  proxy) so Q07/Q08/Q11 enforce real-evidence at verdict time, not only at merge.

**Key files:** `farmctl.py` — `_derive_verdict_from_summary` (~1317),
`_derive_phase_runner_verdict` (~1230), timeout/retry logic (~2800–2886).

**Acceptance:** verdicts distinguish infra vs strategy failure; retry budgets
are separate; Q07/Q08/Q11 reject non-real-MT5 evidence at the verdict step.

**Depends on:** WS-0 (need real verdicts to ground the taxonomy).

---

## WS-3 — Tame the orchestration

**Problem #4 — fragile monolith.** 8+ scheduled tasks hammer one SQLite DB
with no mutual exclusion; the pump is a ~13-job monolith on a 10-min timeout
with an invisible codex-auth circuit breaker. Source of most of today's
symptoms.

**Owner:** Codex implements; Claude reviews.

**Actions:**
- **Stagger** the scheduled tasks (router :01, pump :03, health :07, …) to cut
  SQLite write contention.
- **De-monolith the pump** — give each sub-job an independent timeout + log line
  so one hang does not kill the whole cycle.
- **Make the codex-auth circuit breaker explicit** — log + health signal +
  cockpit banner, not a silent cap-zero.
- **Add a stuck-task timeout** so the router/reservoir cannot deadlock on dead
  `IN_PROGRESS` tasks.

**Key files:** `tools/strategy_farm/run_pump_task.py`, `farmctl.py` pump
(~4946+), `agent_router.py`, the Windows scheduled-task triggers.

**Acceptance:** scheduled tasks staggered; pump sub-jobs independently timed;
auth circuit breaker visible; no router deadlock on dead tasks.

**Depends on:** WS-0 + WS-2 (do not refactor orchestration while the pipeline
is unproven and the evidence layer is still changing).

---

## WS-4 — Re-point the farm at the mission

**Problem #1 — inverted funnel; wrong success metric.** The farm optimizes
saturation/volume; the mission is 5 proven EAs. A saturated factory with 0
survivors reads as "succeeding."

**Owner:** Claude (metric/IA + Edge Lab), Codex (implementation).

**Actions:**
- **Redefine the cockpit/health headline:** track *EAs advancing per gate
  toward Q11* and *distinct Q11 candidates* as the primary signal; MT5
  saturation becomes a secondary throughput stat. Add a health "funnel
  advancement" check.
- **Make the Edge Lab the primary input** — 4 directions, sequential, screened
  (charter `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`). Park the ~1,600-card
  generic backlog as cold storage, not active feed.
- **Run Edge Lab Direction 1 through the fixed pipeline** as the end-to-end
  proof: QM5_10717 / QM5_10718 — card → G0 → build (per the basket design
  `docs/ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md`) → P2 → … → Q11.

**Key files:** `tools/strategy_farm/render_cockpit.py`, `health.py`,
`docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`.

**Acceptance:** cockpit headline = gate advancement; Edge Lab is the live input
path; QM5_10717/10718 are moving through the pipeline with real evidence.

**Depends on:** WS-0 (the metric redesign can start anytime; the Edge Lab build
proof waits on a working pipeline).

---

## Sequencing

```
NOW  ──►  WS-0 (prove P2)   ┐
         WS-1 (hygiene)     ┘  run in parallel
WS-0 green ──►  WS-2 (verdict taxonomy)
WS-0 + WS-2 green ──►  WS-3 (orchestration)
WS-4: metric redesign anytime; Edge Lab build proof after WS-0
```

## Verification (end-to-end)

- **WS-0:** `farmctl.py work-items --ea <id>` shows a real P2 verdict;
  `farmctl.py health` → `p_pass_stagnation` OK.
- **WS-1:** `git status` clean; `git rev-list --count HEAD..origin/main` small;
  disk/cruft health checks green.
- **WS-2:** a forced timeout yields `INFRA_FAIL` + a clean retry; a real losing
  backtest yields `FAIL`; pipeline/runner contract tests green.
- **WS-3:** scheduled-task triggers staggered; pump log shows per-sub-job
  timing; a simulated codex 401 raises a visible alarm.
- **WS-4:** cockpit first-viewport shows gate advancement; QM5_10717/10718 have
  work_items progressing past P2.

**Whole-farm success:** one EA reaches Q11 with real evidence at every gate.
</content>
