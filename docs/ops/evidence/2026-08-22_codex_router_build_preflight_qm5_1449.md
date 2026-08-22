# Codex router build preflight — QM5_1449

Date: 2026-08-22  
Role: Development / Codex  
Scope: scheduled single-pass router cycle; `build_ea` task at numeric priority 50  
Verdict: `PREBUILD_BLOCK_REGISTRY_UNALLOCATED`

## Outcome

Router task `b436a5ae-5394-495f-b9b0-067e9222c948` targets `QM5_1449_wilder-adx-dmi-crossover-h4`. Its card of record exists at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1449_wilder-adx-dmi-crossover-h4.md`, has the exact EA ID and slug, and declares `g0_status: APPROVED`.

The canonical `framework/registry/ea_id_registry.csv` contains 0 rows for EA ID 1449, and `framework/registry/magic_numbers.csv` contains 0 rows for it. This fails the deterministic preflight required by `qm-build-ea-from-card`, which explicitly excludes registry allocation from Development's build scope.

## Focused verification

| Check | Result |
|---|---|
| Approved-card SHA-256 | `7ac52a10591958834a08a125c3ab02c9bdb8b05e050dd1be9c3f96b04a010d8f` |
| Card identity | `QM5_1449` / `wilder-adx-dmi-crossover-h4` (exact) |
| G0 | `APPROVED` |
| Canonical EA-ID rows | 0 |
| Canonical magic rows | 0 |
| Exact EA directory/source | present; tracked |
| Source SHA-256 | `09ed6b67acf32a5fc33d05a9da861741dccce575992b03efa9b72ed942499819` |
| Source state | auto-generated TODO skeleton; no implemented entry logic |
| EX5 / SPEC / setfiles | 0 / 0 / 0 |

Verification used exact numeric-ID CSV-field matching, exact card/source paths, SHA-256 hashing, Git tracking, the explicit skeleton TODO marker, and filesystem counts.

No build check, compile, setfile generation, smoke, or pipeline phase was run because none can produce valid build evidence before governed identity and magic allocation. No source, registry, resolver, terminal, `T_Live`, or AutoTrading state was changed.

## Required upstream remediation

Allocate and activate the exact EA-ID row and every required magic row through the OWNER-governed deterministic registry workflow, regenerate the resolver through its governed writer, verify exact card/registry/directory slug identity, and then route a fresh build task.

This is a precondition failure, not a compile verdict, pipeline verdict, or live authorization.
