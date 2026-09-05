# FTMO/DXZ spread and execution pairing inventory — current frozen pool

Date: 2026-09-05  
Task: `b8a0676b-006c-4f3e-9897-47ee87af30b3`  
Scope: read-only inventory; no terminal launch, purchase, live action, Q verdict, or book change

## Result

**ABSTAIN — no current-pool symbol has a complete, timestamp-identical FTMO and DXZ M1 spread pair.** Consequently no per-session FTMO-vs-DXZ median/p95 delta is reported. The repository calibrator correctly refuses incomplete pairs; cross-symbol substitution would fabricate execution evidence.

The frozen census is eight sleeves and six distinct symbols: `10706/GBPUSD`, `11421/EURUSD`, `11422/USDCAD`, `11910/NZDUSD`, `13054/XTIUSD`, `1537/XAGUSD`, `20048/XTIUSD`, and `21505/XAGUSD`. These are research candidates only; none is an admitted book sleeve.

## Available series and containers

`Period` for an HCC row is the container year, not a decoded first/last quote claim. HCC containers are acquisition inputs; only `qm.m1-spread-row/v1` projections are directly consumable by `ftmo_spread_calibration.py`.

| Series / venue | Symbol | Period or observed coverage | Source path | SHA-256 | Usable now |
|---|---|---|---|---|---|
| FTMO demo HCC | GBPUSD | container 2026 | `D:/QM/mt5/FTMO_STREAM1/Bases/FTMO-Demo/history/GBPUSD/2026.hcc` | `823a9edb6dc6d4350188878ae76d9da485cf9265e81145e70868ebd43e3f9338` | Source only; no M1 projection |
| FTMO demo HCC | EURUSD | container 2026 | `D:/QM/mt5/FTMO_STREAM1/Bases/FTMO-Demo/history/EURUSD/2026.hcc` | `a8d4d82117c6d9cb586f397ba8c204e5da6727695bf1b06600a9db3970bba2ff` | Source only; no M1 projection |
| FTMO demo HCC | USDCAD | lookup 2026-09-05 | `D:/QM/mt5/FTMO_STREAM{1,2}/Bases/FTMO-Demo/history/USDCAD/` | `MISSING` | No |
| FTMO demo HCC | NZDUSD | lookup 2026-09-05 | `D:/QM/mt5/FTMO_STREAM{1,2}/Bases/FTMO-Demo/history/NZDUSD/` | `MISSING` | No |
| FTMO demo HCC | XTIUSD | lookup 2026-09-05 | `D:/QM/mt5/FTMO_STREAM{1,2}/Bases/FTMO-Demo/history/XTIUSD/` | `MISSING` | No |
| FTMO demo HCC | XAGUSD | lookup 2026-09-05 | `D:/QM/mt5/FTMO_STREAM{1,2}/Bases/FTMO-Demo/history/XAGUSD/` | `MISSING` | No |
| DXZ custom HCC | GBPUSD.DWX | container 2026 | `C:/QM/mt5/DXZ_Truth_1/Bases/Custom/history/GBPUSD.DWX/2026.hcc` | `8c408f4a38a1cb4abc033ee9e028168d67263a6c7817916d708d834ecb8bec4a` | Source only; no M1 projection |
| DXZ custom HCC | EURUSD.DWX | container 2026 | `C:/QM/mt5/DXZ_Truth_1/Bases/Custom/history/EURUSD.DWX/2026.hcc` | `bfe6f5f971fd97c69d0c68a6fc1abb04c1990d5049b75a15c1df95762f4d3eeb` | Source only; no M1 projection |
| DXZ custom HCC | USDCAD.DWX | container 2026 | `C:/QM/mt5/DXZ_Truth_1/Bases/Custom/history/USDCAD.DWX/2026.hcc` | `88ee7bd65cd33926e1d3c85a68b43d2def4d6859024ac2405d86be2ab09ad3ec` | Source only; no M1 projection |
| DXZ custom HCC | NZDUSD.DWX | container 2025 | `D:/QM/archive/Custom_master/history/NZDUSD.DWX/2025.hcc` | `8099447dec980f968e6699bd198696a946c4335b256ba38fedb7a11bd7ac5248` | Historical source only; not contemporaneous |
| DXZ custom HCC | XTIUSD.DWX | container 2026 | `C:/QM/mt5/DXZ_Truth_1/Bases/Custom/history/XTIUSD.DWX/2026.hcc` | `277f5c564ebf3711bb8f9695f5bff4c870eedb5f3bbf08ff41d8fe39acd7787b` | Source only; no M1 projection |
| DXZ custom HCC | XAGUSD.DWX | container 2025 | `D:/QM/archive/Custom_master/history/XAGUSD.DWX/2025.hcc` | `df592ccc56e0f638dbb7e8187d3a76dfd8d14d7d92006214a41100cc678f8a18` | Historical source only; not contemporaneous |
| FTMO M1 projection | XAUUSD | 2026-04-28 07:55Z–2026-08-07 23:49Z; 100,000 rows | `D:/QM/reports/ftmo_spread_calibration/XAUUSD_FTMO_M1.jsonl` | `257549cd0116c373eabe0e12ab0ab8971d042a19c6a3f8d2dcfdc1a80aa73066` | Valid projection, outside current pool; paired DXZ projection missing |
| FTMO M1 projection | GER40.cash | 2026-04-24 18:38Z–2026-08-07 22:49Z; 100,000 rows | `D:/QM/reports/ftmo_spread_calibration/GER40_cash_FTMO_M1.jsonl` | `d1b9a4af51fb9937253f1d05e77956217819e6d2cc70a871838657838a1a94cf` | Valid projection, outside current pool; paired DXZ projection missing |
| DXZ measured quote-drift proxy | EURUSD.DWX | 800 samples at 2026-04-27 16:25:44 server time | `artifacts/qua-228/vps_slippage_latency_calibration_v2_measured_20260427_162544.json` | `3d96a17ca19a11b14845e7269cfe9d7c345998893d7985ef8f2f70d74868e2c4` | Unpaired point-in-time proxy only |

