# Dukascopy P1 tail / P2 conversion / P3 reconciliation — 2026-09-12

Task: `79c942ac-bebb-4dd4-a4ff-281d5d11dac7`  
Parent result: `3032534e-eaf0-5b68-b09f-2127ebb315b0`  
Decision: `OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES`  
Disposition: **REVIEW — scratch conversion complete for 36/37; production splice and manifest update BLOCKED**

## Result

The hardened downloader resolved 307,580 of 307,581 planned hours. All source
hours except `AUDCAD.DWX` at `2026-09-11T17:00:00Z` are authenticated as a
download or legitimate no-data response. The remaining URL exhausted five
fresh attempts with read/connect timeouts after an earlier five-attempt run
also produced timeouts/HTTP 503. This is an unresolved transient, not evidence
of permanent unavailability.

The converter produced checksum-bound scratch tick, import-M1 and
reconciliation-M1 outputs for the other 36 symbols: 398,733,724 append-only
ticks, 5,203,284 import M1 bars, and 12,420,375 reconciliation M1 bars. Each
symbol has a durable source sidecar; there are 36 sidecars, 144 output files,
17,702,835,262 bytes, and zero `.tmp` files. `AUDCAD.DWX` was correctly refused
because its manifest still has one unresolved source hour.

P3 ran on every symbol available in both the conversion set and the governed
T1 export: 24 symbols. All 24 fail the fixed production gate. The result is
useful evidence, not an authorization: close-price correlation is high
(`rho=0.997930452273..0.999999482576`), but the T1 export is incomplete and
three non-FX price-scale/basis mismatches are material.

No custom history, signed archive, terminal directory, factory row, verdict,
registry, threshold, T1–T12, or `T_Live` path was written. No terminal process
was started/stopped/signaled and AutoTrading was untouched.

## P1 tail receipt

Root: `D:/QM/reports/dukascopy/backfill/20260909T191800Z_hardened`

| Metric | Value |
|---|---:|
| Planned / completed | 307,581 / 307,581 |
| Resumed before this tail | 306,500 |
| Tail downloaded / no-data / error | 556 / 524 / 1 |
| Final resolved / unresolved | 307,580 / 1 |
| Receipt status | `FAIL` (correct fail-closed result) |

| Artifact | SHA-256 |
|---|---|
| `download_receipt.json` | `7d9008161a90020b447d0a69a3f9dbf7ab7b1b84c8459e00c8dd11937557a18f` |
| `download_manifest.jsonl` | `775a0690e37b38a7183a6c4679e778bd50ed98f2eb42538aa1e54039f4fc1657` |
| `hour_ledger.jsonl` | `025bc3ea461a2e0d1382f73f6be0b927fed199e1a38dc09eeff41df9ce5574fd` |
| `progress.json` | `21889d697ce0766f2be3b71c6e28a3d2b3675052206ab0a2f5da7b3485a312a9` |

Unresolved URL:
`https://datafeed.dukascopy.com/datafeed/AUDCAD/2026/08/11/17h_ticks.bi5`.
The append-only ledger contains failed rows at `2026-09-12T00:11:27.271Z` and
`2026-09-12T09:15:53.932Z`, each with five attempts. The fresh run's attempts
were a read timeout followed by four connect timeouts. Other error hours in the
same tail subsequently resolved; no-data was accepted only through the
downloader's existing structural policy.

## P2 conversion

Scratch root:
`D:/QM/reports/dukascopy/conversion/20260912_0919_task79c942ac`.

The full 36-row count/hash/splice inventory is
`2026-09-12_dukascopy_p2_p3_tail_execution/conversion_inventory.csv`
(SHA-256 `695967dd2ce7b43c9e7aae6050cb11efce9e19d50657bd6c471c6f10f3369684`).
It was mechanically checked against every live sidecar with zero mismatches.

Every conversion used the authenticated P1 manifest and raw root, the exact
governed splice timestamp, reconciliation start `2025-10-01T00:00:00Z`, and
the reviewed nine-row metadata file
`D:/QM/reports/dukascopy/splice/20260909_185632/price_scale.csv` (SHA-256
`b72a05df91da8da053cd066a698a02aeda2930761e990f4f35d379899761fb4d`).
All sidecars record `production_import=false`; reconciliation M1 outputs record
`import_authorized=false`. The first import tick is strictly newer than the
per-symbol splice.

