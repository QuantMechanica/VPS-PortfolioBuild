---
ea_id: QM5_12844
slug: commodity-trend-crude
type: strategy
strategy_id: BALKE_DAVEY_SLATE_B1_XTI_20260701
source_id: BALKE-DAVEY-SLATE-20260630
source_citation: "Local research slate docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md, B1 Commodity Trend / Breakout; supplemental structural lineage from Davey (2014) and the V5 Turtle/ADX/ATR-trail pattern."
source_citations:
  - type: research_slate
    citation: "Balke/Davey synthesis slate, 2026-06-30, B1 Commodity Trend / Breakout - Crude & Gold."
    location: "docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md"
    quality_tier: B
    role: primary
  - type: book
    citation: "Davey, Kevin J. (2014). Building Winning Algorithmic Trading Systems. Wiley."
    location: "Mechanization discipline and trend-following validation workflow."
    quality_tier: A
    role: supplemental
target_symbols: [XTIUSD.DWX]
timeframes: [D1]
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
---

> NOTE 2026-07-02: the card of record is
> `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12844_commodity-trend-crude.md`.
> This local copy is retained only as build-side context and must not override the
> approved card.

# Crude Commodity Trend Breakout

This local EA copy follows the approved card at
`strategy-seeds/cards/approved/QM5_12844_commodity-trend-crude_card.md`.

The strategy is a crude-only D1 Donchian+ADX+ATR-trail breakout sleeve on
`XTIUSD.DWX`: enter long or short on a closed-bar 20-bar channel breakout when
ADX(11) is above 20, use a 3.0x ATR(14) hard stop, trail by 3.0x ATR after
favorable movement, close on the opposite 10-bar channel break, and time-exit
after 45 calendar days.

Backtests use `RISK_FIXED=1000`. No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.
