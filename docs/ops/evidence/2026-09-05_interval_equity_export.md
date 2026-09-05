# Joint interval equity / positions export — frozen FTMO candidate pool

Date: 2026-09-05  
Task: `0af640f6-239e-4c18-a769-29c8c865160f`  
Result: **ABSTAIN for FTMO daily-loss and flat-at-target claims**

## Outcome

`tools/strategy_farm/portfolio/interval_equity_export.py` now produces a synchronized, hash-bound interval ledger from the durable artifacts already emitted by Q08/run_smoke:

- balance is reconstructed from complete `TRADE_CLOSED` lifecycle net P&L;
- position occupancy and interval opening counts are reconstructed from each lifecycle's `entry_time` and close `time`;
- every `EQUITY_SNAPSHOT` is retained at its exact logger event timestamp;
- endpoint equity is populated only when an exact snapshot timestamp equals a grid endpoint;
- interval-minimum equity and pending-order state remain null because the existing artifacts do not contain them;
- the joint row is a weighted research superposition with one explicit book starting balance, not an admitted roster or executable allocation.

No interpolation or closing-P&L substitution is used for open-equity or pending-order claims. The January 2024 run therefore returns `status=ABSTAIN`, `daily_loss=ABSTAIN_MISSING_INTERVAL_MIN_EQUITY`, and `flat_at_target=ABSTAIN_MISSING_PENDING_ORDERS_AND_ENDPOINT_EQUITY`.

## Reproduction and schema

```powershell
cd C:/QM/repo
python tools/strategy_farm/portfolio/interval_equity_export.py `
  --spec docs/ops/evidence/2026-09-05_interval_equity_export_spec.json `
  --output docs/ops/evidence/2026-09-05_interval_equity_export.json
```

Spec SHA-256: `56a283e5fdcd4ee7f938a97729d60e80693606b1e49810798994624988f5c4c4`  
Output SHA-256: `d4e30471248fa03115e7682e525765d2544dd37d9815d02494d1b7d6fb1665a3`

The output schema is `qm.interval-equity-export/v1`. Each interval contains:

- `ts_utc`, `interval_start_utc`;
- `joint.balance`, `joint.equity`, `joint.interval_min_equity`, `joint.open_positions`, `joint.opened_positions`, and `joint.pending_orders`, each with an evidence-basis label;
- the same fields per sleeve;
- `equity_observation` with its exact `observed_at_utc`, value, prior-day key, and whether it is an exact endpoint or merely an event within the interval;
- input path, byte count, and SHA-256 under `coverage`.

Money is serialized as two-decimal strings; non-finite numbers, duplicate JSON keys, missing files, non-monotonic snapshots, malformed lifecycles, and misaligned grids are refused.

## Coverage of the eight candidates

The worked export uses daily UTC endpoints from `2024-01-01T00:00:00Z` through `2024-02-01T00:00:00Z` (32 rows). The code accepts any positive minute grid, including M5; daily output was selected to keep the durable evidence compact. A finer grid does not create equity observations that the inputs never recorded.

| Sleeve | Closed lifecycles | Equity snapshots, full run | Snapshots in month | Exact daily endpoints | Balance | Endpoint equity | Interval minimum | Open positions | Pending orders |
|---|---:|---:|---:|---:|---|---|---|---|---|
| 10706 / GBPUSD | 360 | 2,119 | 22 | 0 | Reconstructed | Partial event-time only | Missing | Reconstructed | Missing |
| 11421 / EURUSD | 91 | 1,974 | 23 | 0 | Reconstructed | Partial event-time only | Missing | Reconstructed | Missing |
| 11422 / USDCAD | 195 | 1,970 | 22 | 0 | Reconstructed | Partial event-time only | Missing | Reconstructed | Missing |
| 11910 / NZDUSD | 63 | 1,898 | 20 | 0 | Reconstructed | Partial event-time only | Missing | Reconstructed | Missing |
| 13054 / XTIUSD | 82 | 1,966 | 22 | 0 | Reconstructed | Partial event-time only | Missing | Reconstructed | Missing |
| 1537 / XAGUSD | 96 | 1,962 | 22 | 0 | Reconstructed | Partial event-time only | Missing | Reconstructed | Missing |
| 20048 / XTIUSD | 60 | 1,966 | 22 | 0 | Reconstructed | Partial event-time only | Missing | Reconstructed | Missing |
| 21505 / XAGUSD | 116 | 2,021 | 22 | 0 | Reconstructed | Partial event-time only | Missing | Reconstructed | Missing |

