# DXZ portfolio admission/resize remediation

Status: **analysis-only, fail-closed**  
Canonical implementation: `tools/strategy_farm/portfolio/portfolio_resize.py`  
Freeze gate: `tools/strategy_farm/portfolio/portfolio_freeze_gate.py`

This path does not create presets, touch MT5, change a live book, or approve a
deployment. Its output status is `ANALYSIS_ONLY_OWNER_REVIEW` and
`deployment_action` is always `NONE`.

## What this fixes

1. **No cap weight loss.** The old pattern
   `min(cap, target * normalized_weight)` silently discarded capped excess while
   the report continued to claim the original target total. The canonical allocator
   redistributes excess and asserts `sum(allocation) == target`. If aggregate capacity
   is too small, it raises; it never reports a short allocation as the target.
2. **Overlapping hierarchical caps.** A resize config must explicitly cover sleeve,
   EA, symbol, mechanism, and asset class. The solver projects the requested total
   onto all five overlapping cap families. This prevents a literal 1% sleeve cap from
   being misrepresented as a 1% EA or symbol cap.
3. **Frozen input only.** The resize CLI has no `--common-dir`. Every stream must be
   under a declared frozen root and carry an exact SHA256. MT5 `Common\Files` paths,
   missing/extra streams, duplicate files, path escapes, wrong hashes, and ambiguous
   source-risk units are hard errors.
4. **One risk scale.** All cap and allocation values are account percentage points:
   `1.0` means 1% of account equity. Every stream declares the source capital and
   source risk percent used by its backtest.
5. **Truth-chain gate.** No output path is touched until an independently hashed
   truth-chain artifact is `PASS` and the gate matches the config, stream manifest,
   commission registry, and every stream hash.
6. **No double risk scaling.** A manifest's allocated sleeve risk is written in
   full to `RISK_PERCENT`; its EA-facing `PORTFOLIO_WEIGHT` is `1.0`. Relative
   portfolio weights remain analytics metadata. Since the framework sizes as
   `RISK_PERCENT * PORTFOLIO_WEIGHT`, writing the normalized weight into both
   allocation and set fields would silently under-risk every sleeve a second time.

The historical `D:\QM\reports\book_resize_2026-07-15\resize_B_final.json` is not an
input to this implementation and must not be treated as reproduced evidence. A new
number requires a complete frozen bundle and a passing gate.

## Risk scaling

For sleeve `i`, the closed-trade stream is normalized before allocation:

```text
return_per_1pct_risk[i, day]
  = net_of_cost_pnl[i, day]
    / source_starting_capital[i]
    / source_risk_pct[i]

portfolio_return[day]
  = sum(return_per_1pct_risk[i, day] * allocated_risk_pct[i])

equity[day]
  = equity[prior_day] * (1 + portfolio_return[day])
```

This makes a stream produced at 2% source risk comparable with one produced at 1%
source risk. Raw dollar PnL is never multiplied by a risk number without first
dividing by the explicit source scale.

## Frozen stream manifest

Minimal schema version 1:

```json
{
  "schema_version": 1,
  "frozen": true,
  "frozen_root": "frozen_streams",
  "risk_scale": {
    "unit": "account_percent",
    "source_starting_capital": 100000,
    "source_risk_pct": 1.0
  },
  "streams": [
    {
      "ea_id": 100,
      "symbol": "EURUSD.DWX",
      "path": "100_EURUSD_DWX.jsonl",
      "sha256": "<64 hex>",
      "trade_count": 250
    }
  ]
}
```

`source_starting_capital` and `source_risk_pct` may be overridden per stream when a
legacy run genuinely used a different scale. That override is visible in the output.
SHA verification protects content identity; operational retention/backup of the
frozen directory remains required.

## Resize config and hierarchy

Each sleeve needs mechanism and asset-class metadata. Cap rules accept either one
default number or `default` plus exact group overrides:

```json
{
  "schema_version": 1,
  "starting_capital": 100000,
  "target_total_risk_pct": 9.75,
  "min_vol_sessions": 63,
  "darwin_var_target_pct": 6.5,
  "d_leverage_cap": 9.75,
  "var_window_sessions": 21,
  "caps": {
    "sleeve": 1.0,
    "ea": 2.0,
    "symbol": {"default": 3.0, "overrides": {"XAUUSD.DWX": 2.0}},
    "mechanism": 3.0,
    "asset_class": 5.0
  },
  "sleeves": [
    {
      "ea_id": 100,
      "symbol": "EURUSD.DWX",
      "mechanism": "trend_pullback",
      "asset_class": "fx"
    }
  ]
}
```

The numbers above illustrate the schema; they are not an approved DXZ policy. OWNER
must set them from the frozen-book evidence. Unknown override groups are errors so a
typo cannot silently remove a cap.

