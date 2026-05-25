# Claude Orchestration Cycle — 2026-05-25 16:00Z (1800 local)

62nd consecutive idle cycle for Claude (no IN_PROGRESS claude tasks; router
returned `no_routable_task`).

## Health snapshot

- Overall: **FAIL** (4 FAIL / 1 WARN / 14 OK). checked_at = 2026-05-25T16:00:17Z.
- FAILs:
  - `p2_pass_no_p3` = 127 (flat — 62nd cycle).
  - `unbuilt_cards_count` = 832 (flat — **11th consecutive cycle**; same
    cluster QM5_1071/1072/1073/1074/1075/1076/1077/1078/1079/1083).
  - `unenqueued_eas_count` = **11** (was WARN 9 last cycle, +2 — escalated
    to FAIL). Reviewed-built EAs without Q02 work_items: QM5_10019,
    QM5_10021, QM5_10028, QM5_10035, QM5_10039, QM5_10043, QM5_10044,
    QM5_10050, QM5_10075, QM5_10076 (+1 truncated in detail string).
  - `p_pass_stagnation` = 0 P3+ PASS verdicts / 12h (flat).
- WARNs:
  - `mt5_worker_saturation` = 8/10 — **12th consecutive cycle** (T1 + T10
    absent for 62nd / 12th cycle).
- `pump_task_lastresult` OK exit 0 — 35th consecutive clean cycle.
- `codex_auth_broken` OK; auth_age = **148.2h** (~6.18 days clean).
- `codex_zero_activity` OK: detail `1 codex, 2 pending` — codex now shows
  1 active task at the health level (router `agents.running` still
  reports 0 for codex; likely a direct-pump worker outside router state).
