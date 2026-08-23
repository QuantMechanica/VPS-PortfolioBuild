# QM5_1651 build preflight — card and governed identity hold

- Task: `5e7ee21a-5fe8-48e9-870f-18bec88fc5ce` (`build_ea`, priority 10, Codex)
- EA: `QM5_1651_ehlers-ebsw-cycle-extract-composite-h4`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1651_ehlers-ebsw-cycle-extract-composite-h4.md`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Outcome: `PRECONDITION_HOLD_CARD_AND_REGISTRY`

## Deterministic preflight

The approved card has `g0_status: APPROVED`, but the build-ready schema check returns:

- `schema_missing_frontmatter:expected_trades_per_year_per_symbol`
- `schema_missing_frontmatter:target_symbols`

The canonical read-only `farmctl.magic_allocation_precheck` returns `ready: false`, classification `card_target_symbols_missing_or_invalid`, and action `CARD_AMENDMENT_REQUIRED`. It resolves no target symbols, finds 0 exact EA-ID registry rows for 1651, and finds 0 active or historical magic rows for 1651.

This is also an identity-adjudication case. The normalized slug `ehlers-ebsw-cycle-extract-composite-h4` is active under EA ID 1671 with 13 active magic rows; the alias-like registry identity `QM5_1651_ehlers-ebsw-cycle-extract-composite-h4` exists under EA ID 12259 and is retired. Development cannot silently reserve 1651 or reuse another identity.

## Existing directory census

`framework/EAs/QM5_1651_ehlers-ebsw-cycle-extract-composite-h4/` is clean and contains one `.mq5`, no `.ex5`, no `SPEC.md`, and no `.set` files. The existing source SHA-256 is `f0891ec218aa14bf3784a3a3e857007752556ec0e7b220303ef187958bd85b0e`.

No source, card, registry, resolver, setfile, binary, terminal, pipeline, `T_Live`, or AutoTrading state was changed. No compile or pipeline verdict is claimed.

## Required handoff

OWNER/Card Governance must add explicit canonical `target_symbols` and `expected_trades_per_year_per_symbol`, then adjudicate the requested 1651 identity against active EA 1671 and the retired alias history. Only after the governed allocator creates an exact active identity, one magic tuple per approved symbol, and matching resolver tuples may this build be routed again.

Tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee` is already in REVIEW; its evidence (`docs/ops/evidence/2026-08-23_registry_dispatch_drain_blocker.md`) records that no live registry batch was applied and the refusal cohort had zero build-ready cards. The approved flag alone does not authorize inventing missing scope or re-identifying the strategy.

**Short verdict:** `PRECONDITION_HOLD_CARD_AMENDMENT_AND_GOVERNED_IDENTITY_REQUIRED`
