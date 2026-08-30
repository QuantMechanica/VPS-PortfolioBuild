# Q09 eight-pair deterministic requalification manifest

Date: 2026-08-30T07:18:43+00:00

Router task: `8709bc0f-e0cf-4117-bb73-a6b399e5e612`

OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`

## Verdict

`MANIFEST_READY_FOR_ORCHESTRATOR_REVIEW`. The mechanical rule yields exactly eight `NEW_IDENTITY_FROM_Q02` rows and zero same-identity rows. QM5_41215 through QM5_41222 are reservations only: no EA was compiled, no Q02 row was seeded, and all eight holds remain active.

## Mechanical rule

action=NEW_IDENTITY_FROM_Q02 iff current MQ5/setfile/include-closure bytes differ from the evidence-bound vintage of the pair's last authentic gate, or the bound evidence file/vintage is missing; otherwise SAME_IDENTITY_APPEND_ONLY.

newest done work item of the pair whose MQ5/EX5/setfile hashes verify against current or archived bindings and whose gate contract has a v4 equivalence.

Machine-readable manifest: `docs\ops\evidence\2026-08-30_8709bc0f_q09_requal8_manifest.json`

Manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`

## Exact eight-row manifest

| Held work item | Pair | Authentic anchor (stored -> v4) | Comparison MQ5 / EX5 / set / closure | Action | Reserved identity / magic | Successor |
|---|---|---|---|---|---|---|
| `aa80274f-fb46-4432-b47e-6fb2bf28c9a2` | QM5_13128 / NDX.DWX | `7adc5872-626c-4340-9ed5-1f1682c4e332` (Q09 v4 -> Q09) | MATCH / MATCH / MISMATCH / UNBOUND_AT_ANCHOR | `NEW_IDENTITY_FROM_Q02` | QM5_41215 / `pre-fomc-drift-ndx-requal8` / `412150000` slot 0 | Q02 |
| `1cff016c-d25c-4723-a892-6bc53bfafa0b` | QM5_12989 / XAUUSD.DWX | `543c693f-867d-40af-b07f-35d501e46485` (Q09 v4 -> Q09) | MATCH / MATCH / MISMATCH / UNBOUND_AT_ANCHOR | `NEW_IDENTITY_FROM_Q02` | QM5_41216 / `grimes-nested-pb-v2-requal8` / `412160000` slot 0 | Q02 |
| `57d8bacd-2805-45a6-ac51-156e22bb3a65` | QM5_10815 / GDAXI.DWX | `c7845c62-6c35-49eb-8e9f-056af2c6c14e` (Q09 v4 -> Q09) | MATCH / MATCH / MISMATCH / UNBOUND_AT_ANCHOR | `NEW_IDENTITY_FROM_Q02` | QM5_41217 / `tv-post-vwap-requal8` / `412170000` slot 0 | Q02 |
| `2604a1f0-4f58-4597-89ef-432af9093131` | QM5_1567 / EURUSD.DWX | `e460e02b-e940-49fa-ace0-e2b9c853e7d6` (Q02 legacy -> Q02) | MISMATCH / MATCH / MISMATCH / UNBOUND_AT_ANCHOR | `NEW_IDENTITY_FROM_Q02` | QM5_41218 / `demark-td-reverse-sequential-h4-requal8` / `412180000` slot 0 | Q02 |
| `7bbeef66-becf-4bd3-aa5c-1d00bde262d8` | QM5_12567 / XAUUSD.DWX | `8f43a2f8-d0be-472f-87ca-c2fd628136e4` (Q09 v4 -> Q09) | MATCH / MATCH / MISMATCH / UNBOUND_AT_ANCHOR | `NEW_IDENTITY_FROM_Q02` | QM5_41219 / `cum-rsi2-commodity-requal8` / `412190000` slot 0 | Q02 |
| `9639a773-b913-40a2-b12f-128a027aec98` | QM5_10939 / GBPUSD.DWX | `bae5710a-c610-474d-b885-3f9989f0d99a` (Q09 v4 -> Q09) | MATCH / MATCH / MISMATCH / UNBOUND_AT_ANCHOR | `NEW_IDENTITY_FROM_Q02` | QM5_41220 / `grimes-context-pb-requal8` / `412200000` slot 0 | Q02 |
| `30584122-b7b3-41eb-8e1a-b03517554d4d` | QM5_11421 / EURUSD.DWX | `a2b39c48-4845-4b49-9e84-9e88616a5862` (Q09 v4 -> Q09) | MATCH / MATCH / MISMATCH / UNBOUND_AT_ANCHOR | `NEW_IDENTITY_FROM_Q02` | QM5_41221 / `ohlc-daily-squeeze-reversal-d1-requal8` / `412210000` slot 0 | Q02 |
| `08fe4173-07d9-47e1-97e9-a76b1159ad94` | QM5_11476 / USDJPY.DWX | `fae2b8eb-db7b-4f59-86ec-ca917b270d3f` (Q09 v4 -> Q09) | MATCH / MATCH / MISMATCH / UNBOUND_AT_ANCHOR | `NEW_IDENTITY_FROM_Q02` | QM5_41222 / `lien-k-double-bb-trend-h1-requal8` / `412220000` slot 0 | Q02 |

