# Codex build preflight refusal: QM5_2297, QM5_2298, QM5_2299, QM5_2300, QM5_2351

Date: 2026-08-24 (Europe/Berlin)  
Lane: `codex` scheduled orchestration  
Outcome: `BUILD_BLOCKED_PRECONDITION`

## Scope

| Priority | Router task | Card identity | Related registry row | Registry status | Magic rows |
|---:|---|---|---|---|---:|
| 10 | `6550a1f8-cb6b-4b6b-b04b-f06be41603d1` | `QM5_2297_sperandeo-channel-buster-h4` | `12307,QM5_2297_sperandeo-channel-buster-h4` | `retired` | 0 |
| 10 | `15d9681a-5f85-40ad-8a0d-00f3c5fbba76` | `QM5_2298_williams-smash-day-h4` | `12308,QM5_2298_williams-smash-day-h4` | `retired` | 0 |
| 10 | `3c27df92-4d2c-4b51-9e5b-a2d63c4db340` | `QM5_2299_brooks-final-flag-h4` | `12309,QM5_2299_brooks-final-flag-h4` | `retired` | 0 |
| 10 | `ba175427-ff12-42bf-8790-c6e997a0673f` | `QM5_2300_chande-vidya-slope-h4` | `12310,QM5_2300_chande-vidya-slope-h4` | `retired` | 0 |
| 10 | `997906f8-9eec-4693-9193-74c6597715ca` | `QM5_2351_demark-td-diff-rsi-h4` | `12311,QM5_2351_demark-td-diff-rsi-h4` | `retired` | 0 |

## Deterministic preflight findings

1. Each runtime card is present under `D:/QM/strategy_farm/artifacts/cards_approved/` and declares `g0_status: APPROVED`, the expected legacy `QM5_<id>` identity, and the expected plain slug.
2. `framework/registry/ea_id_registry.csv` has no active exact row for any requested numeric ID and plain slug. The only related rows use different numeric IDs (`12307` through `12311`), embed the legacy `QM5_<id>_` prefix in the registry slug, and are all `retired`.
3. Every related registry row records `retired_at: 2026-08-21T18:52:35+00:00`, reason `OWNER-approved D1 disposition; action=RETIRE only`, and evidence `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`.
4. `framework/registry/magic_numbers.csv` has zero rows for the requested IDs, the related IDs, and the five slugs.
5. Each EA directory contains only an uncompiled `.mq5` scaffold. There is no `.ex5` and no `SPEC.md`; each `Strategy_EntrySignal` still contains `TODO: Auto-generated skeleton` and returns `false`.

The approved-card files were written on 2026-08-23, after the recorded 2026-08-21 retirement. Card presence alone does not reactivate an OWNER-retired registry row or allocate magic numbers.

## Focused verification

A read-only PowerShell check parsed both registries and the five approved cards, hashed each source, and asserted the preflight failure. It exited `0` only because all five results matched the expected refusal condition:

```text
task 6550a1f8: g0=APPROVED active_exact=0 related=12307/retired magic=0 ex5=false spec=false -> FAIL_REGISTRY_AND_MAGIC_PRECONDITIONS
task 15d9681a: g0=APPROVED active_exact=0 related=12308/retired magic=0 ex5=false spec=false -> FAIL_REGISTRY_AND_MAGIC_PRECONDITIONS
task 3c27df92: g0=APPROVED active_exact=0 related=12309/retired magic=0 ex5=false spec=false -> FAIL_REGISTRY_AND_MAGIC_PRECONDITIONS
task ba175427: g0=APPROVED active_exact=0 related=12310/retired magic=0 ex5=false spec=false -> FAIL_REGISTRY_AND_MAGIC_PRECONDITIONS
task 997906f8: g0=APPROVED active_exact=0 related=12311/retired magic=0 ex5=false spec=false -> FAIL_REGISTRY_AND_MAGIC_PRECONDITIONS
```

Source SHA-256 values, in table order:

```text
6943C4324305AF6A61EA4BFE348B1CFFF5CB7F2FD930ADD0606348AED3E0CAF2
CAA25909268882402187B8C23F69F8F673ADD7AFF7EF9CAF66009679624B11D6
C269374D779EDF237F1794FAA927C477503A6675CCC81A804BA9E842BB89A9A6
8BA3220FAF6C71220E84BCBAAB41A32A815504C3A81882DC827C515D6F52DAF7
208EA7E5475924B94F846C80BE17E1C2A1B0C0A6F472B720A2B4CD23B5ED25D8
```

## Verdict and boundary

The `qm-build-ea-from-card` preflight requires an active allocated `ea_id`, an exact slug identity, and governed magic rows before implementation. Those conditions are absent and the related identities are explicitly OWNER-retired. No EA, setfile, registry, resolver, terminal, or pipeline mutation was made, and compile was intentionally not run.

The required `REVIEW` transition was attempted for every task and refused by the canonical router with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`. A build review packet must bind committed current MQ5, EX5, setfiles, and strict-build PASS; none can truthfully exist after a failed registry preflight. Following the canonical preflight-hold precedent, all five tasks were therefore dispositioned `BLOCKED` with this artifact, without fabricating build identity.

Any future build requires a new OWNER-governed active allocation and magic rows that supersede the retirement evidence; Codex must not manufacture that authority.
