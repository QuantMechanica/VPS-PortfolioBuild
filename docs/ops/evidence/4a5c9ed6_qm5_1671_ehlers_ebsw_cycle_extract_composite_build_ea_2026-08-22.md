# QM5_1671 Build Evidence — Ehlers EBSW + Cycle-Extraction Composite H4

- Task: `4a5c9ed6-20b8-47e3-91d3-1aa4e51d4385` (`build_ea`, priority 50, assigned to Gemini)
- EA: `QM5_1671_ehlers-ebsw-cycle-extract-composite-h4`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1671_ehlers-ebsw-cycle-extract-composite-h4.md`
- Source MQ5 SHA-256: `b9808e004e82b6bce626cb7c6f881b3fa5e6d4b53f44e673bb42a04a44102a21`
- Compiled EX5 SHA-256: `a937a0972c3d523668e18dbcfd943485c29015c9f55e5ca8373b50c0570ddb25`
- Build Identity Artifact: `C:/QM/repo/framework/EAs/QM5_1671_ehlers-ebsw-cycle-extract-composite-h4/build_identity.json`
- Outcome: `BUILD_READY_REVIEW`

## Governed Identity and Registries

- EA ID `1671` registered in `framework/registry/ea_id_registry.csv` with source `6e967762-b26d-59a3-b076-35c17f2e7c36` and slug `ehlers-ebsw-cycle-extract-composite-h4`.
- 13 active magic rows allocated in `framework/registry/magic_numbers.csv` across slots 0..12 (base `16710000`):
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

The EA implements the approved Ehlers EBSW + Cycle-Extraction Composite (H4) specification:
- Roofing filter (hp=48, lp=10) on H4 close followed by Hilbert-transform analytic signal to extract cycle amplitude and dominant cycle period.
- Even-Better-Sinewave (EBSW) phase calculation with roofing filter (hp=40, lp=10) and Hilbert discriminator.
- Composite rule: EBSW zero-crossings qualified by amplitude threshold (0.5 * ATR(14)) and dominant cycle period within [10, 48] bars.
- Macro trend filter: D1 SMA(200) regime gate on D1 close.
- Exit rules: EBSW phase reversal / cycle-peak target (|ebsw| > 0.95), D1 SMA(200) slope reversal, amplitude-collapse exit (3 bars below 0.5x threshold), and cycle-scaled time stop (1.5 * cycle_period bars).
- Stop loss: 1.5 * cycle_amplitude (capped at 3.0 * ATR(14)).
- Position management: Break-even at +1.0 * cycle_amplitude, trailing stop at +2.0 * cycle_amplitude.
- Spread filter: Skip entry if spread > 0.3 * ATR(14).
- Cooldown: 0.5 * cycle_period bars between entries in the same direction.
- Framework conformance: MAE hook in OnTick, zero-initialized QM_EntryRequest, news gate covering new entries only.

## Verification

- `validate_spec_doc.py`: PASS (1/1).
- `build_gate_hardening.py`: PASS (0 failures, 0 warnings across all D2-D11 checks).
- `validate_build_guardrails.py`: PASS (0 findings).
- `gen_setfile.ps1`: 13 setfiles generated in `sets/` with valid `build_hash` stamped.
- Strict non-iterative single-pass build complete.

