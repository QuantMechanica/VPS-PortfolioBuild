# QM5_11167 legacy calendar-input rebuild — execution evidence

- Generated: `2026-09-09T09:04:53Z`
- Router task: `b66b5ccc-7826-4c60-9d64-2bb5d3fb09c3`
- OWNER decision: `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`
- Decision receipt: `70823296-549a-4fba-8d2d-68ef34607664`
- Branch: `agents/board-advisor`
- Result: `REVIEW_REQUIRED — BUILD_PASS_Q02_ADMITTED_TESTER_ECHO_PENDING`

The authorized rebuild is complete through governed compile and first-Q02
intake. The one first-Q02 row is still in the normal queue, so no tester report
exists yet. This record does **not** claim a Q02 verdict or a tester-report echo
of the three calendar-bundle inputs. Independent review should retain this item
in REVIEW until that external execution evidence exists.

## Acceptance ledger

| Requirement | Result | Evidence |
|---|---|---|
| Measure the exact pending Q10_NEWS and named B-prime scope | PASS | `2026-09-09_q09_legacy_calendar_input_scope_b66b5ccc.json` |
| Rebuild only QM5_11167 mechanics as a distinct identity | PASS | New identity `QM5_41394_weiss-ichi2-ma-calendar-r1`; commits below |
| Use the current V5 template/framework contract | PASS | Source/SPEC validation, governed strict build check, and hook order below |
| Compile cleanly | PASS | `COMPILE_OK`, build check PASS, 0 errors, 0 compiler warnings |
| Compile with the current NewsFilter calendar inputs | PASS (structural) | Source-bound include closure contains current `QM_NewsFilter.mqh` and all three declarations |
| Show the three inputs in this EA's tester report echo | PENDING | Q02 `58b36f74-a831-4119-943b-8a9924b20179` is pending; `evidence_path` is null and its report directory does not exist |
| Create exactly one new Q02 row | PASS | DB census returns one Q02 row for `QM5_41394` |
| Inherit no QM5_11167 Q02-Q09 continuity | PASS | New identity has only one COMPILE_EA row and one pending Q02 row |
| Preserve old binary, old Q10 rows/evidence, and the other cohort members | PASS | Byte/state checks and explicit commit pathspecs below |
| Make no gate, threshold, verdict, T_Live, AutoTrading, or manual-terminal change | PASS | No such path/state was mutated; compilation used the governed resident worker |

## Exact scope measurement

The machine-readable census is
`docs/ops/evidence/2026-09-09_q09_legacy_calendar_input_scope_b66b5ccc.json`
(commit `58ad7cbd20`). Its snapshot covers 55 unique Q10_NEWS rows: all 53 rows
pending at `2026-09-09T08:25:53Z` plus the explicitly named B-prime rows
`a909ee18`, `f625d9aa`, and `6797ed1c` (with `a909ee18` already present in the
pending set). It classifies 35 rows affected and 20 unaffected under:

`affected = includes QM_Common/QM_NewsFilter AND f0102fbcf2 is not in the EX5 build history`

All nine legacy-logger cohort EA IDs are present: `QM5_1230`, `QM5_9573`,
`QM5_10148`, `QM5_10476`, `QM5_10771`, `QM5_11167`, `QM5_11179`,
`QM5_11196`, and `QM5_12474`. Each row records the work-item ID, EA ID,
symbol, status/verdict, source and EX5 paths, EX5 SHA-256, byte-resolved build
commit/date, include result, boundary ancestry, affected flag, and allowlist
membership. Git blame binds the three tester inputs at lines 73–75 of
`QM_NewsFilter.mqh` to boundary commit
`f0102fbcf279329f607be841c54536b69cfe7f47` (2026-08-03).

## Fresh identity and mechanics

- New EA: `QM5_41394_weiss-ichi2-ma-calendar-r1`
- Registry ID/slug: `41394,weiss-ichi2-ma-calendar-r1`
- Strategy/source UUID: `3005c768-aa91-5daf-9dd7-500d7bfcb7a6`
- Card of record: `artifacts/cards_approved/QM5_41394_weiss-ichi2-ma-calendar-r1.md`
- EA package: `framework/EAs/QM5_41394_weiss-ichi2-ma-calendar-r1/`
- Symbols/magic numbers: EURUSD `413940000`, USDJPY `413940001`, XAUUSD
  `413940002`, SP500 `413940003`, XTIUSD `413940004`; all `.DWX`, active,
  collision-free slots 0–4.

The old mechanics are retained: D1 SMA 9/26 direction with slow-SMA slope,
ATR(20) × 3 catastrophic stop, reverse-signal exit, and one position per
symbol/magic. The source uses the current V5 lifecycle: MAE tracking precedes
the kill switch, management and exits remain active through news windows,
the central news check gates entries only, new-bar gating precedes request
construction, and `QM_EntryRequest` is zero-initialized.

All five governed baseline setfiles use `RISK_FIXED=1000` and
`RISK_PERCENT=0`. The EA source defaults to the same values and caps
`qm_news_stale_max_hours` at `336`.

There is no pipeline-continuity assertion. The old ID remains `QM5_11167`; the
new ID starts with a fresh compile record and one fresh Q02 canary only.

## Current calendar-input and compile proof

`docs/ops/evidence/QM5_41394_include_closure.json` is a fail-closed recursive
include closure generated after compilation. It binds:

- source SHA-256: `3e5aae565f2f7faba9082a3ca88719a103f7f5372e228c9e250d00505f335a76`
- EX5 SHA-256: `68c53b0c6de6ec1675e617b8573d7f6c6e9ef139341369614481e60114623b26`
- 38 resolved files (31 repository files and 7 MT5 standard-library files)
- `QM_Common.mqh` SHA-256: `eee41e2f06ac22b8fa398529e93e24038a3b460113145e7f77fb390decf10b90`
- `QM_NewsFilter.mqh` SHA-256: `739230a0ba963c11f84d858f5bb8886a8b48a5e84f0be2ded29f8f813f2b6233`

