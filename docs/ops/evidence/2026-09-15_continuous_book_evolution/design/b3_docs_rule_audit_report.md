# Slice report — b3_docs_rule_audit

**Slice key:** `b3_docs_rule_audit`
**Author:** Claude (board-advisor worktree) · **Date:** 2026-09-15
**Authority:** OWNER-DEC-CBE-20260915 (directive §20–§23, §69);
`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md`.
**Inputs read (read-only):** directive §20–§23/§69; audits `rule_inventory_code.md`,
`vault_doc_drift.md`, `pipeline_factory_state.md`, `quota_tasks_routing_resources.md`,
`research_disk_guard.md`, `ftmo_demo_state.md` under
`docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/`.

## Files changed

New files:
- `docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md` — one section per §21 rule (13 rules,
  F1–F13, with sub-parts 13a–13d): original purpose + cited decision, §20 class A/B/C/D,
  current benefit, current cost (with audit numbers), safety impact, recommendation, rollback,
  and DISPOSITION (SUPERSEDED-implemented slice / SUPERSEDED-pending phase / KEPT-intentional /
  OWNER question). Includes the mandated RAM-class live cost (6/10 terminals idle ~2.95 h for the
  un-winnable flat 44 GB `heavy_or_unknown_multisymbol` reservation, census 0/h vs 732 claimable
  rows) in §13b. Cites the correct guard path `tools/strategy_farm/research/research_env.py`.
- `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` — canonical operating-model doc: two living books;
  venue fitness layers (§57); weekly rhythm (§61); weekly outcomes (§6); materiality/anti-churn
  (§59, computable spec referenced as Phase E PENDING); Q17 evidence-based introduction/probation
  with the §10 decision-inputs list; live/money authority (§64); the Sunday 2026-09-20 ceremony
  under this model; and the weekly recomposition contract skeleton (inputs frozen at Friday cut;
  outputs; artifacts at `D:/QM/reports/book_evolution/<ISO-week>/`; reserved Phase-H scheduled
  task names).

Edited files:
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` — rewrote the P10/Q17 section header + purpose into
  evidence-based live introduction/probation, wrapped the original mandatory-min-lot/14-day
  content in a `<details>` SUPERSEDED block (retained verbatim), added a CBE note preserving the
  DXZ-live-only + KS-kill-switch controls, and marked the two downstream table/impact references
  (V5-vs-V2.1 table row; impact item 13) as SUPERSEDED.
- `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` — rewrote the step-13 Q17 row (~line 162) to
  evidence-based probation and added a SUPERSEDED note block quoting the old "14-day min, min-lot"
  text.
- `docs/ops/OPERATING_RULES_2026-07-03.md` — added "Amendment 2026-09-15 (OWNER-DEC-CBE-20260915)":
  drain-first doctrine superseded (§23), HR16 one-at-a-time superseded as absolute + controlled
  parallelism conditions (§24), determinism-first spirit retained (§25/§26), and an explicit
  "what is not changed" clause.
- `docs/ops/COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md` — added "Annex 2026-09-15": Q00–Q13 → Q00–Q17
  correction, 25-candidate trigger superseded (§4), global drain doctrine superseded (§23),
  tester-cache purge low-water drift corrected to 60 GB with the layering invariant, and the Q17
  evidence-based note. (The worktree base of this file is the old 76-line version predating the
  newer "line 135" copy; the annex is line-drift-robust because it is appended at the end and
  states the superseded content explicitly rather than by line number.)
- `CLAUDE.md` — added a dated `OWNER-DEC-CBE-20260915` bullet under "## Ratified Rules (recent)"
  covering: WAY-TO-25 abolished, book trigger = any valid pool, two living books + weekly
  recomposition, Q17 evidence-based, caps advisory, controlled parallelism, FTMO two-week demo /
  one paid challenge / 100k 2-Step / probability over speed / scalping + trailing allowed, ML
  offline-research-only (HR14 unchanged), Fable may originate strategies. Rest of CLAUDE.md
  untouched.

## Contracts changed

**None.** This slice is documentation-only. No gate threshold, verdict semantic, qualification
predicate, JSON config, or Python function was modified. All code/contract conversions named in
the RULE_EFFECTIVENESS_AUDIT (book_build_guard, gate_manifest.v4.json book_trigger,
ftmo_probability_contract.v1.json caps, correlation gates, research_env.py, kimi_governor.py) are
attributed to their owning slices/phases (b1, b2, Phase C, Phase E) and are NOT touched here.

## Tests added + result

**No contract changed → no §70 contract regression test applies to this slice.** §70 requires
regression tests for changed *contracts* (code/JSON); this slice changes only Markdown docs.
Verification performed instead:
- Grep confirmed no `pytest` test file depends on the touched docs (the only match,
  `framework/scripts/README.md`, is a README, not a test).
- Grep confirmed every `research_env.py` citation in the new docs uses the full path
  `tools/strategy_farm/research/research_env.py` (the one bare-string hit is the prose sentence
  "…not a bare `research_env.py`", intentional).
- No affected test files exist to run; existing tests are unaffected (no code touched).

pytest summary line: `n/a — documentation-only slice, no test files affected`.

## Rollback

Every change is additive documentation or a marked SUPERSEDED block:
- Revert the two new files by deleting `docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md` and
  `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md`.
- Revert the edited files with `git revert`/`git checkout` of this slice's patch; each edit
  retains the original text (SUPERSEDED blocks / annexes are append-only), so reverting restores
  the prior wording exactly.
- No env flag is involved (no runtime behaviour changed). The behavioural rollbacks for the
  *rules* discussed are documented per-rule in `RULE_EFFECTIVENESS_AUDIT_2026-09.md` and belong to
  the implementing slices.

## Items I could NOT do (with exact reason)

1. **COMPANY_AUDIT / CLAUDE.md line-anchored edits (~line 135, and the newer CLAUDE.md body).**
   The worktree base predates the CBE Phase A commits: `docs/ops/COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md`
   is the old 76-line version (says "Q00 through Q13", has no line 135), and the worktree
   `CLAUDE.md` is the pre-Kimi version (still says "no ML libraries", "no-op ≥150GB / LowWater
   80→150", references the retired `QM_StrategyFarm_TerminalWorkers_AT_STARTUP`). I therefore
   appended a dated, self-describing annex (COMPANY_AUDIT) and a dated Ratified-Rules bullet
   (CLAUDE.md) instead of editing at the exact line numbers named in the task. This is
   line-drift-robust and states the superseded content explicitly, but the orchestrator should be
   aware that when this patch is applied onto the newer `main` copies, the stale in-body prose
   (CLAUDE.md disk-purge "LowWater 80→150"; COMPANY_AUDIT line ~135 "25-trigger + drain") may need
   a small in-body SUPERSEDED marker in addition to my annex — my annex already states the correct
   values (LowWater 60, no fixed 25, drain superseded) so the correction is present regardless.
2. **Nothing else was blocked.** The directive's decisions are treated as final; no
   "pending OWNER approval" caveats were added for directive-decided items; no RED-boundary action
   (gate thresholds, verdicts, T_Live/AutoTrading, DB writes, commits) was taken.
