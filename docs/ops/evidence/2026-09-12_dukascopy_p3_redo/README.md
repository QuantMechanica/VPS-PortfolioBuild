# Dukascopy P3 redo — 2026-09-12

Task: `b5f660f9-29ea-4cc9-a67d-38e3cd877153`  
Disposition: **REVIEW — 37/37 outcomes explained; manifest proposal BLOCKED**

## Result

The sole unresolved P1 hour, `AUDCAD.DWX` at `2026-09-11T17:00:00Z`,
downloaded successfully on a fresh authenticated retry. P1 is therefore
resolved for 307,581/307,581 planned hours. The retry receipt reports one
download, zero errors, and status `PASS`.

The reviewed Dukascopy BI5 integer divisor is now independent of MT5
`digits`/`point`. First-principles raw/DWX probes establish divisor 1000 for
UK100, XAUUSD and XTIUSD. The exact samples and source hashes are in
`price_scale_proof.csv`; the nine-row proposal is `dukascopy_price_scale.csv`.
This changes provider decoding only. It does not change the destination broker
point or authorize an import.

P3 has a durable outcome for all 37 symbols:

- 25 symbols executed against the fresh governed T1 export;
- 12 did not execute because that export returned an exact empty-history error
  for each symbol; and
- 0/37 pass the complete gate.

The full per-symbol explanations are in `p3_symbol_outcomes.csv`. There is no
generic unexplained failure bucket.

No custom history, archive, terminal, registry, verdict, T1–T12, `T_Live`, or
AutoTrading state was written. The only T1 action was the governed read-only
work item. No terminal process was started, stopped, or signaled.

## Governed T1 export

Work item: `156ed639-3557-4c8e-bc14-b8ff69637bc5`  
Summary: `D:/QM/reports/work_items/156ed639-3557-4c8e-bc14-b8ff69637bc5/QM_DIAG_DWX_M1_OVERLAP/Q00/summary.json`

The work item correctly returned `INFRA_FAIL`, `canonicalization_status=PARTIAL`:
25 successful symbols and 12 failures. All 12 failures are `raw M1 export is
empty`: AUDCHF, EURJPY, EURUSD, GBPCAD, GBPNZD, GBPUSD, GDAXI, NDX, SP500,
USDJPY, WS30 and XNGUSD (all `.DWX`).

Manifest SHA-256:
`4f69fe5b03722074de87caa42bd3faa6c211943db8f564b40e7c396c79d6eb74`.
Receipt SHA-256:
`95f073947e6292c7092feacceea12fb38c61a67de37d99dd8df185a7865706ef`.
The receipt records `signed_archive_unchanged=true`.

Every populated export begins 2025-10-01 and ends no later than
2025-12-31T21:59Z. It therefore cannot cover the required end date
2026-04-01 or the March 2026 US-DST transition.

## P2 and scale repair

Scratch root:
`D:/QM/reports/dukascopy/conversion/20260912_1300_taskb5f660f9`.

The focused redo contains nine checksum-bound sidecars (the five completed
fresh FX inputs used by P3, AUDCHF, and the three scale probes), 36 files,
4,245,164,182 bytes, and zero `.tmp` files. All sidecars retain
`production_import=false`; every reconciliation output retains
`import_authorized=false`.

The consolidated P3 uses eight fresh task conversions and 17 unchanged
predecessor conversions. `conversion_inventory.csv` binds every one of those
25 inputs to the reconciliation CSV and sidecar SHA-256. Its SHA-256 is
`158930a84f39c58bf3d9a78eebb1c4e584879235b8cf988d3d3aba2c6a1ec6a6`.

Scale repair changed the price results as follows:

| Symbol | old close p95 points | new close p95 points | limit | price check |
|---|---:|---:|---:|---|
| UK100.DWX | 9,787,924.2 | 223.23 | 32.955 | FAIL |
| XAUUSD.DWX | 4,019,427 | 31.50 | 95.067954 | PASS |
| XTIUSD.DWX | 55,761 | 38.50 | 7.50 | FAIL |

The encoding defects are removed. UK100 and XTIUSD still have material
provider/broker level or basis differences, so their price failures remain.

## P3 outcomes

The immutable consolidated result is also copied into this evidence directory:

| Artifact | SHA-256 |
|---|---|
| `p3_reconciliation_summary.json` | `e6798deaa0686494b5ef20b1135a20fcd0bf5b7cce522243a06218274fa8ff3f` |
| `p3_reconciliation_summary.csv` | `d22fa61d69bb995f3c626e9892f4e01d852ca77b632e964c39dbd733c795bf9b` |
| `p3_symbol_outcomes.csv` | `bc2fa66f7bf305c2d1ff2daf2db1a4e9ce3882b6b279741652127c1ccd846fbd` |
| `p3_jobs.json` | `bd4e49fe43a01620516781d323cda83d27f83df5b4dcb15804e3c2692f29cb07` |

Fixed-check totals across the 25 executed symbols:

| Check | Pass |
|---|---:|
| compute under two hours | 25/25 |
| close p95 <= 1.5× typical spread | 23/25 |
| required overlap through 2026-04-01 | 0/25 |
| bilateral session coverage >=99% | 0/25 |
| both US-DST windows at zero offset | 0/25 |

Coverage spans 68.534%–96.336%. Only the November 2025 DST-end window is
present. Its best offset is nonzero for AUDCAD (-60 seconds), AUDNZD (-60),
CADCHF (-120), EURNZD (-60), and GBPCHF (-60); the other 20 align at zero in
that observed window. All 25 still fail the overall DST check because the March
2026 window is absent.

## Proposal

`manifest_update_proposal.json` is ready for review, but its status is
`PROPOSAL_BLOCKED` and both `archive_write_authorized` and
`production_splice_authorized` are `false`. A ceremony cannot proceed until a
complete governed T1 export through April 2026 permits 37/37 P3 passes, the
remaining UK100/XTIUSD basis defects are resolved, and OWNER separately
authorizes the archive write.

## Verification

```text
python -m pytest -q tools/dukascopy/tests/test_dukascopy_backfill.py
19 passed

python -m compileall -q tools/dukascopy
PASS

fresh scratch inventory
9 sidecars; 36 files; 0 temporary files

consolidated P3
25 executed; 12 exact governed-export failures; 37 explained
```