- Disk D: **137.2 GB (−1.3 vs 1715's 138.5)** — **fifth consecutive cycle
  of ≥1 GB drop** (139.5 → 138.5 → 137.2; ~113.2 GB headroom above 25 GB
  FAIL threshold).

## MT5 queue — second-wave growth continues

- pending = **1067** (+106 vs 1715's 961; cumulative +542 since the 1445
  surge began). Trajectory: 525 → 643 → 689 → 742 → 831 → 920 → 933 →
  936 → 961 → **1067**.
- active = **8 of 8 alive terminals**, **all newly on QM5_10146** (T2
  AUDCHF / T3 CHFJPY / T4 EURCAD / T5 AUDNZD / T6 EURAUD / T7 AUDCAD /
  T8 CADCHF / T9 AUDUSD). T1 + T10 absent.
- QM5_10146 status: 8 active, 12 done, 6 failed, 29 pending — the
  dispatcher is actively sweeping QM5_10146's symbol fan-out.
- pwsh workers −5 (119 → **114**).
- fresh work_item logs −7 (9 → **2**) — sharp drop, consistent with
  fleet now firmly in execution mode (fewer fresh log spawns per minute
  than during settling).

## QM5_10260 dispatcher latency — thesis updated (EA-switch observed)

- QM5_10260 Q02 work_items NDX.DWX / WS30.DWX / SP500.DWX still
  `claimed_by=null`, `status=pending`, `created_at=2026-05-25T12:43:15+00:00`
  — **~197 min queued** (~3.28h; 8th consecutive cycle).
- **Major change from 1715**: the dispatcher has moved off QM5_10144
  (created `2026-05-25T12:42:51+00:00`) and onto **QM5_10146**
  (`work_items.created_at` range `2026-05-24T05:38:57+00:00` →
  `2026-05-25T12:42:52+00:00`). Crucially, QM5_10146's earliest
  work_items are **30h+ older than QM5_10144's earliest** and **31h+
  older than QM5_10260's**. The dispatcher selected QM5_10146 over
  QM5_10260 despite both being eligible after QM5_10144 drained — this
  **falsifies a strict "newest-EA-first" sub-thesis** and is consistent
  with EA-grouping + some non-created_at ranking within eligible EAs
  (priority? attempt_count? parent_task_id ordering? — needs source
  inspection of `claim_work_item`).
- Pending NDX/WS30/SP500 totals: NDX **97**, SP500 **80**, WS30 **69** —
  QM5_10260's three rows are not unique stalls.
- **Oldest pending row in the queue**: still
  `2026-05-24T05:38:53+00:00` (QM5_10010 EURUSD.DWX) — **~34h 21m** since
  creation. QM5_10010 / QM5_10012 / QM5_10041 Q02 pending rows from that
  timestamp remain unclaimed.
- **344 of 1067 pending rows** at or older than QM5_10260's 12:43:15Z
  stamp (vs 361/961 at 1715) — relative depth in the queue ~32%.

OWNER-class signal carry-forward: the dispatcher's EA-grouping +
unidentified-within-EA sub-ranking is stranding 34-hour-old
QM5_10010/10012/10041 rows. The 1800 cycle adds the **EA-switch
observation** to the diagnostic surface — QM5_10146 was preferred over
both QM5_10144 and QM5_10260, so the binding criterion is neither
purely created_at FIFO nor purely "newest fan-out wins". Inspect
`tools/strategy_farm/farmctl.py` `claim_work_item` / dispatcher loop
ranking logic.

## Router state

- Claude: 0 running / max 3 — list-tasks empty (62nd cycle).
- Codex: 0 running / max 5 (router-view); health shows 1 active.
  - 3 APPROVED build_ea (priorities 30 / 35 / 40):
    - `09f78f65` priority 30, stale since `2026-05-23T18:07:22Z` =
      **45.89h** (oldest stale APPROVED of the idle window).
    - `96bbfa22` priority 35.
    - `9982c1f4` priority 40.
  - 2 APPROVED ops_issue assigned to codex (`9c34e720` + `231d6f8f`,
    priority 35, stale since 2026-05-23T19:51Z).
  - 1 REVIEW ops_issue assigned to codex — `3854cd8b` priority 80,
    `updated_at=2026-05-25T10:52:48+00:00`, raw dwell vs checked_at
    16:00:17Z = **~307.5 min, ~5.13h** — **9th consecutive idle cycle**
    with no `updated_at` movement; remains the longest single-task
    REVIEW dwell of the entire idle window.
  - 1 APPROVED ops_issue **still unassigned** —
    `0bf5dc87-dec2-4617-b740-9efb5f1d487d` (priority 90,
    `task_type=ops_issue`, `assigned_agent=null`, created
    `2026-05-25T14:15:25+00:00` = **~105 min unrouted**; third cycle in
    `APPROVED + assigned_agent=null`). Router cannot auto-route an
    APPROVED ops_issue without assigned_agent — needs OWNER (or a
    router policy update) to assign codex.
- Gemini: 1 IN_PROGRESS research_strategy (`f5043456`, priority 20,
  updated_at 2026-05-25T15:57:18Z — moved within last ~3 min, active).
- Replenishment frozen
  (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`).
  **Strategy inventory reverted**: `blocked_approved_cards=2566`,
  `ready_approved_cards=0` (vs 1715's 1574/992 split). The 992-card
  "ready" surge has collapsed back into "blocked" — either a pump
  re-classification or a query-time flip. Worth investigating next
  cycle whether this is the auto-build pickup beginning (consuming
  ready cards) or the readiness flag being revoked.

## Other chronic markers (carry-forward)

- `zerotrade_rework_backlog` OK — **20th consecutive cycle**.
- `source_pool_drained` OK 12 flat.
- `cards_ready_stagnation` OK (1 source waiting on in-flight cards).
- `codex_review_fail_rate_1h` OK 5/26 = 0.19 (vs threshold 0.8).
- `claude_review_starved` OK value 2 (vs threshold 3).
- `quota_snapshot_fresh` OK (codex=27s, claude=27s).

## Recommendations (carry-forward, no new ones)

1. **QM5_10260 dispatcher escalation** — strengthened: the EA-switch
   from QM5_10144 to QM5_10146 (older created_at) falsifies the
   "newest-eligible-EA wins" sub-thesis. Binding criterion within
   eligible EAs is unknown — `claim_work_item` ranking inspection
   becomes more valuable. OWNER-class signal still the 34-hour-old
   QM5_10010/10012/10041 strandings.
2. **`0bf5dc87` priority-90 ops_issue** — third cycle unrouted; needs
   an assigned_agent.
3. **`3854cd8b` REVIEW close-out triage** — 5.13h single-task REVIEW
   dwell; priority-80 daemon slot held >5h.
4. **`ready_approved_cards` 992 → 0 reversal watch** — investigate next
   cycle whether this is auto-build pickup (good) or readiness-flag
   revocation (bad).
5. **`unenqueued_eas_count` WARN→FAIL escalation** — 9 → 11 EAs without
   Q02 work_items; pump should be emitting up to 3 enqueues per cycle.
6. **Enqueue-vs-drain trajectory** — pending growth re-accelerated
   (+106 vs 1715's +25); still no net drain across the wave that began
   at 1445.
