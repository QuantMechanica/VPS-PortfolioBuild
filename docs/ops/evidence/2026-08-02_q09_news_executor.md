# Q09_NEWS production executor and binding evidence

**Date:** 2026-08-02

**Router task:** `a5c055b2-2fe6-4fd3-9483-91101ee09dc3`

**Authority:** OWNER 2026-08-02, “geh den gesamten Reparaturaufwand an”

**Disposition:** **EXECUTOR AND FACTORY BINDING PASS ON FIXTURES; PRODUCTION
`CONFIG_LOCKED` DEFERRED UNTIL THE TESTED EA PROVES EFFECTIVE USE OF THE SEALED
CALENDAR BUNDLE.** No production Q09 row was enqueued, no terminal was started,
and T_Live/AutoTrading were not touched.

## What was built

`tools/strategy_farm/q09_news_runner.py` now implements the missing middle of
the Q09 contract:

1. `load_authenticated_plan` authenticates the exact run-plan bytes, the
   internal plan hash, input manifest, Q08 evidence, baseline setfile, EX5,
   recursive include-closure manifest, calendar bundle, every generated
   setfile, and every unique cell identity.
2. `bind_plan_to_work_item` atomically binds that sealed plan to one exact,
   unclaimed, pending `Q09_NEWS` work item. It requires the row's immutable Q08
   dependency to be a durable `PASS`, authenticates the Q07 seed-stability
   predecessor cited by Q08, registers the verified calendar bundle in the Q09
   sidecar schema, records the serial cell budget, and self-hashes the dispatch
   binding. It never creates or requeues work.
3. `execute` uses only the ordinary factory slot already claimed by the
   terminal worker. It rechecks the exact active terminal claim before every
   tester window and refuses missing capacity, terminal drift, payload drift,
   plan drift, Q07 evidence drift, or work-item identity drift. It dispatches
   serially; there is no extra terminal or parallel lane.
4. Each cell runs selection, holdout, and full windows through
   `framework/scripts/run_smoke.ps1` with Model 4 real ticks. The executor
   authenticates the effective expert, EX5, setfile, tester window, symbol,
   period, seed, news axes, risk inputs, report bytes, structured logger delta,
   and canonical commission-group identity before publishing a receipt in the
   collector's existing v2 shape.
5. `collect_run_plan_status` makes missing cells `REVIEW_REQUIRED` and any
   present-but-invalid receipt `INVALID_EVIDENCE`; neither path can lock an
   arm. A complete authenticated matrix delegates economic selection to the
   existing contract.
6. `farmctl.py bind-q09-plan` exposes the atomic binding operation. The Q09
   phase builder invokes `execute`, passes the worker's exact terminal claim,
   and points the work item at the canonical Q09 aggregate path. A missing
   terminal, binding, hash, or plan produces no runnable command.
7. `terminal_worker.py` accepts a Q09 aggregate only when an append-only
   `q09_news_tests` row matches its verdict, path, and SHA-256. A bare or
   tampered `aggregate.json` cannot finish a Q09 row.

Backtest setfiles are checked immediately before dispatch and require
`RISK_FIXED > 0`, `RISK_PERCENT = 0`, and, when the field exists,
`qm_news_stale_max_hours <= 336`.

The default targeted matrix contains 40 cells (five `CONTROL_OFF` seeds plus
seven temporal modes × five `POLICY_ON` seeds for the deployment compliance
mode). Each cell has three serial tester windows. The conservative outer
timeout is written into the work-item payload at bind time so the ordinary
worker lease is not mistaken for a stalled process. This reserves one T-slot;
the other factory slots remain available to the DXZ backlog.

## Fail-closed production defer

The Python execution bridge is complete, but current MQL5 source does not yet
provide evidence that the sealed calendar bundle can affect the tested EA:

- the Q09 planner writes `qm_news_calendar_bundle_id`,
  `qm_news_calendar_expected_sha256`, and
  `qm_news_calendar_common_relative_path` into every cell setfile;
