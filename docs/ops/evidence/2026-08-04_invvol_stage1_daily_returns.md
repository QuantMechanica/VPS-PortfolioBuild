# DXZ inverse-volatility stage-1 daily-return substrate

Date: 2026-08-04

Router task: `2f5a7926-efb7-4b62-a564-2912b02ba02f`

Artifact: `D:/QM/reports/portfolio/invvol_stage1_20260804/`

Status: `PASS_WITH_EXPECTED_NOT_EXTRACTABLE` (data package only)

## Outcome

The actual 24-sleeve DXZ live manifest was bound and processed once:

- 23 sleeves have a full weekday daily-return series and realized-volatility
  summary;
- `QM5_10440/NDX.DWX` is explicitly `NOT_EXTRACTABLE` because its exact Q10
  work item is `FAIL` and the signed deploy record says that no Q10 PASS
  baseline exists;
- all 24 sleeves have a per-sleeve CSV. The `QM5_10440` file is deliberately
  header-only rather than populated from an unaccepted report;
- the read-only T_Live journal snapshot contributes 78 matching deal rows and
  36 closed position lifecycles as a separate overlay;
- no portfolio weights, weight recommendation, pipeline verdict, deploy
  action, database state change, or live-control action was produced.

## Book and source binding

The source book is:

- `D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json`
- SHA-256
  `8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6`
- book `DXZ_4000090541`, status `LIVE`, declared/actual sleeves `24/24`.

This is the manifest named by
`D:/QM/reports/state/live_book_pulse_postdeploy_20260802.json`. It is the
actual deployed book, not the later un-deployed FINAL24b alternative.

Source categories:

| source | sleeves | treatment |
|---|---:|---|
| work-item-bound Q10 PASS native report | 22 | extracted |
| `QM5_12567/XNGUSD.DWX` bound Q08 baseline native report | 1 | extracted as data only; parent `FAIL_HARD` preserved |
| `QM5_10440/NDX.DWX` Q10 FAIL | 1 | `NOT_EXTRACTABLE`; header-only output |

`lineage.csv` documents, for every manifest sleeve, its work-item ID, exact
artifact/report/summary path, SHA-256 values, native and parsed trade counts,
risk/news controls, generated CSV paths and hashes, and extraction reason.
This is the per-sleeve work-item/path record required by the task; no sleeve is
silently dropped.

The one fail-closed row is:

- sleeve: `QM5_10440_NDX_104400003`
- Q10 work item: `bdfdd179-3801-492c-b3c0-2a5a163d16a4`
- artifact:
  `D:/QM/reports/pipeline/QM5_10440/Q10/NDX_DWX/aggregate.json`
- artifact verdict: `FAIL`
- reason: `dd_above_ceiling:dd_pct=31.01:max=25.0`
- deploy evidence:
  `docs/ops/evidence/2026-08-02_ks_deploy_execution.md` records this sleeve as
  the book's one uncovered baseline.

## Construction

Each accepted native `report.htm` was parsed with the repository's canonical
FIFO deal parser (`ftmo_report_cost_reconcile.extract_round_trips`). The
parsed lifecycle rows were written to `source_report_csv/` and then aggregated
by report close date. Screenshots and visual transcription were not used.

For every extracted sleeve:

- parsed lifecycle count equals the native report total and selected summary;
- parsed net P&L equals the native report and selected summary within one cent;
- `RISK_FIXED=1000` and `RISK_PERCENT=0` are proven by the report inputs;
- the mandatory PRE30/POST30 news blackout is proven by the modern report
  inputs or, for `QM5_1567`, legacy mode 1 plus the Q10 DXZ attestation;
- modern reports record `qm_news_stale_max_hours=336`. The legacy `QM5_1567`
  report does not expose that input; its selected run instead binds an `OK`
  calendar with `max_age_hours=336`. No value above 336 is used;
- the selected run uses the full history request `2017.01.01` through
  `2025.12.31`.

The required money series is normalized by fixed-risk unit:

```text
daily_return_eur_at_RISK_FIXED_1000
  = native_net / native_RISK_FIXED * EUR 1000
```

The native reports use a USD test-account currency. This formula measures the
same strategy return per fixed-risk unit at an EUR 1,000 risk budget; it does
not relabel native cash P&L as an FX spot conversion. With native
`RISK_FIXED=1000`, the normalized number is numerically equal to the native
money result.

