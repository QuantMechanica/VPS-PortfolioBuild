---
copy_of: strategy-seeds/cards/xti-xng-vcb_card.md
canonical_approved_card: strategy-seeds/cards/approved/QM5_12850_xti-xng-vcb_card.md
---

# Strategy Card Copy - QM5_12850_xti-xng-vcb

See `strategy-seeds/cards/xti-xng-vcb_card.md` for the full approved card.

This EA expresses a market-neutral XTI/XNG ratio volatility-contraction
breakout: low Bollinger BandWidth rank on the completed D1 log ratio, followed
by a close outside the ratio Bollinger envelope. It is distinct from the
existing XTI/XNG raw channel breakout and return-spread mean-reversion builds.

Backtests use `RISK_FIXED=1000` and logical basket symbol
`QM5_12850_XTI_XNG_VCB_D1`. No live manifest, AutoTrading, portfolio gate,
external runtime data, grid, martingale, or ML is involved.