## Per-row hash evidence

### 1. QM5_13128 / NDX.DWX -> QM5_41215

- Held row: `aa80274f-fb46-4432-b47e-6fb2bf28c9a2`; state `pending` / `Q09_AWAITING_SEALED_PLAN`.
- Anchor: `7adc5872-626c-4340-9ed5-1f1682c4e332`; Q09 `v4` -> Q09; evidence `D:\QM\reports\work_items\7adc5872-626c-4340-9ed5-1f1682c4e332\QM5_13128\Q09\NDX_DWX\aggregate.json` SHA-256 `d0e25f07d2d98d89fa4aa8fb1a7ef58250892e89fa2410c8867791a4bef63808`.
- Anchor hashes: MQ5 `e2bd93a2a66700763997af1e8a9713e40ae76e31916b86d941ae08f495e3fb19`; EX5 `59b9d1657fb04a9f33a030d420da76a1cae92c4223f4404842a53feed1848370`; setfile `48b1efc4a209217cce2628709361eb59680684af8143d125d71008fc3df682c7`; include closure `UNBOUND`.
- Current hashes: MQ5 `e2bd93a2a66700763997af1e8a9713e40ae76e31916b86d941ae08f495e3fb19`; EX5 `59b9d1657fb04a9f33a030d420da76a1cae92c4223f4404842a53feed1848370`; setfile `6bf3e6337c54143ebcb0e727cc9409a7eaf1bc9409f6ef1ec78581e1192ddbaf`; recursive include closure `04e4f3092037df7f33604c0d42c024af977b4b80eef88c747c15e1b75ec1af48` (31 members).
- Mechanical result: `NEW_IDENTITY_FROM_Q02` because setfile, include_closure is not `MATCH`.
- Reservation: `QM5_41215` / `pre-fomc-drift-ndx-requal8`; active magic row `{'ea_id': '41215', 'ea_slug': 'pre-fomc-drift-ndx-requal8', 'symbol_slot': '0', 'symbol': 'NDX.DWX', 'magic': '412150000', 'reserved_at': '2026-08-30', 'reserved_by': 'Codex governed allocator', 'status': 'active'}`; recovery card `D:\QM\strategy_farm\artifacts\cards_review\QM5_41215_pre-fomc-drift-ndx-requal8.md` SHA-256 `523a4cc0775e2e4a8c6fdcc526d1d0b59120f4c1205f396fec40580e916f795b`.
- Successor/enqueue contract (not executed): `python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_QM5_41215> --phase Q02`. Preconditions: governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded.
- Hold release note (not applied): OWNER-DEC-Q09HOLD-REQUAL-8-20260829; release only after Orchestrator approves manifest SHA-256, QM5_41215 is built and Codex-reviewed, and one append-only Q02 seed for NDX.DWX is verified from anchor 7adc5872-626c-4340-9ed5-1f1682c4e332; preserve historical rows.

### 2. QM5_12989 / XAUUSD.DWX -> QM5_41216

