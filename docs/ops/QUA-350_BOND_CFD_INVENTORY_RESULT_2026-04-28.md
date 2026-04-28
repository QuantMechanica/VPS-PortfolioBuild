# QUA-350 Bond-CFD Inventory Result (US10Y + Bund10Y)

- generated_at_utc: 2026-04-28T09:11:30Z
- mt5_probe_ok: True
- overall: fail
- disposition: both_missing_external_shim_or_defer

| bond | darwinex_symbol | status | tradeable_hours | liquidity | typical_spread | min_lot | margin | commission |
|---|---|---|---|---|---|---|---|---|
| US10Y |  | missing | absent (symbol not found) | absent (symbol not found) | absent (symbol not found) | absent (symbol not found) | absent (symbol not found) | absent (symbol not found) |
| DE10Y |  | missing | absent (symbol not found) | absent (symbol not found) | absent (symbol not found) | absent (symbol not found) | absent (symbol not found) | absent (symbol not found) |

Decision branch:
- both symbols missing -> SRC04_S11 `_v2` requires external-data shim (FRED) or remains deferred.
