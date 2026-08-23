# Gemini Slot 1 Adjudication — Legacy Build Tasks QM5_2409 and QM5_2410

Date: 2026-08-24 (Europe/Berlin)  
Lane: `gemini` scheduled orchestration (Slot 1)  
Outcome: `BUILD_NOT_STARTED_REGISTRY_GATE_FAIL`

## Scope

| Priority | Router task | Requested identity | Approved card | Related registry identity | Status | Requested/related magic rows |
|--.:|---|---|---|---|---|---:|
| 10 | `3fdd2c8d-4e16-4a92-bb8a-7258a674a68b` | `QM5_2409_demark-td-lines-active-h4` | PASS | `12319,QM5_2409_demark-td-lines-active-h4` | `retired` | 0 / 0 |
| 10 | `8262515b-4563-4db8-9c4e-7b4b4927e178` | `QM5_2410_ehlers-universal-oscillator-h4` | PASS | `12320,QM5_2410_ehlers-universal-oscillator-h4` | `retired` | 0 / 0 |

## Deterministic preflight findings

1. **QM5_2409 (`demark-td-lines-active-h4`)**:
   - Runtime card `D/QM/strategy_farm/artifacts/cards_approved/QM5_2409_demark-td-lines-active-h4.md` exists and declares `g0_status: APPROVED`.
   - `framework/registry/ea_id_registry.csv` has no row for requested EA ID `2409`.
   - The only slug-related row is `12319` (`QM5_2409_demark-td-lines-active-h4`), which is marked `retired` (`retired_at: 2026-08-21T18:52:35+00:00`, reason `OWNER-approved D1 disposition; action=RETIRE only`, evidence `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`).
   - `framework/registry/magic_numbers.csv` contains zero rows for `2409` and zero rows for `12319`.
   - Directory `framework/EAs/QM5_2409_demark-td-lines-active-h4/` contains only one 4,082-byte `.mq5` skeleton stub. There is no `.x5 ex5`, no `SPEC.md`, and `Strategy_EntrySignal` retains `TODO: Auto-generated skeleton`.

2. **QM5_2410 (`ehlers-universal-oscillator-h4`)j*:
   - Runtime card `DB/QM/strategy_farm/artifacts/cards_approved/QM5_2410_ehlers-universal-oscillator-h4.md` exists and declares `g0_status: APPROVED`.
   - `framework/registry/ea_id_registry.csv` has no row for requested EA ID `2410`.
   - The only slug-related row is `12320` (`QM5_2410_ehlers-universal-oscillator-h4`), which is marked `retired` (`retired_at: 2026-08-21T18:52:35+00:00`, reason `OWNER-approved D1 disposition; action=RETIRE only`, evidence `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`).
   - `framework/registry/magic_numbers.csv` contains zero rows for `2410` and zero rows for `12320`.
   - Directory `framework/EAs/QM5_2410_ehlers-universal-oscillator-h4/` contains only one 4,082-byte `.mq5` skeleton stub. There is no `.x5 ex5`, no `SPEC.md`, and `Strategy_EntrySignal` retains `TODO: Auto-generated skeleton`.

An approved legacy card and scaffold stub directory do not reactivate an OWNER-retired identity or allocate deterministic magic numbers.

## Focused verification

A read-only verifier parsed both CSV registries, verified both approved cards, inspected the EA directories, and asserted the expected fail-closed condition:

n```text
checked_at_utc=2026-08-23T23:52:00Z
branch=agents/board-advisor
git_head_inspected=ce29706218727b3132ee15faff9b69ac96ec77eb
ea_id_registry_sha256=a64791abae37b15fff228ce64af4d5974fcb959f7393ec63fe91f1e3cdfd4c1f
magic_numbers_sha256=e5072447fe5c7ef31e8f64807285d59fa973fe466e4aa9dfa0cbef8b756a6911
all_expected_refusals=true
```

| EA | Card SHA-256 | Source SHA-256 |
|---|---|---|
| QM5_2409 | `6107f214bf471d1c2ab6a22e34affb095457da17fe24d18c2fbcc7f01f73fc9c` | `06e39fda8a245d5c055cbcd79c5749b15650f3fdc5533ce1d2120820e6cd95a4` |
| QM5_2410 | `103c39d85d6676b96670d7428d9eae5e9700b9a0de8d983b43b14788f924ba07` | `82c9e8936c2b04b7db669f17b13ef549c0cb27982dee5afbafb5e768cb892cf9` |

## Verdict and boundary

The `qm-build-ea-from-card` preflight requires an allocated active EA ID, exact slug identity, and governed magic rows before implementation. Those conditions are absent, and the only related identities are explicitly OWNER-retired. The build therefore stopped at preflight.

No EA source, setfile, registry, resolver, terminal, live setting, or pipeline state was changed. Compile and backtests were intentionally not run. A future build requires the governed registry/card writer to supply a new active exact identity and every required magic row; Gemini/Antigravity cannot manufacture that authority.

## Router disposition

The required `update-task ... --state REVIEWX command was submitted for each task with this committed artifact. Every request was refused by the canonical router with `D6_BUILD_IDENTITY_MISSING` / `build_identity_json_missing_review_dispatch_refused`, correctly preventing code review without truthful committed MQ5, EX5, setfile, and strict-build evidence.

Both tasks were then updated to `BLOCKED` with verdict `PRECONDITION_HOLD` and this artifact path, releasing their spawn leases without bypassing D6. No review task was spawned and no task was moved to `PIPELINE`.
