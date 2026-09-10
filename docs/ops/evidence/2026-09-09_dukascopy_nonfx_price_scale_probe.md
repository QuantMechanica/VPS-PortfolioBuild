# Dukascopy non-FX price-scale probe — implementation and deferred T1 receipt

Date: 2026-09-09  
Router task: `2f717775-2bdd-4457-b5b6-e9ecae2a3e4a`  
Governed work item: `ed393d48-7539-4059-abf9-c7b2a9716563`  
Code commit: `97c1ea8d50341fd9ba4377ef97163a859c1647a4`  
Disposition: **IMPLEMENTATION_VERIFIED / T1_RECEIPT_DEFERRED**

## Implemented contract

The existing T1-only tick-tail diagnostic now contains a distinct metadata
sub-probe for exactly the nine non-FX symbols. Reusing that route preserves its
contract-versioned diagnostic payload, `diagnostic/Q00` work-item kind/phase,
`QM_DIAG_DWX_TICK_TAIL` pseudo identity, ordinary serialized worker claim,
T1-only enforcement, before/after signed-archive and custom-history isolation
audits, disabled live-trading flags, and non-admission `REVIEW_REQUIRED` verdict.

The MQL5 sub-probe obtains only:

- `SYMBOL_DIGITS` via `SymbolInfoInteger`; and
- `SYMBOL_POINT` via `SymbolInfoDouble`.

It derives `price_scale` as `10**digits` and emits the exact schema
`symbol,digits,point,price_scale`. Python canonicalization requires exactly the
nine governed symbols, rejects duplicates, invalid/non-finite point values,
schema drift, and inconsistent derived scales, then SHA-256 binds
`price_scale.csv` into the probe receipt and worker summary.

`tools/dukascopy/common.py` now loads only an exact nine-row receipt.
`convert_to_import.py` and `reconcile_overlap.py` accept that receipt by API or
`--instrument-metadata`, bind its path/hash into their result, and reject
missing or conflicting non-FX values. The legacy FX scale and point derivation
remain unchanged. Tests use generated synthetic contract rows rather than
encoding or guessing any broker symbol values.

## Verification

```text
python -m pytest tools/dukascopy/tests/test_dukascopy_backfill.py \
  tools/strategy_farm/tests/test_dwx_tick_tail_probe.py -q
30 passed
```

The committed MQL and Python blobs contain LF line endings. The queued payload's
source bindings still match the committed bytes exactly:

| Binding | SHA-256 | Match |
|---|---|---|
| Probe MQL5 source | `e1f581ab49b86875f11b71cbab38e7f3cc43a1b22d55ba1488dd71b634245041` | yes |
| Probe Python wrapper | `e755ef99eceb41f39dc3b92afd11f7057a6a70b1f054c19ca86b79351089d628` | yes |

## Governed runtime state

One and only one work item was enqueued at `2026-09-09T18:56:33Z`, with output
root `D:\QM\reports\dukascopy\splice\20260909_185632`. It remained `pending`
and unclaimed through the end of this single-pass cycle. Read-only canonical
queue snapshots placed it at ranks 97, 94, 91, 96, and 93 of roughly 6,500
pending rows. The stable/rising rank is explained by continuously replenished
priority optimization-frontier cells ordered ahead of Q00. T1 repeatedly
claimed those ordinary cells, while shared claim-spacing and commit-headroom
guards also correctly produced short idle windows.

No worker, terminal, active backtest, queue row, or factory state was altered to
bypass those guards. The existing work item must be allowed to reach T1 through
normal admission; it must not be duplicated. When it finishes, append the
authenticated nine CSV rows and receipt hashes to this document before treating
the task acceptance as complete.

## Authenticated T1 receipt (completed 2026-09-10)

The governed T1 work item completed at `2026-09-10T03:33:46Z` with
`status=PASS` and its non-admission verdict fixed at `REVIEW_REQUIRED`.  The
probe used only `SymbolInfoInteger(SYMBOL_DIGITS)` and
`SymbolInfoDouble(SYMBOL_POINT)` on T1; the following values are transcribed
from its bound CSV, not inferred by this document or the conversion code.

| Symbol | Digits | Point | Price scale |
|---|---:|---:|---:|
| GDAXI.DWX | 1 | 0.1 | 10 |
| NDX.DWX | 1 | 0.1 | 10 |
| SP500.DWX | 1 | 0.1 | 10 |
| UK100.DWX | 1 | 0.1 | 10 |
| WS30.DWX | 0 | 1 | 1 |
| XAGUSD.DWX | 3 | 0.001 | 1000 |
| XAUUSD.DWX | 2 | 0.01 | 100 |
| XNGUSD.DWX | 3 | 0.001 | 1000 |
| XTIUSD.DWX | 2 | 0.01 | 100 |

| Bound artifact | SHA-256 |
|---|---|
| `price_scale.csv` | `b72a05df91da8da053cd066a698a02aeda2930761e990f4f35d379899761fb4d` |
| `probe_receipt.json` | `159f98171260a1155a7611f457ca0d00c5234d644cc2b1d437085fe8dc42784e` |
| T1 Q00 `summary.json` | `status=PASS`, `signed_archive_unchanged=true`, verdict `REVIEW_REQUIRED` |

The before/after signed archive inventory is identical (`3946` files,
`44,231,653,718` bytes; manifest
`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`).
This completes the deferred receipt portion without any production download,
import, Factory state change, live-trading action, or gate verdict.

## Original deferred-receipt boundary

Before completion, no broker values were stated here because the governed T1
work item had not run. The now-realized expected artifacts are:

- `D:\QM\reports\dukascopy\splice\20260909_185632\price_scale.csv`
- `D:\QM\reports\dukascopy\splice\20260909_185632\probe_receipt.json`
- `D:\QM\reports\work_items\ed393d48-7539-4059-abf9-c7b2a9716563\QM_DIAG_DWX_TICK_TAIL\Q00\summary.json`

No production bi5 download was started by this task, no T1 history import was
performed, and no Factory-OFF/ON, T_Live, AutoTrading, live-account, threshold,
gate, or verdict action occurred. A separately owned hardened backfill process
was observed after 19:19Z and left untouched; it was not launched by this task.
