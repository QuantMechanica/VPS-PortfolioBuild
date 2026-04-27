# QUA-228 Calibration Measurement - 2026-04-27

Status: partial measurement completed on T1.

## Measured on T1 Darwinex-Live

- Server-time timestamp: `2026-04-27 16:17:32`
- Source symbol: `EURUSD` (mapped to calibration key `EURUSD.DWX`)
- Live sample count: `120`
- Latency ms: `avg=33.145`, `p95=33.219`
- Spread points: `median=3.0`, `p95=4.0`

## Missing fields and reason

- `slippage_points` and `commission_cents_per_lot` remain `null`
- Reason: `0` EURUSD deal fills found in 30-day history window on T1 account (`deals_used_for_slippage=0`)

## Evidence

- Raw artifact: `artifacts/qua-228/vps_slippage_latency_calibration_v2_raw_20260427_161732.json`
- Pipeline evidence note: `D:\QM\reports\pipeline\calibration\QUA-228_VPS_SLIPPAGE_LATENCY_CALIBRATION_EVIDENCE_2026-04-27.md`
- MT5 log proof: `D:\QM\mt5\T1\MQL5\Logs\20260427.log` line with `CALIB|status=OK`

## Account-mode check

- T1 account mode verified as `REAL`:
- `ACCOUNT_MODE|mode=REAL|login=4000090541|server=Darwinex-Live|company=Tradeslide Trading Tech Limited`
- Deal-history scan (365 days): `DEAL_SCAN|status=OK|total_deals=1`
- No usable BUY/SELL fill sample set for slippage extraction.

## Unblock

- Owner: CEO/CTO
- Action: authorize and schedule controlled micro-fill measurement run on Darwinex demo or designated calibration account so slippage/commission can be measured from real fills and JSON can be promoted from `MEASURED_PARTIAL` to `MEASURED`.
