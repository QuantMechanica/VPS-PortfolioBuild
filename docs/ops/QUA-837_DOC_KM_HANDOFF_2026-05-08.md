# QUA-837 Doc-KM Handoff Packet

Date: 2026-05-08
Issue: QUA-837
Prepared by: DevOps

## Purpose

Provide copy-ready entries for Doc-KM to register two new tooling scripts in:

- `06 Infrastructure/Tools and Scripts.md`

## Scripts to register

1. `framework/scripts/lint_strategy_wiki.py`
- CLI: `python framework/scripts/lint_strategy_wiki.py [--vault PATH]`
- Default vault: `G:\My Drive\09 Strategy Wiki`
- Function: deterministic lint for Strategy Wiki graph
  - broken `[[...]]` cross-refs
  - missing YAML frontmatter
  - `_INDEX.md` drift vs filesystem
  - duplicate IDs/slugs
- Exit codes:
  - `0` = clean
  - `1` = violations or invalid vault

2. `framework/scripts/research_dedup_check.py` (extended)
- Existing CLI preserved (`check`, `list`, `audit`)
- New behavior: now ingests both sources
  - `strategy-seeds/cards/*.md`
  - `09 Strategy Wiki/strategies/*.md` (via `--vault`, default above)
- Cross-source duplicate detection now reports source tag (e.g. `[wiki]`)

## Implementation evidence

- Main implementation commit: `f5b6137b`
- Closeout evidence commit: `9bfe9a0a`
- Closeout artifact: `docs/ops/QUA-837_CLOSEOUT_2026-05-08.md`

## Suggested Doc-KM markdown snippet

```markdown
### lint_strategy_wiki.py
Path: `framework/scripts/lint_strategy_wiki.py`

Deterministic lint for `09 Strategy Wiki/` graph integrity. Checks broken cross-references, missing YAML frontmatter, `_INDEX.md` drift, and duplicate IDs/slugs.

Run:
`python framework/scripts/lint_strategy_wiki.py [--vault PATH]`

Default vault path:
`G:\My Drive\09 Strategy Wiki`

### research_dedup_check.py
Path: `framework/scripts/research_dedup_check.py`

Research dedup checker across strategy cards and wiki strategy nodes. Commands: `check`, `list`, `audit`.

Run examples:
- `python framework/scripts/research_dedup_check.py check --slug <slug> --strategy-id <id> [--vault PATH]`
- `python framework/scripts/research_dedup_check.py list [--vault PATH]`
- `python framework/scripts/research_dedup_check.py audit [--vault PATH]`
```
