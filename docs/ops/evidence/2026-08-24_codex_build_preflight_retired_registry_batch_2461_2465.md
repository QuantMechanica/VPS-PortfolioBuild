# Codex build preflight refusal: QM5_2461 through QM5_2465

Date: 2026-08-24 (Europe/Berlin)  
Lane: `codex` scheduled orchestration  
Outcome: `BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Scope

| Priority | Router task | Requested identity | Approved card | Related registry identity | Status | Requested/related magic rows |
|---:|---|---|---|---|---|---:|
| 10 | `1fd88db4-fbd1-49a2-83c6-293bdf9cb11b` | `QM5_2461_brooks-failed-wedge-h4` | PASS | `12321,QM5_2461_brooks-failed-wedge-h4` | `retired` | 0 / 0 |
| 10 | `5297d50e-314d-4557-8f14-9463bcf7fc3e` | `QM5_2462_demark-td-channel-1-h4` | PASS | `12322,QM5_2462_demark-td-channel-1-h4` | `retired` | 0 / 0 |
| 10 | `fcaeb2ee-6c92-4d57-8a8b-fe71deb585e9` | `QM5_2463_sperandeo-spring-channel-h4` | PASS | `12323,QM5_2463_sperandeo-spring-channel-h4` | `retired` | 0 / 0 |
| 10 | `afe18aff-644c-43da-84b3-7e725212ba61` | `QM5_2464_pring-special-k-histogram-h4` | PASS | `12324,QM5_2464_pring-special-k-histogram-h4` | `retired` | 0 / 0 |
| 10 | `d76d758e-d4d6-4898-a958-15e9bdf4e853` | `QM5_2465_demark-td-channel-2-h4` | PASS | `12325,QM5_2465_demark-td-channel-2-h4` | `retired` | 0 / 0 |

## Deterministic preflight findings

1. Each runtime card exists under `D:/QM/strategy_farm/artifacts/cards_approved/`, declares `g0_status: APPROVED`, and matches its requested legacy EA ID and slug.
2. `framework/registry/ea_id_registry.csv` has no row at all for requested EA IDs `2461` through `2465`.
3. The only slug-related rows use different numeric IDs (`12321` through `12325`), embed the requested `QM5_<id>_` identity in the registry slug, and are all `retired`.
4. Each related row records `retired_at: 2026-08-21T18:52:35+00:00`, reason `OWNER-approved D1 disposition; action=RETIRE only`, and evidence `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.
5. `framework/registry/magic_numbers.csv` has zero rows for every requested ID and every related retired ID.
6. Each canonical EA directory contains only one 4,082-byte `.mq5` skeleton. There is no `.ex5`, no `SPEC.md`, and `Strategy_EntrySignal` retains `TODO: Auto-generated skeleton`.

An approved card and a scaffold directory do not reactivate an OWNER-retired identity or allocate deterministic magic numbers.

## Focused verification

A read-only PowerShell verifier parsed both CSV registries and all five approved cards, checked the EA directories, and asserted the expected fail-closed condition. It exited `0` with `all_expected_refusals=true`:

```text
checked_at_utc=2026-08-23T23:45:12.9194376Z
branch=agents/board-advisor
git_head_inspected=9fac958035fd7098bcd865e562f528b0aa145d39
ea_id_registry_sha256=a64791abae37b15fff228ce64af4d5974fcb959f7393ec63fe91f1e3cdfd4c1f
magic_numbers_sha256=e5072447fe5c7ef31e8f64807285d59fa973fe466e4aa9dfa0cbef8b756a6911
all_expected_refusals=true
```

| EA | Card SHA-256 | Source SHA-256 |
|---|---|---|
| QM5_2461 | `dc8c8bf88eec23dd125e181301b105e06fa6623770d044390e1431b1a560593c` | `709276311e07701439dfe49be3371235fab328b6faebc3fe5391487bd6272f86` |
| QM5_2462 | `eb896fc1057801e14144767bc4b012563eb42f1acfa78d07dbdfde0e98a9f16f` | `d5d09ce02975b62b4b4e6f563e5782a8c6994dc523b36b641cb131a961466df8` |
| QM5_2463 | `001722151aeae72246f275ababcdb5c4d7b4164206570198cfb61ee0810311e0` | `04e43ac3406d0846c673abeb390476e0b7e7213dae98afe28350018389c894e3` |
| QM5_2464 | `ebd4ee34ce152a1ae920c29544db5976446ad744fce580866ef1e6fec163922a` | `6225991cc226ec239f98c5e8df86d63691eb558196c199fa5f37a136f0126d98` |
| QM5_2465 | `f76e719fb41efe68e5c41b40a12f4d930fd6f9d3b416ce509fa821148f0347d6` | `1a3656e16b391289de293257119abc66b4bb56ff508dcf87d0be41534c2e0c91` |

## Verdict and boundary

The `qm-build-ea-from-card` preflight requires an allocated active EA ID, exact slug identity, and governed magic rows before implementation. Those conditions are absent, and the only related identities are explicitly OWNER-retired. The build therefore stopped at preflight.

No EA source, setfile, registry, resolver, terminal, live setting, or pipeline state was changed. Compile and backtests were intentionally not run. A future build requires the governed registry/card writer to supply a new active exact identity and every required magic row; Codex cannot manufacture that authority.
