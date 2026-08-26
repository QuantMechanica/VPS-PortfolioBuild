# HMA Category-A compile conformance repair — 2026-08-26

## Scope and authority

- Router task: `d29159b2-84ff-4f78-a9e0-c724995e074c`
- OWNER decision retained: `OWNER-DEC-HMA-CATA`
- Original execution authority: `router_ops_issue:c29fddf8-fab7-4909-a506-499f6ab78f37`
- Approved population: the exact nine labels in
  `docs/ops/evidence/2026-08-25_c29fddf8_hma_cata_compile_labels.csv`
- Source repair commit: `8922c5a1a` on `agents/board-advisor`

This continuation changes only objective framework conformance. It does not
change entry/exit thresholds, HMA mechanics, sizing, risk, news behavior,
symbols, timeframes, historical verdicts, or the OWNER decision binding.

## Failed predecessor census and repair

| EA | Immutable failed predecessor | Failure classes | Mechanical source repair | New MQ5 SHA-256 |
|---|---|---|---|---|
| `QM5_2002_nnfx-qqe-trend` | `b6fef2d3-23a5-4517-aef0-1946608bec51` | `EA_FRAMEWORK_RAW_SERIES_CALL`; `EA_Q08_MAE_HOOK_MISSING`; `EA_TRADE_REQUEST_UNINITIALIZED` | raw OHLCV reads replaced by `QM_ReadBar`; direct MAE hook; aggregate-zero entry request | `9a7b5b6b350c44d6b099aad3baebad55f0859a69cf3c992ee6af1861b1f8fac4` |
| `QM5_9998_tv-hull-suite-hma-color-flip` | `fe00c27a-7924-4f49-abf3-33d80e85032b` | `EA_Q08_MAE_HOOK_MISSING` | direct MAE hook | `e940ea179575d3c02d001ae77b3a7404f90ef66dbd3b5f36d300ccfe363fafdd` |
| `QM5_10251_tv-nova-rev` | `e2a41bd1-87bd-434b-8b5d-b8c1e02b92bc` | `EA_Q08_MAE_HOOK_MISSING`; `EA_INDICATOR_BUFFER_UNBOUNDED` | direct MAE hook; explicit fail-fast `ArraySize` proof | `fb47f95592400abc285586f4d84ae34027bb5c97e1b5f2180742999f6b7a4078` |
| `QM5_10593_mql5-adxhull` | `96c09e7e-1586-4140-9dd1-9bbe96fbbbb5` | `EA_Q08_MAE_HOOK_MISSING` | direct MAE hook | `959e2e2c86aef788f96c50f5b8afa5310be7816da8264c6342acf0538a92d40b` |
| `QM5_10602_mql5-oshma` | `5140d4a2-756d-4bca-9608-10299dba1748` | `EA_Q08_MAE_HOOK_MISSING` | direct MAE hook | `f77c6526f249318771c9a4effc31132e24a6fe979c2d84555c5c44d4580145e2` |
| `QM5_10833_tv-autobot12` | `c96c55ee-762a-4f47-81de-1b6126a6e4e2` | `EA_Q08_MAE_HOOK_MISSING`; `EA_TRADE_REQUEST_UNINITIALIZED` | direct MAE hook; aggregate-zero entry request | `a13a6aef639d3d1ae5e7bb6e7bebf029e3bbfb24a0b64ddb5eee607ac0ae9557` |
| `QM5_10960_ftmo-hma-rsi` | `b74f3eed-8140-4a79-bd71-cd035696b650` | `EA_Q08_MAE_HOOK_MISSING`; `EA_INDICATOR_BUFFER_UNBOUNDED` | direct MAE hook; explicit fail-fast `ArraySize` proofs | `b10e7b62937bc6f244346ecaeb17ef0f08195ee8d10aed392191e85763868cac` |
| `QM5_12742_nnfx-configurable-engine` | `a3e70bd6-5123-4b43-9aeb-e40db80f9d8e` | `EA_Q08_MAE_HOOK_MISSING` | direct MAE hook | `ff486d5a8daecb8044317c500b0a937f460bf064dd6f013fbb6174af398b3dd8` |
| `QM5_12958_nnfx-hma-wae-swing` | `5deb4aa6-defe-4897-9495-62e003f09393` | `EA_FRAMEWORK_RAW_SERIES_CALL`; `EA_Q08_MAE_HOOK_MISSING` | raw closed-bar reads replaced by `QM_ReadBar`; direct MAE hook | `60dae6a33ad47e7a60a06100959a8b222f557d70f81cb65e6a75eaf93eab7962` |

