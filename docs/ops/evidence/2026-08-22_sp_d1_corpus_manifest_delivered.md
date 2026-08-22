# SP-D1 — content-addressed `G:` corpus manifest: DELIVERED

Date: 2026-08-22
Router task: `0fb2edcb-7411-4323-9422-e4fb0fd9adc2`
Executed by: Claude (Orchestrator), interactive session — the security context
that owns the DriveFS mount.
Supersedes the access gate `2026-08-22_sp_d1_corpus_manifest_access_gate.md`,
which correctly refused because `G:` is invisible to the headless scheduler.

Authority to proceed: `OWNER-DEC-G-RETENTION` 2026-08-22 — "OWNER:
Manifest-first". The manifest is the precondition OWNER put in front of any
deletion on `G:`.

## Result

```
files_total                 130
pdf_total                   127
mq5_total                     3
sha256_missing                0
raw_untrusted_mq5           3/3
mq5_bound_file_level        3/3
pdf_bound_collection_level    127
pdf_bound_file_level            0
pdf_unbound                     0
```

- Corpus root: `G:\My Drive\QuantMechanica - VPS Portfolio Build`
- Manifest: `D:\QM\reports\state\g_corpus_manifest_2026-08-22.json`
- Manifest SHA-256: `e7f256db275de92d0a0fc14ab57310de77d978d3264e7ab027f59c7ef3f5e8ae`
- Collector: `tools/strategy_farm/build_g_corpus_manifest.py`
- `retrieved_at_utc`: `2026-08-22T19:30:00Z` (caller-supplied; the tool takes no clock)

Every one of the 130 files carries `source_id`, `relative_path`, `sha256`,
`size_bytes`, `media_type`, `source_url`, `retrieved_at_utc`,
`license_or_usage_basis`, `trust_level`, `harvest_status`, `ledger_binding`,
`candidate_ids`, `card_ids`, `retention_class`, `confidentiality`.

## Hard constraints honoured

- No new ingestion, no card generation, no EA-ID reservation, no queue item.
  The collector is a cataloguer.
- The farm database is opened `mode=ro` (`file:…?mode=ro`), so binding
  physically cannot mutate the ledger.
- No archive file was moved, renamed, or deleted.

## The finding the acceptance criterion could not express

The task's acceptance asked for "127 PDFs bound to existing ledger rows". Taken
literally as *per-document* rows, that is **unsatisfiable — and the reason is
itself the result worth reporting.**

The `sources` ledger holds 117 rows, and those rows are **harvest streams, not
documents**: `ForexFactory strategies and systems`, `arXiv q-fin Trading &
Market Microstructure`, `MQL5 CodeBase MT5 strategies`, `Legacy QuantMechanica
books and EAs`. There is exactly one row covering this entire archive, at
collection granularity (`local_archive`, uri `G:\My Drive\QuantMechanica`).

So the 127 PDFs are bound at **collection** level and at no finer level,
because no finer level exists. Manufacturing 127 per-document rows to satisfy
the counter would have been new ingestion — forbidden by this task's own hard
constraint — and would have invented provenance that was never recorded.

The manifest therefore reports two distinct binding kinds rather than one
boolean, and never dresses a collection binding up as a per-file one:

- `FILE` — a ledger row names this exact file
- `COLLECTION` — a row covers the archive as a whole
- `NONE` — nothing covers it

**What this means for retention:** these 127 PDFs have no per-document
provenance anywhere in the operational system. Deleting them destroys evidence
that nothing else records — the manifest written here is now the only
per-document record of what the archive contains. This is precisely what
manifest-first was meant to surface, and it strengthens OWNER's decision:
the G-Drive audit's radical immediate purge would have deleted 127 documents
whose identity was, until this run, unrecorded.

## Independent confirmation of the MQ5 quarantine

The three `.mq5` files bind at **file** level — the ledger names each one
individually, carrying `[RAW_UNTRUSTED][DO_NOT_DEPLOY]`:

- `Prop Challenger EA.mq5`
- `King Trader EA.mq5`
- `TickTrader2.mq5`

The collector classified all three `RAW_UNTRUSTED` independently, from the
artifact class alone (a raw MQ5 from an external archive is never trusted),
without reading the ledger's labels. Independent agreement, 3/3.

This is the same trio quarantined under task `aa6510fb`, and it is now covered
twice over: technically (compile/REVIEW/Q02 promotion from `G:` refused in
code, 46 tests) and by rule (`OWNER-DEC-MQ5-PROMOTION-BAN`, ratified
2026-08-22 — direct promotion of raw MQ5 is permanently forbidden; adoption
runs only via card, V5 re-implementation and the full gate chain).

## Next in the OWNER-mandated order

1. ~~Corpus manifest~~ — done, this document.
2. Dependency / retention dry-run (`2f36c28c`) — was correctly blocked on this
   manifest; the blocker is now removed and it can be re-commissioned. Its own
   finding stands and is now measured: the previously available capped
   inventory was not a safe basis for deletion.
3. Only then may any retention proposal be put to OWNER. Nothing is deleted in
   the meantime.

## Evidence

- `D:\QM\reports\state\g_corpus_manifest_2026-08-22.json` (sha256 above)
- `tools/strategy_farm/build_g_corpus_manifest.py`
- Prior access gate: `docs/ops/evidence/2026-08-22_sp_d1_corpus_manifest_access_gate.md`
- OWNER decision: `decisions/2026-08-22_owner_decisions_evening_batch.md` §3
- MQ5 quarantine: `docs/ops/evidence/2026-08-22_raw_mq5_quarantine.md`
