# Skills Adoption — V5 Initial Pin

Date: 2026-04-27
Owner: Documentation-KM
Reviewer: CTO (technical correctness), CEO (assignment matrix), OWNER (veto)
Issue: QUA-251
Status: PARTIALLY EXECUTED — CTO body review complete and required marketplace `commit_pin` values filled on 2026-04-27; Paperclip skill imports blocked by missing runtime permission (`can create agents`)

## Context

OWNER directive 2026-04-27 ~15:00 local (relayed via Board Advisor) instructed V5 to adopt Paperclip's Skills system to migrate V4-era procedural how-tos into reusable, token-efficient instruction bundles loadable on demand by agents.

Per Paperclip docs (https://aronprins.github.io/paperclip-docs/, `docs/guides/org/skills.md`):

> "A skill is a reusable instruction document that agents can load on demand… Use when… / Don't use when… loaded only when relevant."

V4 procedures were either embedded in agent prompts (bloating system context) or scattered across long-form ops docs (hard to discover at the right moment). Skills are the right home: scoped routing, source-of-truth body, version-pinned.

## Decision

V5 adopts the Skills system in two parts:

1. **Custom V5 Skills** (6 authored, this work): trading-specific procedures the marketplace cannot supply. Authored by Doc-KM under `skills/qm/`.
2. **Marketplace Skills** (7 required + 5 optional): ready-made skills from `anthropics/skills` and `obra/superpowers` covering authoring framework, file-format readers, verification discipline, worktrees, TDD, debugging.

Skills do **not** override agent prompts (`paperclip-prompts/*.md`). They augment. Hard rules stay in `CLAUDE.md` + agent prompts; skills are how-tos.

## Custom V5 Skills authored

| # | Skill | Owner | Reviewer | Body source |
|---|---|---|---|---|
| 1 | `qm-validate-custom-symbol` | DevOps + Pipeline-Operator | Quality-Tech | `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md` |
| 2 | `qm-strategy-card-extraction` | Research | CEO + Quality-Business | `paperclip-prompts/research.md` + `strategy-seeds/cards/_TEMPLATE.md` |
| 3 | `qm-build-ea-from-card` | Development | CTO | `framework/V5_FRAMEWORK_DESIGN.md` |
| 4 | `qm-run-pipeline-phase` | Pipeline-Operator | Quality-Tech | `framework/scripts/run_phase.ps1` + `docs/ops/PIPELINE_PHASE_SPEC.md` |
| 5 | `qm-t6-deploy-verification` | LiveOps | OWNER | `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md` |
| 6 | `qm-zero-trades-recovery` | Strategy-Analyst + R-and-D + CEO + CTO | Quality-Tech | `processes/02-zt-recovery.md` + V5 enhancement loop QUA-236 |

All 6 skills mirror existing reference docs verbatim. Doc-KM did **not** invent procedures — content is sourced from the basis docs cited above.

## Marketplace skills pinned (Required tier)

Per `skills/marketplace/INDEX.md`. `commit_pin` is `TBD` for all entries until CTO review.

| Skill | Source | Assigned to |
|---|---|---|
| `anthropics/skills/skill-creator` | anthropics/skills | Doc-KM, CTO |
| `anthropics/skills/pdf` | anthropics/skills | Research |
| `anthropics/skills/xlsx` | anthropics/skills | Pipeline-Op, CTO |
| `obra/superpowers/verification-before-completion` | obra/superpowers | CEO, CTO, DevOps |
| `obra/superpowers/using-git-worktrees` | obra/superpowers | CTO, DevOps |
| `obra/superpowers/test-driven-development` | obra/superpowers | CTO, Development |
| `obra/superpowers/systematic-debugging` | obra/superpowers | DevOps |

## Optional tier (assign on demand)

- `obra/superpowers/writing-plans` + `executing-plans`
- `obra/superpowers/requesting-code-review` + `receiving-code-review`
- `firecrawl/cli` + `firecrawl-scrape` + `firecrawl-search`
- `lllllllama/ai-paper-reproduction-skill/paper-context-resolver`
- `anthropics/skills/mcp-builder` (deferred until real MCP need)

## Explicitly NOT pinned

The skills.sh marketplace skews startup-frontend. Skipped:
- Marketing skills (auto-post, copywriting templates)
- Mobile / frontend design skills
- Azure / Firebase / Vercel deploy skills
- Generic web-dev scaffolds

The trading-specific procedures (the 6 `skills/qm/*` set) had to be authored ourselves.

## Governance

- **Doc-KM** authors and maintains the inventory (`skills/qm/*` and `skills/marketplace/INDEX.md`).
- **CTO** reviews each skill body for technical correctness. For marketplace skills, CTO clones the source repo at HEAD, reviews the body, and fills `commit_pin: <SHA>` + `reviewed_at` + `reviewed_by: CTO`.
- **CEO** ratifies the assignment matrix (which agent gets which skill required vs. optional).
- **OWNER** has veto on any external pin via request_confirmation.
- **No agent** registers a marketplace skill in Paperclip until pin + ratification complete.

## Pin lifecycle

A marketplace skill becomes registered in Paperclip ("Add Skill → marketplace") only after:

1. CTO fills `commit_pin: <SHA>` + `reviewed_at` + `reviewed_by: CTO` in `INDEX.md`
2. CEO ratifies the assignment in `processes/process_registry.md` § Skills
3. (For sensitive sources) OWNER accepts a request_confirmation interaction

Until then, the entry is `TBD` and not visible to agents.

## Rationale

- **Token efficiency:** agent system prompts shrink — procedural how-tos move out of always-on context.
- **Discoverability:** a skill's frontmatter (`Use when X / Don't use when Y`) is a routing oracle, not a doc-search problem.
- **Source-of-truth single point:** each skill cites a basis doc and mirrors it. No duplicate maintenance burden.
- **Trust + provenance:** marketplace skills are commit-pinned. Pin updates are deliberate, not implicit.
- **Eat-own-dogfood:** authoring the 6 V5 skills with `anthropics/skills/skill-creator` is the same pattern as the PC1-00 worktree mitigation — use the tool you intend to recommend.

## Boundary (PC1-00 + V5 hard rules preserved)

- Skills do **not** override `paperclip-prompts/*.md` or `CLAUDE.md`.
- T6 stays OFF LIMITS — `qm-t6-deploy-verification` is read-only verification with AutoTrading OFF, never toggles.
- `qm-build-ea-from-card` does not touch `framework/scripts/*` or `include/QM_*.mqh` (CTO + Quality-Tech territory).
- Agents do not auto-publish anything — show notes, public copy, etc. all go through OWNER sign-off (Doc-KM rule preserved).

## Acceptance (per QUA-251)

- [x] All 6 custom skills authored under `skills/qm/` with `SKILL.md` + frontmatter routing
- [x] Skill folder layout matches the issue spec (including `references/` subfolders for skills 1, 4, 5)
- [x] `processes/process_registry.md` § Skills updated with inventory + assignment matrix
- [x] This DL entry authored
- [ ] Each skill committed to repo + registered in Paperclip via "Add Skill → Local folder" (commit step complete; Paperclip registration blocked by runtime permission mismatch on QUA-260)
- [x] Required marketplace skills `commit_pin`-locked by CTO and assigned to listed agents
- [ ] CEO ratifies assignment matrix
- [ ] OWNER veto window passes (no objections within heartbeat round)

## Approval evidence

- OWNER directive: relayed by Board Advisor 2026-04-27 ~15:00 local (per QUA-251 issue body)
- Doc-KM execution commit: `ced53a6` (`docs(skills): author 6 V5 skills + pin marketplace inventory (QUA-251)`)
- CTO review completed on 2026-04-27 (custom-skill body review + required marketplace pin lock)
- CEO ratification pending

## References

- `skills/README.md` — top-level skills layout
- `skills/qm/` — custom V5 skills
- `skills/marketplace/INDEX.md` — marketplace pin inventory + assignment matrix
- `processes/process_registry.md` § Skills — assignment matrix (canonical)
- `paperclip-prompts/documentation-km.md` — Doc-KM ownership of skills layer (V5 BASIS)
- Paperclip Skills doc: https://aronprins.github.io/paperclip-docs/ → `docs/guides/org/skills.md`
- QUA-236 children: strategy_type_flags vocabulary, V5 enhancement loop, distribution queue (referenced by skills 2, 4, 6)
