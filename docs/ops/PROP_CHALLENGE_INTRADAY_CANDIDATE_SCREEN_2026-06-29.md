# Prop Challenge Intraday Candidate Screen - 2026-06-29

Scope: find higher-frequency candidates for a 60-calendar-day FTMO-style
2-step challenge after the D1 Q12-ready candidate proved too slow.

`T_Live` was not touched. Manual validation used disabled/free terminals
`T8`, `T9`, and `T10`.

## Method

The first broad screen used native MT5 `report.htm` closing deals, not the
stored Q04 aggregate PF alone. This matters because several older Q04 aggregates
were inflated by Common-Files stream/report mismatches.

Corrections applied during the screen:

- `summary.json`: use the last OK run only, not every OK retry.
- `Q04 aggregate.json`: use one report per fold.
- Calendar days with no trades are retained as zero-PnL days.
- Report-level PnL is adjusted as `profit + swap - max(2 * abs(close_commission), registry flat round-trip fallback)`.

Artifacts:

- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_report_candidate_screen_dedup_fast_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_report_candidate_sim_dedup_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round4_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round5_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round5_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round6_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round6_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round7_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round7_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round8_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round8_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round9_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round9_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round10_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round10_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round11_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round11_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round12_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round12_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round13_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round13_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round14_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round14_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round15_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round15_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_weight_search_round15_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_weight_refine_round15_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round16_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round16_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_confirm_round16_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_scale_sweep_round16_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round17_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round17_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round18_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round18_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_confirm_round18_20260629.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round19_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round19_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round20_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round20_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_confirm_round20_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_scale_sweep_round20_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round21_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round21_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_confirm_round21_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round22_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round23_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round23_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_confirm_round23_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_scale_sweep_round23_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round24_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round24_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_confirm_round24_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_scale_sweep_round24_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round25_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round26_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round27_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round27_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_confirm_round27_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round28_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round29_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_validated_combo_screen_round29_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_combo_confirm_round29_20260630.json`
- `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_mt5_validation_intraday_candidates_round30_20260630.json`

## Corrected Screen Results

Top single-candidate screen, before fresh MT5 revalidation:

| candidate | phase | trades | trades/60d | PF | net | best FTMO scale | robust pass | risk note |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `QM5_10816:GDAXI.DWX` | Q03 | 207 | 35.08 | 1.725 | 49998.94 | 1 | 36.8% | Q04 GDAXI later failed |
| `QM5_10672:NDX.DWX` | Q02 | 347 | 113.77 | 1.457 | 39472.58 | 1 | 62.8% | needs higher-phase validation |
| `QM5_10410:GDAXI.DWX` | Q02 | 255 | 83.61 | 1.262 | 27038.85 | 1 | 40.6% | max-loss risk high |
| `QM5_11476:USDJPY.DWX` | Q03 | 255 | 42.15 | 1.516 | 4555.51 | 8 | 21.4% | Q05 later failed |
| `QM5_10468:GDAXI.DWX` | Q03 | 235 | 38.74 | 1.506 | 52728.40 | 1 | 41.0% | Q05 later failed |

Top combinations were statistically better, but mostly depended on Q02/Q03
components. Best raw combo:

- `QM5_10816:GDAXI.DWX`
- `QM5_10468:GDAXI.DWX`
- `QM5_11090:USDJPY.DWX`
- `QM5_10543:EURUSD.DWX`

At equal weights, scale 3 showed `83.6%` robust pass with `4.8%` max-loss
breach in the corrected report-screen simulation. This is not deployable
evidence because two core components are not Q04/Q05 stable.

## Fresh MT5 Validation

Re-ran selected candidates over `2023.01.01` to `2025.12.31` on free terminals:

| candidate | terminal | result | trades | PF | net | DD | summary |
|---|---|---|---:|---:|---:|---:|---|
| `QM5_10672:NDX.DWX` | T8 | PASS | 1873 | 1.04 | 20385.88 | 27478.99 / 26.08% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation\QM5_10672\20260629_112030\summary.json` |
| `QM5_10543:EURUSD.DWX` | T10 | PASS | 603 | 0.95 | -14779.96 | 43601.32 / 43.47% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation\QM5_10543\20260629_112030\summary.json` |
| `QM5_10410:GDAXI.DWX` | T9 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_10410:GDAXI.DWX` | T8 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_10816:GDAXI.DWX` | T10 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_11090:USDJPY.DWX` | T9 | PASS | 713 | 1.11 | 23703.90 | 20487.19 / 19.94% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round2\QM5_11090\20260629_114405\summary.json` |
| `QM5_12450:USDJPY.DWX` | T8 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_1258:GBPJPY.DWX` | T9 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_10582:XAUUSD.DWX` | T10 | PASS | 1143 | 1.18 | 35178.70 | 13025.16 / 9.49% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round3\QM5_10582\20260629_115838\summary.json` |
| `QM5_12450:USDJPY.DWX` | T9 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_1258:GBPJPY.DWX` | T10 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_10816:NDX.DWX` | T8 | PASS | 773 | 1.08 | 25415.25 | 38120.42 / 32.54% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round5\QM5_10816\20260629_132924\summary.json` |
| `QM5_10423:XAUUSD.DWX` | T9 | PASS | 582 | 1.17 | 40093.11 | 22253.38 / 21.38% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round5\QM5_10423\20260629_132924\summary.json` |
| `QM5_12475:XAUUSD.DWX` | T10 | PASS | 755 | 1.27 | 92229.68 | 39603.87 / 35.30% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round5\QM5_12475\20260629_132924\summary.json` |
| `QM5_11476:USDJPY.DWX` | T9 | PASS | 775 | 1.14 | 4275.77 | 3632.75 / 3.61% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round6\QM5_11476\20260629_141313\summary.json` |
| `QM5_10110:GBPUSD.DWX` | T10 | PASS | 660 | 0.95 | -10541.54 | 23112.87 / 20.94% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round6\QM5_10110\20260629_141313\summary.json` |
| `QM5_11114:USDJPY.DWX` | T8 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_10163:NDX.DWX` | T8 | PASS | 257 | 1.64 | 18803.13 | 3761.01 / 3.66% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round7\QM5_10163\20260629_154522\summary.json` |
| `QM5_10594:USDJPY.DWX` | T9 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_11118:USDJPY.DWX` | T10 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_11629:NDX.DWX` | T8 | PASS | 417 | 1.21 | 71252.50 | 30499.79 / 21.53% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round8\QM5_11629\20260629_155657\summary.json` |
| `QM5_10482:NDX.DWX` | T9 | PASS | 1645 | 1.02 | 12235.97 | 39470.19 / 32.75% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round8\QM5_10482\20260629_155657\summary.json` |
| `QM5_10233:NDX.DWX` | T10 | FAIL | 1 | 0.00 | 0.00 | 0.00 | `MIN_TRADES_NOT_MET` |
| `QM5_10132:NDX.DWX` | T9 | PASS | 643 | 1.18 | 37436.68 | 14010.78 / 13.29% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round9\QM5_10132\20260629_161617\summary.json` |
| `QM5_10375:NDX.DWX` | T8 | PASS | 662 | 1.19 | 30706.30 | 14438.29 / 13.15% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round9\QM5_10375\20260629_161616\summary.json` |
| `QM5_10585:XAUUSD.DWX` | T10 | PASS | 722 | 1.25 | 42164.76 | 11716.89 / 10.87% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round9\QM5_10585\20260629_161617\summary.json` |
| `QM5_10477:NDX.DWX` | T8 | PASS | 605 | 0.93 | -14732.28 | 21134.71 / 20.37% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round10\QM5_10477\20260629_170803\summary.json` |
| `QM5_10692:NDX.DWX` | T10 | PASS | 224 | 1.42 | 32140.12 | 10122.73 / 7.87% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round10\QM5_10692\20260629_170804\summary.json` |
| `QM5_12475:NDX.DWX` | T9 | PASS | 691 | 1.23 | 71328.91 | 19233.16 / 10.66% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round10\QM5_12475\20260629_170803\summary.json` |
| `QM5_10590:XAUUSD.DWX` | T10 | PASS | 683 | 1.08 | 16862.17 | 20815.88 / 20.41% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round11\QM5_10590\20260629_172206\summary.json` |
| `QM5_10599:NDX.DWX` | T8 | PASS | 744 | 1.03 | 5806.26 | 26676.30 / 20.44% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round11\QM5_10599\20260629_172206\summary.json` |
| `QM5_10967:NDX.DWX` | T9 | PASS | 265 | 0.93 | -8782.41 | 23383.61 / 22.05% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round11\QM5_10967\20260629_172206\summary.json` |
| `QM5_10440:NDX.DWX` | T8 | PASS | 265 | 1.20 | 35170.43 | 15862.19 / 10.99% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round12\QM5_10440\20260629_173555\summary.json` |
| `QM5_10589:XAUUSD.DWX` | T9 | PASS | 339 | 1.24 | 28832.38 | 8816.90 / 7.79% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round12\QM5_10589\20260629_173555\summary.json` |
| `QM5_10848:XAUUSD.DWX` | T10 | PASS | 502 | 1.38 | 56639.93 | 14633.78 / 12.66% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round12\QM5_10848\20260629_173555\summary.json` |
| `QM5_9996:NDX.DWX` | T8 | PASS | 1245 | 1.01 | 9969.06 | 61252.60 / 36.68% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round13\QM5_9996\20260629_175404\summary.json` |
| `QM5_10469:NDX.DWX` | T9 | PASS | 855 | 1.02 | 8760.92 | 28362.01 / 20.69% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round13\QM5_10469\20260629_175404\summary.json` |
| `QM5_10512:XAUUSD.DWX` | T10 | PASS | 581 | 1.20 | 36916.98 | 10908.58 / 8.46% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round13\QM5_10512\20260629_180433\summary.json` |
| `QM5_10467:XAUUSD.DWX` | T8 | PASS | 197 | 1.19 | 17275.71 | 11347.37 / 11.19% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round14\QM5_10467\20260629_181939\summary.json` |
| `QM5_10700:XAUUSD.DWX` | T9 | PASS | 151 | 1.69 | 49095.99 | 10664.87 / 10.42% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round14\QM5_10700\20260629_181939\summary.json` |
| `QM5_10858:NDX.DWX` | T10 | PASS | 424 | 1.14 | 29820.51 | 16235.38 / 13.24% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round14\QM5_10858\20260629_181939\summary.json` |
| `QM5_10988:XAUUSD.DWX` | T8 | PASS | 495 | 1.23 | 56963.94 | 29737.13 / 27.84% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round15\QM5_10988\20260629_183306\summary.json` |
| `QM5_10702:XAUUSD.DWX` | T9 | PASS | 526 | 1.12 | 34035.36 | 23114.73 / 21.23% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round15\QM5_10702\20260629_183306\summary.json` |
| `QM5_1061:NDX.DWX` | T10 | PASS | 309 | 1.19 | 6751.41 | 3822.82 / 3.46% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round15\QM5_1061\20260629_183306\summary.json` |
| `QM5_12511:XAUUSD.DWX` | T8 | PASS | 94 | 1.59 | 1320.76 | 644.84 / 0.64% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round16\QM5_12511\20260629_202633\summary.json` |
| `QM5_10468:XAUUSD.DWX` | T9 | PASS | 1330 | 0.96 | -30111.52 | 71434.35 / 68.41% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round16\QM5_10468\20260629_202633\summary.json` |
| `QM5_10951:NDX.DWX` | T10 | PASS | 228 | 1.20 | 20474.98 | 12440.20 / 9.79% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round16\QM5_10951\20260629_202633\summary.json` |
| `QM5_10804:NDX.DWX` | T8 | PASS | 220 | 1.31 | 19947.81 | 11975.07 / 9.36% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round17\QM5_10804\20260629_204623\summary.json` |
| `QM5_10150:NDX.DWX` | T9 | PASS | 94 | 1.43 | 8155.39 | 4332.15 / 3.96% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round17\QM5_10150\20260629_204623\summary.json` |
| `QM5_10656:NDX.DWX` | T10 | PASS | 882 | 1.00 | 1526.91 | 29659.88 / 22.66% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round17\QM5_10656\20260629_204623\summary.json` |
| `QM5_10110:NDX.DWX` | T8 | PASS | 372 | 1.11 | 18647.19 | 11047.46 / 8.56% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round18\QM5_10110\20260629_205856\summary.json` |
| `QM5_10194:XAUUSD.DWX` | T10 | PASS | 584 | 1.31 | 73123.84 | 28396.18 / 24.20% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round18\QM5_10194\20260629_205856\summary.json` |
| `QM5_10750:NDX.DWX` | T9 | PASS | 990 | 0.96 | -21602.82 | 57536.52 / 50.67% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round18\QM5_10750\20260629_205856\summary.json` |
| `QM5_1638:XAUUSD.DWX` | T8 | PASS | 2506 | 1.02 | 26919.13 | 53451.14 / 49.83% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round19\QM5_1638\20260630_042757\summary.json` |
| `QM5_10471:NDX.DWX` | T9 | REPORT_COPIED | 2758 | 0.98 | -19312.96 | 80791.95 / 53.03% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round19\QM5_10471\20260630_042757\raw\run_01\report.htm` |
| `QM5_10490:XAUUSD.DWX` | T10 | PASS | 562 | 0.72 | -58821.81 | 62048.36 / 61.41% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round19\QM5_10490\20260630_042757\summary.json` |
| `QM5_10286:XTIUSD.DWX` | T8 | PASS | 189 | 1.38 | 26656.50 | 10999.58 / 10.26% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round20\QM5_10286\20260630_044953\summary.json` |
| `QM5_10531:USDJPY.DWX` | T9 | PASS | 1382 | 0.90 | -8047.74 | 11058.50 / 10.93% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round20\QM5_10531\20260630_044953\summary.json` |
| `QM5_11340:EURUSD.DWX` | T10 | PASS | 210 | 1.32 | 17907.69 | 10546.45 / 8.97% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round20\QM5_11340\20260630_044953\summary.json` |
| `QM5_1142:USDJPY.DWX` | T8 | PASS | 463 | 0.90 | -3247.74 | 6845.52 / 6.75% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round21\QM5_1142\20260630_051112\summary.json` |
| `QM5_10715:USDJPY.DWX` | T9 | PASS | 468 | 1.19 | 10947.94 | 3939.77 / 3.46% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round21\QM5_10715\20260630_051112\summary.json` |
| `QM5_9936:USDJPY.DWX` | T10 | PASS | 445 | 1.21 | 7397.83 | 5087.49 / 5.06% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round21\QM5_9936\20260630_051112\summary.json` |
| `QM5_10551:USDJPY.DWX` | T8/T9 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS`; retry also failed |
| `QM5_10469:USDJPY.DWX` | T9 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_10596:USDJPY.DWX` | T10 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_10847:GBPUSD.DWX` | T8 | PASS | 272 | 1.32 | 45905.23 | 14179.07 / 12.92% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round23\QM5_10847\20260630_060004\summary.json` |
| `QM5_1120:GBPUSD.DWX` | T9 | PASS | 470 | 1.07 | 18785.00 | 29376.74 / 24.85% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round23\QM5_1120\20260630_060004\summary.json` |
| `QM5_9952:EURUSD.DWX` | T10 | PASS | 2239 | 0.87 | -38522.85 | 59006.89 / 49.33% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round23\QM5_9952\20260630_060004\summary.json` |
| `QM5_10113:GBPUSD.DWX` | T8 | PASS | 69 | 0.24 | -22204.51 | 22850.74 / 22.85% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round24\QM5_10113\20260630_062040\summary.json` |
| `QM5_10476:USDCAD.DWX` | T10 | PASS | 73 | 1.39 | 13365.93 | 12070.18 / 10.69% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round24\QM5_10476\20260630_062040\summary.json` |
| `QM5_10712:GBPUSD.DWX` | T9 | PASS | 666 | 0.89 | -54934.92 | 58160.74 / 56.34% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round24\QM5_10712\20260630_062039\summary.json` |
| `QM5_10215:GBPJPY.DWX` | T9 | PASS | 275 | 0.73 | -9769.31 | 10452.31 / 10.45% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round25\QM5_10215\20260630_082337\summary.json` |
| `QM5_10540:EURUSD.DWX` | T8 | PASS | 1205 | 0.81 | -71553.11 | 79864.37 / 73.98% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round25\QM5_10540\20260630_082337\summary.json` |
| `QM5_10163:USDJPY.DWX` | T8 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_1241:USDJPY.DWX` | T9 | FAIL | 0 | 0.00 | 0.00 | 0.00 | `NO_HISTORY`, `INCOMPLETE_RUNS` |
| `QM5_10352:USDJPY.DWX` | T10 | PASS | 1171 | 0.96 | -2302.06 | 9967.06 / 9.81% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round26\QM5_10352\20260630_084815\summary.json` |
| `QM5_10375:SP500.DWX` | T8 | PASS | 641 | 1.11 | 17966.69 | 8418.79 / 8.35% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round27\QM5_10375\20260630_090000\summary.json` |
| `QM5_10163:SP500.DWX` | T9 | PASS | 257 | 1.14 | 3721.39 | 2986.77 / 2.81% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round27\QM5_10163\20260630_090000\summary.json` |
| `QM5_10595:USDJPY.DWX` | T10 | PASS | 674 | 1.03 | 3096.93 | 9694.97 / 8.77% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round27\QM5_10595\20260630_090001\summary.json` |
| `QM5_11132:SP500.DWX` | T8 | PASS | 32 | 2.13 | 4991.95 | 1551.46 / 1.47% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round28\QM5_11132\20260630_093605\summary.json` |
| `QM5_10300:SP500.DWX` | T9 | PASS | 197 | 0.90 | -6270.20 | 17711.28 / 17.12% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round28\QM5_10300\20260630_093606\summary.json` |
| `QM5_10192:WS30.DWX` | T10 | PASS | 179 | 0.65 | -75330.35 | 70239.64 / 64.30% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round28\QM5_10192\20260630_093606\summary.json` |
| `QM5_11165:AUDCAD.DWX` | T8 | PASS | 53 | 1.55 | 2473.76 | 1744.17 / 1.72% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round29\QM5_11165\20260630_105406\summary.json` |
| `QM5_11421:EURUSD.DWX` | T9 | PASS | 34 | 1.38 | 3326.07 | 2826.04 / 2.75% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round29\QM5_11421\20260630_105406\summary.json` |
| `QM5_10939:GBPUSD.DWX` | T10 | PASS | 34 | 1.40 | 4927.92 | 4663.09 / 4.63% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round29\QM5_10939\20260630_105406\summary.json` |
| `QM5_10041:GBPUSD.DWX` | T8 | PASS | 1371 | 0.87 | -3926.82 | 9356.05 / 9.25% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round30\QM5_10041\20260630_110828\summary.json` |
| `QM5_11708:AUDUSD.DWX` | T9 | PASS | 32 | 0.52 | -2274.75 | 3474.74 / 3.47% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round30\QM5_11708\20260630_110828\summary.json` |
| `QM5_10300:XTIUSD.DWX` | T10 | PASS | 277 | 0.93 | -4306.18 | 13218.91 / 12.93% | `D:\QM\reports\prop_ftmo_candidates_20260629\validation_round30\QM5_10300\20260630_110828\summary.json` |

