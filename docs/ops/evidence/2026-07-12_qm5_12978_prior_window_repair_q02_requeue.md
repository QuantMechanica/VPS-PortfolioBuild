# QM5_12978 prior-window repair and Q02 requeue

Recorded 2026-07-12 on `agents/board-advisor`.

## Outcome

`QM5_12978` GBPUSD/USDCAD now implements the same fixed-window z-score
contract as the research scan that selected it. The repaired EA compiled with
zero errors and zero warnings, passed its scoped V5 checks, and has exactly one
new logical-basket Q02 work item:
`06539d34-2fef-4ac0-b11c-779de3d87a83`.

The row is `pending`, priority-tracked, and uses the canonical logical symbol
`QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1`. It was not dispatched because
`D:/QM/strategy_farm/state/FACTORY_OFF.flag` is present.

## Selection

The anchor baskets do not have current Q02 setup blockers. `QM5_12532` has
Q02 and Q04 PASS followed by Q05 FAIL; `QM5_12533` has Q02 PASS followed by
Q04 FAIL. Their historical ONINIT/NO_HISTORY rows are superseded component or
infrastructure attempts.

The sign-aware reproduction of the OWNER-requested 66-pair scan has seven
strict rows, all already built. The mission fallback therefore applies. The
chosen existing sleeve is the top-ranked strict row:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| GBPUSD/USDCAD | 0.26 | 1.55 | 9.04% | 19 | -1.140460 | 62 D1 bars |

Reproduction:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The method remains grounded in Ernest P. Chan, *Quantitative Trading*
(Wiley, 2009), Chapter 7, with the approved local extraction at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

## Structural repair

The pre-repair EA copied 60 closed observations, included the newest closed
spread in its own rolling mean and sample standard deviation, and then scored
that same spread against the self-containing window. The checked-in scan does
something materially different: it builds the window from bars `k-60..k-1`
and scores bar `k` outside that window.

The repair now:

- requests 61 closed observations;
- requires the GBPUSD and USDCAD D1 timestamps to match;
- scores observation 0 against calibration observations 1 through 60; and
- leaves beta, entry/exit thresholds, leg directions, risk, stops, and basket
  membership unchanged.

This is card-to-code parity work, not parameter tuning. No ML, banned
indicator, adaptive refit, grid, martingale, or pyramiding was added.

The earlier Q02 PASS (`b1656e8e-...`), Q03 PASS (`30907ff5-...`), and Q04 FAIL
(`bf98a2c5-...`) remain intact for audit, but they describe the old binary and
cannot promote the repaired one. Q02 is restarted from the approved review.

## Verification

- Clean detached compile: PASS, 0 errors, 0 warnings.
- Compile summary: `D:/QM/reports/compile/20260712_174101/summary.csv`.
- Preserved compile log:
  `D:/QM/reports/compile/20260712_174101/QM5_12978_edgelab-gbpusd-usdcad-cointegration.compile.log`.
- Scoped build check: PASS, 0 failures, 0 warnings;
  `D:/QM/reports/framework/21/build_check_20260712_174700.json`.
- Card schema lint: PASS for all three synchronized card mirrors.
- Build prerequisite guard: PASS.
- SPEC validation: PASS.
- Symbol-scope validation: `BASKET_OK`, 0 violations.
- Basket regressions: 32 passed, including a scoped guard for the repaired
  61-observation/60-prior-window contract.
- MQ5 SHA-256:
  `6d488217d24691c2afc53b1458b83bdbfe556fa822b93a835e7ebe0da5d643aa`.
- EX5 SHA-256:
  `feeec49bc9118abf4c1607b289f0d12f2e79fae11117a7885966768a966f3259`.

The backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; the manifest remains a two-symbol USD-account basket
with a USD 100,000 tester deposit. Its refreshed build hash is
`46bb2545c007f828aee66a02d9753c304020e88ec2d571410ca7d995779e431f`.

## Queue and safety

The canonical `enqueue-backtest` path created task
`14abceb9-2d86-4621-a5b0-f6f839598498` and one work item. The payload retains
the basket manifest, both symbols, host D1 contract, USD tester settings, and
the current 450-minute basket timeout. There is one pending/active Q02 row for
this EA and no duplicate leg rows.

At handoff the DB had 3 active rows against the mission ceiling of 7, so the
CPU ceiling was not reached. The explicit factory-off flag is the stop
boundary; no tester, dispatch tick, T_Live action, or AutoTrading action was
started. The online pre-mutation backup is
`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_12978_prior_window_requeue_20260712T174301Z.sqlite`,
and post-mutation `PRAGMA integrity_check` returned `ok`.

No portfolio gate, `portfolio_admission`, portfolio KPI, Q08 contribution,
T_Live manifest, or live setfile was touched.

Machine-readable evidence:
`artifacts/qm5_12978_prior_window_repair_q02_requeue_20260712.json`.
