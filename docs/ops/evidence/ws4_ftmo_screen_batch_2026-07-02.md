# WS4 FTMO Admission Screen Batch - 2026-07-02

Scope: entire Q08 `FAIL_SOFT` pool from `D:/QM/strategy_farm/state/farm_state.sqlite` plus the current 13-sleeve live book from `decisions/2026-07-01_t_live_d2c_13sleeve_book.md`. The live sleeves were already present in the Q08 `FAIL_SOFT` pool after `.DWX` normalization, so the union is 19 unique EA/symbol candidates.

Execution: `tools/strategy_farm/portfolio/prop_challenge_optimizer.py --screen-candidate ... --candidate-report <report.htm> --screen-runs 20 --screen-seeds 0,1,2,3,4 --force-confirm --out D:/QM/strategy_farm/artifacts/portfolio/ftmo_screen_batch_20260702/<candidate>.json`. Defaults were used for Round24 risk scales and candidate weights.

Benchmark: Round24 clean bar from `prop_challenge_ftmo_combo_scale_sweep_round24_20260630.json`, risk scale `5.9`, min robust `57.04`, mean robust `57.776`, max max-loss breach `4.96`, mean target-not-reached `38.04`.

Artifacts: `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702`. JSON artifacts written: 19. Skipped for missing report: 0.

Basis note: all screens used native MT5 `report.htm` closing deals, not Q08 jsonl streams. Exact 2023-2025 Round24-calendar reports were located for 7 candidates; 12 candidates used broader Q08 baseline reports covering 2017-2025 because no exact prop-FTMO report was located. The admission code unions candidate and lead calendars, so the broader-report rows are marked in the basis column.

Verdict counts: ADMIT 0, BACKUP 13, REJECT 6.

## Ranked Summary

Sorted by verdict (`ADMIT`, `BACKUP`, `REJECT`), then min-robust delta vs Round24 descending. `TOP10` marks the first ten rows under that sort.

| Rank | Top | Candidate | Live | Verdict | Min robust delta | Min robust | Mean robust | Max daily breach | Max-loss breach | Target not reached | Risk | Cand wt | Basis | Trades |
|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|
| 1 | TOP10 | `QM5_10440:NDX.DWX` | yes | BACKUP | -7.04 | 50 | 55 | 0 | 5 | 43 | 6 | 0.08 | `EXACT_2023_2025` | 265 |
| 2 | TOP10 | `QM5_10692:NDX.DWX` | yes | BACKUP | -12.04 | 45 | 56 | 0 | 5 | 42 | 5.9 | 0.1 | `EXACT_2023_2025` | 224 |
| 3 | TOP10 | `QM5_10494:XAUUSD.DWX` | no | BACKUP | -52.04 | 5 | 7 | 0 | 0 | 93 | 6.1 | 0.03 | `COVERS_2017-01-01_2025-12-31` | 667 |
| 4 | TOP10 | `QM5_10569:XAUUSD.DWX` | no | BACKUP | -52.04 | 5 | 7 | 0 | 0 | 93 | 6.1 | 0.08 | `COVERS_2017-01-01_2025-12-31` | 324 |
| 5 | TOP10 | `QM5_10115:GDAXI.DWX` | no | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 430 |
| 6 | TOP10 | `QM5_10513:XAUUSD.DWX` | yes | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 76 |
| 7 | TOP10 | `QM5_10938:GDAXI.DWX` | no | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 78 |
| 8 | TOP10 | `QM5_10940:XAUUSD.DWX` | yes | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 51 |
| 9 | TOP10 | `QM5_11124:SP500.DWX` | no | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 60 |
| 10 | TOP10 | `QM5_11128:NDX.DWX` | no | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 146 |
| 11 |  | `QM5_11421:AUDUSD.DWX` | yes | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 81 |
| 12 |  | `QM5_12567:XAUUSD.DWX` | yes | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 73 |
| 13 |  | `QM5_12567:XNGUSD.DWX` | yes | BACKUP | -57.04 | 0 | 4 | 0 | 0 | 96 | 5.7 | 0.01 | `COVERS_2017-01-01_2025-12-31` | 58 |
| 14 |  | `QM5_11132:SP500.DWX` | yes | REJECT | -12.04 | 45 | 56 | 0 | 10 | 41 | 6.1 | 0.01 | `EXACT_2023_2025` | 32 |
| 15 |  | `QM5_11421:EURUSD.DWX` | yes | REJECT | -12.04 | 45 | 56 | 0 | 10 | 41 | 6.1 | 0.01 | `EXACT_2023_2025` | 34 |
| 16 |  | `QM5_11165:AUDCAD.DWX` | yes | REJECT | -12.04 | 45 | 56 | 0 | 15 | 41 | 6.1 | 0.01 | `EXACT_2023_2025` | 53 |
| 17 |  | `QM5_10715:USDJPY.DWX` | yes | REJECT | -12.04 | 45 | 55 | 0 | 10 | 42 | 6.1 | 0.01 | `EXACT_2023_2025` | 468 |
| 18 |  | `QM5_10939:GBPUSD.DWX` | yes | REJECT | -12.04 | 45 | 55 | 0 | 10 | 42 | 6 | 0.08 | `EXACT_2023_2025` | 34 |
| 19 |  | `QM5_10911:GDAXI.DWX` | yes | REJECT | -57.04 | 0 | 6 | 20 | 0 | 93 | 6.1 | 0.08 | `COVERS_2017-01-01_2025-12-31` | 296 |

## Report Basis