## Admission/resize freeze gate

The gate is intentionally not auto-generated as `PASS`. A review process creates a
truth-chain artifact, and the gate binds that artifact plus every calculation input:

```json
{
  "schema_version": 1,
  "gate_type": "ADMISSION_RESIZE_FREEZE",
  "allowed_purposes": ["admission", "resize"],
  "truth_chain": {
    "status": "PASS",
    "artifact_path": "truth_chain.json",
    "artifact_sha256": "<64 hex>",
    "candidate_manifest_sha256": "<64 hex>",
    "adjudication_sha256": "<64 hex>",
    "requal_summary_sha256": "<64 hex>"
  },
  "inputs": {
    "resize_config_sha256": "<64 hex>",
    "stream_manifest_sha256": "<64 hex>",
    "commission_registry_sha256": "<64 hex>",
    "streams": {
      "100:EURUSD.DWX": "<64 hex>"
    }
  }
}
```

The truth-chain file itself must contain `"verdict": "PASS"` and a passing,
applicable `qualification_chain`. That chain must prove a
`BOUND_CANDIDATE_COMPLETE`, adjudication `PASS`, and requalification
`FULL + PASS`. The three lineage SHA fields in the gate must exactly match the
actual artifact hashes recorded by Truth Chain. A gate-level PASS cannot
override failed, partial, incomplete, repaired, or tampered evidence. Expected
and actual stream key sets must match exactly.

Q09 candidate screening is not a book mutation and can still produce a diagnostic
verdict. Any process that turns an admission into a proposed new book must call
`validate_admission_resize_freeze_gate(..., purpose="admission")`. The resize CLI calls
the same validator with `purpose="resize"` before creating its output directory.

## Command

```powershell
python -m tools.strategy_farm.portfolio.portfolio_resize `
  --config D:\QM\reports\dxz_resize\resize_config.json `
  --stream-manifest D:\QM\reports\dxz_resize\frozen_stream_manifest.json `
  --freeze-gate D:\QM\reports\dxz_resize\admission_resize_freeze_gate.json `
  --out D:\QM\reports\dxz_resize\resize_analysis.json
```

Any missing gate, non-PASS truth chain, hash mismatch, infeasible cap system, missing
metadata, empty/zero-vol stream, or insufficient volatility history exits non-zero and
does not produce a new output.

## What the DXZ metrics do and do not mean

The report compounds normalized daily realized-close returns and reports:

- realized-close peak-to-trough drawdown;
- historical 95% loss VaR and expected shortfall of overlapping 21-session returns;
- calendar-month historical VaR as a secondary diagnostic;
- an explicitly labelled D-Leverage-limited target-fill diagnostic;
- source/MAE/entry-time coverage.

Darwinex Zero's own documentation says the DARWIN risk engine targets up to 6.5%
monthly VaR, evaluates strategy VaR using recent exposed-market history, and can adjust
positions while they remain open. The D-Leverage ceiling also depends on holding time
(9.75 is the documented ceiling for positions beyond 60 minutes). The documented
drawdown uses a DARWIN quote curve sampled every 30 seconds:

- https://www.darwinexzero.com/docs/en/risk-engine
- https://www.darwinexzero.com/docs/drawdown-calculation

Our Q08 streams contain exits, optional entry timestamps, and optional per-trade MAE;
they do **not** contain a timestamped mark-to-market portfolio curve. Consequently:

| Available here | Not reconstructable from closed trades |
|---|---|
| net-of-cost realized closes | floating PnL before exit |
| daily compounded close equity | 30-second DARWIN quote curve |
| historical 21-session VaR proxy | official 45-exposed-day strategy VaR engine |
| single-trade MAE coverage | timestamped simultaneous portfolio MAE |
| static allocation scale | live margin, duration D-Leverage and risk adjustments |

Therefore `max_drawdown_realized_close_only_pct` and `monthly_var_95_loss_pct` are
screening diagnostics. They are not official DARWIN statistics, not a live risk limit,
and not sufficient evidence for deployment. A deployment-grade pass still needs a
timestamped balance/equity or bar/tick mark-to-market reconstruction with open-position
overlap, gap/slippage, margin, and dynamic sizing.

## Tests

`tools/strategy_farm/tests/test_portfolio_resize.py` covers cap redistribution,
infeasible targets, crossing hierarchical constraints, exact target preservation,
frozen-root/SHA validation, source-risk scaling, compounded drawdown, truth-chain
validation, complete input binding, and the guarantee that a failed gate creates no
output directory.
`tools/strategy_farm/tests/test_dxz_post_sweep_contract.py` additionally covers
the end-to-end runner-summary -> adjudicator -> Truth Chain -> freeze-gate
contract and proves that a partial candidate remains ineligible.