- no `.mq5` or `.mqh` source currently declares or consumes those three
  inputs;
- `framework/include/QM/QM_Common.mqh` still calls `QM_NewsInit` with the fixed
  `D:\QM\data\news_calendar` directory, whose loader uses the established
  calendar filenames (and their FILE_COMMON basename fallback);
- the content-addressed Q09 bundle provisioner writes one `events.csv` at its
  sealed relative Common path.

The executor therefore checks the MT5 report's effective Inputs region for all
three sealed bundle fields. A current production EX5 that ignores the new
setfile fields will fail on the first cell and publish only non-locking review
evidence. This is intentional. Fixture `CONFIG_LOCKED` proves the executor and
collector protocol, not that today's compiled EAs consume the bundle.

Before production Q09 execution, a separately reviewed framework/EA change
must make the content-addressed bundle an effective tester input, compile the
EA, and requalify its Q02→Q08 chain on that exact EX5/include closure. The
alternative would be a separately authenticated adapter that proves the fixed
calendar files are the sealed bundle bytes for every run. Neither change was
authorized in this task. The news staleness limit was not weakened; stale seed
recovery remains a calendar refresh in `D:\QM\data\news_calendar` and the
FILE_COMMON copy.

## Exact post-review operator sequence — QM5_11422

**Do not run this sequence today.** It becomes executable only after (a) Claude
accepts this change, (b) the calendar-input defer above is resolved and
reviewed, and (c) the ordered repair chain has produced a fresh, current-EX5
Q08 `PASS`. Run one command at a time and stop on the first refusal or
non-pass. The two angle-bracket values are outputs that do not exist yet; they
must come from the reviewed fresh Q08/compile evidence and must never be
replaced with historical lookalikes.

```powershell
Set-Location C:\QM\repo

$q08 = '<NEW_11422_CURRENT_EX5_Q08_PASS_WORK_ITEM_ID>'
$includeClosure = '<REVIEWED_CURRENT_EX5_RECURSIVE_INCLUDE_CLOSURE_JSON>'
$q08Evidence = "D:\QM\reports\work_items\$q08\QM5_11422\Q08\USDCAD_DWX\aggregate.json"
$eaRoot = 'C:\QM\repo\framework\EAs\QM5_11422_williams-18ma-outside-bar-entry-d1'
$baseline = "$eaRoot\sets\QM5_11422_williams-18ma-outside-bar-entry-d1_USDCAD.DWX_D1_backtest.set"
$ex5 = "$eaRoot\QM5_11422_williams-18ma-outside-bar-entry-d1.ex5"
$calendarManifest = '<OWNER-APPROVED_Q09_NEWS_CALENDAR_BUNDLE_V2_DIR>\manifest.json'

if (-not (Test-Path -LiteralPath $q08Evidence -PathType Leaf)) { throw 'fresh Q08 evidence missing' }
if (-not (Test-Path -LiteralPath $includeClosure -PathType Leaf)) { throw 'reviewed include closure missing' }
if (-not (Test-Path -LiteralPath $calendarManifest -PathType Leaf)) { throw 'approved Q09 calendar manifest missing' }
$currentEx5Sha = (Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash.ToLowerInvariant()
$bundleId = [string](Get-Content -LiteralPath $calendarManifest -Raw | ConvertFrom-Json).bundle_id
if ($bundleId -notmatch '^q09cal-') { throw 'calendar is not a Q09 v2 content-addressed bundle' }

$enqueue = python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_11422 --phase Q09_NEWS `
  --from-work-item-id $q08 `
  --append-only-rerun-of 87af2578-b9ba-4010-9776-07faa4e729d5 `
  --rerun-reason 'BOOK_ADMISSION_REPAIR_2026-08-02_Q09_NEWS_CURRENT_BINARY' `
  --expected-current-ex5-sha256 $currentEx5Sha | ConvertFrom-Json
if (-not $enqueue.enqueued -or $enqueue.created.Count -ne 1) { throw 'Q09 enqueue refused or ambiguous' }
$q09 = [string]$enqueue.created[0].id
$planRoot = "D:\QM\reports\work_items\$q09\q09_plan"

$q08Sha = (Get-FileHash -LiteralPath $q08Evidence -Algorithm SHA256).Hash.ToLowerInvariant()
$lineageText = "QM5_11422|USDCAD.DWX|D1|$q08|$q08Sha"
$lineageKey = [Convert]::ToHexString(
  [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lineageText))
).ToLowerInvariant()

python tools/strategy_farm/q09_news_runner.py plan `
  --work-item-id $q09 `
  --candidate-lineage-key $lineageKey `
  --deployment-target DXZ `
  --q08-work-item-id $q08 `
  --q08-evidence $q08Evidence `
  --baseline-setfile $baseline `
  --ex5 $ex5 `
  --include-closure $includeClosure `
  --calendar-manifest $calendarManifest `
  --calendar-common-relative-path "QM/q09_news/$bundleId/events.csv" `
  --full-from-utc 2019-01-01T00:00:00Z `
  --full-to-utc 2025-12-31T23:59:59Z `
  --selection-from-utc 2019-01-01T00:00:00Z `
  --selection-to-utc 2023-12-31T23:59:59Z `
  --holdout-from-utc 2024-01-01T00:00:00Z `
  --holdout-to-utc 2025-12-31T23:59:59Z `
  --complete-months 60 `
  --holdout-complete-months 24 `
  --tester-model REAL_TICKS `
  --cost-profile DXZ_CANONICAL_REAL_TICKS_V1 `
  --output-root $planRoot