- Held row: `1cff016c-d25c-4723-a892-6bc53bfafa0b`; state `pending` / `Q09_AWAITING_SEALED_PLAN`.
- Anchor: `543c693f-867d-40af-b07f-35d501e46485`; Q09 `v4` -> Q09; evidence `D:\QM\reports\work_items\543c693f-867d-40af-b07f-35d501e46485\QM5_12989\Q09\XAUUSD_DWX\aggregate.json` SHA-256 `c3d66763cc791f4c1676520f0687b445cf3991dfc2613f7a62ef1072d641717b`.
- Anchor hashes: MQ5 `0beecb7626056612c05153549529be73bc7bac37f84b1d54b076cbe326d006f3`; EX5 `77d3c5fda5ef2dfd0c138e6520f76d450a04fe812fcefabac07e2673fcd2e425`; setfile `6ae10f3a0f7a29d0ef0f4f7ac7a23c3dda7c9e19ff60796adc8439edd43e4dbc`; include closure `UNBOUND`.
- Current hashes: MQ5 `0beecb7626056612c05153549529be73bc7bac37f84b1d54b076cbe326d006f3`; EX5 `77d3c5fda5ef2dfd0c138e6520f76d450a04fe812fcefabac07e2673fcd2e425`; setfile `d409d8b75d1c3efd7f30fb56ec26c19b142c410cb15b339fab67afc290eba152`; recursive include closure `665bcb50887a8739fc6f625121bd4bae719365a2492b624b04e6588f9fba2356` (31 members).
- Mechanical result: `NEW_IDENTITY_FROM_Q02` because setfile, include_closure is not `MATCH`.
- Reservation: `QM5_41216` / `grimes-nested-pb-v2-requal8`; active magic row `{'ea_id': '41216', 'ea_slug': 'grimes-nested-pb-v2-requal8', 'symbol_slot': '0', 'symbol': 'XAUUSD.DWX', 'magic': '412160000', 'reserved_at': '2026-08-30', 'reserved_by': 'Codex governed allocator', 'status': 'active'}`; recovery card `D:\QM\strategy_farm\artifacts\cards_review\QM5_41216_grimes-nested-pb-v2-requal8.md` SHA-256 `5b24d88f7af51ef583fb6f7e7cc12ce5a1c449c91915bff651e519b5513cafa9`.
- Successor/enqueue contract (not executed): `python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_QM5_41216> --phase Q02`. Preconditions: governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded.
- Hold release note (not applied): OWNER-DEC-Q09HOLD-REQUAL-8-20260829; release only after Orchestrator approves manifest SHA-256, QM5_41216 is built and Codex-reviewed, and one append-only Q02 seed for XAUUSD.DWX is verified from anchor 543c693f-867d-40af-b07f-35d501e46485; preserve historical rows.

### 3. QM5_10815 / GDAXI.DWX -> QM5_41217

- Held row: `57d8bacd-2805-45a6-ac51-156e22bb3a65`; state `pending` / `Q09_AWAITING_SEALED_PLAN`.
- Anchor: `c7845c62-6c35-49eb-8e9f-056af2c6c14e`; Q09 `v4` -> Q09; evidence `D:\QM\reports\work_items\c7845c62-6c35-49eb-8e9f-056af2c6c14e\QM5_10815\Q09\GDAXI_DWX\aggregate.json` SHA-256 `b0a5eaae0f1455101a2ae1ffeeff729b0c9d619b9b496a914b896fe6cfc5944a`.
- Anchor hashes: MQ5 `cdbf22e77035d7ef3e30deb05d171c4c265d14cd3aec9e78c3d817d078c345dd`; EX5 `af1b535b3cd6e8f8ff6c0a5d54933e58e2f391fa007b6811b897d76ba9631bba`; setfile `11dea3699d9b9af224cd807a21ad39cd3fffb1439a2d854cb0cbfa959cdc5af3`; include closure `UNBOUND`.
- Current hashes: MQ5 `cdbf22e77035d7ef3e30deb05d171c4c265d14cd3aec9e78c3d817d078c345dd`; EX5 `af1b535b3cd6e8f8ff6c0a5d54933e58e2f391fa007b6811b897d76ba9631bba`; setfile `01a4f1dc97a83cfdbfbb0d6e73f21af95f28e6a5776d4caeda7f62a2b6c3a024`; recursive include closure `5ef7dd7c8fbd94f0633c66e25a313b7357b51c2b17a53b016cb83ae5497cd6f1` (31 members).
- Mechanical result: `NEW_IDENTITY_FROM_Q02` because setfile, include_closure is not `MATCH`.
- Reservation: `QM5_41217` / `tv-post-vwap-requal8`; active magic row `{'ea_id': '41217', 'ea_slug': 'tv-post-vwap-requal8', 'symbol_slot': '0', 'symbol': 'GDAXI.DWX', 'magic': '412170000', 'reserved_at': '2026-08-30', 'reserved_by': 'Codex governed allocator', 'status': 'active'}`; recovery card `D:\QM\strategy_farm\artifacts\cards_review\QM5_41217_tv-post-vwap-requal8.md` SHA-256 `69a221c48e3d43dbe40aa3aede0701a574a7144063290493bf15064a674cf611`.
- Successor/enqueue contract (not executed): `python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_QM5_41217> --phase Q02`. Preconditions: governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded.
- Hold release note (not applied): OWNER-DEC-Q09HOLD-REQUAL-8-20260829; release only after Orchestrator approves manifest SHA-256, QM5_41217 is built and Codex-reviewed, and one append-only Q02 seed for GDAXI.DWX is verified from anchor c7845c62-6c35-49eb-8e9f-056af2c6c14e; preserve historical rows.

