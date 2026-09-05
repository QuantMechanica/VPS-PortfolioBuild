# E1-A calendar repair candidates — REVIEW, verification FAIL

Router task `8eb9f74b-67bb-42e4-8979-077e2d39f64b`; OWNER receipt row 9; decision binding `OWNER-DEC-CALENDAR-E1A-20260905`. The offline builder, tests, candidate pair, verification runner and compiled manual exporter are delivered. **The candidates are not publishable.** Data and governed-publication prerequisites remain unresolved; this is not a pipeline verdict or a reseal approval.

Code commit `b88ea75f4838438c5f8fe3916da64c29abd98878` is on `agents/codex-news-calendar-repair-20260905` in `C:/QM/worktrees/codex-lock-attribution-20260905`. The existing `agents/codex` checkout is divergent and contains unrelated edits, so this isolated Codex branch preserves those changes. Code has not been integrated into canonical tooling or main. The exact four-file patch is [2026-09-05_news_calendar_repair_e1a.patch](2026-09-05_news_calendar_repair_e1a.patch), SHA256 `061627b9a0fa07cebea6170bad6c0c73c99b618d9fe681c34dbcc7f111625fac`.

Final candidate directory: `D:/QM/reports/news_calendar/repair_e1a/20260905T094500Z/`. Earlier `093500Z` and `094000Z` diagnostic iterations remain retained; they are superseded by this directory. The first exposed the separate-range USD export defect described below and must not be used.

| Final artifact | Rows | SHA256 |
|---|---:|---|
| `news_calendar_2015_2025.csv` | 48,954 | `d936e680b69446f3b19b15aa498d6ac6f616db06cb6a34fc93275f6dc07df151` |
| `forex_factory_calendar_clean.csv` | 48,963 | `76e22d47ef4de26f39a7887bee33310a1c48f857d3f99902195d7756a6585c44` |
| `manifest.json` | — | `29ce8215f98de53e800937292d8fa8e6b6ffabe7d941f28065556abb4ffa0dde` |
| `verification.json` | — | `46c3d5bd58ba1c2727afb30ebbc12fc9adbe31bef214d6e815c889ec47b50124` |

Canonical evidence copies, input hashes, full per-gate results, CSV footprints and the 45-file staged artifact index are in [2026-09-05_news_calendar_repair_e1a](2026-09-05_news_calendar_repair_e1a/). `row_transform.csv`, the full `repair_gaps.json`, candidates and rollback snapshots remain in the staged directory and are hash-bound by that index. The E2/E4 handoff is `e2_e4_gap_inventory.csv`, with 2,486 unresolved native non-USD event windows, affected currency/symbol examples and a PRE30_POST30 potential under-block upper bound. This is an input inventory, not an enqueue or re-adjudication.

## What the tool implements

`news_calendar_repair.py` reads the two exact production schemas, captures the current row counts and cross-file identity in `baseline.json`, and hashes its input files before/after processing. It writes only a new child of the E1-A staging root. Existing output directories are refused. The private lab is read as AST data literals; its builders are never executed.

USD timestamps are replaced by native or pinned official release instants, including FOMC Statement and Economic Projections. Matching uses the exact maintained name map and a bounded ±36-hour join. No release date is reconstructed from a corrupted stored date. Medium/low labels and actual/forecast/previous strings are retained. Class-D residuals stay inert; other unverified medium/low rows remain Class E. A high-impact row with no authoritative date is retained for audit continuity and explicitly declared unresolved, which prevents a publishable result. No schedule date is invented to conceal missing data.

The separate USD 2025 export is **cross-check only**. Actual observation: both the full-range 2025 slice and separate-range file have 480 rows; all 480 separate-range timestamps are **+10,800 seconds** against the corresponding full-range event. They must never be unioned as a second truth stream. The manifest records the histogram and excluded role. The original plan's 481-row number is not used as a constant.

Non-USD correction requires at least three distinct confirmed footprint anchors, including a non-rate check, before trusting a currency's rate class. The private lab's implementation actually emits a conservative offset union, including all non-rate classes; it does not itself select one offset. This tool selects only demonstrated offsets and does not extrapolate a varying AUD fan into an unproved seasonal rule. JPY raw time is treated as a candidate requiring confirmation. The documented CAD January 29 override is supported when confirmation exists. Non-rate and unconfirmed classes become declared gaps.

