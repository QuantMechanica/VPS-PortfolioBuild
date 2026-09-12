# Q09 legacy calendar rebuild — reissue resolution and cohort plan

**Task:** `fda6370f-df2d-4903-94bb-15cded73a7cd`  
**Decision:** `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909 = YES / Option B`  
**Disposition:** REVIEW — acceptance was already fulfilled by the governed
predecessor; duplicate rebuild correctly suppressed.

## Result

This reissue requested the same QM5_11167 new-identity build already completed
under Codex task `b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3`, independently closed
APPROVED on 2026-09-12. Repeating it would violate the decision's one-pilot,
new-identity-only boundary and allocate a second successor for the same source.

The valid successor is `QM5_41394_weiss-ichi2-ma-calendar-r1`. It has an
APPROVED G0 card, active deterministic registry row, five active magic rows,
current-template source, five setfiles, and governed `COMPILE_EA` receipt
`1fb4d6f0-c15d-4a10-9ff5-9fd56b5a5f4e` with `COMPILE_OK`, strict build PASS,
zero errors/warnings, and EX5 SHA-256
`68c53b0c6de6ec1675e617b8573d7f6c6e9ef139341369614481e60114623b26`.
The receipt SHA-256 is
`336e2001c2af0402ca430a038381e9d375111f05100146bc064f06cd8701ac7f`.

Five Q02 rows were enqueued through the normal queue. Four have worker PASS
(EURUSD, USDJPY, XAUUSD, XTIUSD); SP500 remains pending. This exceeds the
literal acceptance condition that fresh Q02 rows be enqueued. Later Q03/Q04
rows are normal pipeline output and are not altered here.

The original `QM5_11167` MQ5/EX5 remain at the recorded hashes
`6f0647e4...d8ef` / `4b349d21...dd99`; its two Q10_NEWS rows remain
`done/REVIEW_REQUIRED`. No continuity with their verdicts is claimed.

## Complete affected scope

The immutable original census
`2026-09-09_q09_legacy_calendar_input_scope_b66b5ccc.json` has SHA-256
`8c7fb3d4bfa99360b71ac4f1bcd80acc518e9e83fe5acc96834c7b430d10fa29`.
It covers all 53 then-pending Q10_NEWS rows plus the named released B-prime
rows: 55 unique rows, 35 affected and 20 unaffected under the exact boundary
`f0102fbcf279329f607be841c54536b69cfe7f47`.

| EA | Affected rows | Symbols | Named legacy cohort |
|---|---:|---|---|
| QM5_1230 | 2 | XAUUSD | yes |
| QM5_1567 | 4 | EURUSD, GBPJPY, GBPNZD, XAGUSD | no |
| QM5_9573 | 1 | USDCHF | yes |
| QM5_10148 | 1 | EURNZD | yes |
| QM5_10476 | 1 | USDCAD | yes |
| QM5_10569 | 3 | XAUUSD | no |
| QM5_10692 | 9 | NDX | no |
| QM5_10771 | 1 | USDJPY | yes |
| QM5_10847 | 1 | GDAXI | no |
| QM5_11129 | 1 | SP500 | no |
| QM5_11147 | 1 | SP500 | no |
| QM5_11167 | 2 | XAUUSD | yes; pilot source |
| QM5_11179 | 1 | USDJPY | yes |
| QM5_11196 | 1 | XAUUSD | yes |
| QM5_11422 | 1 | USDCAD | no |
| QM5_11476 | 1 | USDJPY | no |
| QM5_12474 | 1 | GBPUSD | yes |
| QM5_12831 | 1 | XTI/AUDUSD basket | no |
| QM5_13059 | 1 | XTI/AUDJPY basket | no |
| QM5_13128 | 1 | NDX | no |

The exact 35 row IDs, snapshot/current states and active holds are preserved in
`2026-09-12_q09_legacy_calendar_scope_current.csv`. Current affected pending
holds are: `NEWS_CALENDAR_TAINTED` 21, `NEWS_CALENDAR_TIMESTAMP_DEFECT` 6,
`NEWS_RUNNER_SPAWN_SILENT_ABORT` 3, and `Q09_AWAITING_SEALED_PLAN` 2. Three
released B-prime rows are now terminal `REVIEW_REQUIRED` (two QM5_11167, one
QM5_11196). This task releases none of them.

## Staged follow-up cohort plan

The remaining OWNER-named cohort is exactly: 11196, 10148, 10476, 10771,
11179, 1230, 12474, 9573. No build below is authorized by this plan alone.

| Stage | Source identities | Required action and stop gate |
|---|---|---|
| 0 | all eight | Freeze original binaries/rows; re-hash card, source, EX5 and held Q10 rows. Resolve contradictions independently (notably 10148's Q09 plan/evidence mismatch). |
| 1 | 11196, 10148 | After a new OWNER follow-up ticket, allocate one new EA ID per source, copy only APPROVED mechanics to the current V5 template, allocate exact symbol magics, then enqueue `COMPILE_EA`. Stop unless both governed compile receipts PASS and expose all calendar inputs. |
| 2 | 10476, 10771, 11179 | Repeat the new-identity/card/registry/COMPILE_EA ceremony. Seed one normal Q02 per successor; expand only after authenticated Model=4 worker evidence. |
| 3 | 1230, 12474, 9573 | Same ceremony, preserving every old hold/verdict. Complete Q02 intake and publish a cohort reconciliation before any Q09/Q10 work. |
| 4 | all successors | Compare tester input echoes and sealed calendar identities. Any Q10 work requires ordinary upstream gates; no repin, publish, threshold, priority, or verdict shortcut. |

Every stage uses a separate allocated ID and magic rows, an APPROVED successor
card, explicit-path commits on `agents/board-advisor`, governed COMPILE_EA only,
and append-only Q02 rows. Old IDs and evidence never move. A stage failure
halts later stages; it does not justify a legacy exception.

## Verification

- `farmctl compile-status QM5_41394_weiss-ichi2-ma-calendar-r1`: compiled 1,
  `COMPILE_OK`, build check PASS, five setfiles.
- `validate_spec_doc.py`: 1 PASS / 0 FAIL.
- `farmctl work-items --ea QM5_41394`: one compile row and five Q02 rows;
  four Q02 PASS, one pending.
- Current MQ5 and EX5 hashes equal the compile receipt.
- Approved card says `g0_status: APPROVED`; registry/magic rows are active.
- `git diff --exit-code -- framework/EAs/QM5_11167_weiss-ichi2-ma`: clean.

No registry allocation, build, compile, queue insert, verdict, hold, priority,
terminal, AutoTrading, T_Live, repin, publish, threshold, or old artifact was
changed in this reissue resolution.