### 4. QM5_1567 / EURUSD.DWX -> QM5_41218

- Held row: `2604a1f0-4f58-4597-89ef-432af9093131`; state `pending` / `Q09_AWAITING_SEALED_PLAN`.
- Anchor: `e460e02b-e940-49fa-ace0-e2b9c853e7d6`; Q02 `legacy` -> Q02; evidence `D:\QM\reports\work_items\e460e02b-e940-49fa-ace0-e2b9c853e7d6\QM5_1567\20260805_191338\summary.json` SHA-256 `ca7d6e3f47915e2fe96287703e695132ce96d9cfe941177c0aa85f839b7e80ec`.
- Anchor hashes: MQ5 `685af902fd614945f15df604810f52b561d6dd3c0d155166b09dde9126da0f27`; EX5 `aee0eb60798ef7ada09e49df6e9a339dd8199f810de56dab8a25957cb26fba31`; setfile `1282e2adba701ee17f39184da9bf6ed5d6e3c48f6a401ca768eb085ada9c9e64`; include closure `UNBOUND`.
- Current hashes: MQ5 `a9531d333dbbe067270811e696e235483d12d2604e86c974feea411066649f8c`; EX5 `aee0eb60798ef7ada09e49df6e9a339dd8199f810de56dab8a25957cb26fba31`; setfile `2e9347a132ed89218a293d03e1b6eb10abce2a74bec50190aa4c6039754fba58`; recursive include closure `66f3c0cc9736b04c0239e2f39bade3750e5179095f5559d9c3b3d171b793c719` (31 members).
- Mechanical result: `NEW_IDENTITY_FROM_Q02` because mq5, setfile, include_closure is not `MATCH`.
- Reservation: `QM5_41218` / `demark-td-reverse-sequential-h4-requal8`; active magic row `{'ea_id': '41218', 'ea_slug': 'demark-td-reverse-sequential-h4-requal8', 'symbol_slot': '0', 'symbol': 'EURUSD.DWX', 'magic': '412180000', 'reserved_at': '2026-08-30', 'reserved_by': 'Codex governed allocator', 'status': 'active'}`; recovery card `D:\QM\strategy_farm\artifacts\cards_review\QM5_41218_demark-td-reverse-sequential-h4-requal8.md` SHA-256 `5d5b5b902e98c8030a0b8432020f4a06e6d7f62bc80bc817b446bdf8b7d666bb`.
- Successor/enqueue contract (not executed): `python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_QM5_41218> --phase Q02`. Preconditions: governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded.
- Hold release note (not applied): OWNER-DEC-Q09HOLD-REQUAL-8-20260829; release only after Orchestrator approves manifest SHA-256, QM5_41218 is built and Codex-reviewed, and one append-only Q02 seed for EURUSD.DWX is verified from anchor e460e02b-e940-49fa-ace0-e2b9c853e7d6; preserve historical rows.

