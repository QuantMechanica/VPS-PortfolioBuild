# Dukascopy lane export-side fix: CopyChunk retry, per-symbol completeness gate, gap-based reconciler check

Task: `dc7f0545-2d0a-4220-a1a4-4a9141dbade8` (parent `ca955879-fd90-4889-9f72-187dfd4e3522`,
grandparent `60174747-2b7b-4326-88fe-3f3e1adc3ba3`)

Disposition: **REVIEW — code implemented and tested, MetaEditor compile bound.
No T1 export run performed. No archive write, no manifest update, no
production splice.**

This evidence is written against `agents/board-advisor` HEAD
`911cd5ad1c81d9a51bddba335c2d0e802519e570`, plus the working-tree changes
listed below (to be committed alongside this file, in the canonical
checkout `C:/QM/repo`, using explicit pathspecs).

## Scope discipline

Per the ticket's hard limits: no terminal64.exe was started, T1-T10/T_Live
were not signalled, no export ran; compile happened outside the factory and
live terminal trees; no fixed reconciliation threshold (1.5x spread p95, 99%
bilateral coverage, DST 0 s) changed; the new checks are additive and
fail-closed; files touched are limited to
`framework/scripts/mt5_diagnostics/`, `tools/dukascopy/` (+tests), and this
evidence directory.

## Files changed

- `framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5`
- `framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py`
- `framework/scripts/mt5_diagnostics/test_dwx_m1_overlap_export_completeness.py` (new)
- `tools/dukascopy/reconcile_overlap.py`
- `tools/dukascopy/tests/test_dukascopy_backfill.py`

## (1) mq5: CopyChunk no longer accepts a zero-tick chunk as final

`CopyChunk` (previously: any `copied>=0` with no `ERR_HISTORY_TIMEOUT` returned
immediately, including `copied=0`) now retries a `copied=0` result up to 3
more times with a 2 s / 5 s / 10 s backoff before accepting it, and journals
every attempt -- both the existing sync-retry loop and the new zero-retry
loop -- to a new per-symbol file `<symbol>_M1_chunks.csv` written alongside
the M1 CSV in `InpOutputDir`: `symbol, chunk_start_epoch, chunk_end_epoch,
phase, attempt, copied, error_code, status`. A chunk that is still zero after
all retries gets a final `ZERO_TICK_CHUNK` row (and a `Print`) instead of
being silently accepted; the export still proceeds to the next chunk (the
existing per-symbol continuation behavior is unchanged), so one bad chunk
does not abort an otherwise-good symbol -- the classification in (2) is what
turns a chunk-level shortfall into a symbol-level `SHORT_READ` verdict.

`ExportOne` opens/closes the new journal handle alongside the existing M1 CSV
handle (single centralized cleanup point, same as the existing handle).

## (2) Per-symbol completeness floor: COMPLETE / SHORT_READ

**Source of the expected-minutes ceiling: the P1 manifest's per-symbol
`downloaded_hours`** (`docs/ops/evidence/2026-09-15_dukascopy_p3_completion/p1_window_manifest_receipt.json`,
schema `qm.dukascopy-p3-p1-window/v1`, sha256-bound to
`download_manifest.jsonl` at `a7d9fe65...dade42`) -- not a live Dukascopy-side
recount. This is deliberate: it needs no network access and no T1 run to
compute, it is already an evidence-bound artifact, and `downloaded_hours*60`
is a real per-symbol upper bound on obtainable minutes that already reflects
each symbol's actual data availability (GDAXI/SP500/WS30/etc. show fewer
`downloaded_hours` than full FX pairs).

`framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py::load_expected_minutes`
converts this into a floor: `expected_minutes = downloaded_hours * 60 * (1 -
allowance)`, where `allowance` is a documented per-instrument-class constant:

| Class | Symbols | Allowance |
|---|---|---|
| `fx` | all pairs not listed below | 0.20 |
| `index_commodity` | GDAXI, UK100, NDX, SP500, WS30, XAUUSD, XAGUSD, XNGUSD, XTIUSD | 0.35 |

