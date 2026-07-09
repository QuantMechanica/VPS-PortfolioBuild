# QM5_1558 Build Notes

Build date: 2026-07-09

- Card source: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1558_aa-zak-mac-3-10.md`
- Rule: monthly long/cash SMA(3) > SMA(10) with ATR(20,D1) catastrophic stop.
- Volatility filter: monthly ATR(6) must be at least 50% of its 36-month median before opening a new monthly position.
- DWX port: card-stated `USOIL.DWX` is not in `framework/registry/dwx_symbol_matrix.csv`; the build uses `XTIUSD.DWX` as the available crude-oil DWX proxy.
- Host timeframe: `D1`; monthly bars are aggregated from completed D1 bars because `.DWX` custom symbols do not reliably expose `PERIOD_MN1` in tester.
