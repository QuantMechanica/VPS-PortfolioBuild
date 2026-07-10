# QM5_13106 AUDUSD/EURGBP Cointegration Card

Canonical approved card:
`strategy-seeds/cards/approved/QM5_13106_aud-eurgbp-coint_card.md`.

- Source: OWNER-requested all-sign rerun of the 2026-06-09 66-pair FX scan.
- Symbols: AUDUSD.DWX and EURGBP.DWX; GBPUSD.DWX is conversion-only.
- Spread: `ln(AUDUSD) - (-0.0545763736541407) * ln(EURGBP)`.
- Entry: z above +2 short both legs; z below -2 long both legs.
- Exit: `abs(z) < 0.5`, per-leg `ATR(20) * 2.0` hard stops, orphan cleanup.
- Backtest: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Constraints: deterministic, no ML, no adaptive refit, no grid/martingale,
  no pyramiding, and no live authorization.