### 5. QM5_12567 / XAUUSD.DWX -> QM5_41219

- Held row: `7bbeef66-becf-4bd3-aa5c-1d00bde262d8`; state `pending` / `Q09_AWAITING_SEALED_PLAN`.
- Anchor: `8f43a2f8-d0be-472f-87ca-c2fd628136e4`; Q09 `v4` -> Q09; evidence `D:\QM\reports\work_items\8f43a2f8-d0be-472f-87ca-c2fd628136e4\QM5_12567\Q09\XAUUSD_DWX\aggregate.json` SHA-256 `b08dd4e4cecb1f3cb66b3f1011dc946dc3430989d2ba012471b0aa308d7d1318`.
- Anchor hashes: MQ5 `8a5dc80942f867936ab18f6b98243437761aba55330024b18e5a050757ad60fc`; EX5 `8d901924fe7dd2cd00c61dac6db78871fdfe34f73e0f003393196992d5143e04`; setfile `433d823ff97c1657913c340be17aaf81c5f5c2efbc87efba31bb15fdd2253363`; include closure `UNBOUND`.
- Current hashes: MQ5 `8a5dc80942f867936ab18f6b98243437761aba55330024b18e5a050757ad60fc`; EX5 `8d901924fe7dd2cd00c61dac6db78871fdfe34f73e0f003393196992d5143e04`; setfile `12c1dfe5d4e743cda2fd102a5b3baa9e5691781ea2f65e433a4273e9d8fef943`; recursive include closure `a824f1e4dbbe900657a186fec4aef71b04ff44813fe84370e04d32566dce4a9d` (31 members).
- Mechanical result: `NEW_IDENTITY_FROM_Q02` because setfile, include_closure is not `MATCH`.
- Reservation: `QM5_41219` / `cum-rsi2-commodity-requal8`; active magic row `{'ea_id': '41219', 'ea_slug': 'cum-rsi2-commodity-requal8', 'symbol_slot': '0', 'symbol': 'XAUUSD.DWX', 'magic': '412190000', 'reserved_at': '2026-08-30', 'reserved_by': 'Codex governed allocator', 'status': 'active'}`; recovery card `D:\QM\strategy_farm\artifacts\cards_review\QM5_41219_cum-rsi2-commodity-requal8.md` SHA-256 `af36edefbf33f5269da134ebd3c31de238fc0e928a67dbc26ed3ab0a2d126aba`.
- Successor/enqueue contract (not executed): `python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_QM5_41219> --phase Q02`. Preconditions: governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded.
- Hold release note (not applied): OWNER-DEC-Q09HOLD-REQUAL-8-20260829; release only after Orchestrator approves manifest SHA-256, QM5_41219 is built and Codex-reviewed, and one append-only Q02 seed for XAUUSD.DWX is verified from anchor 8f43a2f8-d0be-472f-87ca-c2fd628136e4; preserve historical rows.

### 6. QM5_10939 / GBPUSD.DWX -> QM5_41220

