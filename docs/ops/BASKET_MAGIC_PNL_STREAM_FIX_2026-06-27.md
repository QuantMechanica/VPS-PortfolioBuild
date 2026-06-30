# Basket Magic / PnL Stream Fix (2026-06-27)

## Summary

Investigation of the mis-tested EA rescue queue found a high-confidence harness bug for basket/logical-symbol EAs: basket legs use per-slot magic numbers, but `QM_FrameworkOnTradeTransaction()` only accepted `deal_magic == g_qm_fw_magic`. As a result, non-host basket legs could be excluded from:

- Q04 simulated-commission PF-net accounting.
- Q08 `TRADE_CLOSED` JSONL stream.
- KS distribution live-window input.
- Friday-close / KS divergence position closure.

This made several Q04 basket failures suspect because the evaluated PnL could be host-leg-only rather than combined basket PnL.

## Code Change

Changed `framework/include/QM/QM_Common.mqh`:

- Added `QM_FrameworkOwnsMagicSymbol(magic, symbol)`.
  - Single-symbol behavior is unchanged: base magic is accepted as before.
  - Basket behavior now accepts registered slots for the same EA id when the deal symbol is in the active `QM_SymbolGuard` basket allow-list.
- Added `QM_FrameworkCloseAllOwnedPositions(reason)`.
  - Single-symbol behavior delegates to `QM_FrameworkCloseAllByMagic()`.
  - Basket behavior closes all owned registered basket-slot positions for allowed symbols.
- Updated Friday close and KS divergence closure to use `QM_FrameworkCloseAllOwnedPositions()`.
- Updated `QM_FrameworkOnTradeTransaction()` to feed accepted basket-slot closing deals into Q04/Q08/KS accounting.

Changed `framework/scripts/q04_walkforward.py`:

- Q04 now reads `basket_manifest.json` from the original EA setfile directory and passes `-TesterCurrencyOverride` / `-TesterDepositOverride` to `run_smoke.ps1`.
- Reason: Q04 copies setfiles into `D:\QM\reports\...` before launch, so the existing `run_smoke.ps1` setfile-relative manifest fallback could not see the EA manifest.
- This is required for JPY basket EAs such as `QM5_12533`, where the manifest intentionally sets `tester_currency=JPY` and `tester_deposit=15000000` to avoid MT5 pulling bare `USDJPY` for USD account conversion.
- Q04 now treats `PASS_SOFT` as process success (`exit_code=0`), matching the already-supported verdict semantics.

## Recompiled Basket Rescue Candidates

All of the following compiled PASS with 0 errors and 0 warnings after the framework include change:

| EA | compile report |
|---|---|
| `QM5_12532_edgelab-audnzd-cointegration` | `D:\QM\reports\compile\20260627_194335\summary.csv` |
| `QM5_1023_chan-at-bb-pair` | `D:\QM\reports\compile\20260627_194344\summary.csv` |
| `QM5_1156_caldeira-cointegration-pairs-fx` | `D:\QM\reports\compile\20260627_194352\summary.csv` |
| `QM5_12604_cme-oilgold-ratio` | `D:\QM\reports\compile\20260627_194401\summary.csv` |
| `QM5_12605_cme-oilgold-brk` | `D:\QM\reports\compile\20260627_194409\summary.csv` |
| `QM5_12606_oil-silver-ratio` | `D:\QM\reports\compile\20260627_194418\summary.csv` |
| `QM5_12608_eia-oilgas-breakout` | `D:\QM\reports\compile\20260627_194426\summary.csv` |
| `QM5_12533_edgelab-eurjpy-gbpjpy-cointegration` | `D:\QM\reports\compile\20260627_194434\summary.csv` |
| `QM5_12609_wti-cad-spread-mr` | `D:\QM\reports\compile\20260627_194442\summary.csv` |

Also compiled a single-symbol regression target (`QM5_10000_ff-tasayc-cci-breakout`) PASS with 0 errors / 0 warnings: `D:\QM\reports\compile\20260627_194212\summary.csv`.

## Runtime Validation

User approved using T8-T10 for validation. A fresh post-fix Q04 run was executed on T8 for `QM5_12609_XTI_USDCAD_SPREAD_D1` via host `XTIUSD.DWX`.

Evidence:

