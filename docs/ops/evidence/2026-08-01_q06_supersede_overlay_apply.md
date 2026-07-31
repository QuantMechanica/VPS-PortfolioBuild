# Q06 supersede overlay apply — 2026-08-01

Result: **PASS / APPLIED**. Codex applied the exact Claude-approved 13-event Q06 supersede proposal to the MNT-043/MNT-044 append-only adjudication overlay. No `work_items` row was updated.

## Authority and immutable inputs

- Apply router task: `4b64823f-cd32-42f6-908f-9ea1841b4858`.
- Claude authority task: `13c3a60d-e9fc-4c97-962b-eb735b16960b`, state `APPROVED`, `review_close_state=APPROVED`, closed `2026-07-31T22:30:56+00:00`.
- Approved proposal: `docs/ops/evidence/2026-07-31_q06_stress_supersede_proposal.json` at commit `e12753b4dcc1a367f01335b00e1d8f14dc4d8924`.
- Proposal SHA-256: `cdb3472e9a24738c09eb928ebde1b2ea6042f0035e50be2ab5d8a263408a0b27`.
- Apply tool: `tools/strategy_farm/apply_q06_stress_supersede.py`, SHA-256 `0436d70fa196600eb2b96d22719f2ba07505ce81a12424b4725c7b02d564a074`.
- Durable machine receipt: `docs/ops/evidence/2026-08-01_q06_supersede_overlay_apply_receipt.json`, fingerprint `82a5c1c8e21ca1f496cfb81c82be7b03842c9a3678cd92abf25e4f5642efc6e1`.

The dispatch prose says “7x `STRESS_INPUT_NOT_EFFECTIVE` + 5x `BASKET_REJECTION_HOOK_MISSING`” while also requesting all 13 proposal rows. That arithmetic is inconsistent. The exact approved proposal contains **8 + 5 = 13**, and this apply used those exact 13 proposal event IDs without rewriting the proposal.

## Preconditions and publication

Before publication, the tool opened `D:\QM\strategy_farm\state\farm_state.sqlite` with SQLite `mode=ro` and `query_only=ON`, then re-read all 13 historical rows, 13 evidence files, 13 replacement rows, and the Claude authority row. Every historical row remained `done/PASS`; all full-row hashes and evidence hashes matched; all replacements carried `append_only_rerun=true`, `historical_work_item_preserved=true`, and the exact `append_only_rerun_of_work_item` binding.

The approved proposal hashes the complete SQLite row, including `claimed_by`. An initial no-mutation dry run used the narrower MNT scan snapshot and therefore rejected the first row. Before publication, the verifier was corrected and covered by focused tests. Independent read-only comparison then found all 13 approved full-row hashes unchanged in the pre-repair `20260731T220932Z` backup, the post-repair `20260731T223750Z` backup, and the live post-apply database.

The overlay did not exist before apply: event count `0`, byte SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, tail `null`. Under the canonical `.lock` sidecar, Codex built the complete new byte stream in the same directory, content-CAS checked the empty predecessor, and published all 13 records with one atomic rename. The sidecar lock was removed after ownership verification.

After publication:

- Path: `D:\QM\reports\maintenance\mnt_adjudication_overlay.jsonl`
- Events: `13` appended, `13` total
- Bytes: `26676`
- File SHA-256: `f3b3a11877689a4a81848f764f26623c1f778dc615a8e8f1e817a835fde9621c`
- Tail event SHA-256: `0ec0eb5a0c9c1c580b1282eefeef0632c7c08851965ab6f97c4cf75a8555adc6`
- Chain validation: `PASS`
- Historical database mutations: `0`

## Per-row append receipts

Each `event SHA-256` below is also the chain tail after that line. Full event IDs, proposal event IDs, paths, and observed replacement states are retained in the machine receipt.