The two projected FTMO files are bound by their coverage sidecars: `XAUUSD_FTMO_coverage.json` (`c7f9203e1604aed035e902362736f007678e3c751bc633a71ae3c160c8e4528c`) and `GER40_cash_FTMO_coverage.json` (`14329c8efd228d84ea8993179129e46bbe20f7aadfe1156835a22c9df5ce4b2d`). Their symbols cannot stand in for any of the six current-pool symbols.

## Frozen DXZ execution streams

These are realized tester trade/fill ledgers, not quote-time spread series. They support execution and closing-P&L inventory but cannot produce synchronized venue spread deltas.

| Sleeve | Recorded close-label span | Path | SHA-256 |
|---|---|---|---|
| 10706 / GBPUSD | 2018-03-16–2025-12-26 | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/10706_GBPUSD_DWX.jsonl` | `71fb35b8f8539356f511609a4d1dfb06571f85b19b60de6647e907ec891e34f7` |
| 11421 / EURUSD | 2018-05-11–2025-12-11 | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/11421_EURUSD_DWX.jsonl` | `e9d0a9ef831f156f0f67e5bf1140d7e57702c3923a4ff47b5548847957d7c0c1` |
| 11422 / USDCAD | 2018-03-02–2025-12-26 | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/11422_USDCAD_DWX.jsonl` | `7ce6cc3ec2f1279c18e8601119e3319375d5d3fa1ce4cf95cf33e05eefc33198` |
| 11910 / NZDUSD | 2018-03-23–2025-06-05 | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/11910_NZDUSD_DWX.jsonl` | `555bbee205432c62f06da96a0a291d14028dc5c88e3fa8b2792ad62bc5d885b0` |
| 13054 / XTIUSD | 2018-03-02–2025-12-30 | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/13054_XTIUSD_DWX.jsonl` | `67d4fe2cef067e041f01d10e5e6c98312a32b43683eee2da3d0bfa9af296955b` |
| 1537 / XAGUSD | 2018-11-02–2024-12-06 | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/1537_XAGUSD_DWX.jsonl` | `1885c21e4c895827c79ff3d55849308ab4ee5c0db96a7d576cd652dc3eff8658` |
| 20048 / XTIUSD | 2018-04-02–2025-12-26 | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/20048_XTIUSD_DWX.jsonl` | `a792e2635250bcd6df5aa4a290359b54e6d5ffe8fbe10e34d143b74dfe0e8d55` |
| 21505 / XAGUSD | 2018-07-27–2025-09-26 | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/21505_XAGUSD_DWX.jsonl` | `243804faaf0050f5482b9a4aac8f9eb0dcd552de1c2c139a486f0bcfa46b94c1` |

