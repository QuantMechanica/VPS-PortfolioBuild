# Marketplace Skills — Pinned Inventory

Skills pinned from external marketplaces (skills.sh / Anthropic / community repos) and assigned to QuantMechanica V5 agents. Per `docs/guides/org/skills.md` § "Trust and Source Provenance" (Paperclip docs), each pinned skill must have:

- **Source provenance** (GitHub repo + commit hash)
- **Body review** before assignment
- **Required vs. optional** classification per agent

## Pin governance

- **Doc-KM** authors this inventory and assignment matrix.
- **CTO** reviews each skill body for technical correctness and fills `commit_pin` on approval.
- **CEO** ratifies the assignment matrix.
- **OWNER** has veto on any external skill pin (request_confirmation interaction).

`commit_pin: TBD` means CTO has not yet reviewed; the skill is **not** registered in Paperclip until pinned. After CTO review, the entry is updated with:

- `commit_pin: <SHA>`
- `reviewed_at: YYYY-MM-DD`
- `reviewed_by: CTO`

---

## Required skills (assign on CTO pin + CEO ratification)

### 1. `anthropics/skills/skill-creator`

| Field | Value |
|---|---|
| Source | https://github.com/anthropics/skills |
| Path | `skill-creator/` |
| commit_pin | `5128e1865d670f5d6c9cef000e6dfc4e951fb5b9` |
| reviewed_at | `2026-04-27` |
| reviewed_by | `CTO` |
| Assigned to | Documentation-KM, CTO |
| Why | Authoring framework for the 6 custom V5 skills (eat-own-dogfood pattern) |

### 2. `anthropics/skills/pdf`

| Field | Value |
|---|---|
| Source | https://github.com/anthropics/skills |
| Path | `pdf/` |
| commit_pin | `5128e1865d670f5d6c9cef000e6dfc4e951fb5b9` |
| reviewed_at | `2026-04-27` |
| reviewed_by | `CTO` |
| Assigned to | Research |
| Why | Reading books / papers (Ernest Chan, Kaufman, Ehlers PDFs) for `qm-strategy-card-extraction` |

### 3. `anthropics/skills/xlsx`

| Field | Value |
|---|---|
| Source | https://github.com/anthropics/skills |
| Path | `xlsx/` |
| commit_pin | `5128e1865d670f5d6c9cef000e6dfc4e951fb5b9` |
| reviewed_at | `2026-04-27` |
| reviewed_by | `CTO` |
| Assigned to | Pipeline-Operator, CTO |
| Why | Backtest report parsing + commission table handling |

### 4. `obra/superpowers/verification-before-completion`

| Field | Value |
|---|---|
| Source | https://github.com/obra/superpowers |
| Path | `verification-before-completion/` |
| commit_pin | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` |
| reviewed_at | `2026-04-27` |
| reviewed_by | `CTO` |
| Assigned to | CEO, CTO, DevOps |
| Why | Codifies the "verify before promote" pattern already running at QM (PC1-00 mitigation, T6 deploy verification, etc.) |

### 5. `obra/superpowers/using-git-worktrees`

| Field | Value |
|---|---|
| Source | https://github.com/obra/superpowers |
| Path | `using-git-worktrees/` |
| commit_pin | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` |
| reviewed_at | `2026-04-27` |
| reviewed_by | `CTO` |
| Assigned to | CTO, DevOps |
| Why | Codifies PC1-00 Drive-vs-Git mitigation pattern (already running per `docs/ops/PC1-00_WORKTREE_PROOF_2026-04-27.md`) |

### 6. `obra/superpowers/test-driven-development`

| Field | Value |
|---|---|
| Source | https://github.com/obra/superpowers |
| Path | `test-driven-development/` |
| commit_pin | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` |
| reviewed_at | `2026-04-27` |
| reviewed_by | `CTO` |
| Assigned to | CTO, Development |
| Why | TDD discipline for framework includes (`include/QM_*.mqh`) and EA build code |

### 7. `obra/superpowers/systematic-debugging`

| Field | Value |
|---|---|
| Source | https://github.com/obra/superpowers |
| Path | `systematic-debugging/` |
| commit_pin | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` |
| reviewed_at | `2026-04-27` |
| reviewed_by | `CTO` |
| Assigned to | DevOps |
| Why | Debugging methodology for incidents (P0 / P1 incident response per `processes/04-incident-response.md`) |

---

## Optional skills (assign on demand per role need)

### `obra/superpowers/writing-plans` + `executing-plans`

- **Source:** https://github.com/obra/superpowers
- **Why:** CEO planning discipline — pin if CEO needs a structured planning skill beyond the core prompt
- **Assign trigger:** CEO requests, OR a planning quality issue is filed

### `obra/superpowers/requesting-code-review` + `receiving-code-review`

- **Source:** https://github.com/obra/superpowers
- **Why:** CTO ↔ CEO/Quality-Tech dialectic protocol
- **Assign trigger:** Friction observed in code review handoffs, OR CTO requests

### `firecrawl/cli` + `firecrawl-scrape` + `firecrawl-search`

- **Source:** https://github.com/firecrawl/cli (or skills.sh listing)
- **Why:** Research scraping (Adam Grimes blog, etc.) and structured search
- **Assign trigger:** Research needs to scrape a non-PDF source; pinned per-source rather than always-on

### `lllllllama/ai-paper-reproduction-skill/paper-context-resolver`

- **Source:** https://github.com/lllllllama/ai-paper-reproduction-skill
- **Why:** Academic paper analysis (Ehlers DSP papers etc.)
- **Assign trigger:** Research is mining an academic paper that requires citation graph traversal

### `anthropics/skills/mcp-builder`

- **Source:** https://github.com/anthropics/skills
- **Why:** Building a custom MT5 MCP — **deferred** until a real need arises
- **Assign trigger:** OWNER approves a custom-MCP project; not before

---

## Explicitly NOT pinned (skip)

The skills.sh marketplace skews startup-frontend. The following classes are **not relevant** to QuantMechanica V5 and will not be pinned:

- Marketing skills (social-media auto-post, copywriting templates)
- Mobile / frontend design skills (React Native, Figma helpers, design-system generators)
- Azure / Firebase / Vercel deploy skills (we run on a single Windows VPS + Drive + Git)
- Generic web-dev scaffolds

The trading-specific procedures had to be authored ourselves — that is the 6 `skills/qm/*` set.

---

## Process for adding a new marketplace skill

1. **Doc-KM proposes:** add a new entry under "Required" or "Optional" with `commit_pin: TBD` + provenance + assigned-to + why.
2. **CTO reviews:** clones the source repo at HEAD, reviews the skill body for technical correctness, fills `commit_pin: <SHA>` + `reviewed_at` + `reviewed_by: CTO`.
3. **CEO ratifies:** the assignment matrix changes (who gets the skill required vs. optional).
4. **OWNER veto:** any external skill pin is subject to OWNER veto via request_confirmation.
5. **Paperclip registration:** after pin, register via "Add Skill → marketplace" with the locked commit hash.

## References

- Paperclip Skills doc (Aron Prins): https://aronprins.github.io/paperclip-docs/ → `docs/guides/org/skills.md`
- Custom V5 skills inventory: `skills/qm/`
- Skills adoption decision: `decisions/2026-04-27_skills_adoption_v1.md`
- Process registry skills section: `processes/process_registry.md` § Skills
