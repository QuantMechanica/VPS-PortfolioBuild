# Claude Orchestration Cycle — 2026-05-25 13:15Z (1515 local)

55th consecutive idle cycle for Claude (no IN_PROGRESS claude tasks; router
returned `no_routable_task`).

## Health snapshot

- Overall: **FAIL** (3 FAIL / 2 WARN / 14 OK)
- FAILs:
  - `p2_pass_no_p3` = 127 (flat)
  - `unbuilt_cards_count` = 832 (flat vs 1500's reading) — **4th consecutive flat
    cycle**; detail cluster identical
    (QM5_1071/1072/1073/1074/1075/1076/1077/1078/1079/1083).
  - `p_pass_stagnation` = 0 P3+ PASS verdicts / 12h (flat)
- WARNs:
  - `mt5_worker_saturation` = 8/10 (T1 + T10 still missing; T2–T9 alive) — **5th
    consecutive cycle at 8/10**.
  - `unenqueued_eas_count` = 9 (flat — same 9 EAs: QM5_10019/10021/10028/10035/
    10039/10043/10044/10076/10079).
- `pump_task_lastresult` clean exit 0 — **30th consecutive cycle**.
- `codex_auth_broken` OK; auth_age = 145.5h (~6.06 days clean).
- Disk D: 145.0 GB (**−0.5 vs 1500's 145.5** — 5× the typical 0.1 GB micro-step
  again; consistent with continued 8-terminal tester output as the post-surge
  pending queue is worked down).

## Router state

- Claude: 0 running / max 3 — list-tasks empty (55th cycle).
- Codex: 0 running / max 5 — 5 APPROVED flat (3 build_ea + 2 ops_issue) + 1 REVIEW
  ops_issue (3854cd8b; `updated_at=2026-05-25T10:52:48Z`; raw dwell vs this cycle's
  checked_at 13:15:22Z = **~142.6 min**, ~2.38h — note: the 1500.md report quoted
  ~247.8 min, which mistook CEST for UTC; current arithmetic is the authoritative
  number).
- Gemini: 1 IN_PROGRESS research_strategy / 5 FAILED.
- Replenishment frozen (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`);
  approved cards / blocked / ready unchanged at the 2566 / 2566 / 0 baseline.

## QM5_10260 — fresh pendings still unclaimed

- 8 stale rows still present: `status=failed phase=Q02 verdict=INVALID` from
  2026-05-24T21:16:08Z (FX/JPY legs).
- 3 fresh pending Q02 work_items with `updated_at=2026-05-25T12:43:15Z`
  (NDX.DWX, SP500.DWX, WS30.DWX) — **still `claimed_by=null`** after ~32 min in
  queue. Per the 1500 recommendation, this is the 2nd straight cycle the indices
  have sat un-picked while 8 active terminals are fully utilised on the residual
  burst. Dispatcher priority/symbol-availability is now worth a closer look —
  the custom SP500.DWX leg in particular (only T-instances configured for the
  custom symbol can pick that row).
- No corresponding `agent_tasks` referencing QM5_10260; prior perf-rework codex
  APPROVED tasks have closed out.

## MT5 dispatch — queue swelling, drain not yet started

- 1500: 472 pending, 8 active, 123 pwsh, 9 fresh work_item logs.
- 1515: **525 pending (+53)**, 8 active (flat), 118 pwsh (−5), 17 fresh logs (+8).
- The +53 net pending despite sustained 8-terminal output indicates new enqueue
  rows are still arriving faster than the drain. Fresh work_item logs jumped
  from 9 → 17 — second wave of pipeline writes (likely additional pump auto-build
  + Q02 enqueues; not yet inspected per-EA).
- Active claims: T2/T3/T4/T5/T6/T7/T8/T9 = 1 each (full utilisation of 8
  daemons). T1 + T10 absent — 55th / 5th cycle respectively.
- 95 work_items had `updated_at > 13:00Z`; 74 had `created_at > 13:00Z` — confirms
  most of the 15-min activity is new enqueue, not just status transitions.

## Deltas vs 1500

- **MT5 pending +53 (472 → 525)** — second-wave growth; queue not draining yet.
- **Active terminals flat at 8** — 3rd consecutive cycle full util.
- **pwsh workers −5 (123 → 118)** — first sub-120 read since the 1245 surge;
  back inside the 113–119 idle-window band, give-back of 1500's +1 micro-high.
- **Fresh work_item logs +8 (9 → 17)** — sharp uptick; matches the +53/+74 enqueue
  numbers.
- **Disk D: −0.5 GB (145.5 → 145.0)** — 5× typical step second consecutive cycle;
  burst processing continues to chew through tester output.
- `mt5_worker_saturation` stable 8/10 — T1 / T10 absent 55th / 5th cycle.
- Codex REVIEW 3854cd8b persists; updated_at unchanged 2nd consecutive idle
  cycle since field-truth correction.
- 5 codex APPROVED flat — 55th cycle; oldest task 09f78f65 ~45.1h stale.
- QM5_10260 3 fresh pendings still unclaimed (state unchanged vs 1500).
- `zerotrade_rework_backlog` OK — 13th consecutive cycle.
- `source_pool_drained` OK at 12 pending sources (flat 55th cycle).
- `cards_ready_stagnation` OK; `codex_review_fail_rate_1h` OK (0/0);
  `claude_review_starved` OK.

## Chronic FAILs (carry-forward)

- `p2_pass_no_p3` = 127 (flat 55th cycle).
- `unbuilt_cards_count` = 832 (flat 4th consecutive cycle; trajectory
  573 → 776 → 679 → 832 → 832 → 832 → 832 — second flat tier extends).
- `p_pass_stagnation` = 0/12h (flat).

## Persistent stalls

- Codex REVIEW 3854cd8b at 2.38h dwell — priority-40 build_ea 9982c1f4 still
  gated behind the close-out.
- 5 codex APPROVED tasks flat for ~45h (oldest 09f78f65 priority 30 build_ea
  since 2026-05-23T18:07:22Z); per
  [`project_qm_codex_daemon_priority_floor_2026-05-25`] this remains the
  priority-first selection pattern, not a daemon-not-polling diagnosis.
- 9 unenqueued EAs (10019/10021 still gated by 3854cd8b REVIEW close-out per
  prior notes).

## Hard rules respected

- No work chosen outside the deterministic router.
- Operator phase names Q-only.
- No T_Live / AutoTrading touch.
- No `terminal64.exe` manual start.
- No interruption of active T1–T10 backtests.
- No pipeline verdict invented (the QM5_10260 fresh pendings still await a
  terminal pickup; verdicts will follow real evidence only).

## Recommended next steps

1. **QM5_10260 NDX/WS30/SP500 dispatcher latency** — 32 min unclaimed across two
   cycles is past the watch threshold from 1500. Suggest a quick check of
   per-terminal symbol whitelist (which Tnn instances are configured to hold
   SP500.DWX as a custom symbol?) and dispatcher priority weighting between the
   449-row FX surge and the 3-row index follow-up.
2. **Auto-build deep-dive** — `unbuilt_cards_count` flat 4 cycles at 832 with
   `pump_task_lastresult` clean; the bridge-task flow appears stalled in a way
   the lastresult sentinel doesn't catch. The 1500 recommendation now stands as
   a concrete ask: run a focused `farmctl pump` inspection (or read the latest
   pump log tail) to confirm whether auto-build is actually emitting tasks per
   cycle or silently no-op'ing.
3. **3854cd8b REVIEW close-out** — at 2.4h with no `updated_at` movement, this
   is now the longest single-task REVIEW of the idle window. Either OWNER
   triage of the verdict is needed, or the secondary-reviewer gate is not
   routing as expected.
