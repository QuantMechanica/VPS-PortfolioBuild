# EP01 — The Reset: Why I'm Starting Over After 6 Months

**Status:** DRAFT — pending CEO + OWNER sign-off. Do NOT publish.
**Drafted by:** Documentation-KM (agent `8c85f83f-db7e-4414-8b85-aa558987a13e`)
**Drafted on:** 2026-04-27
**Source issue:** QUA-152
**Date range covered:** 2026-04-21 → 2026-04-26 (V4 archive + V5 restart)
**Target episode date:** per `docs/ops/EPISODE_GUIDE.md` § Foundation Arc — originally 2026-04-25, slipping; re-target on OWNER review.
**Length target:** 8–12 min per Episode Guide.

---

## 1. Episode summary

After six months of QuantMechanica V1–V4, I'm hitting reset. Not because the research was wrong — the V4 process produced a real strategy archive, real backtests, real lessons — but because the **operating layer** around it accumulated tech debt faster than it produced edge. V5 is the same project rebuilt on a fresh VPS with a smaller, sharper organisation: a clean repo, a documented 15-phase pipeline, a new EA framework with no V4 baggage, and a Paperclip company designed around what V1–V4 actually taught us.

This episode is the "why" — what V1–V4 got right, what went sideways, and the specific decisions that shaped the V5 rebuild over the last week.

## 2. What V1–V4 got right (kept verbatim into V5)

These survived the reset because the evidence was unambiguous (full list in `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md`):

- **Model 4 Every Real Tick baselines.** Model 1/2 produce artificially clean PFs.
- **Fixed Risk $1K for backtests, Percent Risk for live.** Same dual-mode convention, comparable across EAs.
- **Darwinex MT5 native data only.** No Alpha Vantage / Polygon / Yahoo. Broker-native data is what the EA actually sees live.
- **Magic-number formula `magic = ea_id * 10000 + symbol_slot`.** V4's collisions came from missing registry validation, not the formula.
- **Enhancement Doctrine: exits yes, entries no.** Once entries change, prior P2–P10 evidence is no longer valid.
- **Git as canonical source of truth.** Extended in V5 to nightly Notion → Git export.
- **No fantasy numbers.** Every claimed metric must cite a report or state file.
- **File-deletion requires approval.** Hard rule since the QUAA-255 mass-delete incident (2026-04-20) — see `lessons-learned/2026-04-20_mass_delete_incident.md`.

## 3. What V1–V4 got wrong (changed for V5)

- **Research breadth, not depth.** V1 ran parallel sources, 46 rounds, 81+ edges. Looked productive on paper, but it produced duplicate findings discovered only at build time and was hard to present on YouTube. V5 goes source-by-source, exhaustive extraction before next source.
- **No shared EA framework.** Codex's V4 inventory (2026-04-26) confirmed every V4 EA was self-contained — there was no `Company/Include`. That is the root cause of three V4 failure modes (magic collisions, unreviewable risk sizing, doc/code drift). V5 ships a shared framework on day one. Spec: `framework/V5_FRAMEWORK_DESIGN.md`. Rationale: `decisions/2026-04-26_v5_framework_design.md`.
- **Locked basket as starting state.** The Codex laptop reconstruction listed V4's locked basket (SM_124, SM_221, SM_345, SM_157, SM_640) as "must inherit". OWNER overruled on 2026-04-26: V5 is a clean restart, no SM_XXX sleeves, no V4 magic numbers, no V4 set files. The V4 archive remains as historical reference, never as a V5 input. Decision: `decisions/2026-04-26_v5_restart_clean_slate.md`.
- **CEO close protocol.** V1 closed work on the agent's claim. V5 requires real test output before close — claim → verify → archive.
- **Heartbeat noise.** V1 agents were chatty and overlapped. V5 keeps the same 13 roles but with revised, narrower prompts and ~60% lower heartbeat rates.

## 4. Key decisions in this window (the audit trail behind the reset)

All of these are committed under `decisions/`:

1. **15-phase pipeline is canonical** (`2026-04-25_pipeline_15_phase_override.md`). The Notion 10-phase outline collapsed the V2.1 robustness gates and mislabelled P8 as a 30-day demo. The laptop's 15-phase spine (G0..P10) is the real intended pipeline. Notion page is superseded; canonical spec lives in `docs/ops/PIPELINE_PHASE_SPEC.md`.
2. **News-compliance variants flagged TBD** (`2026-04-25_news_compliance_variants_TBD.md`). FTMO / The5ers / no-news / news-only are not in the canonical P8 spec. Tracked separately, later folded into the framework's `QM_NewsFilter.mqh` mode enum.
3. **Paperclip reality check + 7-phase project map** (`2026-04-26_paperclip_reality_and_phase_map.md`). Honest labelling: Paperclip is not installed yet. Workstream items assigned to "CTO" or "Pipeline-Operator" are blocked on Phase 1. New `PROJECT_BACKLOG.md` at repo root with a "today's actual owner" column.
4. **V5 starts from scratch on bestand and framework** (`2026-04-26_v5_restart_clean_slate.md`). No V4 SM_XXX sleeves, no V4 EA framework code. Process shape and learnings are kept; specific strategies are not.
5. **V5 EA framework design accepted** (`2026-04-26_v5_framework_design.md`). 8 modules under `framework/include/`, magic registry with hash baked at compile, set-file format with mandatory header + schema validator, JSON-line structured logger, news filter as first-class include with mode enum, kill-switch with three independent paths, DST-aware time helper, TradeContext error taxonomy.
6. **DXZ live-only, P10 = 2-week shadow deploy** (`2026-04-26_dxz_live_only_and_p10_live_burn_in.md`). Confirms the demo-as-permanent-state was a Notion artefact, not the real model.
7. **TDS renewal skipped pending evidence** (`2026-04-26_tds_renewal_skip.md`). Tick Data Suite license expires ~2026-05-05; renewal decision deferred until V5 first ticks land.

## 5. Learnings cited

Per `paperclip-prompts/documentation-km.md` § Maintain the Learnings Archive — every entry follows the **Learning → V1 Behavior → V5 Behavior → Why** format.

- **L-K-01..L-K-10** (V5 inherits unchanged) — full list in `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md`.
- **L-C-01** Research breadth → depth.
- **L-C-02** Lean prompts, narrower heartbeats.
- **L-C-03** CEO close: single-step → 2-phase claim/verify/archive.
- **2026-04-20 mass-delete incident** — ground truth for the file-deletion-requires-approval hard rule. Cited in CLAUDE.md.
- **2026-04-26 Paperclip Wave-0 bootstrap lessons** (`lessons-learned/2026-04-26_paperclip_wave0_bootstrap.md`):
  - Embedded Postgres 18-beta failed → pin Postgres 17 (no-beta-runtime rule).
  - Paperclip auto-onboarding wizard creates tutorial agents → repurpose, don't delete (DL-010).
  - Two-layer hire pattern locked (DL-014): Paperclip-managed system prompt + V5 first-issue brief from `paperclip-prompts/<role>.md`.

## 6. Commits referenced

Story-relevant commits in this window (full log: `git log --since=2026-04-21 --until=2026-04-26 --oneline`, ~30 commits in the V5-reset narrative; the QUA-95 ops-suite cluster on 2026-04-27 is post-EP01 and stays out of the episode):

| Hash | Date | Subject |
|------|------|---------|
| `4b79815` | 2026-04-21 | Initial commit |
| `51ac91e` | 2026-04-24 | chore: bootstrap V5 repo structure and migrate ops docs from drive |
| `0a5d458` | 2026-04-25 | docs: migrate canonical pipeline spec and process registry from laptop |
| `face68a` | 2026-04-26 | docs: self-review corrections — lane drift, news compliance, scope fix |
| `3813533` | 2026-04-26 | docs: V5 starts clean — overrule "must inherit" framing for V4 bestand |
| `8c0dec0` | 2026-04-26 | docs: strategy-seeds README — V5 clean-slate folder shape |
| `ef8bfbe` | 2026-04-26 | docs: V5 EA framework design + fold Codex pack findings |
| `1c492c7` | 2026-04-26 | docs: V5 sub-gate spec reconstructed + framework defaults locked |
| `5374d51` | 2026-04-26 | docs: V5 brand guide + framework trade-mgmt modules + per-EA chart UI |
| `f3e5a0c` | 2026-04-26 | docs: project backlog + Paperclip reality check + spec-density principle |
| `16a4b5e` | 2026-04-26 | docs: V4 = V5 basis correction + framework patterns + open items + self-review |
| `3898d1a` | 2026-04-26 | docs: Sweep 1 — 13 Paperclip prompts + 4 critical Notion docs + Strategy Card Template |
| `621fc3e` | 2026-04-26 | docs: Sweep 2 — Wave-0/1 reference material + brand assets |
| `1d86749` | 2026-04-26 | docs: Sweep 3 — V4 reference material + voice samples + open-items audit |
| `f987053` | 2026-04-26 | docs: OWNER decision sweep — News Compliance ACCEPTED, DXZ live-only, P10 Live Burn-In |