The current confirmations support GBP's -3-hour rate offset: two rate observations and the January CPI observation pass. EUR has only two passing observations, JPY one, and AUD/CAD have no available matching M5 files. The correction therefore accepts 66 GBP native rate events and leaves other non-USD offset paths unconfirmed. The global footprint gate still fails because the full requested observation list is incomplete.

Both output schemas are projected deterministically, with all PRIMARY flags/date fields regenerated and each original impact label retained. SECONDARY `DateTime_UTC` preserves seconds; the diagnostic parser now supports that allowed format. `DateTime_EET` uses the EU last-Sunday March/October 01:00Z rule, solely for display. M5 broker epochs use the separate US-DST -2/-3-hour conversion before comparison. The confirmation probe records a ±15-minute peak, same-slot control median and raw-native comparison band; its declared diagnostic threshold is 1.5 times the control median. Volume confirms an official anchor and never supplies a missing release date.

The optional native mode in `news_calendar_diagnose.py` checks every USD HIGH class in 2018–2026 against an explicit expectation catalog. Missing anchors fail. It accepts the native November 20, 2025 NFP reschedule without applying a first-Friday rule. The legacy report-only schedule mode remains available. Neither the production gate nor its enforcement mode was changed.

## Measured result and verification

Captured baseline: PRIMARY 48,630 rows; SECONDARY 48,639; 46,352 identical common instants. The builder replaces 1,724 PRIMARY and 1,725 SECONDARY USD timestamps, leaves 1,063 native-exact USD rows per file unchanged, applies 120 existing GBP rate/statement row corrections per file, and adds **324 backfill rows per file**: 318 USD and six GBP. It does not drop rows or reconcile the impact taxonomy.

| Plan check | Result | Evidence |
|---|---|---|
| 6.1 all USD HIGH anchor shares | FAIL | 366 failing class/year/source groups; mandatory native targets absent |
| 6.2 coverage | FAIL | 2025-05..12 globally filled; all six 2026-H1 months still empty and explicitly declared; fresh exports absent |
| 6.3 common-event identity | FAIL | Previously identical rows preserved; 2,278 pre-existing +1-minute differences remain without authoritative reconciliation |
| 6.4 non-USD completeness | PASS | 40 currency/year rows and quantified E2/E4 gap inventory |
| 6.5 tick-volume confirmation | FAIL | 30 checks: 11 PASS, three failed observation bands, seven missing M5, nine missing exact official instants |
| 6.6 row-loss accounting | PASS | +324 per file, zero declared or unexplained drops |
| 6.7 native-mode detector clean | FAIL | 2,772 failed or unverified USD HIGH rows; zero unexplained global hole months; zero changed input hashes |
| 6.8 schema/format | PASS | Production parser accepts both candidates; exact 20/9 columns, UTF-8, no BOM/NUL |

Mandatory target-name validation names the absent targets: **Core PPI m/m, NY Empire State Manufacturing Index, Building Permits, Trade Balance**. The exporter cannot supply them from its current HIGH-only input. Supplying just the 2026-H1 exports will therefore not make all gates pass. Missing dates require an authoritative native/official source; unverified high-impact rows and the common-file minute differences must be resolved or the acceptance contract explicitly revised by OWNER. The tool has no blanket gap-to-PASS switch.

USD spot checks show elevated volume at the required June NFP, August CPI and June Fed instants: peak/control ratios 4.4705, 5.1707 and 5.6445. The October CPI and December ECB/BoE bands have no matching observations in the supplied M5 data. Backfilled months have no pre-repair CSV row; the report does not invent a displaced timestamp and label it observed. Raw-native comparison bands are explicitly named as such.

Focused tests: **14 passed in 1.02 seconds**, covering displaced NFP, consumed-column DST seam, FOMC, rescheduled NFP, hole backfill, impact preservation, common identity, deterministic output bytes, declared gaps, broker conversion, varying offset rejection, release identity, excluded +3-hour sidecar, input immutability and staging guards. `git diff --check` passed. The prepared exporter compiles with **0 errors / 0 warnings**, 731 ms; MetaEditor returned process code 1, so the explicit compiler Result line is the success evidence. No terminal was launched or script executed.

