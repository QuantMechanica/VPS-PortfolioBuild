# Claude Orchestration Cycle — 2026-05-25 15:00Z (1700 local)

60th consecutive idle cycle for Claude (no IN_PROGRESS claude tasks; router
returned `no_routable_task`).

## Health snapshot

- Overall: **FAIL** (3 FAIL / 2 WARN / 14 OK). checked_at = 2026-05-25T15:00:21Z.
- FAILs:
  - `p2_pass_no_p3` = 127 (flat — 60th cycle).
  - `unbuilt_cards_count` = 832 (flat — **9th consecutive cycle**; cluster
    identical: QM5_1071/1072/1073/1074/1075/1076/1077/1078/1079/1083).
  - `p_pass_stagnation` = 0 P3+ PASS verdicts / 12h (flat).
- WARNs:
  - `mt5_worker_saturation` = 8/10 (T1 + T10 still absent; T2–T9 alive) —
    **10th consecutive cycle at 8/10**.
  - `unenqueued_eas_count` = 9 (flat — same 9 EAs:
    QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079).
- `pump_task_lastresult` back to **OK exit 0** — last cycle's `267009`
  (`SCHED_S_TASK_RUNNING`) was the transient mid-run artefact predicted at
  1630; no pump regression.
- `codex_auth_broken` OK; auth_age = 147.2h (~6.13 days clean).
- Disk D: **139.5 GB (−1.2 vs 1630's 140.7)** — 12× typical step, **third
  consecutive cycle of >1 GB drop** consistent with sustained tester output
  on the full 8-daemon fleet. Threshold still clear (25 GB FAIL);
  ~114.5 GB of headroom.

## MT5 queue — sustained second-wave growth (third hour)

- pending = **936** (was 831 → 933 → 936 over the last three cycles → +105
  cumulative since 1615; second-wave enqueue continues, no drain yet).
- active = **7** of 8 alive terminals — **all on QM5_10144** (created
  `2026-05-25T12:42:51+00:00`):
  - T2 CADCHF.DWX (updated_at 14:52:19Z)
  - T3 GBPAUD.DWX (15:02:20Z)
  - T4 EURCAD.DWX (14:53:10Z)
  - T5 EURUSD.DWX (15:02:03Z)
  - T7 EURNZD.DWX (15:01:33Z)
  - T8 GBPCAD.DWX (15:03:07Z)
  - T9 EURGBP.DWX (14:57:59Z)
  - T6 alive but **idle** (no active claim this cycle — see dispatcher
    finding below)
- pwsh workers +2 (118 → 120).
- fresh work_item logs −2 (12 → 10) settle continues.

## Dispatcher — strong new evidence the queue is NOT FIFO by created_at

This is the cleanest single-cycle test of the dispatcher-latency thesis yet:

1. **QM5_10260** Q02 work_items NDX.DWX / WS30.DWX / SP500.DWX, all
   `created_at=2026-05-25T12:43:15+00:00`, `claimed_by=null`, `status=pending`
   — **~137 min queued** (longest dispatcher-latency dwell of the idle window
   for these custom symbols).
2. **QM5_10144** active claims (7×) all have `created_at=2026-05-25T12:42:51+00:00`
   — exactly **24 seconds before** QM5_10260's enqueue stamp.
3. **Oldest pending row in the queue**:
   `2026-05-24T05:38:53+00:00` (QM5_10010 EURUSD.DWX) — **~33h 22m** since
   creation. There are pending Q02 work_items from QM5_10010 / QM5_10012 /
   QM5_10041 that have been waiting **far longer** than the QM5_10144
   12:42:51Z burst, yet QM5_10144 is the EA the dispatcher is sweeping right
   now.
4. There are **91 pending NDX.DWX, 68 pending WS30.DWX, 70 pending SP500.DWX**
   in the queue — QM5_10260's three custom-symbol work_items are NOT unique
   stalls (the symbol whitelist sub-thesis is not the binding constraint;
   plenty of NDX/WS30/SP500 work is queued and equally unclaimed).
5. By created_at order, **368 of 936 pending rows are at or older than
   QM5_10260's 12:43:15Z stamp** — the EA is roughly 39% deep in the
   created_at-ordered queue.

**Revised dispatcher thesis**: the dispatcher selects by EA-grouping (claim a
whole EA's symbol fan-out across all available terminals before moving to the
next EA) rather than by strict created_at FIFO. That explains both:
- QM5_10144 (created 12:42:51Z) fully claimed across 7 terminals while
  QM5_10010 / QM5_10012 / QM5_10041 rows from 2026-05-24T05:38:53+00:00
  remain pending; and
- QM5_10260 not yet getting a single terminal claim despite being only 24s
  newer than QM5_10144 — the dispatcher hasn't moved to the next EA yet.

Operationally this means QM5_10260's NDX/WS30/SP500 should claim a terminal
naturally once the dispatcher steps off QM5_10144 — but the **33-hour-old
QM5_10010 / QM5_10012 / QM5_10041 rows are evidence of a systemic
queue-ordering issue** that hurts every EA enqueued before the most recent
burst. This is OWNER-class signal: prior cycles flagged "dispatcher latency"
on QM5_10260, but the deeper pathology is **older work stranded under newer
enqueue bursts**.

Note: I am **not** filing a new router task — orchestration-cycle reports go
to OWNER via this file; the priority-90 unassigned ops_issue
`0bf5dc87` already addresses the related Q02→Q03 pump bug. Recommend OWNER
inspect dispatcher selection logic
(`tools/strategy_farm/farmctl.py` `claim_work_item` / dispatcher loop) for
created_at weighting vs. EA-grouping behaviour.

## Router state

- Claude: 0 running / max 3 — list-tasks empty (60th cycle).
- Codex: 0 running / max 5.
  - 3 APPROVED build_ea (09f78f65 priority 30 stale since
    2026-05-23T18:07:22Z = **44.70h**; 96bbfa22 priority 35; 9982c1f4
    priority 40).
  - 2 APPROVED ops_issue assigned to codex (9c34e720 + 231d6f8f, priority 35,
    stale since 2026-05-23).
  - 1 REVIEW ops_issue assigned to codex (3854cd8b, priority 80) —
    raw dwell vs checked_at 15:00:21Z = **~247.6 min, ~4.13h** — 7th
    consecutive idle cycle since the field-truth correction with no
    `updated_at` movement; remains the longest single-task REVIEW dwell of
    the entire idle window.
  - 1 APPROVED ops_issue **still unassigned** —
    `0bf5dc87-dec2-4617-b740-9efb5f1d487d` (priority 90, `task_type=ops_issue`,
    `assigned_agent=null`, created 14:15:25Z = ~45 min unrouted).
    Payload diagnoses the Q02→Q03 pump bug at
    `tools/strategy_farm/farmctl.py:3251` and `:7882` (`next_phase_map` only
    carries P-keys) + missing `Q02→Q03` entry in `cascade_phase_map` at
    `:6152`. This matches the existing memory entry
    `project_qm_q02_q03_pump_bug_2026-05-25`. Router cannot auto-route an
    APPROVED ops_issue without an assigned_agent; the deterministic next
    step needs OWNER (or a router policy update) to assign codex.
- Gemini: 1 IN_PROGRESS research_strategy / 5 FAILED.
- Replenishment frozen
  (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`);
  pump's `research_replenish_gate.allow_new_research=false`,
  `strategy_backlog=992` (well above the 5-card floor).

## Other chronic markers (carry-forward)

- `mt5_worker_saturation` 8/10 — **10th consecutive cycle** (T1 + T10 absent
  for 60th / 10th cycle respectively).
- `zerotrade_rework_backlog` OK — **18th consecutive cycle**.
- `source_pool_drained` OK 12 flat.
- `cards_ready_stagnation` OK (1 source waiting on in-flight cards).
- Research backlog: ready_approved_cards = 992 (steady since 1630),
  blocked_approved_cards = 1574, unbuilt_cards_count = 832 flat 9 cycles —
  auto-build pickup still has not begun on the freshly-released 992 ready
  tier (watch next 1–2 cycles for evidence of pump building from that
  reservoir).

## Recommendations (carry-forward, no new ones)

1. **QM5_10260 dispatcher escalation** — original thesis substantially
   revised this cycle: not symbol whitelist, not pure latency; it's
   EA-grouping selection. New OWNER-class signal: 33-hour-old QM5_10010 /
   QM5_10012 / QM5_10041 Q02 pending rows stranded under newer enqueue
   bursts.
2. **`0bf5dc87` priority-90 ops_issue** — needs assigned_agent before the
   router will move it; otherwise will sit indefinitely in
   `APPROVED + assigned_agent=null`. Payload is the Q02→Q03 pump bug fix
   for `farmctl.py:3251 / :7882 / :6152`.
3. **`3854cd8b` REVIEW close-out triage** — 4.13h single-task REVIEW dwell;
   priority-80 daemon slot has now been held >4h.
4. **Research-ready (992) → unbuilt (832) pipeline watch** — no auto-build
   pickup yet from the freshly-released ready tier; watch the pump's
   build-task emission over the next two cycles.
5. **Enqueue-vs-drain trajectory** — pending growth has slowed to +3 over
   the last cycle (933 → 936) but still no net drain across the wave that
   began at 1445.