- Held row: `9639a773-b913-40a2-b12f-128a027aec98`; state `pending` / `Q09_AWAITING_SEALED_PLAN`.
- Anchor: `bae5710a-c610-474d-b885-3f9989f0d99a`; Q09 `v4` -> Q09; evidence `D:\QM\reports\work_items\bae5710a-c610-474d-b885-3f9989f0d99a\QM5_10939\Q09\GBPUSD_DWX\aggregate.json` SHA-256 `209c66ae55281e95625cfdc10dc76a51db1b38e1ce905ab343d613759556a1e8`.
- Anchor hashes: MQ5 `619331975f50ef4a4c0a97b7feaa091d9d37a311502390387ea3a90441fdead9`; EX5 `812fc52a90f0dba0282aa2fecb3a0b3640c18386ac3e2ab7e3b80765a3970278`; setfile `2ea0ae8c38553be0e12481ea795ebb82c17bf381d3f7cc9839f183678b7b2357`; include closure `UNBOUND`.
- Current hashes: MQ5 `619331975f50ef4a4c0a97b7feaa091d9d37a311502390387ea3a90441fdead9`; EX5 `812fc52a90f0dba0282aa2fecb3a0b3640c18386ac3e2ab7e3b80765a3970278`; setfile `dc7c216b85598642b35cff10f52cd84dedb3ac069dc3a41695176e9362a9acba`; recursive include closure `9022c92a4d980cd0e5616bcf8749ae38a17b10c98a4041fcb653c27a8743b36a` (31 members).
- Mechanical result: `NEW_IDENTITY_FROM_Q02` because setfile, include_closure is not `MATCH`.
- Reservation: `QM5_41220` / `grimes-context-pb-requal8`; active magic row `{'ea_id': '41220', 'ea_slug': 'grimes-context-pb-requal8', 'symbol_slot': '0', 'symbol': 'GBPUSD.DWX', 'magic': '412200000', 'reserved_at': '2026-08-30', 'reserved_by': 'Codex governed allocator', 'status': 'active'}`; recovery card `D:\QM\strategy_farm\artifacts\cards_review\QM5_41220_grimes-context-pb-requal8.md` SHA-256 `0019d8c64b6379252606a4cb9109242e0ced53da80546b820287cc32ed479511`.
- Successor/enqueue contract (not executed): `python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_QM5_41220> --phase Q02`. Preconditions: governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded.
- Hold release note (not applied): OWNER-DEC-Q09HOLD-REQUAL-8-20260829; release only after Orchestrator approves manifest SHA-256, QM5_41220 is built and Codex-reviewed, and one append-only Q02 seed for GBPUSD.DWX is verified from anchor bae5710a-c610-474d-b885-3f9989f0d99a; preserve historical rows.

### 7. QM5_11421 / EURUSD.DWX -> QM5_41221

- Held row: `30584122-b7b3-41eb-8e1a-b03517554d4d`; state `pending` / `Q09_AWAITING_SEALED_PLAN`.
- Anchor: `a2b39c48-4845-4b49-9e84-9e88616a5862`; Q09 `v4` -> Q09; evidence `D:\QM\reports\work_items\a2b39c48-4845-4b49-9e84-9e88616a5862\QM5_11421\Q09\EURUSD_DWX\aggregate.json` SHA-256 `607562e8ba682785e820eb811830e88961d10f35080df823c4e65d45dbb00fa7`.
- Anchor hashes: MQ5 `b5dfd159b46281cdb30dae3ae12a12fd67cdf810941b82a4a5f7e11a9dce6a15`; EX5 `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b`; setfile `839fb74b3320e8ce62710c8765bc230c7f3d05f0f8ed9fdcae31a32e1fab5747`; include closure `UNBOUND`.
- Current hashes: MQ5 `b5dfd159b46281cdb30dae3ae12a12fd67cdf810941b82a4a5f7e11a9dce6a15`; EX5 `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b`; setfile `7b87dbf2a4a6b6e6d8cea39e9123ebf9e06f61e53e2215eed24afde7923d74cf`; recursive include closure `b066b20bc7beff5e5e5daaa0decee9e62b68620d54633cceb3e301bc3bf85332` (31 members).
- Mechanical result: `NEW_IDENTITY_FROM_Q02` because setfile, include_closure is not `MATCH`.
- Reservation: `QM5_41221` / `ohlc-daily-squeeze-reversal-d1-requal8`; active magic row `{'ea_id': '41221', 'ea_slug': 'ohlc-daily-squeeze-reversal-d1-requal8', 'symbol_slot': '0', 'symbol': 'EURUSD.DWX', 'magic': '412210000', 'reserved_at': '2026-08-30', 'reserved_by': 'Codex governed allocator', 'status': 'active'}`; recovery card `D:\QM\strategy_farm\artifacts\cards_review\QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8.md` SHA-256 `6a7a6bd10ab45b9253d6a52feaa285ed2a3c61d3727a745f1a555c44fe3457e9`.
- Successor/enqueue contract (not executed): `python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_QM5_41221> --phase Q02`. Preconditions: governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded.
- Hold release note (not applied): OWNER-DEC-Q09HOLD-REQUAL-8-20260829; release only after Orchestrator approves manifest SHA-256, QM5_41221 is built and Codex-reviewed, and one append-only Q02 seed for EURUSD.DWX is verified from anchor a2b39c48-4845-4b49-9e84-9e88616a5862; preserve historical rows.
- **No-touch clause:** This requalification must not mutate, supersede, cancel, reprioritize, reuse, or otherwise touch any QM5_41162 OPT_CENSUS row, artifact, or evidence.

