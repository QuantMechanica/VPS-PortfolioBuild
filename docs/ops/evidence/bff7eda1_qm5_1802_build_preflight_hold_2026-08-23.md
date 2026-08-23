# QM5_1802 build preflight — card and governed identity hold

- Task: `bff7eda1-2b00-4170-8a02-1afbffcd5c70` (`build_ea`, priority 10, Codex)
- EA: `QM5_1802_elder-impulse-system-h4`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1802_elder-impulse-system-h4.md`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Outcome: `PRECONDITION_HOLD_CARD_AND_REGISTRY`

## Deterministic preflight

The approved card has `g0_status: APPROVED`, but the build-ready schema check returns `schema_missing_frontmatter:target_symbols`.

The canonical read-only `farmctl.magic_allocation_precheck` returns `ready: false`, classification `card_target_symbols_missing_or_invalid`, and action `CARD_AMENDMENT_REQUIRED`. It resolves no target symbols, finds 0 exact EA-ID registry rows for 1802, and finds 0 active or historical magic rows for 1802.

The alias-like registry identity `QM5_1802_elder-impulse-system-h4` exists under EA ID 12266 and is retired. There is no active normalized identity for the requested slug. Development cannot reactivate or rekey that history.

## Existing directory census

`framework/EAs/QM5_1802_elder-impulse-system-h4/` is clean and contains one `.mq5`, no `.ex5`, no `SPEC.md`, and no `.set` files. The existing source SHA-256 is `d902fbf3aa3117f8da3ff902610afb11547713fd2376ecb99c6d3faf2226e261`.

No source, card, registry, resolver, setfile, binary, terminal, pipeline, `T_Live`, or AutoTrading state was changed. No compile or pipeline verdict is claimed.

## Required handoff

OWNER/Card Governance must add explicit canonical `target_symbols`, then adjudicate the requested identity against the retired alias history. Only after the governed allocator creates an exact active identity, one magic tuple per approved symbol, and matching resolver tuples may this build be routed again.

Tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee` is already in REVIEW; its evidence (`docs/ops/evidence/2026-08-23_registry_dispatch_drain_blocker.md`) records that no live registry batch was applied and the refusal cohort had zero build-ready cards. The approved flag alone does not authorize inventing missing scope or re-identifying the strategy.

**Short verdict:** `PRECONDITION_HOLD_CARD_AMENDMENT_AND_GOVERNED_IDENTITY_REQUIRED`
