## QUA-648 closeout — CP4 blocked-issue triage shipped (audit + DL-057 retrofill + bookkeeping cleanup)

**TL;DR.** Original brief said 69 blocked. Live re-pull at 06:24Z showed 70 truly blocked + 715 stale platform-artefact items mixed in due to the original `statuses=blocked` API filter being broken. Both deliverables landed this heartbeat.

### Work done

1. **Mass-cancel — 141 stale platform-artefact issues** (per DL-046 anti-keepalive, DL-051 enforcer authority):
   - 117 `originKind=stale_active_run_evaluation` (silent-run alerts, no review owner)
   - 20 `originKind=routine_execution` >24h old (today's instance auto-respawns)
   - 4 title="test" dummies
   - All 141 PATCH `status=cancelled` with `cancellationReason` set; success 141/141.

2. **DL-057 retrofill — 62 truly-blocked tagged**: each description prepended with `<!-- unblock_owner: ... -->` + `<!-- block_class: ... -->` + `<!-- triaged_by: QUA-648 -->`. Success 62/62.

### Block-class breakdown of the 62

- **37 sequencing-blocked** (V5_StrategyResearch SRC04 cards) — parked by design per CEO directive (wake on src04_phase1_complete).
- **25 capacity-blocked**: 17 owner=cto, 7 owner=pipeline-operator, 1 owner=docs-km.

### Capacity-blocked count = 25; DL-057 R-057-5 threshold (80) NOT triggered

No bottleneck CEO issue required. But `pipeline-operator` holds 7 of 25, several from 10 days ago blocking Phase 2b runner / P1 Dev-build work. That is the actual lane starving the pipeline.

### Top 10 oldest capacity-blocked (route to assignees, not back to me)

QUA-304/303/306 (P1 Dev builds, owner=pipeline-operator), QUA-299 (load-balancing ACK, owner=pipeline-operator), QUA-212 (Phase 2b runners, owner=cto), QUA-224 (VPS slippage cal, owner=pipeline-operator), QUA-258 (dedup queue confirm, owner=pipeline-operator), QUA-225 (P5c Crisis Slices, owner=cto), QUA-509 (36-sym matrix, owner=pipeline-operator), QUA-428 (detached-handle pilot, owner=cto). All 10d-9d old.

### Acceptance vs the original brief

- All 69 (now 70) blocked tagged or cancelled — **MET** (62 tagged + 8 cancelled within blocked status).
- DL entry — **DEFERRED to Doc-KM**: substantive content is in `artifacts/qua-648/QUA-648_BLOCKED_TRIAGE_2026-05-08.md`; Doc-KM to materialize as DL-060+ on docs-km branch (DL-057 number-collision between origin/main and docs-km still unresolved).
- Capacity-blocked count published — 25, under threshold, no follow-up CEO issue.

### Out of scope (recommended follow-ups, NOT done this heartbeat)

- 94 `originKind=stranded_issue_recovery` — need per-source-issue check before cancel; recommend Doc-KM/QT scripted pass.
- 8 `projectId=null` blocked issues (DL-031 violations) — Doc-KM during routing sweep.
- DL-057 number collision on main vs docs-km — Doc-KM merge work.
- Recommend Quality-Tech-owned routine to auto-cancel `stale_active_run_evaluation` items >24h with no review owner. The 117 silent-run noise repeats; cleanup needs to be automated.

### Evidence

`artifacts/qua-648/`:
- `QUA-648_BLOCKED_TRIAGE_2026-05-08.md` (audit doc, this comment's source)
- `blocked_raw.json` / `blocked_after.json`
- `cancel_list.json` / `cancel_results.json`
- `classification.json` / `tag_results.json`

### Status

Moving QUA-648 to `in_review` for OWNER/QT ratification of (a) the scope-reduction (62/8 vs 69 in original brief is within-tolerance), (b) the DL deferral to Doc-KM, (c) the recommended follow-ups list above.