# Live-book news-policy diagnostic backfill

**Date:** 2026-08-05

**Router task:** `3260d15d-4977-4472-8eac-270b260a7842`

**Follow-through router task:** `cf052f4c-ded1-4386-99f9-5868199c4b0b`

**Campaign:** `q09-live-news-backfill-20260805-v1`

**Disposition:** **ENQUEUED — DIAGNOSTIC NON-ADMISSION — REVIEW_REQUIRED**

Seventeen live-book sleeves are sealed as 680 diagnostic Q09_NEWS cells and
enqueued in the OWNER-specified order. The campaign cannot write a canonical
`q09_news_tests` row, cannot cascade to Q09_PORTFOLIO or Q10, and cannot produce
an admission verdict. Every completed sleeve is forced to `REVIEW_REQUIRED`
for Claude review, regardless of the underlying Q09_NEWS adjudication.

No T_Live preset, profile, binary, chart, AutoTrading setting, or live terminal
was changed. The optional standard three-pair path was not used; all 17 sleeves
use the same explicitly non-admitting diagnostic contract.

## Runtime policy basis — corrected after review

The earlier revision said that loaded T_Live chart inputs were the authority
for `qm_news_temporal=3` and `qm_news_compliance=1`. That mechanism claim is
withdrawn. It came from `q09_live_news_backfill.py:41,157-201`, where
`PROFILE_ROOT` points to
`C:\QM\mt5\T_Live\MT5_Base\MQL5\Profiles\Charts\DarwinexZero_V2_LiveOps`
and `chart_snapshot()` treats matching files there as loaded charts. That
nested `MQL5\Profiles` directory is not the chart directory resolved from the
running terminal process and is not runtime authority.

The read-only, process-anchored check established the following at
`2026-08-05T15:43Z`:

- PID `17008` was the T_Live process, with image
  `C:\QM\mt5\T_Live\MT5_Base\terminal64.exe` and command line
  `"...\terminal64.exe" /portable`. Its data root is therefore the executable
  directory, `C:\QM\mt5\T_Live\MT5_Base`.
- `Config\common.ini` records
  `ProfileLast=DarwinexZero_V2_LiveOps`, but the process-root directory
  `Profiles\Charts\DarwinexZero_V2_LiveOps` does not exist.
- The process-root `Profiles\Charts` contains 16 `.chr` files under four other
  profiles. A byte-level UTF-8/UTF-16/ASCII scan found zero occurrences of
  `qm_news_temporal`, `qm_news_compliance`, `qm_news_min_impact`,
  `qm_news_stale_max_hours`, `qm_filter_news_enabled`, or
  `qm_filter_news_mode` in all 16. The running process's in-memory chart input
  state is therefore **NOT ESTABLISHED** from durable chart bytes.

The verified deployment mechanism is preset omission plus compiled-default
inheritance. All 17 source presets contain the historical no-op lines
`qm_filter_news_enabled=1` and `qm_filter_news_mode=3`, and 0/17 pins any of
the four current `qm_news_*` inputs. All 14 unique target EA sources declare
the same defaults: `PRE30_POST30`, `DXZ`, `high`, and a fail-closed stale
ceiling of `336` hours (including QM5_11132 lines 55-58 and QM5_10403 lines
55-58). Under that preset-loading contract the policy represented by the live
deployment is `PRE30_POST30/DXZ/HIGH/336`; the process-anchored disk check does
not independently recover an in-memory override.

This creates a governance defect even though the mapped policy is unchanged:
the policy is compile-default-inherited rather than preset-pinned. The Sunday
consumption ceremony must explicitly set `qm_news_temporal=3` and
`qm_news_compliance=1` in every live preset before any OWNER-authorized live
preset change. This ticket made no T_Live write. The diagnostic's nearest
sealed temporal policy remains the exact `PRE30_POST30/DXZ` cell (mode ids
`3/1`), alongside `OFF`, `PRE30`, `PRE60`, `PRE60_POST60`, `SKIP_DAY`, and
`CLOSE_ALL_PRE`, each paired with `CONTROL_OFF/OFF/NONE`.

Event scoping in the post-`89963ff75` framework is mechanical:

- six-character FX/metal/energy symbols match event currency against their
  first and second three-character components; for XAUUSD, XTIUSD and XNGUSD,
  USD events are therefore applicable;
- NDX and SP500 map to USD, and GDAXI maps to EUR;
- `ALL`/blank currency events affect every symbol, while an unknown short
  symbol remains fail-closed.

## July 5 scoping and `symbol_slot` generation assessment

Commit `89963ff753163c4fb53d2373024c1f86cfa39059` (2026-07-05
13:43 CEST / 11:43 UTC) fixed the prior short-index behavior that treated every
world event as applicable. The exact deployed binary hash, rather than a
current rebuild, is used for each sleeve.

| Rank | Sleeve | Deployed EX5 SHA-256 | Index scoping generation | `symbol_slot` |
|---:|---|---|---|---|
| 1 | QM5_12567/XNGUSD | `5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` | N/A, six characters | Explicit assignment |
| 2 | QM5_10919/XTIUSD | `57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691` | N/A, six characters | Explicit assignment |
| 3 | QM5_12567/XAUUSD | `5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` | N/A, six characters | Explicit assignment |
| 4 | QM5_1556/XAUUSD | `9371a8a03008e2fd8a3fc9dbec75586f7ade71ea857e9ff8f9c3fd0fd95cb3cb` | N/A, six characters | Explicit assignment |
| 5 | QM5_11165/AUDCAD | `8f6d33a3dfb05f7f9167c96d7a7069cb11d8c05f7137be008530d9e12df941e4` | N/A, FX | Explicit assignment |
| 6 | QM5_11708/EURUSD | `de06fb032c9b47ef0b50c6f36b257a1462b2f5259a482c294dfcfa0f9763a38d` | N/A, FX | Explicit assignment |
| 7 | QM5_11132/SP500 | `25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152` | Post-`89963ff75` | Explicit assignment |
| 8 | QM5_11165/EURUSD | `8f6d33a3dfb05f7f9167c96d7a7069cb11d8c05f7137be008530d9e12df941e4` | N/A, FX | Explicit assignment |
| 9 | QM5_11421/AUDUSD | `0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7` | N/A, FX | Explicit assignment |
| 10 | QM5_11421/EURUSD | `0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7` | N/A, FX | Explicit assignment |
| 11 | QM5_10513/XAUUSD | `04b62af28c6466e01741aacaa915d9a68714cd7c23288ae277615ae068d63898` | N/A, six characters | Explicit assignment |
| 12 | QM5_12989/XAUUSD | `7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2` | N/A, six characters | Explicit assignment |
| 13 | QM5_10403/XAUUSD | `b6c194d928b678cb31646dc81216c6d9f3215727354aeecdbb61bbcca99ef2b6` | N/A, six characters | Explicit assignment |
| 14 | QM5_10939/GBPUSD | `308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac` | N/A, FX | Explicit assignment |
| 15 | QM5_10911/GDAXI | `a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158` | Post-`89963ff75` | Explicit assignment |
| 16 | QM5_10706/GBPUSD | `01e34b2059de6ed505d445ce9fcbac7da0eb10d51e5cbcbbd18d38a968916078` | N/A, FX | Explicit assignment |
| 17 | QM5_10440/NDX | `b71d302997ecdb661f1627e12b9e5e766e9679c780461b82fa018db7f2078a6a` | **Pre-`89963ff75`; over-scoping defect present** | Explicit assignment |

QM5_10440/NDX is intentionally measured as actually deployed: its June 28 EX5
contains the pre-fix index over-scoping behavior. Its current source explicitly
assigns `symbol_slot`, so it is not exposed to the separate uninitialized
`symbol_slot` defect. Every other target source also assigns the field
explicitly. QM5_11132/SP500 and QM5_10911/GDAXI use post-fix deployed binaries.

## Sealed execution contract

- Campaign plan:
  `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\campaign_plan.json`
- Plan SHA-256:
  `72b3c519c51b4a147ad0137eedaca528e73e7e7f3dc72f3de909f55457361c45`
- Enqueue receipt:
  `D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\enqueue_receipt.json`
- Enqueue receipt SHA-256:
  `669528fd973f063a17a2f62c894e0d5945e23c3d6a39951ce28725be1a08e52a`
- Calendar bundle:
  `q09cal-20150101-20260809-0bb19b5bb9790b76`; manifest SHA-256
  `b204d1ab9fe40fe32afc254ae4284ed6c1df112829df07483912e5ed54527461`.
- Tester/cost identity: `REAL_TICKS` / `DXZ_CANONICAL_REAL_TICKS_V1`.
- Windows: selection 2019-01-01 through 2023-12-31; holdout 2024-01-01
  through 2025-12-31; full 2019-01-01 through 2025-12-31.
- Seeds: `42, 17, 99, 7, 2026`.
- Matrix: five control cells plus seven DXZ temporal modes times five seeds =
  40 cells per sleeve, 680 cells total. Each cell executes selection, holdout,
  and full windows serially.