The largest outputs were XAGUSD (35,085,128 ticks, tick SHA-256
`07b6d5dad75d4a625c6f2949ff0a0b27ec0e2fae515176e8e1d7a09691463179`)
and XAUUSD (33,575,139 ticks, tick SHA-256
`8c7f386a668f3fcaf80af3e21fb96e57ed77eb3aa067f5a11b3508bbbf5f2887`).

## P3 governed overlap

T1 input root:
`D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/20260912_063608`.
This separately governed read-only export attempted all 37 symbols, emitted 25
and returned `FAIL` for 12 empty histories:

`AUDCHF, EURJPY, EURUSD, GBPCAD, GBPNZD, GBPUSD, GDAXI, NDX, SP500,
USDJPY, WS30, XNGUSD` (all `.DWX`).

The requested contract was 2025-10-01 through 2026-04-01, but every populated
file ends no later than `2025-12-31T21:59:00Z`. Therefore the March 2026 US-DST
window is absent. Export manifest SHA-256 is
`1f7bca135b3903cb24788a3b362c978dd4a32ad1b108edd0bacfcf2f87cc7c92`;
receipt SHA-256 is
`e817bd3f666a898907bc1d23d1608b59e8e1dcc7109a96ff4db8fab2331a2c22`.
The receipt records `signed_archive_unchanged=true`.

Two immutable scratch reconciliations cover the 24-symbol intersection:

| Run | Symbols | Summary SHA-256 | Status |
|---|---:|---|---|
| `results_22` | 22 | `6817900f62d91d22d8c94e0bfba95678f77d42d98a54b668c9037503d37f19a8` | FAIL |
| `results_metals` | 2 | `5ef271c85aaee4a8889a50119a863bddcb97ba89c0b0d40754edd80b41837e0a` | FAIL |

Fixed-check totals:

| Check | Pass |
|---|---:|
| computation under two hours | 24 / 24 |
| close p95 <= 1.5× typical spread | 21 / 24 |
| required overlap through 2026-04-01 | 0 / 24 |
| bilateral session coverage >=99% | 0 / 24 |
| both DST windows at zero offset | 0 / 24 |

Coverage spans 68.534% to 96.336%. For the available November 2025 DST-end
window, the best offset is zero seconds for 20/24 symbols; AUDNZD, EURNZD and
GBPCHF choose -60 seconds and CADCHF chooses -120 seconds. No symbol can pass
the overall DST check without the March window.

The converter and reconciler use Darwinex broker wall time: GMT+2 outside US
DST and GMT+3 during US DST. The T1 export's explicit UTC timestamps are
normalized to that same broker epoch before exact M1 matching. The independent
close-series calculation in `overlap_rho.csv` (SHA-256
`c4e1c19dfb75080fe81913539eb6a04901454c514b623f99c151a58e263673aa`)
binds 63,911–85,777 matched bars per symbol. All rho values are >=0.99793.

Price checks fail for UK100 (close p95 9,787,924.2 vs limit 3,295.5), XTIUSD
(55,761 vs 75), and XAUUSD (4,019,427 vs 950.68). XAUUSD makes the defect
especially explicit: converted values near 38,630 compare with authentic DWX
near 3,863, an approximately 10× encoding-scale mismatch. High rho does not
waive this level/basis defect. XAGUSD passes the price check (34 vs 48.68) but
coverage is only 95.787%.

## Proposal and governed pause

The 24-symbol scratch job proposal is
`2026-09-12_dukascopy_p2_p3_tail_execution/reconciliation_jobs_proposal.json`
(SHA-256 `fe64a1d8626631edb817f31af7d229891d7c0872847538faf09044ecbd82254b`).
The signed-manifest proposal is
`2026-09-12_dukascopy_p2_p3_tail_execution/manifest_update_proposal.json`
(SHA-256 `30f3ba414a118b19dba04ae79f114bd956a36bc8270a19dcd67b6cf57ec385c5`).

Its decision is `PROPOSAL_BLOCKED`, with both
`archive_write_authorized=false` and `production_splice_authorized=false`.
Before a new proposal: resolve/authenticate AUDCAD, regenerate its conversion,
produce a complete 37-symbol T1 export through April 2026, correct the XAUUSD
encoding scale and the UK100/XTIUSD basis defects into fresh scratch roots, and
obtain 37/37 P3 passes. Even then, the archive write remains a separate
orchestrator/OWNER-governed step.

## Verification

```text
python -m pytest -q tools/dukascopy/tests/test_dukascopy_backfill.py
19 passed

python -m compileall -q tools/dukascopy
PASS

conversion inventory vs 36 sidecars
36 rows; 0 mismatches

JSON parse + git diff --check for scoped artifacts
PASS
```
