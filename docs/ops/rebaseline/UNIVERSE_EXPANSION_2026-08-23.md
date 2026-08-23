# Universe Expansion — OWNER-DEC-13036-XAU

Generated: `2026-08-23T18:49:10+00:00`
State DB: `D:/QM/strategy_farm/state/farm_state.sqlite` (**read-only mode=ro**)
Mode: **dry-run census; no enqueue in this section**

## Policy

Every non-retired/non-obsolete/non-superseded card with one exact built EX5 and at least one native-symbol Q02 PASS is expanded to every verified DWX index, `XAUUSD.DWX`, and the seven FX majors. Any `(EA, symbol)` with any historical `work_items` row is excluded. Q02 economics and windows are unchanged.

Single-symbol cards remain included under the OWNER decision, carry `CARD_SINGLE_SYMBOL`, and rank after every multi-symbol card. Within each cohort, native contiguous frontier ranks descending.

Queue placement is `BELOW_ALL_REBASELINE_BACKFILL`: the farm scheduler ranks these rows after both ordinary and recovery/backfill work. Claim-time `(EA,symbol)` serialization and the active-symbol cap remain enforced by `farmctl`/terminal workers.

## Census

- Wider active+built cohort (reported separately): **2901 cards/EAs**
- Starting cohort with native Q02 PASS: **992** (921 multi-symbol, 71 single-symbol)
- New untested candidate pairs: **9144**
- Apply-eligible after history/card/registry preflight: **7174**
- Q02 terminal-row median: **6.5133 h**
- Estimated Q02 factory hours: **59557.615 h** (candidate count × historical Q02 phase median; serial terminal-hour estimate)

## Counts per symbol

| symbol | family | candidates |
|---|---|---:|
| AUDUSD.DWX | FX_MAJOR | 834 |
| EURUSD.DWX | FX_MAJOR | 247 |
| GBPUSD.DWX | FX_MAJOR | 337 |
| GDAXI.DWX | INDEX | 766 |
| NDX.DWX | INDEX | 679 |
| NZDUSD.DWX | FX_MAJOR | 940 |
| SP500.DWX | INDEX | 817 |
| UK100.DWX | INDEX | 966 |
| USDCAD.DWX | FX_MAJOR | 908 |
| USDCHF.DWX | FX_MAJOR | 913 |
| USDJPY.DWX | FX_MAJOR | 536 |
| WS30.DWX | INDEX | 790 |
| XAUUSD.DWX | GOLD | 411 |

## Counts per symbol family

| family | candidates |
|---|---:|
| FX_MAJOR | 4715 |
| GOLD | 411 |
| INDEX | 4018 |

## Priority and apply contract

Apply requires both `--apply --i-understand-append-only` and `--max-rows N`. It updates only selected cards' `target_symbols`, appends missing active magic rows without slot reuse, regenerates the resolver, creates setfiles with `framework/scripts/gen_setfile.ps1`, validates each EA with scoped `framework/scripts/build_check.ps1 -EALabel <exact-label> -SkipCompile`, then invokes `farmctl enqueue-backtest --phase Q02` once per selected row. The farm DB is never written directly by this planner.

Machine artifacts: `D:/QM/reports/rebaseline/universe_expansion_2026-08-23.csv` and `D:/QM/reports/rebaseline/universe_expansion_2026-08-23.json`.

## First governed tranche

