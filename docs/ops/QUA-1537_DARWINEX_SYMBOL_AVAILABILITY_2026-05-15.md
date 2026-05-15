# QUA-1537 — Darwinex MT5 instrument availability check (WTI.cash.DWX, USDX.f)

Date: 2026-05-15
Owner: CTO
Terminal checked: `D:/QM/mt5/T1/terminal64.exe`
Method: direct `MetaTrader5` API probe (`symbols_get`, `symbol_info`, `symbol_select`).

## Objective
Verify whether strategy dependency symbols are available on Darwinex MT5 runtime:
- `WTI.cash.DWX`
- `USDX.f`

## Result
- MT5 initialize: `true`
- `WTI.cash.DWX`: not found (`in_symbols_get=false`, `symbol_info_exists=false`, `symbol_select_true=false`)
- `USDX.f`: not found (`in_symbols_get=false`, `symbol_info_exists=false`, `symbol_select_true=false`)
- Related available symbols observed:
  - oil candidates: `XTIUSD`, `XTIUSD.DWX`
  - USDX candidates: none
  - DX-like broker symbols: `DXCM`, `DXC`

## Conclusion
- Exact required symbols for `singh-cmd-corr` are **not available** on current Darwinex MT5 T1 runtime.
- `WTI.cash.DWX` can likely be substituted by `XTIUSD.DWX` only if card/spec explicitly allows the mapping.
- `USDX.f` has no direct runtime match in the observed symbol universe; P0 should treat this as unresolved dependency until a Darwinex-native proxy mapping is formally approved.

## Next action requested
- CTO + Research + QB: approve one of:
  1. canonical remap (`WTI.cash.DWX -> XTIUSD.DWX`) and define Darwinex-native USDX proxy basket, or
  2. defer `singh-cmd-corr` before P0 compilation.
