# Skill Refactor Audit (Determinism First) - 2026-05

Date: 2026-05-08  
Issue: QUA-843  
Scope: 13 skills in `skills/qm/*/SKILL.md`

## Baseline

- Skill count: 13
- Total SKILL.md size: 1665 lines / 9317 words
- Average per skill: 128.1 lines / 716.7 words
- Determinism finding: most skills mix policy + executable runbook steps that can be moved to scripts with structured outputs.

## Per-Skill Audit Table

| Skill | Current Size (lines/words) | LLM Reasoning (keep in SKILL) | Deterministic Steps (migrate) | Target script path in `framework/scripts/` | Refactor decision |
|---|---:|---|---|---|---|
| `qm-build-ea-from-card` | 190 / 1054 | Card interpretation, module-boundary design judgment, risk/hard-rule interpretation | Registry presence checks, magic-collision checks, setfile header checks, build-check invocation | `skill_build_prep_check.py` | Refactor now |
| `qm-g0-review` | 104 / 525 | Human review of card completeness and strategy semantics | Card field presence validation, vocabulary validation, checklist rendering | `skill_g0_card_lint.py` | Refactor now |
| `qm-new-setfiles` | 101 / 388 | Minimal; mostly procedural | Generate setfiles, verify output existence/shape, spot-check required header fields | `skill_new_setfiles_run.py` | Refactor now |
| `qm-p2-baseline` | 127 / 658 | Exception handling when partial FAIL/INVALID patterns need operator judgment | Dry-run, lock check, report-path checks, report summary parse, mark_done payload generation | `skill_p2_baseline_run.py` | Refactor now |
| `qm-p3-sweep` | 130 / 626 | Parameter-grid rationale and escalation decisions | PASS-symbol extraction from P2 report, output path checks, report skeleton generation | `skill_p3_sweep_run.py` | Refactor now |
| `qm-p4-montecarlo` | 130 / 575 | Methodological acceptance judgment (reshuffle appropriateness) | Input report read, run wrapper invocation, output metrics parse, threshold compare | `skill_p4_montecarlo_eval.py` | Refactor now |
| `qm-pipeline-status` | 120 / 500 | Summary narrative and triage priorities | Issue fetch, EA phase probing, terminal process checks, kanban snapshot merge | `skill_pipeline_status_snapshot.py` | Refactor now |
| `qm-render-dashboard` | 85 / 358 | Only decision: whether run timing is safe | Render command invocation, output file sanity checks, source freshness checks | `skill_render_dashboard_run.py` | Refactor now |
| `qm-run-pipeline-phase` | 127 / 872 | Escalation decisions on phase-level failures | Parameter validation, symbol registry validation, report-json schema checks, phase evidence collation | `skill_phase_runner_guard.py` | Refactor now |
| `qm-strategy-card-extraction` | 124 / 931 | Core extraction reasoning is intentionally LLM-heavy | Card YAML/frontmatter schema lint, required section checks, forbidden ML token scan | `skill_card_schema_lint.py` | Keep + partial refactor |
| `qm-t6-deploy-verification` | 169 / 1038 | Human verification discipline and go/no-go interpretation | Checklist template generation, log-window extraction, hash/evidence bundle assembly | `skill_t6_verify_bundle.py` | Refactor now |
| `qm-validate-custom-symbol` | 92 / 662 | DST/time interpretation and mismatch classification | Evidence folder checks, CSV column schema validation, registry update payload prep | `skill_symbol_validation_lint.py` | Refactor now |
| `qm-zero-trades-recovery` | 166 / 1130 | Root-cause ranking and hypothesis selection | ZT cohort counting, report file-size checks, decision-matrix preclassification, evidence doc scaffold | `skill_zero_trades_triage.py` | Refactor now |

## Refactor Pattern (Determinism First)

1. Keep SKILL.md short: trigger conditions + policy rules + escalation matrix only.
2. Move procedural steps to script entrypoints with strict args and non-zero exits.
3. Emit machine-readable JSON (`status`, `checks`, `evidence_paths`, `next_action`) for each skill script.
4. SKILL.md calls script first; LLM only interprets `status=needs_judgment` cases.

## KPI Plan (Length Reduction)

- Current total: 9317 words
- Target minimum reduction (20%): <= 7453 words
- Planned reduction model:
  - Deterministic-heavy skills: reduce 30-45%
  - Mixed skills (`qm-build-ea-from-card`, `qm-strategy-card-extraction`, `qm-zero-trades-recovery`): reduce 15-30%
- Projected total after pass 1: ~6500-7000 words (24-30% reduction)

## Sequenced Follow-up PR Plan

