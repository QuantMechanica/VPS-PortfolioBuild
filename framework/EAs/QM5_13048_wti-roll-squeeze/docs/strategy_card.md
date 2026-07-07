---
ea_id: QM5_13048
slug: wti-roll-squeeze
status: APPROVED
source_id: CFTC-ETF-ROLL-WTI-2014
period: D1
target_symbols: [XTIUSD.DWX]
pipeline_phase: Q02
---

# QM5_13048 WTI ETF Roll-Window Squeeze Breakout

Canonical card: `strategy-seeds/cards/wti-roll-squeeze_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It uses the official CFTC crude-oil ETF
roll paper as a structural early-month flow clock, but reads no external data
at runtime. Entry requires a prior completed D1 bar inside the roll window, a
compressed pre-signal channel, and a closed-bar breakout. Risk uses hard ATR
stop/target, SMA failure, exit-window, month-change, max-hold, standard news,
and Friday close.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy
manifest, `T_Live`, portfolio gate, or AutoTrading setting is touched.
