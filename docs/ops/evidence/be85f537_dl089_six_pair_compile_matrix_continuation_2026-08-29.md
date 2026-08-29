# DL-089 six-pair compile and matrix continuation — 2026-08-29

- Router task: `be85f537-3c0d-4104-8c69-14bf8af0c165`
- Lane: Codex / `agents/board-advisor`
- Disposition: **PARTIAL PASS, PRECISE FAIL-CLOSED BLOCKERS**
- Scope: append-only governed compile enrollment/release and DL-089 matrix
  materialization only. No Q-phase, pipeline, economic, portfolio, or live
  verdict is asserted.

## Outcome

Three of the six measurement EAs have source-hash-matched `COMPILE_OK`
receipts with zero compiler errors, zero compiler warnings, and passing build
checks: `QM5_41163`, `QM5_41197`, and `QM5_41198`. `QM5_41194` compiled with
zero errors/warnings but correctly failed its build check. `QM5_41195` and
`QM5_41196` were refused before enrollment by the canonical candidate guard.

The governed DL-089 service materialized the ready
`QM5_20266 / XTIUSD.DWX` declaration into 1,085 append-only `OPT_CENSUS`
cells. The other five declarations remain at zero cells behind the exact
preconditions below. This satisfies the routed task's alternative acceptance
condition: an exact fail-closed blocker is recorded for every incomplete pair.

## Governed compile receipts

| Measurement EA | Work item | MQ5 expected/current | EX5 SHA-256 | Compiler | Build check | Receipt SHA-256 |
|---|---|---|---|---|---|---|
| `QM5_41163` | `2361ac93-a55b-4e32-a020-db5417d22dba` | `337aa718eab729ec7c4e7c55e66145898f779064a8618bcfb02be8289916ef36` / exact match | `72f41ebf0511e4b1adc34bd62612833dc58b76bf7580e225b4ae51bc7752aaec` | 0 errors, 0 warnings | PASS / `COMPILE_OK` | `32e94472174f795671ea88666a916dd3bcc1b72f9952ec1b6c6903293458965b` |
| `QM5_41194` | `518916d5-ff50-4724-8583-6a21d7b9ebe2` | `20eb478d8db92fd9f6d5ad0c9e6146765e3465bebd5b4b3c13db1f454262f056` / exact match | `0b637dc915b7d8f5e220fbf04afbc6a1336603512d103a74108e3258bed6ef5d` | 0 errors, 0 warnings | **FAIL**: `EA_FRAMEWORK_RAW_SERIES_CALL`, `EA_Q08_MAE_HOOK_MISSING` / `COMPILE_FAIL` | `5b24fa8563261e06e5dcdb15062f978dcc89554cc4129f2a806cefc67227310c` |
| `QM5_41195` | none | current MQ5 `713f6503a73b1c39a35c77b727ffd57999507fc50defb9da3de3c41f4146ecca` | none | not run | enrollment refused: `BOUND_SETFILE_HASH_EXISTS` | none |
| `QM5_41196` | none | current MQ5 `0128d2f16f3febd0bec549b8db0ea9fd030825dedfc06934d5aabc01781be665` | none | not run | enrollment refused: `BOUND_SETFILE_HASH_EXISTS` | none |
| `QM5_41197` | `3f472524-6774-4fb9-91fa-2de5dde91169` | `9918490a1942c1b3a661d0a1b2a4a1ed8c2f3517ac0ef4a480796c25d5016c3a` / exact match | `98e052ec71f1584a25c43189ef2ceeada6098ffa52ed3e3269b5933164da1841` | 0 errors, 0 warnings | PASS / `COMPILE_OK` | `f6c4780cc3eae01364beb79ff6d09a465c36f2167f529451b558d4e038227b85` |
| `QM5_41198` | `5d4f7971-02e1-4280-a4c8-e546c9e56858` | `c59d14f7f13e29faac36e29315288267978a6babe92ab181273620f9760d1d2e` / exact match | `7bc7b5ec70c3ed2687edfffdf9ff3208886f361af831316e5324672fa7ed57a3` | 0 errors, 0 warnings | PASS / `COMPILE_OK` | `f06f92b10de9274e9e15dee5f3fb86397e255f4ca067c2f62effd78430428279` |

Receipt paths follow the governed layout
`D:/QM/reports/work_items/<work-item>/<ea-id>/COMPILE_EA/compile_evidence.json`.

