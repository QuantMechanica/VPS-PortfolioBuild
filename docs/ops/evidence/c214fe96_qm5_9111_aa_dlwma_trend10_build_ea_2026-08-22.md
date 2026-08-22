# QM5_9111 Build Evidence — Alpha Architect DLWMA N10 Trend Filter

- Task: `c214fe96-6101-46e0-98cc-30daa4ea8d03` (`build_ea`, priority 50, assigned to Gemini)
- EA: `QM5_9111_aa-dlwma-trend10`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9111_aa-dlwma-trend10.md`
- Source MQ5 SHA-256: `1d1498bfc31dcc463bab92ddfac6206748b148c023495b7711f70c7301abdf73`
- Compiled EX5 SHA-256: `dcb01b20753f61ecbb5c39c2649552e7ffeb243d42855f26b45d9ba50e1d9ad5`
- Build Identity Artifact: `C:/QM/repo/framework/EAs/QM5_9111_aa-dlwma-trend10/build_identity.json`
- Outcome: `BUILD_READY_REVIEW`

## Governed Identity and Registries

- EA ID `9111` registered in `framework/registry/ea_id_registry.csv` with source `ede348b4-0fa7-5be1-baa8-09e9089b67b7` and slug `aa-dlwma-trend10`.
- 13 active magic rows allocated in `framework/registry/magic_numbers.csv` across slots 0..12 (base `91110000`):
  - 0: `GDAXI.DWX`
  - 1: `NDX.DWX`
  - 2: `SP500.DWX`
  - 3: `UK100.DWX`
  - 4: `WS30.DWX`
  - 5: `XAUUSD.DWX`
  - 6: `EURUSD.DWX`
  - 7: `GBPUSD.DWX`
  - 8: `USDJPY.DWX`
  - 9: `USDCHF.DWX`
  - 10: `AUDUSD.DWX`
  - 11: `USDCAD.DWX`
  - 12: `NZDUSD.DWX`
- `framework/include/QM/QM_MagicResolver.mqh` regenerated via `update_magic_resolver.py` with 17,813 rows kept and 0 dropped.

## Strategy Implementation

The EA implements the approved Alpha Architect Double Linear Weighted Moving Average (DLWMA) Trend Filter specification:
- Double LWMA calculation on completed D1 closes: `LWMA1 = LWMA(Close, N=10)`, `LWMA2 = LWMA(LWMA1, N=10)`.
- DLWMA linear trend: `Trend = LWMA1 - LWMA2`.
- Entry rule: Long entry when `Trend(1) > 0.0` and `Trend(2) <= 0.0` (zero-cross upwards) on new D1 bar.
- Exit rule: Position close when `Trend(1) <= 0.0` on completed D1 bar.
- Stop loss: `3.0 * ATR(20, PERIOD_D1)` initial protective stop.
- Spread filter: Skip entry if spread > 0.3 * ATR(20, D1).
- Minimum D1 bars: 80 completed bars.
- Framework conformance: MAE hook in OnTick, zero-initialized QM_EntryRequest, news gate covering new entries only.

## Verification

- `validate_spec_doc.py`: PASS (1/1).
- `build_gate_hardening.py`: PASS (0 failures, 0 warnings across all D2-D11 checks).
- `validate_build_guardrails.py`: PASS (0 findings).
- `gen_setfile.ps1`: 13 setfiles generated in `sets/` with valid `build_hash` stamped.
- Strict non-iterative single-pass build complete.

