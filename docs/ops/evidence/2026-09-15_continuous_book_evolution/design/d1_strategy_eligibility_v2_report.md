# Slice report — d1_strategy_eligibility_v2

**Slice key:** `d1_strategy_eligibility_v2`
**Author:** Claude (board-advisor worktree) · **Date:** 2026-09-15
**Authority:** OWNER-DEC-D3-20260915 (directive 3 §14–§22, §37, §43D, §44);
verbatim `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`.
**Base:** worktree HEAD == `agents/board-advisor` head `1617cb22be` (clean at start; reset confirmed).

**Inputs read (read-only):** directive §14–§22/§37/§43D/§44; audit exec summary
`docs/ops/QUANTMECHANICA_COMPLETENESS_AND_GAP_AUDIT_2026-09-15.md`; `processes/qb_reputable_source_criteria.md`;
`tools/strategy_farm/card_intake_prescreen.py`; `tools/strategy_farm/strategy_card_v3.py` +
`schemas/strategy_card_v3.schema.json`; `framework/V5_FRAMEWORK_DESIGN.md` risk principles;
`docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md` (F8/F10); vault `01 Identity/Hard Rules.md`;
`docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`; portfolio risk layer
(`tools/strategy_farm/portfolio/{risk_diagnostics,concentration_tail}.py`,
`config/concentration_tail_limits.v1.json`).

## What changed

### New files
- `tools/strategy_farm/config/strategy_risk_contract.v1.json` — JSON Schema (draft 2020-12) for
  the §18 deterministic risk contract (`schema: qm.strategy-risk-contract/v1`). Standalone new
  file — no schema-hash binding to any existing sealed card.
- `tools/strategy_farm/strategy_risk_contract.py` — stdlib-only shared validator: controlled
  `MECHANISM_FLAGS` vocabulary, `TAIL_AMPLIFYING_FLAGS`, `detect_flags_in_text` (affirmative,
  non-negated, direction-aware pyramiding), `normalize_flags`, `validate_contract`, `is_unbounded`.
- `tools/strategy_farm/tests/test_strategy_risk_contract.py` — 14 unit tests (vocab, distinct
  pyramiding, detection/negation, bounded vs unbounded, basket-loss substitutes for equity stop).
- `docs/research/STRATEGY_ELIGIBILITY_V2.md` — the style-agnostic doctrine: §14 questions, §17
  allowed families, §15 ML boundary, §16 internal-source policy, §18 tail-risk contract as a
  formal schema, §20 portfolio-layer requirements (exists/missing table), §21 positive vs
  negative pyramiding, §22 pattern-filter overlay policy, and a SUPERSEDED table citing every
  place the old style prohibitions lived.
- `docs/research/PORTFOLIO_TAIL_RISK_RESEARCH.md` — §19 research design (10 metrics, datasets
  available today from Q08/Q14 streams + demo journal, the "diversification proven" acceptance
  rule, the wave-2 engine deliverable contract) and the §20 capability map (exists vs missing).

### Edited files (repo)
- `tools/strategy_farm/card_intake_prescreen.py` — **removed** style-based rejections
  (`PROHIBITED_MECHANICS:HFT|GRID|MARTINGALE|AVERAGING_INTO_LOSERS`); **kept** the runtime-ML
  rejection (`PROHIBITED_MECHANICS:ML`, `_ml_runtime_reason`, provenance-scoped) and all
  integrity/dup/symbol/feed/section/DD/timeframe/internal-source checks; **added** fail-closed
  `RISK_CONTRACT_MISSING` (tail-amplifying flag without a valid contract) and `UNBOUNDED_RECOVERY`
  (contract declares infinite levels or no equity stop) via `_declared_mechanism_flags` +
  `_risk_contract_reasons`, sourcing flags from frontmatter `mechanism_flags` ∪ affirmative prose.
  Only new intake is affected; `_annotate_and_reject` / history path unchanged.
