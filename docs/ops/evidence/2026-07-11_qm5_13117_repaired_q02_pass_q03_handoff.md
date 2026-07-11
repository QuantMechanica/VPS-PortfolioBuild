# QM5_13117 Repaired EURGBP/AUDJPY Q02 PASS and Q03 Handoff

Date: 2026-07-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: one existing low-frequency, market-neutral FX cointegration basket. No
live or portfolio-gate action.

## Outcome

The repaired `QM5_13117_eurgbp-audjpy` binary passed its required fresh Q02
baseline, and its one pre-existing invalidated Q03 row was reopened in place.
No duplicate EA, card, Q02 row, or Q03 row was created.

- Logical symbol: `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`.
- Traded legs: `EURGBP.DWX` and `AUDJPY.DWX`.
- Conversion/history dependencies: `GBPUSD.DWX` and `USDJPY.DWX`.
- Q02 work item: `fb649d4a-3a9e-42e8-ae99-b492d2c65f5e`.
- Q03 work item: `dc01fd4d-0f8f-414a-a6b1-80441204fefc`, now pending and
  unclaimed.

## Selection and De-duplication

The published 66-pair scan has only two hard survivors, both already built and
past Q02:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, Q04 FAIL.

The sign-aware reproduction adds five strict rows. All seven rows have EA
folders: `QM5_12978`, `QM5_12533`, `QM5_12532`, `QM5_13003`, `QM5_13106`,
`QM5_13117`, and `QM5_13119`. The approved-card/EA reconciliation also found
no approved cointegration card without a build. The mission fallback therefore
applied: advance the higher-ranked existing EURGBP/AUDJPY sleeve rather than
invent a weaker source threshold or duplicate a pair.

The reproduction command remains:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

For EURGBP/AUDJPY it records DEV net Sharpe `0.4168`, OOS net Sharpe `0.8919`,
OOS return `4.4752%`, 20 OOS state changes, fixed beta
`-0.12202869296345396`, and a 36.84-day half-life. The negative, small hedge
and cross-bloc exposure remain explicit caveats; Q02 is a setup/baseline gate,
not portfolio admission.

## Repaired Binary Preflight

Commit `72237d508` corrected a card-to-code mismatch: the newest closed spread
had been included in the same 60-bar calibration window used to score it. The
repaired EA requests 61 aligned observations, scores index 0, and calibrates on
indices 1 through 60. Beta, thresholds, symbols, and risk are unchanged.

- EX5 SHA256:
  `aa8ff930a973632b0dbd9b2694ccf20869f441a4fa7c9eac670339800eb199ef`.
- Setfile SHA256:
  `c584bcf5b274ae293ebd0ea60ba9ba7ea0ca5a4afda09da2fb50423322531b83`.
- Setfile build hash:
  `4d9aee1701ea38dfa655d983b803ecaba51d6d7f0cd2bef59547b53b63f085d3`.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`,
  `environment=backtest`.

These hashes matched the repaired Q02 row before its targeted claim.

## Q02 Result

The exact pending repaired row was claimed once by the targeted Factory-OFF
worker on T3. It ran Model 4 over 2018-07-02 through 2022-12-31.

| Field | Value |
|---|---:|
| Status / verdict | `done` / `PASS` |
| Tester trades | 112 |
| Profit factor | 1.46 |
| Net profit | 4,991.52 |
| Drawdown | 3,049.81 (2.86%) |
| Attempted / non-OK runs | 1 / 0 |
| ONINIT failure | false |
| Real-tick marker | true |
| Log bomb | false |

Canonical evidence:
`D:/QM/reports/work_items/fb649d4a-3a9e-42e8-ae99-b492d2c65f5e/QM5_13117/20260711_031904/summary.json`.

The repaired result differs materially from the superseded pre-repair result
(112 vs. 104 trades; PF 1.46 vs. 1.75), confirming that the new Q02 actually
tested the corrected signal window.

## Q03 Handoff

The standalone Q02 row has no parent task, so it cannot auto-cascade. After an
online SQLite backup, the one invalidated Q03 row was reopened in place with
the repaired Q02 evidence, binary/setfile hashes, basket dependencies,
RISK_FIXED contract, date window, T5 avoidance, and priority context.

- Q03 work item: `dc01fd4d-0f8f-414a-a6b1-80441204fefc`.
- Parent task: `caf51649-e9fa-4db9-ba79-53632a514992`.
- State: `pending`, unclaimed, attempt 0.
- Open Q03 rows for this EA/logical symbol/setfile: exactly one.
- Event: `repaired_q02_pass_q03_requeued`, ID `246685`.
- Database backup:
  `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_13117_repaired_q03_handoff_20260711T040130Z.sqlite`.
- Live DB integrity: `ok`; backup integrity: `ok`.

Factory OFF remained in force and Q03 was not dispatched. After Q02, no T1-T5
terminal or terminal worker remained running, so the backtest CPU ceiling was
not reached.

## Safety

- No `T_Live` process, path, manifest, or AutoTrading state was changed.
- No live setfile or deploy manifest was created or changed.
- No portfolio gate, `portfolio_admission`, `_kpi`, or `_q08_contribution`
  path was touched.
- No ML, banned indicator, grid, martingale, pyramiding, or structural rule
  change was introduced.

Machine-readable evidence:
`artifacts/qm5_13117_repaired_q02_pass_q03_handoff_20260711.json`.
