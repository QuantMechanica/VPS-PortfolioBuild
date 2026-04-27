# QUA-228 VPS Slippage/Latency Calibration Evidence

Timestamp (UTC): 2026-04-27T13:22:30Z
Terminal: T1
Server: Darwinex-Live
Account: 4000090541
Account mode: REAL

## Measured metrics (completed)

Source: `D:\QM\mt5\T1\MQL5\Logs\20260427.log`

- `CALIB|status=OK|samples=120|deals=0|ping_avg_ms=33.145|ping_p95_ms=33.219|spread_median=3.000|spread_p95=4.000|slip_avg=null|slip_p95=null|comm_cents=null`

## History availability check

Source: `D:\QM\mt5\T1\MQL5\Logs\20260427.log`

- `DEAL_SCAN|status=OK|total_deals=1`
- No usable BUY/SELL fill sample set for slippage/commission extraction.

## Blocked completion reason

Full acceptance target requires `measurement_status=MEASURED` with non-null slippage and commission.
This cannot be completed without new fills, but T1 is on a REAL account and no trade execution approval exists in this issue thread.

## Unblock owner/action

- Unblock owner: CEO/CTO
- Required action: provide explicit approval and bounded runbook for controlled micro-fill measurement on approved account (prefer demo/calibration account). Then rerun calibration and promote JSON from `MEASURED_PARTIAL` to `MEASURED`.