`QM5_41197` was released through the exact-row rollout utility. The release
selected only `3f472524-6774-4fb9-91fa-2de5dde91169`, verified the queued and
current MQ5 hashes above, and made a pre-mutation SQLite backup at
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260829T200411Z_b1223b50.sqlite`
(SHA-256 `715fdd8877b1120e3bac6f7bd8667806fd7bb777a2c9a349d91cd8c594481b7a`).
The release receipt is
`docs/ops/evidence/2026-08-29_be85f537_QM5_41197_compile_release.json`
(SHA-256 `1e371951cb93cfc9dfdf973ab6633403af5c3d1073b570fafe99fbd0c36b0c23`).

## Canonical enrollment refusals

The positional `farmctl.py enqueue-compile` path was invoked serially with the
exact open build-task binding for each remaining unenrolled sibling:

- `QM5_41195` / build task `5f813a36-e205-47ac-b3d2-fa21851f5cf7`:
  build-task binding authorized, then refused solely because the existing
  XAGUSD D1 setfile contains bound build hash
  `55d38ba42b601f03aaec0451d6358b9c1c8b0ce86d7b692d2f9aee9db1476771`.
- `QM5_41196` / build task `70a134ea-144f-420f-9585-ad6d4c588320`:
  build-task binding authorized, then refused solely because the existing
  XAUUSD D1 setfile contains bound build hash
  `ae7b2e5bdeb59c6ad95d5c856c77b2bbe23e20d3415a2498c525adf2c78b0660`.

No setfile binding was removed, no force-rebuild/source-repair authority was
invented, and no guard was weakened. Both setfiles retain fixed-risk semantics
(`RISK_FIXED > 0`, `RISK_PERCENT = 0`).

## Q12 declaration and OPT_CENSUS state

Read-only counts were taken directly from canonical
`D:/QM/strategy_farm/state/farm_state.sqlite`, grouped by measurement EA and
`phase='OPT_CENSUS'`.

| Subject pair / declaration | Measurement EA | OPT_CENSUS total | Exact current state |
|---|---|---:|---|
| `QM5_11422 / USDCAD.DWX` / `f9e1f7fc-f92e-5399-9f7d-c7e83e940ce5` | `QM5_41163` | 0 | Compile receipt is ready; governed service is waiting on its created Q02 prerequisite `7d61eedb-1b9c-5cb8-a416-13a50fb67814` (`pending`, no verdict). |
| `QM5_13054 / XTIUSD.DWX` / `a5b90e08-cf49-51ac-be59-1d4926da2363` | `QM5_41194` | 0 | No `COMPILE_OK`: immutable compile row failed build checks `EA_FRAMEWORK_RAW_SERIES_CALL` and `EA_Q08_MAE_HOOK_MISSING`. |
| `QM5_1537 / XAGUSD.DWX` / `c41e2606-3af1-5766-9bb7-18de8a763a18` | `QM5_41195` | 0 | Measurement binary absent because canonical enrollment refused `BOUND_SETFILE_HASH_EXISTS`. |
| `QM5_21507 / XAUUSD.DWX` / `99e7e9db-d9a7-514c-b78d-c14e98ebec5d` | `QM5_41196` | 0 | Measurement binary absent because canonical enrollment refused `BOUND_SETFILE_HASH_EXISTS`. |
| `QM5_11881 / GBPUSD.DWX` / `d824e8cb-8397-5aa3-b6fa-fec9b0c375eb` | `QM5_41197` | 0 | Compile receipt is ready; governed service is waiting on its created Q02 prerequisite `0eadb68f-95d8-518c-a718-c8adc7c79c20` (`pending`, no verdict). |
| `QM5_20266 / XTIUSD.DWX` / `d8739ae2-1ce4-553a-9b59-1335e582614c` | `QM5_41198` | **1,085** (`pending=1,085`) | Materialized successfully; eight pending cells received the governed priority-window boost. |

The materialized program is
`DL089_QM5_20266_XTIUSD_DWX_2019_2025`. Its authenticated ledger is
`D:/QM/strategy_farm/artifacts/opt_census/DL089_QM5_20266_XTIUSD_DWX_2019_2025/ledger.json`
(SHA-256 `7e65e2717c117b22785ade374f9286906977d3bc010c3f356699f7b6a945a9ae`),
and its runner registration SHA-256 is
`37bfe5da277a80e42948cf62adadae5478f654dbf68cbecda9a16cb1719b03dc`.

## Guardrail statement

No terminal was started manually, no active backtest was interrupted, no
AutoTrading or T_Live state was changed, no hold/precondition was bypassed,
and no pipeline verdict was manufactured. The compile and matrix work remains
append-only and the incomplete pairs remain fail-closed for the deterministic
router to continue after their exact upstream defects are repaired.
