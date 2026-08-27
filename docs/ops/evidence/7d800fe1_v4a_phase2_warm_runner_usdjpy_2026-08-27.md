# V4a Phase 2 — USDJPY warm-runner validation deviation stop

**Verdict:** `DEVIATION_STOP_UNSUPPORTED_BACKEND`
**Execution:** `NO_MT5_LAUNCH`
**Feature flag:** `QM_ENABLE_WARM_CELL_RUNNER` remained globally unset/Default-OFF.

The commissioned reference floor now passes, but the execution precondition does not. The repository still has only an injected resident-session interface used by tests; it has no reviewed backend that can submit a second tester cell to one already-running MT5 session. The governed cold launcher starts one terminal process per cell. Therefore no warm result, parity value, timing value, or speedup claim was fabricated.

## Acceptance result

| Criterion | Result |
|---|---|
| Deterministic oldest complete cohort | PASS — 20 of 100 authenticated receipts selected; selection `863cb4e59aeb8bc578d79aaa5278b4af9c930f61a3e950a143ef8d651e736b7a` |
| 20/20 comparison table with hashes | DEVIATION — 0/20 warm comparisons; all 20 cold hashes are bound below and warm fields are explicitly NOT RUN |
| Warm versus cold timing | DEVIATION — 20-cell cold total 7394.198 s; warm timing and speedup are null |
| Activation checklist | NOT ELIGIBLE — backend, exact-parity, speedup, repeatability, and OWNER-seal gates remain blocked |
| Cold path / DL-089 | PASS — four governed cold-path files match their Phase-2 start bytes; no production claim or DL-089 mutation |

## Deterministic cohort

The read-only snapshot found **100** measured USDJPY rows, all **100** authenticated. Selection is ascending `(updated_at, work_item_id)` after receipt authentication. Common identity exact: **TRUE**. Setfiles are intentionally cell-specific because each arm encodes a different predicate.

| Field | Common value |
|---|---|
| `ea_id` | `QM5_41097` |
| `symbol` | `USDJPY.DWX` |
| `period` | `H1` |
| `model` | `4` |
| `seed` | `None` |
| `from_date` | `2019.01.01` |
| `to_date` | `2019.12.31` |
| `ex5_sha256` | `e077660cc9ac5d74a6edc8896b72249f221fb030279bbd022f7e9d7756bb3a2e` |
| `mq5_sha256` | `8e5cfdbf6f513bdbfd5fdcd25357907cad124497123b8a1abe133c9f2d1d6329` |
| `history_manifest_sha256` | `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06` |

## Timing

Cold elapsed time is measured from each governed receipt's `payload.started_at_iso` to `summary.timestamp_utc`. It includes the existing per-cell startup path and is the relevant cold baseline. No warm elapsed clock exists because the unsupported backend gate stopped execution before launch.

| Path | Cells | Total s | Mean s | Median s | Min s | Max s | Speedup |
|---|---:|---:|---:|---:|---:|---:|---|
| Cold governed receipts | 20 | 7394.198 | 369.71 | 358.684 | 238.565 | 673.957 | baseline |
| Warm resident session | 0 | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT MEASURABLE |

## 20-cell comparison table

