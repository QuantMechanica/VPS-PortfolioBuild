# Q06 stress-path repair and append-only rerun packet — 2026-07-31

Router task: `13c3a60d-e9fc-4c97-962b-eb735b16960b`

Disposition: **IMPLEMENTED; REVIEW REQUIRED**

Pipeline verdict: **none** — builds and queued runs are evidence inputs, not gate verdicts.

## Outcome

- Added the public `qm_rng_seed` and `qm_stress_reject_probability` inputs and passed both through `QM_FrameworkInit` for `QM5_10571`, `QM5_1116`, and `QM5_1551` (`8da56c0d9`). Existing news behavior was retained; the two older call sites use the framework defaults `30 / 30 / 336 / high`, and no stale-news limit exceeds 336 hours.
- Added an idempotent, exact-row, append-only rerun mode to `farmctl enqueue-cascade` (`8e30c2069`). It binds a new row to one historical predecessor, refuses an existing open replacement, and preserves the historical row.
- Rebuilt the requested nine EAs serially through `compile_ea.py --force --json --fail-on-error`. The final attempt for every target compiled with zero errors and zero warnings. Canonical binaries are commit `790a27a40`; the clean detached build provenance commit is `39ba68c6a06b559657aa3df54f2cf62704752623`.
- Enqueued exactly 13 Q05 and 13 Q06 append-only reruns, one CLI invocation per historical row. No wave or manual terminal dispatch was used.
- Prepared the exact 13-row Q06 supersede proposal in [`2026-07-31_q06_stress_supersede_proposal.json`](2026-07-31_q06_stress_supersede_proposal.json). It proposes `PROVENANCE_UNVERIFIED` in the append-only MNT-043/MNT-044 overlay. It did **not** update a raw row, append an overlay event, or grant an admission verdict; Claude review is an explicit apply precondition.

## Source and build evidence

The canonical checkout contained unrelated operator changes before this task. To honor the dirty guard, the build ran from the clean registered detached worktree `C:\QM\worktrees\codex-q06-stress-build-20260731`. The nine exact EX5 blobs were then verified against build commit `39ba68c6a` and committed into the canonical checkout without staging any unrelated path. No `T_Live` path was addressed, `terminal64.exe` was not started manually, and no active test was interrupted.

`QM5_13140` had one wrapper invocation time out at 120 seconds. No output from that attempt was accepted. A serial retry through the same canonical wrapper completed successfully; the table records only the verified final compile.

| EA | MQ5 SHA-256 | EX5 SHA-256 | Bytes | Final compile UTC | Compiler-log SHA-256 |
|---|---|---|---:|---|---|
| QM5_10571 | `a9fa14ca9fff416b82112c6143c7eebc6d34345632f726f8cc1e78bce8932f60` | `c96f56d83ad858d36ea6f3b1b5aa87f6e61c377cead00c265fe8abe05e04b52b` | 359538 | 21:59:02 | `760752a2bd9c94f15485432b5c6c36fefb4649b1643accad7a3696724867becf` |
| QM5_1116 | `9a8695789fbabd39edf0b22aafaae60997a41612d01b078c7e539dc7e9179bd9` | `d1b1d2ebcd07e96b0978ee5ce8c1b40e5db4366920533a56fc681fdfab18c10a` | 353462 | 21:59:26 | `2ee905e77109e036e0aaf5b8fc5d15e9921babeafb7bc3f9b2e1cb63909f68d9` |
| QM5_1551 | `27baf1bac1dd416f2fdedae6424687ac1f0e49b513805ab29c60d15ed878ac89` | `4c371efa7c541a30d76250b6b6fc6ebeabb8c9ae4e36cdca9c2a2d865e84e810` | 356094 | 21:59:50 | `6645ac5a0ece064bb1d90a4479dd6985a10848f96485550b02ba239d605ac094` |
| QM5_1567 | `9cdd879e4987cac3460e03e41a0c4eaae2995aaf998c913e7484f7a906499e52` | `aee0eb60798ef7ada09e49df6e9a339dd8199f810de56dab8a25957cb26fba31` | 348278 | 22:00:17 | `939812ec3b5836e36861309f71b530f9cc6078b6179e597ea0d77e560c16e91e` |
| QM5_13140 | `f654ea2139b17f19714928a839e9bc4d6f9cf62fe0018bdafe34bcce163422f1` | `3ab9d554aa62647d002b3a20cafb9b6f043bc519751e69af3032d6ffc0fbbc77` | 364098 | 22:04:00 | `68250b7bf8a12a5c5637a7006ed6674764f50c06042f519e031954c4fe960f85` |
| QM5_13144 | `9cf9c96c62531234d5057b905dc7e9d0c49abc2bcbae08c22612a2213d14a58a` | `73de7be35f1904c96be3817350c8e9313526f4646cdc2395eb6f1befeb5fe360` | 364992 | 22:04:32 | `4e96e62ef7420ee0d07caa40dc0d165bd7fc37c00d85bb2f6b4e15c5532d2ed1` |
| QM5_13146 | `33e1c71b0b6b4a8bdcdb03e5da0c1fd721f23fdd8e194c2a482e1820dc8111e7` | `cfac88883e802053ac3ca060ab4b5d02d6a320b276c13024cdc317f8a69b38c5` | 364228 | 22:04:56 | `3b292b201e1cd9cf16c8b0f204849cc0481cac164bd0e0b89cbeedc01e04c814` |
| QM5_13147 | `0232625ddcdda5032419299acf5d1098e0c6f72938d622ddd8ba268c194bbe9a` | `2b34fec5f6fc801836de22c461f2b7d36055f3ad1818913c67397e27df093b82` | 369574 | 22:05:21 | `aae8d2a32f92f0e3fe1f1af9d30aca91f71beea905b7b75530671fe879b9f982` |
| QM5_13151 | `62a4e957ef6d4fcd4d4a8830b1ad86bde06dfab4e7ebc3e2c4934ee411202b96` | `7b42fcc4bedb6fec26477dc5db29fc91ce8217da6ced51516fb83d07f0aa9003` | 369624 | 22:06:37 | `6364c647303a6b273cbbf483d03b84d1e42aa699b6684eaa56c75d2df60a252c` |

