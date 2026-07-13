# Master-EA Phase 2.5 — Explicit FIXED Risk Design Note

Date: 2026-07-13
Branch: `agents/codex-master-ea-p25`

## Scope

Phase 2.5 adds an opt-in, per-call `RISK_FIXED` sizing context to the V5
framework. The fixed value is risk money, not lots. No master strategy module,
dispatcher behavior, registry row, or strategy logic is part of this change.

The intended module call is:

```cpp
QM_TM_OpenPosition(req,
                   out_ticket,
                   strategy_magic,
                   QM_RISK_MODE_FIXED,
                   strategy_risk_fixed);
```

The Phase-1 percentage call remains valid and unchanged:

```cpp
QM_TM_OpenPosition(req, out_ticket, strategy_magic, strategy_risk_percent);
```

## Added overloads

- `QM_RiskSizerRiskMoney(equity, explicit_mode, explicit_value)` resolves an
  explicit `QM_RiskMode` without modifying the configured global mode/value.
- `QM_LotsForRisk(symbol, sl_points, explicit_mode, explicit_value)` applies
  that risk money to the existing symbol snapshot, lot quantization, DWX
  margin fallback, 90% free-margin ceiling, and final requantization.
- `QM_Entry(req, out_ticket, explicit_magic, explicit_mode, explicit_value)`
  threads the mode/value into sizing. Invalid/`UNSET` modes and nonpositive
  explicit values resolve to zero lots and reject; they never fall back to the
  global risk context.
- `QM_TM_OpenPosition(req, out_ticket, explicit_magic, explicit_mode,
  explicit_value)` exposes the same context to a strategy module.

The new Entry and Trade Manager overloads require all five arguments. Their
arity is distinct from the existing defaulted two-through-four-argument
percentage signatures.

## FIXED equivalence

For `QM_RISK_MODE_FIXED`, the explicit risk-money overload deliberately mirrors
the valid global fixed branch in the same order:

1. reject nonpositive equity;
2. `base_risk = explicit_value`;
3. `weighted_risk = base_risk * g_qm_risk_portfolio_weight`;
4. if configured and lower, apply `g_qm_risk_per_trade_cap_money`.

It then enters the same `QM_LotsForRiskFromSnapshot` calculation and the same
available-margin ceiling as global/percentage symbol sizing. The explicit
value is never copied into `g_qm_risk_fixed`, and no other process-wide risk
global is mutated.

`QM_RISK_MODE_PERCENT` delegates directly to the existing Phase-1 explicit
percentage overload. This preserves its exact expression order,
`equity * (explicit_risk_percent / 100.0)`, and its existing safety rails.

## Backward compatibility

The existing public overloads and defaults remain source-compatible:

- `QM_RiskSizerRiskMoney(equity)`;
- `QM_RiskSizerRiskMoney(equity, explicit_risk_percent)`;
- `QM_LotsForRisk(symbol, sl_points)`;
- `QM_LotsForRisk(symbol, sl_points, explicit_risk_percent)`;
- `QM_Entry(req, out_ticket, explicit_magic=0,
  explicit_risk_percent=0.0)`;
- `QM_TM_OpenPosition(req, out_ticket, explicit_magic=0,
  explicit_risk_percent=0.0)`.

The global risk-money and lot-sizing bodies were not refactored. The Phase-1
percentage bodies were not refactored. The legacy Entry wrapper retains the
same rule: exactly `0.0` selects global sizing (including global FIXED), while
a negative nonzero explicit percentage follows the explicit percentage path
and rejects. `QM_TM_AddToPosition` and every existing EA call site remain on
their prior overloads.

## Exact unit proof

`framework/tests/unit/risk_sizer_smoke.mq5` now uses direct `==` assertions for:

- explicit FIXED risk money == configured global FIXED risk money;
- explicit FIXED snapshot lots == global FIXED snapshot lots;
- explicit FIXED public symbol lots == global FIXED public symbol lots;
- the same comparisons with an active per-trade cap;
- global FIXED remaining unchanged after a different per-call fixed override;
- the different per-call fixed override resolving to its expected active cap;
- legacy explicit PERCENT and mode-aware explicit PERCENT == global PERCENT;
- explicit PERCENT snapshot lots == global PERCENT snapshot lots;
- legacy and mode-aware explicit PERCENT public symbol lots == global PERCENT
  public symbol lots.

All lot comparisons require a nonzero result, so zero-vs-zero cannot produce a
false pass.

Verification:

- Strict fixture compile: PASS, 0 errors / 0 warnings.
  - Log: `C:\QM\worktrees\codex-master-ea-p25\framework\build\compile\20260713_123841\risk_sizer_smoke.compile.log`
  - Summary: `D:\QM\reports\compile\20260713_123841\summary.csv`
- Runtime fixture on T6, Model 4: PASS.
  - Run-scoped `RISK_SIZER_SMOKE_PASS`: 1 occurrence
  - Run-scoped `ASSERT_FAIL`: 0 occurrences
  - Summary: `D:\QM\reports\smoke\QM5_99999\20260713_123901\summary.json`
  - Tester log: `D:\QM\reports\smoke\QM5_99999\20260713_123901\raw\run_01\20260713.log`
  - Unit EX5 SHA-256:
    `093730CA6F4F16CACB9D30C0EA7304A6AC3FB2E8A236F3C4ECE2C02B287AD4C4`

## Backward-compatibility regression

- Required force rebuild of `QM5_12567_cum-rsi2-commodity`: PASS, 0 errors /
  0 warnings (`compile_one.ps1 -Strict`).
  - Log: `C:\QM\worktrees\codex-master-ea-p25\framework\build\compile\20260713_122114\QM5_12567_cum-rsi2-commodity.compile.log`
  - Summary: `D:\QM\reports\compile\20260713_122114\summary.csv`
- Full-history regression: PASS, exactly 73 trades / net $4,676.76.
  - T6, XAUUSD.DWX, D1, Model 4
  - 2017.01.01 through 2025.12.31
  - Backtest set:
    `QM5_12567_cum-rsi2-commodity_XAUUSD.DWX_D1_backtest.set`
  - Summary: `D:\QM\reports\smoke\QM5_12567\20260713_122149\summary.json`
  - Report: `D:\QM\reports\smoke\QM5_12567\20260713_122149\raw\run_01\report.htm`
  - Worktree EX5 SHA-256:
    `17E7FAA9EF1800B204344B349E57024E3AFB74D2CDE494F07E63175AE9A7B870`

Both runtime gates used unique expert aliases copied to T6 with verified
SHA-256 values, preventing `run_smoke.ps1` from substituting the canonical
`C:\QM\repo` binary. The factory remained off, and no T1/T2 terminal was used
for a smoke/backtest run.