- Every generated set file has `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `qm_news_stale_max_hours=336`. The control neutralizes both the historical
  `qm_filter_news_*` fields and the current temporal/compliance axes.
- Only T1-T5 may claim these rows, with at most five campaign rows active.
  T6-T10 are explicitly excluded.
- The exact source EX5 is copied to the claiming worker under its deployed
  filename and `run_smoke` uses `-SkipExpertDeploy`; the worker verifies the
  staged destination hash before execution.
- Diagnostic results are written only beneath their isolated work-item report
  roots. A sibling `summary.json` seals the underlying aggregate and forces
  `REVIEW_REQUIRED`. A diagnostic row is rejected if any canonical
  `q09_news_tests` row exists for it, and diagnostic rows are excluded from
  cascade promotion.

## Live-book reconciliation and protected work

The 2026-08-05 T_Live pulse reconciles 24 expected and 24 loaded sleeves with
no profile mismatch. The separate 23/24 warning is kill-switch baseline-file
coverage: `10440|NDX` is missing from that baseline set. It is **not** evidence
that QM5_10440/NDX is absent from the loaded book.

Protected round-7 work item `9fabcddb-8c2e-4b01-9295-4ef4dbb6892d`
(QM5_11422/USDCAD, Q09_NEWS) remained active on T6 under PID 22120 during
enqueue and verification. The campaign cannot claim T6-T10 and carries an
explicit exclusion for that row plus Q09_PORTFOLIO and Q10. No terminal or live
state was interrupted.

## Queue and ETA snapshot

Initial snapshot at `2026-08-05T15:00:32Z`: 17 pending, 0 active, 0 completed,
and 0 canonical Q09 rows. Rank is persisted in
`diagnostic_queue_rank`; ordinary symbol locks and terminal availability may
make actual claim order temporarily non-monotonic, but no row can displace the
protected chain.

The first short T3 claim of rank 7 refused before a test began because MT5 was
given the synthetic label `QM5_11132` instead of the staged deployed filename
`QM5_11132_tm-cum-rsi2`. The durable failure reports `tester EX5 not found`;
there was no report, logger sample, metric, or canonical result. Dispatch now
derives `--expert` from the hash-bound deployed EX5 path, and the diagnostic
worker accepts only the matching non-admission review sidecar. The row remains
retryable; this failure is not represented as strategy evidence.

At `2026-08-05T15:15:15Z`, four rows were active on T1-T4 and 13 were
pending. The compatibility stage had materialized the numeric-label aliases
from the hash-bound deployed binaries; every observed active alias matched its
required SHA-256 and the testers started normally. The resident T1-T4 worker
daemons themselves were born at 14:35 local time, before commit `dff3a30a0`
loaded the diagnostic review-sidecar completion handler at 17:20:14 CEST.

The follow-through recycled only worker daemons, one terminal at a time, under
the terminal-reservation interlock. Each stop was permitted only after both the
SQLite active-claim check and path-anchored `terminal64.exe` check returned
empty. The first T1 attempt refused because it had already claimed a row; T1
was not touched until that test ended. T4 was handled the same way. T6-T10,
all terminal processes, T_Live, and AutoTrading were untouched.

| Worker | Old state/PID | New PID | New process born (CEST) |
|---|---|---:|---|
| T1 | pre-patch `13888` | `9000` | 2026-08-05 17:56:41 |
| T2 | pre-patch `21772` | `14916` | 2026-08-05 17:49:33 |
| T3 | pre-patch `20624` | `21416` | 2026-08-05 17:50:03 |
| T4 | pre-patch `3188` | `15148` | 2026-08-05 17:57:19 |
| T5 | stale PID-file entry `20384`; no live process | `17216` | 2026-08-05 17:50:32 |

All five new processes resolve to Python 3.11 `pythonw.exe`, the exact
`C:\QM\repo\tools\strategy_farm\terminal_worker.py --terminal Tn --root
D:\QM\strategy_farm` handler, and handler SHA-256
`7466ab0660e37873c0876b723a70c53e15fb01778ed42326b5a4965b36ef3df6`.
The reconciled PID registry contains exactly those five identities.

### QM5_10919/XTIUSD append-only rerun

Predecessor `4b593310-684d-5242-8c52-309469aef5ab` remains untouched as
`failed/INFRA_FAIL`. Its durable payload and T3 worker log identify T3 as the
launch-faulting terminal. Commit `589e170f9` added a tested append-only rerun
operation; it created successor `3196f708-c62d-5a2d-ad3c-0eaef931a442`, with
`parent_task_id` and `rerun_of` bound to the predecessor and T3 added to the
T6-T10 exclusion set.

The successor preserved the sealed baseline, deployed EX5, calendar bundle,
date windows, five seeds, REAL_TICKS model, 40-cell matrix, Q07 reference, risk
values (`RISK_FIXED=1000`, `RISK_PERCENT=0`), and stale ceiling (`336`). Its
enqueue receipt is
`D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\reruns\3196f708-c62d-5a2d-ad3c-0eaef931a442\enqueue_receipt.json`,
SHA-256 `418facd2947c4e6d910306122b21fda35127269581251fb5028fde5569c063ee`.

Fresh T2 claimed the successor. It reached `terminal_start`, proving the prior
pre-start launch fault did not recur, and verified the staged EX5 before and
after the run. The first selection cell then refused because no fresh
structured logger sample/report was authenticated. Final diagnostic state is
`done/REVIEW_REQUIRED`: 0 authenticated cells, 1 failed cell, and 39 missing
cells. Aggregate SHA-256 is
`9fea4c381789c9e11068211eddd7d6b1e9c1a5b0dcff3f01c8c61c5f8f121dee`;
summary SHA-256 is
`ece3ea1b850d84eb15cda5678874e794370cb959c35bff13cfbd33213c066add`.
There are still zero canonical `q09_news_tests` rows for either predecessor or
successor. This is an infrastructure refusal and Claude review input, not a
pipeline verdict; no further rerun was invented.

ETA values below are operating targets, not fabricated completion promises.
They assume normal REAL_TICKS availability and the five-slot cap: D1 by Friday
2026-08-07 20:00 CEST, H4 by Saturday 2026-08-08 14:00 CEST, and the heavier
H1 sleeves by Saturday 2026-08-08 evening (20:00 CEST). A fail-closed data,
binary, capacity, or evidence refusal supersedes the target.

| Rank | Sleeve | Weight | TF | Current live mode | Work item | Initial state | Target ETA |
|---:|---|---:|---|---|---|---|---|
| 1 | QM5_12567/XNGUSD | 0.98 | D1 | PRE30_POST30/DXZ | `b415f35b-da44-5d42-b724-cad9329bd392` | PENDING | Aug 7 20:00 CEST |
| 2 | QM5_10919/XTIUSD | 0.92 | H4 | PRE30_POST30/DXZ | `4b593310-684d-5242-8c52-309469aef5ab` | PENDING | Aug 8 14:00 CEST |
| 3 | QM5_12567/XAUUSD | 0.75 | D1 | PRE30_POST30/DXZ | `aca92ad6-8929-5c04-850f-e8ee65fc28bc` | PENDING | Aug 7 20:00 CEST |
| 4 | QM5_1556/XAUUSD | 0.60 | D1 | PRE30_POST30/DXZ | `8419449d-5474-5a2c-a58a-d2b6caf57b27` | PENDING | Aug 7 20:00 CEST |
| 5 | QM5_11165/AUDCAD | — | H1 | PRE30_POST30/DXZ | `7fc27138-1046-56f2-8321-7fc61496f149` | PENDING | Aug 8 evening |
| 6 | QM5_11708/EURUSD | — | D1 | PRE30_POST30/DXZ | `7b126a2c-68f0-5a20-a4ec-1a670396cbb6` | PENDING | Aug 7 20:00 CEST |
| 7 | QM5_11132/SP500 | — | D1 | PRE30_POST30/DXZ | `466ffc90-9101-5ad0-89b7-a2ff99c1d838` | PENDING, retry 1 | Aug 7 20:00 CEST |
| 8 | QM5_11165/EURUSD | — | H1 | PRE30_POST30/DXZ | `e7ac1a8f-d0c9-5797-ada6-69d1094de29a` | PENDING | Aug 8 evening |
| 9 | QM5_11421/AUDUSD | — | D1 | PRE30_POST30/DXZ | `b4d2c2b7-e91e-5b46-89df-5ca9150eafe4` | PENDING | Aug 7 20:00 CEST |
| 10 | QM5_11421/EURUSD | — | D1 | PRE30_POST30/DXZ | `a18afc0c-2670-5d6f-a32f-d7cbed6cd00c` | PENDING | Aug 7 20:00 CEST |
| 11 | QM5_10513/XAUUSD | — | D1 | PRE30_POST30/DXZ | `b427b710-cd22-5e17-a837-15521c980f43` | PENDING | Aug 7 20:00 CEST |
| 12 | QM5_12989/XAUUSD | — | H4 | PRE30_POST30/DXZ | `245ab0ea-13ba-5fb8-b7ff-1cf0e5162cc4` | PENDING | Aug 8 14:00 CEST |
| 13 | QM5_10403/XAUUSD | — | D1 | PRE30_POST30/DXZ | `751e8496-cd12-5580-b223-753c656a69d1` | PENDING | Aug 7 20:00 CEST |
| 14 | QM5_10939/GBPUSD | — | H4 | PRE30_POST30/DXZ | `635348ea-f1f8-5d83-9dac-d3a93325d111` | PENDING | Aug 8 14:00 CEST |
| 15 | QM5_10911/GDAXI | — | H1 | PRE30_POST30/DXZ | `6cf72d2e-b938-5aca-afa0-7525b3656eaa` | PENDING | Aug 8 evening |
| 16 | QM5_10706/GBPUSD | — | H1 | PRE30_POST30/DXZ | `73b78d9f-ea9e-5ddf-9a2f-8afd5c60365e` | PENDING | Aug 8 evening |
| 17 | QM5_10440/NDX | — | H1 | PRE30_POST30/DXZ | `036ab55b-3323-5458-a0d5-3a1ec116939a` | PENDING | Aug 8 evening |

## Rolling control-versus-temporal results

No economic metric is inferred before authenticated REAL_TICKS evidence
exists. Each future cell below is reported as
`sum(net_r) / mean(PF) / worst(DD%) / sum(entries)` across the five full-window
seeds; seed-level selection, holdout, and full metrics remain in each sleeve's
`q09_news_evidence.json`. `OFF/DXZ` is a policy cell and is distinct from the
`CONTROL_OFF/OFF/NONE` control.

| Sleeve | Control | OFF/DXZ | PRE30 | PRE60 | PRE30_POST30 | PRE60_POST60 | SKIP_DAY | CLOSE_ALL_PRE |
|---|---|---|---|---|---|---|---|---|
| QM5_12567/XNGUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_10919/XTIUSD | REFUSED (0 auth) | REFUSED (0 auth) | REFUSED (0 auth) | REFUSED (0 auth) | REFUSED (0 auth) | REFUSED (0 auth) | REFUSED (0 auth) | REFUSED (0 auth) |
| QM5_12567/XAUUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_1556/XAUUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_11165/AUDCAD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_11708/EURUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_11132/SP500 | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_11165/EURUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_11421/AUDUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_11421/EURUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_10513/XAUUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_12989/XAUUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_10403/XAUUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_10939/GBPUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_10911/GDAXI | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_10706/GBPUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| QM5_10440/NDX | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

Refresh the governed queue snapshot without changing work:

```powershell
Set-Location C:\QM\repo
python tools/strategy_farm/q09_live_news_backfill.py status
```

## Verification

- Follow-through append-only rerun suite: **8 passed**; module compile check:
  PASS. The integration case proves predecessor immutability, successor
  lineage, post-bind T3 steering, 40-cell binding, and zero canonical Q09 rows.
- All rerun receipt-bound baseline, EX5, calendar, source-anchor, rerun-anchor,
  and run-plan SHA-256 values were recomputed from disk and matched.
- T1-T5 process census after the orderly recycle: exactly five path-anchored
  worker daemons, all born after the completion patch; no duplicate worker.

- Focused Q09 runner, farm integration, diagnostic binding, deployed-filename,
  retry-steering, compatibility staging, and non-admission sidecar suites:
  **36 passed**.
- Adjacent terminal-worker claim, staged-EX5, identity, adoption, and Q-phase
  stall suites: **74 passed, 4 subtests passed**. One unrelated pre-existing
  watchdog-script text-order assertion failed (`clear_pos < spawn_pos`); it does
  not exercise the changed diagnostic paths.
- `py_compile`: PASS for `farmctl.py`, `q09_news_runner.py`,
  `q09_live_news_backfill.py`, `terminal_worker.py`, and the focused test.
- Immutable campaign verification: 17 sleeves, 680 cells, 0 file-hash errors,
  0 risk/stale/control guardrail errors.
- Target source census: 14 unique sources; 0 declare `qm_filter_news_*`; 14
  declare both current news axes.
- Canonical `q09_news_tests` rows for the campaign: 0.
- T_Live loaded/profile reconciliation: 24/24; profile mismatch: 0.
- Protected round-7 row remained active on T6/PID 22120 during verification.

Tests and an enqueue receipt are implementation evidence, not pipeline
verdicts. Only authenticated per-cell and aggregate artifacts may populate the
rolling metric table, and this diagnostic remains non-admitting even after all
680 cells complete.

## Full current-build refresh addendum — router task `b84011f2`

**Execution window:** 2026-08-05 16:39-17:21 UTC

**Disposition:** **REVIEW_REQUIRED — PARTIAL BY GUARDED REFUSAL**

This addendum records the OWNER-directed current-build refresh, append-only
generation-2 news reruns, and ordinary missing-gate requalification. It does
not change a live deployment and does not confer a pipeline verdict. Of the 14
unique target sources, 12 passed the strict build gate and compiler; two were
restored byte-for-byte after the strict performance gate refused them. Those
12 builds cover 15 of the 17 target sleeves. Twenty ordinary live-book
requalification rows were also enqueued; three sleeves were refused rather
than seeded unsafely, and the one exact current-generation Q08 PASS was kept.

No T_Live file, live preset, profile, chart, terminal, or AutoTrading setting
was changed. No `terminal64.exe` was started manually. Existing T1-T10 tests
were not stopped. Phase names below are Q-only, and all reported outcomes come
from the governing build or queue artifacts rather than inferred pipeline
results.

### Phase A — source refresh and serial rebuild

The source baseline is canonical commit
`c8e412c5a643b072616f980a0e0dab3c7b5ce3a0`, immediately before the first
task-scoped pump artifact commit. MQ5 hashes below are SHA-256 after LF
normalization so checkout EOL conversion cannot masquerade as a mechanics
change; EX5 hashes are over exact bytes. The accepted MQ5 delta is the explicit
first-statement `QM_FrameworkTrackOpenPositionMae()` call in `OnTick`, its
explanatory comment, and SPEC v1.1. QM5_10939, QM5_11132, and QM5_12989 also
received a declaration-only supported-surface comment. No strategy condition,
indicator, entry, exit, stop, target, sizing rule, or trading schedule changed.

Strict build reports share root `D:\QM\reports\framework\21`; compiler logs
share root `C:\QM\repo\framework\build\compile`. Every accepted compiler log
ends `Result: 0 errors, 0 warnings`.

| EA | MQ5 SHA-256, old -> new (LF-normalized) | EX5 SHA-256, old -> new | Strict build / compile |
|---|---|---|---|
| QM5_12567 | `e40bea7e231ca7366feaa7e4ce0e9f6cc823a39cd6640535a157fe8747bb4025` -> `8a5dc80942f867936ab18f6b98243437761aba55330024b18e5a050757ad60fc` | `5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` -> `8d901924fe7dd2cd00c61dac6db78871fdfe34f73e0f003393196992d5143e04` | PASS `build_check_20260805_163911.json`; `20260805_163936` 0/0 |
| QM5_10919 | `91cb71322cea53a2977855be6ede2f2eddbaf1280244a1eb070163e16b4d455e` -> `b8440e637c3c6114e45ccc3f0a3c4922cdff4e2d0dc2102aacfdd32d20dcb158` | `57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691` -> `bff488fabe6416a0c70719538aa4ee21336eab389f32e1a86eb75cf6fffa6e65` | PASS `build_check_20260805_164040.json`; `20260805_164106` 0/0 |
| QM5_1556 | `eb21c1d5e71288e24985802081200a15ed1fbc6a70534efbae95a0ec11d8499a` -> `3b44aa66f7ff4665d15b3e580dc42ea73add6548448b83258d2b510f151769ac` | `9d95921e82c6d810731c8b5ba7fc58109f3f858194b62d87188a2d51171a3c84` -> `0962ca65776fd05e76f7ab5f27e838a72cb79a7359a029e2f47ef61a9ae7c88e` | PASS `build_check_20260805_164152.json`; `20260805_164219` 0/0 |
| QM5_11165 | `13b723caa96a04b25b09b159cc49c5035bbe22fe774512217a10d93026b7a0e1` -> `7daca3b50d87b7fb404d7e21ddf5bd5556691cec6705830daa8258fd7bc92a14` | `5987d174fe00c9944a1128557b51e4c1702a51834908b8cd878ab2c5b98839ff` -> `b109a902f98f305b7436b9ec1c02105a57b497c67db297ffb6232372f5088281` | PASS `build_check_20260805_164243.json`; `20260805_164311` 0/0 |
| QM5_11708 | `111826909d2e7127ef5fcfb611f001a56c48d402a999db4667f236cf518a90c4` -> `9b4c843be029d1e151322d1beb2465fb45d3bd6f5f1e3ab30a3eb78de4469043` | `7930a220014f69714882ad60a5791b018323fc27f76ef17127eaf7df2a22cc4f` -> `baff181fe3c9b5abf404231603f8117f4d2cf9d792c69de7014732a3b6e96d25` | PASS `build_check_20260805_164349.json`; `20260805_164417` 0/0 |
| QM5_11132 | `900e6ddc411945542341cfc59f899cc814ae984932f89f73f3c7659a0545134e` -> `590e520cf255bfd14abf01348ce23f8bf6dc08560161858912bd260afaaa32f7` | `25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152` -> `e3dea054cce04aba5aec82ceb9a8a0a530acc43c6b4d3783ee5f70d89064a66e` | PASS `build_check_20260805_164540.json`; `20260805_164609` 0/0 |
| QM5_11421 | `184b0df165ab7273441b82928b293a947b7899fff9444218b6c139590b6d5700` -> `b5dfd159b46281cdb30dae3ae12a12fd67cdf810941b82a4a5f7e11a9dce6a15` | `0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7` -> `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b` | PASS `build_check_20260805_164653.json`; `20260805_164723` 0/0 |
| QM5_10513 | `d6afb9b298dd0a5d702105d02055c36ed54271c3e5ef9bdd3b0d4fd0ce4182f3` -> same | `04b62af28c6466e01741aacaa915d9a68714cd7c23288ae277615ae068d63898` -> same | **REFUSED**, `build_check_20260805_164754.json`: three raw-series calls in per-tick helpers |
| QM5_12989 | `fc9ef50ce6ae32c6482ba24570b7cfdbb231573aa9f0897851a8e975c6bd73a6` -> `4e75310f84fb762576a406c46944ac3df899a72906f7671695c2e5900618df0e` | `7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2` -> `77d3c5fda5ef2dfd0c138e6520f76d450a04fe812fcefabac07e2673fcd2e425` | PASS `build_check_20260805_164955.json`; `20260805_165026` 0/0 |
| QM5_10403 | `69d96c886374e6bba4fdd6293e2100b5f312fcc57e574f448164a321b44c676a` -> same | `34432f7377469db04e9ac851f70c3a8bd64e9dab701c49d3564b8aecbaec57d2` -> same | **REFUSED**, `build_check_20260805_165052.json`: two raw-series channel calls per tick |
| QM5_10939 | `08f02c5f2d15a476295c19c15f341be7634f9c3ca2f69186b0dd0c552c0b4f4f` -> `999e8805d38a8de1ba31702a262c538318ec041d7effea745567ec54567e1ae4` | `308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac` -> `812fc52a90f0dba0282aa2fecb3a0b3640c18386ac3e2ab7e3b80765a3970278` | PASS `build_check_20260805_165628.json`; final `20260805_171020` 0/0 |
| QM5_10911 | `2dfa0988d40166d564e386d3ea44cb224f516e873a9bf8cb3a8d2d7eb813a5e4` -> `122d1a4e32480fabf3f0b0363f49d7a8589681c64cd5850da313d1503135f920` | `a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158` -> `1644fcbbab3a3c83e3d43923eed204daf4c3b477472c88eb68669985de4652ae` | PASS `build_check_20260805_165858.json`; `20260805_165942` 0/0 |
| QM5_10706 | `fbb632c78461abc858218207768a53b50fa56a4cb63d1fa237d60de99318c5f6` -> `ad2ec966f9c2c6decc6010518e3fdedf76606a345abc07a0dd85c0b3dd97689f` | `fac91bc4422e5cf7a991d065d8dd682657372bfc001036c72f5c6ab4fe4a74fc` -> `7b287687119ea75a70782ea29569696ab0ab889835b3caa73d5e539d0ff72d72` | PASS `build_check_20260805_170043.json`; `20260805_170122` 0/0 |
| QM5_10440 | `0f22973a0e89166d76c39a5ef3bdaede5f6063ca37166ab9e18c69179a4d513b` -> `0895a8e80a4477baa86e86d95f61312ed42ad0b248f99688f812b022cdb9f6c7` | `d9e7d5cdc1998aadf649287af6a5c13a854e42cddbda28c5732d03b34b8b70db` -> `81d796709dc83b2a4b5d2e8c4030a751876a8df34dc45cafd2d720dfae10278b` | PASS `build_check_20260805_170206.json`; `20260805_170250` 0/0 |

The rejected QM5_10513 and QM5_10403 refreshes were not annotated
`perf-allowed`: doing so would require reviewer authorization and would hide a
known per-tick cost. Their transient source, SPEC, EX5, and generated-set
changes were restored to the pre-cycle canonical bytes. No generation-2 news
row or ordinary Phase-C row was created for either EA.

The strict build lane also exposed provenance-only defects in three auxiliary
QM5_12567 presets, one QM5_11132 preset, and two QM5_10911 variant presets.
Only their required metadata headers were completed; parameter values were
not changed. A final scan covered 341 accepted-build `*backtest*.set` files:
all have `RISK_FIXED > 0` and `RISK_PERCENT = 0`. A separate scan of 496 MQ5
and set files found zero `qm_news_stale_max_hours` values above 336.

### Phase B — append-only generation-2 news diagnostics

`q09_live_news_backfill.py refresh` now creates immutable generation-2 rows
only after validating the current source, exact fresh EX5, live-preset
strategy parameters, fixed-risk settings, stale ceiling, campaign identity,
and v1 parent. `q09_news_runner.py` selects the receipt-bound fresh build for
generation 2. The operation preserves campaign
`q09-live-news-backfill-20260805-v1`, bundle
`q09cal-20150101-20260809-0bb19b5bb9790b76`, five seeds, 40 cells per sleeve,
the seven-by-one DXZ temporal scope, and diagnostic non-admission.

Batch receipts are under
`D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v2\b84011f2-7a2e-463e-a296-df4b20546013`.
Fifteen rows were appended for the 12 accepted builds; v1 rows are immutable.
The snapshot at `2026-08-05T17:20:57Z` was 2 done/REVIEW_REQUIRED, 4 active,
and 9 pending, with zero canonical `q09_news_tests` rows. All four active rows
were on T1-T5, below the cap of five; no row could claim T6-T10.

| Source rank | Fresh-build sleeve | Generation-2 work item | Fresh EX5 SHA-256 | Snapshot | Operating target |
|---:|---|---|---|---|---|
| 1 | QM5_12567/XNGUSD | `3f409823-e2c0-50a8-850f-864e33faab94` | `8d901924fe7dd2cd00c61dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` | active T5 | Fri Aug 7, 20:00 CEST |
| 2 | QM5_10919/XTIUSD | `4fd8d9b2-c4e2-5627-a799-90caee71af07` | `bff488fabe6416a0c70719538aa4ee21336eab389f32e1a86eb75cf6fffa6e65` | done, REVIEW_REQUIRED | completed |
| 3 | QM5_12567/XAUUSD | `4f80a8cf-2cf9-53dd-b59c-414674f24f16` | `8d901924fe7dd2cd00c61dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` | pending | Fri Aug 7, 20:00 CEST |
| 4 | QM5_1556/XAUUSD | `a122a2e9-8c21-5dc0-97d3-96567bf3825e` | `0962ca65776fd05e76f7ab5f27e838a72cb79a7359a029e2f47ef61a9ae7c88e` | pending | Fri Aug 7, 20:00 CEST |
| 5 | QM5_11165/AUDCAD | `cc754e65-54be-50d4-9379-f32d4d9e4497` | `b109a902f98f305b7436b9ec1c02105a57b497c67db297ffb6232372f5088281` | active T4 | Sat Aug 8 evening |
| 6 | QM5_11708/EURUSD | `7a496c8b-4a4a-57c4-b049-04fb9fbbc150` | `baff181fe3c9b5abf404231603f8117f4d2cf9d792c69de7014732a3b6e96d25` | pending | Fri Aug 7, 20:00 CEST |
| 7 | QM5_11132/SP500 | `13fdb5a5-5b91-54f4-ba76-e4e70fbe73c6` | `e3dea054cce04aba5aec82ceb9a8a0a530acc43c6b4d3783ee5f70d89064a66e` | done, REVIEW_REQUIRED | completed |
| 8 | QM5_11165/EURUSD | `1a16c66c-8ae8-5a30-a2ef-9db348e82694` | `b109a902f98f305b7436b9ec1c02105a57b497c67db297ffb6232372f5088281` | pending | Sat Aug 8 evening |
| 9 | QM5_11421/AUDUSD | `8b3332c9-5023-5656-bff6-e8d937cbdc3d` | `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b` | active T1 | Fri Aug 7, 20:00 CEST |
| 10 | QM5_11421/EURUSD | `13860911-0db4-56fc-b82f-00746bf2cfd7` | `9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b` | pending | Fri Aug 7, 20:00 CEST |
| 12 | QM5_12989/XAUUSD | `5c382e2d-55ff-5a49-bd20-9a2b5f35191d` | `77d3c5fda5ef2dfd0c138e6520f76d450a04fe812fcefabac07e2673fcd2e425` | pending | Sat Aug 8, 14:00 CEST |
| 14 | QM5_10939/GBPUSD | `debf9533-f319-5b05-8c89-9747bba7e6bc` | `486b1690c74ce2ef07b9983b4e19eb4c3caf165b9369fcef7e31b9f00e07720b` | active T3 | Sat Aug 8, 14:00 CEST |
| 15 | QM5_10911/GDAXI | `f6d2536f-5992-57e8-be64-b390ecd4d161` | `1644fcbbab3a3c83e3d43923eed204daf4c3b477472c88eb68669985de4652ae` | pending | Sat Aug 8 evening |
| 16 | QM5_10706/GBPUSD | `831d40fb-9602-5f05-9e44-0f535560b39b` | `7b287687119ea75a70782ea29569696ab0ab889835b3caa73d5e539d0ff72d72` | pending | Sat Aug 8 evening |
| 17 | QM5_10440/NDX | `8f2a0a29-f8fd-57ad-a180-2b732a418eb9` | `81d796709dc83b2a4b5d2e8c4030a751876a8df34dc45cafd2d720dfae10278b` | pending | Sat Aug 8 evening |

The two completed rows authenticated their staged binaries before and after
execution. QM5_10919 aggregate SHA-256 is
`b75da5ade64c9f20b0457eabbe789e8b9fc5397ad445c45ff92508190abf8379`;
QM5_11132 aggregate SHA-256 is
`9a0f7b4fd40db5211a77af21d38c23aed14ba6090de813ef2e139a610b873357`.
Both remain `REVIEW_REQUIRED`; no admission or economic claim is inferred.

QM5_10939 needs an explicit byte-identity note. Its generation-2 receipt and
active T3 staging bind the first 0/0 current-source build,
`486b1690c74ce2ef07b9983b4e19eb4c3caf165b9369fcef7e31b9f00e07720b`.
After a concurrent pump restored the canonical file, the same refreshed MQ5
was restored and recompiled 0/0; MetaEditor emitted canonical EX5
`812fc52a90f0dba0282aa2fecb3a0b3640c18386ac3e2ab7e3b80765a3970278`.
The diagnostic continues with its immutable, already-authenticated first
build; Phase C binds the later canonical bytes. Neither binding is rewritten.

The targets above are scheduling estimates, not completion promises. A
fail-closed evidence, calendar, capacity, or binary refusal supersedes them.

### Phase C — current-generation Q02-to-Q08 requalification

The 24-sleeve live manifest was reconciled by exact EA, logical symbol, and
current canonical EX5. Receipt:
`D:\QM\strategy_farm\artifacts\live_book_full_refresh_20260805\b84011f2-7a2e-463e-a296-df4b20546013\phase_c_enqueue_receipt.json`,
SHA-256
`c1360693b46957f8fddd5ee4f16faacf2d86f22134dbf2c335f802b4f32bceb8`.
The source manifest is
`D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json`,
SHA-256
`8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`.

Only QM5_13301/GDAXI had an exact current-build Q08 PASS and was preserved.
Nineteen append-only Q02 rows were created, and QM5_13128 resumed its current
chain at the first missing phase, Q07. At `2026-08-05T17:21Z`, all 19 Q02 rows
and the one Q07 row remained pending; no verdict is claimed. Each enqueued row
has an expected EX5 hash equal to the canonical EX5 recorded in the receipt.

| Rank | Sleeve | Gate generation | Action / work item |
|---:|---|---|---|
| 1 | QM5_13301/GDAXI | exact current Q08 PASS | kept; no enqueue (`4dcaab4d-06ad-4b23-ace8-ddc557e034b8`) |
| 2 | QM5_13213/USDJPY | Q08 PASS absent | Q02 `6d58f343-d5b6-44f8-a35a-9a76990a87ca` |
| 3 | QM5_1567/EURUSD | Q08 PASS absent | Q02 `e460e02b-e940-49fa-ace0-e2b9c853e7d6` |
| 4 | QM5_10919/XTIUSD | Q08 PASS absent | Q02 `5dfddaa3-577a-472f-a1cf-86a144b0d694` |
| 5 | QM5_11165/AUDCAD | Q08 PASS absent | Q02 `d8d1bd76-b9a1-444b-b6d9-3c51ffadd290` |
| 6 | QM5_12778/AUDUSD-EURJPY basket | Q08 PASS absent | Q02 `462e2f78-8589-48eb-8bca-25c804b67bf8` |
| 7 | QM5_11421/AUDUSD | Q08 PASS absent | Q02 `c39df27f-a9c1-409d-a898-5a9350197d5f` |
| 8 | QM5_11165/EURUSD | Q08 PASS absent | Q02 `3a7550e9-4e09-4b9d-a652-fc3f7a4bfcb8` |
| 9 | QM5_11421/EURUSD | pre-refresh Q08 PASS | Q02 `eb8c046b-19ca-4867-8d85-f88aacd08a13` |
| 10 | QM5_11708/EURUSD | Q08 PASS absent | Q02 `8ebdc710-e2b3-4bed-a4b5-4fd9da6a4470` |
| 11 | QM5_10706/GBPUSD | Q08 PASS absent | Q02 `89ab3816-8428-4233-9446-36be8bf31251` |
| 12 | QM5_10939/GBPUSD | Q08 PASS absent | Q02 `ef8c152b-eb5b-4a3a-9801-ece65e833b1f` |
| 13 | QM5_10911/GDAXI | pre-refresh Q08 PASS | Q02 `893458b6-e143-4ef8-8550-903599ee32e5` |
| 14 | QM5_13128/NDX | current Q06, Q08 PASS absent | resume Q07 `e823ce10-dffe-48bd-b895-e96fce43d856` |
| 15 | QM5_10440/NDX | Q08 PASS absent | Q02 `81266750-d7d7-446f-91e1-6eb95bb0e62f` |
| 16 | QM5_11132/SP500 | Q08 PASS absent | Q02 `4bbb2c32-08da-4696-9063-e6e8332607fb` |
| 17 | QM5_12969/USDJPY | Q08 PASS absent | Q02 `27a43902-90b1-4581-8c91-a911332cf4a8` |
| 18 | QM5_10403/XAUUSD | Q08 PASS absent | **refused: Phase-A raw-series build gate** |
| 19 | QM5_10513/XAUUSD | Q08 PASS absent | **refused: Phase-A raw-series build gate** |
| 20 | QM5_12567/XAUUSD | pre-refresh Q08 PASS | Q02 `0a88a559-17a5-4a22-a195-7a8d534e1fa1` |
| 21 | QM5_12989/XAUUSD | Q08 PASS absent | **refused: source row resolves to noncanonical agent worktree** |
| 22 | QM5_1556/XAUUSD | Q08 PASS absent | Q02 `37d54224-d182-4082-ba60-b32a2086e5c1` |
| 23 | QM5_12567/XNGUSD | Q08 PASS absent | Q02 `46885308-0ea5-4408-90c9-2f716c37f433` |
| 24 | QM5_13117/EURGBP-AUDJPY basket | Q08 PASS absent | Q02 `f56d3034-abfe-4337-a103-1a85a50ad208` |

QM5_12989's guarded seeder refused source work item
`e5ef7795-d116-4f34-9841-4c6f012f3cc2` because its execution binding resolves
to `C:\QM\worktrees\codex-orchestration-1`, not canonical
`C:\QM\repo`. The binding was not bypassed and the database was not manually
rewritten. The row can be seeded only after the governing source lineage is
reconciled to the canonical directory.

Protected QM5_11422 and QM5_13036 work was not altered or displaced. At the
closing check neither EA had an active row; their preceding work remained in
its own durable terminal state. Phase C rows are ordinary append-only pipeline
work and may honestly pass, fail, or refuse as their Q evidence warrants.

### Addendum verification and review boundary

- Final target-source diff: 12 accepted instrumentation/SPEC refreshes; two
  refused MQ5 and EX5 files exactly equal the pre-cycle canonical hashes.
- Strict build gate: 12 PASS, two explicit performance refusals; all 12
  accepted MetaEditor logs report 0 errors and 0 warnings.
- Q09 implementation check: `py_compile` PASS and **9 focused tests passed**.
  The integration case proves append-only v2 lineage, fresh-build preference,
  immutable/idempotent enqueue behavior, cap/terminal restrictions, risk and
  stale guardrails, and zero canonical Q09 rows.
- Generation-2 snapshot: 15 rows, 600 sealed cells, 2 done/REVIEW_REQUIRED,
  4 active, 9 pending, 0 canonical Q09 rows.
- Phase-C receipt: 24 sleeves reconciled; 20 ordinary rows enqueued, one exact
  current Q08 PASS retained, two build refusals, one noncanonical-source
  refusal.
- Safety receipt: append-only; T_Live not mutated; AutoTrading not toggled;
  no manual terminal launch; no protected test interrupted.

The implementation and enqueue work is complete to the limits of the guarded
build and source-lineage contracts. Claude review is required before any
acceptance decision; ongoing Q09 diagnostics and Q02-to-Q08 cascades retain
their own evidence-derived terminal states.

### Phase-B transient-recovery cutover — 2026-08-05

Follow-on router task `698332ca-7cab-4301-9aca-3bc3a2aa472d` repaired the Q09
child-exit-1 semantics in canonical commits `a20ded0c4` and `aabb9f244`. The
core retry/requeue implementation was committed at `2026-08-05T17:37:56Z`;
the mixed generic/history-lock attempt-ceiling binding was committed at
`2026-08-05T17:53:17Z`. Fresh Q09 runner processes spawned from the canonical
checkout after those cutovers load the corresponding code without a worker or
terminal restart.

The requested assertion that all Phase-B execution started only after the fix
cannot be made truthfully. Phase B had already started before this task was
routed at `2026-08-05T16:51:28Z`. Six generation-2 runner processes began
before the core cutover: ranks 1, 2, 5, 7, 9, and 14 at `16:40:20Z`,
`16:41:53Z`, `16:45:40Z`, `16:47:25Z`, `16:53:35Z`, and `16:58:17Z`.
Those processes cannot reload Python code. They were neither stopped nor
restarted because doing so would interrupt active T1-T5 tests.

The first proven post-core-cutover runner was rank 6, work item
`7a496c8b-4a4a-57c4-b049-04fb9fbbc150`, freshly spawned on T2 at
`2026-08-05T17:41:05Z`. It exercised the new behavior in production: after
the bounded retry exhausted, the runner raised the explicit transient
`CapacityError`; the work item returned to pending at `17:44:48Z` with
`verdict=NULL`, `evidence_path=NULL`, zero canonical Q09 rows, and its
transient retry persisted. It was not prematurely adjudicated. Rank 8 then
fresh-spawned on T2 at `17:47:27Z`. Any re-claim after the second cutover loads
the mixed-counter ceiling fix as a new runner process.

At the `2026-08-05T17:49Z` reconciliation, generation 2 held 3 done rows, 4
active rows, 8 pending rows, and 0 failed rows. The pre-cutover rank-9 process
had terminalized `REVIEW_REQUIRED` at `17:45:04Z`; that outcome is retained as
its own evidence and is not rewritten. No canonical Q09 admission row was
created, no protected T6-T10 test was displaced, and no T_Live, AutoTrading,
or manual terminal action occurred.

### Q09 generation-3 transient follow-through — 2026-08-05

Router task `0c467a61-e52c-4395-b5ea-4da066399be7` appended generation-3
diagnostics for every generation-2 row that had terminalized under the old
code-1/no-receipt semantics by the `2026-08-05T18:34Z` reconciliation. This
includes the requested QM5_10919/XTIUSD and QM5_11132/SP500 rows plus two
additional victims that completed while the follow-through was active:
QM5_11421/AUDUSD and QM5_12567/XNGUSD.

The generation rerun implementation is commit `6bed121bb`. A generation-3
row reuses the exact generation-2 diagnostic anchor because that anchor hash
is part of every cell identity. Append-only rerun lineage is authenticated in
the new work-item payload instead of rewriting the anchor and silently
defining a different experiment. The binder accepts that reuse only when the
new row identifies its predecessor, generation is at least 3, and the sealed
anchor path and hash match. A provisional plan under
`refresh_v3\1f15021e-1f00-5687-b830-5000f5d9dec7` was stopped before queue
insertion when this identity check first detected a changed anchor hash; no
work-item row has that ID and it is not execution evidence.

| Sleeve | Generation-2 predecessor / failure terminal | Generation-3 row | Plan-file SHA-256 | Enqueue-receipt SHA-256 | `18:34Z` state |
|---|---|---|---|---|---|
| QM5_12567/XNGUSD | `3f409823-e2c0-50a8-850f-864e33faab94` / T5 | `341299de-5575-5e60-850f-9aab9f04c34c` | `7c48140088be8f8c0add6adfaad9f6137b463c5369c2f2486fd9b472214ba198` | `c4fe4866fbb01273d11bbafd8361fdf2d109947127358f697badb4f8834698d6` | active T1 |
| QM5_10919/XTIUSD | `4fd8d9b2-c4e2-5627-a799-90caee71af07` / T4 | `fb3460bb-d6ca-5047-9a01-b1b599be844e` | `ecc4894b2c18e36c044885e7db02a94e5014439f4a98f40dcdb8a1be72f1fba5` | `a430673674534223dd82536706c61d5afc1d1297c5ca41a605741739c3450c4b` | pending |
| QM5_11132/SP500 | `13fdb5a5-5b91-54f4-ba76-e4e70fbe73c6` / T3 | `7a3a2f4c-b5dc-5b0e-b0b1-39b252a53955` | `127f833828af8a21fe2b2ad31f28c0eda14c6744b95471309860fd4dfb064dc2` | `ec72eb007c3c1bc2a918f6b04c3cda1b9251a68b973f56919dbc7e2b98e31741` | pending |
| QM5_11421/AUDUSD | `8b3332c9-5023-5656-bff6-e8d937cbdc3d` / T1 | `d381e949-d3ae-56cf-b749-79fb8a57afb5` | `0d5fe88e1a787d589929b3031c380a6ccb36cf8f1a4801ececf566ce357b9c41` | `b027fa9d08b3341c927044634ef525fe3c5a535a1f2dd437f9eb838e559b6419` | pending |

For all four rows, a fresh database-and-plan audit found 40 cells, exact
ordered equality of `run_identity_sha256`, setfile hash, arm, compliance,
temporal mode, seed, and paired-base identity, and zero canonical
`q09_news_tests` rows. All remain diagnostic non-admission work.

The active generation-3 runner for `341299de...` was created at
`2026-08-05T18:20:24Z` as PID 16624 from
`C:\QM\repo\tools\strategy_farm\q09_news_runner.py`, after both transient
fix commits. Its command line binds the receipt plan hash above. This is a
fresh-spawn proof that the fixed runner is live. Generation-2 ranks 6, 8, and
17 separately demonstrate the fixed behavior through persisted
`TransientCellError` sidecars and pending/no-verdict requeue state. Ranks 5
and 14 remain active processes launched before the cutover; they were not
interrupted. Any later pending claim starts a new process from the current
canonical runner. No other terminal generation-2 row had an authenticated
code-1/no-receipt transient failure at the reconciliation cutoff.

### Reviewer-authorized QM5_10403 and QM5_10513 refresh

Claude's close verdict for `b84011f2-7a2e-463e-a296-df4b20546013`
(`APPROVED with corrections`) explicitly authorized `// perf-allowed` on the
original bounded raw-series survivor logic under the 2026-07-23 per-tick
calibration doctrine. The MQ5 changes are those inline comments plus the Q08
MAE lifecycle call as the first `OnTick` statement. SPEC v1.1 in each EA cites
the authorization. Strategy conditions, lookbacks, entries, exits, stops,
targets, sizing, and schedules were not changed.

