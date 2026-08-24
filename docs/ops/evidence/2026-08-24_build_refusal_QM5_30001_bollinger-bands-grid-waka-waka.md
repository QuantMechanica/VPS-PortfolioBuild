# Build Refusal — QM5_30001 bollinger-bands-grid-waka-waka

- Ticket: `build-QM5_30001_bollinger-bands-grid-waka-waka`
- Decision date: 2026-08-24
- Result: **REFUSED — deterministic G0 preflight failure**
- Build, registry, resolver, setfile, compile, backtest, router, factory, and live mutations: **not performed**

## Exact blocking gap

The canonical runtime card is not OWNER-authorized for build. Its front matter has
`status: APPROVED` but `g0_status: REJECTED`:

- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_30001_bollinger-bands-grid-waka-waka.md:9`: `status: APPROVED`.
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_30001_bollinger-bands-grid-waka-waka.md:10`: `g0_status: REJECTED`.
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_30001_bollinger-bands-grid-waka-waka.md:55`: the rejection record says the strategy was retired after the earlier grid/martingale build refusal.

The binding build SOP is fail-closed at this point:

- `tools/strategy_farm/prompts/codex_build_ea.md:516-517`: stop and return `card not APPROVED` when `g0_status: APPROVED` is not set.
- `C:/Users/Administrator/.codex/skills/qm/qm-build-ea-from-card/SKILL.md`, **Pre-flight verification** and **When NOT to use**: do not build a card whose G0 status is `REJECTED`.

There is no authorized interpretation under which the general `status: APPROVED` field overrides the explicit G0 rejection. An OWNER-authorized card revision setting `g0_status: APPROVED` would be required before this EA could be implemented.

## Corroborating repository state

The deterministic registry and tracked-tree state also contradict the ticket's build-ready premise:

- `framework/registry/ea_id_registry.csv:4408` records EA ID `30001` with status `retired`, not an active build allocation.
- `framework/registry/magic_numbers.csv:17354-17356` already contains active slots 0-2 for `AUDCAD.DWX`, `AUDNZD.DWX`, and `NZDCAD.DWX`; no rows were appended or overwritten.
- `framework/EAs/QM5_30001_bollinger-bands-grid-waka-waka/QM5_30001_bollinger-bands-grid-waka-waka.mq5:1-126` already exists as a tracked skeleton.
- That skeleton is not an implementation: line 46 identifies its entry logic as TODO, lines 42-57 contain inert strategy hooks, and it has no `SPEC.md` or setfiles.
- `docs/ops/evidence/111e7bc2_qm5_30001_grid_build_preflight_block_2026-08-17.md:1-27` records the prior refusal for the same grid/martingale mechanism.

The mirrored card under the existing EA directory is stale: `framework/EAs/QM5_30001_bollinger-bands-grid-waka-waka/docs/strategy_card.md:10` still says `g0_status: APPROVED`, while the ticket designates the runtime card above as canonical and that card says `REJECTED`. The runtime canonical card therefore controls this preflight.

## Validation and test disposition

Read-only verification performed from `C:/QM/worktrees/rework-slot-16`:

```text
rg -n '^(status|g0_status|g0_rejection_reason):|card not APPROVED|g0_status: APPROVED' <canonical-card> tools/strategy_farm/prompts/codex_build_ea.md
EA_DIR_EXISTS=True
ea_id_registry.csv:4408:30001,bollinger-bands-grid-waka-waka,MASTER-CENTURY-SUITE-2026-08-15,retired,Claude,2026-08-15,,,
magic_numbers.csv:17354-17356: slots 0-2, active
```

No pytest suite, build hardening, resolver regeneration, setfile generation, or compilation was run. Those actions validate or mutate an implementation and are downstream of the failed G0 authorization gate. The ticket's refusal branch requires committing only this evidence file.

## Rollback

Rollback is documentation-only: revert the commit containing this file, or remove
`docs/ops/evidence/2026-08-24_build_refusal_QM5_30001_bollinger-bands-grid-waka-waka.md`.
No EA source, registry, resolver, setfile, state database, factory, backtest queue,
router task, MT5 terminal, or live deployment state was changed.
