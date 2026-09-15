# Slice b4_vault_rewrites — report

**Slice key:** `b4_vault_rewrites`
**Date:** 2026-09-15
**Authority:** OWNER-DEC-CBE-20260915 (Continuous Book Evolution master directive)
**Directive sections implemented:** §3, §4, §8, §10, §15, §23, §24, §25, §26, §28, §29, §30–§34,
§37, §38–§54, §60, §63, §64, §65–§67, §72.
**Scope:** direct in-place edits to the Company Reference Vault (`G:/My Drive/QuantMechanica -
Company Reference/`) — no git, no worktree. `patch_path = NONE (vault edits in place)`.

Supersession method used everywhere: **mark obsolete + update current guidance, never delete
history.** Current-guidance sentences on current-guidance pages struck with `~~ ~~`; each superseded
statement carries a dated annex block:
`> [!note] Superseded 2026-09-15 — OWNER-DEC-CBE-20260915 (§n): <old> → <new>. Record: C:/QM/repo/decisions/2026-09-15_owner_continuous_book_evolution.md`.
Historical/dated records (Gate Manifest v4 Diff, the 2026-08-23 delta blocks in Current Operating
State) were annotated append-only, not rewritten.

## Pages EDITED (existing)

| Vault page | Change | § |
|---|---|---|
| `_HOME.md` | Canonical manifest pointer v2 → **v4** (`gate_manifest.v4.json`); pipeline path "Q00–Q13 + Q14–Q16" → linear **Q00–Q17**; supersession annex. | §1/§65 |
| `START_HERE.md` | Rule 1 "don't self-choose work" → **Fable owns prioritisation & may originate strategies**; Rule 7 "research only if cards<5" → **autonomous edge discovery + parallel research by ROI**; Rule 8 "no ML" → **ML allowed offline / forbidden in EA runtime** (HR14 annex ref). | §37/§38/§49/§50/§41/§42 |
| `08 Current State/Current Objective.md` | New headline objective **CONTINUOUS BOOK EVOLUTION** (two living books); old "successful/fastest payouts" objective struck+annexed; FTMO section rewritten to probability-first + two-week Demo; **drain Zwischenziel superseded** (continuous pipeline); density gate reframed as input; v4 gate-path fix. | §0/§2/§73/§15/§23/§18/§5 |
| `01 Identity/Hard Rules.md` | **HR16 annex**: absolute "one research / one EA at a time" → **Controlled Parallelism** under isolation/compute/quota conditions; determinism-first (§26) retained; HR14 + Kimi 2026-09-15 annex left intact. | §24 |
| `02 Org/Company Structure.md` | CBE annex: **two permanently evolving books** (DXZ_BOOK/FTMO_BOOK, separate fitness), **Fable = orchestration intelligence** (owns prioritisation, may originate), **Kimi role** pointer. Existing Kimi (fourth-AI) annex left intact. | §5/§7/§25/§28/§37 |
| `02 Org/AI Agent Routing and Role Contracts.md` | CBE annex: **Kimi continuously available research lane** (§29); **Fable may originate strategies** with generalized internal-source authorship. Existing Kimi lane annex left intact. | §29/§37 |
| `04 Processes/Research Methodology.md` | Grundregel "one source at a time" → parallel external+internal programmes; new **Autonomous Edge Discovery annex** covering the full loop, ML offline/EA-forbidden, mechanization gate, cross-vendor attack, preregistration/data-snooping, failure mining, white-space, external-vs-internal ROI, experiment memory, FTMO-gap mission. Existing Internal-Edge-Discovery annex left intact. | §24/§37/§38–§54 |
| `04 Processes/Determinism Over LLM Calls.md` | §26 annex (never-waste-LLM list + new legit LLM uses: hypothesis generation, adversarial critic); HR16 references → Controlled Parallelism keeping determinism-first. | §24/§26/§37/§38 |
| `04 Processes/Operational Disciplines.md` | "max 1 EA in Development (HR16)" and "HR16 = primary token-saver" → Controlled Parallelism under quota governance. | §24 |
| `04 Processes/Lessons Learned Loop.md` | §67 annex: **lessons must become executable artifacts** (script/guard/preflight/feature/dataset field/research exclusion), with the directive's examples table. | §67 |
| `03 Pipeline/Q15 Final Portfolio Construction.md` | Book trigger `>=25` → **valid pool + OWNER order (no fixed minimum)** in code block, trigger line, prose, OWNER-trigger steps; **Diversification Rules (Hard) → default guardrails + portfolio-risk analysis** (measure real economic dependence); "violate hard caps" → guardrail-with-justification; FTMO 60/30 sprint note reframed. | §4/§3/§8/§15 |
| `03 Pipeline/Q16 Operational Readiness.md` | Check 4 + `burn_in_lot` schema: min-lot no longer a mandatory default → evidence-based initial live risk; Q11/Q13 refs → Q15/Q17. | §10 |
| `03 Pipeline/Q17 Live Burn-In DXZ.md` | Duration/min-lot/"14-day minimum"/burn-in-config/hard-rules table → **evidence-based live introduction / probation / deployment**; OWNER-only live activation preserved. | §10 |
| `03 Pipeline/Pipeline Overview.md` | Q15/Q17 gate rows, ASCII book-trigger, data-window Q17, book-trigger code block + note, Pipeline-Rules table (book trigger, no-demo-gate min-lot, **HR16 row → Controlled Parallelism**). | §4/§8/§10/§24 |
| `03 Pipeline/Pipeline Operations Workflow.md` | Book-trigger prose (`>=25` → valid pool), Q17 burn-in min-lot → evidence-based, "Buchbau unter 25" refusal row. | §4/§10 |
| `03 Pipeline/Gate Manifest v4 Diff.md` | Historical diff record kept; annotated with `>=25` supersession note (annotate, not delete). | §4 |
| `06 Infrastructure/Risk Conventions.md` | Live-burn-in phase table + "Übergang Backtest→Live" section: min-lot + fixed 14-day → **evidence-based Q17 live introduction**; OWNER-only live authority preserved. | §10 |
| `06 Infrastructure/AI Spend and Quota Governance.md` | New **Kimi lane quota section**: governor + flag, subscription reality, real telemetry (`GET /coding/v1/usages`), local caps as fallback guardrails, resource guard. | §29–§34 |
| `02 Org/Stehende Vollmacht Claude 2026-08-20.md` | CBE annex: **§64 authority split** (Fable autonomous reversible work incl. prepare-everything; OWNER retains paid FTMO purchase / additional accounts / live AutoTrading / irreversible actions / purchases). | §64 |
| `08 Current State/Current Operating State.md` | New **Delta 2026-09-15 — Continuous Book Evolution** (append-only): objective changed, Way-to-25 abolished, supersession list, newly-allowed items, Mission-Control rebuild + new pages. Dated historical deltas left intact. | §3/§60/§65 |
| `12 ToDo/AI ToDos/Claude.md` | Preserved-doctrine **Nordstern block**: Way-to-25 struck → Continuous Book Evolution + programme/decision pointers. (Auto-rendered top sections left to the generator — Phase D.) | §3/§4/§60 |
| `12 ToDo/10_Pipeline_Leerlauf.md` | Title + context: drain "Zwischenziel" superseded as a **book blocker** → backlog-hygiene work goal; "Weg zu 25" removed. | §3/§23 |
| `12 ToDo/07_FTMO_Kampagne.md` | Ziel + internal 60d/0.80 sprint contract → **probability-first, two-week Demo gate, one paid Challenge**; metrics reframed as evidence. | §12/§14/§15 |