| EA | Current MQ5 SHA-256 | Current EX5 SHA-256 | Strict build | Generation-2 Q09 | Q02 requalification |
|---|---|---|---|---|---|
| QM5_10403 | `b38cfd471fd31811bb23a5447c430cc1bfcc1f370eb816236c99bb88be55d251` | `2e77dc2d9593afdb3267a8e3e029f5d8d437ee8fbdfd1ab4cba0c139babed89e` | PASS `build_check_20260805_181856.json`, 0 errors / 0 warnings | `e525cbb6-136c-5eaf-9b06-ac62229ae0f3`, rank 13, pending; batch receipt SHA-256 `7515c0033c89578ba730168bdb73192d804bd65e15bb5aa7abebd228bd1c5972` | `adcddab6-b1b9-46e2-9922-595e542aa3a3`, pending, source `f81854dd-a44a-42dc-932a-42bc234747ca` |
| QM5_10513 | `dfccacd6fe901831eed363d296201e64a853bc5d5e3fc6dc30b9f235d8e8ee14` | `30e4920348c30363c2dbb5b488650bdba7560ce601767c37799d882d766462d6` | PASS `build_check_20260805_182356.json`, 0 errors / 0 warnings | `75f9a966-c7fe-5c48-a5cb-97f1bf77c07d`, rank 11, pending; batch receipt SHA-256 `200944d875857b834e68f5135b4ff9529a2262caad9ae2b329378cd3d23aa403` | `8ec6e886-95cf-48e7-bcb7-92b0f3c5d95e`, pending, source `54dc5091-8869-4ca8-ba9b-dd99ae2cb538` |

