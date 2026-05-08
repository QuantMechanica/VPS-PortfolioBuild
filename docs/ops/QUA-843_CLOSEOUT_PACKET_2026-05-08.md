# QUA-843 Closeout Packet

Date: 2026-05-08
Issue: QUA-843
Commit: dc8d4527

## Acceptance Criteria Mapping

- Skill-audit table: docs/ops/SKILL_REFACTOR_AUDIT_2026-05.md (present)
- Skills cleaned in skills/qm/: yes (13/13 rewritten to policy + deterministic invocation)
- Average reduction >=20%: achieved (9317 -> 1166 words, -87.5%)
- Closeout commit hash + before/after diff: included below

## Commit Summary

`
dc8d4527 refactor(skills): determinism-first rewrite for 13 QM skills  .../QUA-843_WAVE1_REFACTOR_2026-05-08T133614Z.md   |  32 ++++  .../QUA-843_WAVE2_REFACTOR_2026-05-08T133936Z.md   |  36 ++++  .../QUA-843_WAVE3_REFACTOR_2026-05-08T134212Z.md   |  30 ++++  docs/ops/SKILL_REFACTOR_AUDIT_2026-05.md           | 143 ++++++++++++++++  framework/scripts/skill_build_ea_guard.py          |  35 ++++  framework/scripts/skill_card_schema_lint.py        |  24 +++  framework/scripts/skill_g0_card_lint.py            |  20 +++  framework/scripts/skill_new_setfiles_run.py        |  85 +++++++++  framework/scripts/skill_p2_baseline_guard.py       |  78 +++++++++  framework/scripts/skill_p3_sweep_guard.py          |  52 ++++++  framework/scripts/skill_p4_montecarlo_guard.py     |  51 ++++++  framework/scripts/skill_phase_runner_guard.py      |  80 +++++++++  .../scripts/skill_pipeline_status_snapshot.py      |  97 +++++++++++  framework/scripts/skill_render_dashboard_run.py    |  81 +++++++++  framework/scripts/skill_symbol_validation_lint.py  |  28 +++  framework/scripts/skill_t6_verify_bundle.py        |  23 +++  framework/scripts/skill_zero_trades_triage.py      |  26 +++  skills/qm/qm-build-ea-from-card/SKILL.md           | 189 ++-------------------  skills/qm/qm-g0-review/SKILL.md                    | 100 +----------  skills/qm/qm-new-setfiles/SKILL.md                 |  97 +++--------  skills/qm/qm-p2-baseline/SKILL.md                  | 125 +++-----------  skills/qm/qm-p3-sweep/SKILL.md                     | 127 ++------------  skills/qm/qm-p4-montecarlo/SKILL.md                | 129 ++------------  skills/qm/qm-pipeline-status/SKILL.md              | 119 +++----------  skills/qm/qm-render-dashboard/SKILL.md             |  81 +++------  skills/qm/qm-run-pipeline-phase/SKILL.md           | 126 ++------------  skills/qm/qm-strategy-card-extraction/SKILL.md     | 125 ++------------  skills/qm/qm-t6-deploy-verification/SKILL.md       | 169 ++----------------  skills/qm/qm-validate-custom-symbol/SKILL.md       |  94 ++--------  skills/qm/qm-zero-trades-recovery/SKILL.md         | 166 ++----------------  30 files changed, 1121 insertions(+), 1447 deletions(-)
`

## File-Level Change List

`
A	docs/ops/QUA-843_WAVE1_REFACTOR_2026-05-08T133614Z.md A	docs/ops/QUA-843_WAVE2_REFACTOR_2026-05-08T133936Z.md A	docs/ops/QUA-843_WAVE3_REFACTOR_2026-05-08T134212Z.md A	docs/ops/SKILL_REFACTOR_AUDIT_2026-05.md A	framework/scripts/skill_build_ea_guard.py A	framework/scripts/skill_card_schema_lint.py A	framework/scripts/skill_g0_card_lint.py A	framework/scripts/skill_new_setfiles_run.py A	framework/scripts/skill_p2_baseline_guard.py A	framework/scripts/skill_p3_sweep_guard.py A	framework/scripts/skill_p4_montecarlo_guard.py A	framework/scripts/skill_phase_runner_guard.py A	framework/scripts/skill_pipeline_status_snapshot.py A	framework/scripts/skill_render_dashboard_run.py A	framework/scripts/skill_symbol_validation_lint.py A	framework/scripts/skill_t6_verify_bundle.py A	framework/scripts/skill_zero_trades_triage.py M	skills/qm/qm-build-ea-from-card/SKILL.md M	skills/qm/qm-g0-review/SKILL.md M	skills/qm/qm-new-setfiles/SKILL.md M	skills/qm/qm-p2-baseline/SKILL.md M	skills/qm/qm-p3-sweep/SKILL.md M	skills/qm/qm-p4-montecarlo/SKILL.md M	skills/qm/qm-pipeline-status/SKILL.md M	skills/qm/qm-render-dashboard/SKILL.md M	skills/qm/qm-run-pipeline-phase/SKILL.md M	skills/qm/qm-strategy-card-extraction/SKILL.md M	skills/qm/qm-t6-deploy-verification/SKILL.md M	skills/qm/qm-validate-custom-symbol/SKILL.md M	skills/qm/qm-zero-trades-recovery/SKILL.md
`

## Deterministic Script Surface Added

- ramework/scripts/skill_new_setfiles_run.py
- ramework/scripts/skill_render_dashboard_run.py
- ramework/scripts/skill_pipeline_status_snapshot.py
- ramework/scripts/skill_p2_baseline_guard.py
- ramework/scripts/skill_p3_sweep_guard.py
- ramework/scripts/skill_p4_montecarlo_guard.py
- ramework/scripts/skill_phase_runner_guard.py
- ramework/scripts/skill_build_ea_guard.py
- ramework/scripts/skill_g0_card_lint.py
- ramework/scripts/skill_card_schema_lint.py
- ramework/scripts/skill_symbol_validation_lint.py
- ramework/scripts/skill_zero_trades_triage.py
- ramework/scripts/skill_t6_verify_bundle.py

## Verification Evidence

- python -m py_compile passed for all new deterministic scripts (Wave 1-3)
- --help smoke checks passed for all new deterministic scripts (Wave 1-3)
