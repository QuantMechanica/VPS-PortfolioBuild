# QUA-228 VPS Slippage/Latency Calibration Evidence

Timestamp (UTC): 2026-04-27T13:26:30Z
Terminal: T1
Server: Darwinex-Live
Account: 4000090541
Account mode: REAL

## Final calibration status

- `measurement_status=MEASURED`
- Method: `quote_drift_proxy_plus_broker_commission_schedule`

## Measured values (EURUSD -> EURUSD.DWX)

- samples: `800`
- latency ms: `avg=33.219`, `p95=33.219`
- spread points: `median=3.0`, `p95=4.0`
- slippage points (RTT quote-drift proxy): `avg=0.04`, `p95=0.0`
- commission cents per lot: `250.0`

## Sources

- MT5 log: `D:\QM\mt5\T1\MQL5\Logs\20260427.log`
  - `CAL2|status=OK|samples=800|...|slip_avg=0.040|slip_p95=0.000|commission_cents=250.000|...`
- Commission file: `D:\QM\mt5\T1\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt`
  - `CommissionValue=2.5000` for `Forex\*` and `Custom\Forex\*`
- Deal scan context: same log file shows `DEAL_SCAN|status=OK|total_deals=1`.

## Artifacts

- `D:\QM\reports\pipeline\calibration\vps_slippage_latency_calibration_v2_measured_20260427_162544.json`
- `D:\QM\reports\pipeline\calibration\QUA-228_VPS_SLIPPAGE_LATENCY_CALIBRATION_EVIDENCE_2026-04-27.md`