Calibrated against the 2026-09-13 fixed-window reconciliation
(`docs/ops/evidence/2026-09-15_dukascopy_p3_defects/README.md`), which showed
two populations: 27 FX/index symbols at 83.8%-98.5% `dukascopy_coverage`
(ordinary DWX/Dukascopy session-accounting differences, not a defect) and 10
symbols at 0.03%-2.3% (catastrophic short reads). Both allowances sit below
the ordinary population's worst observed shortfall (index/commodity gets the
larger allowance because GDAXI/UK100 already showed larger legitimate
shortfalls than plain FX pairs), so a legitimate export still classifies
`COMPLETE`, while a catastrophic short read stays `SHORT_READ`.

`framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py::classify_completeness`
is a hard floor, not a rounded threshold: `status = "COMPLETE" if rows >=
expected_minutes else "SHORT_READ"`. `canonicalize_export_set` now:

- computes `expected_minutes` once per run and attaches
  `expected_minutes` / `completeness_ratio` / `status` to every symbol
  binding in the manifest;
- treats the new `<symbol>_M1_chunks.csv` journal as **optional** (existing
  exports/fixtures predate it) but, when present, parses it and attaches the
  `ZERO_TICK_CHUNK` rows as that symbol's `short_chunks` list;
- aggregates `short_read_symbols` / `short_read_symbol_count` at the
  manifest level.

`canonicalization_status` (parse success/failure) and the new `SHORT_READ`
classification are deliberately independent gates: a manifest can be
`canonicalization_status: COMPLETE` (every symbol parsed) while still
carrying a nonzero `short_read_symbol_count`. `run()`'s overall PASS/FAIL
gate was extended with `and not manifest_binding.get("short_read_symbol_count")`,
so **SHORT_READ never becomes COMPLETE by any downstream aggregation** -- a
single short-read symbol fails the receipt even though `written_rows>0` and
canonicalization otherwise succeeded (the exact prior defect this ticket
exists to close).

## (3) Wrapper: export_receipt.json carries the per-chunk journal, fails loud

`export_receipt.json`'s `m1_export_manifest.files[*]` now carries
`expected_minutes`, `completeness_ratio`, `status`, and `short_chunks` per
symbol; the manifest and the top-level receipt both carry `short_read_symbols`
/ `short_read_symbol_count`. The `summary.json` written alongside the receipt
surfaces the same fields and its `error` field states the short-read symbols
by name when `short_read_symbol_count>0` (loud, not silent).

New unit tests in
`framework/scripts/mt5_diagnostics/test_dwx_m1_overlap_export_completeness.py`
(synthetic chunk journals, no T1 run):

- `test_load_expected_minutes_matches_p1_manifest_with_documented_allowance`
  -- binds the loader's arithmetic to the actual P1 manifest file for one FX
  and one index/commodity symbol.
- `test_classify_completeness_is_a_hard_floor_not_a_rounded_threshold`
  -- exactly-at-floor is `COMPLETE`, one-below is `SHORT_READ`.
- `test_parse_chunk_journal_and_short_chunks_extraction` -- a synthetic
  5-row journal (2 chunks, one `OK`, one `ZERO_TICK_CHUNK` after a sync
  attempt and a zero-retry attempt) round-trips and `short_chunks_from_journal`
  extracts only the zero chunk.
