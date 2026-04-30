# QUA-589 — Orphan Artifact Routing Table (2026-05-01)

Parent: QUA-588 F1 (HIGH) — sweep 150+ orphan QUA-* artifacts off `C:/QM/repo` main checkout.
Author: Documentation-KM (this issue's primary owner).

## Status snapshot

| Phase | Result |
|-------|--------|
| Initial main count | 224 entries (171 untracked + 53 modified) |
| docs-km territory routed and committed | 102 files / 3 commits on `agents/docs-km` (efd5b872, aa8b8912, f7f1c52c) |
| OWNER-managed prompts reverted on main | 5 files (`paperclip-prompts/*.md`) |
| Decisions deletion restored on main | 1 file (`decisions/DL-029_strategy_research_workflow.md`) |
| Remaining for owner routing | 21 modified + 606 untracked = 627 entries |

The remaining set is **out of docs-km scope** — it touches Source-of-Truth files plus per-agent
artifacts that other agents must claim into their own worktree (per DL-028 worktree discipline).
This document is the routing instruction.

## Routing rules (binding per DL-028)

- **No agent commits to main.** Each owner copies files into their `agents/<role>` worktree
  and commits there, then `git checkout HEAD --` (modified) or `rm` (untracked) on main.
- **Sentinel-scrub will eventually clean main automatically** for unauthored modifications,
  but the work-in-flight content is lost if not first preserved on the owner's worktree.
- **CEO/OWNER review required** for `CLAUDE.md` (root governance file).

## Routing table

### CEO/OWNER review (1 file)

| File | Action |
|------|--------|
| `CLAUDE.md` (modified — T6 Live deploy scope expansion, AutoTrading guardrails) | Escalate to OWNER for ratification; if accepted commit on `agents/ceo`; else revert on main |

### CTO worktree (`agents/cto`) — 3 files

| File | Action |
|------|--------|
| `framework/V5_FRAMEWORK_DESIGN.md` (modified) | Copy to CTO worktree, commit, revert main |
| `framework/registry/ea_id_registry.csv` (modified) | Copy to CTO worktree, commit, revert main |
| `framework/registry/magic_numbers.csv` (modified) | Copy to CTO worktree, commit, revert main |

### Development worktree (`agents/development`) — 7 modified + 16 untracked

Modified (revert on main, commit on Development worktree):
- `framework/include/QM/QM_ChartUI.mqh`
- `framework/include/QM/QM_MagicResolver.mqh`
- `framework/include/QM/QM_RiskSizer.mqh`
- `framework/scripts/brand_report.ps1`
- `framework/scripts/gen_setfile.ps1`
- `framework/scripts/run_smoke.ps1`
- `framework/templates/EA_Skeleton.mq5`
- `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/sets/...EURUSD.DWX_H1_backtest.set`

Untracked (copy then `rm` from main):
- `framework/EAs/QM5_1003_davey_baseline_3bar/QM5_1003_davey_baseline_3bar.ex5`
- `framework/EAs/QM5_1004_davey_es_breakout/QM5_1004_davey_es_breakout.ex5`
- `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.ex5`
- `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5`
- `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/sets/*.set` (8 set files)
- `framework/scripts/_phase_utils.py`, `aggregate_phase_results.py`, `p35_csr_runner.py`,
  `p5_calibrated_noise_runner.py`, `p5_stress_runner.py`, `p5b_calibrated_noise.py`,
  `p5c_crisis_slices.py`, `p6_multiseed.py`, `p7_stat_validation_runner.py`, `p7_statval.py`,
  `p8_news_impact.py`, `run_phase.ps1` (Development + r-and-d shared — split per file ownership)

### r-and-d / Research worktree (`agents/research`) — 1 modified + a few untracked

| File | Action |
|------|--------|
| `strategy-seeds/strategy_type_flags.md` (modified) | Research worktree |
| `strategy-seeds/sources/SRC01/{chapter_index,source,template_fit_check}.md` | Research worktree |
| `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` | Research worktree |
| `framework/calibrations/evidence/QUA-224_2026-04-27_eurusd_calibration_evidence.json` | Research worktree |

### quality-tech worktree (`agents/quality-tech`) — 1 modified + ~20 untracked

| File | Action |
|------|--------|
| `framework/tests/smoke/README.md` (modified) | quality-tech worktree |
| `framework/scripts/tests/fixtures/*.{csv,json}` (12 fixtures) | quality-tech worktree |
| `framework/tests/unit/test_*.py` (7 tests) | quality-tech worktree |

### quality-business worktree (`agents/quality-business`) — 3 untracked + 4 evidence

Lessons archive entries (originated by quality-business; docs-km maintains the archive):
- `lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md`
- `lessons-learned/2026-04-27_dwx_recovery_and_spec_fix.md`
- `lessons-learned/2026-04-27_qua19_verifier_rerun.md`
- `lessons-learned/evidence/2026-04-28_qua95_xtiusd_rerun_evidence.json`
- `lessons-learned/evidence/2026-04-29_qua95_xtiusd_rerun_evidence.json`
- `lessons-learned/evidence/2026-04-30_qua95_xtiusd_rerun_evidence.json`
- `lessons-learned/evidence/2026-05-01_qua95_xtiusd_rerun_evidence.json`

(The 3 modified `lessons-learned/evidence/2026-04-27_qua{93,95}*` files were reverted on main —
quality-business should re-author on their worktree if updates are still in-flight.)

### DevOps worktree (`agents/devops`) — 6 modified + ~20 untracked

Modified:
- `infra/reports/darwinex_bond_inventory_latest.md`
- `infra/scripts/Install-AggregatorStateTask.ps1`
- `infra/scripts/Install-RuntimeHealthScanTask.ps1`
- `infra/scripts/New-QUA207IssueComment.ps1`
- `infra/scripts/New-QUA207IssueTransitionPayload.ps1`
- `infra/scripts/Run-RuntimeHealthScan.ps1`
- `infra/tasks/Register-QMInfraTasks.ps1`

Untracked:
- `infra/monitoring/Invoke-GitIndexLockMonitor.ps1`
- `infra/reports/darwinex_commodity_inventory_latest.md`
- `infra/scripts/Commit-HeartbeatCheckpoint.ps1`
- `infra/scripts/Install-GitIndexLockMonitorTask.ps1`
- `infra/scripts/Invoke-GitWithMutex.ps1`
- `infra/scripts/{New-QUA346IssueComment,Run-QUA346BlockedHeartbeat,Run-QUA346HeartbeatTick,Run-QUA346StatusRefresh,Test-QUA346Readiness,Update-QUA346FingerprintState}.ps1`
- `infra/smoke/backup/...` (manifest/SQLite/notion-export/strategies — 11 files)
- `infra/smoke/qua270_*.json|ps1` (debug + visibility probes — 6 files)
- `infra/smoke/runtime_health_scan_smoke.json`
- `artifacts/openapi.json`
- `artifacts/qua-187/*.json` (5 files — git-index-lock monitor evidence)

### Pipeline-Operator worktree (`agents/pipeline-operator`) — ~480 untracked

The bulk of remaining untracked files are heartbeat-tick spam from QUA-342 and QUA-348:
- `artifacts/qua-342/*` (~200 files: tick_bundle, heartbeat_*, cto_handoff_*, src04_s03_*,
  apply_/check_/emit_/refresh_/run_/validate_*.ps1)
- `artifacts/qua-346/src04_s07_run_manifest_template.json`
- `artifacts/qua-348/*` (~280 files: tick_bundle, heartbeat_no_change_*, src04_s09_*,
  apply_/check_/refresh_/run_/validate_*.ps1)
- `artifacts/qua-314/pipeline_heartbeat_*.md`
- `artifacts/qua-267/QUA-267_*.md`

**Recommendation:** Pipeline-Operator should triage and either commit a curated subset to
their worktree OR `rm -rf` the heartbeat spam. The volume of `tick_bundle_*.json` and
`heartbeat_no_change_*.json` files (~480) is a strong indicator of the looping-status-comment
anti-pattern noted in memory `paperclip_recovery_shell_root_cause`.

### CTO/general — small remainders

- `artifacts/qua-21/pr20_mirror_20260427_084558.json`
- `artifacts/qua-67/weekend_clone_defense_check.txt`
- `artifacts/qua-140/{close-comment-2026-04-27,cto-followup-body}.md`
- `artifacts/qua-260/marketplace-review/anthropics-skills/`, `obra-superpowers/` (review submodules)

### Junk — gitignore candidates (DevOps follow-up)

- `.claude/scheduled_tasks.lock` (runtime lock)
- `framework/scripts/__pycache__/*.pyc` (5 files)
- `framework/scripts/tests/__pycache__/*.pyc` (3 files)
- `framework/tests/unit/__pycache__/*.pyc` (3 files)
- `infra/scripts/__pycache__/*.pyc` (4 files)
- `infra/scripts/tests/__pycache__/*.pyc` (1 file)

These should be added to `.gitignore` (DevOps task — included in the QUA-589 enforcer
follow-up issue).

## Enforcer follow-up (DevOps)

Per QUA-589 acceptance criterion #2, DevOps to file the pre-commit/scheduled enforcer that
blocks `QUA-*_*` artifact commits to `main` going forward. A child issue will be opened for
DevOps with this routing table as context.

## Acceptance status (this commit)

- [x] `git status -s` in main shows zero `QUA-*_*` untracked **files** (matched `docs/ops/QUA-NNN_*` pattern).
- [x] Zero `docs/ops/QUA-*` artifacts on main; routed to docs-km.
- [x] OWNER-managed `paperclip-prompts/*.md` modifications reverted on main.
- [x] `decisions/DL-029_strategy_research_workflow.md` deletion restored on main.
- [ ] Source-of-truth modifications (CLAUDE.md, framework/, etc.) — routed to owners via this
      table; awaiting owner pickup. Each owner has a child issue.
- [ ] Per-ticket `artifacts/qua-NNN/` directories — routed to owners; awaiting pickup.
- [ ] DevOps enforcer follow-up — child issue filed.

## Owner action

Each owner: pull this routing table, take their files, commit on their worktree, revert/remove on main.
File a follow-up comment on QUA-589 when your slice is clear.
