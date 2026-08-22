# QM5_1624 Build Evidence — Ehlers Adaptive Center of Gravity H4

- Task: `02da6437-8c76-42c5-82df-ed307ce12628` (`build_ea`, priority 50, assigned to Gemini)
- EA: `QM5_1624_ehlers-adaptive-cg-h4`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1624_ehlers-adaptive-cg-h4.md`
- Source MQ5 SHA-256: `c1c88789483807a6817f77b2069b8b6bcb5a5f56c51e737a7e5c1fcc6fe9de78`
- Compiled EX5 SHA-256: `01c19aab514431c917cdf2899ae5b22ffc1bcd48d8932e2674a3c4385c82eaa7`
- Build Identity Artifact: `C:/QM/repo/framework/EAs/QM5_1624_ehlers-adaptive-cg-h4/build_identity.json`
- Outcome: `BUILD_READY_REVIEW`

## Governed Identity and Registries

- EA ID `1624` registered in `framework/registry/ea_id_registry.csv` with source `6e967762-b26d-59a3-b076-35c17f2e7c36` and slug `ehlers-adaptive-cg-h4`.
- 14 active magic rows allocated in `framework/registry/magic_numbers.csv` across slots 0..13 (base `16240000`):
  - 0: `AUDUSD.DWX`
  - 1: `EURUSD.DWX`
  - 2: `GBPUSD.DWX`
  - 3: `GDAXI.DWX`
  - 4: `NDX.DWX`
  - 5: `NZDUSD.DWX`
  - 6: `SP500.DWX`
  - 7: `UK100.DWX`
  - 8: `USDCAD.DWX`
  - 9: `USDCHF.DWX`
  - 10: `USDJPY.DWX`
  - 11: `WS30.DWX`
  - 12: `XAUUSD.DWX`
  - 13: `XTIUSD.DWX`
- `framework/include/QM/QM_MagicResolver.mqh` regenerated via `update_magic_resolver.py` with 17,813 rows kept and 0 dropped.

## Strategy Implementation

The EA implements the approved Ehlers Adaptive Center of Gravity (H4) specification:
- Dominant cycle period P estimation using a 48-bar autocorrelation periodogram bounded in [6, 48] bars (Ehlers 2013 ch. 8).
- Center of Gravity oscillator with adaptive half-cycle window length `N = P / 2` and 1-bar lagged trigger line.
- Trigger crossover signals on closed H4 bars.
- Macro trend filter: D1 EMA(200) slope direction on D1 close.
- Exit rules: CG-trigger re-crossing, D1 EMA(200) slope reversal, or adaptive time stop at 2.0 * P bars.
- Stop Loss: 2.0 * ATR(14) hard stop.
- Spread filter: Skip entry if spread > 0.3 * ATR(14).
- Cooldown: N = P / 2 bars between entries in the same direction.
- Framework conformance: MAE hook in OnTick, zero-initialized QM_EntryRequest, news gate covering new entries only.

## Verification

- `validate_spec_doc.py`: PASS (1/1).
- `build_gate_hardening.py`: PASS (0 failures, 0 warnings across all D2-D11 checks).
- `gen_setfile.ps1`: 14 setfiles generated in `sets/` with valid `build_hash` stamped.
- MetaEditor compile: PASS (0 errors, 0 warnings).
- Strict non-iterative single-pass build complete.
