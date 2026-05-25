# Claude Orchestration Cycle — 2026-05-25 14:35Z (1630 local)

59th consecutive idle cycle for Claude (no IN_PROGRESS claude tasks; router
returned `no_routable_task`).

## Health snapshot

- Overall: **FAIL** (4 FAIL / 2 WARN / 13 OK). checked_at = 2026-05-25T14:34:59Z.
- FAILs:
  - **NEW**: `pump_task_lastresult` = **267009** (was clean exit 0 for 33
    consecutive cycles). `267009 = 0x41301 = SCHED_S_TASK_RUNNING` — the
    scheduled task `QM_StrategyFarm_Pump_5min` was still mid-execution when
    health.py queried it, so this is a transient timing artefact, **not** a
    pump regression. Corroboration: `pump_task_20260525T143301Z.log` was
    being written at 4:35:29 PM local with normal JSON output (no error trail);
    the 14:33:01Z pump run completed cleanly and produced the expected
    `research_backlog_inventory` block.
  - `p2_pass_no_p3` = 127 (flat — 59th cycle).
  - `unbuilt_cards_count` = 832 (flat — **8th consecutive cycle**; cluster
    identical: QM5_1071/1072/1073/1074/1075/1076/1077/1078/1079/1083).
  - `p_pass_stagnation` = 0 P3+ PASS verdicts / 12h (flat).
- WARNs:
  - `mt5_worker_saturation` = 8/10 (T1 + T10 still absent; T2–T9 alive) —
    **9th consecutive cycle at 8/10**.
  - `unenqueued_eas_count` = 9 (flat — same 9 EAs:
    QM5_10019/10021/10028/10035/10039/10043/10044/10076/10079).
