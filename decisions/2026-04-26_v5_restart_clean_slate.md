# Decision: V5 starts from scratch on strategy bestand and EA framework

- Date: 2026-04-26
- Status: accepted
- Owner: OWNER (board)
- Affected docs: `docs/ops/V5_RESTART_SCOPE_BOUNDARY.md`, `strategy-seeds/v5_locked_basket_2026-04-18.md`, `strategy-seeds/specs/README.md`, `strategy-seeds/README.md`, `docs/ops/PHASE0_EXECUTION_BOARD.md`

## Context

The Codex laptop reconstruction (`CANONICAL_LAPTOP_STATE_2026-04-25.md`) listed the V4 locked basket (SM_124, SM_221, SM_345, SM_157, SM_640) and the V4 strategy specs as items that "the VPS build must inherit from the laptop". That phrasing was carried into the migration commit `0a5d458` — `strategy-seeds/v5_locked_basket_2026-04-18.md` documented the V4 sleeves as a current V5 composition with open waivers.

OWNER overruled this on 2026-04-26: V5 is a clean restart. The new operating loop is

```
V5 Research → V5 Strategy Card → V5 EA (new framework) → V5 Backtest → V5 Pipeline (G0..P10) → V5 Live
```

None of the V4 SM_XXX sleeves enter that loop unless they are independently re-derived from new research and pass every V5 gate.

## Decision

1. V5 does **not** inherit any V4 strategy bestand — no SM_XXX sleeves, no magic numbers, no set files, no V4 lock-basket weights, no V4 deploy folder layout.
2. V5 does **not** inherit the V4 EA framework code — V5 builds a new EA framework (Include lib, magic schema, set-file convention, risk inputs, EA template, compile harness). Tracked as `P0-26` on the Phase 0 board.
3. V5 **does** inherit the *process shape*: the 15-phase pipeline (`PIPELINE_PHASE_SPEC.md`), the hard rules from CLAUDE.md, the V5 / V2.1 evidence discipline, and the learnings encoded by V4 incidents (lane drift caution, waiver-creep caution, setup-vs-strategy classification).
4. The migration commit `0a5d458` is **not reverted**; the V4 artifacts are kept in the repo as legacy/historical reference, but every file that documented them is rewritten with a clear "legacy / not a V5 input" header.
5. The 5 markdown strategy specs under `strategy-seeds/specs/` remain in the repo as research material only — they are not approved V5 Strategy Cards and cannot bypass V5 G0 Research Intake.

## Alternatives Considered

- **Inherit the V4 lineup, re-validate it.** Rejected. CLAUDE.md says explicitly "Do NOT trust old QUAA runtime state" and "No promotion of V1-V4 results into V5 PASS without re-test". Carrying the lineup as the V5 starting basket creates exactly the trap the rule is meant to prevent — the basket would gather narrative weight long before fresh evidence existed.
- **Delete the migrated V4 artifacts entirely.** Rejected. The artifacts are valuable as historical evidence (they justify why V5's pipeline is stricter than V4's was). Removing them would lose that audit trail. The fix is labelling, not deletion.
- **Inherit pipeline thresholds verbatim from V2.1 (PF>1.30, T>200, etc.).** Provisionally accepted. V5 starts with V2.1 thresholds as defaults but may revisit once the new framework's first EAs produce real distributions. Tracked in `project_qm_pipeline_v5.md` memory.

## Consequences

- `strategy-seeds/v5_locked_basket_2026-04-18.md` rewritten as a labelled V4 legacy snapshot.
- `strategy-seeds/specs/README.md` added with a legacy / research-material-only banner.
- `strategy-seeds/README.md` added documenting the V5 clean-slate folder shape (cards/, sources/, specs/ legacy).
- `docs/ops/V5_RESTART_SCOPE_BOUNDARY.md` added — single source of truth for what V5 inherits vs what it does not.
- `docs/ops/PHASE0_EXECUTION_BOARD.md` extended with `P0-26 Establish V5 EA framework` (CTO + Development).
- Memory `project_qm_v5_locked_basket.md` and `project_qm_pipeline_v5.md` updated.
- Codex Task A (locate `run_news_impact_tests.py` on laptop) is downgraded — V5 may not reuse the V4 runner verbatim. Codex should still report what exists; V5 framework will decide whether to port, rewrite, or replace.

## Sources

- OWNER conversation 2026-04-26 (Board Advisor session)
- CLAUDE.md V5 boundary rules
- `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md` (the document whose "must inherit" framing this decision overrules)
- `decisions/2026-04-25_pipeline_15_phase_override.md`