| # | Arm | Work item | Cold s | Metrics SHA-256 | Trade-list SHA-256 | Warm | Exact |
|---:|---|---|---:|---|---|---|---|
| 1 | baseline | `356a3655-5f0a-51ea-84f3-a3d04e2ed714` | 238.565 | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` | NOT RUN | NULL |
| 2 | buy_003 | `ccc0055d-046a-5b80-9f3f-7d1ed7392e38` | 516.103 | `c939eac37d0c409bcc2d05396c58f4ba7a54541db5786a0c6014f5f58b6ad9d8` | `69befe7a507a3943d2a75924248a4530cec5076f3e2a4253e9ca93637af17080` | NOT RUN | NULL |
| 3 | buy_004 | `ea962544-3f33-536b-a20e-081e4a7bc5eb` | 272.551 | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` | NOT RUN | NULL |
| 4 | buy_005 | `86ba5c0c-7d44-5461-8b69-c4ca4e68bf0f` | 403.304 | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` | NOT RUN | NULL |
| 5 | buy_006 | `76963c69-9b55-5924-8e92-385705cbb582` | 379.362 | `c5d05a555f5affede5905015bda167a8e2faf7cf7adc09143e0b4aa9e903103d` | `db78ccde49fb8caac3ebd6d1188c1984809c2d8e26febbedff1d04c2d7dcc8b8` | NOT RUN | NULL |
| 6 | buy_007 | `97305edc-622b-5e81-888b-6fbe3c08dbfb` | 298.454 | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` | NOT RUN | NULL |
| 7 | buy_008 | `05fb3d10-950c-51c0-9b18-eaa31acb1e1f` | 279.532 | `950d222ef2fa8a90a44b689fff73730e25519fae78679e0b3d30b68043d195b9` | `435c5436f6c3d24046c3ac1e6830f9f7e9e942e28f6eda11001613235d2588e6` | NOT RUN | NULL |
| 8 | buy_009 | `7b192d77-6305-569a-a034-ff13f54d18a3` | 291.041 | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` | NOT RUN | NULL |
| 9 | buy_010 | `9d29a68a-c2a6-5b8e-828a-541d56626192` | 487.317 | `6cf2a53bfcad6fa23d2155fbc15f20dd0b25a7db884b25295c96d4bc68453f24` | `bbd0c5fb4c27c12248550d10ca562e437db24b9b2209ba48702db7d7e67fa572` | NOT RUN | NULL |
| 10 | buy_011 | `3c7642dc-8046-56d0-b923-3d78adb6bf87` | 264.479 | `a38adb929b3335128837a2b99ecb0cee80abeac236556b2bc6f0082f5b3da7a2` | `151800be34e02c3d55c2039f3a283ce2b62db9c66cb8806c25c30142334d36d8` | NOT RUN | NULL |
| 11 | buy_012 | `e2ddff40-e36a-5e8c-8f14-887fa974e268` | 379.08 | `44720c613e29b790de66cad5b9940c66a310a4fd6259f8f22d49e97b7a1638be` | `df8d8086ab7b35b0c089ab9d7b59e58d60ec75de07f4d7334e4afe3602a0f554` | NOT RUN | NULL |
| 12 | buy_013 | `590b1266-f6c5-5bda-9883-81f6cbd222d5` | 422.656 | `c2c0b4c63fb664659ae226b6b6ea60bc18e69a35bb5b84f51158547989286063` | `166708674db87ac87efca8085cee4dade876257c3f41f91bd6e5251c68bb08f4` | NOT RUN | NULL |
| 13 | buy_014 | `7957f730-ebd5-5433-95a0-5a8ea4324275` | 673.957 | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` | NOT RUN | NULL |
| 14 | buy_015 | `ba0d42dc-9471-5e03-a4e0-fda59ac0d324` | 370.126 | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` | NOT RUN | NULL |
| 15 | buy_016 | `f426ba47-db0b-5060-809d-04907fa93820` | 281.915 | `67001b479b829022cc99a9c11842154547b97b8b38fbe03ff52168440f551e2d` | `5897c1e6ea63eeeffbada377b455ee3e6dcd268d7f5abaea30f9c52e721e360f` | NOT RUN | NULL |
| 16 | buy_017 | `e4533930-dda7-57af-879f-3ecd94efd6e6` | 252.569 | `e7436c51311ba53b064069db0f87395e94785ed12100cded4b02337606903a36` | `5a3d3bfef8a9c2c04af9609934ba3daabb8b79498e49def6a1c3e60f05d8eb5d` | NOT RUN | NULL |
| 17 | buy_018 | `2f02b9e6-f2db-5077-b477-83312244f011` | 263.652 | `2e308f588d24f1b54bc96a9aefc7b43f4cd9fb788018254a226252666e0cce47` | `bb3cba89327b6883f32a4f972fbc06b4e17e561d9d16d8311efb1b8393fb0e26` | NOT RUN | NULL |
| 18 | buy_019 | `85ce2003-8d1a-58c3-baf3-52386ad6ad27` | 596.262 | `174682be19ada36eb090bbd14b81fa6afa61b1409afaf295e0446a19fc27be16` | `c7032dce9c15eb8c780cea805373a4e1c557d45048bbf57a05f37dd492a0e47d` | NOT RUN | NULL |
| 19 | buy_020 | `b1e6dd54-edc1-5ef1-9f39-dc5e28db2e81` | 347.243 | `58c401cfaf6521a36198eef74d6344a8dd65794bde7a3e44ec16f697f87340e5` | `7dd7b691e34dbfb2ee5dd9ff2238113102ccce1468a6a632ddcf3220142e41dd` | NOT RUN | NULL |
| 20 | buy_021 | `07a2e28a-a1fd-598b-9df1-e7e36dd08d4d` | 376.03 | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` | NOT RUN | NULL |