- `test_canonicalize_export_set_flags_short_read_symbol_and_surfaces_chunk_journal`
  -- full `canonicalize_export_set` run over a synthetic 37-symbol raw
  export (monkeypatched tiny floors) with one symbol one row below its floor
  and a `ZERO_TICK_CHUNK` journal for it; asserts the manifest's
  `short_read_symbols`, the short symbol's `status`/`short_chunks`, a
  COMPLETE symbol's `status`/`short_chunks`, and that `canonicalization_status
  == COMPLETE` coexists with `short_read_symbol_count > 0` (the two gates
  are independent, per the "never becomes COMPLETE by aggregation"
  requirement).

## (4) reconcile_overlap.py: gap-based SHORT_READ_GAP

AUDCAD's real defect (dense - 25-day hole - dense, 84.48% aggregate
`dukascopy_coverage`) sits inside the "ordinary" 83.8%-98.5% coverage-ratio
band, so `SHORT_READ_COVERAGE_RATIO` (0.5) never catches it and it was
classified a generic `FAIL` (`docs/ops/evidence/2026-09-15_dukascopy_p3_defects/README.md`,
section (a)/(b)). Added `reconcile_overlap.longest_weekday_gap(dwx_times,
dukascopy_times)`: the longest silent interval between consecutive **DWX**
minutes, counted only over its **UTC-weekday** portion (`_weekday_seconds_in_range`,
a coarse UTC-calendar-day proxy for "trading week", not an exact FX session
calendar), and **only when Dukascopy has ticks inside that same interval**
(proof the market was open and DWX alone is missing data, as opposed to an
interval where both sources are equally silent -- see the false-positive
below). `SHORT_READ_GAP_WEEKDAY_HOURS = 24`: an ordinary Friday-close/Sunday-
open weekend contributes only a couple of weekday hours at its edges; a
genuine multi-week hole like AUDCAD's contributes many weekday days.

`reconcile_symbol`'s status chain is now `PASS > SHORT_READ_GAP > SHORT_READ
> FAIL` (gap check takes priority over the coverage-ratio check, since it is
the more specific defect signature); the gap fields are additive to the
returned dict (`longest_weekday_gap_seconds`, `..._start_broker_epoch`,
`..._end_broker_epoch`, `short_read_gap_threshold_hours`) and are **not**
folded into the `checks` dict, matching the existing `is_short_read`
pattern, so the fixed-threshold `checks` output stays byte-identical for
every existing test.

**False positive found and fixed during implementation:** an initial version
keyed the gap purely off DWX-side silence (ignoring whether Dukascopy also
had data there) and broke
`test_reconciliation_fixed_thresholds_and_dst_zero_offset`'s `failed`
assertion (`SHORT_READ_GAP` instead of the expected `FAIL`) -- that fixture's
`candidate`/`reference` share the exact same sparse, months-apart DST-window
timestamps by construction, so a DWX-only gap check misclassified a narrow
shared-window fixture as a short read. Requiring Dukascopy evidence inside
the gap (`duk_ordered` binary-advance in `longest_weekday_gap`) fixed it
without weakening the AUDCAD-class detection, and the full existing suite
was re-run green afterward (see Verification).

New test:
`tools/dukascopy/tests/test_dukascopy_backfill.py::test_short_read_gap_status_flags_a_multiweek_weekday_hole`
builds a synthetic dense(5d)-gap(4d, 2 weekdays inside)-dense(5d) DWX series
against a fully dense Dukascopy reference over the same 14-day span
(`dukascopy_coverage` ~71.4%, above `SHORT_READ_COVERAGE_RATIO`) and asserts
`status == "SHORT_READ_GAP"`.

## Verification

```text
python -m compileall -q framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py tools/dukascopy/reconcile_overlap.py
(no output = PASS)

python -m pytest -q tools/dukascopy/tests/
35 passed   (34 pre-existing + 1 new: test_short_read_gap_status_flags_a_multiweek_weekday_hole)

python -m pytest -q framework/scripts/mt5_diagnostics/test_dwx_m1_overlap_export_completeness.py
5 passed    (new file)

python -m pytest -q tools/strategy_farm/tests/test_dwx_m1_overlap_export.py
14 passed   (out-of-scope suite, exercised only to confirm no regression;
             not modified by this ticket -- canonicalize_export_set's
             chunk-journal handling is opt-in via file presence, so its
             37-file-only fixtures are unaffected)
