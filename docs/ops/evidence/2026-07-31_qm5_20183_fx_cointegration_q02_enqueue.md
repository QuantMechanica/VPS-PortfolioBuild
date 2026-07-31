# QM5_20183 GBPUSD/USDCHF cointegration — Q02 enqueue

Date: 2026-07-31 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20183_gbpusd-chf-coint`

## Outcome

The existing approved GBPUSD/USDCHF D1 cointegration basket was advanced into
Q02 as one logical package. The immediate post-enqueue state was `pending`,
attempt 0, unclaimed. No tester was manually launched and no gate verdict is
claimed.

## Non-duplicate boundary

The governed positive-beta anchors are not blocked at Q02:

- `QM5_12532` has logical-basket Q02 PASS and later Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS and later Q04 FAIL.

The repository duplicate guard also records builds and terminal Q02 evidence
for every governed strict scan qualifier. The valid mission fallback was
therefore the already-built `QM5_20183`, which had zero farm work items before
this action.

## Queue-boundary repair

The legacy never-tested sweep initially proposed the physical host
`GBPUSD.DWX`, despite the EA's `basket_manifest.json`. That would have
misrepresented the two-leg package as a single-symbol Q02 row.

Commit `72fc367e5` changes the sweep to:

- validate a present basket manifest fail-closed;
- select only its canonical logical-basket setfile;
- preserve host, leg, tester-currency, deposit, and basket-scope payload;
- allow the validated logical symbol through the `.DWX` queue guard; and
- explicitly skip physical-leg/host setfiles.

Regression coverage:

- `tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py`: PASS
- basket work-item suite plus mutation-lock writer check: 17 PASS
- Python compile and `git diff --check`: PASS

The targeted dry run produced one candidate:
`QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1`, with the physical
`GBPUSD.DWX` setfile skipped.

## Paced enqueue

The final pre-enqueue scan at `2026-07-31T11:24:14+02:00` observed five
factory terminals (`T1`, `T2`, `T6`, `T8`, and `T10`) against the documented
seven-terminal ceiling. The separate pre-existing T_Live process was observed
only to exclude it. `FACTORY_OFF.flag` was absent.

The targeted apply created:

- Work item: `564a8012-bb2b-4edf-a9f1-acd04b177d64`
- Phase/kind: `Q02` / `backtest`
- Logical symbol/timeframe:
  `QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1` / D1
- Canonical setfile:
  `framework/EAs/QM5_20183_gbpusd-chf-coint/sets/QM5_20183_gbpusd-chf-coint_QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1_D1_backtest.set`
- Created: `2026-07-31T11:24:26+02:00`
- Immediate state: `pending`, attempt 0, unclaimed, no evidence

Manifest execution metadata remains:

- Host: `GBPUSD.DWX`
- Companion: `USDCHF.DWX`
- Tester currency/deposit: USD / 100,000
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

## Safety

- No portfolio admission, KPI, or Q08 contribution artifact changed.
- No T_Live file, manifest, terminal, or AutoTrading state changed.
- No live setfile or deploy artifact was created.
- No manual smoke test, backtest, terminal dispatch, or terminal launch was
  performed.
