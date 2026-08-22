# SP-B3 — consolidated news provenance self-report

Date: 2026-08-22  
Router task: `80abf3f5-cfdf-4f2e-9e82-a392bc622d1d`  
Verdict: **IMPLEMENTED, with an explicit pre-V2 non-authoritative mapping marker**

Future Q09 cell receipts now embed one `news_selfreport` object in both the receipt and its hashed cell-evidence document. The collector authenticates equality and rejects empty values for all six requested fields:

1. `source_path`
2. `content_sha256`
3. `row_count`
4. `max_event_date_utc`
5. `schema_version`
6. `mapping_version`

The builder verifies the immutable Q09 calendar bundle before emitting the object and checks that the EVENTS SHA equals the manifest content identity. A focused sample receipt is stored beside this document.

ROT-2 and SP-B2 are still blocked pending the OWNER impact-taxonomy/source decision. Therefore the mapping field is honestly populated as `PRE_V2_UNVERSIONED_OWNER_MAPPING_PENDING`, and the object carries `evidence_authority=NON_AUTHORITATIVE_PRE_V2`. This satisfies observability without representing current two-source semantics as post-V2 comparable evidence. Once ROT-2 is ratified, callers can provide the approved mapping version; the field may never be empty.

Backward compatibility is append-only: historical Q09 cell receipts without this additive object remain readable, including the 23 authenticated predecessor receipts reused by the active successor run. Any newly emitted object must match the hashed evidence document and have every required field populated.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_q09_news_runner_v2.py -q
32 passed in 64.56s

sample bundle verification:
source_path=D:\QM\data\news_calendar\q09_bundles\q09cal-20150101-20260809-0bb19b5bb9790b76\events.csv
content_sha256=86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1
row_count=48245
max_event_date_utc=2026-08-09T01:30:00Z
schema_version=q09-news-calendar-bundle/v2
mapping_version=PRE_V2_UNVERSIONED_OWNER_MAPPING_PENDING
```

No Q09 verdict, work item, active backtest, calendar byte, T_Live, terminal, or AutoTrading state was changed.
