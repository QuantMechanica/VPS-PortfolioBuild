# Codex Review: Latent-Defect Audit Wave 1

Task: `83be4dd3-618b-4421-94f7-290aa353dcf3`
Review target: `REVIEW: latent-defect audit wave 1 (2026-07-06)`
Date: 2026-07-07

## Verdict

PASS_CONDITIONAL. I found no blocking defect in the routed focus areas. The fixes are coherent with the audit register and the available focused verification is green.

Conditions/caveats:

- The Q09 resolver claim for `QM5_12772` is a standalone durable-stream resolver proof, not a farm Q09 verdict. The current farm DB has `QM5_12772` stopped at Q08 `FAIL_HARD`, with no Q09 work item. Wording should avoid implying a pipeline Q09 verdict for 12772.
- The NO_MONEY latch semantics were statically reviewed against current framework callers. I did not produce a live broker retcode reproduction. If future custom EAs call `QM_TradeContextSend()` for a risk-reducing `TRADE_ACTION_DEAL` without setting `request.position`, the helper will still classify it as exposure-opening. Current framework close helpers set `position`.

## Evidence Reviewed

- `docs/ops/FRAMEWORK_LATENT_DEFECT_AUDIT_2026-07-06.md`
- Commits:
  - `d8b741d02` - MQL5 wave-1 fixes.
  - `8158dca1b` - skeleton gate order and KS baseline writer.
  - `6113c8927` - evidence-layer gate fixes.
  - `64dcd7c96` - audit register and recompile record.
  - `aa7b861ce` - recompiled StopATR-profile pipeline EAs.
- Files in focus:
  - `framework/include/QM/QM_TradeContext.mqh`
  - `framework/include/QM/QM_StopRules.mqh`
  - `framework/scripts/q08_davey/aggregate.py`
  - `framework/scripts/run_smoke.ps1`
  - `framework/scripts/gen_setfile.ps1`

## Claim Checks

1. `QM_TradeContext` NO_MONEY latch semantics: VERIFIED.
   - `TRADE_ACTION_SLTP`, `TRADE_ACTION_REMOVE`, `TRADE_ACTION_CLOSE_BY`, and `TRADE_ACTION_DEAL` with `request.position > 0` bypass the latch.
   - The latch blocks only `QM_TradeContextOpensExposure(request)`.
   - The latch resets on broker-day change and logs latched rejections.
   - Sampled framework close paths (`QM_TM_ClosePosition`, grid cap close, pair close callers via `QM_TM_ClosePosition`) set `request.position`.

2. `QM_StopRules` pooled ATR route: VERIFIED.
   - `QM_StopRules.mqh` now includes `QM_Indicators.mqh`.
   - `QM_StopRulesReadATRValue()` reads via `QM_ATR(symbol, PERIOD_CURRENT, atr_period_value, shift)`.
   - The helper no longer creates/releases a raw `iATR` handle per call.

3. `aggregate.py` cushion INVALID and symbol-gated baseline adoption: VERIFIED.
   - All-volume-less trade sets set `cost_cushion_tier` to `INVALID` instead of cost PASS.
   - `_latest_baseline_summary()` accepts `expected_symbol` and rejects shared `_baseline` summaries for other symbols.
   - Baseline retry passes `expected_symbol=baseline_run.get("test_symbol")`.

4. `run_smoke.ps1` German aliases and missing metric markers: VERIFIED.
   - German aliases include `Rueckgang Equity maximal` equivalent and `Qualitaet der Historie` strings in source form.
   - Missing graded metrics emit `REPORT_METRIC_MISSING:<metric>` markers instead of silently defaulting to zero.
   - Parser classification explicitly routes these markers as parser drift.

5. `gen_setfile.ps1` magic-row hard throw: VERIFIED.
   - Missing `magic_numbers.csv` throws `MAGIC_REGISTRY_MISSING`.
   - Missing active `(ea_id, symbol)` row throws `MAGIC_REGISTRY_ROW_MISSING`.
   - Backtest risk guardrails remain present: `RiskFixed > 0` and `RiskPercent == 0`.

6. Q09 resolver functional evidence: VERIFIED WITH WORDING CAVEAT.
   - `portfolio_common.load_streams(D:/QM/reports/portfolio/sleeve_streams, candidates=[...])` resolves:
     - `QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1`: 226 trades.
     - `QM5_12864_XTI_XAG_RSPREAD_D1`: 106 trades.
     - `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`: 195 trades.
   - Farm DB confirms current Q09 verdicts for 12864 and 12778 only:
     - `QM5_12864`: Q09 `FAIL_PORTFOLIO`, 106 trades.
     - `QM5_12778`: Q09 `PASS_PORTFOLIO`, 195 trades.
     - `QM5_12772`: no Q09 row; current latest row is Q08 `FAIL_HARD`.

## Focused Verification

Commands run from `C:/QM/repo`:

```text
python -m pytest framework/scripts/tests/test_q08_davey_subgates.py -q
python <static verifier for latch, StopRules, aggregate, run_smoke, gen_setfile>
pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw framework/scripts/run_smoke.ps1)) | Out-Null; ..."
python <compile-summary scan for the nine named EAs>
python <durable-stream load_streams check for 12772/12864/12778>
```

Results:

```text
Q08 Davey suite: 39 passed in 0.57s
PowerShell parser:
  framework/scripts/run_smoke.ps1: PARSE_OK
  framework/scripts/gen_setfile.ps1: PARSE_OK

Static verifier:
  latch_exempts_sltp_remove_closeby: PASS
  latch_exempts_deal_with_position: PASS
  latch_only_blocks_opening_requests: PASS
  latch_rearms_by_day: PASS
  stoprules_uses_pooled_qm_atr: PASS
  stoprules_no_raw_iatr_in_helper: PASS
  aggregate_volume_less_invalid: PASS
  aggregate_symbol_gated_baseline: PASS
  run_smoke_german_dd_alias: PASS
  run_smoke_metric_missing_markers: PASS
  gen_setfile_magic_missing_throw: PASS
```

Compile evidence found in `D:/QM/reports/compile/20260706_*`:

```text
QM5_10163_tv-rsi-macd-long: PASS, errors=0, warnings=0
QM5_11132_tm-cum-rsi2: PASS, errors=0, warnings=0
EA_Skeleton: PASS, errors=0, warnings=0
QM5_12874_xng-inject-slope-short: PASS, errors=0, warnings=0
QM5_13000_xng-rig-fri-fade: PASS, errors=0, warnings=0
QM5_13004_xti-cot-fade: PASS, errors=0, warnings=0
QM5_13009_xng-tom-mom: PASS, errors=0, warnings=0
QM5_13014_mql5-dema-chan-v2: PASS, errors=0, warnings=0
QM5_13016_tv-ma-scalper-relief-v2: PASS, errors=0, warnings=0
```

## Residual Risk

- The live-book effect of these fixes still depends on rebuilding the live binaries. This review did not enable `T_Live`, AutoTrading, or start `terminal64.exe`.
- The `QM_TradeContextOpensExposure()` helper relies on callers using the framework convention that close/reduce `DEAL` requests set `request.position`. That convention holds in the reviewed framework paths, but it is not enforced by type.