The new EA directly includes `<QM/QM_Common.mqh>`. That closure reaches the
current `QM_NewsFilter.mqh`, whose plain EA inputs are:

- `qm_news_calendar_bundle_id`
- `qm_news_calendar_expected_sha256`
- `qm_news_calendar_common_relative_path`

Governed compile work item
`1fb4d6f0-c15d-4a10-9ff5-9fd56b5a5f4e` completed `COMPILE_OK` on resident
slot T5 at `2026-09-09T08:50:34Z`. Its evidence is:

`D:/QM/reports/work_items/1fb4d6f0-c15d-4a10-9ff5-9fd56b5a5f4e/QM5_41394/COMPILE_EA/compile_evidence.json`

The evidence reports strict build check PASS, 0 compile errors, 0 compile
warnings, five generated setfiles, the source/EX5 binding above, and no gate
verdict. The strict check also emitted three non-failing card-discovery
advisories; the governed setfile generator independently resolved the exact
approved card path above for all five files. No local/ad-hoc terminal compile
was substituted.

## First Q02 intake and remaining evidence gap

Canonical `farmctl intake-first-q02` appended exactly one row:

- Work item: `58b36f74-a831-4119-943b-8a9924b20179`
- EA/symbol/timeframe: `QM5_41394 / EURUSD.DWX / D1`
- State: `pending`; verdict: null; evidence path: null
- Setfile SHA-256: `a4f9912c8e990784fd3e845fe379cc88e69090afe823a1c588c8dbedacd419d3`
- EX5 SHA-256: `68c53b0c6de6ec1675e617b8573d7f6c6e9ef139341369614481e60114623b26`
- Priority boost: false
- Deferred symbols: SP500.DWX, USDJPY.DWX, XAUUSD.DWX, XTIUSD.DWX
- Intake receipt:
  `D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/1fb4d6f0-c15d-4a10-9ff5-9fd56b5a5f4e_58b36f74-a831-4119-943b-8a9924b20179.json`
- Receipt SHA-256:
  `be3b92f415d3abd4248830e0b931488846d40eb304a4881ef57c7496e4e88ae0`

The canonical DB census returns two rows for the new identity—one done
COMPILE_EA/COMPILE_OK and this one pending Q02—and therefore exactly one Q02.
The report directory
`D:/QM/reports/work_items/58b36f74-a831-4119-943b-8a9924b20179`
does not exist. The scheduler, not this orchestration cycle, owns execution.
No priority mutation or terminal start was used to bypass the queue.

## Preservation checks

The original assets reproduce the pre-action hashes and have no Git diff:

- Old EX5 SHA-256:
  `4b349d21060502bd5f4ce3eb7619b1bed75e7e9630ea74eb7d85b06e4795dd99`
- Old MQ5 SHA-256:
  `6f0647e462924ce1ab7b8b967e77a570c3d6248f3bfb6321c2e21981f019d8ef`
- `git diff --exit-code -- framework/EAs/QM5_11167_weiss-ichi2-ma` returned 0.

The two released QM5_11167 Q10_NEWS rows also reproduce the pre-action state
and hashes:

| Work item | State/verdict | Canonical full-row SHA-256 | Aggregate SHA-256 |
|---|---|---|---|
| `f625d9aa-da34-44bb-aa9f-0eda284f3f32` | done / REVIEW_REQUIRED | `9a9ea81f1020bb3609dedd9e99ee8930cbf44a4328ed53d75c274e9669dd2a40` | `17b100b7c3bee61cfcba26a2339304735fe54bcf522349eb46145ffadd3994e4` |
| `6797ed1c-597a-4d44-82f9-7379d45b5e06` | done / REVIEW_REQUIRED | `2af138bf9f2008c3f5df35979daff9ddeea04d9b330e99dcc2253527d06231d6` | `8fbd8829fe9221c6402a720d3019ab13060a6fcd4955c6f606db3ca38da0a12d` |

The implementation commits contain only the new card/identity, five magic
rows and resolver regeneration, the new EA package, and task-specific evidence.
No old cohort EA path occurs in their pathspecs.

## Verification ledger

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41394_weiss-ichi2-ma-calendar-r1`
  → `1 PASS, 0 FAIL`.
- `python tools/strategy_farm/farmctl.py compile-status QM5_41394_weiss-ichi2-ma-calendar-r1`
  → one compiled, `COMPILE_OK`, build check PASS, five setfiles, no failure class.
- `python tools/strategy_farm/farmctl.py work-items --ea QM5_41394`
  → one done COMPILE_EA plus one pending Q02.
- `python tools/strategy_farm/build_q09_include_closure.py --ea-id QM5_41394 --out-dir docs/ops/evidence`
  → 38 files resolved, no unresolved include.
- Direct read-only DB census → `all_count=2`, `q02_count=1`.
- Old-directory diff, old-file SHA-256, Q10 full-row SHA-256, and aggregate
  SHA-256 checks all match the recorded pre-action values.

## Commit ledger

- `58ad7cbd20` — exact legacy calendar-input scope census
- `cd86803329` — reserve new EA identity
- `7e11a3e8ca` — approved card and governed magic allocation
- `08bbce50e2` — current-template source, SPEC, and five baselines
- `99d6330963` — source-matched governed EX5 and hash-bound setfiles

This evidence is intentionally a REVIEW artifact. The next authorized
observation is the normal worker's Q02 output; only that report can close the
remaining tester-input-echo acceptance item.