### 8. QM5_11476 / USDJPY.DWX -> QM5_41222

- Held row: `08fe4173-07d9-47e1-97e9-a76b1159ad94`; state `pending` / `Q09_AWAITING_SEALED_PLAN`.
- Anchor: `fae2b8eb-db7b-4f59-86ec-ca917b270d3f`; Q09 `v4` -> Q09; evidence `D:\QM\reports\work_items\fae2b8eb-db7b-4f59-86ec-ca917b270d3f\QM5_11476\Q09\USDJPY_DWX\aggregate.json` SHA-256 `9fcedf14f618fa0b09e3d3e947530f8853f9859555429157a4b25a3cde3280b4`.
- Anchor hashes: MQ5 `2a9ee156652684883db01fafecf38ae142c76aa03d3211373bc74d5ba2692aec`; EX5 `034179dc9ef42db4ee1895bcba31edb707d3faac4a284ed08a6eeb944b097b64`; setfile `25d1f1d1f5fabdfe37e63f0837e053b471f84c1ad2de6cef836cbfc3a72eecb8`; include closure `UNBOUND`.
- Current hashes: MQ5 `2a9ee156652684883db01fafecf38ae142c76aa03d3211373bc74d5ba2692aec`; EX5 `034179dc9ef42db4ee1895bcba31edb707d3faac4a284ed08a6eeb944b097b64`; setfile `110b9a3d24af4d7effb5c665ed5dbbc34b9fe23e3c62b70895625dab734c65b4`; recursive include closure `8245eacfe1ebc8fb4b099f05d4e8fc3cbe59aece60bcf252a180791fe3baf316` (31 members).
- Mechanical result: `NEW_IDENTITY_FROM_Q02` because setfile, include_closure is not `MATCH`.
- Reservation: `QM5_41222` / `lien-k-double-bb-trend-h1-requal8`; active magic row `{'ea_id': '41222', 'ea_slug': 'lien-k-double-bb-trend-h1-requal8', 'symbol_slot': '0', 'symbol': 'USDJPY.DWX', 'magic': '412220000', 'reserved_at': '2026-08-30', 'reserved_by': 'Codex governed allocator', 'status': 'active'}`; recovery card `D:\QM\strategy_farm\artifacts\cards_review\QM5_41222_lien-k-double-bb-trend-h1-requal8.md` SHA-256 `b9b3de1e011c05ee98a92ed9ee6532d79b53799bed19109a88005c4d1bbe67ad`.
- Successor/enqueue contract (not executed): `python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id <APPROVED_BUILD_REVIEW_TASK_ID_FOR_QM5_41222> --phase Q02`. Preconditions: governed build complete; .mq5/.ex5/setfile present; Codex build review approved; Orchestrator manifest approval recorded.
- Hold release note (not applied): OWNER-DEC-Q09HOLD-REQUAL-8-20260829; release only after Orchestrator approves manifest SHA-256, QM5_41222 is built and Codex-reviewed, and one append-only Q02 seed for USDJPY.DWX is verified from anchor fae2b8eb-db7b-4f59-86ec-ca917b270d3f; preserve historical rows.

## Scope and safeguards

- The allocator receipt proves eight EA rows and eight magic rows were added with zero status-aware magic collisions; cards were copied byte-for-byte into the reserved EA directories.
- Each reserved directory contains only `docs/strategy_card.md`: no MQ5, EX5, setfile, compile result, or work item exists for a successor.
- All eight held rows remain pending under `Q09_AWAITING_SEALED_PLAN`. Hold release requires a later Orchestrator-approved, compiled, Codex-reviewed, append-only Q02 seed.
- The QM5_11421 successor is isolated from QM5_41162. It may not mutate, supersede, cancel, reprioritize, reuse, or otherwise touch any QM5_41162 `OPT_CENSUS` row, artifact, or evidence.
- No pipeline verdict is asserted by this manifest.

Verdict: `MANIFEST_READY_FOR_ORCHESTRATOR_REVIEW`; eight reservations complete, zero seeds, zero hold releases.