- `tools/strategy_farm/strategy_card_v3.py` — additive **optional** top-level fields
  `mechanism_flags` + `risk_contract` (`_OPTIONAL_TOP_LEVEL_KEYS`, `_keys_with_optionals`,
  `_validate_optional_eligibility_fields`), wired into `validate_card` and `build_card`
  (canonical flag ordering). Cross-field rule: a tail-amplifying flag requires a present, bounded
  contract. Backward compatible: cards without the fields validate and hash identically.
- `tools/strategy_farm/tests/test_card_intake_prescreen.py` — dropped the obsolete HFT-reject
  fixture; added 7 V2 tests (scalping KEEP; martingale w/ valid contract KEEP; martingale w/o
  contract → `RISK_CONTRACT_MISSING`; `max_levels:0` → `UNBOUNDED_RECOVERY`; no-equity-stop →
  `UNBOUNDED_RECOVERY`; runtime-ML still REJECT; positive vs negative pyramiding distinct).
- `tools/strategy_farm/tests/test_strategy_card_v3.py` — 6 tests for the additive fields
  (absent = unchanged; benign flags need no contract + canonical order; tail flag + bounded
  contract seals; tail flag w/o contract rejected; unbounded contract rejected; unknown token
  rejected).
- `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md` — SUPERSEDED banner on the "no prohibited techniques"
  line (historical text retained).
- `processes/qb_reputable_source_criteria.md` — append-only "Annex 2026-09-15 (D3)": R4 style
  ban superseded; runtime-ML unchanged; bounded-risk contract requirement generalizing DL-081.

### Edited files (vault, G:)
- `01 Identity/Strategy Eligibility & Tail-Risk Doctrine.md` — new canonical hand-written page.
- `01 Identity/Hard Rules.md` — append-only annex "Strategie-Stilverbote abgelöst, beschränktes
  Risiko gefordert (OWNER 2026-09-15, D3)"; HR14 ML boundary explicitly unchanged.

## Contracts
- **New:** `qm.strategy-risk-contract/v1` (`tools/strategy_farm/config/strategy_risk_contract.v1.json`)
  — required only when a card declares a tail-amplifying mechanism; optional otherwise.
- **Additive to** `qm.strategy-card/v3` (Python validator layer only): optional `mechanism_flags`
  + `risk_contract`. The bound JSON schema file was intentionally **not** edited (see NOT-done).
- **New intake reasons:** `RISK_CONTRACT_MISSING`, `UNBOUNDED_RECOVERY` (fail-closed).
- **Removed intake reasons:** `PROHIBITED_MECHANICS:{HFT,GRID,MARTINGALE,AVERAGING_INTO_LOSERS}`.
  `PROHIBITED_MECHANICS:ML` retained.

## Tests
Command (from worktree root):
`python -X utf8 -m pytest tools/strategy_farm/tests/test_strategy_risk_contract.py tools/strategy_farm/tests/test_card_intake_prescreen.py tools/strategy_farm/tests/test_strategy_card_v3.py -q`
→ **59 passed**.
Regression sweep:
`python -X utf8 -m pytest tools/strategy_farm/tests/test_card_r1_internal_source.py tools/strategy_farm/tests/test_dl089_prescreen.py tools/strategy_farm/tests/test_dl089_prescreen_retro.py tools/strategy_farm/tests/test_dl089_derived_prescreen_lanes.py tools/strategy_farm/tests/test_governed_magic_allocator.py -q`
→ **50 passed**;
`... test_terminal_worker_prescreen_verdict.py test_p2_prescreen_policy.py -q` → **9 passed, 10 subtests**.

## Runtime / vault artifacts (with counts)
- Vault: 1 new canonical page + 1 append-only Hard Rules annex (`G:/…/01 Identity/`).
- No read-model generated (this slice ships doctrine + config + code + tests; no generator).
- No farm-DB writes, no terminal64 starts, no scheduled-task registration.

## Rollback
- Code: `git checkout agents/board-advisor -- tools/strategy_farm/card_intake_prescreen.py
  tools/strategy_farm/strategy_card_v3.py` and delete
  `tools/strategy_farm/strategy_risk_contract.py`,
  `tools/strategy_farm/config/strategy_risk_contract.v1.json`, the two new test files, and the
  two new `docs/research/*.md`; revert the qb-criteria annex and EDGE_LAB banner.
