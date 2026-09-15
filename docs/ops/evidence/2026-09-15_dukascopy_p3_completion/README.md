# Dukascopy overlap-reconciliation completion

Task: `60174747-2b7b-4326-88fe-3f3e1adc3ba3`

Disposition: **REVIEW — execution complete; reconciliation FAIL_CLOSED; 37/37 failures explained**

The task payload calls this check “P3.” That label is retained in artifact
filenames for lineage only; this is not a strategy-farm pipeline verdict and it
does not authorize any later Q phase.

## Result

The previously governed T1 export was reused exactly as instructed. It was not
rerun, and no terminal was launched or signaled. The export receipt remains
`PASS`, 37/37 symbols, 4,290,764 rows, with
`signed_archive_unchanged=true`.

All 37 Dukascopy fixed-window inputs were rebuilt in one fresh scratch root
from the checksum-bound P1 manifest. Every conversion sidecar has
`production_import=false`; every reconciliation-only output has
`import_authorized=false`; all 37 sidecars exist and there are zero `.tmp`
files.

The prescribed `tools/dukascopy/reconcile_overlap.py` run executed all 37
symbols and returned exit code 1 with batch status `FAIL`. The expected
35/37 PASS result was not obtained: **0/37 pass**. The acceptance alternative
is satisfied instead: every failed check for every symbol is quantified in
`p3_symbol_outcomes.csv`; there is no unexplained bucket.

No symbol is eligible for a manifest update from this run. The UK100/XTIUSD
scope-exclusion proposal is decision-ready for OWNER, but it remains a
proposal only. `archive_write_authorized=false` and
`production_splice_authorized=false`.

## Bound inputs

| Input | Binding |
|---|---|
| Governed DWX export | `D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/20260913_114500`; work item `030e8488-5372-439e-be03-0430748cf83b` |
| DWX export receipt SHA-256 | `996553f4c4274a15527ee2fddc049a72f3440578b4ad9ab3dacd8c79c2cb14a9` |
| DWX M1 manifest SHA-256 | `9a055f50ab8936b0d6734148dd80eff8b5b4142f848c23e3659a9b005d74d284` |
| Dukascopy P1 manifest SHA-256 | `a7d9fe65494f126f7cf468bb7158396469801f52a95db2868c5b21afb1dade42` |
| Provider-scale receipt SHA-256 | `2dbf6f6662243fa8abd2982543a092a6765c8f62358f9d90270d46efc3299db1` |
| Reconciler SHA-256 | `d0740da790985ee5ef85945b34a278e2a064f216a97a20040e6e982c3c18397f` |
| Fixed UTC interval | `[2025-10-01T00:00:00Z, 2026-04-01T00:00:00Z)` |

## Fixed-check matrix

| Fixed check | PASS | FAIL |
|---|---:|---:|
| close p95 <= 1.5 x typical spread | 24 | 13 |
| bilateral session coverage >= 99% | 0 | 37 |
| both US-DST windows best-align at 0 seconds | 20 | 17 |
| required overlap window | 0 | 37 |
| compute time < 7,200 seconds | 37 | 0 |
| overall | 0 | 37 |

Total reconciliation compute time was 324.409 seconds; the slowest symbol was
12.844 seconds.

## Why every row fails

The per-symbol file gives exact bar counts, both directional coverage ratios,
price p95/limit, DST offsets, broker-epoch bounds, failed-check set, and a
complete explanation string for all 37 symbols.

1. **Endpoint contract — 37 failures.** The governed export correctly emits
   the requested half-open interval through `2026-03-31T23:59:00Z`. The
   reconciler compares the final observed minute against the exclusive
   `2026-04-01T00:00:00Z` boundary. For full FX rows this is broker epoch
   `1775012340` versus required `1775012400`, an exact 60-second shortfall.
   Session-limited and sparse instruments end earlier. The fixed check was not
   weakened or bypassed; its export/checker contract needs separate review.

2. **Bilateral coverage — 37 failures.** The 27 non-sparse DWX files achieve
   only 83.842191%–97.717845% bilateral coverage against Dukascopy. The ten
   sparse DWX files achieve 0.034138%–2.275112%. The directional columns show
   that most non-sparse FX files match more than 99% of their own DWX minutes,
   but the fixed gate takes the minimum of DWX and Dukascopy coverage. As a
   concrete export gap, `AUDCAD.DWX` contains October rows only for October
   1–8 (8,581 rows) while its P1 October input contains 32,880 rows.

3. **Sparse governed exports — ten symbols.** `EURAUD.DWX`, `EURCHF.DWX`,
   `EURJPY.DWX`, `EURUSD.DWX`, `GBPAUD.DWX`, `GBPJPY.DWX`, `NDX.DWX`,
   `USDJPY.DWX`, `XAUUSD.DWX`, and `XNGUSD.DWX` contain only 61–2,607 DWX
   bars, despite the work-item receipt classifying all 37 symbol calls as
   successful. Their complete fixed-window P1 conversion outputs contain
   158,906–184,215 bars, so these are specifically DWX-side coverage failures.

