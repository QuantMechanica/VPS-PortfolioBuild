# Dukascopy backfill source-tool build evidence

Date: 2026-09-07

Router task: `e9dea1e3-2a1e-4b38-88e6-097bf15ffd8e`

Decision authority: `OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES`

Disposition: **REVIEW — tooling and scratch dry run complete; no production download or import was run**

## Delivered contracts

| Component | Contract |
|---|---|
| `tools/dukascopy/download_bi5.py` | Exact 37-symbol mapping, hourly public bi5 files, 20-byte big-endian/LZMA validation, 5–10 requests/second, retry, atomic files, append-only checksum manifest, checksum-authenticated resume, UTC log, and atomic progress/receipt files. The production window begins at the earlier of the governed per-symbol splice and 2025-10-01. A full splice run refuses anything other than the exact 37-symbol universe. |
| `tools/dukascopy/convert_to_import.py` | Revalidates every source hash and emits headerless tick/M1 CSVs accepted by T1's existing `prepare_import.py`. Every import tick is strictly newer than the authoritative UTC splice. A separate `RECONCILIATION_ONLY_M1` file can include the pre-splice overlap and is explicitly marked `import_authorized=false`. The durable sidecar binds source files, hashes, scale, point size, splice, output hashes, and exact rollback range. |
| `tools/dukascopy/reconcile_overlap.py` | Exact M1 timestamp match, OHLC median/p95 deltas in points, bilateral session coverage, tick-density ratio, separate source spread distributions, both intervening US-DST transition windows, and systematic-offset detection. It writes immutable per-symbol CSV/JSON plus aggregate CSV/JSON/README. |

The fixed acceptance checks are not configurable: overlap must span at least
2025-10-01 through 2026-04-01; close p95 must be at most 1.5 times typical
spread; bilateral session coverage must be at least 99%; both US-DST window
offsets must be exactly zero seconds; per-symbol computation must remain under
two hours. Any failed check leaves the symbol `FAIL` and
`production_splice_authorized=false`.

