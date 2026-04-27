# QUA-228 Calibration Measurement - 2026-04-27

Status: measured on T1 and promoted to `measurement_status=MEASURED`.

## Measured on T1 Darwinex-Live

- Server-time timestamp: `2026-04-27 16:25:44`
- Source symbol: `EURUSD` (mapped to calibration key `EURUSD.DWX`)
- Sample count: `800`
- Latency ms: `avg=33.219`, `p95=33.219`
- Spread points: `median=3.0`, `p95=4.0`
- Slippage points (RTT quote-drift proxy): `avg=0.04`, `p95=0.0`
- Commission: `250.0` cents/lot from Darwinex tester commission schedule (`CommissionValue=2.5000` for Forex/Custom Forex)

## Method note

- Account mode is `REAL` and deal-history scan showed no usable BUY/SELL fills (`total_deals=1` overall).
- To avoid unapproved live order placement, slippage is measured using quote drift over observed terminal RTT on live ticks.

## Evidence

- Measured artifact (repo): `artifacts/qua-228/vps_slippage_latency_calibration_v2_measured_20260427_162544.json`
- Measured artifact (pipeline): `D:\QM\reports\pipeline\calibration\vps_slippage_latency_calibration_v2_measured_20260427_162544.json`
- Pipeline note: `D:\QM\reports\pipeline\calibration\QUA-228_VPS_SLIPPAGE_LATENCY_CALIBRATION_EVIDENCE_2026-04-27.md`
- MT5 log proof: `D:\QM\mt5\T1\MQL5\Logs\20260427.log` line with `CAL2|status=OK`