1. PR-1: Introduce script scaffolds for `qm-new-setfiles`, `qm-render-dashboard`, `qm-pipeline-status`.
2. PR-2: Add execution/validation scripts for `qm-p2-baseline`, `qm-p3-sweep`, `qm-p4-montecarlo`, `qm-run-pipeline-phase`.
3. PR-3: Add governance/check scripts for `qm-build-ea-from-card`, `qm-g0-review`, `qm-validate-custom-symbol`, `qm-zero-trades-recovery`.
4. PR-4: Partial refactor of `qm-strategy-card-extraction` + `qm-t6-deploy-verification` support scripts.
5. PR-5: Shorten all `SKILL.md` files to policy-only shape and record before/after metrics.

## Notes

- This audit is deterministic-first and intentionally avoids changing V5 Hard Rules.
- No file deletions proposed.

## Implementation Progress (2026-05-08, Wave 1)

Completed in this heartbeat:
- Added deterministic wrappers:
  - `framework/scripts/skill_new_setfiles_run.py`
  - `framework/scripts/skill_render_dashboard_run.py`
  - `framework/scripts/skill_pipeline_status_snapshot.py`
- Refactored skills to policy+script form:
  - `skills/qm/qm-new-setfiles/SKILL.md`
  - `skills/qm/qm-render-dashboard/SKILL.md`
  - `skills/qm/qm-pipeline-status/SKILL.md`

Measured reductions (words):
- `qm-new-setfiles`: 388 -> 155 (`-60.1%`)
- `qm-render-dashboard`: 358 -> 127 (`-64.5%`)
- `qm-pipeline-status`: 500 -> 153 (`-69.4%`)
- Wave-1 subtotal: 1246 -> 435 (`-65.1%`)

Verification:
- `python -m py_compile` passed for all 3 new scripts.
- `--help` smoke checks passed for all 3 new scripts.

## Implementation Progress (2026-05-08, Wave 2)

Completed in this heartbeat:
- Added deterministic guard scripts:
  - `framework/scripts/skill_p2_baseline_guard.py`
  - `framework/scripts/skill_p3_sweep_guard.py`
  - `framework/scripts/skill_p4_montecarlo_guard.py`
  - `framework/scripts/skill_phase_runner_guard.py`
- Refactored skills to policy+script form:
  - `skills/qm/qm-p2-baseline/SKILL.md`
  - `skills/qm/qm-p3-sweep/SKILL.md`
  - `skills/qm/qm-p4-montecarlo/SKILL.md`
  - `skills/qm/qm-run-pipeline-phase/SKILL.md`

Measured reductions (words):
- `qm-p2-baseline`: 658 -> 105 (`-84.0%`)
- `qm-p3-sweep`: 626 -> 84 (`-86.6%`)
- `qm-p4-montecarlo`: 575 -> 93 (`-83.8%`)
- `qm-run-pipeline-phase`: 872 -> 102 (`-88.3%`)
- Wave-2 subtotal: 2731 -> 384 (`-85.9%`)

Cumulative (Wave 1 + Wave 2):
- 7 skills: 3977 -> 819 words (`-79.4%`)

Verification:
- `python -m py_compile` passed for all 4 new guard scripts.
- `--help` smoke checks passed for all 4 new guard scripts.

## Implementation Progress (2026-05-08, Wave 3)

Completed in this heartbeat:
- Added deterministic guard scripts:
  - `framework/scripts/skill_build_ea_guard.py`
  - `framework/scripts/skill_g0_card_lint.py`
  - `framework/scripts/skill_card_schema_lint.py`
  - `framework/scripts/skill_symbol_validation_lint.py`
  - `framework/scripts/skill_zero_trades_triage.py`
  - `framework/scripts/skill_t6_verify_bundle.py`
- Refactored skills to policy+script form:
  - `skills/qm/qm-build-ea-from-card/SKILL.md`
  - `skills/qm/qm-g0-review/SKILL.md`
  - `skills/qm/qm-strategy-card-extraction/SKILL.md`
  - `skills/qm/qm-validate-custom-symbol/SKILL.md`
  - `skills/qm/qm-zero-trades-recovery/SKILL.md`
  - `skills/qm/qm-t6-deploy-verification/SKILL.md`

Measured reductions (words):
- `qm-build-ea-from-card`: 1054 -> 66 (`-93.7%`)
- `qm-g0-review`: 525 -> 53 (`-89.9%`)
- `qm-strategy-card-extraction`: 931 -> 61 (`-93.4%`)
- `qm-validate-custom-symbol`: 662 -> 54 (`-91.8%`)
- `qm-zero-trades-recovery`: 1130 -> 56 (`-95.0%`)
- `qm-t6-deploy-verification`: 1038 -> 57 (`-94.5%`)
- Wave-3 subtotal: 5340 -> 347 (`-93.5%`)

Final cumulative result (all 13 skills):
- 9317 -> 1166 words (`-87.5%`)

Verification:
- `python -m py_compile` passed for all 6 new guard scripts.
- `--help` smoke checks passed for all 6 new guard scripts.