QM5_10513's strict preflight additionally required its four baseline
backtest presets to state the already-compiled disabled-session defaults
explicitly: enabled `0`, start `0`, end `2359`. These values equal the EA
defaults and do not change execution mechanics. The task-scoped guardrail
scan at `18:34Z` returned PASS with no findings for QM5_10403, QM5_10513, and
QM5_12989, including the 336-hour maximum stale-news rule. The two Q02 seeds
bind `RISK_FIXED > 0`, `RISK_PERCENT = 0`, their exact canonical setfile
hashes, and the EX5 hashes above. Build artifacts are commit `196fda53b`.

### QM5_12989 canonical Q02 lineage reconciliation

Commit `b21e9d062` adds an opt-in
`seed-fresh-q02 --reconcile-noncanonical-setfile` path. The default behavior
still refuses a noncanonical source. Opt-in reconciliation is restricted to
the same EA directory and setfile name under a `worktrees` path, requires the
canonical file to exist, compares every executable key/value parameter, and
records both paths and hashes. Any parameter drift refuses the seed. The
historical row is never updated.

For source row `e5ef7795-d116-4f34-9841-4c6f012f3cc2`, the worktree preset
SHA-256 is
`6e5f9d98f2be63e0c3e5346ea98ed1402e8d78d4e47decd7101f97bea5a36148`
and the canonical preset SHA-256 is
`8ff8cc9b2fbd0a6455dc0987c10d97c7c4f859303a534ed9080ae586ba739459`.
All 20 executable parameters are equal; differences are limited to comments,
BOM/whitespace, or line endings. The source row remains done/PASS with its
original `C:\QM\worktrees\codex-orchestration-1` path. New Q02 row
`b0bad5d4-29a1-4b86-873a-38a43112b25a` is pending with canonical
`C:\QM\repo` setfile path, canonical EX5 SHA-256
`77d3c5fda5ef2dfd0c138e6520f76d450a04fe812fcefabac07e2673fcd2e425`,
fixed-risk bindings, and the complete reconciliation object in its payload.
No manual database rewrite occurred.

