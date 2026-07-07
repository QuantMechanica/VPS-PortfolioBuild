# QM5_13038 Strategy Card Copy

Canonical approved card:
`strategy-seeds/cards/approved/QM5_13038_xti-dpr-fade_card.md`.

Source card:
`strategy-seeds/cards/xti-dpr-fade_card.md`.

This EA trades `XTIUSD.DWX` on D1 using the official EIA DPR source lineage as
a structural mid-month shale-production information window. It fades failed
Donchian breakouts that close back inside the channel with ATR range/body/tail
confirmation and SMA stretch, then exits on ATR stop/target, SMA
mean-reversion, max-hold, and V5 framework controls.

Backtests use `RISK_FIXED=1000`. No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.
