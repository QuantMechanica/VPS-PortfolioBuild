# QM5_1629 Build Evidence — Ehlers Cybernetic Cycle H4

- Task: `810145d0-5aeb-4a8f-9830-b0bdaadac57f` (`build_ea`, priority 50, assigned to Gemini)
- EA: `QM5_1629_ehlers-cybernetic-cycle-h4`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1629_ehlers-cybernetic-cycle-h4.md`
- Source MQ5 SHA-256: `6a2e3ff5044180af4e9363df665fb533ef3f8fe32c3052778cf4373ef7c105d1`
- Compiled EX5 SHA-256: `b32130054b4c1226dbbb7ed7caed583649bec9e147e56c1f2867b061ab84e4f8`
- Build Identity Artifact: `C:/QM/repo/framework/EAs/QM5_1629_ehlers-cybernetic-cycle-h4/build_identity.json`
- Outcome: `BUILD_READY_REVIEW`

## Governed Identity and Registries

- EA ID `1629` registered in `framework/registry/ea_id_registry.csv` with source `6e967762-b26d-59a3-b076-35c17f2e7c36` and slug `ehlers-cybernetic-cycle-h4`.
- 14 active magic rows allocated in `framework/registry/magic_numbers.csv` across slots 0..13 (base `16290000`):
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

The EA implements the approved Ehlers Cybernetic Cycle (H4) specification:
- 4-bar weighted smoothing kernel `(p0 + 2*p1 + 2*p2 + p3)/6` on median price.
- 2-pole IIR high-pass cycle filter with fixed alpha=0.07 (Ehlers 2004 ch. 4).
- Zero-line crossing signal evaluation on closed H4 bars.
- Amplitude confirmation gate: recent cycle amplitude > 0.5% of price across 20-bar window.
- D1 SMA(200) macro trend regime filter: long entries require D1 Close > SMA(200), short entries require D1 Close < SMA(200).
- Risk model: 2.0 ATR hard stop and take profit, break-even move at +1.0 ATR excursion.
- Opposite strong cycle cross exit and 20-bar time stop.
- Cooldown: 4 bars between trades in the same direction.
- Framework conformance: MAE hook in OnTick, zero-initialized QM_EntryRequest, news gate covering new entries only.

## Verification

- `validate_spec_doc.py`: PASS (1/1).
- `build_gate_hardening.py`: PASS (0 failures, 0 warnings across all D2-D11 checks).
- `gen_setfile.ps1`: 14 setfiles generated in `sets/` with valid `build_hash` stamped.
- MetaEditor compile: PASS (0 errors, 0 warnings).
- Strict non-iterative single-pass build complete.