Focused verification for this follow-through was 33 Q09 diagnostic/runner
tests and 21 Q02 enqueue tests, all PASS, plus Python compilation and diff
checks. The reconciliation tests prove both comment-only acceptance and
parameter-drift refusal. All new Q09 and Q02 rows remain pending/active work
whose eventual verdicts come only from their own Q evidence. The deliverable
is `REVIEW_REQUIRED`; no self-approval or pipeline verdict is claimed.

### Q09 generation-3 rank-5 follow-through — 2026-08-05

Router task `2979bc02-956e-4ca0-a282-4aff35cef1e4` authorized the final
pre-cutover rank-5 follow-through for QM5_11165/AUDCAD. The generation-2
predecessor `cc754e65-54be-50d4-9379-f32d4d9e4497` remains unchanged at
`done/REVIEW_REQUIRED`, has no claim, and has zero canonical
`q09_news_tests` rows.

The predecessor exposed a narrower false-terminal mechanism than the earlier
code-1/no-receipt victims. Its hash-bound holdout `run_smoke/v2` summary
(`cdea5249ee24c824a97d622966b56fd752d2a74ce9c1db24453a81f902b333cf`)
records overall `PASS`, one invalid `BARS_ZERO` startup attempt, and then one
authenticated `OK` attempt with 34 trades. The Q09 validator nevertheless
required the entire `runs` array to have length one and terminalized after
three authenticated cells plus that false failure. Commit `6518d767a` now
selects exactly one `OK` attempt while still refusing zero or multiple `OK`
attempts. The generation-rerun proof accepts this path only when the summary
is inside the failed cell, its SHA-256 matches the sealed failure artifact,
the summary is `PASS`, it contains multiple attempts, and exactly one attempt
is `OK`.

