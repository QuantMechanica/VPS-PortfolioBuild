# Q09 sealed-plan hold recovery — task 83b4e208

- Router task: `83b4e208-e477-41f1-8e19-e4b124dd3717`
- Execution: 2026-08-25 21:50–22:10 UTC, canonical checkout `C:/QM/repo`
- Branch: `agents/board-advisor`
- Code commits: `3fa0d567e` (immutable plan successor generation),
  `645ccbb5a` (supersession evidence binding)
- Pre-mutation database backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_q09_plan_successor_20260825T215032Z.sqlite`
- Backup SHA-256:
  `025595385D23DF8F6A599DA696D9A3F7A549F42B6D71F543B8AD2B5529244037`

## Result

The original census of 45 active `Q09_AWAITING_SEALED_PLAN` holds is fully
classified below. Active holds fell from 45 to 43 during this execution:

- replacement row `7ba6e027-c462-4364-be83-da0447a9ec41` is now
  `RUNNABLE_BOUND` against regenerated Q08 row
  `5692fd6b-89a5-4b8e-86db-5aa3cacb0f30`;
- historical row `92158087-2aa5-4a72-9f92-7e68caf07395` is preserved as
  `done/SUPERSEDED`, with the authenticated replacement run plan in
  `evidence_path`;
- 26 exact append-only Q08 successors were created from authenticated Q07
  regenerations; at the final action snapshot one was active and 25 pending;
- the two genuine launch faults received one append-only retry each;
- five pre-existing Q07 regenerations remain pending under the fleet-wide
  Q07/Q08 active cap of two;
- deterministic gate outcomes were not replayed, and no gate criterion or
  historical verdict was changed.

This is a measurable `45 -> 43` hold reduction (`-2`, `-4.44%`) plus 28 new
governed recovery rows. The remaining holds are waiting on explicit work-item
IDs or have a terminal recommendation; none is an unexplained plan-authoring
collision.

## Root causes and fixes

### Immutable plan collision

All 27 rows initially reported as `Q09_AUTOSEAL_BUILD_PLAN_FAILED` shared this
exception:

`RunnerError: existing planned artifact contradicts immutable content: .../q09_contract_v3/input_manifest.json`

The autosealer correctly refused to overwrite an authenticated plan, but it
reused the original output directory after calendar/include-closure inputs had
changed. `_build_q09_autoseal_plan` now:

1. authenticates the pre-existing plan and manifest;
2. requires exact work-item, Q08 evidence, setfile, EX5, lineage, and contract
   identity agreement;
3. hashes those identities plus the calendar, include closure, settings, and
   windows into a successor generation key; and
4. writes the refreshed immutable plan below `q09_contract_v3/successors/<hash>`.

An identity mismatch remains fail-closed. Re-running the census after this fix
converted the opaque 27-row authoring class into the actual bind classes: 23
missing current Q07 evidence, three absent Q07 lineages, and one supersession
write defect.

### Supersession evidence defect

The already-regenerated QM5_10939/XAUUSD replacement bound successfully, but
retiring its older held row attempted a terminal `SUPERSEDED` transition with
no `evidence_path`. The production database guard rejected that write. The
supersession helper now authenticates the bound replacement plan by file hash,
stores its path/hash in the historical payload, and uses that plan as the
terminal evidence path. No sentinel or weakened database guard is used.

## Complete 45-row census and disposition

`Q08 successor` means a new append-only row whose payload records both the
exact Q07 predecessor and the preserved historical Q08 row.

| Held Q09 row | Pair | Class | Action / durable ID |
|---|---|---|---|
| `9812fc7b-faf3-42c4-add3-81f25f70a8fd` | QM5_10114 / SP500 | transient Q07 launch fault | Q07 retry `504d0bf7-6f8f-4302-aba1-ffbd5723af6e`; preserves failed `fba8d002-2b84-47b2-be10-b03d8a750c45` |
| `1773b453-83d7-40e2-a00f-1dcd922905ca` | QM5_10115 / GDAXI | regenerated Q07 ready | Q08 successor `b9564ceb-2674-4067-aaf1-163a2640fb89`; Q07 `517ebc7b-9835-4cc3-8af9-6281d0bf1cb4`; preserves `0ed64130-4131-4575-8438-cb3bef1641f0` |
| `04a3fe87-42a7-4600-bfea-dbc3fe8af2dd` | QM5_10123 / XAUUSD | regenerated Q07 ready | Q08 successor `6b89e8a9-6749-4c3d-9f62-828cb022db7c`; Q07 `3c8b743c-8c0e-4477-b12a-ba3e94afb614`; preserves `a370af27-1f45-4d21-834e-aad479a538b1` |
| `2ac15e24-869c-471f-bd4d-39cbd2cfc2c7` | QM5_10128 / XAUUSD | regenerated Q07 ready | Q08 successor `3179241b-96f0-4abe-97e6-5c5fcdb7bf69`; Q07 `a110f85e-7164-48d3-9efd-b675e52e11a6`; preserves `4af1eb52-bdc7-4bec-9711-18f19d318c91` |
| `6ea0cd9f-5b65-4135-bb1e-4ec39c72116b` | QM5_10145 / SP500 | regenerated Q07 ready | Q08 successor `7ed3c1bf-1eae-48c4-a72d-0a47a31b8f23`; Q07 `0edd8fd6-ed6c-42b0-a602-2dc9ef3b114c`; preserves `a3e17e53-ff08-4794-9073-ef5af719e2ef` |
| `360a3045-8d6c-48f1-9da5-993f3a1b4804` | QM5_10145 / XAUUSD | regenerated Q07 ready | Q08 successor `48778bc7-e7e0-499a-8266-4c0c1c50e8a5`; Q07 `00f84670-6610-4d41-bf32-bb28825f7516`; preserves `01e8d662-6a32-41ce-9028-031250d5c863` |
| `15cf7483-2a99-4047-8005-7327ff608a18` | QM5_10146 / AUDUSD | regenerated Q07 ready | Q08 successor `de21a2ad-e30b-445f-bcc5-2ad649180eed`; Q07 `08e7d4fb-a2ae-419a-b424-b8cc4fd4403c`; preserves `23c63618-67f3-4235-beed-b8dd61a5e6c7` |
| `ce131b6f-4805-4b08-8781-b6b676784224` | QM5_10183 / XAUUSD | regenerated Q07 ready | Q08 successor `4032f22e-47d1-4bfc-b974-0d22bfb7841e`; Q07 `35532806-d27e-48f2-ab1b-3fc3d14f4922`; preserves `11e4572f-183f-450e-99a3-0789489a10cb` |
| `b321eb30-3493-47cb-b958-c49bf32837ad` | QM5_10403 / XAUUSD | regenerated Q07 ready | Q08 successor `7fd4caf6-b599-4833-a431-a132a404b60b`; Q07 `831c9521-ce8c-4cd7-983e-b53b5c15cd69`; preserves `a4d1c0a6-7692-44c3-b633-6efc79891e02` |
| `2dd1aef8-91b6-4234-8972-75c6aec96ac7` | QM5_10513 / XAUUSD | regenerated Q07 ready | Q08 successor `da5dc579-3d0a-4591-80e8-dc64eb52d81e`; Q07 `ec0344ec-c74b-4859-afde-5495af712af3`; preserves `375d7f67-fb0e-4793-ac60-7bebb4f9986b` |
| `99f28ea8-582f-4fc7-859b-48766eab6f47` | QM5_10692 / NDX | regenerated Q07 ready | Q08 successor `14fbb01c-0bc5-4387-baa9-8646a3252bdf`; Q07 `64c42802-4c1a-443c-a762-f2993f0e846c`; preserves `5f01dbc3-87c6-4198-ad0d-de9d24c9b70d` |
| `cdfc4ddc-2f82-4321-ac36-876202eadcad` | QM5_10706 / GBPUSD | regenerated Q07 ready | Q08 successor `7855588a-9ff8-4896-8d8d-16e1fdc25f72`; Q07 `81cd341c-a2c1-4c18-9ec6-6b85f0226080`; preserves `335d9197-0fef-4dbb-809f-36f616c84e78` |
| `57d8bacd-2805-45a6-ac51-156e22bb3a65` | QM5_10815 / GDAXI | Q08 evidence file absent | Terminal recommendation: OWNER-authorized current-identity rebuild/requalification; do not reconstruct or overwrite missing historical evidence |
| `49a059da-82ab-4835-9c46-f18ba9b94dcf` | QM5_10847 / GDAXI | no Q07 lineage; prior Q05 economic FAIL | Terminal recommendation: retire held row unless OWNER commissions a new candidate; do not bypass Q05/Q07 |
| `f11985e3-b19e-4449-822d-42d437757899` | QM5_10848 / XAUUSD | regenerated Q07 ready | Q08 successor `cb91ed40-bfa9-4a34-ba2e-378100e4cb24`; Q07 `e0f6453a-0892-46b9-b680-ea281fc64a43`; preserves `be9beb50-8353-49d5-bba5-0db04d24e51a` |
| `9c6ca9c7-a215-40e8-ab5c-d7628c74355a` | QM5_10911 / GDAXI | regenerated Q07 ready | Q08 successor `55256268-50f8-4d94-8d9a-83652c64b013`; Q07 `cc0cdf9e-b053-4e12-9199-856e5a94ce66`; preserves `4701b0c0-54af-4b25-a468-ab684b1530eb` |
| `a25b2479-8455-4156-af58-a1298e55e6f7` | QM5_10938 / GDAXI | regenerated Q07 ready | Q08 successor `a99a58a7-9b27-4c9d-8d8c-547ea1391387`; Q07 `902f7307-d85c-438c-91bc-e1eb35f9808b`; preserves `96ba6c17-945d-45f4-b3d6-3a2adad0ec58` |
| `9639a773-b913-40a2-b12f-128a027aec98` | QM5_10939 / GBPUSD | deterministic Q08 invalidity | `8234812d-b9ff-4652-b4a3-48bcdc41c2b5`: degenerate neighborhood baseline; terminal recommendation is repair-as-new-candidate or retire, not identical replay |
| `92158087-2aa5-4a72-9f92-7e68caf07395` | QM5_10939 / XAUUSD | historical stale dependency | Released; preserved `done/SUPERSEDED` by `7ba6e027-c462-4364-be83-da0447a9ec41` with authenticated plan evidence |
| `7ba6e027-c462-4364-be83-da0447a9ec41` | QM5_10939 / XAUUSD | regenerated dependency bound | Released; `RUNNABLE_BOUND`, Q08 `5692fd6b-89a5-4b8e-86db-5aa3cacb0f30`, eight-cell sealed plan |
| `c9c3c2a2-335f-4053-a2cb-5ce7c5c6ae04` | QM5_11124 / SP500 | regenerated Q07 ready; old Q08 evidence absent | Q08 successor `7b564fb0-433f-41ef-be1a-6adc0249b71e`; Q07 `b7726d9d-6068-4dc7-8d97-595314ad07c3`; preserves `9611dbac-49e5-44fc-b86f-a66b38b5f031` |
| `3888c02c-49c7-4432-8615-f96dc5513e9c` | QM5_11124 / WS30 | regenerated Q07 ready | Q08 successor `003521a7-f6d9-411f-b3e1-28f25fb89590`; Q07 `209f2f40-3f01-4c4d-9fff-45d4f123dcd9`; preserves `b3fe5bc3-cdcd-420d-b68e-2da748e641cd` |
| `30584122-b7b3-41eb-8e1a-b03517554d4d` | QM5_11421 / EURUSD | deterministic Q08 invalidity | `9d183609-3721-4a11-94d0-b0987ae43a30`: invalid perturbation neighborhood and insufficient distinct PBO configs; terminal repair/retire recommendation |
| `08fe4173-07d9-47e1-97e9-a76b1159ad94` | QM5_11476 / USDJPY | no authentic Q07 predecessor | Terminal recommendation: OWNER-authorized current-identity requalification from the last valid upstream gate, or retire |
| `f290aa11-881e-49ff-a336-7b93ebeef2a2` | QM5_11708 / EURUSD | Q07 regeneration in flight | Existing Q07 `f35e08ce-95f0-4a8a-8c65-f6deac55650d`; enqueue Q08 only after authenticated PASS |
| `7bbeef66-becf-4bd3-aa5c-1d00bde262d8` | QM5_12567 / XAUUSD | deterministic Q08 invalidity | `c089a98d-2879-4151-8bb4-fbe722cb1b46`: insufficient valid perturbations (and PBO 62.857%); terminal repair/retire recommendation |
| `5302ac48-3123-4327-8d8a-506fffeee365` | QM5_12623 / XAUUSD | regenerated Q07 ready | Q08 successor `5fd45ac3-4743-4671-85dd-e24903064919`; Q07 `1505ff12-34b9-4142-865e-869537fbd597`; preserves `adff323e-5ff4-4af2-852a-7ffb12bdfd64` |
| `e6aaf4b4-008a-40f1-96da-4a00f2822e13` | QM5_12823 / USDJPY | Q07 regeneration in flight | Existing Q07 `5ab267f0-75dd-4e74-8887-7ad12cadcbff`; enqueue Q08 only after authenticated PASS |
| `84608819-5253-4df0-871c-6eb4750c3435` | QM5_12831 / custom XTI-AUDUSD | Q07 regeneration in flight | Existing Q07 `9398e0b3-e43c-4a9d-9c86-6474c9cbf48a`; enqueue Q08 only after authenticated PASS |
| `cc670aa2-c9b4-4605-aea3-a925afb238bf` | QM5_12847 / NDX | regenerated Q07 ready | Q08 successor `00363e8b-653c-497a-bd73-7b899d192821`; Q07 `d5484501-e425-4c1d-941f-afa18706937d`; preserves `2f4a4f40-80c2-4973-9909-d20dcad412d3` |
| `00f61d53-d479-4395-ac24-c36d92b8a024` | QM5_12915 / SP500 | regenerated Q07 ready | Q08 successor `73c2f8d8-d13d-4fec-ae65-105d62fedb35`; Q07 `e78721f3-49b6-4e2d-8767-063deaa14d6d`; preserves `591f7453-2d44-4ae3-9cd9-8378bf4f8de7` |
| `5b3d7bb3-9592-49d7-a457-9655a4d12566` | QM5_12969 / USDJPY | regenerated Q07 ready | Q08 successor `f14ad921-721e-413d-a2de-6506ceaf8483`; Q07 `e30dbad3-d870-48b9-90b6-9dcf0af65abd`; preserves `7191fc3f-7bce-4881-835d-ea04a50a69b3` |
| `1cff016c-d25c-4723-a892-6bc53bfafa0b` | QM5_12989 / XAUUSD | current source/setfile closure drift | Terminal recommendation: OWNER-authorized rebuild and full requalification; no evidence rebinding |
| `36304cfd-02c5-48e5-9502-a67f253ac6d8` | QM5_13013 / NDX | Q07 regeneration in flight | Existing Q07 `68875929-5efa-4341-aa2c-f0de95657950`; enqueue Q08 only after authenticated PASS |
| `bf7557c3-d9b5-4105-9762-0803ec60512e` | QM5_13108 / XTIUSD | regenerated Q07 ready | Q08 successor `78c6c13c-45fe-43ab-90ef-2777bc96419c`; Q07 `88d316c5-481a-4687-88d9-70530b108777`; preserves `37894f9c-0a12-4e40-ac36-ba1fc8e56b88` |
| `aa80274f-fb46-4432-b47e-6fb2bf28c9a2` | QM5_13128 / NDX | current source/include closure drift | Terminal recommendation: OWNER-authorized rebuild and full requalification; no historical verdict rewrite |
| `72f7d4c1-aa87-4098-9c5e-545b5b93b249` | QM5_13213 / USDJPY | Q07 regeneration in flight | Existing Q07 `002ccb7f-d17e-473c-bdbd-cca20dccc535`; enqueue Q08 only after authenticated PASS |
| `84c6e9e9-76a8-4cd4-87b4-647d7fad3c1a` | QM5_13301 / GDAXI | deterministic Q07 economic FAIL | `e04ed006-ec2b-4d07-971f-b62fde225510`: all seeds below trade floor; terminal retire/new-candidate recommendation |
| `d81d9ea8-b802-4c38-8fc9-8bdbab6ef75c` | QM5_1556 / XAUUSD | transient Q08 launch fault | Q08 retry `ea0cd059-07f1-47c0-ab19-42d97f49fa04`; preserves failed `5a396f28-70f9-4fe1-81fc-645a1df4eae8` |
| `2604a1f0-4f58-4597-89ef-432af9093131` | QM5_1567 / EURUSD | build/current-identity chain incomplete | Terminal recommendation: OWNER-authorized full current-identity requalification through Q08; a newer compile alone cannot authenticate the stale Q08 row |
| `ab2fd18a-57a8-41d1-ab17-d3110505e708` | QM5_20047 / XTIUSD | regenerated Q07 ready | Q08 successor `05e1f833-3d9c-43cf-8bf0-ed20a5709105`; Q07 `719a1b21-52c6-47ac-80d4-e06e5c8e7508`; preserves `0ac2f29e-7d8c-4f3c-9b0b-cdf20db3de0e` |
| `05ac13bc-cd1c-4a78-bba3-42e5d4face89` | QM5_20048 / XTIUSD | regenerated Q07 ready | Q08 successor `3ee5c53c-6fe5-4776-9baf-a3ec9600e626`; Q07 `bf54ff43-b0c4-4e48-a290-25c3304ec28f`; preserves `beae922f-84e9-4850-8325-e6fdae993c6a` |
| `e8722c6b-9009-48a8-86b2-43df7812cfc6` | QM5_9403 / GDAXI | regenerated Q07 ready | Q08 successor `3a409d6d-99df-40fc-b6e7-4fa771120fdf`; Q07 `354dfecb-7fa9-4df7-8372-40ad6edf04ed`; preserves `577cc034-e74e-4914-ba36-57fa0414ad9e` |
| `11874a1f-ab1c-42aa-81b6-678fc79135f6` | QM5_9502 / SP500 | regenerated Q07 ready | Q08 successor `6a3a3f3a-2db6-4551-ae2f-ab64da8b4e92`; Q07 `dc69608b-2563-4b93-adb7-6080418b8a99`; preserves `87da806d-0f8a-4faa-be55-850f1644ed83` |
| `b4ebfe77-a0d0-407a-8ac3-299ad96502e4` | QM5_9503 / USDJPY | regenerated Q07 ready | Q08 successor `6c4075b3-0a44-4d32-bf25-69124fb31932`; Q07 `28fffbdb-22b9-4159-b768-21b163c82fb1`; preserves `196efa7a-d01a-4d2d-8416-d6d189ca16dd` |

Count reconciliation: `2 released + 26 Q08 successors + 5 existing Q07 pending +
2 transient retries + 4 deterministic terminal outcomes + 6 rebuild/OWNER
recommendations = 45`.

## OWNER red-decision template

No action is required for rows already bound or queued. For the ten terminal
recommendations, OWNER should choose one of these explicit append-only paths:

1. **Retire** the held candidate where the current evidence is economic or
   mechanically invalid (QM5_10847, QM5_10939/GBPUSD, QM5_11421, QM5_12567,
   QM5_13301).
2. **Commission a new candidate/repair card** if mechanics should change. The
   repaired candidate starts a new identity and full gate chain; it does not
   overwrite these outcomes.
3. **Authorize full rebuild/requalification** for missing evidence or source
   closure cases (QM5_10815, QM5_11476, QM5_12989, QM5_13128, QM5_1567).

Gate thresholds, evidence, and historical verdicts remain immutable under all
three choices.

## Focused verification

- `python -m pytest tools/strategy_farm/tests/test_q09_news_farmctl_integration.py -q`
  -> `25 passed in 24.24s`.
- Positive collision test proves an authenticated prior plan produces a
  deterministic hash-scoped successor and preserves the prior files.
- Negative collision test changes the primary EX5 identity and proves the
  successor path refuses the mismatch.
- Supersession test proves the old held row becomes `done/SUPERSEDED`, binds
  the replacement plan as evidence, and releases its hold.
- Runtime successor audit found exactly 26 Q08 rows whose `rerun_reason` starts
  `83b4e208 Q09 sealed-plan recovery:`; each has one exact Q07 predecessor, one
  preserved Q08 target, and a current EX5 SHA-256.
- Final action snapshot: Q07/Q08 active count `2` (`Q07=1`, `Q08=1`), equal to
  the fleet cap; pending rows remain claim-selectable without displacing short
  work.

## Safety and rollback

- No terminal was started manually, no active test was interrupted, and
  AutoTrading/T_Live were untouched.
- No router routing command was used.
- All runtime changes are append-only. Successor rows and sealed plans are
  evidence and must not be deleted during rollback.
- Code rollback is by reverting the two scoped commits on
  `agents/board-advisor`; do not reset, merge, or advance main.
- The database backup above is forensic recovery evidence, not authorization
  for an in-place rollback over newer farm work.
