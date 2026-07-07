# Latent-Defect Audit Wave 1 Review - 2026-07-07

- task_id: 83be4dd3-618b-4421-94f7-290aa353dcf3
- reviewer: codex
- task_type: ops_issue / review
- source_audit: docs/ops/FRAMEWORK_LATENT_DEFECT_AUDIT_2026-07-06.md
- reviewed_commits: d8b741d02, 8158dca1b, 6113c8927, 64dcd7c96, aa7b861ce
- verdict: PASS_CONDITIONAL

## Scope Reviewed

Focused review covered the wave-1 CRITICAL MQL5 fixes and evidence-layer fixes named by the router payload:

- `framework/include/QM/QM_TradeContext.mqh`
- `framework/include/QM/QM_StopRules.mqh`
- `framework/scripts/q08_davey/aggregate.py`
- `framework/scripts/run_smoke.ps1`
- `framework/scripts/gen_setfile.ps1`

## Findings

No blocking defect was found in the reviewed scope.

Observed implementation points:

- `QM_TradeContextSend` now gates the NO_MONEY latch through `QM_TradeContextOpensExposure`.
- SL/TP modification, pending-order removal, close-by, and deal requests carrying an existing position bypass the latch.
- The NO_MONEY latch re-arms by broker day and WARN logging is throttled to avoid tick-rate log writes.
- `QM_StopRulesReadATRValue` now calls pooled `QM_ATR(symbol, PERIOD_CURRENT, atr_period_value, shift)` instead of creating/releasing a raw `iATR` handle per stop read.
- Q08 cost-cushion grading marks all-volumeless report-fallback trade sets as `INVALID` instead of treating zero modeled commission as a PASS-like cost result.
- Q08 baseline summary adoption is symbol-gated through `expected_symbol`, preventing a shared `_baseline` directory from adopting another symbol's freshest summary.
- Q08 durable stream persistence refuses HTML report-fallback rows without volume and mirrors host-symbol basket streams where applicable.
- `run_smoke.ps1` includes German report-label aliases for core graded metrics and preserves missing graded labels as `REPORT_METRIC_MISSING:*`.
- `Resolve-RunInvalidReason` maps metric-only missing/unparseable reasons to `REPORT_FORMAT_DRIFT`.
- `run_smoke.ps1` waits for complete report metrics before latching a stable tester report, reducing false success on incomplete shell reports.
- `gen_setfile.ps1` hard-fails with `MAGIC_REGISTRY_ROW_MISSING` when no active magic registry row exists for the EA/symbol.
- Backtest setfile guards remain strict: `RiskFixed > 0` and `RiskPercent == 0`.

## Verification

Commands run from `C:\QM\repo`:

```powershell
$errors=$null; [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath 'framework/scripts/run_smoke.ps1'), [ref]$errors) | Out-Null; if (@($errors).Count -gt 0) { exit 1 }; 'run_smoke.ps1 parse PASS'
```

Result: PASS.

```powershell
$errors=$null; [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath 'framework/scripts/gen_setfile.ps1'), [ref]$errors) | Out-Null; if (@($errors).Count -gt 0) { exit 1 }; 'gen_setfile.ps1 parse PASS'
```

Result: PASS.

```powershell
python -m py_compile framework/scripts/q08_davey/aggregate.py
```

Result: PASS.

```powershell
python -m unittest framework.scripts.tests.test_q08_davey_subgates framework.scripts.tests.test_p2_baseline tools.strategy_farm.tests.test_portfolio_common tools.strategy_farm.tests.test_portfolio_q08_contribution
```

Result: PASS, 64 tests.

```powershell
python tools/strategy_farm/validate_build_guardrails.py framework/include/QM/QM_TradeContext.mqh framework/include/QM/QM_StopRules.mqh framework/scripts/q08_davey/aggregate.py framework/scripts/run_smoke.ps1 framework/scripts/gen_setfile.ps1
```

Result: PASS, `max_news_stale_hours=336`, no findings.

Static assertions also passed for:

- entry-only trade latch classifier
- broker-day latch rearm and WARN throttle
- pooled ATR stop-route
- all-volumeless Q08 cost-cushion INVALID
- symbol-gated Q08 baseline summary adoption
- German report aliases and `REPORT_FORMAT_DRIFT` routing
- active magic-row hard throw

## Residual Risk

This review did not launch MT5, start `terminal64.exe`, enable AutoTrading, or interrupt active terminals. Evidence is code review plus static/unit verification only. Live rollout, rebuild evidence, and pipeline verdicts must still come from the appropriate Q-phase evidence.
