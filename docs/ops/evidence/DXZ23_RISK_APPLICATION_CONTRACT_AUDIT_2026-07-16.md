# DXZ-23 Risk Application Contract Audit — 2026-07-16

Status: **DEFECT CONFIRMED / HISTORICAL DRAFT SUPERSEDED / NO LIVE MUTATION**

## Decision

The historical 23-sleeve draft cannot be used as a deploy or requalification
source manifest. It stored each sleeve's already allocated account-risk
percentage in `RISK_PERCENT`, then also stored the sleeve's relative book share
in the EA-facing `PORTFOLIO_WEIGHT`. The V5 risk sizer multiplies those fields.
That is a dimensional double scaling error.

This finding does **not** mean that the observed T_Live presets were running at
the doubly scaled values. Read-only inspection of the 23 `*_dxz23_live.set`
presets found `RISK_FIXED=0` and `PORTFOLIO_WEIGHT=1` in every preset. Their
effective aggregate risk input is 9.7501 account percentage points after preset
rounding. No preset, binary, chart, order, risk setting or AutoTrading state was
changed by this audit.

## Bound evidence

| Evidence | SHA-256 |
|---|---|
| `D:\QM\reports\portfolio\portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json` | `493fff6f18594928ec5727fed616b5a736acfdefeb636df76961acc9a24b8db1` |
| Requalification copy `D:\QM\reports\portfolio\dxz23_audit_requal_input_20260715T221618Z\source_manifest_AUDIT_REQUAL_INPUT.json` | `ee47e67f8c9a006452ca39672f8165668381fa78e90999e05a249ac810868ac7` |
| Read-only lineage audit containing the individual live-preset hashes and effective report inputs | `41b540a2bfd78969494ecb03580e2ff0f7965694a717e267149717cabed6a3dd` |
| V5 risk-sizer source at audit time, `framework/include/QM/QM_RiskSizer.mqh` | `e75d7aaa48f3eae0d298ac67ba0db4404089f9b1abc7ea361fee7662c342fbed` |

The source manifest's 23 `risk_percent` values sum to 9.749998. Its EA-facing
expectations instead imply:

```text
effective sleeve risk = RISK_PERCENT * PORTFOLIO_WEIGHT
sum(declared RISK_PERCENT)                 = 9.749998
sum(implied effective sleeve risk)         = 0.633498663662
declared/effective factor                  = 15.3907159703214
```

For `10706:GBPUSD.DWX`, the manifest declares `RISK_PERCENT=0.056389` and
`PORTFOLIO_WEIGHT=0.005783`, implying only `0.000326097587` percentage points.
The observed live preset and native MT5 report use `PORTFOLIO_WEIGHT=1`; the
weight-field difference alone is `1 / 0.005783 = 172.9206294311x`. The old
fixed-money reference therefore cannot qualify the percent-risk economics.

## Repair applied to repository tooling

- The generic portfolio manifest builder now treats `RISK_PERCENT` as the
  absolute allocated sleeve risk and emits `PORTFOLIO_WEIGHT=1`.
- The one-off DXZ-23 manifest generator uses the same explicit contract.
- Per-sleeve cap excess is redistributed across eligible sleeves; an infeasible
  aggregate target fails instead of silently losing risk.
- Whole-book leverage scaling preflights every sleeve and rejects legacy
  double-scaled contracts before mutating the in-memory manifest.
- The as-live requalification runner must compare the source manifest's exact
  `set_file_expectation` with the bound preset. A mismatch is a technical fail,
  not a warning or a cost downgrade.

This repair only closes the application formula. It does not retroactively make
volatile legacy Q08 streams, fixed-risk shape KPIs or an unsealed draft valid
live-sized portfolio evidence. Admission and resize must still use the frozen,
per-stream source-risk contract in `portfolio_resize.py` and a passing Truth
Chain/freeze gate.

The canonical representation is now:

```json
{
  "RISK_PERCENT": "absolute_allocated_sleeve_risk",
  "PORTFOLIO_WEIGHT": 1.0,
  "effective_risk_formula": "RISK_PERCENT * PORTFOLIO_WEIGHT",
  "relative_weights_are_analytics_only": true
}
```

## Qualification consequence

The historical draft and its audit copy remain immutable evidence of the
defect, but are not valid qualification inputs. A replacement source manifest
must bind the exact live-preset contract, be sealed before the qualifying runs,
and be reproduced in two isolated run roots with independent receipts. Until
that chain exists, no DXZ-23 sleeve or book receives qualification from the old
manifest, even when its entries or native closes reproduce.