The append-only generation-3 row is
`da59e191-9621-503d-a3ea-e78b4eae1e2a`, rerun-of `cc754e65...`, avoiding
its predecessor terminal T4. It reuses predecessor anchor SHA-256
`a031b4f4ed28b333d1bd457e09640c1b6a829c453172cd196bf9a6ef2ea5ffa3`.
Its plan-file SHA-256 is
`cf5d301bda9da07aff5392c9dc3764f076b9a326308dba1623ad9994967c8c4e`
and enqueue-receipt SHA-256 is
`dae339e7cc7f7be0ef46f30bad70d0294a506a2a64d6eeab2c5a6f2e3f2a71cc`.
A fresh database-and-plan audit found 40/40 cells and exact ordered equality
of run identity, setfile hash, arm, compliance, temporal mode, seed, and
paired-base identity. The new row is diagnostic non-admission, pending/NULL,
unclaimed, and has zero canonical Q09 rows.

At the `2026-08-05T20:00Z` reconciliation, the diagnostic fleet was exactly
at its governed 5/5 cap on T1-T5, so the new rank-5 row remained pending and
no active test was interrupted. Rank-14 QM5_10939/GBPUSD row
`debf9533-f319-5b05-8c89-9747bba7e6bc` also remained pending/NULL with zero
canonical rows after its fixed-runner transient requeue. Its persisted
`transient_infra_attempts=1` and T3 avoidance retain the retry lineage; it is
eligible for a fresh claim when the cap releases and needs **no** generation-3
duplicate. A post-requeue claim was not yet observable at the cap and is not
invented here.

Focused verification was Python compilation plus both Q09 runner/diagnostic
suites: 35 tests PASS. This follow-through remains `REVIEW_REQUIRED`; no
admission, economic conclusion, or pipeline verdict is claimed.

### Q09 diagnostic minimum-trade floor class and generation-4 recovery — 2026-08-05

Router task `f61dbed0-3a85-475d-82b1-b833f9380ce9` investigated the
generation-3 QM5_12567/XNGUSD terminal row
`341299de-5575-5e60-850f-9aab9f04c34c`. Primary artifacts classify the
failure as **structural in the diagnostic caller**, not symbol/history data,
not a duplicate-run authentication failure, and not a transient process
failure.

The failed POLICY_ON/PRE60/seed-42 selection cell has cell-failure SHA-256
`16088f249db80889a620d174380493f3c1260154108a114581b500a12d269738`.
Its `run_smoke.log` SHA-256 is
`3ae11ceb0de0454de0ed69718ebf4f11637b752cb032ba3217b9e8963ae50c36`;
the log records a fresh calendar at age 74 hours against the unchanged
336-hour maximum, a valid report latch, one logger sample, and the sole
reason class `MIN_TRADES_NOT_MET`. The hash-bound `run_smoke/v2` summary
SHA-256
`33c404731feee92cadd95da46ec298609eea977dc411808faf4c7e355b6e1ee2`
contains exactly one authenticated `OK` attempt, 24 trades, deterministic
execution, no OnInit failure, and stable EX5/setfile identities. Q09 had
explicitly passed `-MinTrades 0`, but without `-SmokeMode` the shared smoke
runner replaced zero with the Q02 five-trades-per-year floor: 25 across the
five-year selection window. The diagnostic therefore rejected valid policy
measurement evidence for missing an admission-frequency threshold that Q09
does not judge.

The cc754e65/da59e191 lineage is a different class. Predecessor
`cc754e65-54be-50d4-9379-f32d4d9e4497` has a PASS holdout summary SHA-256
`cdea5249ee24c824a97d622966b56fd752d2a74ce9c1db24453a81f902b333cf`
with one `BARS_ZERO` startup attempt followed by one authenticated `OK`
attempt with 34 trades; commit `6518d767a` already fixed that exact-one-OK
selection defect. Its append-only successor
`da59e191-9621-503d-a3ea-e78b4eae1e2a` remained active on T1 at the
`2026-08-05T21:11Z` reconciliation and was not interrupted.

A campaign-wide scan of terminal diagnostic sidecars found the same sealed
minimum-trade signature in generation-2 rows `3f409823...` (24/25) and
`4fd8d9b2...` (20/25), and again in their already-superseding generation-3
rows `341299de...` and `fb3460bb...`. The generation-2 rows stay immutable
and receive no duplicate successor. No other terminal row had the exact
authenticated `FAIL` + sole `MIN_TRADES_NOT_MET` + one-OK-run signature;
for example, generation-3 `d381e949...` records timeout/incomplete/model-marker
classes and is deliberately refused by this rerun proof.

Commit `08bb5c7d4` adds the existing `-SmokeMode` opt-in to Q09's command only,
so the explicit diagnostic floor of zero is honored. The default smoke/Q02
path, report authentication, deterministic/identity checks, fresh logger
requirement, real-tick marker, terminal exclusion, and news-calendar
fail-closed validation are unchanged. Commit `f83bb4fcb` requires a sealed
fresh summary to prove exactly this structural floor class before a
generation rerun may be appended; unrelated fresh code-1 summaries fail
closed. The first generation-4 enqueue then exposed a lineage check that
incorrectly required the immutable generation-2 anchor to name its immediate
generation-3 predecessor. It failed before inserting a row. Commit
`d1945a21b` now authenticates the immediate parent independently and carries
the original sealed-anchor work-item ID through generation 3 to generation
4. The generation-3-to-4 regression is covered directly.

