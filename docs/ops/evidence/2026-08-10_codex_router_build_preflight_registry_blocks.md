# Codex router build preflight — registry blocks

Date: 2026-08-10  
Role: Development / Codex  
Scope: one scheduled router cycle; build only

## Outcome

Four priority-50 `build_ea` tasks reached Codex with OWNER-authorized Strategy Cards, but none passed the deterministic registry preflight required by `qm-build-ea-from-card`. No EA source, registry, resolver, setfile, compiled binary, smoke run, pipeline row, terminal, or live setting was changed for these tasks.

| Router task | EA | Approved card | EA registry | Required magic rows | Verdict |
|---|---|---|---|---|---|
| `f3093ecd-e820-4224-9c22-e248300d50e8` | `QM5_1670_hopwood-bermaui-macd-h4` | PASS (`g0_status: APPROVED`) | PASS: active row for `1670` / exact slug | FAIL: no rows for slots covering `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`, `NDX.DWX`, `WS30.DWX` | `BLOCKED_PREBUILD` |
| `fa98372d-3350-4ddd-b904-2a00a72bbd05` | `QM5_1750_hopwood-bermaui-adx-h4` | PASS (`g0_status: APPROVED`) | FAIL: no row for `1750` | FAIL: no rows for the six card symbols | `BLOCKED_PREBUILD` |
| `31609b87-fa05-441e-b957-09058a694b1c` | `QM5_1753_bressert-timecycle-mtf-h4` | PASS (`g0_status: APPROVED`) | FAIL: no row for `1753` | FAIL: no rows for the six card symbols | `BLOCKED_PREBUILD` |
| `7e8c9eaa-1af5-40ca-9f49-4c785b5ae07d` | `QM5_20065_pricebob-refbar-breakout-eurusd` | PASS (`g0_status: APPROVED`) | PASS: active row for `20065` / exact slug | FAIL: no slot-0 row for `EURUSD.DWX` | `BLOCKED_PREBUILD` |

## Evidence checked

- Cards of record were read in full from `D:/QM/strategy_farm/artifacts/cards_approved/`.
- EA allocation was checked in `C:/QM/repo/framework/registry/ea_id_registry.csv` using anchored numeric-ID matches.
- Magic allocation was checked in `C:/QM/repo/framework/registry/magic_numbers.csv` using anchored numeric-ID matches.
- Every card-declared symbol was checked against `C:/QM/repo/framework/registry/dwx_symbol_matrix.csv`; symbol availability is not the blocker.
- Pre-existing `.mq5` files for all four labels contain unimplemented skeleton hooks. They were treated as incomplete prior state and left unchanged.

## Deterministic boundary

The selected build skill requires the allocated EA row and all `(ea_id, symbol_slot)` magic rows to exist before implementation. It explicitly forbids Development from allocating either registry. Consequently, compile and smoke verification would not be valid evidence and were not run.

Required recovery is an OWNER-governed registry allocation for the missing EA IDs and symbol slots, followed by fresh deterministic routing. Build approval, pipeline advancement, and live authorization are not implied by this preflight.