Calendar and metrics:

- 2,348 weekdays per extracted sleeve;
- no-close weekdays are zero-filled;
- `ann_vol`, `60d_vol`, and `120d_vol` are population standard deviations of
  normalized daily P&L, annualized by `sqrt(252)`;
- `max_dd` is peak-to-trough drawdown of cumulative normalized daily P&L,
  initialized at zero;
- `summary.csv` contains exactly the requested leading fields:
  `sleeve,n_days,ann_vol,60d_vol,120d_vol,max_dd,data_source,gaps_note`.

Two upstream source qualifications remain visible rather than being hidden:

- `QM5_10919/XTIUSD.DWX` has a selected run summary marked
  `MIN_TRADES_NOT_MET`, while its exact work-item-bound Q10 aggregate and work
  item are PASS. The package preserves both facts and uses the accepted Q10
  artifact only as a data source.
- `QM5_12567/XNGUSD.DWX` uses work item
  `084a05e0-99cf-435e-bce3-d464d97081e0`. Its Q08 aggregate is `FAIL_HARD`,
  but its baseline run is PASS and the aggregate binds stream, build, setfile,
  source and report. Only baseline data are extracted; no verdict is promoted.

The current live EX5 hash and historical report-build EX5 hash are both
recorded in `lineage.csv`. Exact binary equivalence is not claimed where they
differ; the selection claim is limited to the actual live manifest's
strategy/symbol lineage and the designated Q08/Q10 source artifacts.

## Read-only live overlay

The existing normalized journal was read and snapshotted; no terminal action
was taken:

- source:
  `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv`
- snapshot SHA-256:
  `21f232e2f8298f32f55ba30a6e048658a9d00786ce517d308d5a2608b619a00c`
- matched manifest deal rows: `78`
- closed position lifecycles: `36`
- account: `4000090541`, currency `USD`
- last journal export: `2026-08-04T13:41:23Z`.

The overlay retains actual USD profit, swap, commission and fee amounts. It is
not merged into the historical fixed-risk series because the journal's
`risk_percent_in_force` field is not populated. The fill, daily and sleeve
views are `live_overlay_fills.csv`, `live_overlay_daily.csv`, and
`live_overlay_summary.csv`.

## Verification

Reproducible package build:

```text
python D:/QM/reports/portfolio/invvol_stage1_20260804/extract_invvol_stage1.py
PASS_WITH_EXPECTED_NOT_EXTRACTABLE extracted=23 not_extractable=1 live_deals=78
```

An independent read-back verifier then:

- recomputed all full-history, 60-day and 120-day volatilities and maximum
  drawdowns from the generated daily CSVs;
- reconciled every generated report CSV row count to native/lineage counts;
- reconciled every daily-series total to its report-trade total;
- checked the explicit `QM5_10440` header-only fail-closed row and work-item
  binding;
- verified all 58 entries in `verification.json.output_sha256`;
- confirmed that the package has no weight output columns.

Independent result:

```text
PASS
series=24 extracted=23 daily_rows_per_extracted=2348
not_extractable=QM5_10440_NDX_104400003
live_deal_rows=78 live_closed_positions=36 output_hashes_verified=58
```

Key output hashes:

| file | SHA-256 |
|---|---|
| `verification.json` | `3b709332f9e6b33a229344bdc89d2af229f06ecd6bd01b4b7421d8ac153bba3a` |
| `summary.csv` | `04c175c9a8420f6370aef8345b3bd07a539f9b817ee3ea40be35af8cf8aacd5a` |
| `lineage.csv` | `16ecb060e7616b28f1d9008b744cc8b74849ba6713c194abd1a91a39dd763e1e` |
| `live_overlay_fills.csv` | `51a836dec6204aeb21354f7007ac1e12187032dd2c99a20b35d74b14cb50fd99` |

The package contains 59 files (2,261,290 bytes), including the verifier,
source snapshots, 24 daily CSVs, 24 parsed report CSVs, lineage, summary and
live overlays.

## Safety record

- farm database opened with SQLite URI `mode=ro` plus `PRAGMA query_only=ON`;
- T_Live journal/account files read only and copied into the report package;
- no T1-T10 work was interrupted;
- no terminal was started;
- no AutoTrading or T_Live setting was changed;
- no news-calendar threshold was weakened;
- no work-item or pipeline verdict was changed;
- writes were limited to the report directory and this canonical evidence
  document.