```

### MetaEditor compile (framework compile path, non-factory)

Compiler: `D:/QM/mt5/DEV1/metaeditor64.exe` -- `DEV1` is a non-factory,
non-live MT5 install already used for this exact purpose (see
`tools/strategy_farm/pattern_fixture_compile_probe.py`, which compiles a
different diagnostics script with the same binary for the same reason: a
clean compile away from any T1-T10/T_Live data folder). The source was
staged into this evidence directory and compiled from there -- MetaEditor's
`/compile:<path>` compiles the exact file passed, independent of which
`/portable` data folder supplies the compiler binary, so nothing under
`D:/QM/mt5/DEV1`'s own MQL5 tree was read or written.

```text
D:/QM/mt5/DEV1/metaeditor64.exe /portable
  /compile:C:/QM/repo/docs/ops/evidence/2026-09-15_dukascopy_export_fix/compile_probe/MQL5/QM_DWX_M1_Overlap_Export.mq5
  /include:C:/QM/repo/docs/ops/evidence/2026-09-15_dukascopy_export_fix/compile_probe/MQL5
  /log

Result: 0 errors, 0 warnings, 820 ms elapsed, cpu='X64 Regular'
```

No terminal was started; no export ran.

| Artifact | SHA-256 |
|---|---|
| `compile_probe/MQL5/QM_DWX_M1_Overlap_Export.mq5` (staged; identical to the committed source) | `5ab8ea26056695a438337a9abc4289289458cbd3298bbe29c6e9716c53ea663f` |
| `framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5` (committed source) | `5ab8ea26056695a438337a9abc4289289458cbd3298bbe29c6e9716c53ea663f` |
| `compile_probe/MQL5/QM_DWX_M1_Overlap_Export.ex5` | `5d3ca8eb2954e40cd4b2a88cc301a8449665652318dfe78330c0b70544a2f9a4` |
| `compile_probe/MQL5/QM_DWX_M1_Overlap_Export.log` | `f2f0638946a79ef63cbdb306caf4b10f39f66f18a1608946f2a1a2c04167f59e` |

The wrapper's own contract validator was also re-run against the modified
source and still accepts it unchanged (37-symbol universe, all required
contract tokens, exact T1 path guard):

```text
python -c "from framework.scripts.mt5_diagnostics import dwx_m1_overlap_export as export; print(export.validate_mql_source())"
{'path': '...QM_DWX_M1_Overlap_Export.mq5', 'sha256': '5ab8ea26...ea663f',
 'symbol_count': 37, 'read_only_api': True, 'period': 'M1',
 'overlap_start_utc': '2025-10-01T00:00:00Z', 'overlap_end_utc': '2026-04-01T00:00:00Z'}
```

## What was not done (by design)

- No T1 probe rerun; no terminal64.exe start; T1-T10/T_Live untouched.
- No archive write, no production splice, no manifest update outside this
  evidence directory. `production_import=false` / `production_splice_authorized:
  false` everywhere this ticket's code paths touch (unchanged from the prior
  ticket; this ticket added no new archive/splice-authorizing code path).
  `run()`'s own claim/factory-off/idle-terminal guards are unmodified.
- No fixed reconciliation threshold changed (1.5x spread p95, 99% bilateral
  coverage, DST 0 s all untouched; `SHORT_READ_COVERAGE_RATIO` unchanged).
- The governed T1 export rerun is a **separate** work item, enqueued only
  after this ticket is reviewed/approved (same path as the `156ed639` /
  `030e8488` precedent,
  `docs/ops/evidence/2026-09-11_dukascopy_dwx_m1_overlap_export/README.md`):

```text
python C:/QM/repo/tools/strategy_farm/dwx_m1_overlap_export_work_item.py \
  --root D:/QM/strategy_farm \
  --stamp <YYYYMMDD_HHMMSS> \
  --authority-task-id dc7f0545-2d0a-4220-a1a4-4a9141dbade8 \
  --apply
```

Dry-run first (omit `--apply`) to inspect the enqueue payload before
committing it; the orchestrator should only add `--apply` once this ticket
is `APPROVED`.

RESULT task=dc7f0545-2d0a-4220-a1a4-4a9141dbade8 parent=ca955879
copychunk_zero_retry=DONE+TESTED completeness_floor=DONE+TESTED
gap_based_reconciler_check=DONE+TESTED compile=PASS(0_errors_0_warnings)
tests="35+5+14 passed" t1_probe_rerun=NONE
archive_write_authorized=false production_splice_authorized=false
