# News-calendar E1-D3/D4 full-scope continuation — REVIEW

Task `d74fa978-4672-4bcc-838b-5948cf5c9c47` completed the requested
source-ingestion, taxonomy, row-adjudication, immutable rebuild, eight-gate
rerun, canonical ingress check, and receipt verification. The outcome is
**`NOT_READY_FAIL_CLOSED`**. No production calendar, `FILE_COMMON` mirror,
bundle, contract, news hold, verdict, publication, or repin was changed.

Candidate:
`D:/QM/reports/news_calendar/repair_e1a/20260907T024800Z_e1d34_continuation/candidate`.
Manifest SHA256:
`5f28c2f3bba94c0c7b78dbff93aba0e2dc22bb8cfbe0b1ec484b5a24ed69366a`.
The manifest binds 32 current inputs; input drift is now **zero**. PRIMARY has
49,235 rows and SECONDARY 49,226 rows.

## Official instants and event identity

The new catalogue contains 58 anchors, including all nine previously requested
instants (two separate BoJ decisions). Each new anchor retains the actual
civil UTC offset for its date. EUR `CPI y/y` is bound to the Eurostat flash
estimate under the CEO task assumption; the final release is not represented
as a separate HIGH anchor. CAD CPI is bound to Statistics Canada The Daily at
08:30 ET. The anchor catalogue is source-ingestion evidence, not publication
authority.

Catalogue:
`D:/QM/reports/news_calendar/repair_e1a/20260907T024800Z_e1d34_continuation/official_anchors.json`
(SHA256 `7aef792e637bb7f486811a8ce519796b81553264d1e65825283f306f0fdd6b04`).

All formerly missing official-instant footprint records are now concrete.
None remains classified `MISSING_OFFICIAL_INSTANT`.

## Taxonomy and 2,591-row adjudication

The taxonomy covers exactly the predecessor's 79 failing HIGH event classes,
345 class/source/year groups, and 2,711 group rows. It separates work that can
be anchored from named official schedules from event-by-event/ad-hoc records
that must remain declared. A declaration remains scope metadata and is never a
measured pass.

| Disposition | Classes | Failed/unverified HIGH rows |
|---|---:|---:|
| `OFFICIAL_SCHEDULE_ANCHOR_REQUIRED` | 39 | 726 |
| `DECLARED_EVENT_BY_EVENT_UNANCHORED` | 40 | 1,865 |
| **Total** | **79** | **2,591** |

Taxonomy:
`D:/QM/reports/news_calendar/repair_e1a/20260907T024800Z_e1d34_continuation/anchor_taxonomy.json`
(SHA256 `1efec608099481053d84597cc6130bf0a8876583dd007ca7abfc67410fc00f03`).
The row-level adjudication is
`high_row_adjudication.csv` (SHA256
`a0347846da3f1b63eb370959c62e393cefa6dd04bb53e309d9e4858718e803cc`).

The GBP and AUD 2026-H1 exports were rechecked rather than presumed valid.
Their mixed observed offsets remain unresolved by the existing whole-file
selector: GBP has `-10800/-7200` seconds and AUD has
`-14400/-10800` seconds. Both therefore remain explicitly excluded from the
candidate truth stream; the code does not guess a global offset across event
classes or DST regimes.

## Eight measured gates

| Gate | Result | Exact residual |
|---|---|---|
| 6.1 anchor shares | FAIL | 345 groups, 2,711 group rows, 79 classes |
| 6.2 coverage | FAIL | only USD fresh-export anchors confirmed; GBP/AUD mixed-offset exports remain unverified |
| 6.3 cross-file identity | PASS | none |
| 6.4 non-USD completeness | PASS | none |
| 6.5 tick footprints | FAIL | 51 checks: 27 PASS, 24 `FAIL_FOOTPRINT`; zero missing M5 and zero missing official instants |
| 6.6 no row loss | PASS | none |
| 6.7 detector clean | FAIL | 2,591 failed/unverified HIGH rows; 2 unverified native exports; 0 changed inputs |
| 6.8 schema | PASS | none |

Canonical candidate ingress correctly returned `REFUSED` because the candidate
retains explicit inadmissible ranges. Current repin-chain verification passed.
Because four measured gates fail, no in-memory publication multi-plan was
emitted; status is `WITHHELD_FAILED_FULL_SCOPE_ADMISSION`.

Seal report:
`D:/QM/reports/news_calendar/repair_e1a/20260907T024800Z_e1d34_continuation/full_scope_seal.json`
(SHA256 `1fd956ffca746eb989dd832a3419094035eb9b585b0c41409d8af7017ca59976`).

## Verification

Focused suite:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_news_calendar_e1d34_continuation.py \
  tools/strategy_farm/tests/test_news_calendar_full_scope_seal.py \
  tools/strategy_farm/tests/test_news_calendar_repair.py \
  tools/strategy_farm/tests/test_news_calendar_candidate_ingress.py \
  tools/strategy_farm/tests/test_news_calendar_gate.py \
  tools/strategy_farm/tests/test_news_calendar_repin.py \
  tools/strategy_farm/tests/test_news_calendar_export_e1d2_m5.py
```

Result: `75 passed in 7.95s`. `git diff --check` passed for the five new source
and test files. Machine-readable summary:
`docs/ops/evidence/2026-09-07_news_calendar_e1d34_continuation.json`.
