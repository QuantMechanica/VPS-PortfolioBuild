# QM5_20058 XCU Three-Month Momentum Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20058_xcu-tsmom3m`
- Source: Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
  Economics* 104(2), 228-250.

## Decision

Build one low-frequency industrial-commodity sleeve on `XCUUSD.DWX`: at the
first D1 bar of each broker month, trade the sign of the prior completed
63-D1 log return, use a frozen 3.5 ATR hard stop, and renew at the next month.
This is distinct from the existing index, precious-metal, XNG, copper
Donchian, copper four-week reversal, and commodity relative-value builds.

## Validation

- Strategy-card schema lint: PASS; no missing sections or ML hits.
- EA ID `20058`; active magic `200580000`; resolver regenerated and verified.
- Strict compile: PASS, 0 errors and 0 warnings.
- EX5 SHA256:
  `66225A23F3DAD3828B1E1F29A82D69326F2F8451305ABC63E631B089BEA136C5`.
- Backtest set SHA256:
  `B4E4A79799C995A12049C8E648E6642A8B41B73343D4D12BC5DB92416CC738DD`.
- Backtest mode is `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Review task: `3ca35e49-3194-4575-8174-d37f1228f6ad`.
- Q02 task: `57ea687d-23b3-48b1-8c4f-14a7df4ed41c`, pending. The enqueue
  created no immediate work-item rows; normal factory reconciliation owns
  work-item materialization and dispatch.

No backtest was manually started. No T_Live, AutoTrading, deploy manifest,
portfolio gate, portfolio KPI, or T_Live manifest was touched.