## Why the warm launch is not valid yet

`warm_cell_runner.py` defines sequencing, authorization, exact comparison, and immediate deviation stop around an injected backend. It deliberately contains no MetaTrader launcher. The governed `run_smoke.ps1` writes `ShutdownTerminal=1` and starts `/portable /config:<ini>` for every test. A second startup invocation is not resident next-cell control, and `-AllowRunningTerminal` also bypasses the fresh logger-authentication path.

The only supported MT5 multi-pass mechanism found is native optimization. The V4b feasibility packet already proved its standard pass report lacks the per-pass closed-trade list, entry-day evidence, logger sample, and native report bytes required for field-for-field cold receipt parity. It cannot be substituted silently.

## Activation checklist

| Gate | Status | Evidence / next condition |
|---|---|---|
| supported resident tester-control backend reviewed | **BLOCKED** | Only an injected Protocol/fake backend exists; no governed next-cell implementation exists. |
| 20 oldest complete homogeneous cold references | **PASS** | 20 selected; selection SHA-256 is bound in this packet. |
| 20/20 field- and trade-byte exact warm parity | **BLOCKED** | 0 warm cells were launched; equality is null, not assumed. |
| measured warm-versus-cold speedup | **BLOCKED** | Cold timing is measured for 20 cells; warm timing is null. |
| repeat complete warm batch deterministically | **BLOCKED** | Requires the same reviewed backend after first-batch exact parity. |
| OWNER activation seal binding backend and parity packet | **BLOCKED** | Not eligible until parity and speedup gates pass. |
| production remains Default-OFF | **PASS** | No production wiring, claims, queue writes, terminal launch, T_Live, or AutoTrading change. |

## Cold-path identity

| File | Workspace SHA-256 | Phase-2 start SHA-256 | Exact |
|---|---|---|---|
| `tools/strategy_farm/terminal_worker.py` | `78d98a793f501bd833d98a912a7d4f8395fd8830d3f2ed6a389a8920b93144bb` | `78d98a793f501bd833d98a912a7d4f8395fd8830d3f2ed6a389a8920b93144bb` | TRUE |
| `framework/scripts/run_smoke.ps1` | `750478498f9280b61d2cb02ba1ee03a52b54bb448461b2d3d3cc246af411cf4a` | `750478498f9280b61d2cb02ba1ee03a52b54bb448461b2d3d3cc246af411cf4a` | TRUE |
| `tools/strategy_farm/opt_census.py` | `1c23cf9cf399902bff07fcbd1e02e104c0c5f09c8ec16d990a89c681f6f18f9a` | `1c23cf9cf399902bff07fcbd1e02e104c0c5f09c8ec16d990a89c681f6f18f9a` | TRUE |
| `tools/strategy_farm/dl089_matrix_service.py` | `30e3929f3408b801fc47c93f68adcc288f1e418b8ed7d8fe3e707ecaaebf8bb7` | `30e3929f3408b801fc47c93f68adcc288f1e418b8ed7d8fe3e707ecaaebf8bb7` | TRUE |

## Safety record

- The farm database was opened with SQLite URI `mode=ro` and `PRAGMA query_only=ON`.
- No terminal, tester, worker, production claim, queue row, verdict, policy file, DL-089 receipt, T_Live, or AutoTrading state was changed.
- This is a deviation packet, not pipeline evidence and not an activation authorization.
