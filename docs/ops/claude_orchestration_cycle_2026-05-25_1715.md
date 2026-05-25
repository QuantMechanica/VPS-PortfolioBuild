# Claude Orchestration Cycle — 2026-05-25 15:15Z (1715 local)

61st consecutive idle cycle for Claude (no IN_PROGRESS claude tasks; router
returned `no_routable_task`).

## Health snapshot

- Overall: **FAIL** (3 FAIL / 2 WARN / 14 OK). checked_at = 2026-05-25T15:15:37Z.
- FAILs (all flat vs 1700):
  - `p2_pass_no_p3` = 127 (flat — 61st cycle).
  - `unbuilt_cards_count` = 832 (flat — **10th consecutive cycle**; same
    cluster QM5_1071/1072/1073/1074/1075/1076/1077/1078/1079/1083).
  - `p_pass_stagnation` = 0 P3+ PASS verdicts / 12h (flat).
- WARNs:
  - `mt5_worker_saturation` = 8/10 — **11th consecutive cycle** (T1 + T10
    absent for 61st / 11th cycle respectively).
  - `unenqueued_eas_count` = 9 (flat — same 9 EAs).
- `pump_task_lastresult` OK exit 0 — 34th consecutive clean cycle.
- `codex_auth_broken` OK; auth_age = **147.5h** (~6.15 days clean).
- Disk D: **138.5 GB (−1.0 vs 1700's 139.5)** — **fourth consecutive cycle
  of ≥1 GB drop** (140.7 → 139.5 → 138.5; cumulative −2.2 GB over the last
  two cycles vs prior 4-cycle band of −0.7 / cycle). Threshold still clear
  (25 GB FAIL); ~113.5 GB headroom.

## MT5 queue — sustained second-wave growth (fourth hour)

- pending = **961** at health snapshot (15:15:37Z); spot-check ~60s later
  showed **969** rows — queue is actively growing this cycle.
  Trajectory across the second-wave window: 525 → 643 → 689 → 742 → 831 →
  920 → 933 → 936 → **961** (+25 vs 1700; cumulative +436 since 1445).
- active = **8 of 8 alive terminals** — **all on QM5_10144** (created
  `2026-05-25T12:42:51+00:00`). T6 has now joined the claim sweep (1700
  showed 7-of-8 with T6 idle; this cycle T6 claimed NZDCHF.DWX):
  - T2 GBPJPY.DWX  (updated 15:06:32Z)
  - T3 NZDJPY.DWX  (15:16:04Z)
  - T4 GBPCHF.DWX  (15:05:31Z)
  - T5 NZDCAD.DWX  (15:13:10Z)
  - T6 NZDCHF.DWX  (15:15:55Z) **newly joined**
  - T7 GBPNZD.DWX  (15:06:53Z)
  - T8 GBPUSD.DWX  (15:07:07Z)
  - T9 GDAXI.DWX   (15:08:38Z)
- pwsh workers −1 (120 → **119**).
- fresh work_item logs −1 (10 → **9**) — settle continues, back to
  pre-surge baseline.

## QM5_10260 dispatcher latency — thesis carry-forward

- QM5_10260 Q02 work_items NDX.DWX / WS30.DWX / SP500.DWX still
  `claimed_by=null`, `status=pending`, `created_at=2026-05-25T12:43:15+00:00`
  — **~152 min queued** (~2.53h; longest dispatcher dwell of the idle
  window for these custom-symbol rows; 7th consecutive cycle).
- T6 picking up QM5_10144 NZDCHF.DWX rather than QM5_10260's NDX/WS30/SP500
  this cycle further confirms the 1700 revised thesis: the dispatcher is
  still sweeping QM5_10144's symbol fan-out, not stepping to the next
  created_at-newer EA.
- Pending NDX/WS30/SP500 totals: NDX **93**, WS30 **69**, SP500 **72** —
  QM5_10260's three rows are not unique stalls.
- **Oldest pending row in the queue**: still
  `2026-05-24T05:38:53+00:00` (QM5_10010 EURUSD.DWX) — **~33h 37m** since
  creation. QM5_10010 / QM5_10012 / QM5_10041 Q02 pending rows from that
  timestamp remain unclaimed.
- **361 of 961 pending rows** at or older than QM5_10260's 12:43:15Z stamp
  (vs 368/936 at 1700) — relative depth in the queue holds at ~38%.

OWNER-class signal carry-forward: the dispatcher's EA-grouping selection is
stranding 33-hour-old QM5_10010/10012/10041 rows under newer enqueue
bursts. Inspect `tools/strategy_farm/farmctl.py` `claim_work_item` /
dispatcher loop for created_at weighting vs EA-grouping behaviour.

## Router state

- Claude: 0 running / max 3 — list-tasks empty (61st cycle).
- Codex: 0 running / max 5.
  - 3 APPROVED build_ea (priorities 30 / 35 / 40):
    - `09f78f65` priority 30, stale since `2026-05-23T18:07:22Z` =
      **45.14h** (oldest stale APPROVED of the idle window).
    - `96bbfa22` priority 35.
    - `9982c1f4` priority 40.
  - 2 APPROVED ops_issue assigned to codex (`9c34e720` + `231d6f8f`,
    priority 35, stale since 2026-05-23T19:51Z).
  - 1 REVIEW ops_issue assigned to codex — `3854cd8b` priority 80,
    `updated_at=2026-05-25T10:52:48+00:00`, raw dwell vs checked_at
    15:15:37Z = **~262.8 min, ~4.38h** — **8th consecutive idle cycle**
    with no `updated_at` movement; remains the longest single-task REVIEW
    dwell of the entire idle window.
  - 1 APPROVED ops_issue **still unassigned** —
    `0bf5dc87-dec2-4617-b740-9efb5f1d487d` (priority 90,
    `task_type=ops_issue`, `assigned_agent=null`, created
    `2026-05-25T14:15:25+00:00` = **~60 min unrouted**; second cycle in
    `APPROVED + assigned_agent=null`). Payload is the Q02→Q03 pump bug fix
    for `farmctl.py:3251 / :7882 / :6152` (matches memory entry
    `project_qm_q02_q03_pump_bug_2026-05-25`). Router cannot auto-route an
    APPROVED ops_issue without assigned_agent — needs OWNER (or a router
    policy update) to assign codex.
- Gemini: 1 IN_PROGRESS research_strategy (`f5043456`, priority 20) / 5
  FAILED.
- Replenishment frozen
  (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`);
  `strategy_backlog=992`, `ready_approved_cards=0` from router payload
  (well above the 5-card floor).

## Other chronic markers (carry-forward)

- `zerotrade_rework_backlog` OK — **19th consecutive cycle**.
- `source_pool_drained` OK 12 flat.
- `cards_ready_stagnation` OK (1 source waiting on in-flight cards).
- `quota_snapshot_fresh` OK (codex=47s, claude=47s).
- Research-ready (992) → unbuilt (832) pipeline: auto-build pickup still
  has not begun on the freshly-released 992 ready_approved_cards tier
  (10th consecutive cycle of `unbuilt_cards_count=832` flat).

## Recommendations (carry-forward, no new ones)

1. **QM5_10260 dispatcher escalation** — EA-grouping selection still the
   binding constraint; T6 joining QM5_10144's sweep this cycle reaffirms
   the thesis. The OWNER-class signal is the 33-hour-old
   QM5_10010/10012/10041 strandings, not QM5_10260 specifically.
2. **`0bf5dc87` priority-90 ops_issue** — second cycle unrouted; needs an
   assigned_agent. Payload is the Q02→Q03 pump bug fix.
3. **`3854cd8b` REVIEW close-out triage** — 4.38h single-task REVIEW
   dwell; priority-80 daemon slot has now been held >4h.
4. **Research-ready (992) → unbuilt (832) pipeline watch** — 10th
   consecutive flat cycle; still no auto-build pickup evidence.
5. **Enqueue-vs-drain trajectory** — pending growth resumed (+25 vs 1700;
   spot-check showed +33 within a minute of the snapshot); still no net
   drain across the wave that began at 1445.
