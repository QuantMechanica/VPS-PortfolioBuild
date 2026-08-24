# Build Refusal Evidence — QM5_38007 codetrading-python-atr-grid-engine

- **Ticket:** `build-QM5_38007_codetrading-python-atr-grid-engine`
- **Date:** 2026-08-24
- **Disposition:** `BUILD_REFUSED`
- **Scope:** pre-build authorization and mechanical-completeness checks only

## Decision

No EA, registry, resolver, setfile, factory, queue, verdict, database, or live-system mutation was made. The binding pre-build gate failed because the named card is retired and has `g0_status: REJECTED`, not `APPROVED`.

The canonical build SOP requires an immediate stop when `g0_status: APPROVED` is absent (`tools/strategy_farm/prompts/codex_build_ea.md:516-517`). The build skill carries the same fail-closed precondition. The ticket's explicit refusal clause therefore applies.

## Deterministic evidence

### Card authorization

Canonical card read:

`D:/QM/strategy_farm/artifacts/cards_approved/QM5_38007_codetrading-python-atr-grid-engine.md`

- SHA-256: `078AEF73FBC75C63F00360A5D44B35A61A656E177B22C29DE5719D52A61F9F4A`
- The generic `status` field says `APPROVED`, but the controlling build authorization says `g0_status: REJECTED` (card lines 9-10).
- The card records its retirement reason in `g0_rejection_reason` (card line 55).
- Its final adjudication is headed `RETIRED ... DO NOT BUILD` (card line 232), repeats `g0_status: REJECTED` (line 234), and states that no faithful deterministic mechanization is possible (lines 236-239).

The prior durable adjudication independently records QM5_38007 as `RETIRED` and gives the same rationale (`docs/ops/evidence/471cffc3_strategy_cards_respecification_or_retirement_2026-08-21.md:22`, `:253-280`).

### Exact mechanical gaps

1. **Missing Level-0 trigger and direction.** The source assumes an initial dataframe position but supplies no reproducible live-market event that establishes `FirstEntry` or chooses long versus short (card lines 236-239; prior adjudication lines 277-280). The tier formulas cannot run before that undefined state exists.
2. **Irreconcilable position-count rules.** The no-trade filter blocks entries once one strategy position is open (card line 89), while the entry/exit contract requires tiers `k in [1,5]` and up to five concurrent orders (card lines 91-100). Literal implementation makes tiers 2-5 unreachable; relaxing the one-position cap would invent a rule contrary to the card.
3. **Prohibited mechanic.** The retirement adjudication states that grid/averaging-down is prohibited by the Edge Lab Charter and that DL-082 cannot repair the missing Level-0 rule (card line 236; prior adjudication line 280).

These are core entry/state-machine defects, not implementation details that can be resolved through a conservative default.

### Registry and worktree observations (read-only)

- `framework/registry/ea_id_registry.csv:4478` already marks EA ID `38007` as `retired`.
- `framework/registry/magic_numbers.csv:17365-17367` contains pre-existing active magic rows for the three card symbols. They were not edited because the refusal path permits committing only this evidence file.
- Contrary to the ticket premise that the EA does not exist, the current worktree already contains tracked files under `framework/EAs/QM5_38007_codetrading-python-atr-grid-engine/`, introduced by commit `bfd467bc6fcfa7dc1f61b4b8a2b5754fb394e500`. Those pre-existing files were not modified, compiled, or removed.

## What changed

Only this refusal evidence file was added. No build artifacts or governed registries changed.

## Validation output

The focused guard proving that retired registry IDs—explicitly including the QM5_38007 regression case—are excluded from build discovery passed:

```text
python -m pytest -q tools/strategy_farm/tests/test_auto_build_routing.py::RGateBuildReadinessTests::test_unbuilt_scan_skips_retired_registry_ids
.                                                                        [100%]
1 passed in 1.62s
```

The complete touched guardrail test module also passed:

```text
python -m pytest -q tools/strategy_farm/tests/test_auto_build_routing.py
.................................                            [100%]
33 passed, 12 subtests passed in 28.50s
```

EA hardening, setfile validation, compile, and smoke/backtest checks were intentionally not run: they require an authorized EA build, and the authorization gate failed before those stages.

## Required upstream resolution

A future build requires a new OWNER-authorized card with `g0_status: APPROVED` that:

1. defines the Level-0 entry event and deterministic direction;
2. reconciles the one-position limit with all permitted scale-in levels; and
3. supplies explicit authority for a mechanic compliant with the Edge Lab Charter.

Until all three are resolved in the canonical card, building this EA would fabricate strategy logic and violate the binding SOP.

## Rollback

Revert the ticket commit (for example, `git revert <commit>`) to remove this evidence file. No runtime or registry rollback is needed because no such state was changed.
