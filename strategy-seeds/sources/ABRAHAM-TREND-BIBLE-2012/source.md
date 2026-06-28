---
source_id: ABRAHAM-TREND-BIBLE-2012
tier: T1
status: scaffolded_card_extracted
authored-by: Development
last-updated: 2026-06-28
source_type: book
source_text_path: "D:/QM/strategy_farm/source_cache/trendbible_extracted.txt"
cards_extracted:
  - QM5_12757_abraham-xti-pb
---

# ABRAHAM-TREND-BIBLE-2012 - Andrew Abraham, The Trend Following Bible

## Source Identity

```yaml
source_citations:
  - type: book
    citation: "Abraham, Andrew. The Trend Following Bible: How Professional Traders Compound Wealth and Manage Risk. John Wiley & Sons, 2013. ISBN 978-1-118-41732-5."
    location: "Chapters 6-7; extracted research notes pages 101-121"
    quality_tier: A
    role: primary
```

## Extraction Status

The source was mined in `docs/research/LIBRARY_MINING_trend-bible-2012_2026-06.md`.
That review found no existing Abraham-attributed card and no existing card with
the exact channel-breakout plus MACD-zero filter plus ATR-trailing-stop
combination.

## V5 Allowability

- R1: PASS. Single Wiley practitioner book source by a named systematic trend
  trader and fund manager.
- R2: PASS. Rules are arithmetic and testable: X-day channel breakout, MACD
  zero-line direction filter, retracement to the old channel boundary, 10-day
  structural hard stop, and ATR(39) trailing stop.
- R3: PASS. `XTIUSD.DWX` D1 OHLC is available in the Darwinex MT5 universe and
  all indicators are MT5-native/framework-native.
- R4: PASS. No ML, no adaptive model, no grid, no martingale, no pyramiding,
  and one position per magic/symbol.

## Extracted Cards

| Card | Mechanism | Status |
|---|---|---|
| `QM5_12757_abraham-xti-pb` | XTIUSD.DWX D1 breakout-confirmed pullback to old channel boundary, MACD zero filter, 10-day hard stop, ATR(39) trail | APPROVED / built |
