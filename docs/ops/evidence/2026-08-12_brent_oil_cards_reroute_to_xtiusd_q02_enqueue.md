# Brent Oil Cards Reroute to XTIUSD.DWX (WTI) — Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Gemini 3.5 Flash

## Status

Following the retirement of Brent (XBRUSD.DWX) due to missing archive import, the 23 pending 
Brent oil strategy cards have been successfully rerouted to WTI (XTIUSD.DWX) as oil proxies. 
For each of the 23 EAs, the active registry slot has been modified, `QM_MagicResolver.mqh` regenerated, 
new `XTIUSD.DWX` D1 backtest setfiles generated using the canonical fixed-risk contract (`RISK_FIXED=1000`, `RISK_PERCENT=0`), 
and fresh Q02 work items enqueued to the database in pending state. All 23 EAs compiled successfully.

## Magic Numbers Registry & Resolver Changes

- Active `XBRUSD.DWX` rows for the 23 EAs have been set to status `retired` in `magic_numbers.csv`.
- New active `XTIUSD.DWX` rows on symbol slot 0 (magic: `<ea_id>0000`) have been appended.
- `QM_MagicResolver.mqh` was regenerated via `update_magic_resolver.py`.

## Batch Artifact Hashes

| EA ID | EA Slug | MQ5 SHA-256 | EX5 SHA-256 | Setfile SHA-256 |
|---|---|---|---|---|
| QM5_12841 | `brent-thu-prem` | `cf5b371724...` | `a332ba37c6...` | `970e36c012...` |
| QM5_12849 | `brent-tsmom12m` | `376216ce73...` | `9c2933b0f9...` | `a4851b26dc...` |
| QM5_12853 | `brent-may-prem` | `3acc8dd86a...` | `352a2440cf...` | `846dc8e8ca...` |
| QM5_12854 | `brent-dec-fade` | `fdaeefda18...` | `69907785cd...` | `6193b64a3a...` |
| QM5_12855 | `brent-nov-fade` | `87099cb0ae...` | `f4b16d7544...` | `3d40f88402...` |
| QM5_12856 | `brent-mon-fade` | `dd9da6c868...` | `bc9eb69c03...` | `c5b3a90268...` |
| QM5_12859 | `brent-52w-anchor` | `f0f834b2eb...` | `9dfc5288b9...` | `463ed60983...` |
| QM5_12865 | `brent-fri-prem` | `a5aea64f6c...` | `ec3d62948e...` | `fbfd68340d...` |
| QM5_12866 | `brent-apr-prem` | `fcfa28766c...` | `8e80071bd1...` | `e67154ac87...` |
| QM5_12871 | `brent-jan-fade` | `91c1df2f6a...` | `8973519a06...` | `bc1fd973d4...` |
| QM5_12911 | `brent-aug-prem` | `a4f56930c9...` | `1b7fc11497...` | `8790043a46...` |
| QM5_12976 | `brent-mar-prem` | `a53703625d...` | `c08ff181c5...` | `1079fc43cd...` |
| QM5_12980 | `brent-6m-rev` | `b2610643c2...` | `9da9da3684...` | `0360702b55...` |
| QM5_12981 | `brent-febsep-prem` | `7dbb824f61...` | `78b98962b5...` | `b45e7db671...` |
| QM5_12982 | `brent-sep-prem` | `c141475ba8...` | `4c20f3e4c7...` | `5411012390...` |
| QM5_13052 | `brent-jul-prem` | `1beb268aec...` | `c1c4a40379...` | `2553c4ec11...` |
| QM5_13054 | `brent-tom-mom` | `7ed0d9622f...` | `808e9fb660...` | `d834b193a7...` |
| QM5_13055 | `xbr-1w-mom-vol` | `c32f805b20...` | `2c0cbc122c...` | `30960b0066...` |
| QM5_13056 | `xbr-1w-rev-vol` | `2a30952912...` | `0d27cd8b6b...` | `39609564fa...` |
| QM5_13061 | `brent-jun-prem` | `b0619c84d2...` | `708434c0f9...` | `581b6da760...` |
| QM5_13072 | `brent-feb-prem` | `a2aa882c33...` | `9a3c867328...` | `3c33a3c8ed...` |
| QM5_13091 | `xbr-vrp-proxy` | `c280bf4dc1...` | `7bf50ad627...` | `33190c73ae...` |
| QM5_20171 | `brent-tsmom3m` | `822f10c49b...` | `95f670f9d9...` | `0a0a65fefd...` |

## Verification

- **Resolver Generation**: Rerun of `update_magic_resolver.py` completed with exit code 0.
- **Strict Compile**: All 23 EAs recompiled against the regenerated resolver with 0 errors and 0 warnings (exit code 0).
- **Fixed-Risk Check**: All generated setfiles parsed successfully, verifying `RISK_FIXED = 1000` and `RISK_PERCENT = 0` (no violation of the news/risk guardrails).
- **DB Enqueue**: 23 pending Q02 work items enqueued under `BEGIN IMMEDIATE` transaction, verified by unique work item IDs in the database.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is inferred.

