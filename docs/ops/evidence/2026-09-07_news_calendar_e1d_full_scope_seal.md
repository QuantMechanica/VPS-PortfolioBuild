# News-calendar E1-D full-scope seal evidence — 2026-09-07

## Verdict

`NOT_READY_FAIL_CLOSED`. The E1-B3 candidate remains scoped and is not
admissible for full-scope publication. Four of the eight section 6 gates are
measured failures, one manifest-bound input has changed, canonical candidate
ingress refuses the pair, and no CEO release was supplied. No production
calendar, `FILE_COMMON` copy, contract, hold, or receipt was changed. No repin
record was created.

Candidate manifest:
`b33d0a3def6b19dfd78b977cfd13593806eb85f4b483143a5ca42980c2f4eb99`.

Machine-readable reproduction:
`C:/QM/repo/docs/ops/evidence/2026-09-07_news_calendar_e1d_full_scope_seal.json`.

## Measured gate state

| Gate | State | Exact residual |
|---|---|---|
| 6.1 anchor shares | FAIL | 345 failed source/year/class groups, 2,711 rows, 79 event classes |
| 6.2 coverage | FAIL | all six fresh native currency exports exist, but only USD has confirmed fresh anchors; AUD, CAD, EUR, GBP, and JPY do not |
| 6.3 cross-file identity | PASS | none |
| 6.4 non-USD completeness | PASS | none |
| 6.5 tick footprints | FAIL | 42 checks: 19 PASS, 7 `FAIL_FOOTPRINT`, 7 `MISSING_M5`, 9 `MISSING_OFFICIAL_INSTANT`; 23 unresolved |
| 6.6 no row loss | PASS | none |
| 6.7 detector clean | FAIL | 2,591 failed or unverified HIGH rows; GBP and AUD 2026-H1 native exports remain unverified |
| 6.8 schema | PASS | none |

The declaration coverage on 6.1, 6.2, 6.5, and 6.7 is retained as scope
metadata only. It is never interpreted as a measured pass.

The manifest contains 30 bound inputs. One has drifted since the candidate was
built: `C:/QM/repo/decisions/2026-09-02_owner_receipts_ceo_asks.md` now hashes to
`238840ee797b4182fdbecb6a57deed4afa64f7de28fc7ddbbe5a91f2a4335c1e`, while
the manifest expects
`2616579f82c52e89819bfb92e589a689c8fbe7d00a3f256710cd315291ff89b9`.
A future candidate must be rebuilt against an explicit, current input set; this
run did not amend the existing manifest.

## Non-USD offset and footprint state

| Currency | Confirmed | Passing footprints | Non-rate pass | Selected rows | Residual |
|---|---:|---:|---:|---:|---|
| EUR | no | 2 | yes | 0 | one rate footprint failure; fresh anchor confirmation incomplete |
| GBP | yes | 3 | yes | 66 | one rate footprint failure and one requested historical official instant |
| JPY | no | 1 | no | 0 | official instants incomplete; non-rate footprint requirement unmet |
| AUD | no | 0 | no | 0 | `AUDUSD.DWX_M5.csv` absent; three checks cannot run |
| CAD | no | 0 | no | 0 | `USDCAD.DWX_M5.csv` absent; four checks cannot run |

Only GBP's `-3h` offset is presently confirmed by the E1-B3 evidence. EUR's
two passing footprints and JPY's single passing footprint are insufficient;
AUD and CAD cannot be adjudicated until their M5 exports exist. These facts are
reported without changing thresholds or candidate rows.

## Official-source anchor catalogue (research only)

These primary-source findings close source-discovery work but were not injected
into the manifest-pinned candidate. UTC values are deterministic conversions of
the official local release timestamp using the date's civil-time offset.