## Calibration and slippage result

| Current-pool symbol | FTMO projected M1 | DXZ projected M1 | Exact common minutes | FTMO median/p95 by session | DXZ median/p95 by session | Verdict |
|---|---:|---:|---:|---|---|---|
| GBPUSD | 0 | 0 | 0 | MISSING | MISSING | ABSTAIN |
| EURUSD | 0 | 0 | 0 | MISSING | MISSING | ABSTAIN |
| USDCAD | 0 | 0 | 0 | MISSING | MISSING | ABSTAIN |
| NZDUSD | 0 | 0 | 0 | MISSING | MISSING | ABSTAIN |
| XTIUSD | 0 | 0 | 0 | MISSING | MISSING | ABSTAIN |
| XAGUSD | 0 | 0 | 0 | MISSING | MISSING | ABSTAIN |

The canonical recheck artifact `D:/QM/reports/ftmo_spread_calibration/ftmo_spread_calibration_2026-08-09_router_recheck.json` (SHA-256 `67b6652545f21ada142973c89a97455ed48055f0dd54fde7b1a240382370f588`) is `REFUSED` because `XAUUSD_DWX_M1.jsonl` is absent. This proves the fail-closed behavior, not a spread estimate.

The only non-stub measured slippage input found is the Darwinex EURUSD quote-drift proxy: average `0.04` points, stored p95 `0.0` points, latency average/p95 `33.219/33.219 ms`, and spread median/p95 `3/4` points. It is not a fill-slippage distribution, is not FTMO, has no session breakdown, and must not be generalized to GBPUSD, USDCAD, NZDUSD, XTIUSD, or XAGUSD. Therefore the conservative current-pool slippage assumption remains **MISSING**, not zero.

## Missing series and cheapest governed acquisition

1. **OWNER/reviewer action: approve a reviewed, current-pool calibration spec and a scheduled read-only harvest.** Extend the existing `qm.ftmo-spread-calibration-spec/v1` to the six explicit mappings (`GBPUSD↔GBPUSD.DWX`, `EURUSD↔EURUSD.DWX`, `USDCAD↔USDCAD.DWX`, `NZDUSD↔NZDUSD.DWX`, the actual FTMO oil symbol↔`XTIUSD.DWX`, and `XAGUSD↔XAGUSD.DWX`). Symbol names and point sizes must come from the FTMO demo terminal, not guesses.
2. Use the existing free demo/history machinery in `tools/strategy_farm/ftmo_m1_bootstrap.py` and the existing CopyRates harvester. This requires reviewer authorization and must run through its guarded lane/scheduled mechanism; **do not start `terminal64.exe` manually** and do not touch AutoTrading.
3. Harvest both venues over identical UTC minute bounds and retain each source HCC hash. For NZDUSD and XAGUSD, acquire fresh DXZ 2026 history before pairing; the archived 2025 containers are not contemporaneous with FTMO 2026 data.
4. Run `tools/strategy_farm/portfolio/ftmo_spread_calibration.py`. Its contract requires identical minute sets, at least 60 matched minutes, at least 20 observations per session bucket, and applies a non-negative upper-tail delta per side. Any missing minute/bucket remains a refusal.
5. Separate fill slippage from quoted spread. The free M1 harvest closes the spread gap; a real fill-slippage distribution still requires a pre-authorized demo execution probe with no live authority. Until then, record slippage as `MISSING` and evaluate pessimistic sensitivity rather than assuming zero.

## Verification

- Inventory search covered `C:/QM/repo`, `C:/QM/mt5`, `D:/QM/mt5`, `D:/QM/reports`, `D:/QM/archive/Custom_master`, and `D:/QM/scratch` by filename and content terms (`FTMO`, `spread`, `slippage`, `execution`, `tick`, `quote`, `m1_harvest`).
- Candidate identities and stream hashes reconcile with `docs/ops/evidence/2026-09-04_astra_ftmo_inventory.json`.
- Focused regression command: `python -m pytest -q tools/strategy_farm/tests/test_ftmo_spread_calibration.py`.
- No terminal process was started or interrupted; no T_Live/AutoTrading setting was touched.