All `NO_HISTORY` rows produced M0/1970 reports with `EMPTY_EXPERT`,
`EMPTY_SYMBOL`, `BARS_ZERO`, and `HISTORY_CONTEXT_INVALID`. These are infra/data
failures, not strategy performance verdicts.

FTMO simulation from the fresh MT5 reports:

| candidate | scale | robust pass | daily-loss breach | max-loss breach | target-not-reached |
|---|---:|---:|---:|---:|---:|
| `QM5_10672:NDX.DWX` | 0.75 | 3.0% | 0.0% | 4.8% | 93.5% |
| `QM5_10543:EURUSD.DWX` | 0.75 | 0.6% | 0.0% | 3.1% | 96.4% |
| `QM5_11090:USDJPY.DWX` | 0.75 | 1.5% | 0.0% | 0.5% | 98.0% |
| `QM5_10582:XAUUSD.DWX` | 1.50 | 8.7% | 0.0% | 4.8% | 86.5% |
| `QM5_10816:NDX.DWX` | 0.50 | 0.7% | 0.0% | 0.9% | 99.1% |
| `QM5_10423:XAUUSD.DWX` | 0.75 | 3.2% | 0.0% | 0.7% | 96.2% |
| `QM5_12475:XAUUSD.DWX` | 0.50 | 2.6% | 0.0% | 0.8% | 97.1% |
| `QM5_11476:USDJPY.DWX` | 5.00 | 1.5% | 0.0% | 0.9% | 97.4% |
| `QM5_10110:GBPUSD.DWX` | 0.50 | 0.0% | 0.0% | 0.0% | 100.0% |
| `QM5_10163:NDX.DWX` | 4.00 | 11.3% | 0.0% | 1.9% | 86.8% |
| `QM5_11629:NDX.DWX` | 0.25 | 0.4% | 0.0% | 0.0% | 99.6% |
| `QM5_10482:NDX.DWX` | 0.50 | 0.8% | 0.0% | 2.3% | 96.9% |
| `QM5_10132:NDX.DWX` | 1.00 | 2.9% | 0.0% | 2.6% | 91.9% |
| `QM5_10375:NDX.DWX` | 1.50 | 5.3% | 0.0% | 3.1% | 91.6% |
| `QM5_10585:XAUUSD.DWX` | 1.50 | 8.6% | 0.0% | 3.2% | 88.2% |
| `QM5_10477:NDX.DWX` | 1.00 | 0.4% | 0.0% | 2.9% | 96.6% |
| `QM5_10692:NDX.DWX` | 1.50 | 3.3% | 0.0% | 0.7% | 94.4% |
| `QM5_12475:NDX.DWX` | 0.75 | 7.6% | 0.0% | 4.3% | 85.4% |
| `QM5_10590:XAUUSD.DWX` | 1.00 | 1.1% | 0.0% | 2.2% | 96.7% |
| `QM5_10599:NDX.DWX` | 1.00 | 0.7% | 0.0% | 2.5% | 96.1% |
| `QM5_10967:NDX.DWX` | 0.25 | 0.0% | 0.0% | 0.0% | 100.0% |
| `QM5_10440:NDX.DWX` | 1.00 | 3.1% | 0.0% | 2.0% | 94.9% |
| `QM5_10589:XAUUSD.DWX` | 1.25 | 1.6% | 0.0% | 2.3% | 96.1% |
| `QM5_10848:XAUUSD.DWX` | 1.50 | 18.1% | 0.0% | 5.0% | 75.7% |
| `QM5_9996:NDX.DWX` | 0.25 | 0.2% | 0.0% | 1.3% | 98.3% |
| `QM5_10469:NDX.DWX` | 0.50 | 0.4% | 0.0% | 0.9% | 98.5% |
| `QM5_10512:XAUUSD.DWX` | 1.25 | 7.2% | 0.0% | 3.9% | 88.9% |
| `QM5_10467:XAUUSD.DWX` | 1.50 | 2.3% | 0.0% | 3.8% | 93.9% |
| `QM5_10700:XAUUSD.DWX` | 1.50 | 9.8% | 0.0% | 1.3% | 88.9% |
| `QM5_10858:NDX.DWX` | 1.00 | 4.2% | 0.0% | 3.9% | 91.2% |
| `QM5_10988:XAUUSD.DWX` | 1.00 | 8.5% | 0.0% | 3.8% | 86.2% |
| `QM5_10702:XAUUSD.DWX` | 0.75 | 2.6% | 0.0% | 2.0% | 93.5% |
| `QM5_1061:NDX.DWX` | 4.00 | 2.9% | 0.0% | 3.9% | 91.8% |
| `QM5_12511:XAUUSD.DWX` | 0.25 | 0.0% | 0.0% | 0.0% | 100.0% |
| `QM5_10468:XAUUSD.DWX` | 0.25 | 0.0% | 0.0% | 0.0% | 100.0% |
| `QM5_10951:NDX.DWX` | 1.50 | 2.7% | 0.0% | 2.5% | 93.0% |
| `QM5_10804:NDX.DWX` | 2.00 | 6.3% | 0.0% | 5.0% | 88.7% |
| `QM5_10150:NDX.DWX` | 4.00 | 2.7% | 0.0% | 4.2% | 92.4% |
| `QM5_10656:NDX.DWX` | 0.75 | 0.5% | 0.0% | 2.8% | 96.7% |
| `QM5_10110:NDX.DWX` | 1.00 | 1.4% | 0.0% | 2.0% | 95.2% |
| `QM5_10194:XAUUSD.DWX` | 0.75 | 8.6% | 0.0% | 2.9% | 88.5% |
| `QM5_10750:NDX.DWX` | 0.50 | 0.3% | 0.0% | 4.5% | 94.8% |
| `QM5_1638:XAUUSD.DWX` | 0.25 | 0.0% | 0.0% | 0.0% | 100.0% |
| `QM5_10471:NDX.DWX` | 0.25 | 0.0% | 0.0% | 0.5% | 99.5% |
| `QM5_10490:XAUUSD.DWX` | 0.25 | 0.0% | 0.0% | 1.1% | 98.9% |
| `QM5_10286:XTIUSD.DWX` | 1.50 | 4.5% | 0.0% | 3.3% | 93.2% |
| `QM5_10531:USDJPY.DWX` | 3.50 | 0.0% | 0.0% | 4.1% | 96.5% |
| `QM5_11340:EURUSD.DWX` | 2.25 | 4.6% | 0.0% | 3.9% | 93.5% |
| `QM5_1142:USDJPY.DWX` | 5.00 | 0.5% | 0.0% | 2.1% | 97.7% |
| `QM5_10715:USDJPY.DWX` | 3.50 | 5.9% | 0.0% | 3.6% | 90.5% |
| `QM5_9936:USDJPY.DWX` | 5.00 | 3.6% | 0.0% | 1.3% | 95.2% |
| `QM5_10847:GBPUSD.DWX` | 1.00 | 4.5% | 0.0% | 1.8% | 94.2% |
| `QM5_1120:GBPUSD.DWX` | 0.75 | 1.4% | 0.0% | 2.1% | 96.8% |
| `QM5_9952:EURUSD.DWX` | 0.50 | 0.0% | 0.0% | 0.3% | 99.9% |
| `QM5_10113:GBPUSD.DWX` | 1.00 | 0.0% | 0.0% | 2.9% | 99.9% |
| `QM5_10476:USDCAD.DWX` | 1.50 | 0.4% | 0.0% | 2.2% | 98.6% |
| `QM5_10712:GBPUSD.DWX` | 0.50 | 0.0% | 0.0% | 3.8% | 96.2% |
| `QM5_10215:GBPJPY.DWX` | 4.00 | 0.0% | 0.0% | 3.5% | 97.2% |
| `QM5_10540:EURUSD.DWX` | 0.50 | 0.0% | 0.0% | 1.4% | 98.9% |
| `QM5_10352:USDJPY.DWX` | 5.00 | 1.7% | 0.0% | 8.8% | 89.9% |
| `QM5_10375:SP500.DWX` | 4.50 | 33.5% | 11.9% | 48.5% | 9.0% |
| `QM5_10163:SP500.DWX` | 5.00 | 2.3% | 25.1% | 1.1% | 72.0% |
| `QM5_10595:USDJPY.DWX` | 5.00 | 17.0% | 28.1% | 25.3% | 31.8% |
| `QM5_11132:SP500.DWX` | 5.00 | 0.1% | 12.6% | 0.0% | 87.5% |
| `QM5_10300:SP500.DWX` | 4.75 | 9.7% | 15.5% | 29.2% | 49.5% |
| `QM5_10192:WS30.DWX` | 2.00 | 7.3% | 32.7% | 52.8% | 12.8% |
| `QM5_11165:AUDCAD.DWX` | 0.25 | 0.0% | 0.0% | 0.0% | 100.0% |
| `QM5_11421:EURUSD.DWX` | 5.00 | 0.4% | 24.4% | 0.0% | 75.3% |
| `QM5_10939:GBPUSD.DWX` | 4.75 | 3.9% | 6.1% | 1.6% | 89.8% |
| `QM5_10041:GBPUSD.DWX` | 4.75 | 0.1% | 0.0% | 5.1% | 95.8% |
| `QM5_11708:AUDUSD.DWX` | 0.25 | 0.0% | 0.0% | 0.0% | 100.0% |
| `QM5_10300:XTIUSD.DWX` | 5.00 | 9.2% | 4.6% | 31.6% | 55.3% |

