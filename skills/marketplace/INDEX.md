# Marketplace Skills — Pinned Inventory

This inventory records external-skill provenance. A pin is not an approval to use a
skill on live systems and does not grant governance authority.

## Pin contract

Every installed external skill requires:

- source repository and path;
- immutable commit SHA;
- dated technical/body review record;
- explicit intended use;
- OWNER authorization for installation or assignment.

`commit_pin: TBD` means the skill is unavailable until review and OWNER authorization
are complete. Reviews should identify the individual worker or evidence artifact,
not an invented organizational title.

## Recorded pins

| Skill | Source / path | Commit pin | Reviewed | Intended use |
|---|---|---|---|---|
| `anthropics/skills/skill-creator` | `https://github.com/anthropics/skills`, `skill-creator/` | `5128e1865d670f5d6c9cef000e6dfc4e951fb5b9` | 2026-04-27 | Authoring reusable skills |
| `anthropics/skills/pdf` | `https://github.com/anthropics/skills`, `pdf/` | `5128e1865d670f5d6c9cef000e6dfc4e951fb5b9` | 2026-04-27 | Paper and book extraction |
| `anthropics/skills/xlsx` | `https://github.com/anthropics/skills`, `xlsx/` | `5128e1865d670f5d6c9cef000e6dfc4e951fb5b9` | 2026-04-27 | Spreadsheet/report inspection |
| `obra/superpowers/verification-before-completion` | `https://github.com/obra/superpowers`, `verification-before-completion/` | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` | 2026-04-27 | Evidence-first completion checks |
| `obra/superpowers/using-git-worktrees` | `https://github.com/obra/superpowers`, `using-git-worktrees/` | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` | 2026-04-27 | Isolated task worktrees |
| `obra/superpowers/test-driven-development` | `https://github.com/obra/superpowers`, `test-driven-development/` | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` | 2026-04-27 | Framework and tooling changes |
| `obra/superpowers/systematic-debugging` | `https://github.com/obra/superpowers`, `systematic-debugging/` | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` | 2026-04-27 | Incident and defect diagnosis |

Optional candidates such as planning, code-review, scraping, paper-analysis, or MCP
builder skills remain uninstalled until a concrete task needs them and OWNER
authorizes the reviewed pin.

Marketing, generic frontend/mobile scaffolds, and unrelated cloud-deployment skills
are outside the QuantMechanica strategy-farm scope.

## Adding a pin

1. Record source, path, proposed use, and `commit_pin: TBD`.
2. Review the exact pinned body and bundled executable content.
3. Record the immutable SHA, review artifact, and date.
4. Obtain OWNER authorization.
5. Install/register the exact pin and verify the resulting catalog entry.

See [custom skills](../README.md) and the [process registry](../../processes/process_registry.md).
