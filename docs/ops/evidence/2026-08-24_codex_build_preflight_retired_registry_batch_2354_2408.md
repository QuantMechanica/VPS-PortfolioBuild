# Codex build preflight refusal: QM5_2354, QM5_2355, QM5_2406, QM5_2407, QM5_2408

Date: 2026-08-24 (Europe/Berlin)  
Lane: `codex` scheduled orchestration  
Outcome: `BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Scope

| Priority | Router task | Requested identity | Approved card | Related registry identity | Status | Requested/related magic rows |
|---:|---|---|---|---|---|---:|
| 10 | `99efdb31-1df6-4aa5-9102-bf7e250c149f` | `QM5_2354_brooks-failed-final-flag-h4` | PASS | `12314,QM5_2354_brooks-failed-final-flag-h4` | `retired` | 0 / 0 |
| 10 | `5fca8ef3-c38a-4e48-bdf8-0325a297434d` | `QM5_2355_demark-td-clopwin-h4` | PASS | `12315,QM5_2355_demark-td-clopwin-h4` | `retired` | 0 / 0 |
| 10 | `ef0f2333-e00f-41ce-9ecd-5d9f540cf3be` | `QM5_2406_brooks-triangle-h4` | PASS | `12316,QM5_2406_brooks-triangle-h4` | `retired` | 0 / 0 |
| 10 | `8d108839-29ec-4569-8039-109f7bbfcb15` | `QM5_2407_demark-td-clop-h4` | PASS | `12317,QM5_2407_demark-td-clop-h4` | `retired` | 0 / 0 |
| 10 | `2201ca64-2342-41f6-97ea-f34a31b48d92` | `QM5_2408_williams-mmm-h4` | PASS | `12318,QM5_2408_williams-mmm-h4` | `retired` | 0 / 0 |

## Deterministic preflight findings

1. Each runtime card exists under `D:/QM/strategy_farm/artifacts/cards_approved/`, declares `g0_status: APPROVED`, and matches its requested legacy EA ID and slug.
2. `framework/registry/ea_id_registry.csv` has no row at all for requested EA IDs `2354`, `2355`, `2406`, `2407`, or `2408`.
3. The only slug-related rows use different numeric IDs (`12314` through `12318`), embed the requested `QM5_<id>_` identity in the registry slug, and are all `retired`.
4. Each related row records `retired_at: 2026-08-21T18:52:35+00:00`, reason `OWNER-approved D1 disposition; action=RETIRE only`, and evidence `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.
5. `framework/registry/magic_numbers.csv` has zero rows for every requested ID and every related retired ID.
6. Each canonical EA directory contains only one 4,082-byte `.mq5` skeleton. There is no `.ex5`, no `SPEC.md`, and `Strategy_EntrySignal` retains `TODO: Auto-generated skeleton`.

An approved card and a scaffold directory do not reactivate an OWNER-retired identity or allocate deterministic magic numbers.

## Focused verification

A read-only PowerShell verifier parsed both CSV registries and all five approved cards, checked the EA directories, and asserted the expected fail-closed condition. It exited `0` with `all_expected_refusals=true`:

```text
checked_at_utc=2026-08-23T23:41:13.4606849Z
branch=agents/board-advisor
git_head_inspected=12220921d0aa5184f37c75822a501475d88ff9ef
ea_id_registry_sha256=a64791abae37b15fff228ce64af4d5974fcb959f7393ec63fe91f1e3cdfd4c1f
magic_numbers_sha256=e5072447fe5c7ef31e8f64807285d59fa973fe466e4aa9dfa0cbef8b756a6911
all_expected_refusals=true
```

| EA | Card SHA-256 | Source SHA-256 |
|---|---|---|
| QM5_2354 | `8b239254b824be9ea93ecc764ae71fcf565a9d4b5442c1cb9dea64e79f7709ca` | `7c67ef77d45bd790fb9dcbcc1fd3f8153eb938d84c01d48c28970cecb7f61cce` |
| QM5_2355 | `b94eeca02f1d736734881284554297e775cfbb196b0385e686778358ffea160a` | `d43b7118b2b0750ed4282c9a83ffa1c46d4623fd45cb9f9a169ecc51c60a5b30` |
| QM5_2406 | `45b7c9660ad09066621632a999cb7c73b601d0d1a7bf02be075df6d6b5b44ea4` | `a2483b810f50ed8c86963069f143d0ae0e901e62f38580e6876bea5edc9e2ff8` |
| QM5_2407 | `0157ca0c9439890f3e50f9fe5f679736d08f2d2c76428d3df4e01f6859c7e23d` | `cd5d8f10cfc6179dc95a7543dd9d61a304dea66da87433e29657ff3edb854247` |
| QM5_2408 | `7da7bfe8d5c58f89b385ff161b9b8018113eee9efff6cbde591b151a1c521c2c` | `f9e1c9e2018275a543fa6bb53a19db08e75fd3e4ce0f712d2a85735291691bed` |

## Verdict and boundary

The `qm-build-ea-from-card` preflight requires an allocated active EA ID, exact slug identity, and governed magic rows before implementation. Those conditions are absent, and the only related identities are explicitly OWNER-retired. The build therefore stopped at preflight.

No EA source, setfile, registry, resolver, terminal, live setting, or pipeline state was changed. Compile and backtests were intentionally not run. A future build requires the governed registry/card writer to supply a new active exact identity and every required magic row; Codex cannot manufacture that authority.