- `codex_auth_broken` OK; auth_age = 146.8h (~6.12 days clean).
- Disk D: **140.7 GB (−1.1 vs 1615's 141.8)** — second straight 10× typical
  step under sustained tester output across the 8-daemon fleet processing the
  ongoing backlog. Threshold still clear (25 GB FAIL); ~115.7 GB of headroom.

## Router state

- Claude: 0 running / max 3 — list-tasks empty (59th cycle).
- Codex: 0 running / max 5.
  - 3 APPROVED build_ea (09f78f65 priority 30 stale since 2026-05-23T18:07:22Z
    = **44.45h**; 96bbfa22 priority 35; 9982c1f4 priority 40).
  - 2 APPROVED ops_issue assigned to codex (9c34e720 + 231d6f8f, priority 35,
    stale since 2026-05-23).
  - 1 REVIEW ops_issue assigned to codex (3854cd8b, priority 80) —
    `updated_at=2026-05-25T10:52:48Z`; raw dwell vs checked_at 14:34:59Z =
    **~222.2 min, ~3.70h** — 6th consecutive idle cycle since the field-truth
    correction with no `updated_at` movement; **now the longest single-task
    REVIEW dwell of the entire idle window**.
  - **NEW**: 1 APPROVED ops_issue **unassigned** — `0bf5dc87-dec2-4617-b740-9efb5f1d487d`
    created at `2026-05-25T14:15:25Z` (exactly the 1615-cycle window),
    priority **90**, verdict=null. First fresh router entry of the day's
    idle stretch; awaits codex agent claim or assignment.
- Gemini: 1 IN_PROGRESS research_strategy / 5 FAILED.
- Replenishment frozen
  (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`);
  pump's `research_replenish_gate.allow_new_research=false`,
  `strategy_backlog=992` (well above the 5-card floor).

## Research backlog — meaningful shift since 1615

- Pump's research_backlog_inventory (from 14:33:01Z run):
  - `approved_cards` = 2566 (flat)
  - `blocked_approved_cards` = **1574 (−992 vs prior 2566)**
  - `ready_approved_cards` = **992 (+992 vs prior 0)**
  - `open_build_or_review_tasks` = 62
  - `active_pipeline_eas` = 91
  - `draft_cards` = 54
- **992 cards have flipped from blocked → ready_for_build** within the last
  pump cycle window. This does **not** contradict the flat
  `unbuilt_cards_count = 832`, since the latter detector counts cards lacking
  both a built `.ex5` and an auto-build task, whereas ready_approved_cards is
  the upstream "ready to receive a build task" tier. Worth watching the next
  1–2 cycles for whether auto-build picks them up and drains the 832 cluster.

## QM5_10260 — fresh pendings still unclaimed (~112 min, 6th cycle)

- 8 stale rows still present: `status=failed phase=Q02 verdict=INVALID` from
  2026-05-24T21:16:08Z (FX/JPY legs).
- 3 fresh pending Q02 work_items with `updated_at=2026-05-25T12:43:15Z`
  (NDX.DWX, SP500.DWX, WS30.DWX) — **still `claimed_by=null`** after
  **~111.7 min** in queue (was ~92.3 min at 1615, ~77.3 min at 1600,
  ~62 min at 1545, ~32 min at 1515, ~17 min at 1500). Sixth straight cycle
  the indices have sat un-picked. Dispatcher latency thesis unchanged: the
  "no Tnn carries WS30.DWX" hypothesis remains falsified by QM5_10135's WS30
  active claim on T7 last cycle; queue-ordering / priority-age weighting
  remains the primary suspect; SP500.DWX per-terminal symbol-whitelist
  remains the secondary open question.
- No corresponding `agent_tasks` referencing QM5_10260.

## MT5 dispatch — net-enqueue continues, no drain yet

- 1615: 742 pending, 8 active (health JSON), 118 pwsh, 9 fresh work_item logs.
- 1630: **831 pending (+89)**, 8 active (health JSON 14:34:59Z), **121 pwsh
  (+3)**, **12 fresh work_item logs (+3)**.
- Third growth step in a row; cumulative since 1445 surge:
  449→472→525→643→689→742→831 = **+382 over six cycles**, **drain still has
  not begun**. pwsh +3 and fresh logs +3 both suggest moderately heavier
  worker spawn / lifecycle churn vs 1615's settle direction — not a regression
  by itself, but a turn back upward.

## Deltas vs 1615

- **MT5 pending +89 (742 → 831)** — second-wave enqueue persists at a stronger
  pace than 1615's +53; cumulative since 1445 surge: +382 over 6 cycles. No
  drain yet.
- **Active terminals 8 (health JSON snapshot)** — full utilisation of the
  8-daemon fleet; T1 + T10 still absent (59th / 9th cycle respectively).
- **pwsh workers +3 (118 → 121)** — first net-positive step of the idle
  window; back inside the 113–119 band's upper edge / just above.
- **Fresh work_item logs +3 (9 → 12)** — turn back upward after three cycles
  of settle.
- **Disk D: −1.1 GB (141.8 → 140.7)** — 11× typical step; sustained tester
  output processing the queue under full 8-daemon utilisation; still ~115.7 GB
  above the 25 GB FAIL threshold.
- `mt5_worker_saturation` stable 8/10 — T1 / T10 absent 59th / 9th cycle.
- Codex REVIEW 3854cd8b persists; `updated_at` unchanged 6th consecutive idle
  cycle (longest single-task REVIEW dwell of idle window).
- **New unassigned APPROVED ops_issue 0bf5dc87** appeared at 14:15:25Z
  (priority 90) — first fresh router entry of the day's idle stretch.
- QM5_10260 3 fresh pendings still unclaimed (+19.4 min dwell vs 1615 — now
  ~111.7 min).
- `zerotrade_rework_backlog` OK — 17th consecutive cycle.
- `source_pool_drained` OK at 12 pending sources (flat 59th cycle).
- `cards_ready_stagnation` OK; `codex_review_fail_rate_1h` OK (0/0);
  `claude_review_starved` OK.
- **Pump research_backlog_inventory shift**: blocked 2566→1574,
  ready 0→992 (see Research backlog section).

## Chronic FAILs (carry-forward)

- `p2_pass_no_p3` = 127 (flat 59th cycle).
- `unbuilt_cards_count` = 832 (flat **8th consecutive cycle**; trajectory
  573 → 776 → 679 → 832 → 832 → 832 → 832 → 832 → 832 → 832 → 832 — second
  flat tier extends; auto-build still paused at the detector level despite
  the upstream ready 0→992 flip).
- `p_pass_stagnation` = 0/12h (flat).

## Persistent stalls

- Codex REVIEW 3854cd8b at **3.70h dwell** — priority-40 build_ea 9982c1f4
  still gated behind the close-out (priority-80 daemon slot has been free
  222+ min). With the new priority-90 ops_issue 0bf5dc87 now also in queue,
  the priority-stack contention is increasing.
- 5 codex APPROVED tasks flat for ~44.45h (oldest 09f78f65 priority 30
  build_ea since 2026-05-23T18:07:22Z); per
  `project_qm_codex_daemon_priority_floor_2026-05-25` this remains the
  priority-first selection pattern, not a daemon-not-polling diagnosis.
- 9 unenqueued EAs (10019/10021 still gated by 3854cd8b REVIEW close-out per
  prior notes).

## Hard rules respected

- No work chosen outside the deterministic router.
- Operator phase names Q-only.
- No T_Live / AutoTrading touch.
- No `terminal64.exe` manual start.
- No interruption of active T1–T10 backtests.
- No pipeline verdict invented (QM5_10260 fresh pendings still await terminal
  pickup; verdicts will follow real evidence only).

## Recommended next steps

1. **QM5_10260 NDX/WS30/SP500 dispatcher latency — escalation overdue.** Six
   cycles unclaimed at 111+ min while all 8 active terminals continue to chew
   through QM5_10135 / QM5_10143 sweep rows. Action stands: read dispatcher
   claim policy and confirm whether priority/age weighting starves the 3-row
   QM5_10260 index batch behind a larger sweep. SP500.DWX per-terminal
   symbol-whitelist still open as secondary.
2. **`pump_task_lastresult` 267009 watch.** This cycle's FAIL is the
   `SCHED_S_TASK_RUNNING` race condition (health.py queried mid-pump); if
   1645 also reads 267009 with no clean exit between, escalate from "transient"
   to "pump runtime exceeds 5-min cron interval" investigation.
3. **Research backlog ready 0→992 vs unbuilt 832 flat.** Watch whether
   auto-build picks up any of the 992 newly-ready cards in the next 1–2
   cycles; if the 832 cluster remains flat through 1645 / 1700 despite ready
   cards being present, the pump-side stall thesis hardens further (no
   bridge tasks emitted despite eligible inputs).
4. **Unassigned priority-90 ops_issue 0bf5dc87** — read payload next cycle to
   classify (was created within the cycle window so worth understanding
   what triggered it); confirm router will eventually claim it for codex.
5. **3854cd8b REVIEW close-out** — now the longest single-task REVIEW dwell
   of the idle window at 3.70h with no `updated_at` movement for six
   consecutive cycles; either OWNER triage of the verdict is needed, or the
   secondary-reviewer gate is not routing as expected.
6. **Enqueue-vs-drain trajectory watch** — wave continues at +89 this cycle
   (449 surge → +53 → +118 → +46 → +53 → +89); cumulative +382 over 6 cycles,
   still no drain. Worth a check at 1645 whether the wave amplifies again or
   begins draining.
