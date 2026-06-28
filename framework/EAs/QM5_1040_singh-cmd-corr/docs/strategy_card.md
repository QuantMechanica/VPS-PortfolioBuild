# QM5_1040 Strategy Card Build Note

Source card: `strategy-seeds/cards/singh-cmd-corr_card.md`

Build scope: `SRC06_S13`, Part 1 only.

- Trading instrument: `CADJPY.DWX`
- Leading instrument: `XTIUSD.DWX` read-only D1 oil chart
- Timeframe: D1
- Variant excluded: Part 2 `USDX -> XAUUSD`, because this mission needs a new energy-linked sleeve rather than more metal exposure, and USDX native availability remains unresolved.
- P0 dependency resolution: the approved card named `WTI.cash.DWX` or equivalent oil feed. This build uses native Darwinex `XTIUSD.DWX`, which is already present in the V5 symbol matrix and many existing Q02 runners.

Mechanical rules implemented:

- Identify oil D1 resistance/support as highest high / lowest low across the prior 30 completed bars, excluding the signal bar.
- Require at least two touches within 0.25 ATR(14) of the level.
- Require the youngest level touch to be at least 10 completed bars old.
- Long CADJPY when the just-closed oil D1 close breaks above resistance.
- Short CADJPY when the just-closed oil D1 close breaks below support.
- Enter CADJPY at next D1 bar market price through the V5 entry/risk framework.
- SL: 2.0 x CADJPY ATR(14).
- TP: 3.0R.
- Filters: CADJPY spread cap, CADJPY ATR floor against ATR(30), oil daily range cap at 5%, V5 news and Friday-close gates.

This intentionally differs from existing WTI/XNG sleeves: it does not trade oil or gas outright, does not use EIA calendar logic, and expresses the oil shock through the CADJPY importer/exporter currency channel from the Singh source.