| Requested anchor | Official evidence | Derived UTC | Catalogue state |
|---|---|---|---|
| EUR ECB decision, 2024-09-12 | ECB says decisions publish at 14:15 CET; the dated release confirms 12 September 2024 and a 14:45 local press conference: https://www.ecb.europa.eu/press/govcdec/mopo/html/index.en.html and https://www.ecb.europa.eu/press/pr/date/2024/html/ecb.mp240912~67cb23badb.en.html | 2024-09-12 12:15Z (Europe/Berlin was UTC+2) | `SOURCE_LOCATED_NOT_INGESTED` |
| EUR CPI y/y, January 2025 | Eurostat identifies the flash estimate as published 2025-02-03 and the full release as 2025-02-24, but the retrieved primary pages do not state a release time: https://ec.europa.eu/eurostat/en/web/products-euro-indicators/w/2-03022025-ap and https://ec.europa.eu/eurostat/web/products-euro-indicators/w/2-24022025-ap | unresolved | `DATE_LOCATED_TIME_UNRESOLVED` |
| GBP BoE decision, 2024-08-01 | BoE identifies the August decision and states MPC decisions and minutes publish at 12 noon: https://www.bankofengland.co.uk/monetary-policy-summary-and-minutes/2024/august-2024 and https://www.bankofengland.co.uk/monetary-policy- | 2024-08-01 11:00Z (BST) | `SOURCE_LOCATED_NOT_INGESTED` |
| JPY BoJ decision, 2024-07-31 | BoJ records release Wednesday 31 July at 12:56 JST: https://www.boj.or.jp/en/mopo/mpmdeci/state_2024/k240731a.htm | 2024-07-31 03:56Z | `SOURCE_LOCATED_NOT_INGESTED` |
| JPY BoJ decision, 2025-01-24 | BoJ records release Friday 24 January at 12:23 JST: https://www.boj.or.jp/en/mopo/mpmdeci/state_2025/k250124a.htm | 2025-01-24 03:23Z | `SOURCE_LOCATED_NOT_INGESTED` |
| JPY Tokyo CPI, January 2025 | Statistics Bureau states current-month Tokyo preliminary CPI is released at 08:30 JST on Friday of the week containing the 26th: https://www.stat.go.jp/english/data/cpi/1585.htm | 2025-01-30 23:30Z (Friday 31 January JST) | `SOURCE_LOCATED_NOT_INGESTED` |
| AUD RBA decision, 2024-11-05 | RBA's 2024 decision index lists 5 November and states decisions were announced at 14:30 local time: https://www.rba.gov.au/monetary-policy/int-rate-decisions/2024/ | 2024-11-05 03:30Z (AEDT) | `SOURCE_LOCATED_NOT_INGESTED` |
| AUD CPI, 2025-01-29 | ABS records release at 11:30 AEDT: https://www.abs.gov.au/methodologies/consumer-price-index-australia-methodology/dec-quarter-2024 | 2025-01-29 00:30Z | `SOURCE_LOCATED_NOT_INGESTED` |
| CAD CPI, 2025-01-21 | Statistics Canada identifies the December 2024 CPI release date, but the primary HTML retrieval did not expose a verifiable release time: https://www150.statcan.gc.ca/n1/daily-quotidien/250121/dq250121a-eng.htm | unresolved | `DATE_LOCATED_TIME_UNRESOLVED` |

The EUR CPI request also needs OWNER clarification on whether the event means
the 3 February flash estimate or the 24 February final release. The two
unresolved instants remain gate failures.

## Reproducer and dry-run admission contract

`tools/strategy_farm/news_calendar_full_scope_seal.py` is a create-only,
read-only seal reporter. It:

1. rejects duplicate JSON keys and verifies candidate file hashes and row counts
   against the manifest;
2. re-hashes all manifest inputs and records changed or missing inputs;
3. carries all eight exact gate outcomes and full residual records into the
   report;
4. asks canonical `candidate-ingress` to adjudicate the candidate and runs
   read-only receipt-chain verification; and
5. constructs a multi-principal publication plan in memory only if all eight
   measured gates pass, no scope declaration remains, every input hash matches,
   ingress returns `VALIDATED`, and the current repin chain passes.

The present run reports ingress `REFUSED`, current repin-chain `PASS`, and
`WITHHELD_FAILED_FULL_SCOPE_ADMISSION`. The code has no call to repin `record`
and reports `production_write: false`.

## Verification

Focused test command:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_news_calendar_full_scope_seal.py \
  tools/strategy_farm/tests/test_news_calendar_repair.py \
  tools/strategy_farm/tests/test_news_calendar_candidate_ingress.py \
  tools/strategy_farm/tests/test_news_calendar_gate.py \
  tools/strategy_farm/tests/test_news_calendar_repin.py
```

Result: `67 passed in 7.10s`.

## Required continuation (not authorized in this run)

1. Export `AUDUSD.DWX_M5.csv` and `USDCAD.DWX_M5.csv` through the controlled
   export lane without starting a terminal manually or interrupting active
   tests.
2. Obtain primary-source exact instants for EUR CPI and CAD CPI, and resolve the
   EUR flash-versus-final event identity.
3. Expand the official/native anchor taxonomy for the 79 failing HIGH event
   classes, then adjudicate the seven weak footprints and the 2,591 detector
   rows, including the two unverified 2026-H1 exports.
4. Rebuild a new immutable candidate and manifest against current input hashes,
   rerun all eight gates, canonical ingress, and receipt verification.
5. Only after all conditions pass may the tool emit an in-memory dry-run
   multi-plan. Production publication and repin still require CEO release and
   the existing multi-principal authorization path.
