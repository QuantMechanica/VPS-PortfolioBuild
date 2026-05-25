# Claude Orchestration Cycle — 2026-05-25 16:15Z (1815 local)

63rd consecutive idle cycle for Claude (no IN_PROGRESS claude tasks;
`route-many --max-routes 5` and `run --min-ready-strategy-cards 5
--max-routes 5` both returned `no_routable_task`).

## Health snapshot

- Overall: **FAIL** (4 FAIL / 3 WARN / 12 OK). checked_at =
  2026-05-25T16:15:19Z.
- FAILs:
  - `p2_pass_no_p3` = 127 (flat — 63rd cycle).
  - `unbuilt_cards_count` = **832 flat — 12th consecutive cycle**
    (same cluster QM5_1071..1079, 1083).
  - `unenqueued_eas_count` = **11 flat** (carry-forward of 1800
    escalation). Reviewed-built EAs without Q02 work_items: QM5_10019,
    QM5_10021, QM5_10028, QM5_10035, QM5_10039, QM5_10043, QM5_10044,
    QM5_10050, QM5_10075, QM5_10076 (+1 truncated).
  - `p_pass_stagnation` = 0 P3+ PASS verdicts / 12h (flat).
- **NEW WARNs this cycle** (1 → 3 WARN expansion):
  - `codex_review_fail_rate_1h` = 0.21 — **1/38 system-class FAIL**
    on QM5_10201 (single EA, value far below 0.8 threshold; watch for
    second EA).
  - `zerotrade_rework_backlog` WARN — **QM5_10027:6/6** needs auto-
    rework tasks; ends a 20-cycle OK streak. Action hint: next pump
    cycle should emit build_ea + codex_inbox auto-rework tasks.
- Persistent WARN:
  - `mt5_worker_saturation` = 8/10 — **13th consecutive cycle** (T1 +
    T10 absent 63rd / 13th cycle).
- `pump_task_lastresult` OK exit 0 — 36th consecutive clean cycle.
- `codex_auth_broken` OK; auth_age = **148.5h** (~6.19 days clean).
- `codex_zero_activity` OK: detail `1 codex, 3 pending` (codex
  active task surfaced at health-level; router `agents.running` still 0).