if ($LASTEXITCODE -ne 0) { throw 'Q09 plan refused' }

$plan = "$planRoot\run_plan.json"
$planSha = (Get-FileHash -LiteralPath $plan -Algorithm SHA256).Hash.ToLowerInvariant()
python tools/strategy_farm/farmctl.py bind-q09-plan `
  --work-item-id $q09 `
  --plan $plan `
  --plan-file-sha256 $planSha `
  --cell-timeout-sec 3600
if ($LASTEXITCODE -ne 0) { throw 'Q09 binding refused' }
```

There is deliberately no manual `execute` or terminal command after binding.
The ordinary factory pump/terminal worker claims the pending row and supplies
its reserved T-slot. Inspect the row and the Q09 sidecar after it finishes; do
not enqueue Q10 unless this exact row has pipeline-produced `CONFIG_LOCKED` and
the sibling Q09_PORTFOLIO evidence satisfies the existing paired dependency
gate.

## Focused verification

Compilation check completed silently with exit code 0:

```text
python -m py_compile tools/strategy_farm/q09_news_runner.py \
  tools/strategy_farm/farmctl.py \
  tools/strategy_farm/terminal_worker.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py
```

The combined Q09 contract/calendar/schema/runner/migration, worker claim,
sidecar, and cascade suite produced:

```text
.................................................................... [ 59%]
..............................................                       [100%]
114 passed, 1 deselected, 8 subtests passed in 51.59s
```

The one deselected test is the unrelated pre-existing
`watchdog_reset_handover_has_transactional_claim_interlock`; the corresponding
uncurated run had one failure in its PowerShell string-position assertion and
all Q09 tests passed. Ruff is not installed in this environment
(`No module named ruff`). `git diff --check` reported no whitespace errors.

Coverage includes plan-file hash drift, immutable source drift, wrong work-item
identity, wrong Q08/Q07 lineage, partial collection, receipt tampering,
capacity refusal, stale-news/risk guard refusal, worker sidecar tampering, and
one fixture plan→bind→dispatch→collect→`CONFIG_LOCKED` flow (40 cells, two
eligible locked policy arms).

No pipeline verdict is inferred from any test result. Production admission
remains fail-closed pending the effective-calendar input work and review.