## Pages CREATED (missing canonical pages found by the audit)

| New vault page | Content | § |
|---|---|---|
| `08 Current State/FTMO Campaign.md` | Canonical FTMO campaign reference: business objective/path, the 8 core policies (probability>speed, mandatory two-week Demo, one paid Challenge, 100k/2-Step default, aggressive Demo use, different strategies allowed, scalping allowed, trailing allowed), FTMO Challenge Readiness, current-rules verification, authority. | §11–§19/§62/§63/§64 |
| `06 Infrastructure/Mission Control.md` | Operating-surface documentation of the **new primary view** (Book Evolution / DXZ / FTMO / Research / Factory sections), weekly rhythm, generated-surface pointers; marked **implementation Phase D in progress 2026-09-15**. | §60 |
| `02 Org/Kimi Research Provider.md` | Summary of `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md`, `KIMI_EDGE_DISCOVERY_DESIGN.md`, `INTERNAL_RESEARCH_SOURCE_CONTRACT.md` (repo paths cited): role (§28), two planes, denied authority, edge-discovery loop, R1 internal source, quota governance (§30–§34). | §28/§29/§30–§34/§65 |

New wiki-links used (`[[FTMO Campaign]]`, `[[Mission Control]]`, `[[Kimi Research Provider]]`)
resolve by Obsidian basename; all three target pages now exist.

