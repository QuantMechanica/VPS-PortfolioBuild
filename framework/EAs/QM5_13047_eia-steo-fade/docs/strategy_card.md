# QM5_13047 EIA STEO WTI Failed-Breakout Fade

Canonical card: `strategy-seeds/cards/eia-steo-fade_card.md`.

The EA trades `XTIUSD.DWX` D1 only. It uses the official EIA Short-Term Energy
Outlook release schedule as a deterministic monthly timing proxy, but reads no
external EIA data at runtime. Entry fades STEO proxy days that probe outside the
prior D1 range and close back inside it. Risk uses a hard ATR stop, ATR target,
spread cap, max-hold exit, standard news handling, and Friday close.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.