## Prepared manual 2026-H1 export

The source and compiled script are staged beside the candidates:

- `EXPORT_T_EXPORT_HIGH_2026H1.mq5`, SHA256 `41c5633a54f61e9fe479688794cfded33912073ddb72da12d4955509fddc3bee`.
- `EXPORT_T_EXPORT_HIGH_2026H1.ex5`, SHA256 `93f4119cfe3756d3a807c9bfc6ad2f210d7f9a93e20c28b0d275cfd25dab7b72`.

After review, OWNER/CEO copies the script into T_Export's `MQL5/Scripts` and manually runs it six times with `InpCurrency` = USD, EUR, GBP, JPY, AUD, CAD. The script enforces T_Export, uses **2026-01-01 inclusive to 2026-07-01 exclusive**, queries one currency/half per invocation, sorts observations and refuses an existing export filename. Error 5401 stops that currency without switching to a live fallback; retry only the failed currency. Retain any incomplete output under a different name before an OWNER-controlled retry.

Output/ingest path: `D:/QM/mt5/T_Export/MQL5/Files/T_EXPORT_<CCY>_HIGH_2026H1_NATIVE.csv`. Each row also carries `value_id`. `event_id` is a recurring event-class ID and legitimately repeats; uniqueness is checked on `value_id`, or `(event_id, broker_time)` for old-format sidecars. A literal ban on repeated `event_id` would reject normal monthly releases. The loader checks monotonic raw timestamps, the half-year range and duplicate release identities. USD month counts are reported; missing months fail coverage. Raw encoding must be checked against independent official instants; the observed separate-range +3-hour defect makes assuming UTC unsafe.

Additional approved official anchors can be supplied through `--extra-anchors`. The JSON needs `decision_id`, `approved_by`, `approved_at` and `anchors[]`, each carrying `currency`, `event_code`, `utc` with timezone, `kind` (`rate`, `nonrate`, or `usd`) and a source reference. No approval fields or unknown release instants were fabricated. Use release-specific official notices rather than treating example dates in the plan as verified schedules.

After code integration and input preparation, the exact candidate command is:

```powershell
python C:/QM/repo/tools/strategy_farm/news_calendar_repair.py --extra-anchors D:/QM/reports/news_calendar/repair_e1a/owner_official_anchors.json --out D:/QM/reports/news_calendar/repair_e1a/<NEW_RUN_ID>
if ($LASTEXITCODE -ne 0) { throw 'E1-A verification failed; reseal prohibited' }
```

## CEO reseal checklist and current executable boundary

There is **no supported end-to-end corrected-candidate reseal command in the current checkout**. This is a measured control-plane limitation, not a permission request:

1. `refresh_news_calendar.ps1` accepts weekly feed inputs and `-ReconciliationPlanOnly`; it has no candidate-file ingress. Running it today re-appends the existing seed, not these corrected files.
2. A read-only canonical `news_calendar_gate.py multi-plan` against these staged files exits 2: `production candidates must be the exact D source pair or one canonical state staging pair`. The allowed staging root is the refresh-owned `D:/QM/reports/state/news-calendar-staging-<32hex>` directory. See `reseal_admission.json`. This task did not copy files there to bypass the intended flow.
3. `news_calendar_repin.py` still fixes `OWNER_DECISION_ID = OWNER-DEC-CALENDAR-REPIN`; its CLI has no E1-A authority option. `record` also requires the actual refresh parent PID and matching operation proof. The payload's requested E1-A decision ID therefore needs a governed authority migration that preserves verification of prior receipts. No gate, repin code, registry or parent proof was altered.

CEO/OWNER must first close those governed ingress/authority gaps. It would be misleading to invent unsupported flags or present the normal weekly refresh as the repair command. The exact existing commands and required ordering after that close-out are:

