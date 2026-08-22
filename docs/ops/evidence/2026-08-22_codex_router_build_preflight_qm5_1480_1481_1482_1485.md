# Codex router build preflight — QM5_1480, QM5_1481, QM5_1482, QM5_1485

Date: 2026-08-22  
Role: Development / Codex  
Scope: scheduled single-pass router cycle; four `build_ea` tasks at numeric priority 50  
Verdict: `PREBUILD_BLOCK_REGISTRY_IDENTITY`

## Outcome

All four exact cards exist, declare `g0_status: APPROVED` and `r3_data_available: PASS`, and have tracked EA directories containing only auto-generated TODO skeletons. None satisfies the deterministic identity/magic preflight required by `qm-build-ea-from-card`.

QM5_1480, QM5_1481, and QM5_1482 have no EA-ID registry row and no magic row. QM5_1485 has an active EA-ID row, but it is allocated to the different slug `as-haa-simple`, not the routed/card/directory slug `bw-awesome-oscillator-saucer-h4`; it also has no magic rows. Development must not overwrite or reinterpret that active identity.

## Routed cohort and focused verification

Equal-priority tasks are listed by ascending numeric EA ID.

| Router task | EA / routed slug | Card SHA-256 | G0 / R3 | EA registry result | Magic rows | Source | EX5 / SPEC / sets | Result |
|---|---|---|---|---|---:|---|---|---|
| `e1abae8e-98f3-4db2-91e5-d2b82f9a7a68` | `QM5_1480_carter-ttm-trend-h4` | `b6675eab0cd9fcba7af249aa962cb3d94897b5bfb9bae68ddab1b285eeba9b34` | `APPROVED` / `PASS` | 0 rows | 0 | tracked TODO skeleton, SHA-256 `42da5755fa5b4627c64569b97218e3fff84bb0bd18c090b161a3aaa889e237f2` | 0 / 0 / 0 | unallocated |
| `f54dd835-ec9c-4887-9c10-c04ceb733d98` | `QM5_1481_wilder-adx-dmi-crossover-h4` | `97119b892f4e18de4cc80c17633bf56b9d695a7a07e605750eedeedbbbb3ea2c` | `APPROVED` / `PASS` | 0 rows | 0 | tracked TODO skeleton, SHA-256 `91035245587c7ae7444cbd2edac8b3a2a5591d47041f0c25d717111971ad813e` | 0 / 0 / 0 | unallocated |
| `f54bf4d4-befa-47c0-b33b-a099a1fcffc1` | `QM5_1482_carney-three-drive-harmonic-h4` | `48be31572aa93ab20fb7b8de85d0a4fe817bd7858a57940b0b920f36b5b74be3` | `APPROVED` / `PASS` | 0 rows | 0 | tracked TODO skeleton, SHA-256 `ad75e3f15c8a5ac3dbdf8a0c9e75d212ea83e8eae8e90e506610e1c1fdd17cc6` | 0 / 0 / 0 | unallocated |
| `22b0307b-da28-45f8-be0e-d445ac5ed217` | `QM5_1485_bw-awesome-oscillator-saucer-h4` | `d22c62b3ec8d801ebb603a774327d9099d1789deff0bf69436c5f833de2aa76d` | `APPROVED` / `PASS` | active row belongs to `as-haa-simple` | 0 | tracked TODO skeleton, SHA-256 `e1966b36446ed220efd3e311369039cf5e44ffbcb8da314454c99948b93483fc` | 0 / 0 / 0 | identity conflict |

Verification used exact approved-card paths, SHA-256 hashing, exact numeric-ID CSV-field matching, exact slug comparison, Git tracking, the explicit skeleton TODO marker, and filesystem counts.

## Deterministic boundary

The build procedure requires an allocated EA row whose slug exactly matches the card and directory, plus active magic rows for every symbol slot. It explicitly excludes allocating or rekeying either registry from Development's build scope. Consequently no build check, compile, setfile generation, smoke, or pipeline phase was run. These are precondition failures, not compile or pipeline verdicts.

No source, registry, resolver, news seed, terminal, `T_Live`, or AutoTrading state was changed.

## Required upstream remediation

1. Allocate governed exact-slug EA-ID and magic rows for QM5_1480, QM5_1481, and QM5_1482, then route fresh builds.
2. Adjudicate the QM5_1485 identity collision upstream: preserve the active `as-haa-simple` identity or OWNER-authorize a deterministic rekey/new EA ID for `bw-awesome-oscillator-saucer-h4`; then allocate matching magic rows and route a fresh build.

Development must not self-allocate, overwrite, or silently reuse the conflicting identity.