- Disk D: **137.1 GB (−0.1 vs 1800's 137.2)** — first sub-1 GB step
  after five consecutive ≥1 GB drops. ~112.1 GB headroom above 25 GB
  FAIL threshold.

## MT5 queue — second-wave growth essentially stalled

- pending = **1071** (+4 vs 1800's 1067; an order of magnitude smaller
  step than 1715→1800's +106). Cumulative since 1445 surge: +546.
- active = **8 of 8 alive terminals**, all still on **QM5_10146**.
  Symbol fan-out has advanced within QM5_10146:
  - T2 AUDCHF, T3 CHFJPY, T4 **EURGBP** (was AUDCAD), T5 AUDNZD,
    T6 EURAUD, T7 **EURNZD** (was AUDCAD), T8 CADCHF, T9 **EURJPY**
    (was AUDUSD).
  - QM5_10146 has 8 active. AUDCAD has rotated to "done" / "failed";
    the dispatcher has progressed past the AUD-block into EUR-crosses.
- pwsh workers +1 (114 → **115**).
- fresh work_item logs +2 (2 → **4**).
- T1 + T10 absent 63rd / 13th cycle (saturation WARN persists).

## QM5_10260 dispatcher latency — 9th consecutive idle cycle

- QM5_10260 Q02 work_items NDX.DWX / WS30.DWX / SP500.DWX still
  `claimed_by=null`, `status=pending`,
  `created_at=2026-05-25T12:43:15+00:00` — **~212 min queued (~3.53h)**.
- Active fleet still on **QM5_10146** (created_at range
  `2026-05-24T05:38:57+00:00` → `2026-05-25T12:42:52+00:00`).
  QM5_10146 oldest work_item is **30h+ older than both QM5_10144 and
  QM5_10260** — EA-grouping + non-FIFO within-EA ranking thesis from
  1800 holds.
- **Oldest pending row in queue** still
  `2026-05-24T05:38:53+00:00` (QM5_10010 EURUSD.DWX) — **~34h 36m**
  unclaimed.
- QM5_10260's three rows are not unique stalls; queue still carries
  many NDX/WS30/SP500 pending rows under other EAs.

OWNER-class signal carry-forward unchanged: dispatcher EA-grouping +
unidentified within-EA ranking is stranding 34-hour-old
QM5_10010/10012/10041/10044 rows under newer enqueue bursts.
`claim_work_item` source-code inspection (in `farmctl.py`) remains the
recommended diagnostic path.

## Router state

- **Claude**: 0 running / max 3 — `list-tasks --agent claude` empty
  (63rd cycle).
- **Codex**: 0 running / max 5 (router-view); health shows 1 active.
  - **3 APPROVED build_ea**: `09f78f65` priority 30 stale since
    2026-05-23T18:07:22Z = **46.14h**; `96bbfa22` priority 35;
    `9982c1f4` priority 40.
  - **2 APPROVED ops_issue** assigned codex (`9c34e720` + `231d6f8f`,
    priority 35).
  - **1 REVIEW ops_issue** assigned codex — `3854cd8b` priority 80,
    `updated_at=2026-05-25T10:52:48+00:00`, raw dwell vs checked_at
    16:15:19Z = **~322.5 min / 5.38h — 10th consecutive idle cycle**
    with no `updated_at` movement. Longest single-task REVIEW dwell
    of the idle window, now exceeds 5.3h.
  - **1 APPROVED ops_issue still unassigned** — `0bf5dc87`
    (priority 90, `assigned_agent=null`,
    `created_at=2026-05-25T14:15:25+00:00` = **~120 min unrouted**;
    **4th cycle** in `APPROVED + assigned_agent=null`). Router cannot
    auto-route APPROVED ops_issue without assigned_agent — needs
    OWNER or router-policy update.
- **Gemini**: 1 IN_PROGRESS research_strategy (`f5043456` priority 20).
- **Replenishment frozen**
  (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`).
  Strategy inventory: `blocked_approved_cards=2566`,
  `ready_approved_cards=0`, `approved_cards=2566`, `draft_cards=54`
  — same split as 1800 (the "ready→blocked reversal" has stayed put;
  not a transient flip).

## Other chronic markers (carry-forward)

- `source_pool_drained` OK 12 flat.
- `cards_ready_stagnation` OK 0.
- `claude_review_starved` OK value 2 (vs threshold 3).
- `quota_snapshot_fresh` OK (codex=29s, claude=29s).
- `codex_bridge_heartbeat` OK (legacy bridge stale 680399s as
  expected; direct pump Codex active).

## Recommendations (carry-forward + 2 new watch items)

1. **QM5_10260 dispatcher escalation** — still the cleanest probe
   for the deeper dispatcher pathology; older-EA strandings remain
   the OWNER-class signal.
2. **`0bf5dc87` priority-90 ops_issue** — 4th cycle unrouted, ~120 min
   unassigned.
3. **`3854cd8b` REVIEW close-out triage** — 5.38h dwell; priority-80
   daemon slot held >5h.
4. **`unenqueued_eas_count` FAIL** — 11 EAs flat; pump should be
   emitting up to 3 enqueues per cycle.
5. **NEW watch: `zerotrade_rework_backlog` WARN** — QM5_10027:6/6;
   next pump cycle should emit build_ea + codex_inbox auto-rework
   tasks. Verify before recommending escalation.
6. **NEW watch: `codex_review_fail_rate_1h` WARN** — single-EA
   (QM5_10201) system-class FAIL; flag any second EA on same window.
7. **Enqueue-vs-drain trajectory** — pending growth nearly stalled
   (+4 vs prior +106). Watch 1830/1845 for the first net-drain step
   since 1445.