- Requested cap: **150**
- Selected/attempted: **150 / 150**
- Enqueued append-only Q02 rows: **150**
- Apply receipt: `D:/QM/reports/rebaseline/universe_expansion_apply_2026-08-23.json`
- Work-item IDs (150): `4f83551e-7bdd-483b-9502-9ba941b7f0d4`, `1d52c1da-3e27-4536-9b26-3bc9dae6e6cf`, `4d3012ed-10aa-41de-871d-ae34739367da`, `d6235376-2140-467a-bd66-14b686f4430a`, `f270506b-7f39-4096-a190-861a94bab8a6`, `e30ed71a-bd23-4d19-8462-9ddad1be8129`, `4c12f8fc-99ec-4ba5-be05-f47f16cd3278`, `e457457a-6a6c-4402-81e3-dbe3c11bd87a`, `9e398645-3c50-43cc-b4cf-7bd5b7dbd085`, `7db6bb82-de90-4f0b-b215-f64963c297a2`, `55b6d20c-3b4b-46de-81c4-bda4f5d6147c`, `053aba2b-f80f-47ad-9fc0-be0c075143e1`, `7e544606-c866-4084-b221-b8b391015b25`, `5015b0ca-daf2-4f4a-a506-6e07f60b445b`, `e4c126dd-6005-430d-96ec-d158b3d9a28a`, `d44981e4-f733-4ee4-ac6b-9cf43ca50676`, `3f9dae83-3bc3-4aa6-84ae-7bce52f33e70`, `cdbb1594-c647-43ae-909e-d9786fb2b7cb`, `cf46d9bc-c2f4-4613-87b6-b7aefe652bf8`, `ce050b92-d565-4850-8076-e7ea85179341`, `693536fc-5cc9-4cfc-a2c3-38c5d8af85df`, `102cc38d-1816-4792-92ff-098f618276de`, `23bd8743-0f02-4a3a-8051-7167ca0e6bcf`, `34062648-4be8-4ade-a2db-2d1d3b86faec`, `ea4d0f80-e6a6-4e98-94df-f615de4203af`, `434ace3f-29b7-48c6-bc81-ecf9b1ea49ec`, `a1665b4d-9e6c-4168-92b6-8c5529a36a40`, `2a82a2ee-d392-4688-b9d9-f4730a876aa1`, `63c6dab5-83b1-4693-8995-c19b7ae3ecce`, `9ca8f55f-ba75-4366-9822-bbebe162ac8b`, `0015ace3-6f60-4022-8e67-291fcb6bea6c`, `f7b8b05f-f5f4-45d5-bf5e-ea78fe27eed9`, `b10ddcf3-bcdd-4a35-a82e-a53e77b2246e`, `881e221e-d40e-428d-b1b0-b5edae612498`, `e3ac4f5c-09f1-4673-bae8-c1821dc2b5e3`, `80556163-45d4-4a97-8ccc-935b99fce4d9`, `353cb73d-b473-400e-935f-9b03545e12f1`, `4e622d8a-f7d0-4e76-999d-539a4d058601`, `c8278a8f-a52a-4b74-8b90-ab6b4e1a5fbe`, `fac8e062-8dfd-4987-a593-466e1aeed29b`, `46aa5a0d-a97d-48fb-ac08-ed30d6ddda3d`, `8ef5dc5b-3a27-4a1a-aa82-b686e55636a5`, `7b9587d9-c1c1-4ee5-a58d-dc90838499af`, `27d2a2ab-01d8-42c3-b270-53b42a7641c3`, `a401d921-1b8d-4b03-91ef-03f88ebb60db`, `309b8de7-04b8-4519-97e0-1b4c84baffe2`, `7f3cd452-aa1b-4ae4-a79d-9692d6348911`, `d2396791-b1cb-4b5f-a912-92cba9cd9386`, `03473a5f-2060-4817-bf10-3499464e7f41`, `58878809-a5f5-4dd7-8344-59e2a98fe41f`, `b4e9333b-321c-4d6d-adfe-0aa61a84d4f8`, `43a528da-a091-497c-afa7-b06211f98573`, `460f557b-e14b-4a57-ae2f-b14ff0dd48b6`, `541ad741-8c0d-49c5-a3af-237a1659811e`, `81731429-d8fc-4f67-a94b-f002480ea896`, `7f2b6f8d-bc55-4de0-b601-7a1365e5e0a8`, `ddf0a681-fec6-4d81-9147-014d1387931a`, `f32030e6-9e8d-4d85-8082-5b90ae874250`, `69409743-f62c-4898-9ddb-4f571c91a082`, `0db563ec-fe40-4e0e-8695-70bd4fe725be`, `e77649e5-4c99-4859-b574-170b867d4289`, `003ea866-fe33-422d-b68f-2989f2aec50c`, `05cb48ee-072d-4f50-b266-7329fd7ce1a5`, `33893ea6-91da-4a5e-b4f3-b9446c127603`, `60989602-9791-4015-becc-324418a5cf70`, `14e27fbb-ccec-48fb-a752-732b4692ac96`, `05a271cc-7b9c-44f5-8b48-2da17ccf88f4`, `d9be829b-20a3-4b27-bd7b-afaef5a3360a`, `8526030a-0a19-4261-8ee6-12a8379be02d`, `749d2fdf-e756-4de0-ae43-8f978497a2aa`, `4addc005-a814-4647-929c-6ded09f22766`, `def62654-8269-4179-b4ee-8690f823f313`, `d36a7f05-a6e6-47bf-bb98-75ae6a35e4ff`, `e5935952-9e9c-46d8-8dcc-3a7b8be97c95`, `dc03964e-836b-4ec2-ad6c-cc453ed284b6`, `355a6323-c297-476d-85f6-ddb0ab8a507f`, `b87d430f-adbc-46c6-816e-ea157ba13c5b`, `812c73d5-8153-4f57-b79c-f416f6997287`, `51b96aac-c6bf-465c-9329-278d5dcce9af`, `f6dcbb08-f22d-4aa5-8cb1-89d7fa635c18`, `b0551372-e0d8-4ca4-bdd1-c14cf7589bd0`, `cc81bcef-bc85-4e46-97d5-0ce7d06cffad`, `ad5f33e6-7a4b-4fdb-bcf4-89ed8f97995e`, `c629b7ae-8338-4fed-98f3-a5860b2971b9`, `55a54d41-73f4-4b39-9329-193a26926a40`, `f1417034-fe92-41fc-be9c-b65788c49928`, `2f437645-1176-45d2-93f2-459497e53e61`, `1eff82a9-83aa-4f5c-94b4-a1ed52de3050`, `afa8567d-5734-4410-a58c-9add54028ea7`, `8e6eb287-e808-4c9a-bc02-ecc094584069`, `24f14a87-1280-4e18-921f-c4a71d107f41`, `f00d340a-c898-43c1-b725-fb7f4cf2ea42`, `1ef32a81-1224-4df9-a820-b43b2779842a`, `dddceda0-b72b-488c-98a8-3dda87d8d94f`, `d3406957-e60f-4493-9a28-bdf7ff6a9658`, `4199da1c-c613-44f8-aab9-f186b339a3eb`, `b5fece65-45cb-4a1e-a0aa-24460c033a3a`, `6176df67-ab85-418c-a842-9f770da2edca`, `244eb428-db32-4e9b-8478-4fea6677ef3c`, `c40e1183-a8e0-488e-8fed-ee800ba2102b`, `a03e1662-3d1f-4316-900c-c207b48615b8`, `d250a6a9-4edc-4361-a9a5-0eb95ddfb65b`, `fd93ff84-c44c-4277-a96f-a23a820178a5`, `d7b20092-32b2-439f-84c2-2907225866ae`, `aeb8bdde-b69a-4d1f-a377-e1ba7bd009c6`, `93691b77-c6bf-4095-8629-140de1db8abc`, `357ae0c8-96f7-440e-8083-acde6809c746`, `7b115dc4-d1aa-40f4-a8a0-99b4dd1f2a77`, `ab9a6167-d773-4cd7-8217-de95856fef2d`, `a57678c8-a2d5-4a9a-810f-da02cd97108a`, `d38bf203-8ee1-4984-a6b9-efe46b6e862d`, `02bcff07-3856-4629-9790-7d4df4b7cfa7`, `52ed31a8-b78e-445a-9305-0c75a051df30`, `462e0a6a-b83f-410c-aaf5-af7cb24dd8b5`, `5ac94f79-3e1f-4614-83c1-ddd27153f551`, `26e076ac-40ce-4200-b45f-af568c0fc201`, `ebe7898b-bcac-4928-bb44-86d6feb6a7c8`, `2100572d-3fc3-4e03-85c9-35c189a58eaa`, `3865847a-7d49-434a-a91a-3e80c0848730`, `71264576-109c-4eef-9b94-e96208ad39e2`, `44343a08-b5f8-4d87-a424-2f9b3f1f2385`, `a664fb14-83c4-443d-9e08-c6a7e732fa54`, `149e8407-6f5b-4b77-9435-2a907af5b685`, `bd7620e0-df37-4a0b-aa12-14356751e260`, `2ca38fba-b2fd-4f28-a159-7c3aaba7548a`, `c119ba20-a810-4e5d-ac5c-58367d84d8ba`, `e3006d2b-0581-47e7-bd33-e4fab886125c`, `4b152092-10d8-4c01-ac9b-63a4cd5de9ec`, `369f445b-091b-4d18-9018-6abd4a5a9cc9`, `3c04f97f-f963-478e-863a-f83d1bf4dc45`, `4e07a606-a462-4546-a757-e8f49890bdb7`, `68238202-9bb5-45a8-8f31-7ba4abd79410`, `535ba474-1770-40fe-b556-ab8854d7b346`, `9b6f768b-2820-49e5-858f-6f0085da0c28`, `7f9c8d1f-138c-435f-92c0-c6e8449d1dc6`, `629c3902-a2fa-41ac-b48a-7c305c965839`, `b1ece7ae-a61d-424f-9830-f440dbaa4dfb`, `6958fb38-8268-4996-9574-88607d3851c4`, `f484345a-3b1b-415d-ad94-73e435ff261e`, `cc6c64da-8dd4-4a6c-b9ce-f4d59613e58a`, `b3d875de-911f-49bd-afa8-94b4789421cd`, `b1445444-a907-4c08-9cfc-1e6153eae306`, `c8ef72cc-f289-406a-bccf-da82ad19dfc3`, `a4bf4037-a327-42d8-908d-2926c1747407`, `1cf24492-a3dc-403b-87dd-5883f1e49158`, `2d60716b-fa8f-4f83-9664-f7adb4516406`, `ad576621-6708-45e9-b6fd-4f07b8a1aba6`, `211b75c3-d7c9-4f80-bfc6-cc8775b80db6`, `112b2ca3-25e9-42f9-815c-b7a2dfe78fe0`, `404a037c-6926-4f03-9bc0-ade16479c871`
