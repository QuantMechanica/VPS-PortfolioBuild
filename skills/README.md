# Skills

Skills are reusable execution instructions loaded only when their trigger applies.
They describe how to perform bounded work; they do not grant authority or create an
approval gate.

## Repository layout

```text
skills/
  qm/
    qm-strategy-card-extraction/
    qm-validate-custom-symbol/
  marketplace/
    INDEX.md
```

Additional installed skills may live in the current Codex/Claude skill catalog
outside this repository. The catalog presented to the running worker is the source
of truth for availability.

## Governance

- OWNER is the sole human approval authority.
- A skill's technical preconditions and safety boundaries remain binding.
- A skill cannot override `CLAUDE.md`, the active process registry, an OWNER
  instruction, or an exact deployment manifest.
- Obsolete persona or title names in a legacy copy do not add a signature gate.
- External skills require a source URL, immutable commit pin, body review, license
  review where applicable, and OWNER authorization before installation.

## Authoring

Every repository skill has a complete `SKILL.md` with:

```yaml
---
name: <skill-name>
description: Use when <X>. Don't use when <Y>.
last-updated: YYYY-MM-DD
basis: <source doc path>
---
```

The body must cite current repository contracts and must not invent policy. Update
the skill when its basis changes, and test any bundled script independently.

See [process registry](../processes/process_registry.md) for authority semantics and
[marketplace inventory](marketplace/INDEX.md) for external provenance pins.
