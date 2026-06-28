# Strategy Card Copy - QM5_12745_chan-wti-cl3040

Canonical approved card:
`strategy-seeds/cards/approved/QM5_12745_chan-wti-cl3040_card.md`

This EA mechanises the `SRC05_S07_CL3040` crude-oil 30/40-day combination
variant from Chan AT Chapter 6 for `XTIUSD.DWX` on D1. It is a single-position
V5 implementation: long when the prior D1 close is below the 30-day reference
and above the 40-day reference, short on the symmetric condition, and flat when
the condition disappears or reverses. It uses an ATR hard stop, a max-hold
guard, RISK_FIXED backtest setfiles, and no external data or ML.
