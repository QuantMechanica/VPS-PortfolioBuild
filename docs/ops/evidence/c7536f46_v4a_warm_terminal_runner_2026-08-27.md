# V4a warm-terminal cell runner — fail-closed deviation

**Verdict:** `DEVIATION_STOP`
**Execution:** `NO_MT5_LAUNCH`
**Feature flag:** `QM_ENABLE_WARM_CELL_RUNNER` is Default-OFF and is not wired into the production worker.

The reusable single-session orchestration and exact-parity validator were built and unit-tested behind the flag. The commissioned warm replay was not started: the governed MT5 command surface only consumes tester configuration at process startup, and the existing cold runner starts a new terminal process for every test. No supported command was found that submits the next cell to an already-running tester. Treating a second `/config` launch or `-AllowRunningTerminal` as that command would be unsafe and would also skip fresh logger authentication.

## Acceptance result

| Criterion | Result |
|---|---|
| Default-OFF; cold path byte-identical | PASS — flag absence selects `COLD_PATH_UNCHANGED`; all four governed cold-path files retain their exact task-start bytes and have no tracked diff |
| ≥20 exact cold/warm comparisons or deviation | DEVIATION — 15 authenticated cold references available; 0 warm cells launched; no equality claim made |
| Runner and flag tests | PASS — fake resident backend proves one-session sequencing, exact comparison, immediate mismatch stop, activation refusal, and Default-OFF no-op |
| Evidence and activation checklist | PASS — JSON reference packet, CSV deviation table, this report, and explicit checklist |

## Why execution stopped

The platform-start interface is a startup configuration contract. The current `run_smoke.ps1` writes `ShutdownTerminal=1` and its `Start-TesterRun` function calls `Start-Process` with `/portable /config:<ini>` for each test. `-AllowRunningTerminal` only bypasses exclusivity/logger checks; it does not provide a resident next-cell IPC.