| Line | Historical work item | Raw row SHA-256 | Evidence SHA-256 | Replacement work item | Replacement row SHA-256 | Defect class | Previous tail | Event SHA-256 / new tail |
|---:|---|---|---|---|---|---|---|---|
| 1 | `747b2cb2-debc-4da9-8f19-4d937c732532` | `8de3908d676a01cb3085e98a871485dfdc033e610cf58cebde49e9b70e10d4b3` | `6758aee37f7dc9db04b419d560069d26eaa99b6639887137efd8c1ee5097dbaf` | `40af0543-1fd0-4dae-80e1-531cd49df2a6` | `545c8e7062867a222a593f717d11f0cf141e3cc6142b0134467c4981a86d871c` | `STRESS_INPUT_NOT_EFFECTIVE` | `null` | `bdd5c4f02ba801d456a3ab0fa46d750e951191b2470e806f215b8c43bdcec5bc` |
| 2 | `603a318d-cad2-47d5-888b-b767f8536849` | `e24f47c4af331aa0c16bca4db9e7c5fa3338aafa337a136c65f36574c67b23b5` | `eb63c76fb8849d269c8590eea4e37291a09956331bed3d1ed0cdd907330740d5` | `167a7fd4-0575-41bd-9c86-8d8a4fd00ca5` | `2431259f85d78aaa2a1a539dba4b2b229ac3d6dc7be3b4edf323d5f80ef533e6` | `BASKET_REJECTION_HOOK_MISSING` | `bdd5c4f02ba801d456a3ab0fa46d750e951191b2470e806f215b8c43bdcec5bc` | `5b841e52be44e72b998901d6368ab15edd367cd3749b14fe17aae94dbe12efdb` |
| 3 | `04fd4814-f1d9-4db5-a529-1faf300e0896` | `148758773a8fec99892513f49d1b42eb6d12e05ff1e674faf030096a67a6bcbb` | `8422673840bd9e749728dfd183c504674a337ab0c0e772cb0520dccf73616d72` | `a5f6ab9f-75f1-4459-8375-f4e8a627bfd3` | `141d2a7a9dd22ff791d6527994b713568aef3ce6f5d17e7d9648ea4af6efb5c2` | `STRESS_INPUT_NOT_EFFECTIVE` | `5b841e52be44e72b998901d6368ab15edd367cd3749b14fe17aae94dbe12efdb` | `959612648a6587961ae4a33729feda35494d57faff958c73ce5efc1aeecaba79` |
| 4 | `9f4eaf7c-5af1-4075-ac78-48e97e5c4c13` | `d8ca99398d1ddb444cf1b5e0fb276a83629fe3d42903eb09cb5d5117ebaec51c` | `f760001aa1a361bcea8e35f212756f092942506edd66dd7d583a775ba8c3058c` | `bec90777-8491-4574-9ecb-ce324d22e65c` | `a1139256e153618619e943f05efb80a98684c713b68e7d1a97ebe8ca2a012cad` | `STRESS_INPUT_NOT_EFFECTIVE` | `959612648a6587961ae4a33729feda35494d57faff958c73ce5efc1aeecaba79` | `16455ab721b2c2ca60b78594a269ff25f7a9e4105403e401781b3622b037a9d6` |
| 5 | `42cb13b0-11d3-475f-bc5e-a96cfcd2c8f7` | `235c931c0e23a33c8507951a7bcb4892d43b954738ea95c40489f0952588c7e8` | `fb9e43358db384186b7b96532965f807a9f12f0464882825e13eb3fbbf883323` | `c36efc32-ef33-40fb-ad07-78871731978b` | `1985fb8a974e4db2d19a1fc3e426d548b4bbf4260a59de2fe56dc459bfec630a` | `STRESS_INPUT_NOT_EFFECTIVE` | `16455ab721b2c2ca60b78594a269ff25f7a9e4105403e401781b3622b037a9d6` | `62eff35d063992ab20d2ffada87d608902949398830ecacf0fd57d81575fcc6a` |
| 6 | `5766463f-f929-46a5-ba8d-3133f7ddd0e8` | `aec4c760804f0df387824108a7f154b66e1cfab9d067d26810aaab7b10316082` | `60dda0710b08764c9b2c903a372fb9aa56f10a4c2a76c94c5f3b2c420772d564` | `c94c6fda-c669-446d-9b00-2739d2775bf1` | `4f3ffef3b6a1553a8fd4917a9d9870618f648c34bab8c034de07af77e7c670e6` | `BASKET_REJECTION_HOOK_MISSING` | `62eff35d063992ab20d2ffada87d608902949398830ecacf0fd57d81575fcc6a` | `58b5a2299b97a2f23cfcf9a745ff19458a5a74f6450cda2eba90360a8fc05359` |
| 7 | `5299eb44-8e1d-46c8-938c-06d8c1ac5d52` | `58d1e316794753c80bc47ace88a8d3e35ab18ccf8e6ae0817bb14ffdc7ca5b41` | `0fc3091a8020b2bdfa4ab295dce7b524b9905855e4a9c9bae27d78db62528523` | `0430f87d-bc38-4f79-8a44-d4d04c7d3bc1` | `f234392cba55b4ef7776f9f95c522719ec9b63f898f5e700992e039a226e7e70` | `STRESS_INPUT_NOT_EFFECTIVE` | `58b5a2299b97a2f23cfcf9a745ff19458a5a74f6450cda2eba90360a8fc05359` | `d90f58c3764d9e1c1e5fa3ac97263e965585f40cec600685dd5d568af596efe3` |
| 8 | `c9f74c71-6eed-413c-9bae-116137f7cef0` | `edcb1a053fb69e03de927c9dda35f62f8b3b7d3834d6f5b21a090d79b59abce7` | `3b91562113d5cd67e65b97ae3d8e0547f9c08185e7b21ca12323a326259fde23` | `00f37313-423e-4a51-b7e0-d17ec88fe10c` | `b7e847deff2206ef04ad98e0bb597bfe9024b3fc3d605cc349e6653c58a1d692` | `STRESS_INPUT_NOT_EFFECTIVE` | `d90f58c3764d9e1c1e5fa3ac97263e965585f40cec600685dd5d568af596efe3` | `9b7225584bb2e3dd12beac1e223d1987a049226ffa1d42bd678e491c0ef575e0` |
| 9 | `70f8df8a-4251-4082-8c8a-374c1947250a` | `bfcd19c47b4c377f90d968854b50a6d3a38a52fe45fd415dfaedab81993f0753` | `9836a3974b4313c4ac6b0009e11afeea944773706075cad3d7e4b7ba199c8507` | `f814ba0f-ec03-4baa-be4e-7f1779536f3d` | `9b7df10eab2d48271e26f32481ea381dde7a7f36435094148644735e29d319d9` | `STRESS_INPUT_NOT_EFFECTIVE` | `9b7225584bb2e3dd12beac1e223d1987a049226ffa1d42bd678e491c0ef575e0` | `cc61d5c57a68afe1c3cf4360af6dc74890815548d2f2c5bbf596bda7bc5e860a` |
| 10 | `1fcbda55-8565-4718-bb2a-b7dfd7753c3d` | `0b4647c773e90986148ea228bf6fbd6d145f575156c14d65339efb6011c2c971` | `4f3ceb40996c9a2cc99d49daa38de142b10e67b6f4c0ff0935c03f246898c1c7` | `76e26ada-4bb5-457e-8233-25feaa209982` | `ef025e910fad0d699b77c960aee29f4c537485e6d8f6ace1871e43b2c27fb574` | `BASKET_REJECTION_HOOK_MISSING` | `cc61d5c57a68afe1c3cf4360af6dc74890815548d2f2c5bbf596bda7bc5e860a` | `4846aff3cd0a185a9d36174bac569e5ab5c54d61066b910f73ecb426cf6bed9a` |
| 11 | `a61f2775-1ef0-489e-8d63-26d9f7614cfe` | `783d5fb4ac7582bdf9beedaf4d098ad3e45e71f84539a75727f0f1861fcc73dc` | `8c2526f05c4ba1baa89366f390d38c9f7f25200b98d0f6124a77239c76e7bbf4` | `031a2107-94f9-42b3-b75a-f54e1553f055` | `cbd8623d9b880fc1b85d3ab48eb1ed9ea424a8665dede063fb7ff0c95c28160b` | `BASKET_REJECTION_HOOK_MISSING` | `4846aff3cd0a185a9d36174bac569e5ab5c54d61066b910f73ecb426cf6bed9a` | `5b8b533055612f69069ad27be2f5c8d5cde958050acb1592c26e9c6e774f566f` |
| 12 | `eeb2da0e-9243-46ff-8c46-8a5ab3bbe5fa` | `cce4cc36346b6959e3c957ee2ff8dba48e9af8071dfb7b00138d1cfc93dc9fe2` | `e511efe6dbbd102a51820c313233f452606e90cde508a353fc9a976c7c2ce0a0` | `4dd0e95f-5338-4b69-b2f2-169411cc6da4` | `f6281cc0f9f8d4c6a5f1917e63e8b80ba6b7bbbe5621ed4c1ba563079f74dc6d` | `STRESS_INPUT_NOT_EFFECTIVE` | `5b8b533055612f69069ad27be2f5c8d5cde958050acb1592c26e9c6e774f566f` | `aff5e55e8a7dc4f98ca6c381be0c99bf605817488d31550e6dd02eb64f5df208` |
| 13 | `c2f718c6-7427-427a-84da-9da08e2918e3` | `33e0075652be10cb1442c12f918b1cd936b05acb9d75fde4f96516f159983f37` | `aacdb05d14fb7796036664f2cc6c51e6ea527e858beaa95181c38b3f7b66a451` | `c31b69ad-fa20-4dd1-8f07-11cbbabefa82` | `2a86a5c45bc250266568aff8ee1a66f8d85339337b951b70ee6c10b1db03ca00` | `BASKET_REJECTION_HOOK_MISSING` | `aff5e55e8a7dc4f98ca6c381be0c99bf605817488d31550e6dd02eb64f5df208` | `0ec0eb5a0c9c1c580b1282eefeef0632c7c08851965ab6f97c4cf75a8555adc6` |

## Verification

- `python -m py_compile tools/strategy_farm/apply_q06_stress_supersede.py tools/strategy_farm/tests/test_apply_q06_stress_supersede.py`: PASS.
- `python -m pytest -q tools/strategy_farm/tests/test_apply_q06_stress_supersede.py tools/strategy_farm/tests/test_mnt_closure_drift.py`: **12 passed**. Coverage includes absent and existing overlay tails, atomic batch publication, byte-exact LF output on Windows, hash-chain verification, create-only receipt, historical-row immutability, evidence-drift fail-closed behavior, and missing-authority rejection.
- Independent post-apply read-only verification: 13/13 overlay events, 13/13 historical full-row hashes, 13/13 `done/PASS` dispositions, 13/13 evidence hashes, and 13/13 replacement full-row hashes plus lineage markers matched. Receipt fingerprint, file byte hash, every predecessor link, and the final tail matched. Sidecar lock absent.

No terminal was launched, no backtest was interrupted, and neither T_Live nor AutoTrading was touched.