## 7. Notion → Git sync window

Per BASIS workflow step 2 ("Read Notion updates from that period"), the Notion content that backs this episode was migrated into Git in the same window:

- Pipeline V2.1 spec (laptop) → `docs/ops/PIPELINE_PHASE_SPEC.md` (commit `0a5d458`).
- V4 Learnings Archive Notion page → `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` (commit `16a4b5e`, 2026-04-26).
- 13 Paperclip role prompts + 4 critical Notion docs + Strategy Card Template → `paperclip-prompts/` and `docs/ops/` (commit `3898d1a`).
- Episode Guide (Notion id `34947da5-8f4a-8168-8ca7-ff3e1097b8d4`) → `docs/ops/EPISODE_GUIDE.md` (commit `0a5d458`).

No live Notion mutation has occurred during this draft — Documentation-KM does not auto-publish.

## 8. Footage / screen-grab list (per Episode Guide)

- Old local setup (V4 chaos) — pre-existing screenshot, OWNER to provide path.
- New VPS terminal blank-slate — fresh RDP into Hetzner AX42 (B-roll already available from Phase 0 setup).
- `docs/ops/PIPELINE_PHASE_SPEC.md` G0..P10 phase list on screen.
- `framework/V5_FRAMEWORK_DESIGN.md` § module list on screen.
- `PROJECT_BACKLOG.md` opened, "today's actual owner" column highlighted.
- Brief flash of the V4 lessons-learned archive (2026-04-21) — to anchor the "we kept the lessons, not the strategies" beat.

## 9. CTAs

Per `docs/ops/EPISODE_GUIDE.md` § Production Discipline, every video, description, episode page and newsletter ends with a small **Buy-me-a-coffee** support CTA.

**Hard rule (BASIS § Maintain episode artifact packs):** Buy-me-a-coffee CTA copy is **support**, not investment. It must be visually and verbally separated from any portfolio/performance discussion.

Draft copy (separate from any portfolio/performance discussion in the episode):

> **Support the rebuild.** If you want to follow QuantMechanica V5 episode-by-episode and back the work, buy me a coffee at [buymeacoffee link — OWNER to confirm URL]. This is project support, not an investment offer. No performance promise. No fund. Just coffee for the keyboard.

Investment / portfolio claims appear nowhere in this episode — V5 is at Phase 0, no V5 EAs are live, no V5 backtest evidence exists yet.

## 10. Open items / OWNER decisions before publish

- [ ] Confirm episode title — current: "The Reset: Why I'm Starting Over After 6 Months" (per Episode Guide).
- [ ] **Confirm new episode date target** (CEO flag, QUA-152 sign-off comment). Episode Guide originally targeted 2026-04-25; that date has slipped. OWNER picks the new publish target.
- [ ] Confirm date range cutoff. Default per QUA-152: 2026-04-21 → 2026-04-26 (V4 archive + V5 restart). The 2026-04-27 QUA-95 ops-suite cluster is intentionally excluded — it is operational hardening, not story.
- [ ] **Length pass** (CEO flag, QUA-152 sign-off comment). Current draft is detailed and dense; for the 8–12 min target, sections 4–6 likely need to be cut to bullets. Defer to OWNER's narration preference; Documentation-KM does the cut once direction is given.
- [ ] Confirm Buy-me-a-coffee URL (OWNER to provide; not committed to repo).
- [ ] Approve final commit hash list above (CEO sanity-check on claims and numbers per Episode Guide § Production Discipline).
- [ ] Newsletter issue (`newsletter.md`) and thumbnail (`thumbnail.png`) are separate artifacts; not in scope for this draft.

## 11. Approvals

- [x] CEO sign-off — agent `7795b4b0-8ecd-46da-ab22-06def7c8fa2d`, QUA-152 comment `1edae9f2-cab8-495f-b755-a5294b1937c9` (2026-04-27). Approved for the **draft submission deliverable**; publish gated on OWNER.
- [ ] OWNER sign-off — voice, scope, publish go/no-go.

No publish without both. Per BASIS: "No publishing without OWNER sign-off."

## 12. Publish workflow (out of scope here)

Per CEO direction (QUA-152 comment `1edae9f2`): when OWNER signs off, the publish step is tracked in a **separate child issue** under QUA-144 (Episode Publish parent) — not on QUA-152. QUA-152's deliverable is the draft itself.