1. **Require all eight verification checks PASS**, bind the final manifest hash, and re-capture the current production manifest, immutable bundle ID, Q09 parent manifest and dxz23 records. The staged `rollback_snapshot` is a read-only reference snapshot and must be refreshed immediately before reseal. Retain old bundles. Do not enter a Factory OFF/ON recovery window while dxz23 has repin-pending changes.
2. **CEO runs the reviewed governed candidate-ingress refresh path**. It must re-append the current forward feed, issue the gate multi-plan, bind its exact plan hash and existing Factory generation, publish all four Common mirrors, and invoke `news_calendar_repin.py record` from that same refresh process. This is the blocked step; an ad hoc `Copy-Item` to production or forged parent environment is not an equivalent command.
3. **CEO/refresh ops reconciles and commits only the repin-generated registry diff**, under the approved E1-A authority. No AI seat hand-edits or commits dxz23. Verify the receipt chain using the existing read-only command:

```powershell
python C:/QM/repo/tools/strategy_farm/news_calendar_repin.py verify
if ($LASTEXITCODE -ne 0) { throw 'Calendar repin verification failed' }
```

4. **OWNER provides the Q09 correction receipt.** The staged `owner_approval_receipt.template.json` has empty approval fields and is explicitly not an approval. Required completed fields are `approved_by`, `approved_at`, `reason`, and **`correction_reason`** citing E1-A. It also binds the decision ID, candidate manifest SHA and parent bundle ID. Snapshot parent currently: `q09cal-20150101-20260809-0bb19b5bb9790b76`, content SHA `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1`.
5. **Plan and publish Q09 as APPROVED_CORRECTION**, after the governed pair publication and repin succeed. The variables below must refer to the current verified parent, completed OWNER receipt and newly verified coverage endpoints; placeholders are not approval or coverage evidence:

```powershell
$e1aParent = '<CURRENT_VERIFIED_Q09_PARENT_MANIFEST>'
$e1aReceipt = '<COMPLETED_OWNER_CORRECTION_RECEIPT>'
$e1aCoverageFrom = '<VERIFIED_COVERAGE_FROM_UTC>'
$e1aCoverageTo = '<VERIFIED_COVERAGE_TO_UTC>'
$e1aQ09Args = @('--source-csv', 'D:/QM/data/news_calendar/news_calendar_2015_2025.csv', '--receipt', $e1aReceipt, '--coverage-from-utc', $e1aCoverageFrom, '--coverage-to-utc', $e1aCoverageTo, '--publication-reason', 'APPROVED_CORRECTION', '--parent-manifest', $e1aParent)
python C:/QM/repo/tools/strategy_farm/q09_news_calendar.py plan @e1aQ09Args
if ($LASTEXITCODE -ne 0) { throw 'Q09 correction plan failed' }
python C:/QM/repo/tools/strategy_farm/q09_news_calendar.py publish @e1aQ09Args --bundle-root D:/QM/data/news_calendar/q09_bundles --apply
if ($LASTEXITCODE -ne 0) { throw 'Q09 correction publish failed' }
python C:/QM/repo/tools/strategy_farm/q09_news_calendar.py verify --bundle '<NEW_BUNDLE_DIRECTORY_FROM_PUBLISH_RESULT>'
```

An interior correction is not `HORIZON_EXTENSION`. The standalone Q09 publication does not automatically repoint every consumer: record old→new bundle/content hashes and perform the separately approved consumer provisioning/configuration before accepting any new evidence.

6. **Verify the four mirrors individually**: Administrator, SYSTEM `systemprofile`, QMDev1 and QMDev2. Compare each active pair and manifest to the D: source and run `news_calendar_gate._verify_immutable_bundle(common_dir, manifest)` for each; the repin source comparison alone is insufficient. Confirm every dxz23 role hash/coverage, the new Q09 identity, and a clean reconciliation tree. Keep old bundle and receipt-chain records as rollback targets.
7. Only after reseal and verification: separately approved **detectors fail closed → E2 append-only re-adjudication → E4 OOS-2026**. Carry the supplied non-USD gap inventory into both. No such actions were started here.

Disposition: **REVIEW — CANDIDATES_BUILT_VERIFICATION_FAIL_RESEAL_BLOCKED**. The task made no production calendar, Common mirror, bundle, dxz23, gate-enforcement, terminal, AutoTrading or T_Live change. Main integration remains Claude+OWNER close-out.
