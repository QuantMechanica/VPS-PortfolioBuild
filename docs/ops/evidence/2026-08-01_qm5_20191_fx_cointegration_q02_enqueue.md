# QM5_20191 EURUSD/USDCHF cointegration — Q02 enqueue

Date: 2026-08-01 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20191_eurusd-chf-coint`

## Outcome

The newly built EURUSD/USDCHF D1 cointegration sleeve was enqueued once as a
logical two-leg package. Work item
`5cd924e8-af79-4f0e-9699-846dcf72e5b5` was immediately `pending`, attempt 0,
unclaimed, with no evidence or verdict.

## Capacity and queue guards

- Path-aware precheck: three factory terminals (`T2`, `T4`, `T8`) at
  `2026-08-01T03:07:37Z`, below the seven-terminal ceiling.
- T_Live: separately observed and excluded; untouched.
- `FACTORY_OFF.flag`: absent.
- Pre-enqueue QM5_20191 rows: zero.
- Targeted dry run: one logical candidate; physical host skipped.
- Applied rows: exactly one; no stranded or deferred rows changed.

The first attempts failed closed while the global farm mutation lock was busy.
The successful apply ran only after entering that same lock and rechecking the
capacity/Factory-OFF guards. The lock was not removed or bypassed.

## Bound payload

- Symbol: `QM5_20191_EURUSD_USDCHF_COINTEGRATION_D1`
- Host / timeframe: `EURUSD.DWX` / D1
- Basket symbols: `EURUSD.DWX`, `USDCHF.DWX`
- Tester currency / deposit: USD / 100,000
- Setfile:
  `framework/EAs/QM5_20191_eurusd-chf-coint/sets/QM5_20191_eurusd-chf-coint_QM5_20191_EURUSD_USDCHF_COINTEGRATION_D1_D1_backtest.set`
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- Timeout: 450 minutes
- Priority track: true

## Safety

- No manual dispatch, tester launch, or terminal control occurred.
- No portfolio gate or T_Live artifact changed.
- No live setfile or deploy artifact exists for this EA.