The retained compiler logs are under `docs/ops/evidence/2026-07-31_q06_stress_repair_compile_logs/`.

## Exact append-only Q05/Q06 queue rows

Each new row has `append_only_rerun=true`, `historical_work_item_preserved=true`, and an exact `append_only_rerun_of_work_item` binding. The online SQLite backup made immediately before enqueue is `D:\QM\strategy_farm\state\backups\farm_state_pre_q06_stress_repair_20260731T220932Z.sqlite`.

| EA / symbol | Historical Q05 | New Q05 | Historical Q06 | New Q06 |
|---|---|---|---|---|
| QM5_10571 / XAUUSD.DWX | `700dd8e0-07fa-411e-9fb5-1a8081ee4aa4` | `cbcaa64a-090e-4e48-80ac-a09dfae138c7` | `42cb13b0-11d3-475f-bc5e-a96cfcd2c8f7` | `c36efc32-ef33-40fb-ad07-78871731978b` |
| QM5_1116 / EURJPY.DWX | `ae2066ab-d7b1-4760-88a0-1a7ff33b0cfb` | `de0b3333-efb0-4ac3-a24b-9e6bad52ebdf` | `70f8df8a-4251-4082-8c8a-374c1947250a` | `f814ba0f-ec03-4baa-be4e-7f1779536f3d` |
| QM5_13140 / ALIQ | `fecdd2a8-4d65-4c3a-b59c-8285545ebbcf` | `5357e929-d368-4d58-880d-5e3289e6152d` | `c2f718c6-7427-427a-84da-9da08e2918e3` | `c31b69ad-fa20-4dd1-8f07-11cbbabefa82` |
| QM5_13144 / MICRO11 | `0dd5d466-aea8-462f-901e-7fda4211fe30` | `7b858d25-b561-4697-9973-26e734d9b674` | `1fcbda55-8565-4718-bb2a-b7dfd7753c3d` | `76e26ada-4bb5-457e-8233-25feaa209982` |
| QM5_13146 / VOV | `aecfcae3-21ae-47c3-8688-27a455c3ce73` | `ee7dca2f-d738-41aa-80d9-2999d01212d4` | `603a318d-cad2-47d5-888b-b767f8536849` | `167a7fd4-0575-41bd-9c86-8d8a4fd00ca5` |
| QM5_13147 / JBETA | `e9fb1153-8d22-441e-8c1b-960cab61a1f7` | `ce699647-2f69-4105-97b6-7a0535b14c69` | `5766463f-f929-46a5-ba8d-3133f7ddd0e8` | `c94c6fda-c669-446d-9b00-2739d2775bf1` |
| QM5_13151 / VBETA | `8991af81-6836-45b3-aa42-4e824c3800a4` | `cb8729a0-63a2-4a2a-a2ad-74896050c35f` | `a61f2775-1ef0-489e-8d63-26d9f7614cfe` | `031a2107-94f9-42b3-b75a-f54e1553f055` |
| QM5_1551 / USDJPY.DWX | `745ea5f3-b45d-4836-933c-eae91266cc94` | `1db27930-da69-4ab2-9d61-719a187fa9e8` | `9f4eaf7c-5af1-4075-ac78-48e97e5c4c13` | `bec90777-8491-4574-9ecb-ce324d22e65c` |
| QM5_1567 / EURGBP.DWX | `09d9d520-2413-41a3-b46e-701fc2ab06f7` | `0ebc2120-97c5-4615-afcd-a13a64364494` | `04fd4814-f1d9-4db5-a529-1faf300e0896` | `a5f6ab9f-75f1-4459-8375-f4e8a627bfd3` |
| QM5_1567 / EURUSD.DWX | `e0b94eb4-6ceb-4e41-b52f-4cc0972200e5` | `91c580a6-bdf0-445c-aea2-13d01148e5a6` | `5299eb44-8e1d-46c8-938c-06d8c1ac5d52` | `0430f87d-bc38-4f79-8a44-d4d04c7d3bc1` |
| QM5_1567 / GBPJPY.DWX | `470b5cb7-32f9-4ff2-98b1-86fc2e73bb1c` | `fa704429-cd42-4704-886f-126068029513` | `747b2cb2-debc-4da9-8f19-4d937c732532` | `40af0543-1fd0-4dae-80e1-531cd49df2a6` |
| QM5_1567 / GBPNZD.DWX | `5bf1dfe0-e9f8-4933-996d-d8fa38db0d68` | `0df3b874-0517-4b72-83b0-5ad63a5efecd` | `c9f74c71-6eed-413c-9bae-116137f7cef0` | `00f37313-423e-4a51-b7e0-d17ec88fe10c` |
| QM5_1567 / USDJPY.DWX | `5b5cc1f0-813c-4123-ba4b-313a8abd585e` | `8f5520af-1b9e-4dc7-870d-1cf5bf823812` | `eeb2da0e-9243-46ff-8c46-8a5ab3bbe5fa` | `4dd0e95f-5338-4b69-b2f2-169411cc6da4` |