- Full Q04 aggregate: `D:\QM\reports\pipeline\QM5_12609\Q04\QM5_12609_XTI_USDCAD_SPREAD_D1\aggregate.json`
- Verdict: `FAIL`
- F1: `PF-net=0.664`, `trades=26`, `status=OK`
- F2: `PF-net=0.677`, `trades=28`, `status=OK`
- F3: `trades=0`, `status=FAIL`

Because the full three-fold run clears the stream before each fold and F3 ended with no trades, a separate one-fold validation run was executed on T9 with `--latest-full-year 2023` and report root `D:\QM\reports\pipeline_validation_12609_stream`.

Validation aggregate:

`D:\QM\reports\pipeline_validation_12609_stream\QM5_12609\Q04\QM5_12609_XTI_USDCAD_SPREAD_D1\aggregate.json`

Common Files stream after the T9 validation:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\QM\q08_trades\12609_XTIUSD_DWX.jsonl`

Observed stream contents:

| symbol | closed deals | net |
|---|---:|---:|
| `USDCAD.DWX` | 13 | -486.47 |
| `XTIUSD.DWX` | 13 | -400.70 |

Conclusion: the post-fix host-keyed stream now contains both basket legs. The harness bug is fixed for this class of EA. `QM5_12609` itself is still not rescued by the corrected scoring; its combined-leg Q04 evidence remains a strategy FAIL, not an infra false negative.

## Additional Basket Retest: QM5_12533

An initial post-fix Q04 run on T10 for `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` via host `EURJPY.DWX` produced a partial result:

Evidence:

- Full Q04 aggregate: `D:\QM\reports\pipeline\QM5_12533\Q04\QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1\aggregate.json`
- Verdict: `INVALID`
- F1: `PF-net=0.973`, `trades=22`, `status=OK`
- F2: `INVALID`, `NO_HISTORY`
- F3: `INVALID`, `NO_HISTORY`

Interpretation: the full T10 run is not a clean strategy verdict because 2024/2025 folds failed on terminal/history setup. It does show that the corrected stream path can score a real basket fold.

A separate F1-only validation run was then executed on T10 with `--latest-full-year 2023` and report root `D:\QM\reports\pipeline_validation_12533_stream_T10`.

Validation aggregate:

`D:\QM\reports\pipeline_validation_12533_stream_T10\QM5_12533\Q04\QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1\aggregate.json`

Common Files stream after the T10 validation:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\QM\q08_trades\12533_EURJPY_DWX.jsonl`

Observed stream contents:

| symbol | closed deals | net |
|---|---:|---:|
| `GBPJPY.DWX` | 11 | -1201.86 |
| `EURJPY.DWX` | 11 | 1160.99 |

Conclusion: the post-fix host-keyed stream also contains both legs for the EURJPY/GBPJPY basket. `QM5_12533` is not admitted yet: F1 alone is slightly below the Q04 PF-net floor and F2/F3 require terminal/history repair before a complete verdict is valid.

Follow-up investigation showed `EURJPY.DWX`/`GBPJPY.DWX` custom history and ticks were present on T8/T9/T10. The actual invalid-report cause was MT5 account-currency conversion: with default `Currency=USD`, the tester tried to synchronize bare broker symbol `USDJPY`, timed out, and exported blank `M0/1970` reports. The EA's `basket_manifest.json` already specifies `tester_currency=JPY` and `tester_deposit=15000000`, but Q04 was not passing those values after copying the setfile to the report directory.

After fixing Q04 manifest override propagation, a fresh full Q04 was executed on T10:

Evidence:

- Full Q04 aggregate: `D:\QM\reports\pipeline\QM5_12533\Q04\QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1\aggregate.json`
- Verdict: `FAIL`
- F1: `trades=0`, `status=FAIL`, valid `MIN_TRADES_NOT_MET` report with `Currency=JPY`, `Deposit=15000000`
- F2: `PF-net=0.704`, `trades=32`, `status=OK`
- F3: `PF-net=0.754`, `trades=32`, `status=OK`

Conclusion: `QM5_12533` is no longer blocked by Q04 infra for this rerun. It remains a strategy Q04 `FAIL`, not a rescue.

## Rescued Basket Candidate: QM5_12606

A fresh post-fix Q04 run was executed on T8 for `QM5_12606_XTI_XAG_RATIO_D1` via host `XTIUSD.DWX`.

Evidence:

- Full Q04 aggregate: `D:\QM\reports\pipeline\QM5_12606\Q04\QM5_12606_XTI_XAG_RATIO_D1\aggregate.json`
- Verdict: `PASS_SOFT`
- F1: `PF-net=0.914`, `trades=22`, `status=OK`
- F2: `PF-net=1.123`, `trades=26`, `status=OK`
- F3: `PF-net=74.313`, `trades=2`, `status=FAIL` from `MIN_TRADES_NOT_MET`, but completed with real stream evidence
- Q04 soft reason: `soft:2/3>floor,mean=25.450,min=0.914`

Common Files stream after F3:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\QM\q08_trades\12606_XTIUSD_DWX.jsonl`

Observed stream contents:

| symbol | closed deals | net |
|---|---:|---:|
| `XAGUSD.DWX` | 1 | -2.60 |
| `XTIUSD.DWX` | 1 | 215.60 |

Conclusion: `QM5_12606` is a true rescue from the basket-magic/PnL stream fix. The latest clean Q04 verdict is `PASS_SOFT`, so it should be eligible for the next pipeline phase under the Q04 soft-pass policy.

## Additional Basket Retest: QM5_12608

A fresh post-fix Q04 run was executed on T9 for `QM5_12608_XTI_XNG_BREAKOUT_D1` via host `XTIUSD.DWX`.

Evidence:

- Full Q04 aggregate: `D:\QM\reports\pipeline\QM5_12608\Q04\QM5_12608_XTI_XNG_BREAKOUT_D1\aggregate.json`
- Verdict: `FAIL`
- F1: `PF-net=1.059`, `trades=28`, `status=OK`
- F2: `PF-net=1.467`, `trades=23`, `status=OK`
- F3: `PF-net=0.632`, `trades=22`, `status=OK`

Common Files stream after F3:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\QM\q08_trades\12608_XTIUSD_DWX.jsonl`

Observed stream contents:

| symbol | closed deals | net |
|---|---:|---:|
| `XNGUSD.DWX` | 7 | -174.00 |
| `XTIUSD.DWX` | 15 | -391.50 |

Conclusion: the stream contains both basket legs, but `QM5_12608` remains a strategy Q04 `FAIL` because the 2025 OOS fold is below the PF floor.

## Rescued Basket Candidate: QM5_12605

The first post-framework-fix Q04 run for `QM5_12605_XTI_XAU_BRK_D1` still failed with `PF-net=0.000` in all folds. Follow-up log review showed this was not a scoring issue: the EA opened the XTI leg at the D1 bar open around `01:00`, then the intended XAU leg was rejected with `Market closed`, leaving repeated one-leg XTI packages.

EA-local repair:

- Added `strategy_entry_hour_broker=2` and `strategy_entry_minute_broker=0`.
- Delayed the once-per-D1 entry attempt until the configured broker time.
- Added per-leg trade-session readiness checks using `SymbolInfoSessionTrade`.
- Kept the D1 spread state and no-pyramiding logic unchanged.

The repaired EA compiled cleanly:

- Compile verdict: `COMPILED`
- Errors / warnings: `0 / 0`
- Compile log: `C:\QM\repo\framework\build\compile\20260628_054106\QM5_12605_cme-oilgold-brk.compile.log`

A fresh Q04 run was executed on T8 for `QM5_12605_XTI_XAU_BRK_D1` via host `XTIUSD.DWX`.

Evidence:

- Full Q04 aggregate: `D:\QM\reports\pipeline\QM5_12605\Q04\QM5_12605_XTI_XAU_BRK_D1\aggregate.json`
- Verdict: `PASS`
- F1: `PF-net=1.106`, `trades=22`, `status=OK`
- F2: `PF-net=1.125`, `trades=24`, `status=OK`
- F3: `PF-net=1.303`, `trades=34`, `status=OK`