## Focused verification

- `validate_build_guardrails.py` across all nine MQ5 files: **PASS 9/9**,
  with the enforced news-staleness ceiling shown as 336 hours.
- `build_gate_hardening.py --ea-label ...` across all nine labels after the
  repair: **0 failures and 0 warnings for every EA**.
- `python -m pytest tools/strategy_farm/tests/test_build_guardrails.py -q`:
  **22 passed**.
- `git diff --cached --check` on the exact nine source paths: **PASS**.
- No set file was included in commit `8922c5a1a`; therefore the existing
  fixed-risk rows, including `RISK_FIXED > 0` and `RISK_PERCENT = 0`, were
  not altered.

## Append-only compile successors

The batch dry run returned 9 eligible, 0 refused, and 0 pre-existing open
successors. Apply appended the following nine `COMPILE_EA` rows with:

- `no_gate_verdict = true`
- `append_only_source_repair = true`
- `owner_decision_id = OWNER-DEC-HMA-CATA`
- the original OWNER-decision, HMA-census, and fixed-include hash bindings
- the source hash shown above

| EA | New COMPILE_EA successor | Release state at 2026-08-26 02:35Z |
|---|---|---|
| `QM5_2002` | `21b4bb40-6d27-4566-93c7-bc5d6b0549f8` | pending, exact hold released |
| `QM5_9998` | `61146e9b-b981-45e9-96a8-299bb00ace8e` | pending, exact hold released |
| `QM5_10251` | `0c3e48e7-1d23-40a6-b80e-7b93e75e0d6a` | pending, exact hold released |
| `QM5_10593` | `65ee47e4-fad6-4ca6-a905-6f9c1e2d19a4` | pending, exact hold released |
| `QM5_10602` | `f7f45b4f-37d8-4c50-b6ed-b703deae3cb3` | pending, exact hold released |
| `QM5_10833` | `6d5ee415-1787-42d3-9003-971cfbc61920` | pending, exact hold released |
| `QM5_10960` | `4032df46-ca0f-401a-a270-2978f8f7651d` | pending, exact hold released |
| `QM5_12742` | `28d31a7d-5d73-46af-9e66-147fa351746e` | pending, exact hold released |
| `QM5_12958` | `ee61c6d7-f53f-4062-8005-93ae3a41e2ae` | pending, exact hold released |

The source-fresh rollout utility released each exact HMA row through its normal
CAS/ledger path. It created a database backup before every release. The first
and last backups bracket the operation:

- `D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260826T023325Z_d0f38cdd.sqlite`,
  SHA-256 `2e1978865cbaaef282d9e7e0edbacad5cd86aa7a5dfbcfffcf7fefe40d0e94ac`
- `D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260826T023524Z_6bd03d27.sqlite`,
  SHA-256 `a56458de401e004dad05198662ac139e3e078265e0f03a9257bd34e08444c33d`

One unrelated held row, `38660d91-9dc6-4e3d-a71e-0f4369dd12a5`
(`QM5_41011`), was observed and deliberately left untouched.

## Compile and Q02 gate

At the post-release snapshot, all nine successors were pending and unheld:
0 active, 0 `COMPILE_OK`, and 0 new failures. This is an asynchronous
resident-worker queue, so a compile outcome cannot be claimed in this
single-pass task before its evidence exists.

Accordingly, the per-EA exception is the same and explicit: **governed compile
pending, worker not yet claimed**. No new Q02 row is authorized until the
corresponding successor produces evidence-backed `COMPILE_OK`. When that
happens, the `OWNER-DEC-HMA-CATA` new-identity continuation must append the
applicable historical Q02 rows with the current EX5 SHA-256. A compile failure
must remain closed and must not enqueue Q02.

Historical compile/Q rows and verdicts were not updated. No pipeline verdict,
`T_Live`, AutoTrading, terminal process, or active backtest was touched.
