# SP-C4 empirical execution/cost model — evidence readiness

Date: 2026-08-22 15:05 Europe/Berlin

Router task: `42d5b50b-209c-458a-88c0-5b2335a2bf27`

Scope: diagnosis and calibration-input readiness only; no Q06 thresholds or running pipeline criteria changed.

## Verdict

`NOT_READY_FOR_CALIBRATION_INPUT`.

The repository does not currently contain evidence sufficient to claim a venue-calibrated model for spread, slippage, fee, swap, reject, latency, and gap by symbol and session. The existing calibration has one measured symbol and 50 auto-stub keys. It has no session buckets and no swap, reject, or gap fields. Promoting those placeholders would violate the task constraint against invented commission/swap values.

## Reproducible evidence

Repository head observed: `28b41c2c38fffcc89d831809bcc434ea735f97ed`.

Primary calibration:

- `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`
- SHA-256: `DFAF14E5B35F2A4D592CA6521EFABB5E7ACC52AAAB69CA3BEAAF5420F0ECE061`
- Coverage: 51 keys total; 1 measured (`EURUSD.DWX`); 50 `auto_stub=true`.
- Session coverage: 0 keys.
- Swap coverage: 0 keys.
- Reject coverage: 0 keys.
- Gap coverage: 0 keys.

Raw measurement:

- `artifacts/qua-228/vps_slippage_latency_calibration_v2_measured_20260427_162544.json`
- SHA-256: `3D96A17CA19A11B14845E7269CFE9D7C345998893D7985EF8F2F70D74868E2C4`
- Size: 676 bytes.
- Method: `quote_drift_proxy_plus_broker_commission_schedule`.
- Venue/terminal: Darwinex-Live / T1.
- Symbol: `EURUSD.DWX` only.
- Samples: 800 spread, ping, and quote-drift proxy observations.
- Metrics present: commission schedule, latency, spread, and quote-drift slippage proxy.
- Metrics absent: actual order-to-fill slippage, swap, reject probability, gaps, order size, and session bucket.

Read-only filesystem inspection found MT5 binary deal/history stores, including Darwinex-Live T1 files through 2026-08-21. Those binary stores are not an authenticated, normalized per-order dataset and do not contain an independently usable requested-price timestamp in the evidence surface inspected here. They therefore cannot truthfully fill the missing fields without a governed exporter and binding contract.

## Calibration-input contract required

One normalized row per submitted order or held-position rollover is required with at least:

| Field | Purpose |
|---|---|
| venue/account class, symbol, server timestamp, session bucket | grouping identity |
| order id, deal id, side, order type, requested volume | authenticated event identity and size |
| requested price/time, accepted price/time, fill price/time | latency and slippage |
| bid/ask at request and fill | spread and adverse-selection context |
| retcode/reject class | reject probability |
| commission/fee/swap in account currency | realized costs |
| prior close/next open or discontinuity marker | gap size |
| exporter version, source hashes, account-currency conversion source | reproducibility |

Minimum publish rule per symbol/session/size bucket:

- Report sample count, median, p95, and p99 for spread, absolute/signed slippage, and latency.
- Report fee and swap from realized deal fields, never inferred from another symbol.
- Report rejects as submitted orders by retcode over all submitted orders.
- Report gaps from a declared quote/bar continuity rule with timezone and holiday handling.
- Mark any bucket with insufficient observations `UNMEASURED`; do not inherit an auto-stub.
- Keep this model as calibration input only. Applying it to Q06 thresholds requires a separate red/OWNER decision after the current rebuild wave.

## Focused verification commands

```powershell
$j = Get-Content -Raw framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json | ConvertFrom-Json
$p = $j.symbols.PSObject.Properties
@($p | Where-Object { -not $_.Value.auto_stub }).Count  # 1
@($p | Where-Object { $_.Value.auto_stub }).Count       # 50
@($p | Where-Object { $_.Value.PSObject.Properties.Name -contains 'sessions' }).Count # 0
```

## Required successor work

Build and govern a read-only MT5 history/order-event exporter, bind its output to source-file hashes, collect enough observations across declared symbol/session/size buckets, and then generate a versioned calibration artifact. Until that evidence exists, SP-C4 acceptance is not met and no numeric replacement model is authorized.