“Reconstructed open positions” means positions whose complete lifecycle later closed in the tester stream. It does not prove absence of an unclosed/foreign position. Pending orders are never inferred from their later fills.

## Input bindings

| Sleeve | Trade stream SHA-256 | Q08 logger SHA-256 |
|---|---|---|
| 10706 / GBPUSD | `71fb35b8f8539356f511609a4d1dfb06571f85b19b60de6647e907ec891e34f7` | `3a20dcacad40925c9dbfb30ac99f68a3bb2564b6b2e34cd9ca24fa2db34c17c2` |
| 11421 / EURUSD | `e9d0a9ef831f156f0f67e5bf1140d7e57702c3923a4ff47b5548847957d7c0c1` | `a661b2659371a81ca02904ace1f0b2a00dd69818d9edd5d4e015720cf1cb8473` |
| 11422 / USDCAD | `7ce6cc3ec2f1279c18e8601119e3319375d5d3fa1ce4cf95cf33e05eefc33198` | `0073ff555a002c513982426a97c5d0194d5314a52e474a95f277fe0ec45b17af` |
| 11910 / NZDUSD | `555bbee205432c62f06da96a0a291d14028dc5c88e3fa8b2792ad62bc5d885b0` | `3bc435412c83288423c46105760fd80213f03ea4fc75117c1f90cc7cb6ddfc66` |
| 13054 / XTIUSD | `67d4fe2cef067e041f01d10e5e6c98312a32b43683eee2da3d0bfa9af296955b` | `d59deb82cef87e3ab4d378aadc347e0718eab2ef0c17a20837418c3e314631bc` |
| 1537 / XAGUSD | `1885c21e4c895827c79ff3d55849308ab4ee5c0db96a7d576cd652dc3eff8658` | `e3c46ebdcf9e0bd54e2945c216f0c514d950d0af02d8f16b935bce28757933e0` |
| 20048 / XTIUSD | `a792e2635250bcd6df5aa4a290359b54e6d5ffe8fbe10e34d143b74dfe0e8d55` | `138160c571613674d53bb63d828d0d27e17d8330ea4da8836f5167774d9e8bf6` |
| 21505 / XAGUSD | `243804faaf0050f5482b9a4aac8f9eb0dcd552de1c2c139a486f0bcfa46b94c1` | `68ea28ce6d6bd336cfbc739c2869cc09c6764fa84ddaff2cd567ac7a502db4e7` |

Full absolute paths, sizes, first/last lifecycle timestamps, and first/last snapshot timestamps are embedded in the output's `coverage` records. These are the exact streams sealed in the 2026-09-04 current-pool inventory and their corresponding current Q08 baseline logger exports.

## Worked January 2024 FTMO check

The unweighted research superposition starts this window at a reconstructed closed balance of `174,661.36`, because it includes all closed P&L before January. During the month its closed-balance diagnostic ranges from `170,379.61` to `174,661.36` and ends at `173,410.48`. The largest visible adjacent endpoint decline is `1,236.50` (from `171,616.11` on 17 January to `170,379.61` on 18 January). There are reconstructed open positions at 12 of the 32 endpoints.

That arithmetic is **not** an FTMO daily-loss pass:

- the official daily floor is anchored to Prague midnight balance and tests all equity, including open P&L, swaps, and commissions;
- this compact run is UTC-midnight aligned and has no tick/event-complete interval minimum;
- existing snapshots occur inside the intervals, not exactly at the endpoints, and are generated separately in eight tester accounts;
- pending orders are unknown.

Likewise, the balance is already above a nominal USD 110,000 phase-1 target at the start of the selected month, but that cannot establish a target hit. A valid target check needs the first crossing on a synchronized account path, exact endpoint equity, all positions closed, all pending orders absent, and the other rule conditions. The export correctly reports `ABSTAIN` rather than turning a closing-balance diagnostic into pipeline or purchase evidence.

## Verification

```text
python -m pytest -q tools/strategy_farm/tests/test_interval_equity_export.py
4 passed

python -m py_compile tools/strategy_farm/portfolio/interval_equity_export.py
PASS
```

The synthetic tests cover balance/occupancy reconstruction, exact-versus-within-interval snapshot labeling, source hash binding, missing pending/minimum fields, duplicate-key refusal, and non-finite-number refusal. No evaluator policy, live telemetry, T_Live, AutoTrading, or terminal process was changed.