| Candidate | Period | Calendar days | Report used | Artifact |
|---|---|---:|---|---|
| `QM5_10440:NDX.DWX` | H1 (2023.01.01 - 2025.12.31) | 1096 | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round12\QM5_10440\20260629_173555\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10440_NDX_DWX.json` |
| `QM5_10692:NDX.DWX` | H1 (2023.01.01 - 2025.12.31) | 1096 | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round10\QM5_10692\20260629_170804\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10692_NDX_DWX.json` |
| `QM5_10494:XAUUSD.DWX` | H8 (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_10494\Q08\_baseline\QM5_10494\20260701_004315\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10494_XAUUSD_DWX.json` |
| `QM5_10569:XAUUSD.DWX` | H4 (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_10569\Q08\_baseline\QM5_10569\20260701_105232\raw\run_02\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10569_XAUUSD_DWX.json` |
| `QM5_10115:GDAXI.DWX` | M15 (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_10115\Q08\_baseline\QM5_10115\20260626_215722\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10115_GDAXI_DWX.json` |
| `QM5_10513:XAUUSD.DWX` | Daily (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_10513\Q08\_baseline\QM5_10513\20260626_230143\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10513_XAUUSD_DWX.json` |
| `QM5_10938:GDAXI.DWX` | H1 (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_10938\Q08\_baseline\QM5_10938\20260701_101026\raw\run_03\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10938_GDAXI_DWX.json` |
| `QM5_10940:XAUUSD.DWX` | H4 (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_10940\Q08\_baseline\QM5_10940\20260627_182436\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10940_XAUUSD_DWX.json` |
| `QM5_11124:SP500.DWX` | Daily (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_11124\Q08\_baseline\QM5_11124\20260701_100709\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_11124_SP500_DWX.json` |
| `QM5_11128:NDX.DWX` | Daily (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_11128\Q08\_baseline\QM5_11128\20260627_203904\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_11128_NDX_DWX.json` |
| `QM5_11421:AUDUSD.DWX` | Daily (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_11421\Q08\_baseline\QM5_11421\20260627_122807\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_11421_AUDUSD_DWX.json` |
| `QM5_12567:XAUUSD.DWX` | Daily (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_12567\Q08\_baseline\QM5_12567\20260627_201726\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_12567_XAUUSD_DWX.json` |
| `QM5_12567:XNGUSD.DWX` | Daily (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_12567\Q08\_baseline\QM5_12567\20260626_222604\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_12567_XNGUSD_DWX.json` |
| `QM5_11132:SP500.DWX` | Daily (2023.01.01 - 2025.12.31) | 1096 | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round28\QM5_11132\20260630_093605\raw\run_02\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_11132_SP500_DWX.json` |
| `QM5_11421:EURUSD.DWX` | Daily (2023.01.01 - 2025.12.31) | 1096 | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round29\QM5_11421\20260630_105406\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_11421_EURUSD_DWX.json` |
| `QM5_11165:AUDCAD.DWX` | H1 (2023.01.01 - 2025.12.31) | 1096 | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round29\QM5_11165\20260630_105406\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_11165_AUDCAD_DWX.json` |
| `QM5_10715:USDJPY.DWX` | M15 (2023.01.01 - 2025.12.31) | 1096 | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round21\QM5_10715\20260630_051112\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10715_USDJPY_DWX.json` |
| `QM5_10939:GBPUSD.DWX` | H4 (2023.01.01 - 2025.12.31) | 1096 | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round29\QM5_10939\20260630_105406\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10939_GBPUSD_DWX.json` |
| `QM5_10911:GDAXI.DWX` | H1 (2017.01.01 - 2025.12.31) | 3287 | `D:\QM\reports\pipeline\QM5_10911\Q08\_baseline\QM5_10911\20260627_164840\raw\run_01\report.htm` | `D:\QM\strategy_farm\artifacts\portfolio\ftmo_screen_batch_20260702\QM5_10911_GDAXI_DWX.json` |

## Skips

None. All 19 candidates had a locatable native MT5 `report.htm`.

## Top 10

- 1. `QM5_10440:NDX.DWX` - BACKUP, min-robust delta -7.04 pp, basis `EXACT_2023_2025`.
- 2. `QM5_10692:NDX.DWX` - BACKUP, min-robust delta -12.04 pp, basis `EXACT_2023_2025`.
- 3. `QM5_10494:XAUUSD.DWX` - BACKUP, min-robust delta -52.04 pp, basis `COVERS_2017-01-01_2025-12-31`.
- 4. `QM5_10569:XAUUSD.DWX` - BACKUP, min-robust delta -52.04 pp, basis `COVERS_2017-01-01_2025-12-31`.
- 5. `QM5_10115:GDAXI.DWX` - BACKUP, min-robust delta -57.04 pp, basis `COVERS_2017-01-01_2025-12-31`.
- 6. `QM5_10513:XAUUSD.DWX` - BACKUP, min-robust delta -57.04 pp, basis `COVERS_2017-01-01_2025-12-31`.
- 7. `QM5_10938:GDAXI.DWX` - BACKUP, min-robust delta -57.04 pp, basis `COVERS_2017-01-01_2025-12-31`.
- 8. `QM5_10940:XAUUSD.DWX` - BACKUP, min-robust delta -57.04 pp, basis `COVERS_2017-01-01_2025-12-31`.
- 9. `QM5_11124:SP500.DWX` - BACKUP, min-robust delta -57.04 pp, basis `COVERS_2017-01-01_2025-12-31`.
- 10. `QM5_11128:NDX.DWX` - BACKUP, min-robust delta -57.04 pp, basis `COVERS_2017-01-01_2025-12-31`.

No MT5 terminal was launched and no T5/T_Live process was touched.