`QM5_10543:EURUSD.DWX` is rejected by the 2023-2025 validation despite the
earlier Q03 screen. `QM5_10672:NDX.DWX` is active enough, but its full-window
edge is too weak for a serious 60-day sprint candidate.

The Round 5 singles are profitable but drawdown-heavy. At non-breaching scale,
they remain target-starved over a 60-calendar-day two-step window.

## Validated Combo Screen

Validated positive candidates were combined:

- `QM5_10672:NDX.DWX`
- `QM5_11090:USDJPY.DWX`
- `QM5_10582:XAUUSD.DWX`
- `QM5_10816:NDX.DWX`
- `QM5_10423:XAUUSD.DWX`
- `QM5_12475:XAUUSD.DWX`
- `QM5_11476:USDJPY.DWX`
- `QM5_10163:NDX.DWX`
- `QM5_11629:NDX.DWX`
- `QM5_10482:NDX.DWX`
- `QM5_10132:NDX.DWX`
- `QM5_10375:NDX.DWX`
- `QM5_10585:XAUUSD.DWX`
- `QM5_10692:NDX.DWX`
- `QM5_12475:NDX.DWX`
- `QM5_10440:NDX.DWX`
- `QM5_10589:XAUUSD.DWX`
- `QM5_10848:XAUUSD.DWX`
- `QM5_10512:XAUUSD.DWX`
- `QM5_10700:XAUUSD.DWX`
- `QM5_10702:XAUUSD.DWX`
- `QM5_10988:XAUUSD.DWX`
- `QM5_10951:NDX.DWX`
- `QM5_10194:XAUUSD.DWX`
- `QM5_10110:NDX.DWX`
- `QM5_10286:XTIUSD.DWX`
- `QM5_11340:EURUSD.DWX`
- `QM5_10715:USDJPY.DWX`
- `QM5_9936:USDJPY.DWX`
- `QM5_10847:GBPUSD.DWX`
- `QM5_1120:GBPUSD.DWX`
- `QM5_10476:USDCAD.DWX`

