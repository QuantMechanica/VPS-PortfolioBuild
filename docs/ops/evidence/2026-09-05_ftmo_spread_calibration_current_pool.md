# Current-pool FTMO/DXZ M1 spread calibration — 2026-09-05

## Verdict

`ABSTAIN` for all six current-pool symbols. The guarded free-history harvest completed the FTMO side for all six and the DXZ side for GBPUSD/EURUSD. There are zero common minutes for those two pairs. The other four DXZ sources contain no bars in the declared 2026 window. Therefore no median, p95, per-session spread delta, or conservative charge is admissible. Fill slippage remains a separate declared gap. No purchase, account, deployment, Q verdict, or live authority was created.

Matrix artifact: `D:/QM/reports/ftmo_spread_calibration/current_pool/calibration_matrix_2026-09-05.json`, SHA-256 `e4ff9f75d8e6d6dbac3ac0fea89b2e700784d5b07d174e3091adc444f7d47ff3`.

Reviewed spec: `docs/ops/evidence/2026-09-05_ftmo_spread_calibration_current_pool_spec.json`, SHA-256 `7fa184523886a3edf31ad36901fd254fb2effecc939e18b84a9070d33d279571`.

## Guarded execution

`ftmo_m1_bootstrap.py` was extended to the exact mappings GBPUSD↔GBPUSD.DWX, EURUSD↔EURUSD.DWX, USDCAD↔USDCAD.DWX, NZDUSD↔NZDUSD.DWX, USOIL.cash↔XTIUSD.DWX, and XAGUSD↔XAGUSD.DWX. FTMO symbols require an explicit CLI selection; DXZ subsets remain constrained to the reviewed six-symbol set. The script performs a static no-trading-token check, writes `Enabled=0` and `AllowLiveTrading=0`, binds exact process identity, serializes FTMO_STREAM1, reserves only a process-free factory slot, and releases only its own reservation.

An orphaned bootstrap lock dated `2026-08-08T23:29:00Z` for absent PID 16240 was preserved—not deleted—at `D:/QM/reports/ftmo_spread_calibration/stale_locks/ftmo_m1_bootstrap_20260808T232900Z_pid16240.lock`. One NZDUSD FTMO launch underwent a terminal process handoff; the replacement process was terminated by exact PID/path/creation identity and the clean retry passed. No T_Live, challenge terminal, or active T1–T10 backtest was signaled or interrupted.

## Harvest receipts

| Venue / symbols | Result | Receipt | Receipt SHA-256 |
|---|---|---|---|
| FTMO / GBPUSD | PASS, 100,000 | `D:/QM/reports/ftmo_spread_calibration/bootstrap_runs/FTMO_FTMO_STREAM1_20260905T043606Z_49acd9eb/bootstrap_receipt.json` | `5fe2f425b04049e19fb6695bae168b86e08e976e3364ba9eb18d40d6c3515e8d` |
| FTMO / EURUSD | PASS, 100,000 | `.../FTMO_FTMO_STREAM1_20260905T043743Z_d4874d70/bootstrap_receipt.json` | `79fb1263d5cf40f637fa4f67ac5764924ebe61cb056552385e663b5c0bc48d12` |
| FTMO / USDCAD | PASS, 100,000 | `.../FTMO_FTMO_STREAM1_20260905T043941Z_f9c06cfb/bootstrap_receipt.json` | `87369b12bb36dda1dd9a27d8928e61387053ca0dfe708216bc27d827a8f92134` |
| FTMO / NZDUSD | PASS, 100,000 | `.../FTMO_FTMO_STREAM1_20260905T044517Z_0fcba01b/bootstrap_receipt.json` | `2d0d7e9765ff2cd785a4c4e8a671100ab36f8f719df1f4ad0cf50a94edbb0a6b` |
| FTMO / USOIL.cash | PASS, 100,000 | `.../FTMO_FTMO_STREAM1_20260905T044816Z_2f51b2ef/bootstrap_receipt.json` | `ba9119e1fbf174e43ff60f09d5ab63327db92ed2e5142afbc08b07b6f41fedd8` |
| FTMO / XAGUSD | PASS, 100,000 | `.../FTMO_FTMO_STREAM1_20260905T045001Z_9628d0ed/bootstrap_receipt.json` | `e140305d2ec3fee88844ddbc899906a2402d293c16a00e019d96bee076f33234` |
| DXZ / GBPUSD.DWX + EURUSD.DWX | PASS, 100,000 + 94,575 | `.../DXZ_FACTORY_20260905T050325Z_5ca3d91b/bootstrap_receipt.json` | `064b818a919868154cde853de16d4fe8aab3bf36bf9f167ea2dad7352810d56e` |

The guarded no-data attempts are retained under run roots `DXZ_FACTORY_20260905T045440Z_fd5816ec` (USDCAD), `DXZ_FACTORY_20260905T050415Z_38e59a84` (NZDUSD), `DXZ_FACTORY_20260905T050759Z_d1fe4deb` (XTIUSD), and `DXZ_FACTORY_20260905T051036Z_eca7b891` (XAGUSD). Each MQL journal records `QM_M1_HARVEST_NO_BARS_IN_WINDOW` followed by `QM_M1_HARVEST_FAILED`; the owned process and reservation were then cleaned up. Their tiny 2026 HCC containers are hash-bound below.

## Published projections and HCC bindings