## Not touched (by instruction)

- `08 Current State/Heartbeat.md` — generated (`heartbeat_snapshot.py`), Phase D.
- `10 Morning Briefing/*` — generated (`morning_brief.py`) + dated history, Phase D.
- Auto-rendered top of `12 ToDo/AI ToDos/Claude.md` (rendered from `agent_tasks`) — only the
  hand-preserved doctrine Nordstern block was edited.

## Contracts changed

None in code/JSON/tests — this slice is documentation only (vault markdown). No repo files under
`framework/`, `tools/`, or `decisions/` were modified by this slice. The decision record
`decisions/2026-09-15_owner_continuous_book_evolution.md` (referenced by every annex) is authored by
another slice; all annexes point to that path.

## Tests

No automated tests apply to vault markdown. Verification performed:
`python "G:/My Drive/QuantMechanica - Company Reference/00 Governance/lint_company_reference.py"`
→ result `Company Reference lint: FAIL`, but **every failure is in a file this slice did not touch**
(`Codex.md`, `OWNER.md`, three dated `08 Current State/*` notes, four `12 ToDo/AI ToDos/Archive/*`
notes, and a `GER40.DWX` symbol mention in `OWNER.md`) — all pre-existing. The lint's `old gate
token` rule matches only P-series tokens (P0–P10), not the Q-mapping legends on the pipeline pages
edited here; the `legacy_roles` rule's only pages this slice touched (Lessons Learned Loop,
Determinism Over LLM Calls, Operational Disciplines) are already on the `LEGACY_ROLE_DEBT` allowlist,
and no new legacy-role terms were introduced. None of the 22 edited or 3 created pages appear in the
lint failure list.

## Rollback

All edits are in-place vault markdown, cloud-synced (Obsidian/Google Drive version history). To roll
back: restore each page from Drive version history to its pre-2026-09-15 revision, and delete the
three created pages (`08 Current State/FTMO Campaign.md`, `06 Infrastructure/Mission Control.md`,
`02 Org/Kimi Research Provider.md`). The supersession annexes are self-labelling
(`OWNER-DEC-CBE-20260915`) and greppable, so an alternative rollback is to remove the annex blocks
and un-strike the struck sentences. No env flag governs vault content.

## Items NOT done (with exact reason)

- **Generator-driven "Way to 25" surfaces** (`Heartbeat.md`, `10 Morning Briefing/*`, and the
  auto-rendered top of `Claude.md`): intentionally NOT hand-edited — these are overwritten by
  `heartbeat_snapshot.py` / `morning_brief.py` / the ToDo renderer, so the durable fix belongs in the
  generators (Phase D, a different slice). Only the hand-preserved Nordstern doctrine block in
  `Claude.md` was edited.
- **Pre-existing lint failures** in untouched files (old P-token pages, `GER40.DWX` symbol mention):
  out of this slice's scope (those pages are not in the b4 drift work list); left for the owning
  cleanup slice.
