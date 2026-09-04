# News-gate append-only readjudication, wave 1 (2026-09-04 01:59-02:02Z)

Authority: OWNER-DEC-NEWSGATE-AE-20260904 (receipt `decisions/2026-09-04_owner_receipts_briefing_2_4.md`), rule (e) merged as 441b3740a5, CLI `farmctl readjudicate-news-8cell` (wf_7c3a5e11-c3d verified). No tester run; the source rows are untouched; each successor is a `Q10_NEWS` row with verdict `CONFIG_LOCKED` carrying full provenance (`readjudication_of_work_item`, source/successor aggregate sha256, rule commit).

Result: 32 successors minted; 1 row excluded (historical lane `Q09_NEWS`: QM5_1354/XAUUSD 317b916e, reason `readjudicate_source_phase_not_current`). Four first attempts returned no JSON (transient) and succeeded on retry with no duplicate (successor count = eligible count).

| # | EA | Symbol | source (REVIEW) | successor (CONFIG_LOCKED) | created | rule commit |
|---|---|---|---|---|---|---|
| 1 | QM5_41219 | XAUUSD.DWX | `1da33661-ae52-442d-babd-8c73c3d9f9c6` | `80107fb5-70fd-44d3-9caa-06a84101171c` | 2026-09-04T01:59:48Z | `441b3740a5` |
| 2 | QM5_10700 | XAUUSD.DWX | `0c247960-d1e2-4731-a076-b60843d6aa83` | `bb299ec1-25ff-4ab3-95ec-65906e7cf987` | 2026-09-04T01:59:49Z | `441b3740a5` |
| 3 | QM5_11910 | NZDUSD.DWX | `bdae4b44-1cf8-43ff-91de-abf6735242b2` | `a5660f05-ba8d-41c2-acdb-41192f9a8006` | 2026-09-04T01:59:50Z | `441b3740a5` |
| 4 | QM5_12710 | XTIUSD.DWX | `9a2e9380-aeab-4096-b1cb-c07fbdc30752` | `2615606f-2e3b-4c24-91bc-a94dc02cb098` | 2026-09-04T01:59:52Z | `441b3740a5` |
| 5 | QM5_41221 | EURUSD.DWX | `8bd4a1be-63fc-48f1-8b06-eaf77c32010f` | `b1a60270-b481-4631-a152-e94b1daed18d` | 2026-09-04T01:59:53Z | `441b3740a5` |
| 6 | QM5_13213 | USDJPY.DWX | `177f73c4-f952-442a-ad4a-6805abe83155` | `6771f953-a639-4073-984e-bbfdf2cdb3fb` | 2026-09-04T01:59:55Z | `441b3740a5` |
| 7 | QM5_11421 | EURUSD.DWX | `23282266-7853-411f-936f-4c84675682a1` | `485a00f2-1cf6-4546-8e5d-8110095489d8` | 2026-09-04T01:59:57Z | `441b3740a5` |
| 8 | QM5_11708 | EURUSD.DWX | `591322ff-0a3c-44e7-bc88-5aca9cbd79aa` | `532698ec-d517-4efb-99f0-82883047b662` | 2026-09-04T01:59:59Z | `441b3740a5` |
| 9 | QM5_13013 | NDX.DWX | `e84c4ff8-f66d-4ed7-b800-567b8be42e2c` | `04b45fed-3d11-48b6-ad5d-357d9580c438` | 2026-09-04T02:00:01Z | `441b3740a5` |
| 10 | QM5_21501 | USDJPY.DWX | `7d24d056-822b-42a5-bba3-50e7d9f92713` | `c3620f91-aa87-443f-aeff-ec0be1b54948` | 2026-09-04T02:00:07Z | `441b3740a5` |
| 11 | QM5_9641 | WS30.DWX | `068afd3f-a36e-4a82-ac1a-3c57dc4f5efd` | `c33ba35e-ed26-44b8-9a3b-2fa5f7a44529` | 2026-09-04T02:00:11Z | `441b3740a5` |
| 12 | QM5_11294 | GDAXI.DWX | `1a6aa6bf-c747-449c-ab2a-0d082b497522` | `82a932b1-0a14-4945-a32c-85e071e299ce` | 2026-09-04T02:00:14Z | `441b3740a5` |
| 13 | QM5_20266 | XTIUSD.DWX | `42e4b18c-4f1b-4c3f-8129-1265fa42dd7b` | `f7b49d75-61ec-42eb-92e7-a3b029bb5df8` | 2026-09-04T02:00:30Z | `441b3740a5` |
| 14 | QM5_11660 | NDX.DWX | `ce9d7a9e-2494-4eec-ac36-06e21084ba92` | `f489a2c9-a354-4ee0-80a3-44227a2a7931` | 2026-09-04T02:00:32Z | `441b3740a5` |
| 15 | QM5_10706 | GBPUSD.DWX | `025fe79a-d687-4242-bcb3-1522637dfcde` | `75d2dfd6-a9a9-46dc-b222-9c5ad5398732` | 2026-09-04T02:00:34Z | `441b3740a5` |
| 16 | QM5_20048 | XTIUSD.DWX | `064d148e-e3d5-4b42-bffa-b46bb15c07d7` | `98fb689e-bef4-4ab3-89c6-62eaa96c06b8` | 2026-09-04T02:00:36Z | `441b3740a5` |
| 17 | QM5_10911 | GDAXI.DWX | `585048cb-1168-423a-ba63-2df84eedfbf2` | `d05febe9-4774-44b7-bdab-301129f502f8` | 2026-09-04T02:00:40Z | `441b3740a5` |
| 18 | QM5_10513 | XAUUSD.DWX | `66af966d-f123-4f8c-be21-27354394cee9` | `8f44818e-a4f7-4e42-9417-60e77afe86c6` | 2026-09-04T02:00:44Z | `441b3740a5` |
| 19 | QM5_10403 | XAUUSD.DWX | `cf18f426-1ba8-4479-92ee-b7e14b85d5de` | `77482986-702b-46c6-acf4-35d84bf7de29` | 2026-09-04T02:00:47Z | `441b3740a5` |
| 20 | QM5_21507 | XAUUSD.DWX | `0d58a55a-4cb1-4d99-b10e-31af3b625f51` | `609f7c57-ff67-45ee-8efd-9d8df8fc913a` | 2026-09-04T02:00:48Z | `441b3740a5` |
| 21 | QM5_10145 | XAUUSD.DWX | `c279f5bb-f731-409f-bef0-5e2aae6cdfae` | `13e9d6f1-1533-4d38-a885-205cd5d69217` | 2026-09-04T02:00:50Z | `441b3740a5` |
| 22 | QM5_13054 | XTIUSD.DWX | `8f760c32-a6d2-4088-9106-d406de466fbb` | `332b52a7-cdc7-443b-ac6c-c358a3717fbe` | 2026-09-04T02:00:51Z | `441b3740a5` |
| 23 | QM5_11881 | GBPUSD.DWX | `dddcd4a5-5fc3-4568-9527-73286819a1a2` | `b715d987-535c-4413-9047-4dcf2cbce6ce` | 2026-09-04T02:00:53Z | `441b3740a5` |
| 24 | QM5_1537 | XAGUSD.DWX | `42b0c995-7fac-415d-a08e-80581da2db33` | `463a29c4-2ef0-40d2-baef-fa5a4727f073` | 2026-09-04T02:00:55Z | `441b3740a5` |
| 25 | QM5_21502 | XAUUSD.DWX | `ccef6e62-983f-456f-927f-bd2d59e4d2bf` | `ff927169-074c-4bfe-bf68-bff503d3d80c` | 2026-09-04T02:00:56Z | `441b3740a5` |
| 26 | QM5_11294 | XAUUSD.DWX | `f07c2e1f-78da-437b-a313-0c8110bcc1d8` | `231e4bc3-6ef9-4eca-9a44-a432990b4476` | 2026-09-04T02:00:58Z | `441b3740a5` |
| 27 | QM5_20086 | NDX.DWX | `bf2dab64-017b-4a67-9c0b-238c562c7077` | `60069407-65da-4199-86bb-f3e1a8f8b8de` | 2026-09-04T02:01:00Z | `441b3740a5` |
| 28 | QM5_20086 | EURUSD.DWX | `daf3212d-e895-46c3-81dc-2bbc17585d0c` | `34cb735f-c7bc-42e8-8315-aef2d3953e1b` | 2026-09-04T02:01:02Z | `441b3740a5` |
| 29 | QM5_21505 | XAGUSD.DWX | `f9a94c2d-98a3-4edc-ade5-f9ce5940da41` | `21859cc5-0c13-481a-a769-b38be9e4fd91` | 2026-09-04T02:01:34Z | `441b3740a5` |
| 30 | QM5_11422 | USDCAD.DWX | `21eb42e1-5107-4033-b9f6-a97c1edc15d1` | `74fec478-4823-4d84-a9a1-41319407197d` | 2026-09-04T02:01:36Z | `441b3740a5` |
| 31 | QM5_12855 | XTIUSD.DWX | `d8ffeba1-6fc8-467c-ad6b-e4c280493879` | `22baed14-42a0-4f9c-9e8b-96631408c523` | 2026-09-04T02:02:08Z | `441b3740a5` |
| 32 | QM5_12849 | XTIUSD.DWX | `c0fda6f1-84f0-49eb-846d-a7f729dcf984` | `5f23b9ad-db71-4416-b4b1-6c2f66a4970c` | 2026-09-04T02:02:10Z | `441b3740a5` |

Watch item: QM5_10700/XAUUSD already relocked through its expansion child 152e8d29 (00:58Z, Q11 PASS e4097945, Q12 40e69c26 pending); its readjudication successor bb299ec1 is redundant. If the pump mints a second Q11 for that pair it is to be held as a duplicate (append-only, no deletion).
