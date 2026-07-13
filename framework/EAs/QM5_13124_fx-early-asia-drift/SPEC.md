# QM5_13124 FX Early-Asia Drift

Mechanical implementation of the APPROVED `fx-early-asia-drift` card. It buys
one registered FX carrier at its locked early-Asia UTC hour, uses a 1.25 ATR(20)
catastrophic stop, and closes after 60 minutes.

The direction, symbol/hour mapping, hold, ATR stop, spread ceiling, and entry
delay are fixed. The EA contains no take profit, optimization branch, adaptive
filter, scale-in, grid, martingale, trailing stop, partial close, or ML.

Canonical card: `strategy-seeds/cards/fx-early-asia-drift_card.md`.

Status: retired before Q02. The discovery timestamps were broker wallclock,
not UTC, so the apparent effect was a rollover artifact.
