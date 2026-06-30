# QM5_12813 EIA Energy Switch Approval

- Status: APPROVED
- Date: 2026-06-30
- Source packet: `strategy-seeds/sources/EIA-ENERGY-SEASON-SWITCH-2026/source.md`
- Approved card: `strategy-seeds/cards/approved/QM5_12813_eia-energy-switch_card.md`
- Logical symbol: `QM5_12813_XTI_XNG_SEASON_SWITCH_D1`
- Host: `XTIUSD.DWX` D1
- Basket legs: `XTIUSD.DWX`, `XNGUSD.DWX`
- Risk mode for Q02: `RISK_FIXED=1000`

## Approval Basis

R1 PASS: official EIA source lineage for gasoline/oil seasonality and natural gas winter demand/storage seasonality.

R2 PASS: fixed seasonal windows, SMA confirmation, spread caps, ATR stops, monthly package cap, and deterministic exits.

R3 PASS: both symbols are available in the Darwinex symbol registry.

R4 PASS: no ML, grid, martingale, forbidden indicators, or runtime external data.

The edge is non-duplicate relative to existing XTI/XNG ratio reversion, XTI/XNG breakout, XTI/XNG cross-sectional momentum, WTI month ORB, XNG month ORB, and XNG RSI builds.