At the post-enqueue snapshot (`2026-07-31T22:20:10Z`), the worker had naturally claimed only Q06 row `bec90777-8491-4574-9ecb-ce324d22e65c`; the other 25 rows were pending. This task did not interrupt or manipulate that claim.

## Supersede proposal semantics

The companion JSON is an immutable review packet, not an appender input with authority. It binds all 13 invalid historical Q06 PASS rows to their current raw-row SHA-256, aggregate SHA-256, defect class, and replacement Q06 row. Seven rows are classified `STRESS_INPUT_NOT_EFFECTIVE`; the five energy-basket rows are classified `BASKET_REJECTION_HOOK_MISSING`.

If Claude approves, the applying tool must re-read every raw row and evidence file, verify every listed hash and replacement binding, bind the current overlay tail, append atomically, and abort on any drift. It must never `UPDATE` the historical work-item row. A later rerun result is new evidence and does not retroactively rewrite the raw historical result.

## Focused verification

- `validate_build_guardrails.py` on all nine EA directories: PASS; no finding; maximum `qm_news_stale_max_hours=336`.
- Nine final `compile_ea.py` results: `COMPILED`, zero errors, zero warnings; canonical EX5 hashes match clean build commit `39ba68c6a` and binary commit `790a27a40`.
- `python -m py_compile tools/strategy_farm/farmctl.py`: PASS.
- `pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py`: `21 passed, 4 subtests passed`.
- Post-enqueue database checks: all 26 new rows exist with exact predecessor bindings; all 13 historical Q06 rows remain `done/PASS`; `PRAGMA quick_check=ok`.
- Proposal validation: 13 unique historical IDs, 13 unique replacement IDs, all raw/evidence hashes reproduced, no raw mutation, no overlay append.
- `git diff --check`: PASS.

This packet does not enable `T_Live` or AutoTrading, does not copy a binary to `T_Live`, and does not claim a Q05/Q06 verdict before runner evidence exists.
