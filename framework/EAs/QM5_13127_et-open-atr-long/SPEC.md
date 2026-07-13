# QM5_13127 NDX Session-Open ATR Breakout Long

Source-faithful long-only repair of `QM5_10375_et-open-atrbrk`. The EA places
one NDX buy stop at the broker 16:30 session open plus 0.30 of prior D1 ATR(20),
uses the opposite band as stop, targets 0.60 ATR, and is flat at session end.
The session anchor remains the actual 16:30 M5 bar when news gates delay order
evaluation. No short bracket or reversal order exists.

Canonical card: `strategy-seeds/cards/et-open-atr-long_card.md`.
