# QM5_20193 EURUSD/USDCAD cointegration — Q02 enqueue

Date: 2026-08-01 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20193_eurusd-cad-coint`

## Outcome

The newly built EURUSD/USDCAD D1 fixed-beta cointegration sleeve was recorded
successfully and enqueued once as a logical two-leg package. Work item
`0610ebc5-fbb0-4658-8455-2574ee98b277` was observed `pending`, attempt 0,
unclaimed, with no evidence or verdict.

The governed recorder selected the logical setfile and skipped the physical
EURUSD host setfile with
`basket_manifest_logical_setfile_preferred`. A read-only query confirmed one
and only one `QM5_20193` work-item row.

## Bound payload

- Symbol: `QM5_20193_EURUSD_USDCAD_COINTEGRATION_D1`
- Host / timeframe: `EURUSD.DWX` / D1
- Basket symbols: `EURUSD.DWX`, `USDCAD.DWX`
- Tester currency / deposit: USD / 100,000
- Setfile:
  `framework/EAs/QM5_20193_eurusd-cad-coint/sets/QM5_20193_eurusd-cad-coint_QM5_20193_EURUSD_USDCAD_COINTEGRATION_D1_D1_backtest.set`
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- Timeout: 450 minutes
- Priority track: true

## Capacity and safety

- Path-aware observation: three factory terminals (`T1`, `T10`, `T2`) at
  `2026-08-01T10:13:44Z`, below the seven-terminal CPU ceiling.
- T_Live: separately observed and excluded; untouched.
- `FACTORY_OFF.flag`: absent.
- No manual dispatch, Q02 tester launch, terminal control, or queue sweep.
- No portfolio gate, T_Live artifact, live setfile, or AutoTrading state was
  changed.

The earlier Q01 smoke is deterministic setup evidence only; this handoff does
not claim Q02 performance or certification.