| Series | Coverage UTC | Rows | Projection SHA-256 | Source HCC SHA-256 |
|---|---|---:|---|---|
| GBPUSD FTMO | 2026-05-29 14:57 → 2026-09-04 23:54 | 100,000 | `bf9fc50b96fda0b1ffe1913ca2f926cce2d85f43ab6c13dd8425ce868de24d23` | `bfa63126e029678f2eb41b2e93bb04009aa6b1cef4c05e604830c397af4369ff` |
| GBPUSD.DWX | 2026-01-19 03:43 → 2026-04-24 23:54 | 100,000 | `be6f905512764b3aa2dc19386a6ecb98f057e2037e764c95b8c0966dbcc60359` | `7faae17632be2c53c16435bf4889993c3cf009be565f5487362c73f560008d0b` |
| EURUSD FTMO | 2026-05-29 11:52 → 2026-09-04 23:54 | 100,000 | `6d012bc4b3be1bbcc367ce3ff616bb2b7785f43e7b8483bc6dca1d7446fc9c93` | `6eb59b53cf86f9b12730eaa8ce4cdbe1921bfdbcd1a808893c9568f16a023ed2` |
| EURUSD.DWX | 2026-01-02 00:04 → 2026-04-06 02:59 | 94,575 | `427d2378860ab5ccbaf58e50a21daf3d68c61cdeb70a7507d454171ae94c804d` | `96ad7228a4dfe348866e11d663e12c94359a135f80de2096c174d5338d169b11` |
| USDCAD FTMO | 2026-05-29 10:01 → 2026-09-04 23:54 | 100,000 | `86afebd52ed1db39bdc1ee8b22ac7e7afe8c0ac05b9b4c82ba0e738b2720b755` | `81379be2657a6d1c367763e5863f3cfa4f6f91c32fce96fd41bb013bdac47ab2` |
| NZDUSD FTMO | 2026-05-29 10:31 → 2026-09-04 23:54 | 100,000 | `a44d68e98ac98026803547a2e6641150cc338b86a6bf8ec5c53c71dc0f9218b0` | `9cd2b8d26ea1ad8fc89a443aa9f0ce7f7d990f520098c2dc21229e8a631a5f89` |
| XTIUSD FTMO | 2026-05-26 03:16 → 2026-09-04 23:49 | 100,000 | `731e9c4b87e5e8bf93509f81b5f58cf8513401fa0e65034581aa4e782c965ff0` | `a4cc1223c6548879d6f04db69dc6011c025ad5d1ea875d15246ae361a2898f62` |
| XAGUSD FTMO | 2026-05-26 10:12 → 2026-09-04 23:49 | 100,000 | `b1430a4bd64b377cdd19add23d808d46d99177b148f891f315c7f52f20e05f1c` | `447998cd0f32a3c42b19fb6f49843fc79c888f4db772b85db68b0ec47c92c4bd` |

No-data DXZ 2026 HCC bindings: USDCAD `12d94d88c7b899465f645511ee6f388c22c5b228a156ebdaaeb3ea7bd5909e5d` (34,422 bytes), NZDUSD `307f78996e9530416e5fa115da2d0a15009d4874098a1bc19d4db58e81d29b5b` (33,477), XTIUSD `66f432dd47d841f73128861a52af133f63fdcd95068f4e5a73401b8c6b01529b` (34,422), XAGUSD `afa9d118a8ffbed965bc2c4abb20bdbe0532179181572f79597862be0757594d` (35,745).

## Per-symbol calibration result

| Symbol | Exact common minutes | FTMO median / p95 | DXZ median / p95 | Session output | Verdict |
|---|---:|---|---|---|---|
| GBPUSD | 0 | MISSING | MISSING | MISSING | ABSTAIN — the 100,000-row windows do not overlap |
| EURUSD | 0 | MISSING | MISSING | MISSING | ABSTAIN — the 2026 windows do not overlap |
| USDCAD | 0 | MISSING | MISSING | MISSING | ABSTAIN — DXZ has no bars in the declared 2026 window |
| NZDUSD | 0 | MISSING | MISSING | MISSING | ABSTAIN — DXZ has no bars in the declared 2026 window |
| XTIUSD | 0 | MISSING | MISSING | MISSING | ABSTAIN — DXZ has no bars in the declared 2026 window |
| XAGUSD | 0 | MISSING | MISSING | MISSING | ABSTAIN — DXZ has no bars in the declared 2026 window |

The pair-matrix mode invokes the unchanged strict pair calibrator independently. It never intersects, forward-fills, time-shifts, substitutes symbols, or converts missing evidence to zero. For GBPUSD it reports `missing_ftmo=100000 missing_dxz=100000`; for EURUSD, `missing_ftmo=94575 missing_dxz=100000`.

## Verification and next evidence action

Focused tests: `27 passed` across `test_ftmo_m1_bootstrap.py` and `test_ftmo_spread_calibration.py`. Tests cover the exact six mappings, explicit FTMO symbol selection, current-pool DXZ subset confinement, static read-only MQL checks, reservation/identity boundaries, projection validation, strict identical-minute refusal, upper-tail non-credit, and pair-independent refusal preservation.

The next admissible step is a governed refresh of DXZ custom M1 history extending through the same post-2026-05 window as FTMO, followed by the identical-minute calibrator. A separate pre-authorized demo execution probe is still required for fill slippage. Until then every current-pool spread/slippage adjustment remains `MISSING`, and no purchase decision is supported.
