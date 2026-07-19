# QM5_12580 FX Basket Q08 Requeue - 2026-07-19

## Decision

No qualifying unbuilt pair remains in the OWNER-requested 66-pair FX
cointegration scan. The sign-aware reproduction has seven strict rows and all
seven already have approved cards, registered EAs, compiled artifacts,
`basket_manifest.json`, fixed-risk setfiles, and pipeline history. Creating an
eighth card would therefore be either a duplicate or a below-screen candidate.

The existing `QM5_12580_fx-usd-exhaustion-reversal` sleeve was advanced instead.
It is a structural D1 basket over seven USD majors, has a manifest, uses
`RISK_FIXED=1000` / `RISK_PERCENT=0`, and its AUDUSD carrier has Q02 through Q07
PASS/PASS_LOWFREQ evidence.

## Infrastructure Repair Bound By This Change

The prior Q08 rows were `INFRA_FAIL`, not strategy failures. Their aggregate
reported:

- baseline PASS: 75 trades, PF 1.43;
- Q08.5 `INVALID`: `baseline setfile has no strategy parameters`;
- Q08.7 `INVALID`: zero distinct configurations because Q08.5 produced none.

The current AUDUSD baseline setfile now materializes all eight card/source input
defaults below the strategy-parameter marker. This change adds a focused
regression test that feeds the real setfile to the canonical Q08.5 parser and
locks:

- the seven-symbol manifest universe;
- D1 cadence;
- fixed-risk backtest mode;
- exactly eight perturbable strategy parameters.

`build_check.ps1 -SkipCompile` refreshed the canonical setfile build hashes for
the existing compiled EA and passed with zero failures and zero warnings.

## Guarded Queue Action

Command:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12580 --phase Q08
```

The idempotent cascade command requeued exactly one existing row:

- work item: `92e319b4-b40d-4db1-961c-e212c3f93d67`;
- phase/symbol: `Q08` / `AUDUSD.DWX`;
- state after enqueue: `pending`, unclaimed;
- promoted from Q07 PASS: `6d6501bb-af6c-490e-89f6-2c1dedce45dc`;
- created rows: 0; skipped rows: 0.

No dispatch tick or manual MT5 run was issued. The farm had nine active work
items at enqueue time, so this stopped at the paced queue boundary rather than
crossing the ten-job ceiling.

## Verification

- `python -m pytest framework/scripts/tests/test_qm5_12580_q08_readiness.py -q`:
  PASS, 1 test.
- `framework/scripts/build_check.ps1 -EALabel QM5_12580_fx-usd-exhaustion-reversal -SkipCompile`:
  PASS, 0 failures, 0 warnings.
- Build-check evidence:
  `D:/QM/reports/framework/21/build_check_20260719_165413.json`.
- Farm de-dup check after enqueue: one open `QM5_12580` Q08 row, the work item
  above.

## Safety

No new strategy rules, ML or banned indicators, risk calibration, live setfile,
`T_Live`, AutoTrading, deploy manifest, portfolio gate, `portfolio_admission`,
portfolio KPI, or Q08 contribution artifact was touched.
