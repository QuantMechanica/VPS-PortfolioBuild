# RECYCLE backlog census and bounded work record — 2026-07-27

## Scope and evidence

- Snapshot query: `SELECT ... FROM agent_tasks WHERE state=RECYCLE` against `D:\QM\strategy_farm\state\farm_state.sqlite`; captured 2026-07-27.
- Rows: **431** (411 `build_ea`, 20 non-build).
- Build disposition applies the full `qm-build-ea-from-card` preflight: repository source, OWNER-approved G0 card, anchored EA registry row, anchored magic row, and mandatory-news compatibility.
- Explicit duplicate/superseded/withdrawn/obsolete verdict -> RETIRE; every non-build -> NOT-A-BUILD for individual disposal.

## Census summary

| Disposition | Count |
|---|---:|
| COMPLETABLE | 1 |
| NEEDS-SOURCE | 409 |
| RETIRE | 1 |
| NOT-A-BUILD | 20 |

## Full triage table

| # | Priority | Task ID | Type | EA | Disposition | Evidence / reason |
|---:|---:|---|---|---|---|---|
| 1 | 99 | `e90c8b4f-0a31-49f5-a07d-b2d25811a1e3` | `pipeline_run` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 2 | 98 | `a4cb6cc1-5e42-4a2e-94f9-4544826ecad4` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 3 | 96 | `1b1b97b9-a0f5-4243-bf7c-a93beceb0d51` | `triage_failure` | `QM5_11903` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 4 | 96 | `1099e860-4dcd-4d82-acc1-c65a9b995335` | `review_ea` | `QM5_20160` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 5 | 95 | `a19aa372-3269-4097-9996-7b9e071a89fa` | `q02_infra_repair` | `QM5_12834` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 6 | 95 | `3dd18aa1-c4e8-4a77-b30e-01022dc4bcce` | `build_ea` | `QM5_20160` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 7 | 92 | `00b6f79c-b2e6-4653-a18f-420b3f51f49c` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 8 | 90 | `6e26c61f-321e-4313-ab96-b458d5746f0f` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 9 | 80 | `3854cd8b-f943-4db4-95e9-4ff9585ac7a3` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 10 | 70 | `5f860f79-dfb8-4188-aa80-1890aa606ef1` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 11 | 55 | `00591d1c-f0ac-4b56-a18e-d25f70ef00f4` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 12 | 50 | `27fb255a-232e-4a06-9e12-f80e263f98e3` | `build_ea` | `12612` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 13 | 50 | `11468a5a-89fc-4872-b6ec-2a78250ae792` | `build_ea` | `12922` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 14 | 50 | `19c8295f-c2aa-47b6-9e55-47e0fa465b0f` | `build_ea` | `12920` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 15 | 50 | `63c95ae9-d593-403a-928b-c51ac9848a1b` | `build_ea` | `12921` | **NEEDS-SOURCE** | Missing: OWNER-approved G0 card, anchored magic row, OWNER-approved mandatory-news revision. |
| 16 | 50 | `655d9d8a-f593-4dad-b359-a035d5f67d38` | `build_ea` | `12924` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 17 | 50 | `a8942b7a-e32e-4ac1-b819-cdcf1afa19cb` | `build_ea` | `12925` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 18 | 50 | `f9e1abeb-a14c-4f02-9869-b9d99fcbf303` | `build_ea` | `12923` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 19 | 50 | `10f2e21f-344a-451a-ae1d-3531c600ba26` | `build_ea` | `12926` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 20 | 50 | `3b5aa26f-a1b7-4089-8de5-5c425c6444a1` | `build_ea` | `12928` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 21 | 50 | `718716e3-087b-478c-ab26-fd2e49eb8d3e` | `build_ea` | `12927` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 22 | 50 | `7b431d7a-a902-4947-a932-ffa8ef3a54d7` | `build_ea` | `12929` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 23 | 50 | `adec96fb-48a5-4dcd-b949-aa337c89f7ee` | `build_ea` | `12930` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 24 | 50 | `0a7dec9e-8ff0-488b-a587-6dc3ad49af61` | `build_ea` | `12937` | **NEEDS-SOURCE** | Missing: OWNER-approved G0 card, anchored magic row, OWNER-approved mandatory-news revision. |
| 25 | 50 | `2a3580e3-ddbf-4853-b012-0cab4471109e` | `build_ea` | `12939` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 26 | 50 | `8393fe44-f0b1-4105-be77-0595d6761efe` | `build_ea` | `12938` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 27 | 50 | `ab171f6d-bd52-4b39-9386-936314d5439e` | `build_ea` | `12931` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 28 | 50 | `c4f759a4-6be6-4465-aa92-a691fbbf5c68` | `build_ea` | `12936` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 29 | 50 | `d9a93eb1-ac7a-489c-bf8d-5e45162142dd` | `build_ea` | `12932` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 30 | 50 | `01bd8a9d-bd3f-4da5-a275-be9192a763ed` | `build_ea` | `12944` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 31 | 50 | `0d36cc20-3a16-4da4-b0de-bb8b500cf2f1` | `build_ea` | `12942` | **NEEDS-SOURCE** | Missing: OWNER-approved G0 card, anchored magic row, OWNER-approved mandatory-news revision. |
| 32 | 50 | `18520109-5583-4027-95f3-9865f04c7664` | `build_ea` | `12941` | **NEEDS-SOURCE** | Missing: OWNER-approved G0 card, anchored magic row, OWNER-approved mandatory-news revision. |
| 33 | 50 | `e3a2083b-eeb7-40e0-b865-0cc7d001997e` | `build_ea` | `12943` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 34 | 50 | `e3e1d19f-afc3-47be-93f1-9b4008808f20` | `build_ea` | `12945` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 35 | 50 | `f2e0fa39-1871-43b8-a282-e0f2ea55e1cf` | `build_ea` | `12940` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 36 | 50 | `354268b6-da27-404a-8288-3071107d73b9` | `build_ea` | `12950` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 37 | 50 | `aae32e9c-372c-4108-9dd7-2f041682eae4` | `build_ea` | `12951` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 38 | 50 | `b40150ec-8dc7-46fa-b15d-9e82762240ea` | `build_ea` | `12949` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 39 | 50 | `f3254781-8a6f-4d7b-bf99-8183ca5c892a` | `build_ea` | `12946` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 40 | 50 | `fb7ed34a-46f1-479f-9f1c-b9b0ae91914e` | `build_ea` | `12947` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 41 | 50 | `fc522a96-49a9-498e-9a1e-9d5a77e31c99` | `build_ea` | `12948` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 42 | 50 | `12829c50-756a-47c5-87d7-27007115b939` | `build_ea` | `1401` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 43 | 50 | `14e4021c-7420-4072-ba54-028dd4d0883a` | `build_ea` | `12954` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 44 | 50 | `4f5b3b2b-7c8d-4da1-ad62-7577640ddce5` | `build_ea` | `12955` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 45 | 50 | `83f3bde2-3bfe-44cf-998d-ca623626a6d5` | `build_ea` | `12952` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 46 | 50 | `a2180685-9a61-45ef-a254-3d1bbe970d50` | `build_ea` | `13031` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 47 | 50 | `c7b9c56d-2270-4512-bfa3-bd5d8ff982af` | `build_ea` | `1345` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 48 | 50 | `0d490609-922c-47df-a3eb-2a27412e3796` | `build_ea` | `1409` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 49 | 50 | `4fc08ad9-c107-4176-8a47-94290a7bf979` | `build_ea` | `1402` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 50 | 50 | `7dccf57e-a995-465f-a9b7-98e7b945a651` | `build_ea` | `1408` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 51 | 50 | `ababc064-ebcd-4fb2-8d93-106cd2d412c0` | `build_ea` | `1404` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 52 | 50 | `bd923098-ff94-4451-b3c5-a1f2724613fa` | `build_ea` | `1405` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 53 | 50 | `ea5327f9-2e58-4f02-b542-3861c7432401` | `build_ea` | `1407` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 54 | 50 | `14432f77-9abf-4032-aefc-278a6bdbad34` | `build_ea` | `1417` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 55 | 50 | `61ccc27f-951c-47fc-a8c6-985dcf7da3b4` | `build_ea` | `1426` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 56 | 50 | `77bb60df-1c46-46db-b0d5-3560e2949375` | `build_ea` | `1425` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 57 | 50 | `ad4b4d2e-3fb7-48ea-a424-09d85a616e34` | `build_ea` | `1416` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 58 | 50 | `c1850502-ac54-4fc4-b397-5e54e87d1eb6` | `build_ea` | `1410` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 59 | 50 | `335ec1bf-dcac-4a58-977a-096af1426976` | `build_ea` | `1430` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 60 | 50 | `90ae9c0d-857d-432a-aca4-53237883390b` | `build_ea` | `1431` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 61 | 50 | `a2d787e7-fe54-4d73-b58c-20bb04b6c880` | `build_ea` | `1428` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 62 | 50 | `ad739240-04c6-4d26-a618-f6d329bb0ea6` | `build_ea` | `1429` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 63 | 50 | `b5f5f132-c07b-4df4-a7a1-5bf27e6fb471` | `build_ea` | `1436` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 64 | 50 | `cab1d5d3-fc96-454e-af4d-70bab7da8ac7` | `build_ea` | `1432` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 65 | 50 | `05d72df0-f109-4bb8-8c3d-34930aeb91ec` | `build_ea` | `1437` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 66 | 50 | `10837ff7-e232-4b7f-991d-93f8c86b07c0` | `build_ea` | `1438` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 67 | 50 | `37bb113b-eb3b-4a32-b2c7-454dd9b0f853` | `build_ea` | `1445` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 68 | 50 | `6738a92f-f74a-4614-bbd1-05d8a118091f` | `build_ea` | `1439` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 69 | 50 | `8dcde79a-7b64-46f4-a0c7-828ac3bc5257` | `build_ea` | `1441` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 70 | 50 | `fcddd7f2-4322-4365-b710-2f8f8192dc41` | `build_ea` | `1444` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 71 | 50 | `515d6668-ec57-4b46-934a-ed04f404a7a3` | `build_ea` | `1447` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 72 | 50 | `7830f003-6b91-4b15-b29d-4620e6a2172f` | `build_ea` | `1459` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 73 | 50 | `7ac78155-3ba3-4948-8bf9-ab5b451a0a3a` | `build_ea` | `1457` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 74 | 50 | `b436a5ae-5394-495f-b9b0-067e9222c948` | `build_ea` | `1449` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 75 | 50 | `e1abae8e-98f3-4db2-91e5-d2b82f9a7a68` | `build_ea` | `1480` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 76 | 50 | `22b0307b-da28-45f8-be0e-d445ac5ed217` | `build_ea` | `1485` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 77 | 50 | `6c86e8b0-9336-463a-820c-8bb2cc0fa524` | `build_ea` | `1488` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 78 | 50 | `e534be5a-0fe5-4935-9e6f-bd8b44d8f499` | `build_ea` | `1487` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 79 | 50 | `f54bf4d4-befa-47c0-b33b-a099a1fcffc1` | `build_ea` | `1482` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 80 | 50 | `f54dd835-ec9c-4887-9c10-c04ceb733d98` | `build_ea` | `1481` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 81 | 50 | `44027948-6e02-47a0-8446-9e9d14e4b2b5` | `build_ea` | `1508` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 82 | 50 | `62ac4ac4-f961-4d47-b0b8-092551ac2aa5` | `build_ea` | `1507` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 83 | 50 | `cbdefd98-df64-4bdd-a734-4fc86d04caf6` | `build_ea` | `1503` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 84 | 50 | `d53ecca7-608b-4572-9fe3-f1922dd95134` | `build_ea` | `1504` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 85 | 50 | `e15e2aac-ba1f-45b7-a91b-a47552d0d3d7` | `build_ea` | `1502` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 86 | 50 | `eb71678d-c6d3-4550-998a-29eb5cbba9c1` | `build_ea` | `1489` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 87 | 50 | `0a9b9637-30c5-4de4-8833-809ea92d5cbd` | `build_ea` | `1526` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 88 | 50 | `37f0eab1-79ec-47fd-a2e9-8a3a0aabe60d` | `build_ea` | `1524` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 89 | 50 | `41a34361-087e-4d86-acd0-142f0eb803b3` | `build_ea` | `1521` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 90 | 50 | `b15b055e-d2fe-4f71-8f15-4bdf2f073258` | `build_ea` | `1525` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 91 | 50 | `d68dcd1b-0f7e-4fd8-b033-4815f0811c97` | `build_ea` | `1509` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 92 | 50 | `fddbb404-f6fe-46ee-9d1e-1589d07be3d9` | `build_ea` | `1511` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 93 | 50 | `240c7757-7333-482c-938c-21a1b51c9b49` | `build_ea` | `1529` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 94 | 50 | `3d286159-a8b0-4942-9321-5b5f0a3d074c` | `build_ea` | `1533` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 95 | 50 | `531a62de-4ce9-4563-9352-edbffe0d6ed1` | `build_ea` | `1531` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 96 | 50 | `932dde11-f11f-41c1-83df-c7afd521bd3e` | `build_ea` | `1527` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 97 | 50 | `df4391d5-cab6-45f3-91f0-aa7fdbb3c423` | `build_ea` | `1532` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 98 | 50 | `055d165f-ca4d-4eea-9fdc-c440ca593723` | `build_ea` | `1537` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 99 | 50 | `32fe6e27-d811-4e58-947b-fe78e0269ee3` | `build_ea` | `1538` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 100 | 50 | `576c773a-9bba-40eb-a32d-7d0a52d8b386` | `build_ea` | `1539` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 101 | 50 | `b9563ce6-c36e-4a7c-b324-491d6b77a254` | `build_ea` | `1546` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 102 | 50 | `e83eafb9-19bd-4ef6-bce7-8e3a8ae4522e` | `build_ea` | `1547` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 103 | 50 | `3b5bc110-929d-4322-bdd8-994211b6a017` | `build_ea` | `1562` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 104 | 50 | `5d74c748-5879-4574-b6fb-cfc64f4482e6` | `build_ea` | `1553` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 105 | 50 | `7c31ab3a-de96-4948-8138-b2c6aef8630d` | `build_ea` | `1550` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 106 | 50 | `ab456e8d-a4fb-46bd-8d12-a75790ac6d7a` | `build_ea` | `1557` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 107 | 50 | `c5306234-6376-4245-b266-f87319c1fa17` | `build_ea` | `1563` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 108 | 50 | `098a6f11-3d7a-4508-966c-bd54e0274048` | `build_ea` | `1578` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 109 | 50 | `2e1568bf-47b4-4f55-991c-cb2eb92aff24` | `build_ea` | `1583` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 110 | 50 | `46327e2e-5246-4f05-89b1-bdcdc72bb41b` | `build_ea` | `1582` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 111 | 50 | `545ddaea-94fe-494c-a675-79db08806fa4` | `build_ea` | `1581` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 112 | 50 | `dbee1531-c435-46d6-a577-f6b377c2b24d` | `build_ea` | `1577` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 113 | 50 | `e743e2c4-1e35-479b-94d3-20e955efc53e` | `build_ea` | `1572` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 114 | 50 | `72e5f0a9-b4fc-4319-ba9c-83de09df0d23` | `build_ea` | `1585` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 115 | 50 | `ad115992-ffcc-4f30-be48-ff53b1304b3e` | `build_ea` | `1593` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 116 | 50 | `b84df62f-47b8-48cd-a35c-a505a7b731f6` | `build_ea` | `1592` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 117 | 50 | `c81246b6-e72c-4810-aa4b-58dfc8f37ddd` | `build_ea` | `1591` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 118 | 50 | `00946895-b594-4740-8e9f-884d3e3ea58a` | `build_ea` | `1605` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 119 | 50 | `123a5ce6-5595-4f74-8ee9-3d591a168ad9` | `build_ea` | `1595` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 120 | 50 | `1477e9b6-1288-4a1f-bf79-d61c3a185c23` | `build_ea` | `1594` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 121 | 50 | `5abe871c-8cef-4f0d-b8bf-b995c181ed4a` | `build_ea` | `1604` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 122 | 50 | `5ce8d642-5907-4715-bb84-7c3b8a18e792` | `build_ea` | `1606` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 123 | 50 | `01653662-8b30-4869-9540-b2ff3c32513a` | `build_ea` | `1607` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 124 | 50 | `315fdaf0-eec9-4bf2-bac7-69f0acc143ff` | `build_ea` | `1611` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 125 | 50 | `690cd9ab-da44-4dd5-8cb2-0212384dc3db` | `build_ea` | `1612` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 126 | 50 | `6c3610cf-2087-4942-bdd2-a4268a339a14` | `build_ea` | `1617` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 127 | 50 | `de6c76f5-05f5-46cb-ac53-4fa4b81fc9b1` | `build_ea` | `1613` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 128 | 50 | `02da6437-8c76-42c5-82df-ed307ce12628` | `build_ea` | `1624` | **NEEDS-SOURCE** | Missing: repository .mq5, anchored EA registry row, anchored magic row. |
| 129 | 50 | `55c469d0-5432-4efb-8d91-19d9a8fd010f` | `build_ea` | `1618` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 130 | 50 | `810145d0-5aeb-4a8f-9830-b0bdaadac57f` | `build_ea` | `1629` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 131 | 50 | `8d8774bf-011a-4c1e-ab3b-544e290d6435` | `build_ea` | `1623` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 132 | 50 | `8f373d2d-329c-4b18-ae5d-8334c0ad380c` | `build_ea` | `1622` | **NEEDS-SOURCE** | Missing: OWNER-approved G0 card, anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 133 | 50 | `125751de-4019-4138-8f08-9cdb6733e9d3` | `build_ea` | `1635` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 134 | 50 | `3df5d260-bc78-4503-a517-0aaf63de797e` | `build_ea` | `1636` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 135 | 50 | `c24879e3-75d8-4ef5-8d1a-57b64cd0f2c8` | `build_ea` | `1643` | **NEEDS-SOURCE** | Missing: repository .mq5, anchored EA registry row, anchored magic row. |
| 136 | 50 | `f6029c79-fbcd-4134-a9b8-5c286a6642a9` | `build_ea` | `1645` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 137 | 50 | `f990754c-57b2-4be5-b6c3-c0e34c2b7dc2` | `build_ea` | `1640` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 138 | 50 | `2c2ae3bf-b1db-401a-8725-cb109f7eb98d` | `build_ea` | `1650` | **NEEDS-SOURCE** | Missing: OWNER-approved G0 card, anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 139 | 50 | `442039bc-c8d4-4d47-8b08-5ef5c22fc2bc` | `build_ea` | `1648` | **NEEDS-SOURCE** | Missing: OWNER-approved G0 card, anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 140 | 50 | `5a6e93c2-8200-4982-83e5-1d59b8a3a149` | `build_ea` | `1647` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 141 | 50 | `5e7ee21a-5fe8-48e9-870f-18bec88fc5ce` | `build_ea` | `1651` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 142 | 50 | `9a7db6ac-3117-4e68-a53f-ea0aa36dea1d` | `build_ea` | `1649` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 143 | 50 | `4a5c9ed6-20b8-47e3-91d3-1aa4e51d4385` | `build_ea` | `1671` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 144 | 50 | `6cf3af36-e15e-4af0-857b-d0f99eefe6f6` | `build_ea` | `1653` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 145 | 50 | `977c8c04-f57b-40f7-9b3b-3d89d5bf237e` | `build_ea` | `1673` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 146 | 50 | `bd4171e3-56e3-4d5b-96a6-684a49f2b8f4` | `build_ea` | `1701` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 147 | 50 | `c6387b4b-f0b0-4021-8606-6f68a35a79f2` | `build_ea` | `1652` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 148 | 50 | `4283ca39-d208-4e4a-9d81-aa220041afad` | `build_ea` | `1803` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 149 | 50 | `a2c5e7eb-62d3-41f1-8754-b3ffcab3a7c3` | `build_ea` | `1702` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 150 | 50 | `bff7eda1-2b00-4170-8a02-1afbffcd5c70` | `build_ea` | `1802` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 151 | 50 | `c060d896-0a00-4427-999f-6dd0df8f921c` | `build_ea` | `1856` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 152 | 50 | `f8763caf-f44f-4236-b452-10d1598ae802` | `build_ea` | `1751` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 153 | 50 | `0f0a86ae-ae36-4f5b-9dfa-9757ad2cb30d` | `build_ea` | `1912` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 154 | 50 | `2f463fcc-2053-4cc5-8961-00b54db83ebd` | `build_ea` | `1859` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 155 | 50 | `897e7e91-f25a-4dc7-9e35-fd2b47a9869e` | `build_ea` | `1857` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 156 | 50 | `9a44b91f-4ae7-4a8a-9720-cb719df60f58` | `build_ea` | `1913` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 157 | 50 | `b46d62d8-cb34-42fb-8ad8-89bfbb39c4fd` | `build_ea` | `1911` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 158 | 50 | `effa9bc8-c211-4488-8bd7-a22bcaf645cd` | `build_ea` | `1858` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 159 | 50 | `1c2c6857-fa10-492e-a4c4-af4bbcdc71a8` | `build_ea` | `1968` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 160 | 50 | `2c0f932b-668c-4c3c-96ec-53a5fb8cdcbc` | `build_ea` | `1914` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 161 | 50 | `47cbab28-c904-4fac-a2e7-f96fef54f17f` | `build_ea` | `1966` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 162 | 50 | `5adea48e-d98a-461d-ba2b-6613fecc13f2` | `build_ea` | `1967` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 163 | 50 | `d7c64749-a03c-47f8-a555-65269977ca33` | `build_ea` | `1965` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 164 | 50 | `04125547-feee-4d50-9423-eac60e1eec8a` | `build_ea` | `2022` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 165 | 50 | `749f4524-e8c9-4afd-8455-eeca6f6839f8` | `build_ea` | `2020` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 166 | 50 | `8eaf03bd-5b44-4fae-9435-c0e6077154bd` | `build_ea` | `1969` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 167 | 50 | `d09334f9-d869-41eb-aa26-1f99ca45d346` | `build_ea` | `2021` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 168 | 50 | `d90e7498-f47f-4dba-8d2a-674bb0569909` | `build_ea` | `2023` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 169 | 50 | `8511bd8a-6f24-4e78-a416-40699fcf9d0d` | `build_ea` | `2187` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 170 | 50 | `ab03acbe-5428-45e0-ad87-876f07591e73` | `build_ea` | `2135` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 171 | 50 | `ae818e35-7732-4ec4-89ba-5d353cdbcf3e` | `build_ea` | `2025` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 172 | 50 | `b1bcaee2-efb6-4226-9578-bff538852f87` | `build_ea` | `2188` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 173 | 50 | `c15f2390-4c8e-432d-bcfa-600807db676b` | `build_ea` | `2186` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 174 | 50 | `13d9b822-c4ed-489e-9f32-27accae6ff5f` | `build_ea` | `2242` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 175 | 50 | `30bbd5e2-ea7b-46d3-96a1-5cd0050117d8` | `build_ea` | `2189` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 176 | 50 | `3129e748-59f4-445a-9d11-12f6fca5fd97` | `build_ea` | `2241` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 177 | 50 | `69bced3f-e859-43bb-bf24-60f17e23e9d0` | `build_ea` | `2190` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 178 | 50 | `70805206-74fb-455f-876f-11776e8c5621` | `build_ea` | `2243` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 179 | 50 | `15d9681a-5f85-40ad-8a0d-00f3c5fbba76` | `build_ea` | `2298` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 180 | 50 | `3c27df92-4d2c-4b51-9e5b-a2d63c4db340` | `build_ea` | `2299` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 181 | 50 | `6550a1f8-cb6b-4b6b-b04b-f06be41603d1` | `build_ea` | `2297` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 182 | 50 | `b5905d19-0976-41e0-9b5d-9b170993c8db` | `build_ea` | `2296` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 183 | 50 | `fcd84ecd-cb3d-4f2c-be69-6d34bc940761` | `build_ea` | `2244` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 184 | 50 | `6e233c53-cfdf-47fe-8ddb-670346af46e4` | `build_ea` | `2352` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 185 | 50 | `997906f8-9eec-4693-9193-74c6597715ca` | `build_ea` | `2351` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 186 | 50 | `b58bf851-b287-4772-b732-9f5d82352ac2` | `build_ea` | `2353` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 187 | 50 | `ba175427-ff12-42bf-8790-c6e997a0673f` | `build_ea` | `2300` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 188 | 50 | `2201ca64-2342-41f6-97ea-f34a31b48d92` | `build_ea` | `2408` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 189 | 50 | `5fca8ef3-c38a-4e48-bdf8-0325a297434d` | `build_ea` | `2355` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 190 | 50 | `8d108839-29ec-4569-8039-109f7bbfcb15` | `build_ea` | `2407` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 191 | 50 | `99efdb31-1df6-4aa5-9102-bf7e250c149f` | `build_ea` | `2354` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 192 | 50 | `ef0f2333-e00f-41ce-9ecd-5d9f540cf3be` | `build_ea` | `2406` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 193 | 50 | `1fd88db4-fbd1-49a2-83c6-293bdf9cb11b` | `build_ea` | `2461` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 194 | 50 | `3fdd2c8d-4e16-4a92-bb8a-7258a674a68b` | `build_ea` | `2409` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 195 | 50 | `5297d50e-314d-4557-8f14-9463bcf7fc3e` | `build_ea` | `2462` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 196 | 50 | `8262515b-4563-4db8-9c4e-7b4b4927e178` | `build_ea` | `2410` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 197 | 50 | `fcaeb2ee-6c92-4d57-8a8b-fe71deb585e9` | `build_ea` | `2463` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 198 | 50 | `2cdbbe4e-095e-4f53-89a2-243ecc4ae615` | `build_ea` | `9010` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 199 | 50 | `4382291e-4a39-4eda-a38d-745805885817` | `build_ea` | `9103` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 200 | 50 | `aca126f7-1caf-4769-828a-129b2e315d4a` | `build_ea` | `9102` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 201 | 50 | `afe18aff-644c-43da-84b3-7e725212ba61` | `build_ea` | `2464` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 202 | 50 | `d76d758e-d4d6-4898-a958-15e9bdf4e853` | `build_ea` | `2465` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 203 | 50 | `0568432f-2e9e-4ebc-9a91-808eac072508` | `build_ea` | `9104` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 204 | 50 | `14d9adac-7680-4a0f-8a19-80dbd1019d48` | `build_ea` | `9147` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 205 | 50 | `4063b233-b1a9-46e4-a220-2d18c5cb0343` | `build_ea` | `9112` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 206 | 50 | `9c481197-288f-4c07-9714-637ecc8bd624` | `build_ea` | `9113` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 207 | 50 | `c214fe96-6101-46e0-98cc-30daa4ea8d03` | `build_ea` | `9111` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 208 | 50 | `084be1d0-8d08-4c36-b672-5ff5befdd89e` | `build_ea` | `9169` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 209 | 50 | `181b8a00-f226-4240-8649-a4b246f8c9ad` | `build_ea` | `9165` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 210 | 50 | `6a79738c-7643-4d5b-95e3-d8906b029178` | `build_ea` | `9168` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 211 | 50 | `a7124029-0e45-4137-be9e-49e31f685b6a` | `build_ea` | `9166` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 212 | 50 | `f1d3f7a3-1999-48e5-ada5-caac982e382d` | `build_ea` | `9167` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 213 | 50 | `35c9e6ad-0be4-4539-8572-554fb390b4a6` | `build_ea` | `9183` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 214 | 50 | `3cd229bb-8900-4dac-9367-3dbfaf84f67c` | `build_ea` | `9182` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 215 | 50 | `72766d7b-3942-40df-b864-b5d341ec15c1` | `build_ea` | `9176` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 216 | 50 | `e4ad0c0c-01b8-4fd2-99b2-98922c9df54b` | `build_ea` | `9181` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 217 | 50 | `eb06fcee-67c4-4b6a-a499-5be44cabc93c` | `build_ea` | `9177` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 218 | 50 | `31cb89f3-2190-4653-b2b4-8a4dbd86bac7` | `build_ea` | `9196` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 219 | 50 | `4b0bd563-9542-4ac7-b942-3e3845e66f3d` | `build_ea` | `9203` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 220 | 50 | `912be76d-68dc-4852-88fc-e7c80b04c03b` | `build_ea` | `9204` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 221 | 50 | `afeb2af8-f725-4dbe-b15a-47c3e19d2ffd` | `build_ea` | `9205` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 222 | 50 | `2189218c-3a65-4ca3-baba-5d63d0401d25` | `build_ea` | `9216` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 223 | 50 | `52ee2c30-429a-4eed-b0e5-b00379fcd0f0` | `build_ea` | `9215` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 224 | 50 | `7b3784ed-633a-45c9-9762-707630923a80` | `build_ea` | `9211` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 225 | 50 | `ef5aad39-d138-46d1-9227-d9765d5baaa8` | `build_ea` | `9208` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 226 | 50 | `f08a89c4-e47d-492a-8645-247593c2c046` | `build_ea` | `9209` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 227 | 50 | `7b77b2b6-50e4-4c3e-a846-51fc0db5bcf1` | `build_ea` | `9224` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 228 | 50 | `7c217c65-79f8-47cf-85d1-9dc464460a0b` | `build_ea` | `9223` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 229 | 50 | `973e3dce-3504-408a-8c8e-89de1eab6366` | `build_ea` | `9225` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 230 | 50 | `cc5c1221-1289-4d5a-8a18-2d5d15bd63cd` | `build_ea` | `9222` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 231 | 50 | `f99873db-5daa-4579-8c4d-cdc8bb0d159c` | `build_ea` | `9220` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 232 | 50 | `1f7c24c5-553a-4469-b6b7-7a507200841d` | `build_ea` | `9232` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 233 | 50 | `3f4980fb-90b5-49c2-9b22-fc2938b43efb` | `build_ea` | `9230` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 234 | 50 | `8ff4de4c-7e6e-4a65-ad2f-7a8bf5788c68` | `build_ea` | `9231` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 235 | 50 | `9e8fd51d-5c94-41a4-baa3-a36c62cbb62b` | `build_ea` | `9234` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 236 | 50 | `f0dd1187-ac39-4a61-8e38-77b26f600d71` | `build_ea` | `9233` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 237 | 50 | `04f349cc-020f-4180-933b-c665a782439f` | `build_ea` | `9251` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 238 | 50 | `29c5ec88-5f35-4fc0-9fab-78dc5f00ee80` | `build_ea` | `9254` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 239 | 50 | `71af1255-bcb1-4ccd-a4bb-aa8578257e0d` | `build_ea` | `9264` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 240 | 50 | `9285cf7d-9331-4af7-8033-171b4660b36e` | `build_ea` | `9252` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 241 | 50 | `b454e005-2d3f-4a6d-8239-5fbd58c47bec` | `build_ea` | `9256` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 242 | 50 | `d00d7571-74f4-45ea-b652-57fa439f7bd9` | `build_ea` | `9241` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 243 | 50 | `0330fade-59e5-4c59-ab04-03500b2fb85a` | `build_ea` | `9277` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 244 | 50 | `1017e601-92b0-4c72-a1f5-b5e0531416cf` | `build_ea` | `9273` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 245 | 50 | `afed7b7c-0259-4256-acad-f22224babdab` | `build_ea` | `9279` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 246 | 50 | `b994c320-b03a-423d-ab94-fb69b90a38f0` | `build_ea` | `9275` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 247 | 50 | `bb6235da-2157-418f-ab00-7e0c3be0d6e2` | `build_ea` | `9276` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 248 | 50 | `5371ab7c-d88f-4452-a3c3-a338edcb5d28` | `build_ea` | `9297` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 249 | 50 | `6a0ae4d5-66d4-4a37-9323-38e1224236db` | `build_ea` | `9284` | **NEEDS-SOURCE** | Missing: anchored EA registry row, anchored magic row, OWNER-approved mandatory-news revision. |
| 250 | 50 | `8c3ddf84-4b96-467f-8893-b59e85840d95` | `build_ea` | `9280` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 251 | 50 | `c0bb9235-3d6e-4d0f-a688-e8276b939e47` | `build_ea` | `9282` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 252 | 50 | `ffdb2772-97b1-4615-8871-196a23805834` | `build_ea` | `9281` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 253 | 50 | `0bf5bbf0-59b6-4f88-b50d-de609d881642` | `build_ea` | `9304` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 254 | 50 | `52fc3ee3-bd54-41c4-a3fd-d3616da86b62` | `build_ea` | `9406` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 255 | 50 | `67488097-51f8-4a90-a7d5-0ca254d89b15` | `build_ea` | `9363` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 256 | 50 | `7bc95960-7134-4d02-88c2-87ce2cb8761c` | `build_ea` | `9353` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 257 | 50 | `8a0f2cf4-afe3-4e13-80c8-9f39929de4f0` | `build_ea` | `9410` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 258 | 50 | `d82200c3-e4bc-429b-8be1-d20c0f6b5a21` | `build_ea` | `9303` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 259 | 50 | `1b490cf7-9172-410b-8e5b-07b24c0cb517` | `build_ea` | `9465` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 260 | 50 | `5de38382-e3f2-4179-b63b-6f60222bccc3` | `build_ea` | `9467` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 261 | 50 | `aaf5545d-ea51-4dab-9332-8f0784d9c663` | `build_ea` | `9461` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 262 | 50 | `cc4549cc-1955-47fb-9801-78d2aad3f77b` | `build_ea` | `9417` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 263 | 50 | `ffdbf22e-3ec4-4027-88d5-5a6e4ba6c1c7` | `build_ea` | `9466` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 264 | 50 | `34ffb386-bb5b-4c08-8319-c8b893fc50cc` | `build_ea` | `9579` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 265 | 50 | `3ff472a0-8f53-4558-ae66-459a29c77da2` | `build_ea` | `9516` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 266 | 50 | `524cca67-50b7-409a-a13c-7860dc61148d` | `build_ea` | `9521` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 267 | 50 | `add54a46-19bc-415c-810d-0f117f5cf2ae` | `build_ea` | `9519` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 268 | 50 | `e7fdd25e-d16c-44d3-bcbe-c22756021747` | `build_ea` | `9468` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 269 | 50 | `63c1032c-1534-482a-a399-efe2600f8356` | `build_ea` | `9583` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 270 | 50 | `9fd339d0-9e37-40a2-8da6-2b18e20c899d` | `build_ea` | `9717` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 271 | 50 | `c3f03e05-3064-4a1e-93ff-097150115ffe` | `build_ea` | `9580` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 272 | 50 | `cadbb75f-8566-4326-92c6-912cae4b0da6` | `build_ea` | `9718` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 273 | 50 | `d573fb90-49fa-4f73-87a5-4f01d0254002` | `build_ea` | `9716` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 274 | 50 | `2dc0025a-7b2d-472c-ac65-58c806c5a768` | `build_ea` | `9720` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 275 | 50 | `568405c9-6c59-464d-ba22-b3e9512a638e` | `build_ea` | `9719` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 276 | 50 | `9ca8f81d-782e-495f-97f0-8f205dbd45fc` | `build_ea` | `9721` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 277 | 50 | `b3706cb0-1e2f-403c-a3a9-ffc9e87e6835` | `build_ea` | `9730` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 278 | 50 | `d820be5a-675c-411f-b761-6c09aad2b811` | `build_ea` | `9727` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 279 | 50 | `499eaa2a-1f7a-47d2-b6df-a52d4d2999dc` | `build_ea` | `9910` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 280 | 50 | `970379cc-27ef-4f71-a07e-5421e45171ef` | `build_ea` | `9911` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 281 | 50 | `a944cf09-4a86-43b5-90b5-1d6fc5108ae6` | `build_ea` | `9909` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 282 | 50 | `b770de57-f359-4d11-9b5e-1f7f141e26b6` | `build_ea` | `9904` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 283 | 50 | `bf75d014-7e5f-4f32-ac00-b9727b98619c` | `build_ea` | `9907` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 284 | 50 | `ce7ef250-d7c0-418a-aa51-fff4f7a8136e` | `build_ea` | `9908` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 285 | 50 | `25102f3e-14f6-4a82-b25d-1805dd49ce14` | `build_ea` | `9914` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 286 | 50 | `3386130d-8fec-49ff-bf2c-c238d8807121` | `build_ea` | `9921` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 287 | 50 | `39477905-5cfe-43eb-bebf-3ad5ba8d10b3` | `build_ea` | `9922` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 288 | 50 | `69ad8ea9-aec8-40fd-aba1-ac436657ffad` | `build_ea` | `9912` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 289 | 50 | `de7917ef-268a-4b01-90a4-c77cf4e04b9e` | `build_ea` | `9913` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 290 | 50 | `4b9809f2-0f51-4773-9f73-f0787c5c3a17` | `build_ea` | `9925` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 291 | 50 | `6bfd24a6-b1ac-47a0-a767-1053d07e81b8` | `build_ea` | `9924` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 292 | 50 | `c10c1e2c-6932-4db8-afdd-40907ea34246` | `build_ea` | `9933` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 293 | 50 | `c71f308a-76be-456f-8ae7-a5d7c3abc4e0` | `build_ea` | `9932` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 294 | 50 | `d2b4cd24-ae0d-4cbb-92fb-a8ffcf328003` | `build_ea` | `9923` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 295 | 50 | `36e5bbfa-6698-4644-8fe3-60aa9f7052cc` | `build_ea` | `9934` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 296 | 50 | `528d9db8-5f15-4c26-81bf-887a4b6deb17` | `build_ea` | `9949` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 297 | 50 | `7f5be227-52c7-4a57-a68a-a1ca31ffbd01` | `build_ea` | `9947` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 298 | 50 | `8b3cc484-dc8e-494d-a3b8-3a5d0d8e5e56` | `build_ea` | `9963` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 299 | 50 | `cf579137-6e4e-4044-a2c1-fb0a4dfa84bb` | `build_ea` | `9961` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 300 | 50 | `f24b54a3-ca2e-4cfd-8ae8-3b23712ff20d` | `build_ea` | `9946` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 301 | 50 | `037f7a25-4931-4fe9-a5f5-1eef6bacd073` | `build_ea` | `9964` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 302 | 50 | `1b1dd349-786e-48d1-8c3f-d7ed91614c54` | `build_ea` | `9973` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 303 | 50 | `2321b9ed-3a30-4690-a15a-babe2188ae6f` | `build_ea` | `9965` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 304 | 50 | `9afcf2a0-2f75-46d5-9707-8a42834eda67` | `build_ea` | `9971` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 305 | 50 | `f3b6bf03-fa59-4d17-8336-bb440cf90a0d` | `build_ea` | `9972` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 306 | 50 | `86377647-2659-4308-a435-727c070515c4` | `build_ea` | `9983` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 307 | 50 | `a0768e09-7427-4ebe-87c1-19b4b17c9de1` | `build_ea` | `9979` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 308 | 50 | `5766506d-8630-44b8-b85c-229d93051449` | `build_ea` | `1619` | **COMPLETABLE** | All governed build preflight evidence resolved. |
| 309 | 50 | `e22dac9b-351f-41ca-9214-164a7a607ab1` | `build_ea` | `1157` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 310 | 35 | `20cfbf8d-0ce9-4fa7-acc8-9d45ce319df4` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 311 | 35 | `bb105489-2a1f-4af4-8cff-1ada6e43394b` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 312 | 30 | `aac25e1f-61f3-4243-9e5b-063a203d702d` | `research_strategy` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 313 | 30 | `cb255099-a42d-46ad-903d-a69c7b1f2d40` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 314 | 25 | `4b3026f0-c72b-4189-b1d2-cdfa64a8a844` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 315 | 25 | `75a1670d-99cf-4569-969f-3e56d7d20479` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 316 | 15 | `0ff5301f-12d3-486f-add1-42164cb67226` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 317 | 15 | `152ee474-6a8e-4c67-8178-80de9c2d5dce` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 318 | 15 | `1e2d2400-b7b2-47e9-9d9c-8d0c710661fc` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 319 | 15 | `2091a9fa-6673-4b70-8f83-7dd7e46c9662` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 320 | 15 | `2b84d6c6-f553-4789-9f29-2155e2e8789f` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 321 | 15 | `3e541bbb-2b2f-4eec-bc84-d0b6bb1a5538` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 322 | 15 | `43fb67c0-281f-4235-8852-6caefcf065bd` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 323 | 15 | `57ceb773-b51a-471e-b47a-a8e2a812126a` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 324 | 15 | `64a1bc8c-273b-4115-b348-1a0e21696e89` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 325 | 15 | `669cff79-2123-4f96-b859-962907848f8e` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 326 | 15 | `68a9ba8c-9b13-4c6e-905d-42badc7dbfd5` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 327 | 15 | `70a29f36-8861-4b71-8b1b-c3d18330e262` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 328 | 15 | `7584a464-6eb7-4fb6-8d61-0df859e7de39` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 329 | 15 | `774e52ce-3de1-4ee9-8d8c-4b2ef4d6f7e5` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 330 | 15 | `78460a75-1b8a-4570-b710-485aa615ac7f` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 331 | 15 | `78f7eaab-0eea-4a3f-874e-3a26149de52e` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 332 | 15 | `860402ff-39fe-4d81-9aa0-009b559e4e13` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 333 | 15 | `95edd8d3-9957-49a2-9bfb-cc9f858d3410` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 334 | 15 | `9f7ab554-88a4-4394-af06-013af3947186` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 335 | 15 | `affbb364-a7d6-44bd-afc2-fe37ed890fd9` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 336 | 15 | `b99b9910-04f5-41eb-a2b9-a7c88148a765` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 337 | 15 | `baf43eca-0775-4000-b3a5-f5ab0c568341` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 338 | 15 | `bbb0cdb2-6c41-444d-854c-906db563fe39` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 339 | 15 | `d36d5b71-8698-489c-8166-c5f0e5e8aebd` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 340 | 15 | `d3f415e5-6c85-4f57-a515-db22c290e1d6` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 341 | 15 | `d51f0c66-6647-4b73-81b2-991650cc1ff3` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 342 | 15 | `d87095b6-6df2-4ad0-a12e-2cdbb0bba4a7` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 343 | 15 | `dba5fb5f-1e0a-42e9-9296-05bec819ebca` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 344 | 15 | `dc281e0e-6144-4f01-9779-d25d36babb91` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 345 | 15 | `dde5789f-5920-4b5e-96fe-1b6cddc3fdff` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 346 | 15 | `de448769-d15f-4af5-931d-eee6a9eb99c4` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 347 | 15 | `e8f0ddba-577c-4a70-94cf-42d92921b0e0` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 348 | 15 | `ea1fd06d-46c8-4476-b4f3-2fecd05e1de6` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 349 | 15 | `f533c3ae-c9a5-4554-931d-424b3726a8f1` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 350 | 15 | `fe0bd00e-1370-4e09-886d-fac97667b682` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 351 | 15 | `fe5d5eb9-a89b-4007-9620-7ec73e9afc4f` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 352 | 15 | `00654c21-0646-4c96-8e59-76786b39ae01` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 353 | 15 | `1b97c75f-8502-4ce3-b809-c8f1b2e77603` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 354 | 15 | `23f15867-c8c2-4a4e-85c5-6759564f2377` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 355 | 15 | `2d83e1dc-6645-463b-87df-65adcfcd4666` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 356 | 15 | `3b4f50f0-0d3a-4586-8520-2930ee6b90c0` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 357 | 15 | `58529de4-4470-43c9-9098-66740f45c1a1` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 358 | 15 | `5c0e69f3-721b-4b55-b82b-f649e65f3726` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 359 | 15 | `64d8e1e8-e085-43fb-852b-5aee489a1ce8` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 360 | 15 | `659ff715-2026-420d-8f37-2b8b3b16bc2f` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 361 | 15 | `676a3447-b870-4287-9cfe-b887c45a4316` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 362 | 15 | `6940fd50-3542-4bb7-ac20-3dacb35d286b` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 363 | 15 | `7c474fc4-2d99-43bb-9d0e-9caf251d47e2` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 364 | 15 | `7e2eafb9-3e61-4256-980e-97ed14b3a481` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 365 | 15 | `7f23e6cb-1df9-4ca4-acaa-08bc68e991dc` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 366 | 15 | `98208be5-fdfa-4546-b679-5ac088849e31` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 367 | 15 | `9bc1a94c-81f6-47e2-a9e6-31c80007d7ed` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 368 | 15 | `a9c6dde6-8140-4caf-8df3-f13531a2e3e8` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 369 | 15 | `cb8c169e-4857-4a66-b046-eb6f41adfa4c` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 370 | 15 | `cbc142d7-d976-4a95-87fc-aa5bd95bd117` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 371 | 15 | `df232a93-e897-4c0f-9fd8-f838d2687553` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 372 | 15 | `e16fe7e8-3d65-44f8-9404-a62e41eb2314` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 373 | 15 | `f229d72a-d379-4174-b686-71d2699b00d2` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 374 | 15 | `f6faae44-575b-4ab8-b0d9-ba5dff0afe20` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 375 | 15 | `2592752f-166e-42e7-afa2-8ca005a4bbda` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 376 | 15 | `36caa7af-c7e2-441a-9c83-3535bf82b8f1` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 377 | 15 | `5216ca2f-a7a3-4651-b384-dd73e9ff0459` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 378 | 15 | `630cf64e-ab95-4063-99a6-9dd60b319acf` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 379 | 15 | `7db44e63-b270-4b25-9afe-0c2c7d32e8f0` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 380 | 15 | `82ec4a7a-0543-4b52-a76f-21e99da60d5f` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 381 | 15 | `9a02ee33-061e-4b8b-bbea-cf0a8ede131e` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 382 | 15 | `9a76907d-b867-4a5d-b53f-f241b6ece833` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 383 | 15 | `c3c8f065-7271-421f-83c2-3960c32150c8` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 384 | 15 | `f1e850c3-79a5-48dd-9873-af78daaecf72` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 385 | 15 | `05203c02-2ca5-4381-88b7-866bb1b8e07a` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 386 | 15 | `0f789eaa-ee6d-438c-a78d-78d444f12a1b` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 387 | 15 | `26dd277d-89f9-4143-ab23-222b7f61bb02` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 388 | 15 | `29fe6323-0aa9-4fcc-8f04-1bef8c6cf1a4` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 389 | 15 | `b9b00b59-93b2-4bb7-98e5-6dd70858187d` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 390 | 15 | `d2edaf18-b0c8-4d53-a5fd-016548c4f052` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 391 | 15 | `de283d20-bed4-4d3a-af72-b2d3c4edae96` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 392 | 15 | `e0a64a75-e4a0-4776-aec9-607589c7e6e5` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 393 | 15 | `085278aa-7088-4f04-b7de-9556fc52a1c3` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 394 | 15 | `0cc17076-8bcb-4d37-ac28-d1f98659ba7c` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 395 | 15 | `1bb278a3-321f-47a3-84ad-e145cc8ee086` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 396 | 15 | `4b38f7f1-14fa-4074-8760-7bb0e84210f0` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 397 | 15 | `6b6d0752-657a-4547-96b9-a35218f17647` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 398 | 15 | `75362314-5b3f-4aa7-bea0-863d9c47ddb8` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 399 | 15 | `7907b0ff-1173-439b-9314-1a210299b7df` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 400 | 15 | `96066d66-57a0-4c66-b9f2-79e468140033` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 401 | 15 | `9618f47c-c4a1-4ea6-872f-d80ff92ab1c1` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 402 | 15 | `a4003dc3-295e-4718-b829-02e7cc4ea4a8` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 403 | 15 | `d51eb0c4-b300-4f63-9d4a-996cc3df36b8` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 404 | 15 | `e4585374-b44a-4a70-990f-b841bf0ef6bb` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 405 | 15 | `f6ef0ef8-59cb-44f6-891d-e94e817d99ed` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 406 | 15 | `fcf93b69-c21f-4c99-8d9e-43583ec4ad9d` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 407 | 15 | `015c2005-68c6-4a86-9faa-f1214a5ef79a` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 408 | 15 | `30752afb-40c0-4bb4-aea5-f67ae410997d` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 409 | 15 | `63f76377-56a1-4013-8345-f829ce357ea7` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 410 | 15 | `6535bc85-18e0-462c-9491-020fda1a8160` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 411 | 15 | `8f43d17c-f25c-4d18-8170-0fdb2982a2df` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 412 | 15 | `c20945d0-237b-4828-9e78-850a641a6d8a` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 413 | 15 | `9e872ce2-5e53-4c78-97ed-a4248fef4f0c` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 414 | 12 | `4f5ca647-d088-48ee-98ab-0138912bffbd` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 415 | 12 | `6bf69ce4-36de-40fa-9769-472adeb111f7` | `build_ea` | `—` | **NEEDS-SOURCE** | Missing: repository .mq5, OWNER-approved G0 card, anchored EA registry row, anchored magic row. |
| 416 | 5 | `f308fe3f-efa2-43cc-bb69-bf72e6f8d10c` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 417 | 5 | `b4f63560-b99b-44fd-99fb-000e8f6111bf` | `triage_failure` | `QM5_11101` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 418 | 1 | `1f400c88-a2b7-4c48-acd4-37a139b772fe` | `build_ea` | `11899` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 419 | 1 | `7a00522d-6be6-4d44-a89e-2834c096b4ab` | `build_ea` | `11895` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 420 | 1 | `0daf10dc-cb94-499f-a82a-96d15d591135` | `build_ea` | `11901` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 421 | 1 | `2daf62c7-9294-45c9-8bbf-3d6fe6aa2df0` | `build_ea` | `11900` | **NEEDS-SOURCE** | Missing: anchored magic row, OWNER-approved mandatory-news revision. |
| 422 | 1 | `5fad3240-68f1-4b10-b559-fed9bd0dd642` | `build_ea` | `11905` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 423 | 1 | `db2735b1-7fc7-481f-aab9-c0aa9f8e7cf5` | `build_ea` | `11902` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 424 | 1 | `7ddcaec6-3a69-4053-add6-a31c8ed8c8b0` | `build_ea` | `11906` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 425 | 1 | `f1bdb9f3-dbbc-4bf7-a14d-b62420ad8230` | `build_ea` | `11907` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 426 | 1 | `aa39fa26-d79f-45f1-bc34-7826cdab00c6` | `build_ea` | `11915` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 427 | 1 | `ef231a79-4e71-4b2f-848b-7ce4ce15a031` | `build_ea` | `11913` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 428 | 1 | `043c2a30-235b-45fe-8d68-6a4bf272010b` | `build_ea` | `QM5_11896` | **RETIRE** | Task verdict explicitly records duplicate, superseded, withdrawn, or obsolete work. |
| 429 | 1 | `589b946f-ee56-4d69-b757-fcda6d1965d8` | `build_ea` | `11912` | **NEEDS-SOURCE** | Missing: OWNER-approved mandatory-news revision. |
| 430 | 1 | `68e61507-a3e7-43a5-99b9-aaddfde7ff4b` | `triage_failure` | `QM5_1642` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |
| 431 | 0 | `eda8c9c9-6de0-4ca5-8a40-f6fb054a62ba` | `ops_issue` | `—` | **NOT-A-BUILD** | Requires individual non-build disposal; no build-lane action authorized. |

