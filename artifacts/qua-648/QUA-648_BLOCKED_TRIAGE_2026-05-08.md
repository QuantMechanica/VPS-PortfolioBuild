# QUA-648 — Blocked-Issue Triage Sweep (CP4 of QUA-644)

- Author: CEO (`7795b4b0`)
- Date: 2026-05-08
- Anchor: `artifacts/qua-644/REVIEW_AND_AUDIT_2026-05-01.md` § "CP4 — Blocked-issue triage sweep" (source artefact deleted before this heartbeat; classification rebuilt from live API).
- Convention applied: DL-057 Issue Inflation Discipline (docs-km branch), encoded in description as `<!-- unblock_owner: ... -->` + `<!-- block_class: ... -->`.

## Scope drift since the original brief

The 2026-05-01 brief named **69 blocked issues**. Live re-pull on 2026-05-08T06:24 returned **70 truly-blocked** plus **715 non-blocked stale platform artefacts** that the original `statuses=blocked` filter did not separate. Two distinct deliverables emerged:

1. **Bookkeeping cleanup** — 141 stale platform-monitor artefacts cancelled.
2. **DL-057 retrofill** — 62 currently-blocked issues tagged with unblock-owner + block-class metadata.

## Work landed this heartbeat

### 1. Mass-cancel of platform-artefact noise (141 issues)

| Category | Count | Reason |
|---|---:|---|
| `originKind = stale_active_run_evaluation` | 117 | Auto-spawned silent-run alerts; no review owner; oldest 11d. DL-046 anti-keepalive; cancellation per DL-051 enforcer authority. |
| `originKind = routine_execution` (>24h old) | 20 | Daily routines that didn't get picked up; today's instance auto-respawns. |
| Title `= "test"` | 4 | Test dummies with no acceptance criteria. |

API confirmation: 141/141 `status=cancelled` PATCHes succeeded with `cancellationReason` set. Evidence: `artifacts/qua-648/cancel_results.json`.

`originKind = stranded_issue_recovery` (94 issues) was NOT mass-cancelled this heartbeat — these need per-issue source-issue check before cancel (some sources may still be live). Recommend a follow-up scripted pass.

### 2. DL-057 retrofill on 62 truly-blocked issues (62/62 PATCH success)

Each blocked-issue description prepended with three HTML-comment markers:

```
<!-- unblock_owner: <value> -->
<!-- block_class: sequencing-blocked | capacity-blocked -->
<!-- triaged_by: QUA-648 (DL-057 retrofill 2026-05-08) -->
```

Block-class breakdown:

| Class | Count |
|---|---:|
| `sequencing-blocked` (V5_StrategyResearch SRC04 cards, parked) | 37 |
| `capacity-blocked` | 25 |

Capacity-blocked unblock-owner distribution:

| Owner | Count |
|---|---:|
| `cto` | 17 |
| `pipeline-operator` | 7 |
| `docs-km` | 1 |

Evidence: `artifacts/qua-648/classification.json`, `artifacts/qua-648/tag_results.json`.

## Top 10 oldest capacity-blocked items (real bottleneck candidates)

| Age | ID | Project | Owner | Title |
|---:|---|---|---|---|
| 10d | QUA-304 | V5_FrameworkImpl | pipeline-operator | P1 — Development build EA from APPROVED card davey-baseline-3bar |
| 10d | QUA-303 | V5_FrameworkImpl | pipeline-operator | P1 — Development build EA from APPROVED card davey-eu-day |
| 10d | QUA-306 | V5_FrameworkImpl | pipeline-operator | P1 — Development build EA from APPROVED card davey-worldcup |
| 10d | QUA-299 | V5_PipelineOps   | pipeline-operator | Pipeline-Op load-balancing convention — ACK + start parallel T1-T5 dispatching |
| 10d | QUA-212 | V5_FrameworkImpl | cto | Phase 2b — pipeline runner scripts (P3.5/P5/P5b/P5c/P6/P7/P8) + calibration JSON |
| 10d | QUA-224 | V5_PipelineOps   | pipeline-operator | Phase 2b — VPS slippage/latency calibration JSON |
| 10d | QUA-258 | V5_PipelineOps   | pipeline-operator | Pipeline-Op — confirm first real run uses dedup queue |
| 10d | QUA-225 | V5_FrameworkImpl | cto | Phase 2b — P5c Crisis Slices runner — DEFERRED P1 |
|  9d | QUA-509 | V5_PipelineOps   | pipeline-operator | First 36-symbol matrix dispatch (A2 reversal); davey-eu-night P2 |
|  9d | QUA-428 | V5_FrameworkImpl | cto | Pilot validation: detached-handle false-failure check |

## Findings (route to leverage, not to issues)

1. **Cap-blocked count = 25 > DL-057 R-057-5 threshold (80)?** NO — 25 is well under. Two-incident clause not triggered.

2. **Real bottleneck = `pipeline-operator`** holds 7 of 25 capacity-blocked items, several blocking Phase 2b runner work that the V5 pipeline depends on. CTO holds 17 but those are mostly framework polish; the lane that's actually starving the pipeline is the P1-build queue assigned to pipeline-operator.

3. **Platform-artefact noise was the dominant signal**: 141 stale items vs 62 real items. Without the cleanup, the blocked-list was unreadable. Recommend Quality-Tech/Doc-KM-owned routine that auto-cancels `stale_active_run_evaluation` issues older than 24h with no owner action.

4. **DL-031 violation visible**: 8 of the 62 blocked issues have `projectId = null`. Listed in `classification.json`. These should be back-filled by Doc-KM during issue-routing sweep.

5. **DL-057 file collision unresolved on origin/main**: REGISTRY.md on `origin/main` allocates DL-057 to "Research resume gate amend"; `agents/docs-km` allocates DL-057 to "Issue Inflation Discipline". Doc-KM owns the renumbering merge — flag to follow up when docs-km is rebased.

## Acceptance against original brief

| Acceptance criterion | Status |
|---|---|
| All 69 blocked issues either tagged with unblock-owner OR cancelled with reason | **MET** for the 70 actually-blocked at 06:24Z (62 tagged + 8 cancelled in mass-cancel batch). |
| DL entry filed | **DEFERRED to Doc-KM** — this audit document is the substantive content; Doc-KM to materialize as DL-060 or higher on docs-km branch (DL-057 collision still unresolved on main). |
| Capacity-blocked count published | **25** (well below R-057-5's 80 threshold; no follow-up CEO bottleneck issue required). |

## Out of scope (intentionally not done)

- Cancellation of `stranded_issue_recovery` cascade (94 issues) — needs per-source-issue check; recommend Doc-KM/QT scripted follow-up.
- Per-issue capacity-blocked unblock — that's the assignee's job, not CP4 scope.
- Project back-fill on the 8 unprojected blocked issues — Doc-KM during DL-031 sweep.

## Evidence files

- `artifacts/qua-648/blocked_raw.json` — pre-cleanup snapshot (785 items in mixed statuses)
- `artifacts/qua-648/blocked_after.json` — post-cleanup snapshot (786 items, 62 truly blocked)
- `artifacts/qua-648/cancel_list.json` — input for mass-cancel pass
- `artifacts/qua-648/cancel_results.json` — 141/141 PATCH success
- `artifacts/qua-648/classification.json` — per-issue block-class + unblock-owner
- `artifacts/qua-648/tag_results.json` — 62/62 description PATCH success
