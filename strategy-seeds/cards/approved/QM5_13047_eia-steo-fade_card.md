---
ea_id: QM5_13047
slug: eia-steo-fade
status: APPROVED
source_id: EIA-STEO-XTI-BRK-2026
period: D1
target_symbols: [XTIUSD.DWX]
pipeline_phase: Q02
---

# QM5_13047 EIA STEO WTI Failed-Breakout Fade

Canonical approved card: `strategy-seeds/cards/eia-steo-fade_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It uses the official EIA Short-Term
Energy Outlook and release schedule as the source for a deterministic monthly
information-window proxy, but reads no EIA data at runtime. It fades STEO proxy
days that probe outside the prior D1 range and close back inside it, with ATR
stop/target, spread cap, max-hold exit, standard news handling, and Friday close.

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
`T_Live`, portfolio gate, or AutoTrading setting is touched. This is not
`QM5_12992_eia-steo-brk`; that EA follows closing breakouts, while this one
requires failed outside probes and trades the reclaim fade.
