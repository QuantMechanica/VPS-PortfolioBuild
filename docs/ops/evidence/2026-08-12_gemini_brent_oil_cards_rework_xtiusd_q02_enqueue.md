# Brent Oil Cards Reroute to XTIUSD.DWX (WTI) Rework — Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Gemini 3.5 Flash

## Status

Following the Codex review (router task `ce9c3a4d-0ae0-4322-aa62-a27386f9008a`), which identified that all 23 Brent oil strategy source files hard-coded the `XBRUSD.DWX` symbol gate (causing zero-trade suppression under the `Strategy_NoTradeFilter` function when enqueued on WTI), the EAs have been successfully reworked:

1. **Host Gate Update**: Modified the executable host-symbol gate predicate in all 23 `.mq5` strategy source files to check for `_Symbol == "XTIUSD.DWX"` while retaining the `PERIOD_D1` timeframe constraint.
2. **Strict Serial Compilation**: Compiled all 23 updated `.mq5` files serially using `tools/strategy_farm/compile_ea.py`. All EAs successfully passed static validation and strict MetaEditor compilation (0 errors, 0 warnings).
3. **Guardrails Check**: The compilation wrapper automatically executed `validate_build_guardrails.py` for each EA's MQ5 and setfiles. All EAs complied with the 336-hour news-staleness maximum bound.
4. **Setfile Generation**: Generated WTI (`XTIUSD.DWX`) backtest setfiles using `framework/scripts/gen_setfile.ps1` with the fixed-risk backtest profile (`RISK_FIXED = 1000`, `RISK_PERCENT = 0`).
5. **Fresh Q02 Enqueue**: Created a new pending Q02 work item for each EA on `XTIUSD.DWX` in the SQLite database (`farm_state.sqlite`), following the `QM5_20288` enqueue pattern.

The previous stale Q02 rows remain immutable in the database history as evidence.

## Reworked Batch Artifact Hashes and Work Items

| EA ID | EA Slug | MQ5 SHA-256 | EX5 SHA-256 | Setfile SHA-256 | Q02 Work Item ID |
|---|---|---|---|---|---|
| QM5_12841 | `brent-thu-prem` | `ee771506d2` | `007c169a8c` | `970e36c012` | `f485da87-bc08-47d4-9251-6a3f8ebd4fb9` |
| QM5_12849 | `brent-tsmom12m` | `d72f373782` | `c9166d7a34` | `a4851b26dc` | `9764714f-64b0-4f7e-a013-0368fb75828f` |
| QM5_12853 | `brent-may-prem` | `72fd14cc9b` | `8c1c6b4a33` | `846dc8e8ca` | `3e238b68-0d78-4350-8b5e-fb1484b7086c` |
| QM5_12854 | `brent-dec-fade` | `6a2de1ffcb` | `a8c8d45942` | `6193b64a3a` | `4377934e-2eb2-4086-93f6-c5aa80aa76bc` |
| QM5_12855 | `brent-nov-fade` | `07c82d1358` | `1e14130427` | `3d40f88402` | `a16ebbce-4ecc-482b-af07-8ec5e307430c` |
| QM5_12856 | `brent-mon-fade` | `65bab71cfa` | `0724db119b` | `c5b3a90268` | `ea187625-d672-40c4-94f4-972da9fab9da` |
| QM5_12859 | `brent-52w-anchor` | `067ae1b988` | `954cb7441d` | `463ed60983` | `64719c77-89c0-4430-818a-cb299b5c4d46` |
| QM5_12865 | `brent-fri-prem` | `78a9e24a3c` | `3a0a9607d8` | `fbfd68340d` | `806f0949-9ffa-4a9c-b7d7-b84b3e6fd88c` |
| QM5_12866 | `brent-apr-prem` | `f731e37112` | `af97387395` | `e67154ac87` | `4cfb795a-cb94-4591-ae39-572751008eb7` |
| QM5_12871 | `brent-jan-fade` | `bc60cce179` | `3ab07c02a6` | `bc1fd973d4` | `968b25e2-26ba-4719-8a35-7859088e12f0` |
| QM5_12911 | `brent-aug-prem` | `a58b38e905` | `eb339ebaf3` | `8790043a46` | `a0675038-ceb1-48bb-b238-efd671c863b3` |
| QM5_12976 | `brent-mar-prem` | `4ccc40525d` | `b63b387ebf` | `1079fc43cd` | `11d73911-1efb-4269-a6eb-2a6d00fc7377` |
| QM5_12980 | `brent-6m-rev` | `ec12b9ec53` | `a387f6c7a4` | `0360702b55` | `1814e68f-16ae-40cd-a324-ac6ccdfbd7ed` |
| QM5_12981 | `brent-febsep-prem` | `82f735fc53` | `e6c959dcaf` | `b45e7db671` | `b305045f-c503-4fbc-807b-264f0912c03b` |
| QM5_12982 | `brent-sep-prem` | `297aa7f7a4` | `6ceb9ad2ef` | `5411012390` | `8617e683-85d9-4c25-8019-e7d067ec9c84` |
| QM5_13052 | `brent-jul-prem` | `40cb4afbb3` | `c4485475e5` | `2553c4ec11` | `5fb80ee6-65cd-4b49-bb0e-8b1ba1eaf91a` |
| QM5_13054 | `brent-tom-mom` | `326b188c2b` | `2e65488fcc` | `d834b193a7` | `b43f34fe-53e1-4e4e-9d78-d88b6a2fdc2e` |
| QM5_13055 | `xbr-1w-mom-vol` | `c5bee71fe5` | `c9ef294719` | `30960b0066` | `4e336b0b-df23-4fff-8bce-c1076816c3fc` |
| QM5_13056 | `xbr-1w-rev-vol` | `3bae321d4c` | `f2d3223a12` | `39609564fa` | `5b110cba-fc90-46bd-9489-2c6f4fc03551` |
| QM5_13061 | `brent-jun-prem` | `d77faf1e6c` | `fd6b35296b` | `581b6da760` | `c1edaba7-bfd1-4fa5-9131-522ad46d8ccc` |
| QM5_13072 | `brent-feb-prem` | `c213788b2c` | `0d6c4d24bb` | `3c33a3c8ed` | `9a1d0a02-89ea-42d2-8a09-f61d4dc232ed` |
| QM5_13091 | `xbr-vrp-proxy` | `ff1adcf79b` | `4703c9da1a` | `33190c73ae` | `fa630a9a-df56-41d6-93db-f2c8f732b52b` |
| QM5_20171 | `brent-tsmom3m` | `3c605dbcae` | `5d98078fab` | `0a0a65fefd` | `ceb0ed8e-e118-4b64-867a-9ff3e8870915` |

## Safety Boundary

- No manual terminal initialization, optimization, or live execution was conducted.
- The factory mutation lock was respected during database updates.
- All modifications are strictly committed to the canonical checkout in the `agents/board-advisor` branch, preserving non-associated file system states.
