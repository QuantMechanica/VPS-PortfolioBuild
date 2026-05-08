# Skills

Reusable instruction documents that QuantMechanica V5 agents load on demand. Per Paperclip's Skills system (`docs/guides/org/skills.md`):

> "A skill is a reusable instruction document that agents can load on demand… Use when… / Don't use when… loaded only when relevant."

## Layout

```
skills/
  qm/                        # Custom QM-authored skills (V5 procedural how-tos)
    qm-g0-review/              # G0 gate: CEO reviews Strategy Card (R1-R4)
    qm-strategy-card-extraction/  # Research extracts cards from approved sources
    qm-build-ea-from-card/     # Development builds .mq5 EA from APPROVED card
    qm-new-setfiles/           # Pipeline-Operator generates backtest .set files
    qm-p2-baseline/            # Pipeline-Operator runs P2 baseline sweep
    qm-p3-sweep/               # Research + Pipeline-Operator run P3 parameter sweep
    qm-run-pipeline-phase/     # Pipeline-Operator runs P3.5/P5/P5b/P5c/P6/P7/P8
    qm-p4-montecarlo/          # Research + CTO run P4 Monte Carlo validation
    qm-t6-deploy-verification/ # LiveOps verifies T6 deploy under OWNER manifest
    qm-zero-trades-recovery/   # Pipeline-Operator diagnoses cohort zero-trade events
    qm-validate-custom-symbol/ # DevOps validates custom symbols vs broker feed
    qm-pipeline-status/        # CEO/DevOps checks current pipeline state
    qm-render-dashboard/       # DevOps regenerates ops dashboard HTML
  marketplace/               # Pinned external skills (anthropics/skills, obra/superpowers, etc.)
    INDEX.md                 # Provenance + commit pins + assignment matrix
```

## Pipeline Coverage

| Gate | Phase | Skill |
|------|-------|-------|
| G0 | Research intake | `qm-g0-review` (CEO verdict) + `qm-strategy-card-extraction` (Research) |
| P1 | EA build | `qm-build-ea-from-card` (Development/CTO) + `qm-new-setfiles` (Pipeline-Op) |
| P2 | Baseline sweep | `qm-p2-baseline` (Pipeline-Operator) |
| P3 | Parameter sweep | `qm-p3-sweep` (Research + Pipeline-Op) |
| P3.5 | Walk-forward | `qm-run-pipeline-phase` (Pipeline-Operator) |
| P4 | Monte Carlo | `qm-p4-montecarlo` (Research + CTO) |
| P5-P8 | Stress/Stats/News | `qm-run-pipeline-phase` (Pipeline-Operator) |
| P9-P10 | Live shadow/deploy | `qm-t6-deploy-verification` (LiveOps/DevOps interim) |
| Ops | Cross-cutting | `qm-pipeline-status`, `qm-render-dashboard`, `qm-validate-custom-symbol`, `qm-zero-trades-recovery` |

Each `skills/qm/<skill-name>/` folder contains a `SKILL.md` (frontmatter routing + body) and an optional `references/` subfolder for support material.

## Governance

- **Doc-KM** authors and maintains custom skills + marketplace inventory.
- **CTO** reviews skill bodies for technical correctness; fills marketplace `commit_pin` on approval.
- **CEO** ratifies the assignment matrix.
- **OWNER** has veto on external skill pins.

Skills do **not** override agent prompts (`paperclip-prompts/*.md`) — they augment. Hard rules stay in `CLAUDE.md` and agent prompts; skills are how-tos.

## Authoring a new skill

Use the `anthropics/skills/skill-creator` marketplace skill (eat-own-dogfood pattern from PC1-00 mitigation). The frontmatter must include:

```yaml
---
name: <skill-name>
description: Use when <X>. Don't use when <Y>.
owner: <role>
reviewer: <role>
last-updated: YYYY-MM-DD
basis: <source doc path>
---
```

Body content must mirror existing reference docs — do **not** invent procedures. Cite source paths in the References section.

## See also

- `decisions/2026-04-27_skills_adoption_v1.md` — adoption rationale + OWNER directive
- `processes/process_registry.md` § Skills — the assignment matrix
- `paperclip-prompts/documentation-km.md` § Core Responsibilities — Doc-KM ownership of the skills layer