The source-format implementation follows Dukascopy's public data-export
description: zero-based month directories, LZMA payloads, and fixed 20-byte
big-endian records. The same public documentation warns that non-FX integer
scales must be verified for the instrument rather than assumed. Accordingly,
FX scales are deterministic here (100000, or 1000 for JPY quote pairs), while
the nine non-FX symbols refuse conversion until reviewed `price_scale` and
`point_size` values are supplied. Source: [Dukascopy data export](https://www.dukascopy.com/wiki/es/development/data-export/).

## Public one-day scratch run

Scratch root:
`D:/QM/reports/dukascopy/build_dry_run/20260907T1634Z_eurusd_20240115_pass`

The test downloaded EURUSD for 2024-01-15 only from
`https://datafeed.dukascopy.com/datafeed`, at five requests/second. The
workstation Python resolver returned stale addresses during the first attempt.
After independently resolving and reviewing the current endpoint address, the
optional `--resolve-ip 194.8.15.180` path completed while retaining the
canonical hostname for TLS certificate validation, SNI, and the HTTP Host
header. The address is evidence for this run only and must be freshly resolved
before any future override.

| Observation | Result |
|---|---:|
| Hourly URLs in final manifest view | 24 |
| Latest successful files / latest errors | 24 / 0 |
| Compressed bytes | 284,318 |
| Decoded ticks | 61,939 |
| Manifest SHA-256 | `a047cd8a5de081cd99f055e04045d50ce91f53f337507c23faaf70e2dcb813ca` |
| Tick CSV rows / SHA-256 | 61,939 / `e6d89ca1f86894d03c96fa9e30778d85724236004612f698f9f21bafca53a960` |
| Import M1 rows / SHA-256 | 1,412 / `dcdefb3b2f358c1b164a449d1dc6d53d5540238f7f05220048d0ad0821f3752a` |
| Reconciliation-only M1 rows / source ticks | 1,412 / 61,939 |
| Current sidecar SHA-256 | `05d6da832654805842479d3429f75d397421fba0d17c1d6bbe3375383d72a04d` |

The first emitted UTC tick was `2024-01-15T00:00:00.287Z`, strictly after the
scratch splice `2024-01-14T23:59:59.999Z`; the final tick was
`2024-01-15T23:59:59.214Z`. Importing the generated CSVs with the pure
conversion functions from `D:/QM/mt5/T1/dwx_import/prepare_import.py` (no MT5
initialization) produced 61,939 24-byte tick records and 1,412 48-byte M1
records in a scratch directory.

The one-day reconciliation schema smoke intentionally supplied the same
scratch M1 file on both sides. Price delta, coverage, and compute checks were
therefore true, but the result was correctly `FAIL`: it lacked the required
2025-10 through 2026-04 interval and both DST windows. This is a fail-closed
guard demonstration, not source-compatibility evidence. A real source verdict
must wait for the governed DWX M1 export associated with router task
`a7e1333c-9b06-45de-a6be-f14477b5f78b`.

The signed archive was validated with `load_manifest(...,
require_owner_approval=True)` before and after the scratch run. Both checks
returned content identity
`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`,
3,946 files, and years 2017–2025. No T1 path, terminal, factory item, verdict,
registry, or archive file was written.

## Verification

```powershell
Set-Location C:\QM\repo
python -m pytest -q tools/dukascopy/tests/test_dukascopy_backfill.py
python -m compileall -q tools/dukascopy
git diff --check -- tools/dukascopy docs/ops/evidence/2026-09-07_dukascopy_p1_p3_build
```

Result: `18 passed`; compile and whitespace checks passed. Tests cover all 37
mappings, synthetic bi5 decode/refusal, checksum resume, 5–10 request/second
limits, unresolved-hour refusal, exact 2025/2026 DST boundaries, strict splice behavior, separate
non-importable overlap output, prepare-import schema, non-FX scale refusal,
bilateral coverage, fixed price threshold, missing DST/interval refusal, and
one-hour offset detection.

## CEO night commands after tick-tail review

These commands perform source I/O and scratch conversion only. They never start
MetaTrader or submit/interrupt a factory claim. Do not run them until the
37-row splice CSV from the governed tick-tail task has been reviewed.

### Detached download

```powershell
$QmStamp = Get-Date -Format 'yyyyMMddTHHmmssZ'
$QmSpliceCsv = 'D:\QM\reports\dukascopy\splice\<APPROVED_STAMP>\tick_tail.csv'
$QmDukaRoot = "D:\QM\reports\dukascopy\backfill\$QmStamp"
$QmPython = (Get-Command python).Source
New-Item -ItemType Directory -Path $QmDukaRoot -ErrorAction Stop | Out-Null
$QmDownloadArgs = @(
  'C:\QM\repo\tools\dukascopy\download_bi5.py',
  '--out', $QmDukaRoot,
  '--splice-csv', $QmSpliceCsv,
  '--rate', '5',
  '--timeout', '30',
  '--retries', '3'
)
$QmDownloadProcess = Start-Process -FilePath $QmPython -ArgumentList $QmDownloadArgs `
  -WorkingDirectory 'C:\QM\repo' -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput "$QmDukaRoot\launcher.stdout.log" `
  -RedirectStandardError "$QmDukaRoot\launcher.stderr.log"
$QmDownloadProcess.Id
```

Progress is in `$QmDukaRoot\progress.json`; final state is in
`$QmDukaRoot\download_receipt.json`. Resume uses the identical command and
output root. If local Python DNS is still stale, first resolve and independently
review the current canonical endpoint address; only then append
`'--resolve-ip','<REVIEWED_CURRENT_IP>'` to `$QmDownloadArgs`. Never reuse the
address from this dry run without that check, and never disable TLS validation.

### Scratch conversion

Prepare a reviewed non-FX contract CSV with columns
`symbol,price_scale,point_size`. It must contain exactly GDAXI, SP500, NDX,
WS30, UK100, XAUUSD, XAGUSD, XTIUSD, and XNGUSD `.DWX` rows. The loop below
stops before producing any non-FX output if its contract is absent.

```powershell
$QmScaleCsv = 'D:\QM\reports\dukascopy\authority\<APPROVED_STAMP>\non_fx_scales.csv'
$QmConvertRoot = "$QmDukaRoot\converted"
$QmSplices = Import-Csv -LiteralPath $QmSpliceCsv
$QmScaleRows = @{}
Import-Csv -LiteralPath $QmScaleCsv | ForEach-Object { $QmScaleRows[$_.symbol] = $_ }
foreach ($QmSplice in $QmSplices) {
  $QmConvertArgs = @(
    'C:\QM\repo\tools\dukascopy\convert_to_import.py',
    '--manifest', "$QmDukaRoot\download_manifest.jsonl",
    '--raw-root', "$QmDukaRoot\raw",
    '--symbol', $QmSplice.symbol,
    '--splice-utc', $QmSplice.last_tick_utc,
    '--reconciliation-from-utc', '2025-10-01T00:00:00Z',
    '--out', "$QmConvertRoot\$($QmSplice.symbol)"
  )
  if ($QmScaleRows.ContainsKey($QmSplice.symbol)) {
    $QmContract = $QmScaleRows[$QmSplice.symbol]
    $QmConvertArgs += @('--price-scale', $QmContract.price_scale, '--point-size', $QmContract.point_size)
  } elseif ($QmSplice.symbol -notmatch '^[A-Z]{6}\.DWX$') {
    throw "Missing reviewed non-FX scale contract for $($QmSplice.symbol)"
  }
  & $QmPython @QmConvertArgs
  if ($LASTEXITCODE -ne 0) { throw "Conversion refused for $($QmSplice.symbol)" }
}
```

Outputs remain scratch inputs. No command in this evidence invokes
`prepare_import.py`, `verify_import.py`, MT5, T1, or a custom-symbol writer.

### Reconciliation after the governed DWX M1 export

Create a JSON array whose rows have `symbol`, `dukascopy_csv`, `dwx_csv`, and
(for non-FX) reviewed `point_size`. The Dukascopy path must be the
`RECONCILIATION_ONLY_M1.csv`; the DWX path must be the immutable export made by
the governed factory-claim route. Then run:

```powershell
$QmJobs = 'D:\QM\reports\dukascopy\reconciliation\<APPROVED_STAMP>\jobs.json'
$QmReconcileOut = 'D:\QM\reports\dukascopy\reconciliation\<APPROVED_STAMP>\results'
Set-Location C:\QM\repo
python tools/dukascopy/reconcile_overlap.py --jobs $QmJobs --out $QmReconcileOut
if ($LASTEXITCODE -ne 0) { throw 'One or more source-compatibility checks failed' }
```

Even an aggregate `PASS` is evidence only: this tool always records
`production_splice_authorized=false`. Import remains a separate OWNER-governed
factory action.