Best combo outcomes:

| combo | weights | scale | robust pass | max-loss breach | target-not-reached |
|---|---|---:|---:|---:|---:|
| `QM5_10951:NDX.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` + `QM5_10194:XAUUSD.DWX` + `QM5_10286:XTIUSD.DWX` + `QM5_9936:USDJPY.DWX` + `QM5_10847:GBPUSD.DWX` + `QM5_10476:USDCAD.DWX` | 4.5/25.2/11.5/9.3/5.6/11.6/5.8/5.5/2.5/4.6/2.8/8.0/3.0 | 5.90 | 57.0% | 5.0% | 38.0% |
| same as above, aggressive scale | 4.5/25.2/11.5/9.3/5.6/11.6/5.8/5.5/2.5/4.6/2.8/8.0/3.0 | 6.00 | 57.8% | 5.4% | 36.9% |
| `QM5_10951:NDX.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` + `QM5_10194:XAUUSD.DWX` + `QM5_10286:XTIUSD.DWX` + `QM5_9936:USDJPY.DWX` + `QM5_10847:GBPUSD.DWX` | 4.5/28.2/11.5/9.3/5.6/11.6/5.8/5.5/2.5/4.6/2.8/8.0 | 5.80 | 56.5% | 4.9% | 38.5% |
| same as above, aggressive scale | 4.5/28.2/11.5/9.3/5.6/11.6/5.8/5.5/2.5/4.6/2.8/8.0 | 5.90 | 57.2% | 5.3% | 37.4% |
| `QM5_10951:NDX.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` + `QM5_10194:XAUUSD.DWX` + `QM5_10286:XTIUSD.DWX` + `QM5_9936:USDJPY.DWX` | 4.9/30.7/12.5/10.1/6.1/12.6/6.3/6.0/2.8/5.0/3.0 | 5.30 | 50.1% | 4.9% | 44.7% |
| Round 21 backup: trim `QM5_10163:NDX.DWX` 2pct to `QM5_10715:USDJPY.DWX` | 4.9/31.7/12.5/10.1/6.1/12.6/6.3/6.0/2.8/5.0/2.0 | 5.20 | 49.7% | 4.7% | 45.8% |
| `QM5_10951:NDX.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` + `QM5_10194:XAUUSD.DWX` + `QM5_10286:XTIUSD.DWX` | 4.9/33.7/12.5/10.1/6.1/12.6/6.3/6.0/2.8/5.0 | 5.20 | 49.7% | 4.8% | 45.4% |
| same as above, aggressive scale | 4.9/33.7/12.5/10.1/6.1/12.6/6.3/6.0/2.8/5.0 | 5.30 | 50.6% | 5.2% | 44.1% |
| Round 20 screen: lead + `QM5_10286:XTIUSD.DWX` 2% | lead scaled + 2% | 5.00 | 48.5% | 4.6% | 47.4% |
| `QM5_10951:NDX.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` + `QM5_10194:XAUUSD.DWX` | 5.2/35.5/13.2/10.6/6.4/13.3/6.6/6.3/2.9 | 4.90 | 48.0% | 4.9% | 46.9% |
| same as above, aggressive scale | 5.2/35.5/13.2/10.6/6.4/13.3/6.6/6.3/2.9 | 5.00 | 49.0% | 5.4% | 45.5% |
| Round 19 screen: lead + `QM5_1638:XAUUSD.DWX` 2% | lead scaled + 2% | 5.00 | 48.8% | 6.9% | 42.9% |
| Round 19 screen: lead + `QM5_10471:NDX.DWX` 1% | lead scaled + 1% | 4.80 | 45.9% | 4.9% | 48.8% |
| Round 19 screen: lead + `QM5_10490:XAUUSD.DWX` 1% | lead scaled + 1% | 4.80 | 45.6% | 4.9% | 48.9% |
| `QM5_10951:NDX.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` | 5.3/36.5/13.6/11.0/6.6/13.7/6.8/6.5 | 4.90 | 46.3% | 4.8% | 48.3% |
| same as above, aggressive scale | 5.3/36.5/13.6/11.0/6.6/13.7/6.8/6.5 | 5.00 | 47.2% | 5.1% | 46.9% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` | 5.3/36.5/13.6/11.0/6.6/13.7/6.8/6.5 | 4.00 | 40.2% | 3.9% | 55.9% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` | 6.9/38.5/17.2/11.8/2.5/15.8/2.4/4.9 | 4.00 | 40.2% | 4.1% | 55.2% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` | 10/45/10/10/5/10/10 | 4.00 | 39.7% | 5.0% | 55.1% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10988:XAUUSD.DWX` | 10/45/15/10/5/10/5 | 4.00 | 38.3% | 5.0% | 53.5% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` + `QM5_10702:XAUUSD.DWX` | 10/45/15/10/5/10/5 | 4.00 | 37.1% | 4.7% | 56.4% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` | 10/50/15/10/5/10 | 4.00 | 35.5% | 4.8% | 57.6% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10700:XAUUSD.DWX` | 10/50/20/10/5/5 | 4.00 | 35.3% | 4.6% | 58.9% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10700:XAUUSD.DWX` | 10/55/20/10/5 | 4.00 | 32.8% | 4.3% | 62.9% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` | 10/55/20/10/5 | 4.00 | 32.7% | 4.5% | 60.0% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` + `QM5_10589:XAUUSD.DWX` | 10/55/15/10/5/5 | 4.00 | 32.4% | 4.7% | 61.1% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10848:XAUUSD.DWX` | 10/60/15/10/5 | 4.00 | 32.3% | 4.3% | 62.7% |
| `QM5_10163:NDX.DWX` + `QM5_10848:XAUUSD.DWX` | 80/20 | 5.00 | 32.0% | 3.8% | 62.5% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` + `QM5_10512:XAUUSD.DWX` | 10/55/20/10/5 | 4.00 | 31.2% | 4.1% | 62.7% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` | 10/60/20/10 | 4.00 | 30.8% | 4.6% | 64.2% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_10692:NDX.DWX` | 15/60/15/10 | 4.00 | 29.6% | 4.7% | 64.4% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` | 15/70/15 | 4.00 | 28.6% | 4.6% | 66.2% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` + `QM5_12475:NDX.DWX` | 10/65/15/10 | 4.00 | 28.3% | 3.9% | 65.2% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10585:XAUUSD.DWX` + `QM5_10375:NDX.DWX` | 10/60/20/10 | 4.00 | 27.3% | 4.2% | 66.3% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10585:XAUUSD.DWX` | 10/70/20 | 4.00 | 25.2% | 4.4% | 67.2% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_10585:XAUUSD.DWX` + `QM5_10375:NDX.DWX` | 20/55/15/10 | 3.00 | 23.7% | 4.4% | 70.6% |
| `QM5_10163:NDX.DWX` + `QM5_10375:NDX.DWX` | 80/20 | 5.00 | 22.1% | 4.8% | 70.9% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` | 20/80 | 3.00 | 19.0% | 3.6% | 76.1% |
| all eight positive validated candidates | equal | 2.50 | 18.9% | 4.7% | 76.3% |
| `QM5_10423:XAUUSD.DWX` + `QM5_10163:NDX.DWX` | 20/80 | 4.00 | 18.6% | 4.4% | 77.0% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_11629:NDX.DWX` | 20/60/20 | 2.00 | 18.1% | 4.4% | 77.2% |
| `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX` + `QM5_11629:NDX.DWX` | 20/70/10 | 2.50 | 17.5% | 4.5% | 74.4% |
| `QM5_10582:XAUUSD.DWX` + `QM5_10163:NDX.DWX` | 20/80 | 4.00 | 15.2% | 2.5% | 82.3% |
| `QM5_10582:XAUUSD.DWX` + `QM5_12475:XAUUSD.DWX` + `QM5_11476:USDJPY.DWX` | 10/70/20 | 1.00 | 13.9% | 4.7% | 81.4% |
| all seven positive validated candidates | equal | 2.00 | 12.4% | 3.1% | 84.5% |
| `QM5_10423:XAUUSD.DWX` + `QM5_12475:XAUUSD.DWX` + `QM5_11476:USDJPY.DWX` | 20/60/20 | 1.00 | 12.2% | 3.1% | 84.3% |
| `QM5_10582:XAUUSD.DWX` + `QM5_11476:USDJPY.DWX` | 80/20 | 2.00 | 12.0% | 5.0% | 83.0% |
| `QM5_12475:XAUUSD.DWX` + `QM5_11476:USDJPY.DWX` | 20/80 | 3.00 | 11.2% | 3.4% | 85.4% |
| `QM5_10423:XAUUSD.DWX` + `QM5_12475:XAUUSD.DWX` | 20/80 | 0.75 | 10.3% | 4.9% | 87.6% |
| `QM5_10582:XAUUSD.DWX` + `QM5_10423:XAUUSD.DWX` + `QM5_12475:XAUUSD.DWX` | 10/10/80 | 0.75 | 9.4% | 4.2% | 88.5% |
| `QM5_10582:XAUUSD.DWX` + `QM5_12475:XAUUSD.DWX` | 20/80 | 0.75 | 9.2% | 3.3% | 89.2% |
| `QM5_10582:XAUUSD.DWX` | 100% | 1.50 | 8.7% | 4.8% | 86.5% |
| `QM5_12475:XAUUSD.DWX` + `QM5_11090:USDJPY.DWX` | 50/50 | 1.00 | 8.6% | 2.7% | 89.0% |

Round 7 improves the lead by adding `QM5_10163:NDX.DWX`. The best focused mix
is `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX`, weighted 20/80, with `19.0%`
robust pass and `3.6%` max-loss breach. This is still a research candidate, not
a production-ready prop challenge module.

Round 8 validates two more NDX candidates, but neither improves the lead.
`QM5_11629:NDX.DWX` has enough net but too much drawdown concentration at useful
scale. `QM5_10482:NDX.DWX` is active, but its full-window PF is only `1.02`.

Round 9 is the largest improvement so far. `QM5_10375:NDX.DWX` is weak as a
single, but as an overlay to the `QM5_12475:XAUUSD.DWX` + `QM5_10163:NDX.DWX`
lead it lifts robust pass from `19.0%` to `28.6%` while keeping max-loss breach
under `5%`. `QM5_10585:XAUUSD.DWX` is a usable secondary overlay, but did not
beat the top 3-leg mix.

Round 10 adds another small improvement. `QM5_12475:NDX.DWX` lifts the top
basket to `30.8%` robust pass. `QM5_10692:NDX.DWX` validates cleanly with PF
`1.42`, but its lower frequency makes it less useful than `QM5_12475:NDX.DWX`
inside the sprint basket. `QM5_10477:NDX.DWX` is rejected despite MT5 PASS
because full-window PF is `0.93`.

Round 11 does not improve the lead. `QM5_10590:XAUUSD.DWX` and
`QM5_10599:NDX.DWX` validate, but their full-window PF/drawdown profile is too
weak for the sprint basket. `QM5_10967:NDX.DWX` is rejected despite MT5 PASS
because full-window PF is `0.93`.

Round 12 improves the lead again. `QM5_10848:XAUUSD.DWX` is the useful new
overlay: as a single it reaches `18.1%` robust pass, and as a 5% leg in the
current basket it lifts the lead to `32.7%` robust pass with `4.5%` max-loss
breach. `QM5_10589:XAUUSD.DWX` and `QM5_10440:NDX.DWX` validate, but they do
not materially improve the top basket.

Round 13 does not improve the lead. `QM5_10512:XAUUSD.DWX` validates with a
usable single profile (`7.2%` robust pass), but replacing the `QM5_10848`
overlay drops the basket to `31.2%`. `QM5_9996:NDX.DWX` and
`QM5_10469:NDX.DWX` validate mechanically, but their full-window PF is only
`1.01`/`1.02`, so they are rejected for the sprint basket.

Round 14 improves the lead. `QM5_10700:XAUUSD.DWX` has low frequency but a
strong enough edge (`PF 1.69`) to work as a 5-10% XAU overlay. The best basket
now reaches `35.5%` robust pass with `4.8%` max-loss breach. `QM5_10467` and
`QM5_10858` validate, but they do not beat the new `QM5_10700` overlay mix.

Round 15 improves the lead again. `QM5_10702:XAUUSD.DWX` is weak as a single,
but a 5-10% allocation improves the basket distribution. The aggressive top
case reaches `39.7%` robust pass, but sits exactly at the `5.0%` max-loss
research guardrail. The more conservative `QM5_10702` 5% overlay is `37.1%`
robust pass with `4.7%` max-loss breach. `QM5_10988:XAUUSD.DWX` is also usable
as a backup overlay, while `QM5_1061:NDX.DWX` does not improve the lead.

Round 15 weight search improves the same validated leg set without adding new
EAs. A 327-case random/hand search around the Round 15 lead, confirmed with the
standard 1000-run simulation, finds an 8-leg mix at `40.2%` robust pass with
only `3.9%` max-loss breach. This is the cleanest research lead so far, though
still target-starved in `55.9%` of block-bootstrap paths.

A tighter local Round 15 weight refinement did not improve the confirmed lead.
Its 250-run screen candidates did not hold up in the 1000-run confirmation and
fell back to Scale 3.0, so the refinement is recorded but not promoted.

Round 16 adds the strongest basket improvement so far. `QM5_10951:NDX.DWX` is
weak as a single, but replacing the smallest old XAU sleeve
(`QM5_12475:XAUUSD.DWX`) with `QM5_10951:NDX.DWX` materially improves the
validated basket. A 5-seed confirmation with 5000 runs per seed shows the
Scale 4.9 version at minimum `46.3%` robust pass and maximum `4.84%` max-loss
breach. Scale 5.0 is stronger at minimum `47.2%` robust pass but breaches the
research guardrail in two seeds (`max 5.12%`). `QM5_10468:XAUUSD.DWX` is
rejected despite MT5 PASS because the full-window PF is `0.96` and DD is
`68.41%`. `QM5_12511:XAUUSD.DWX` is too slow/small to matter for this sprint.

Round 17 does not improve the confirmed Round 16 lead. `QM5_10804:NDX.DWX` and
`QM5_10150:NDX.DWX` validate and remain backup research legs, but neither
improves the Scale 4.9 basket. `QM5_10656:NDX.DWX` is rejected for this sprint
use case because the full-window PF is effectively flat (`1.00`) despite high
trade count.

Round 18 improves the confirmed lead by adding `QM5_10194:XAUUSD.DWX` as a
small XAU sleeve. The 9-leg Scale 4.9 mix confirms across five 5000-run seeds at
minimum `48.0%` robust pass, mean `48.4%`, and maximum `4.86%` max-loss breach.
Scale 5.0 reaches minimum `49.0%` robust pass but is aggressive only because the
max-loss breach reaches `5.4%`. `QM5_10110:NDX.DWX` validates and stays a backup
leg, while `QM5_10750:NDX.DWX` is rejected because its full-window PF is `0.96`
and net is negative.

Round 19 does not improve the confirmed Round 18 lead. `QM5_1638:XAUUSD.DWX`
validates mechanically with very high trade count, but the full-window edge is
too thin (`PF 1.02`) and DD is too large (`49.83%`) for a sprint leg. The best
screened addition to the lead improves target coverage only at breachy Scale
5.0 (`6.9%` max-loss breach). `QM5_10471:NDX.DWX` and
`QM5_10490:XAUUSD.DWX` are rejected because both lose over the full validation
window. The `QM5_10471` T9 run exported a stable MT5 report, but the terminal
wrapper hung on shutdown; the report was copied manually and parsed into the
Round 19 validation artifact.

Round 20 produces the first confirmed improvement after Round 18. `QM5_10286`
on `XTIUSD.DWX` is too slow as a standalone sprint EA, but it is useful as a
small commodity sleeve. A 5% allocation to `QM5_10286:XTIUSD.DWX`, with the
Round 18 lead scaled down to 95%, confirms across five 5000-run seeds at Scale
5.2 with minimum `49.68%` robust pass, mean `50.48%`, maximum `4.76%` max-loss
breach, and `45.42%` mean target-not-reached. Scale 5.3 and above is aggressive
only because max-loss breach exceeds the `5%` research guardrail. `QM5_11340`
on `EURUSD.DWX` validates and remains a secondary diversification leg, but did
not beat the XTI overlay. `QM5_10531:USDJPY.DWX` is rejected despite high trade
count because the full-window MT5 report loses (`PF 0.90`, `-8047.74` net).

Round 21 adds a small confirmed USDJPY improvement. `QM5_9936:USDJPY.DWX` is
not strong enough as a standalone sprint EA, but shifting 3 percentage points
from the large `QM5_10163:NDX.DWX` sleeve into `QM5_9936:USDJPY.DWX` improves
the confirmed clean lead to Scale 5.3 with minimum `50.12%` robust pass, mean
`50.99%`, maximum `4.86%` max-loss breach, and `44.70%` mean
target-not-reached. `QM5_10715:USDJPY.DWX` validates and is a backup USDJPY
diversifier, but its best confirmed basket variant only marginally improves the
old lead. `QM5_1142:USDJPY.DWX` is rejected because the full-window report loses
(`PF 0.90`, `-3247.74` net).

Round 22 is infrastructure-blocked, not a strategy verdict. `QM5_10551`,
`QM5_10469`, and `QM5_10596` all produced M0/1970 `NO_HISTORY` reports on
USDJPY despite valid-looking tester setup; a sequential retry of `QM5_10551` on
T9 failed the same way. Keep these as retry candidates only after the T8-T10
USDJPY synchronization issue is cleared.

Round 23 is the largest confirmed improvement so far. `QM5_10847:GBPUSD.DWX`
validates as a quality but not standalone-sufficient GBPUSD leg, and an 8%
overlay on the Round 21 lead confirms cleanly across five 5000-run seeds. The
Scale 5.8 sweep reaches minimum `56.52%` robust pass, mean `57.08%`, maximum
`4.94%` max-loss breach, and `38.55%` mean target-not-reached. Scale 5.9 is
aggressive only because max-loss breach rises to `5.26%`. `QM5_1120:GBPUSD.DWX`
validates but does not improve the confirmed lead. `QM5_9952:EURUSD.DWX` is
rejected for sprint use because the full-window report loses (`PF 0.87`,
`-38522.85` net).

Round 24 adds a small confirmed USDCAD improvement, but it is close to the
guardrail. `QM5_10476:USDCAD.DWX` is slow as a single, but shifting 3 percentage
points from `QM5_10163:NDX.DWX` into `QM5_10476:USDCAD.DWX` confirms at Scale
5.9 with minimum `57.04%` robust pass, mean `57.78%`, maximum `4.96%`
max-loss breach, and `38.04%` mean target-not-reached. Scale 6.0 is aggressive
only because max-loss breach rises to `5.44%`. `QM5_10113:GBPUSD.DWX` and
`QM5_10712:GBPUSD.DWX` are rejected because both lose over the 2023-2025
validation window.

Round 25 does not improve the lead and produces no combo screen. Both remaining
non-USDJPY screen candidates validate mechanically, but lose over the full
2023-2025 MT5 window after worst-case commission: `QM5_10215:GBPJPY.DWX`
finishes at `PF 0.73` and `-9769.31` net, while `QM5_10540:EURUSD.DWX` finishes
at `PF 0.81` and `-71553.11` net.

Round 26 also does not improve the lead and produces no combo screen.
`QM5_10163:USDJPY.DWX` and `QM5_1241:USDJPY.DWX` hit the same M0/1970
`NO_HISTORY` path seen in Round 22, so those are infra failures rather than
strategy verdicts. `QM5_10352:USDJPY.DWX` validates mechanically with `1171`
trades, but the full-window report loses after worst-case commission (`PF
0.96`, `-2302.06` net). Its best single simulation is only `1.7%` robust pass
and is already breachy (`8.8%` max-loss breach), so it is not worth adding to
the current Basket.

Round 27 finds a useful backup idea but does not beat the current lead.
`QM5_10375:SP500.DWX` validates with a real edge (`PF 1.11`, `17966.69` net)
and improves some Seed-0 screens as a small SP500 sleeve. The 5-seed
confirmation does not hold above the Round 24 benchmark: the best clean
confirmed variant, shifting 1 percentage point from `QM5_10847:GBPUSD.DWX` to
`QM5_10375:SP500.DWX`, reaches Scale 5.9 with minimum `56.76%` robust pass,
mean `57.35%`, maximum `4.78%` max-loss breach, and `38.49%`
target-not-reached. That is close, but below the Round 24 `57.04%` minimum
robust lead. `QM5_10163:SP500.DWX` and `QM5_10595:USDJPY.DWX` validate
mechanically, but neither provides a confirmed lead improvement.

Round 28 does not improve the lead and produces no combo screen. `QM5_11132`
on `SP500.DWX` validates profitably after worst-case commission (`PF 2.13`,
`4991.95` net) with low full-window DD, but it is too slow for the FTMO sprint:
only `32` trades over 2023-2025, `0.1%` robust pass at Scale 5.0, and already
`12.6%` daily-loss breach. `QM5_10300:SP500.DWX` and `QM5_10192:WS30.DWX`
confirm the earlier Q05-fail warning: both lose over the full validation
window after costs and their useful scales are breachy.

Round 29 validates three deeper-funnel FX/AUD candidates and runs a focused
combo screen/confirmation. All three are profitable after worst-case commission,
but too low-frequency as standalone sprint legs. The best 5-seed confirmed
overlay, shifting 2 percentage points from `QM5_9936:USDJPY.DWX` into
`QM5_11165:AUDCAD.DWX`, reaches Scale 5.9 with minimum `57.04%` robust pass,
mean `57.72%`, maximum `4.98%` max-loss breach, and `38.14%`
target-not-reached. That ties the Round 24 minimum robust number but is worse
on mean robust, max-loss headroom, and target coverage, so it is not promoted.

Round 30 tests the more aggressive high-cadence/Q05-warning sleeve ideas and
rejects all three. `QM5_10041:GBPUSD.DWX` is active (`1371` trades), but the
full-window native report loses after costs (`PF 0.87`, `-3926.82` net).
`QM5_11708:AUDUSD.DWX` and `QM5_10300:XTIUSD.DWX` also lose over 2023-2025, so
no combo screen was run.

## Current Read

No production-ready FTMO 60-calendar-day sprint module is validated yet, but
Round 24 moved the current clean lead to a 13-leg mix with `57.04%` minimum
robust pass and max-loss breach still below the `5%` research guardrail. The
remaining problem is target coverage and guardrail margin: even the clean Scale
5.9 USDCAD/GBPUSD/USDJPY/XTI lead still misses the target in about `38.0%` of
bootstrap paths, and max-loss breach is `4.96%`.

Round 27 adds `QM5_10375:SP500.DWX` as a close backup diversifier, but it is not
promoted because the 5-seed confirmation stays below the Round 24 lead.

Round 28 adds no new promoted leg. `QM5_11132:SP500.DWX` stays a slow research /
Q12-ready candidate, not an FTMO sprint sleeve; `QM5_10300:SP500.DWX` and
`QM5_10192:WS30.DWX` are rejected for this use case.

Round 29 adds two useful backup ideas (`QM5_11165:AUDCAD.DWX`,
`QM5_10939:GBPUSD.DWX`) but no promoted sleeve. Round 30 confirms that the
high-cadence `QM5_10041:GBPUSD.DWX` and the remaining `11708/10300` variants
are not viable FTMO sleeves.

The best next ideas are:

- Treat the `QM5_10951`/`QM5_10163`/`QM5_10375`/`QM5_12475:NDX`/
  `QM5_10848`/`QM5_10700`/`QM5_10702`/`QM5_10988`/`QM5_10194`/
  `QM5_10286:XTIUSD.DWX`/`QM5_9936:USDJPY.DWX`/`QM5_10847:GBPUSD.DWX`/
  `QM5_10476:USDCAD.DWX` at
  4.5/25.2/11.5/9.3/5.6/11.6/5.8/5.5/2.5/4.6/2.8/8.0/3.0 and Scale 5.9 as the
  current clean lead/rescue candidate, not yet as a live prop module.
- Treat Scale 6.0+ for the same 13-leg mix as aggressive only: better target
  coverage, but max-loss breach reached `5.44%` in the 5-seed scale sweep.
- Keep the Round 23 12-leg Scale 5.8 mix as the prior clean benchmark
  (`56.52%` minimum robust pass, `4.94%` max-loss breach).
- Keep the Round 21 11-leg Scale 5.3 mix as the prior clean benchmark
  (`50.12%` minimum robust pass, `4.86%` max-loss breach).
- Keep the Round 20 10-leg Scale 5.2 mix as the prior clean benchmark
  (`49.68%` minimum robust pass, `4.76%` max-loss breach).
- Keep the Round 18 9-leg Scale 4.9 mix as the prior clean benchmark
  (`48.0%` minimum robust pass, `4.86%` max-loss breach).
- Keep the 10/45/15/10/5/10/5 `QM5_10702` variant as the cleaner guardrail
  candidate (`37.1%` robust pass, `4.7%` max-loss breach) if the 10% overlay is
  considered too close to the max-loss line.
- Keep the second optimized 8-leg variant
  6.9/38.5/17.2/11.8/2.5/15.8/2.4/4.9 as an alternate: same `40.2%` robust
  pass, slightly better target coverage (`55.2%` target-not-reached), but
  higher max-loss breach (`4.1%`).
- Note that `QM5_10163:NDX.DWX` Round 7 used the repo
  `ablation_02.set` fallback because the old Q04 `q04comm` setfile referenced
  by evidence was absent.
- Reject `QM5_10110:GBPUSD.DWX` for this sprint use case despite MT5 PASS,
  because the full-window report is losing (`PF 0.95`, `-10541.54` net).
- Retry `QM5_10594:USDJPY.DWX` and `QM5_11118:USDJPY.DWX` only after confirming
  terminal USDJPY history; Round 7 produced infra `NO_HISTORY`, not strategy
  verdicts.
- Keep `QM5_11629:NDX.DWX` as a secondary overlay candidate only; Round 8 did
  not beat the `12475 + 10163` lead.
- Reject `QM5_10482:NDX.DWX` for sprint use unless a stricter filter can lift
  PF materially above `1.02`.
- Keep searching for medium-frequency overlays with genuine decorrelation;
  Round 20 shows commodity exposure can improve the basket more than another
  weak NDX/XAU clone.
- Keep `QM5_10692:NDX.DWX` as a quality backup leg, but prioritize candidates
  with more 60-day target coverage.
- Keep `QM5_10848:XAUUSD.DWX` in the focused basket; it is the first Round 12
  addition that improves target coverage without pushing max-loss breach above
  the 5% research guardrail.
- Keep `QM5_10512:XAUUSD.DWX` as a backup XAU leg only; it validates, but did
  not beat the `QM5_10848:XAUUSD.DWX` overlay in the current basket.
- Keep `QM5_10700:XAUUSD.DWX` in the focused basket as the Round 14 improvement
  leg; its single frequency is low, but the edge is strong enough to improve the
  combined target coverage.
- Keep `QM5_10702:XAUUSD.DWX` as an overlay leg despite weak single stats; the
  basket-level decorrelation is useful.
- Keep `QM5_10988:XAUUSD.DWX` as backup only; it improves one tested mix, but
  its full-window DD is high (`27.84%`) and Q04 had a losing fold.
- Reject `QM5_1061:NDX.DWX` for this basket unless a later filter increases net
  contribution; it validates but does not improve target coverage.
- Reject `QM5_10468:XAUUSD.DWX` for sprint use after Round 16 full-window MT5
  validation (`PF 0.96`, `-30111.52` net, `68.41%` DD).
- Keep `QM5_12511:XAUUSD.DWX` out of the sprint basket; it is stable but too
  slow/small to affect a 60-calendar-day challenge.
- Keep `QM5_10804:NDX.DWX` and `QM5_10150:NDX.DWX` as backup NDX research legs;
  Round 17 did not improve the confirmed lead.
- Reject `QM5_10656:NDX.DWX` for sprint use despite MT5 PASS because full-window
  PF is effectively flat (`1.00`).
- Keep `QM5_10194:XAUUSD.DWX` in the focused basket as a small Round 18 XAU
  sleeve; it has high full-window DD, but improves the confirmed basket at 3%.
- Keep `QM5_10110:NDX.DWX` as a backup NDX research leg only; it validates, but
  did not improve the confirmed lead.
- Reject `QM5_10750:NDX.DWX` for sprint use despite high trade count because
  full-window PF is `0.96` and net is negative.
- Reject `QM5_1638:XAUUSD.DWX` for sprint use despite very high trade count
  because full-window PF is only `1.02` and the combo benefit appears only at
  breachy scale.
- Reject `QM5_10471:NDX.DWX` and `QM5_10490:XAUUSD.DWX` for sprint use because
  both lose over the 2023-2025 MT5 validation window.
- Keep `QM5_10286:XTIUSD.DWX` in the focused basket as the Round 20 commodity
  overlay; it is weak as a single, but materially improves the confirmed basket
  at a 5% sleeve.
- Keep `QM5_11340:EURUSD.DWX` as a secondary diversification leg only; it
  validates, but did not beat the `QM5_10286:XTIUSD.DWX` overlay.
- Reject `QM5_10531:USDJPY.DWX` for sprint use despite high trade count because
  the full-window MT5 report is losing (`PF 0.90`, `-8047.74` net).
- Keep `QM5_9936:USDJPY.DWX` in the focused basket as a small Round 21 USDJPY
  sleeve; it improves the confirmed lead only when funded by trimming
  `QM5_10163:NDX.DWX`, not as a large standalone overlay.
- Keep `QM5_10715:USDJPY.DWX` as a backup USDJPY diversifier; the standalone
  profile is better than `QM5_9936`, but the confirmed basket improvement is
  smaller.
- Reject `QM5_1142:USDJPY.DWX` for sprint use despite MT5 PASS because the
  full-window report is losing (`PF 0.90`, `-3247.74` net).
- Keep `QM5_10551:USDJPY.DWX`, `QM5_10469:USDJPY.DWX`, and
  `QM5_10596:USDJPY.DWX` as infra-blocked retry candidates only; Round 22 did
  not produce valid strategy reports.
- Keep `QM5_10847:GBPUSD.DWX` in the focused basket as the Round 23 GBPUSD
  overlay; it materially improves the confirmed basket at an 8% sleeve.
- Keep `QM5_1120:GBPUSD.DWX` as a backup GBPUSD diversifier only; it validates,
  but did not beat the `QM5_10847:GBPUSD.DWX` overlay.
- Reject `QM5_9952:EURUSD.DWX` for sprint use despite high trade count because
  the full-window report is losing (`PF 0.87`, `-38522.85` net).
- Keep `QM5_10476:USDCAD.DWX` in the focused basket as a small Round 24
  diversification sleeve; it improves the confirmed basket only at 3% and with
  little max-loss headroom.
- Reject `QM5_10113:GBPUSD.DWX` and `QM5_10712:GBPUSD.DWX` for sprint use
  because both lose over the 2023-2025 validation window.
- Reject `QM5_10215:GBPJPY.DWX` and `QM5_10540:EURUSD.DWX` for sprint use
  because both lose over the 2023-2025 validation window.
- Reject `QM5_10352:USDJPY.DWX` for sprint use despite high trade count because
  the full-window MT5 report loses (`PF 0.96`, `-2302.06` net), and useful scale
  is breachy.
- Keep `QM5_10163:USDJPY.DWX` and `QM5_1241:USDJPY.DWX` as infra-blocked retry
  candidates only; Round 26 did not produce valid strategy reports.
- Keep `QM5_10375:SP500.DWX` as a close backup SP500 diversifier; it validates
  profitably and improves some screens, but the 5-seed confirmation did not beat
  the Round 24 lead.
- Keep `QM5_10163:SP500.DWX` as a secondary backup only; it validates, but its
  confirmed basket contribution is smaller than `QM5_10375:SP500.DWX`.
- Reject `QM5_10595:USDJPY.DWX` for sprint use despite MT5 PASS because the
  full-window edge is thin (`PF 1.03`) and useful scale is breachy.
- Keep `QM5_11132:SP500.DWX` as a slow research/Q12-ready candidate only; it
  validates profitably, but the 60-day challenge simulation is too target-starved
  and becomes daily-loss breachy at useful scale.
- Keep `QM5_11165:AUDCAD.DWX` as a backup AUD-cross diversifier only. Its best
  confirmed overlay ties the Round 24 minimum robust number, but worsens
  headroom and target coverage.
- Keep `QM5_10939:GBPUSD.DWX` as a backup GBPUSD diversifier only; it validates
  profitably, but the confirmed overlay stays below the Round 24 benchmark.
- Keep `QM5_11421:EURUSD.DWX` as low-frequency research only; it validates
  profitably, but its standalone useful scale is daily-loss breachy and the
  overlay screen does not improve the lead.
- Reject `QM5_10300:SP500.DWX` for sprint use despite MT5 PASS because the
  2023-2025 report loses after worst-case commission (`PF 0.90`, `-6270.20`
  net).
- Reject `QM5_10192:WS30.DWX` for sprint use despite MT5 PASS because the
  2023-2025 report loses heavily after worst-case commission (`PF 0.65`,
  `-75330.35` net, `64.30%` DD).
- Reject `QM5_10041:GBPUSD.DWX`, `QM5_11708:AUDUSD.DWX`, and
  `QM5_10300:XTIUSD.DWX` for sprint use because all three lose in native
  2023-2025 full-window validation after worst-case commission.
- Keep `QM5_10467:XAUUSD.DWX` and `QM5_10858:NDX.DWX` as secondary research
  legs only; neither improved the lead basket.
- Reject `QM5_9996:NDX.DWX` and `QM5_10469:NDX.DWX` for sprint use despite MT5
  PASS because their full-window PF is only `1.01`/`1.02` and useful scale is
  target-starved.
- Retry GDAXI candidates only on a terminal with confirmed GDAXI history.
- Promote `QM5_10672:NDX.DWX` and `QM5_11090:USDJPY.DWX` only as
  diversification/research candidates.
- Search for candidates with both high frequency and PF materially above 1.15
  on multi-year native reports, then require Q04/Q05 stability before combining.
- Add an explicit prop-candidate gate: native-report dedup, calendar-day sim,
  full-window MT5 validation, and floating-DD guard.