4. **DST alignment — 17 failures.** The exact transition offsets are recorded
   per row. Most nonzero maxima are -60 seconds, with CADCHF also -120 seconds,
   XAGUSD -180 seconds, WS30 +900 seconds, and XNGUSD no matched transition
   window. No offset was normalized away.

5. **Price tolerance — 13 failures.** Seven are sparse-DWX rows, where the
   small sample cannot support splice use. The six non-sparse failures are
   `GDAXI.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`, `XAGUSD.DWX`, and
   `XTIUSD.DWX`; their exact p95 values and limits are in the outcome table.
   Several non-FX provider-scale assumptions therefore remain unfit for a
   production proposal. No scale was changed to manufacture a pass.

## UK100/XTIUSD OWNER proposal

`uk100_xtiusd_splice_exclusion_proposal.json` is ready for the OWNER scope
decision. It recommends excluding both symbols from any future Dukascopy
production splice and retaining their existing DWX history as archive-only.

- UK100: 161,985 matched bars; close p95 222.01 points versus 32.9528565;
  6.7372 times the limit.
- XTIUSD: 168,190 matched bars; close p95 150 points versus 7.5; 20 times the
  limit.

Both pass the zero-second DST check in this run. Their price failures therefore
remain independent of timestamp alignment. The prior signed-difference proof
(`basis_proof.csv`, SHA-256
`0fe7695f2059a074abb0d76b948df48c01a09249d93937b31e9bf6e274dad0b4`)
also shows time-varying basis, so a static offset is not defensible.

The proposal distinguishes two ceremonies: the UK100/XTIUSD scope decision is
ready; an archive-write or production-splice ceremony is not. The latter still
requires passing evidence and a separate exact OWNER authorization.

## Scratch retirement and inventory

The sole fresh scratch root is:

`D:/QM/reports/dukascopy/reconciliation/20260915_60174747`

It contains 266 files totaling about 0.937 GB. The predecessor roots bearing
`79c942ac`, `b5f660f9`, or `f12fbdb3` were retired in the prior continuation
and were confirmed absent before this run. `D:/QM/reports/dukascopy/conversion`
contains no predecessor root. After execution, the reconciliation parent has
exactly one child root: the one above.

## Durable artifacts

| Artifact | SHA-256 |
|---|---|
| `p3_reconciliation_summary.json` | `55d00bb48ea73567f40ca85af6ce3ddffad4198a3df1802fccc2791a8808422f` |
| `p3_reconciliation_summary.csv` | `ae3cb1b48db1d551c0d43629f14719901bc7bf71f47d75503e2227b716bf94c7` |
| `p3_symbol_outcomes.csv` | `b555ad52fb01d30cd19af96e3d34d7401682dad7e9cab4ce1528fd911128a429` |
| `p3_aggregate.json` | `50370c43fdaa1d7927280efaf2f0da6dd7e18a05dfe684de82d0c97ee6958aa4` |
| `p3_jobs.json` | `c11618079dd4649f9bb108cf9219eff6568eed985253a44b4e980e9351a1a130` |
| `input_inventory.csv` | `f8a80ddc7d0a3784b212827c5613acad3f7e8134630f131b7d9dae97eae48b16` |
| `p1_window_manifest_receipt.json` | `bf3ce003da5582ec1cd173bf6bb57e044637d630d3d431be8b667f14fe00500f` |
| `conversion_receipt.json` | `10338690d9b23bceefd82b15bbabb9e6af6619bf0e1b381cd1c7bb2fcbf36220` |
| `p3_tool_README.md` | `2fdf85b5cbcdfa641ae59eb4be06a674053c265bafef27a124aa7695c11e4e8c` |
| `uk100_xtiusd_splice_exclusion_proposal.json` | `b46703f9f2bdf01061d4095f8137b447d0870f5869acb9a334447c1dde788f90` |

## Verification

```text
python tools/dukascopy/reconcile_overlap.py --jobs D:/QM/reports/dukascopy/reconciliation/20260915_60174747/p3_jobs.json --instrument-metadata C:/QM/repo/docs/ops/evidence/2026-09-12_dukascopy_p3_redo/dukascopy_price_scale.csv --out D:/QM/reports/dukascopy/reconciliation/20260915_60174747/p3
exit 1; status FAIL; symbols 37 (expected fail-closed command result)

python -m pytest -q tools/dukascopy/tests/test_dukascopy_backfill.py
19 passed

python -m compileall -q tools/dukascopy
PASS

conversion/inventory audit
37 sidecars; 0 production_import=true; 0 reconciliation import_authorized=true; 0 .tmp files

scratch-root audit
1 current root; all named predecessor roots absent
```

No factory archive, signed manifest, terminal, `T_Live`, AutoTrading, registry,
or production-splice state was written.

RESULT task=60174747 execution=PASS p3=FAIL_CLOSED p3_pass=0/37 failures_explained=37/37 owner_scope_proposal=READY archive_write_authorized=false production_splice_authorized=false scratch_roots=1
