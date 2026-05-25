# Claude Orchestration Cycle — 2026-05-25 15:00Z

54th consecutive idle cycle for Claude (no IN_PROGRESS claude tasks; router
returned `no_routable_task`).

## Health snapshot

- Overall: **FAIL** (3 FAIL / 2 WARN / 14 OK)
- FAILs:
  - `p2_pass_no_p3` = 127 (flat)
  - `unbuilt_cards_count` = 832 (flat vs 14:45Z) — **3rd consecutive flat reading**;
    detail cluster identical (QM5_1071/1072/1073/1074/1075/1076/1077/1078/1079/1083).
    `approved_cards` still 2566.
  - `p_pass_stagnation` = 0 P3+ PASS verdicts / 12h (flat)
- WARNs:
  - `mt5_worker_saturation` = 8/10 (T1 + T10 still missing; T2–T9 alive) — **4th
    consecutive cycle at 8/10**.
  - `unenqueued_eas_count` = 9 (flat — same 9 EAs: QM5_10019/10021/10028/10035/
    10039/10043/10044/10076/10079).
- `pump_task_lastresult` clean exit 0 — **29th consecutive cycle**.
- `codex_auth_broken` OK; auth_age = 145.3h (~6.05 days clean).
- Disk D: 145.5 GB (**−0.6 vs 14:45Z's 146.1**; 5× the typical 0.1 GB micro-step —
  consistent with 8 active terminals writing tester output during the 472-row
  burst-processing window; well above 25 GB threshold).

## Router state

- Claude: 0 running / max 3 — list-tasks empty (54th cycle).
- Codex: 0 running / max 5 — 5 APPROVED flat (3 build_ea + 2 ops_issue) + 1 REVIEW
  ops_issue (3854cd8b; `updated_at=2026-05-25T10:52:48Z`, raw dwell ~247.8 min — note
  prior cycles reported a 2h-shorter dwell, the field-based number is the literal
  truth).
- Gemini: 1 IN_PROGRESS research_strategy / 5 FAILED.
- Replenishment frozen (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`);
  2566 approved cards / 2566 blocked / 0 ready.

## QM5_10260 — fresh pendings still queued, not yet claimed

State unchanged vs 14:45Z's signal change:

- 8 stale rows still present: `status=failed phase=Q02 verdict=INVALID` from
  2026-05-24T21:16:08Z (FX/JPY legs — AUDCAD, AUDCHF, AUDJPY, AUDNZD, AUDUSD,
  CADCHF, CADJPY, CHFJPY).
- 3 fresh pending Q02 work_items with `updated_at=2026-05-25T12:43:15Z`
  (NDX.DWX, SP500.DWX, WS30.DWX) — **still `claimed_by=null`** after ~17 min in queue
  despite 8 active terminals. Dispatcher likely deprioritising vs the 449-row FX
  surge from 14:45Z (468 FX-symbol items in front of 3 index-symbol items).
- No corresponding `agent_tasks` referencing QM5_10260; prior perf-rework codex
  APPROVED tasks have closed out.
- Per `feedback_spx500_card_port_before_build`: SP500.DWX is backtest-only;
  NDX/WS30 are the live-routable substitutes. The new attempt has scoped down to
  the index legs as expected.
- No new evidence yet — verdict will come from the run once a terminal picks the
  index pendings.

## MT5 dispatch — burst absorption holds

- 14:45Z: 457 pending, 8 active, 122 pwsh, 10 fresh work_item logs.
- 15:00Z: **472 pending (+15)**, 8 active (flat), 123 pwsh (+1), 9 fresh logs (−1).
- The +15 pending is far below cycle-to-cycle burn capacity — workers must be
  emitting roughly as fresh items arrive (queue depth essentially flat after the
  449-row surge). The 0.6 GB disk delta corroborates active tester output across
  all 8 daemons.
- Gap-to-alive remains 0 (full utilisation of the 8 active daemons; T1 and T10
  still missing).

## Deltas vs 14:45Z

- **MT5 pending +15 (457 → 472)** — small post-surge top-up, no second burst;
  drain has not started.
- **Active terminals flat at 8** — full util of fleet for 2nd consecutive cycle.
- **pwsh workers +1 (122 → 123)** — micro-step (idle-window high persists).
- **Fresh work_item logs −1 (10 → 9)** — minor settle after the 14:45Z burst peak.
- **Disk D: −0.6 GB (146.1 → 145.5)** — 5× typical step, consistent with sustained
  tester output during burst processing; first non-micro disk step of the idle
  window.
- `mt5_worker_saturation` stable at 8/10 — T1 / T10 absent for 54th / 4th cycle.
- Codex REVIEW 3854cd8b persists; updated_at unchanged (close-out has not happened
  in this cycle).
- 5 codex APPROVED flat — 54th cycle; oldest task (09f78f65) ~45h stale.
- QM5_10260 3 fresh pendings unclaimed (state unchanged vs 14:45Z).
- `zerotrade_rework_backlog` OK — 12th consecutive cycle.
- `source_pool_drained` OK at 12 pending sources (flat 54th cycle).
- `cards_ready_stagnation` OK; `codex_review_fail_rate_1h` OK (0/0);
  `claude_review_starved` OK.

## Chronic FAILs (carry-forward)

- `p2_pass_no_p3` = 127 (flat 54th cycle).
- `unbuilt_cards_count` = 832 (flat 3rd consecutive cycle; trajectory
  573 → 776 → 679 → 832 → 832 → 832 — second flat tier).
- `p_pass_stagnation` = 0/12h (flat).

## Persistent stalls

- 5 codex APPROVED tasks flat for ~45h (oldest 09f78f65 priority 30 build_ea since
  2026-05-23T18:07:22Z); per
  [`project_qm_codex_daemon_priority_floor_2026-05-25`] this is the priority-first
  selection pattern: APPROVED at 30–40 sits while REVIEW at 80 (3854cd8b) waits.
- Codex REVIEW 3854cd8b has not progressed this cycle; priority-40 build_ea
  9982c1f4 still gated.
- 9 unenqueued EAs (10019/10021 still gated by 3854cd8b REVIEW close-out per prior
  notes; 10028/10035/10039/10043/10044/10076/10079 round out the WARN).

## Hard rules respected

- No work chosen outside the deterministic router.
- Operator phase names Q-only.
- No T_Live / AutoTrading touch.
- No `terminal64.exe` manual start.
- No interruption of active T1–T10 backtests.
- No pipeline verdict invented (the QM5_10260 fresh pendings will produce their
  own once a terminal picks them up).

## Recommended next steps

1. **Watch QM5_10260 NDX/WS30/SP500 pickup latency** — 3 fresh pendings have sat
   ~17 min behind the 449-row FX surge; if they remain unclaimed for another 2–3
   cycles, dispatcher priority/symbol-availability is worth a look (custom
   SP500.DWX in particular).
2. **Codex daemon attention** — 3854cd8b REVIEW persists; either the close-out is
   genuinely blocked (needs OWNER triage of the verdict text) or the daemon is
   mis-prioritising vs the 5 APPROVED at priorities 30–40.
3. **Auto-build pause** — `unbuilt_cards_count` flat at 832 for 3 consecutive
   cycles after the 573→776→679→832 trajectory; if `pump_task_lastresult` stays
   clean but `unbuilt_cards` doesn't drop next cycle either, the bridge-task flow
   has stalled in a way the lastresult sentinel doesn't catch — a
   `farmctl pump` deep-dive is warranted on cycle 55.
