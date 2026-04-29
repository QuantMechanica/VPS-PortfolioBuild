# Skills

Reusable instruction documents that QuantMechanica V5 agents load on demand. Per Paperclip's Skills system (`docs/guides/org/skills.md`):

> "A skill is a reusable instruction document that agents can load on demand… Use when… / Don't use when… loaded only when relevant."

## Layout

```
skills/
  qm/                        # Custom QM-authored skills (V5 procedural how-tos)
    qm-validate-custom-symbol/
    qm-strategy-card-extraction/
    qm-build-ea-from-card/
    qm-run-pipeline-phase/
    qm-t6-deploy-verification/
    qm-zero-trades-recovery/
  marketplace/               # Pinned external skills (anthropics/skills, obra/superpowers, etc.)
    INDEX.md                 # Provenance + commit pins + assignment matrix
```

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