The official [platform-start documentation](https://www.metatrader5.com/en/terminal/help/start_advanced/start) describes `/config` as startup configuration, states that two copies cannot run from one directory, and documents `ShutdownTerminal` after testing. No supported resident sequential-test command is documented there. A native optimizer is the supported multi-pass path, but the separate V4b preflight found that its standard pass evidence cannot reproduce the current receipt contract field-for-field.

At snapshot time the read-only farm query found **15** authenticated GBPUSD 2019 cold references (minimum **20**). Thus the reference floor is independently short even before the missing warm backend is considered.

## Cold reference inventory

| Arm | Work item | Trades | Metrics SHA-256 | Trade-list SHA-256 | Warm result |
|---|---|---:|---|---|---|
| baseline | `066dd96a-0c3e-5626-a66f-8ad8799350a6` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_003 | `8d194d9c-bb08-5031-80e2-d429a61c2aab` | 36 | `b5ba8ec2fdace12b6ec5cc6cad156598d548d0fc3ecdd24d0c48b97e31890398` | `4afe6ad2da0a39ca51a6e5e135bd93cdc8a26eab122e5f538b4add4f50b272f9` | NOT RUN |
| buy_004 | `9d161246-0574-5a26-ab72-86bdb8ac3582` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_005 | `f120c2d0-1b16-53a1-b918-a955b77833bf` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_006 | `6365a3b6-d13b-503d-990d-c4cb31fa068b` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_007 | `1a16307c-36a4-5d05-b484-15c2f9116606` | 36 | `29ab35e956fcde45204e7bf3688376cff4bba8f61b5f578c95b448d952de6371` | `473e29d6b7daabec15a242518737c9121e6c79644c41126e9eae3d27cd8b835c` | NOT RUN |
| buy_009 | `b1acc034-8ad9-59e8-92c5-c425452e237f` | 36 | `29ab35e956fcde45204e7bf3688376cff4bba8f61b5f578c95b448d952de6371` | `473e29d6b7daabec15a242518737c9121e6c79644c41126e9eae3d27cd8b835c` | NOT RUN |
| buy_010 | `eacc979d-7bd5-5462-9c7f-2e8d46fb10b5` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_011 | `7b8cb5e1-c09e-539e-95d9-658486994b86` | 35 | `d517928934127c078444f5c48910335319b79128875b1df0b1fb3372e554faa6` | `999c218c63f87456e118df3f8be599db38a227bc80f1e64d3c3e29d1287a7590` | NOT RUN |
| buy_008 | `17d4019b-8a0f-5003-a8b0-3f0bcdb0e81c` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_012 | `4258459d-f38e-566c-b2d8-28b652a19e54` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_013 | `05b4a11a-af8f-5504-a5e1-5ef3f1b92649` | 33 | `ce44339eb44c7dd0e6f377d2609e82dcba4441a3a681a5704cc16bc9e3223dd2` | `9e5c092d473c257131d2d3b96d32ea787846412cb9ce0f0cf9fb8d4be594490f` | NOT RUN |
| buy_014 | `a72f0c0b-4145-518b-8919-8569c9edfcb9` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_015 | `54f1bf75-3908-5fa1-8205-6ba037d52d3d` | 37 | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` | NOT RUN |
| buy_016 | `45b66685-6327-5766-aa41-b580856379e9` | 37 | `f34a3883c94a1e69a9826909ccda6a64f674f9ce9df839b736b2a0e200077c5c` | `dfefc18564fb858c6318339b2f353e9acf94aa71f1408d89171bfac25e4ab2bd` | NOT RUN |

The JSON packet retains the canonical cold trade rows and report fields, so a later authorized backend can compare the exact bytes rather than reconstructed aggregates.

## Cold-path identity

| File | Workspace SHA-256 | Task-start SHA-256 | Exact |
|---|---|---|---|
| `tools/strategy_farm/terminal_worker.py` | `60b80ed28ea1866719fdd75d86f6c48b5560fc7c2ad4eacb7a750cbaf8ea0039` | `60b80ed28ea1866719fdd75d86f6c48b5560fc7c2ad4eacb7a750cbaf8ea0039` | TRUE |
| `framework/scripts/run_smoke.ps1` | `750478498f9280b61d2cb02ba1ee03a52b54bb448461b2d3d3cc246af411cf4a` | `750478498f9280b61d2cb02ba1ee03a52b54bb448461b2d3d3cc246af411cf4a` | TRUE |
| `tools/strategy_farm/opt_census.py` | `1c23cf9cf399902bff07fcbd1e02e104c0c5f09c8ec16d990a89c681f6f18f9a` | `1c23cf9cf399902bff07fcbd1e02e104c0c5f09c8ec16d990a89c681f6f18f9a` | TRUE |
| `tools/strategy_farm/dl089_matrix_service.py` | `14d5c0ff11cd65846bd59436a1ab40e3375e154e553c4368b21ebe0c91a51a0c` | `14d5c0ff11cd65846bd59436a1ab40e3375e154e553c4368b21ebe0c91a51a0c` | TRUE |

## Activation checklist

1. OWNER approves a supported resident tester-control backend; startup config replay is not treated as resident control.
2. Use only a fresh disposable portable profile with isolated agent ports/cache, or a governed idle slot; never an active T1-T10 terminal.
3. Inventory at least 20 authenticated cold cells with identical EA, symbol, history, model, window, setfile and seed bindings.
4. Run all reference cells in one resident session and stop on the first identity, report-field or canonical trade-byte deviation.
5. Repeat the complete warm batch to prove deterministic receipts and unchanged append-only evidence schema.
6. Create an OWNER-approved qm.warm-cell-activation/v1 seal binding the parity packet hash and reviewed backend.
7. Wire the flag only in a separate reviewed restart window; leave it unset by default and never enable AutoTrading or T_Live.
8. Rollback by unsetting the flag and using the governed restart procedure after active tests finish; never start terminal64.exe manually.

## Safety record

- Farm database opened with SQLite URI `mode=ro` and `PRAGMA query_only=ON`; no queue, verdict, gate, DL-089, worker, or receipt was changed.
- No terminal process was launched; T1-T10, T_Live and AutoTrading were untouched.
- The module contains no MetaTrader launcher and production wiring is absent. An exact disposable-validation authorization is required for parity work; later production use additionally requires the OWNER activation seal.