## Bounded completion batches

- Census committed before any completion work, as required.
- Batch 1 preflight: 20 source-backed rows inspected serially under
  `qm-build-ea-from-card`; **0 were eligible to compile**. No RECYCLE exit was
  applied because every row failed a deterministic prerequisite before build.
  No Q02 enqueue is authorized or performed.

| Task | EA | Preflight result |
|---|---|---|
| `3dd18aa1-c4e8-4a77-b30e-01022dc4bcce` | `QM5_20160` | BLOCKED: approved card and anchored registry rows exist, but the card/EA/setfile lock news mode OFF; mandatory Edge Lab news blackout forbids acceptance without a new OWNER-approved card revision. |
| `27fb255a-232e-4a06-9e12-f80e263f98e3` | `QM5_12612` | NEEDS-SOURCE: no approved card resolved and no anchored `^12612,` magic row. |
| `11468a5a-89fc-4872-b6ec-2a78250ae792` | `QM5_12922` | NEEDS-SOURCE: no approved card resolved and no anchored `^12922,` magic row. |
| `19c8295f-c2aa-47b6-9e55-47e0fa465b0f` | `QM5_12920` | NEEDS-SOURCE: no approved card resolved and no anchored `^12920,` magic row. |
| `63c95ae9-d593-403a-928b-c51ac9848a1b` | `QM5_12921` | NEEDS-SOURCE: no approved card resolved and no anchored `^12921,` magic row. |
| `655d9d8a-f593-4dad-b359-a035d5f67d38` | `QM5_12924` | NEEDS-SOURCE: no approved card resolved and no anchored `^12924,` magic row. |
| `a8942b7a-e32e-4ac1-b819-cdcf1afa19cb` | `QM5_12925` | NEEDS-SOURCE: no approved card resolved and no anchored `^12925,` magic row. |
| `f9e1abeb-a14c-4f02-9869-b9d99fcbf303` | `QM5_12923` | NEEDS-SOURCE: no approved card resolved and no anchored `^12923,` magic row. |
| `10f2e21f-344a-451a-ae1d-3531c600ba26` | `QM5_12926` | NEEDS-SOURCE: no approved card resolved and no anchored `^12926,` magic row. |
| `3b5aa26f-a1b7-4089-8de5-5c425c6444a1` | `QM5_12928` | NEEDS-SOURCE: no approved card resolved and no anchored `^12928,` magic row. |
| `718716e3-087b-478c-ab26-fd2e49eb8d3e` | `QM5_12927` | NEEDS-SOURCE: no approved card resolved and no anchored `^12927,` magic row. |
| `7b431d7a-a902-4947-a932-ffa8ef3a54d7` | `QM5_12929` | NEEDS-SOURCE: no approved card resolved and no anchored `^12929,` magic row. |
| `adec96fb-48a5-4dcd-b949-aa337c89f7ee` | `QM5_12930` | NEEDS-SOURCE: no approved card resolved and no anchored `^12930,` magic row. |
| `0a7dec9e-8ff0-488b-a587-6dc3ad49af61` | `QM5_12937` | NEEDS-SOURCE: no approved card resolved and no anchored `^12937,` magic row. |
| `2a3580e3-ddbf-4853-b012-0cab4471109e` | `QM5_12939` | NEEDS-SOURCE: no approved card resolved and no anchored `^12939,` magic row. |
| `8393fe44-f0b1-4105-be77-0595d6761efe` | `QM5_12938` | NEEDS-SOURCE: no approved card resolved and no anchored `^12938,` magic row. |
| `ab171f6d-bd52-4b39-9386-936314d5439e` | `QM5_12931` | NEEDS-SOURCE: no approved card resolved and no anchored `^12931,` magic row. |
| `c4f759a4-6be6-4465-aa92-a691fbbf5c68` | `QM5_12936` | NEEDS-SOURCE: no approved card resolved and no anchored `^12936,` magic row. |
| `d9a93eb1-ac7a-489c-bf8d-5e45162142dd` | `QM5_12932` | NEEDS-SOURCE: no approved card resolved and no anchored `^12932,` magic row. |
| `01bd8a9d-bd3f-4da5-a275-be9192a763ed` | `QM5_12944` | NEEDS-SOURCE: no approved card resolved and no anchored `^12944,` magic row. |

## Remaining work and tester-cost estimate

- Remaining at census: 308 completable builds, 102 needing source, 1 retire candidates, and 20 non-build rows requiring individual disposal.
- Tester cost is **NOT ESTABLISHED** from the recycle task table alone. A defensible estimate requires the symbol/setfile count and historical Q02 wall time for each completed build; no queue-capacity claim is inferred here.

## Guardrails

- No RECYCLE exit was bulk-applied; no Q02 work was queued.
- No approved card, news-staleness ceiling, risk setting, terminal, or AutoTrading state was changed.