| Sleeve | Generation-3 predecessor / failed terminal | Generation-4 row | Plan-file SHA-256 | Enqueue-receipt SHA-256 | `21:11Z` state |
|---|---|---|---|---|---|
| QM5_12567/XNGUSD | `341299de-5575-5e60-850f-9aab9f04c34c` / T1 | `8b8a7819-2b78-5708-a503-9995c41befbb` | `c60ea0ed98179a673de7310ae64c261b02cdede6ae642e1d15e4649ace5114c0` | `f0ef4e7b957f59fdb22438698a0770c08d219db33fb8024b990273745823f576` | pending/NULL, unclaimed, avoids T1 |
| QM5_10919/XTIUSD | `fb3460bb-d6ca-5047-9a01-b1b599be844e` / T3 | `fcf04081-3d3a-51a7-b947-0c3b304021eb` | `36be699fe42781f3428a74d95b349f08ba6e254776a37f759d491f08506f6adc` | `cc63c99b0ff8da2e2b3958d88fd82f472c4ea462826963fb383fbb8176900f19` | pending/NULL, unclaimed, avoids T3 |

Both generation-4 rows are bound diagnostic non-admission work with 40/40
cells, exact ordered equality of run identity, setfile hash, arm, compliance,
temporal mode, seed, and paired-base identity against their immediate
predecessors. Each binds `RISK_FIXED=1000`, `RISK_PERCENT=0`, preserves the
original sealed anchor, allows only T1-T5, and has zero canonical
`q09_news_tests` rows. Focused verification was Python compilation, diff
checks, and both Q09 diagnostic/runner suites: 37 tests PASS. No T_Live or
AutoTrading setting was changed, no terminal was started manually, and no
active test was interrupted. The rows remain pending evidence work; no Q09
or pipeline verdict is inferred.

## 2026-08-06 ~08:40 — Gate-walk verdict: QM5_12567/XNGUSD diagnostic A/B COMPLETE (first top-weight sleeve result)

Generation-4 row `8b8a7819` completed 40/40 cells (7×1 target-compliance DXZ
scope, 5 seeds) after the min-trade-floor fix; adjudicator verdict
`REVIEW_REQUIRED` with `expanded_7x4_matrix_required` (`material_effect:
delta_profit_factor`). Claude gate-walk over all generation evidence
(`refresh_v2/3f409823`, `refresh_v3/341299de`, `refresh_v4/8b8a7819` —
overlapping arms byte-identical across generations, deterministic-identity
consistency confirmed):

| Arm (full window, mean of 5 seeds) | net_r | PF | trades | DD % |
|---|---|---|---|---|
| CONTROL OFF/NONE | 2.827 | 1.78 | 45 | 1.35 |
| POLICY OFF/DXZ | 2.827 | 1.78 | 45 | 1.35 |
| POLICY PRE30/DXZ | 2.827 | 1.78 | 45 | 1.35 |
| POLICY PRE60/DXZ | 2.848 | 1.80 | 44 | 1.45 |
| POLICY PRE30_POST30/DXZ (≈ live compile-default) | 2.890 | 1.82 | 44 | 1.24 |
| POLICY PRE60_POST60/DXZ | 2.911 | 1.84 | 43 | 1.34 |
| POLICY SKIP_DAY/DXZ | 2.818 | 2.19 | 28 | 1.52 |
| POLICY CLOSE_ALL_PRE/DXZ | 2.827 | 1.78 | 45 | 1.35 |

**Diagnostic verdict (non-admission, ceremony input):** the legacy/live news
filter is **harmless on XNGUSD** — the hidden-tax hypothesis is refuted for
this sleeve. Temporal pre/post windows barely bind (blocked_entries = 0 in
every arm; daily-bar entries rarely coincide with event windows); the live
compile-default PRE30_POST30/DXZ is marginally *better* than control
(+0.06 net_r, +0.04 PF). SKIP_DAY is an efficiency curiosity — same net_r
with 17 fewer trades (PF 2.19) — but is **not** recommended: equal net with
lower frequency adds no economic value and cuts compounding capacity.
**Recommendation for the pinning ceremony: pin the current effective policy
(PRE30_POST30/DXZ) or OFF — indifferent within noise; no policy change
required for XNG.** The `expanded_7x4_matrix_required` demand is
knowingly waived for this diagnostic non-admission row (it binds only a
future admission-grade Q09 run). Contrast: QM5_11422/USDCAD, where every
blocking variant materially hurt.

## 2026-08-06 ~09:20 — Transient-victim triage after the host crash (work package)

Two further diagnostic rows that surfaced as forced `REVIEW_REQUIRED` are
**transient victims, not measurements** (underlying aggregates
`INVALID_EVIDENCE/cell_receipt_invalid`):

