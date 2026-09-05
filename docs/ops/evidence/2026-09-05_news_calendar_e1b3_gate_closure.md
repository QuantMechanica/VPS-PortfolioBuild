# E1-B3 calendar gate closure — bounded scope, REVIEW

Task `41e3ee1c-266f-4523-9a66-b175d271b0e2`; code `51c75174cb` on `agents/codex-news-e1b3-20260905`. **Four measured PASS gates; four failing gates fully accounted for by explicit inadmissible ranges. No publication.** The declaration is a scope exclusion, not a successful measurement or permission to use the full calendar.

New staging child: `D:/QM/reports/news_calendar/repair_e1a/20260905T112500Z_e1b3_candidates`. Manifest SHA256 `b33d0a3def6b19dfd78b977cfd13593806eb85f4b483143a5ca42980c2f4eb99`. PRIMARY 49,207 rows, SECONDARY 49,216 rows. All source CSV hashes remain unchanged. The repair preserves impact labels and existing rows.

| Gate | Measured result | Scoped result and residual |
|---|---|---|
| 6.1 anchor shares | FAIL | COVERED_BY_DECLARATION: 345 class/source/year groups; mandatory native names now complete |
| 6.2 coverage | FAIL | COVERED_BY_DECLARATION: EUR/GBP/JPY/AUD/CAD H1 HIGH ranges; only USD has confirmed anchors in the accepted candidate truth stream |
| 6.3 cross-file identity | PASS | Common identities agree |
| 6.4 non-USD completeness | PASS | Explicit native completeness/gap inventory retained |
| 6.5 tick footprints | FAIL | COVERED_BY_DECLARATION: 27 declarations; 42 checks yield 19 PASS, 7 failed footprints, 7 missing M5, 9 missing official instants |
| 6.6 row loss | PASS | No source row dropped |
| 6.7 detector clean | FAIL | COVERED_BY_DECLARATION: 2,591 unverified/failed HIGH rows and the two conflicting export files; no changed input |
| 6.8 schema | PASS | Both canonical schemas parse |

The manifest contains **18,279** explicit currency × event-class × month declarations: 345 for 6.1, five for 6.2, 27 for 6.5 and 17,902 for 6.7. Each includes its reason, required evidence, gate and stable ID. Broad class/year exclusions are conservative: all months of the affected class/year are unavailable, including otherwise good rows. Missing M5 windows are bounded by the affected month; unconfirmed currency selectors additionally exclude their observed months. Every failed anchor group, failed footprint and unverified export was independently checked against these declarations. There is no claim that the reduced scope is useful or production-ready.

## Export and timestamp evidence

The existing guarded StartUp wrapper gained `--catalog-h1`. It compiled the exporter with **0 errors / 0 warnings**, exported Core PPI (7 rows), Empire State (6), Building Permits (9) and Trade Balance (7), then terminated only its owned T_Export process, PID 23924. Receipt: `2026-09-05_news_calendar_e1b3/export_receipt.json`; original run child `20260905T112000Z_e1b3_export`. No active research terminal was interrupted.

`official_anchors.json` records 49 source-backed instants across all six currencies. Local civil times are converted with named IANA zones. Each of the 14 fresh/catalog files has at least three distinct official anchor comparisons. Eight USD ALL files are already UTC; the USD HIGH H1 file requires -10,800 seconds. EUR, JPY and CAD H1 meet the existing three-anchor rule with -10,800 seconds. These are sampled file-model checks, not proof of every individual event class. In particular, the non-USD candidate still requires its separate footprint/selector evidence.

GBP H1 has three rate offsets of -10,800 seconds but CPI requires -7,200 seconds. AUD H1 requires -14,400 seconds for February/March and -10,800 for May. Both files remain excluded from truth. No global offset was guessed. See `encoding_proof.json` for file hashes, counts and all observed offsets. The GBP conflict is grounded in the [ONS January CPI release time](https://www.ons.gov.uk/releases/consumerpriceinflationukjanuary2026) and the [BoE announcement convention](https://www.bankofengland.co.uk/monetary-policy); the AUD changes follow the [RBA's dated AEDT/AEST calendar](https://www.rba.gov.au/schedules-events/calendar/).

The actual revised [BLS 2026 schedule](https://www.bls.gov/schedule/2026/home.htm), [Census construction release calendar](https://www.census.gov/economic-indicators/calendar-listview.html) and [Census trade schedule](https://www.census.gov/foreign-trade/schedule.html) take precedence over stale cross-agency dates in the New York Fed's 2026 calendar. The New York Fed calendar is used for its own Empire releases and verified 2025 dates. Additional sources are the [ECB decision calendar](https://www.ecb.europa.eu/press/govcdec/mopo/html/index.sq.html), [Bank of Canada schedule](https://www.bankofcanada.ca/2025/08/bank-canada-publishes-2026-schedule-policy-interest-rate-announcements-other-major-publications/), [Japan CPI dates](https://www.stat.go.jp/english/data/cpi/1582.html) and [Japan release-time convention](https://www.stat.go.jp/data/guide/3.html). Full source URLs accompany each anchor; source preparation under the routed delegation is not publication approval.

## Implementation and verification

`news_calendar_repair.py:131` includes H1 ALL catalogs; `:162` counts unique release instants so two survey periods released simultaneously do not become two timing anchors. `:562` adds optional scope accounting and `:581` binds it into the manifest. `news_calendar_scope.py:10` derives explicit exclusions from each failed evidence basis; `:76` labels scoped accounting while leaving every measured pass boolean intact. Input mutation cannot be declared away. `news_calendar_candidate_ingress.py:35` rejects scoped candidates even if a malformed caller presents eight true gate booleans. This preserves the full-calendar publication boundary.

**37 tests PASS**, covering the repair, detector, scope, guarded exporter and ingress. New cases include contradictory timing offsets, simultaneous releases, bounded failures, unresolved input mutation, undated footprint refusal and attempted publication of a scoped candidate. The independent evidence receipt confirms all failed groups are declared, all input CSV byte hashes match, and every archived file decompresses to its recorded SHA256.

Canonical evidence directory `2026-09-05_news_calendar_e1b3/` contains the anchor catalog, export receipt, encoding proof, verification receipt and ten lossless gzip archives of the manifest, declarations, gate evidence, gaps, footprint details and candidate pair. Read a compressed JSON with Python `json.loads(gzip.decompress(Path(path).read_bytes()))`; original D:/QM artifacts remain intact. The gzip archive SHA256 and decompressed SHA256 are both recorded. Total evidence footprint is approximately 2.75 MB.

The thirteen held Q09/Q10_NEWS rows remain held. Production calendars, FILE_COMMON mirrors, bundles and dxz23 were not published or repinned. The current candidate cannot enter full-scope ingress. A future full PASS requires resolving the listed source/encoding/M5 gaps or a separately reviewed scope-enforcing consumer; an exclusion declaration alone cannot justify resealing. Claude+OWNER integration remains separate.
