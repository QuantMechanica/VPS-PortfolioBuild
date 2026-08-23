# QM5_1701 build preflight — card and governed identity hold

- Task: `bd4171e3-56e3-4d5b-96a6-684a49f2b8f4` (`build_ea`, priority 10, Codex)
- EA: `QM5_1701_demark-td-sequential-tdst-overlay-h4`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1701_demark-td-sequential-tdst-overlay-h4.md`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Outcome: `PRECONDITION_HOLD_CARD_AND_REGISTRY`

## Deterministic preflight

The approved card has `g0_status: APPROVED`, but the build-ready schema check returns:

- `schema_missing_frontmatter:expected_trades_per_year_per_symbol`
- `schema_missing_frontmatter:target_symbols`

The canonical read-only `farmctl.magic_allocation_precheck` returns `ready: false`, classification `card_target_symbols_missing_or_invalid`, and action `CARD_AMENDMENT_REQUIRED`. It resolves no target symbols, finds 0 exact EA-ID registry rows for 1701, and finds 0 active or historical magic rows for 1701.

The normalized slug `demark-td-sequential-tdst-overlay-h4` has retired registry history under EA ID 1672. Alias-like identities for the requested 1701 and 1652 variants are also retired under IDs 12262 and 12260. Development cannot reactivate, rekey, or choose among that history.

## Existing directory census

`framework/EAs/QM5_1701_demark-td-sequential-tdst-overlay-h4/` is clean and contains one `.mq5`, no `.ex5`, no `SPEC.md`, and no `.set` files. The existing source SHA-256 is `4a5f7674fca6c3d66385de301f619b3752415089b80b269b0d4a22e44acfa948`.

No source, card, registry, resolver, setfile, binary, terminal, pipeline, `T_Live`, or AutoTrading state was changed. No compile or pipeline verdict is claimed.

## Router disposition

The canonical REVIEW gate for every `build_ea` task requires a truthful JSON identity binding committed current MQ5, EX5, setfiles, and strict-build PASS. Those artifacts cannot exist before the card and governed identity prerequisites are satisfied; a prose precondition artifact necessarily returns `D6_BUILD_IDENTITY_MISSING`. Following the canonical compile-hold precedent, this task is therefore dispositioned `BLOCKED`; no build identity was fabricated.

## Required handoff

OWNER/Card Governance must add explicit canonical `target_symbols` and `expected_trades_per_year_per_symbol`, then adjudicate the duplicated/retired Demark identity history. Only after the governed allocator creates an exact active identity for the adjudicated card, one magic tuple per approved symbol, and matching resolver tuples may this build be routed again.

Tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee` is already in REVIEW; its evidence (`docs/ops/evidence/2026-08-23_registry_dispatch_drain_blocker.md`) records that no live registry batch was applied and the refusal cohort had zero build-ready cards. The approved flag alone does not authorize inventing missing scope or re-identifying the strategy.

**Short verdict:** `PRECONDITION_HOLD_CARD_AMENDMENT_AND_GOVERNED_IDENTITY_REQUIRED`