Common Files stream after F3:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\QM\q08_trades\12605_XTIUSD_DWX.jsonl`

Observed stream contents:

| symbol | closed deals | net |
|---|---:|---:|
| `XAUUSD.DWX` | 17 | 807.59 |
| `XTIUSD.DWX` | 17 | 62.30 |

The three fresh raw logs contain no `Market closed` or `failed market` entries. Conclusion: `QM5_12605` is a true implementation rescue. Its latest clean Q04 verdict is `PASS`, so it should advance to the next pipeline phase.

## Additional Basket Retest: QM5_12604

`QM5_12604_XTI_XAU_RATIO_D1` had the same XTI/XAU execution pattern as `QM5_12605`: the EA attempted the basket at the D1 bar open, opened the XTI leg first, and could leave broken packages when XAU was not tradable yet. The same local session-delay repair was applied without changing the z-score strategy logic:

- Added `strategy_entry_hour_broker=2` and `strategy_entry_minute_broker=0`.
- Delayed the once-per-D1 entry attempt until the configured broker time.
- Added per-leg trade-session readiness checks using `SymbolInfoSessionTrade`.

The repaired EA compiled cleanly:

- Compile verdict: `COMPILED`
- Errors / warnings: `0 / 0`
- Compile log: `C:\QM\repo\framework\build\compile\20260628_060125\QM5_12604_cme-oilgold-ratio.compile.log`

A fresh Q04 run was executed on T9 for `QM5_12604_XTI_XAU_RATIO_D1` via host `XTIUSD.DWX`.

Evidence:

- Full Q04 aggregate: `D:\QM\reports\pipeline\QM5_12604\Q04\QM5_12604_XTI_XAU_RATIO_D1\aggregate.json`
- Verdict: `FAIL`
- F1: `PF-net=0.712`, `trades=30`, `status=OK`
- F2: `PF-net=1.051`, `trades=32`, `status=OK`
- F3: `PF-net=0.647`, `trades=38`, `status=OK`

Common Files stream after F3:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\QM\q08_trades\12604_XTIUSD_DWX.jsonl`

Observed stream contents:

| symbol | closed deals | net |
|---|---:|---:|
| `XAUUSD.DWX` | 19 | -1197.61 |
| `XTIUSD.DWX` | 19 | -364.00 |

The three fresh raw logs contain no `Market closed` or `failed market` entries. Conclusion: `QM5_12604` is now a clean combined-leg strategy verdict, but it is not rescued; latest Q04 remains `FAIL`.

## Additional Basket Retest: QM5_1023

`QM5_1023_XTI_XAU_BBPAIR_D1` also had the XTI/XAU basket execution issue. The original post-framework-fix evidence still showed `PF-net=0.000`, and raw logs confirmed repeated XAU `Market closed` failures around the D1 bar open. The EA needed local basket execution repair in addition to the framework stream fix.

EA-local repair:

- Added `strategy_entry_hour_broker=2` and `strategy_entry_minute_broker=0`.
- Delayed the once-per-D1 entry attempt until the configured broker time.
- Added per-leg trade-session readiness checks using `SymbolInfoSessionTrade`.
- Added a 60-second session-open buffer because XAU session metadata can report open before the tester accepts orders.
- Added a two-leg lot preflight so no order is sent unless both legs have valid lot sizes.
- Sent the XAU leg first for new packages and guarded normal z-score exits until both legs are tradable.

The final repaired EA compiled cleanly:

- Compile verdict: `COMPILED`
- Errors / warnings: `0 / 0`
- Compile log: `C:\QM\repo\framework\build\compile\20260628_071350\QM5_1023_chan-at-bb-pair.compile.log`

A fresh Q04 run was executed on T9 for `QM5_1023_XTI_XAU_BBPAIR_D1` via host `XTIUSD.DWX`.

Evidence:

- Full Q04 aggregate: `D:\QM\reports\pipeline\QM5_1023\Q04\QM5_1023_XTI_XAU_BBPAIR_D1\aggregate.json`
- Verdict: `FAIL`
- F1: `PF-net=0.567`, `trades=14`, `status=OK`
- F2: `PF-net=0.431`, `trades=10`, `status=OK`
- F3: `PF-net=1.060`, `trades=6`, `status=OK`
- Low-frequency pooled verdict: `FAIL`, `pooled_pf=0.517`, `pooled_trades=30`, `active_years=3/3`

Common Files stream after F3:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\QM\q08_trades\1023_XTIUSD_DWX.jsonl`

Observed stream contents:

| symbol | closed deals | net |
|---|---:|---:|
| `XAUUSD.DWX` | 3 | -48.20 |
| `XTIUSD.DWX` | 3 | 56.20 |

The three fresh raw logs contain no `Market closed` or `failed market` entries. Conclusion: `QM5_1023` is no longer mis-tested as a PF-zero/broken-basket artifact, but it is not rescued; latest clean Q04 remains `FAIL`.
