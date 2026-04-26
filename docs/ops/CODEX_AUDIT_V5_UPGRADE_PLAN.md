# Codex Audit — V5 Upgrade Plan

> **V5 Source:** Notion `Codex Audit - V5 Upgrade Plan` (id `34947da5-8f4a-8101-b7db-c3b827733bb1`)
> **Migrated to repo:** 2026-04-26
> **Original date:** 2026-04-21

**Scope:** full Notion hub, 10 top-level subpages, 13 agent prompt pages, and local Markdown corpus under `Company/`, `doc/`, `CLAUDE.md`, `RECOVERY.md`.

## Executive Read

The hub is a strong V5 narrative plan, but it needs one architectural correction: V5 is a restart, not a continuation. Existing strategies may be reused only as seed candidates after they are re-sourced, re-tested, and re-gated.

## Key Corrections

- **Fresh company:** do not import old QUAA issues, heartbeats, old `TODO.md`, or old `HANDOFF.md` as active state.
- **Strategy reuse:** old strategies become `strategy-seeds`, not live candidates.
- **Infrastructure:** update from 5 MT5 to **6 MT5**: T1-T5 for factory/research, T6 for Demo/Live.
- **LiveOps:** update from separate Hyonix-first assumption to same-VPS T6 isolation.
- **OWNER role:** OWNER approves deploy manifests; LiveOps executes chart placement and verification.
- **Prompt source:** Notion prompt pages are good drafts, but Git should become canonical after the fresh public repo exists.

## Main Findings

1. The phrase "clean-slate rebuild" is correct, but the plan still contains continuation assumptions.
2. Local Markdown is useful as a learning archive, not as V5 operating truth.
3. Local git state is not trustworthy as canonical V5 state because `git status` fails with `fatal: bad object HEAD`.
4. The old Google Drive/git incident must become a V5 infrastructure constraint: no shared synced `.git/` working directory for concurrent agents.
5. The 6th MT5 terminal changes monitoring, deploy, LiveOps, and risk controls.
6. Manual MT5 chart placement should be removed from OWNER's normal workflow.

## Migration Rule

Every carried-forward strategy must pass:

- Source identity recovered or explicitly marked as legacy-derived
- EA compiles cleanly under V5 template rules
- Model 4 fixed-risk baseline re-run
- Magic number re-assigned in V5 registry
- P7 gate re-earned before Demo/Live

## Notion Contradictions To Fix (status as of 2026-04-21)

- Infrastructure page still says 5 MT5. *(resolved in revised V5 docs)*
- LiveOps prompt assumes separate Hyonix VPS. *(resolved 2026-04-21)*
- Expense log lists Hyonix Live VPS as default future cost; it should become optional fallback. *(resolved)*
- Current phase says first 3 agents only; add Documentation-KM early because public artifacts are part of the build. *(resolved)*
- Agent prompts need a single canonical export path into Git. *(resolved 2026-04-26 — `paperclip-prompts/` now canonical)*

## Codex Phase-Gate Checklist

- [ ] Notion and repo docs agree.
- [ ] Public claims have evidence.
- [ ] T6 Live terminal is isolated from T1-T5 factory load.
- [ ] Strategy seeds were not silently promoted without V5 re-tests.
- [ ] Expense log matches actual purchases.
- [ ] Every episode has an artifact folder.

## Immediate Next Actions (status update 2026-04-26)

1. Update hub language to V5 restart plus strategy-seed migration. ✅ done
2. Create fresh public repo skeleton. ✅ done (`QuantMechanica/VPS-PortfolioBuild`)
3. Export 13 prompts into `paperclip-prompts/`. ✅ done 2026-04-26
4. Create T6 deploy manifest schema before any chart automation. 🟡 schema in `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md`; first dry-run pending
5. Start Phase 0 with CEO, CTO, Research, Documentation-KM. ⬜ blocked on Paperclip install (Phase 1)
6. Treat old QUAA docs as archive/learnings only. ✅ done — V4 framework patterns and learnings ARE inherited (per `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md`); V4 strategy bestand is NOT inherited.

## Subsequent Codex Findings (2026-04-26 sessions)

- `CODEX_PIPELINE_V2.1_SPEC/IMPACT/DIFF.md` files do **not exist** anywhere on Drive (confirmed by Codex 2nd-pass full-text search). V5 sub-gate spec authored fresh per `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md`.
- `run_news_impact_tests.py` does **not exist**. V4 P8 was hand-orchestrated. V5 builds news-impact tooling natively as part of `framework/V5_FRAMEWORK_DESIGN.md` § QM_NewsFilter.
- V4 had no shared `Company/Include` library. V5 closes this with the framework's 8+ shared `.mqh` includes.

See `decisions/` for the ADR trail of all corrections since this audit.