- Vault: delete the new page and the Hard Rules D3 annex block.
- All changes are additive/append-only; no verdict, evidence, or sealed artifact is touched, so
  rollback restores the prior style-based intake behaviour exactly.

## NOT done (with reasons)
- **`strategy_card_v3.schema.json` (portable JSON schema) not edited.** Its content hash is bound
  into every existing sealed card via `contract_bindings.strategy_card_schema_sha256`; editing it
  would invalidate all previously sealed cards (a historical-integrity / sealed-artifact RED
  boundary). The additive `mechanism_flags`/`risk_contract` fields are therefore enforced by the
  authoritative Python validator (`strategy_card_v3.py`), which is what the pipeline uses. Residual
  gap: an external `additionalProperties:false` jsonschema pass would reject a card carrying the
  new fields. Fix belongs to a future card-schema version bump (out of this slice's blast radius).
- **`governed_magic_allocator.py:374` `prohibited_technique:grid` build-preflight not changed.**
  Out of slice scope (build-time magic allocation, not intake). Should be revisited when the
  risk-contract-aware build path is wired so a grid EA with a valid contract can allocate magics.
- **`agent_router.py:2351` research-brief text "no ML/grid/martingale" not changed.** It is a
  discouraging research *prompt*, not a rejection; low risk, cross-slice (routing) surface.
- **Wave-2 tail-risk engine not built.** Only its design/contract is specified
  (`PORTFOLIO_TAIL_RISK_RESEARCH.md`); §19 diversification stays `EVIDENCE_MISSING` until built.
- **Second-chance rescan (§23/§43E) not run here** — that is the sibling second-chance slice;
  this slice only makes the doctrine that rescan will apply.

## Style prohibitions still carried by docs/code I did NOT change (per §37 instruction)
1. `tools/strategy_farm/governed_magic_allocator.py:374` — `prohibited_technique:grid` (build guard).
2. `tools/strategy_farm/agent_router.py:2351` — "no ML/grid/martingale" research-brief text.
3. Numerous immutable evidence files under `docs/ops/evidence/**` (e.g. grid build-preflight
   blocks, historical greviews) — historical audit record, must not be edited.
4. `framework/V5_FRAMEWORK_DESIGN.md` — carries mechanic names but is already permissive
   (gridding/scalping/pyramiding allowed with constraints); no style prohibition to remove.

## Exact commands for the orchestrator
1. Review the patch `<scratchpad>/patches_d3/d1_strategy_eligibility_v2.patch` and commit with
   explicit pathspecs (repo files only; vault is outside git):
   `git add tools/strategy_farm/config/strategy_risk_contract.v1.json tools/strategy_farm/strategy_risk_contract.py tools/strategy_farm/card_intake_prescreen.py tools/strategy_farm/strategy_card_v3.py tools/strategy_farm/tests/test_strategy_risk_contract.py tools/strategy_farm/tests/test_card_intake_prescreen.py tools/strategy_farm/tests/test_strategy_card_v3.py docs/research/STRATEGY_ELIGIBILITY_V2.md docs/research/PORTFOLIO_TAIL_RISK_RESEARCH.md docs/ops/EDGE_LAB_CHARTER_2026-05-22.md processes/qb_reputable_source_criteria.md docs/ops/evidence/2026-09-15_continuous_book_evolution/design/d1_strategy_eligibility_v2_report.md`
2. Verify tests post-merge: `python -X utf8 -m pytest tools/strategy_farm/tests/test_strategy_risk_contract.py tools/strategy_farm/tests/test_card_intake_prescreen.py tools/strategy_farm/tests/test_strategy_card_v3.py -q`.
3. Mint the directive-3 decision record `decisions/2026-09-15_owner_max_factory_utilization_eligibility_v2.md` (`OWNER-DEC-D3-20260915`) if not already created by slice a1, and reconcile the `OWNER-DEC-D3-20260915` id used across these docs.
4. No scheduled-task registration and no worker reload are required for this slice.
