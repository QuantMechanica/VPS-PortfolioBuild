# Live-book news-policy diagnostic backfill

**Date:** 2026-08-05

**Router task:** `3260d15d-4977-4472-8eac-270b260a7842`

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

## Actual runtime policy represented by the live presets

The 17 source presets contain the historical fields
`qm_filter_news_enabled=1` and `qm_filter_news_mode=3`. Those fields do **not**
describe the running policy of these binaries: none of the 14 unique target EA
sources declares either `qm_filter_news_*` input, while all 14 declare the
current two-axis inputs. MT5 therefore has no target EA input to which those
legacy preset lines can bind.

The loaded T_Live chart inputs are the authoritative runtime values for every
target sleeve:

- `qm_news_temporal=3` = `PRE30_POST30`: no new entry from 30 minutes before
  through 30 minutes after an applicable event.
- `qm_news_compliance=1` = `DXZ`. The current framework labels this profile a
  placeholder and adds no separate firm-specific window; the temporal window
  remains effective.
- `qm_news_min_impact=high`: only events meeting the HIGH threshold are gated.
- `qm_news_stale_max_hours=336`: the fail-closed ceiling is unchanged.

The nearest sealed Q09 temporal policy is therefore an **exact**, not
approximate, match: `PRE30_POST30/DXZ` (mode ids `3/1`). The diagnostic also
tests `OFF`, `PRE30`, `PRE60`, `PRE60_POST60`, `SKIP_DAY`, and
`CLOSE_ALL_PRE`, always against the separate `CONTROL_OFF/OFF/NONE` arm.

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
daemons themselves were born at 14:35 local time, before the diagnostic review-
sidecar completion patch was loaded. They must be recycled only after their
current terminal slots become idle; interrupting these active tests is
forbidden. Until that orderly reload, a completed diagnostic may be requeued
fail-closed by the old completion handler, but it still cannot be admitted or
promoted.

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
| QM5_10919/XTIUSD | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
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
