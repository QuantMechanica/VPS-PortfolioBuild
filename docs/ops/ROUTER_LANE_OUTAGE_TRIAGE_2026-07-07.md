# Router & Agent-Lane Outage — Triage and Fixes (2026-07-07)

Status: RESOLVED (3 code fixes committed, 1 scheduled-task setting raised).
Discovered while investigating why two OWNER-mandate agy video tickets
(fe1704fc, ae6c63e6, enqueued 2026-07-06 19:54Z) still sat unassigned in TODO
10+ hours later.

Three independent, mutually masking failures:

## 1. Agent router silently dead since 2026-07-05 ~18:00 (perf regression)

- Symptom: `QM_StrategyFarm_AgentRouter_5min` LastTaskResult 267014
  (0x41306 = terminated at ExecutionTimeLimit PT2M) on every tick; last
  completed router log `agent_router_task_20260705T18*.json`. No ticket
  routing, no 6h stale-IN_PROGRESS release since then.
- Root cause: `farmctl.ready_strategy_card_inventory` validates every approved
  card and each `prebuild_validate_card` call re-parsed both registry CSVs
  (magic_numbers.csv now 14,581 rows after the 07-06 resurrection-wave regen;
  42ms/parse) and re-globbed cards_approved (2,905 cards). Measured: one
  inventory = **253.4s** — the growth of cards x registry pushed a
  quadratic-cost path past the 120s task limit. Faulthandler stack dump
  pinpointed `farmctl.py:_read_csv_dicts_if_exists` under
  `prebuild_validate_card` (probe: scratchpad router_hang_probe.py).
- Fix (commit 9648f1b5c): (mtime_ns,size)-keyed caches for CSV reads, the
  card-independent magic-duplicate scan, ea_id→slug index, and the
  cards_approved name listing. Inventory **253s → 7.7s** with identical counts
  (total 2454 / approved 2905 / ready 2454 / blocked 451). Task limit raised
  PT2M → PT10M (MultipleInstances=IgnoreNew) as growth headroom.

## 2. gemini/agy lane broken since the 2026-07-02 agy update

- Symptom: every gemini orchestration exec exits 1 in ~11s. Live log
  (`gemini_orchestration_slot1_20260707T060001Z.live.log`): the CLI dumps
  `Unknown arguments: dangerously-skip-permissions, ... print-timeout, ...
  add-dir` + Node/yargs usage. Slots without work reported ok:true, so the
  break stayed invisible until the first real ticket went IN_PROGRESS
  (3b3332e3, 07-05 13:32Z) — which then hung 40+ h because fix #1 had also
  killed the stale-release.
- Root cause: agy.exe (Go shim, updated 07-02 20:59Z) forwards argv verbatim
  to its embedded Node gemini-cli; the updated Node payload dropped the
  claude-style flags. The shim's own `--help` still advertises them —
  misleading. Current Node surface (from the usage dump): `-y/--yolo`,
  repeatable `--include-directories`, `-p`, `-m/--model`; no print-timeout.
- Fix (commit c9f7d7f80): `command_for("gemini")` rewritten to
  `--yolo` + `--include-directories` per dir + `-p` pointer; session bound by
  the runner's own `proc.wait(timeout_minutes*60)` (default 240m) instead of
  the removed `--print-timeout`.

## 3. codex lane starvation deadlock since 2026-07-04 00:15

- Symptom: `lane_codex_heartbeat.json` frozen at 07-04 00:15 (78h);
  no codex orchestration result JSON written since, though the scheduled task
  fires every 15 min with LastResult 0. Router `_eligible_agents` skips lanes
  with heartbeat older than 2h → review tickets (prio 70) unroutable.
- Root cause (design flaw, self-reinforcing): the empty-spawn guard
  `_agent_tasks_work_available` counted only tickets **assigned** to the agent
  (TODO/IN_PROGRESS) plus unrouted **BACKLOG** — but unassigned tickets sit in
  **TODO**. Chain: lane drains → guard skips before the heartbeat write →
  heartbeat crosses 2h → router stops assigning → guard sees no work forever.
  The gemini lane escaped only because a stuck IN_PROGRESS ticket kept its
  work-check truthy (and its heartbeat writes happened on failing spawns).
- Fix (commit c9f7d7f80): (a) guard counts unassigned TODO as routable work;
  (b) heartbeat is written at `run_agent` entry BEFORE any guard — heartbeat
  semantics = "lane infrastructure alive", not "lane busy". Stuck-broken lanes
  remain covered by the router's 6h stale-IN_PROGRESS release (which fix #1
  restored).

## Verification & recovery sequence

- Manual router tick post-fix: exit 0 in seconds; released the 40h-stale
  gemini ticket and routed 2 gemini slots (3b3332e3 re-route + OWNER scalping
  ticket fe1704fc). Review tickets await a fresh codex heartbeat — the next
  scheduled codex orchestration writes it pre-guard, then the 5-min router
  assigns; no manual codex/agy exec sessions needed (Operating Rules 07-03).
- Watch item: first post-fix gemini exec must produce returncode 0 and a
  research artifact; if the Node surface differs further, iterate on
  `command_for` (the shim forwards everything verbatim).

## Lessons

- "Scheduled task fired with LastResult 0" ≠ "lane works": empty-slot runs
  report ok:true. Lane health checks must assert on EXEC results
  (result JSON `ok` + returncode of runs that actually spawned).
- Auto-updating agent CLIs (agy) can silently change their argument surface;
  the wrapping shim's --help is not evidence for the payload's surface.
- Heartbeats written after work-availability guards invert their meaning and
  create bootstrapping deadlocks; liveness signals belong before gating.
- O(cards x registry) validation cost grows with factory success; controller
  paths that run per-tick need caches keyed on file identity, not repeated
  parses.