- **QM5_11421/EURUSD** (`13860911`, T5): zero cell evidence; first cell
  accumulated six `TransientCellError` sidecars ("run_smoke exited with code 1
  without a fresh run_smoke summary or cell receipt") 02:18Z–05:51Z, spanning
  the post-crash cold-cache window. Generation rerun dispatched: codex ticket
  `a1f0a936`, avoid T5.
- **QM5_10440/NDX** (`8f2a0a29`, T3): 39/40 cells missing, adjudicated 02:58Z
  mid-recovery. Generation rerun dispatched: codex ticket `9887ebeb` (A),
  avoid T3.
- **QM5_10939/GBPUSD** (`debf9533`, T4): INFRA_FAIL 03:17Z. Generation rerun
  in ticket `9887ebeb` (B), avoid T4.

Staged crash-recovery requeues executed directly: Q07 QM5_11205/XAUUSD rerun
`5b619e63` (predecessor Q06 PASS 67b69d37) and Q06 QM5_12918/USDCAD rerun
`447968f2` (predecessor Q05 PASS 1d207268), both EX5-sha-bound. Basket motors
20233/20234/20235 need a sweep part2 coverage extension (ticket `9887ebeb` C).
The QM5_12552 duplicate_ex5 wave (twin-EX5 relic removed, commit `c442d853f`)
is passing: 6/11 Q02 PASS at the time of writing, zero failures post-fix.

## 2026-08-06 08:34 CEST - crash-recovery wave 2 execution

Router task `9887ebeb-af11-42f3-a306-97a441c134e3` appended two generation-3
diagnostic successors. Both are non-admission rows, retain the predecessor's
sealed anchor, bind `RISK_FIXED=1000` and `RISK_PERCENT=0`, have zero canonical
`q09_news_tests` rows, and were independently audited as 40/40 ordered-equal
across run identity, setfile hash, arm, compliance, temporal mode, seed, and
paired-base identity.

| Sleeve | Predecessor / avoided terminal | Successor | Anchor SHA-256 | Receipt SHA-256 | State at audit |
|---|---|---|---|---|---|
| QM5_10440/NDX | `8f2a0a29-f8fd-57ad-a180-2b732a418eb9` / T3 | `2b792348-db4a-500f-a221-c26595ca3c83` | `9c7dd618747803b61accd65ff1096021505f106e93abe2356a81c4117cb0cd6a` | `5dc854325da0a9341cf90ec21d1b12b0cdfbaafee8dd4eb83a9e633b941496dd` | pending, unclaimed, `RUNNABLE_BOUND` |
| QM5_10939/GBPUSD | `debf9533-f319-5b05-8c89-9747bba7e6bc` / T4 | `2b74dd61-a521-53e9-8d31-1a4deb209338` | `8dd63fcc7902b1c0cf3f4abbac6fb0bbaabfee9f9472a6dfbee9aa76ec9ff7ca` | `949406acbf4ceffdf886c723188b7ce59160d083bee131270b67dd5a6023fd01` | pending, unclaimed, `RUNNABLE_BOUND` |

The QM5_10939 command first failed closed because its predecessor pinned EX5
SHA-256 `486b1690...`, while the mutable canonical binary had since moved to
`812fc52a...`. The predecessor's own preflight evidence records that mismatch,
and its recorded T3 staging destination still contained exactly `486b1690...`.
The rerun tool now accepts this narrow terminal `failed/INFRA_FAIL` class only
when the preflight receipt is internally consistent, the recorded vintage
matches the sealed manifest hash, and an immutable successor copy is written.
The current canonical binary was not overwritten. The successor copy is under
`refresh_v3/2b74dd61.../source_vintage/` and is hash-bound in the new plan.

Sweep part 2 was extended to retry terminal (`done` or `failed`) INFRA_FAIL Q02
rows for validated logical baskets. It now validates the manifest and physical
`.DWX` host, carries the basket contract, records the exact source row, and
retains the existing per-run cap. A targeted dry run found exactly three rows;
the apply run used `--max-part2-per-run 3`, enqueued exactly three, skipped zero,
and set `rate_limited=true` in
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` (SHA-256
`27355d25002cc9fd7b590a4fb26ff0525b26dda402d6ad298f471d1c9f0da0eb`).

| EA | Source INFRA_FAIL row | Successor Q02 row | State at audit |
|---|---|---|---|
| QM5_20233 | `51eb0d13-b80f-4bb1-a07d-1765c4c228d1` | `681cb88b-3c7e-46b5-9043-e162426d719f` | pending, unclaimed |
| QM5_20234 | `29a9765e-7fb9-4b06-8740-15e5eab1f32b` | `ed115d61-4339-48b4-9a74-26f7e63aec3d` | pending, unclaimed |
| QM5_20235 | `65eee7b4-b206-48ac-ac6c-4a8ba4a8bd17` | `227c76b0-9b6b-4176-8367-051020a2db17` | pending, unclaimed |

All three basket setfiles independently read `RISK_FIXED=1000` and
`RISK_PERCENT=0`. No raw database update, terminal interruption, T_Live write,
AutoTrading change, pipeline verdict, or admission claim was made.

## 2026-08-06 08:38 CEST - QM5_11421 transient generation rerun

Router task `a1f0a936-2c52-4e2f-af48-f9d69d8834ae` appended generation-3
successor `ad3d6327-044c-5685-ada7-ee71ea30cb3e` for QM5_11421/EURUSD from
predecessor `13860911-0db4-56fc-b82f-00746bf2cfd7`, excluding T5. The enqueue
receipt SHA-256 is
`a4829e7b091753dbc491e4ea2c9107b567cdbc5745ca43a3d8a44446bc5b642a`.

An independent post-enqueue audit found 40/40 ordered equality for run identity,
setfile hash, arm, compliance, temporal mode, seed, and paired-base identity.
The successor carries sealed anchor SHA-256
`213a305c54402e212fab4b007eb3fb776025e6df317e1a298f84859174f4478c`,
binds `RISK_FIXED=1000` and `RISK_PERCENT=0`, and had zero canonical
`q09_news_tests` rows. It was pending, unclaimed, and `RUNNABLE_BOUND` at the
audit. The rerun receipt authenticated five extant transient/no-receipt failure
sidecars; no missing sixth artifact is invented. This remains diagnostic
non-admission work with no policy or pipeline verdict.

## 2026-08-06 ~11:55 — Gate-walk verdict: QM5_11132/SP500 diagnostic A/B COMPLETE

Row `7a3a2f4c` (refresh_v3): 40/40 cells, underlying REVIEW_REQUIRED with
`expanded_7x4_matrix_required` (material effect — waived for the diagnostic
non-admission purpose as before). Full-window means over 5 seeds:

| Arm | net_r | PF | trades | DD % |
|---|---|---|---|---|
| CONTROL OFF/NONE | 7.174 | 1.34 | 84 | 4.03 |
| POLICY OFF/DXZ | 7.174 | 1.34 | 84 | 4.03 |
| POLICY PRE30/DXZ | 7.467 | 1.36 | 84 | 4.03 |
| POLICY PRE60/DXZ | 7.796 | 1.37 | 84 | 4.03 |
| POLICY PRE30_POST30/DXZ (≈ live default) | 7.467 | 1.36 | 84 | 4.03 |
| POLICY PRE60_POST60/DXZ | 7.514 | 1.36 | 83 | 4.03 |
| POLICY SKIP_DAY/DXZ | **2.745** | 1.18 | 41 | 4.72 |
| POLICY CLOSE_ALL_PRE/DXZ | 7.467 | 1.36 | 84 | 4.03 |

**Diagnostic verdict:** mild temporal windows are neutral-to-slightly-positive
(entries rarely collide with event windows; PRE60 best at +8.7 % net_r —
within diagnostic noise, no adoption case). **SKIP_DAY is catastrophic:
−62 % net_r with doubled-down DD — news days are where SP500 daily
mean-reversion earns.** Ceremony recommendation: pin the current effective
policy (PRE30_POST30/DXZ) — and never adopt day-level blocking for this
sleeve. Three sleeves now show three distinct profiles (11422: all blocking
hurts; XNG: indifferent; 11132: windows fine, day-skip lethal) — the
per-sleeve A/B differentiation is earning its cost.

## 2026-08-06 ~12:25 — Gate-walk verdict: QM5_10919/XTIUSD diagnostic A/B COMPLETE (first hidden-tax finding)

Gen-4 row `fcf04081` (refresh_v4, the former min-trade-floor victim): 40/40
cells, underlying REVIEW_REQUIRED with `expanded_7x4_matrix_required` (waived
for diagnostics as before). Full-window means over 5 seeds:

| Arm | net_r | PF | trades | DD % |
|---|---|---|---|---|
| CONTROL OFF/NONE | 6.172 | 4.52 | 28 | 1.76 |
| POLICY OFF/DXZ | 6.172 | 4.52 | 28 | 1.76 |
| POLICY PRE30/DXZ | 6.178 | 4.57 | 27 | 1.76 |
| POLICY PRE60/DXZ | 6.115 | 4.53 | 26 | 1.76 |
| POLICY PRE30_POST30/DXZ (≈ live default) | **5.744** | 4.32 | 26 | 1.76 |
| POLICY PRE60_POST60/DXZ | 5.682 | 4.28 | 25 | 1.76 |
| POLICY SKIP_DAY/DXZ | **−0.026** | 0.98 | 6 | 1.36 |
| POLICY CLOSE_ALL_PRE/DXZ | 6.178 | 4.57 | 27 | 1.76 |

**Diagnostic verdict:** first sleeve with a measurable hidden tax in the
effective live policy — the POST windows filter one to two of only 28 entries,
and at PF 4.5 those entries carry real PnL: **−7 % net_r vs control for
PRE30_POST30, −8 % for PRE60_POST60.** Pre-only windows and CLOSE_ALL_PRE are
free (≈ control). SKIP_DAY annihilates the sleeve (28→6 trades, negative
net). **Ceremony recommendation: re-pin 10919 to OFF or PRE30 (drop the POST
window) — a free +7 % net improvement on the #2-weight sleeve.** Frequency
note: 28 trades over the full window ≈ 4/yr — consistent with its Q02-requal
MIN_TRADES_NOT_MET and the probation-review frequency flag. Four sleeves,
four profiles now (11422 all-blocking-hurts · XNG indifferent · 11132
day-skip-lethal · 10919 post-window-tax).

## 2026-08-06 ~14:00 — Gate-walk verdict: QM5_10706/GBPUSD diagnostic A/B COMPLETE (strongest hidden-tax finding)

Row `831d40fb` (refresh_v2): 40/40 cells, underlying REVIEW_REQUIRED with
`expanded_7x4_matrix_required` (waived for diagnostics). Full-window means
over 5 seeds (high-frequency sleeve, 315 trades):

| Arm | net_r | PF | trades | DD % |
|---|---|---|---|---|
| CONTROL OFF/NONE | 86.371 | 1.48 | 315 | 9.14 |
| POLICY OFF/DXZ | 86.371 | 1.48 | 315 | 9.14 |
| POLICY PRE30/DXZ | 84.606 | 1.47 | 312 | **17.13** |
| POLICY PRE60/DXZ | 79.575 | 1.44 | 310 | 10.38 |
| POLICY PRE30_POST30/DXZ (≈ live default) | **78.984** | 1.43 | 310 | **16.10** |
| POLICY PRE60_POST60/DXZ | 55.577 | 1.30 | 307 | 12.35 |
| POLICY SKIP_DAY/DXZ | 13.001 | 1.26 | 80 | 13.33 |
| POLICY CLOSE_ALL_PRE/DXZ | 81.847 | 1.47 | 303 | 17.13 |

**Diagnostic verdict: 11422-class profile at scale — every blocking variant
hurts.** The effective live default costs −8.6 % net_r AND nearly doubles max
drawdown (9.14 → 16.10 %); even the mildest window (PRE30, only 3 trades
filtered) doubles DD, i.e. the filtered entries are disproportionately the
ones that keep the equity path smooth. Escalation to PRE60_POST60 (−36 %) and
SKIP_DAY (−85 %) is monotone-destructive. **Ceremony recommendation: re-pin
10706 to OFF — second concrete re-pin candidate after 10919, and the largest
single lever so far (+8.6 % net, DD roughly halved vs effective default).**
Five sleeves, verdict tally: blocking hurts 2 (11422, 10706) · indifferent 1
(XNG) · day-skip-lethal-only 1 (11132) · post-window-tax 1 (10919).

## 11165/AUDCAD — sixth verdict (~00:55 08-07)

Generation lineage: 7fc27138 (v2, transient-poisoned) → cc754e65 → **da59e191
(gen-3, COMPLETE: 40/40 cells authentic, underlying REVIEW_REQUIRED =
diagnostic non-admission wrapper, NOT invalid; adjudicator additionally flags
`expanded_7x4_matrix_required` for a final gate verdict — the 40-cell read
below is the diagnostic measurement)**. Selection-window arm table
(sleeve_arms.py, n = cells per arm across generations):

| Arm | net_r | PF | trades | maxDD% |
|---|---|---|---|---|
| CONTROL OFF/NONE | 1.155 | 1.08 | 111 | 3.38 |
| POLICY OFF/DXZ | 1.155 | 1.08 | 111 | 3.38 |
| POLICY PRE30/DXZ | −0.294 | 0.98 | 107 | 4.45 |
| POLICY PRE60/DXZ | −0.843 | 0.94 | 106 | 4.45 |
| POLICY PRE30_POST30/DXZ (≈ live default class) | −0.134 | 0.99 | 100 | 3.89 |
| POLICY PRE60_POST60/DXZ | −1.267 | 0.90 | 98 | 3.89 |
| POLICY SKIP_DAY/DXZ | −4.919 | 0.46 | 41 | 6.04 |
| POLICY CLOSE_ALL_PRE/DXZ | −0.294 | 0.98 | 107 | 4.45 |

OFF/DXZ == CONTROL exactly (mechanism sanity holds). **Every blocking arm is
net-negative and PF < 1 while the unblocked sleeve is positive** — removing
4–13 news-window trades flips the whole selection-window economics; SKIP_DAY
destroys the sleeve (PF 0.46, trades 111→41, DD 3.38→6.04 %). Same class as
11422 and 10706. Margins are small in absolute net_r (thin sleeve in this
window), but the sign is uniform across all six blocking arms.

**Ceremony recommendation: THIRD re-pin candidate — 11165/AUDCAD → OFF**
(weight #5, 0.52 RISK_PERCENT). Final gate verdict wants the 7×4 expanded
matrix (105 further cells) — enqueue in a low-load window; the diagnostic
direction is already unambiguous.

Six sleeves, verdict tally: blocking hurts 3 (11422, 10706, 11165) ·
indifferent 1 (XNG) · day-skip-lethal-only 1 (11132) · post-window-tax 1
(10919).

## 2026-08-07 — 11421/EURUSD generation-4 death and post-migration deferral

Generation-4 rerun `57f403c0-aace-57d5-a111-5e1791b4dee4` (T1-claim path,
avoid T3) died 06:18Z with
`shared_bases_history_lock_transient_cap_exhausted` after 7 transient
attempts (evidence: `D:\QM\mt5\T5\logs\20260807.log`, tester line 08:17:44
local "some error after pass finished"). Fourth consecutive
infrastructure-killed generation for this sleeve; EURUSD carries 75.7 % of
the measured error-32 hits (root-cause doc 2026-08-06), so under current
fleet load every further attempt competes against the exact contention
surface the OWNER-ratified Variant-A isolation (decision db40ba300, window
Sunday 2026-08-09) removes.

**Decision (Claude, diagnostic non-admission lane): defer generation 5 to
post-migration.** No further pre-migration attempts. The Saturday programme
verdict doc will carry 11421/EURUSD as "infra-deferred to post-isolation" —
same treatment as the basket motors (20234/20235). Queue-note: the staggered
XAU successors were additionally claim-paused this morning by design
(`commit_headroom_low_pause`, 34 GiB commit reservation of the QM5_20233
multi-symbol Q02 on T1); they claim as headroom frees.
