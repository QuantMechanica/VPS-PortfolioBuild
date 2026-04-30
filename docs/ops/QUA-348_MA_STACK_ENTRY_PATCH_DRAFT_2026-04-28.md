# QUA-348 Controlled Vocabulary Patch Draft (post-ratification)

Target file: `strategy-seeds/strategy_type_flags.md`
Insertion point: Section `## A. Entry-mechanism flags`, immediately after `### narrow-range-breakout` and before the struck-note paragraph.

```diff
@@
 ### narrow-range-breakout
 - **Definition**: Entry on the breakout of a range-contraction / NR-bar pattern, often paired with an ADX or volatility-regime filter to require coiled-spring conditions.
 - **V4 examples**: SM_404 ADX5NR6 (ADX(5) + Narrow-Range-6, "Strong holdout PF, 6/8 walk-forward symbols" — `reference/v4_doc/star-ea-reference.md`).
 - **Disambiguation from**: `donchian-breakout` (NR-breakout requires an explicit range-contraction precondition; donchian fires on any N-bar extreme regardless of preceding compression); `vol-regime-gate` (NR is the entry, not just an overlay).
+
+### ma-stack-entry
+- **Definition**: Entry triggered when moving averages of increasing lookback are in strict monotonic sequential order (long: `MA(P1) > MA(P2) > ... > MA(Pk)` for `P1 < ... < Pk`; short mirror), optionally requiring persistence for `N` bars before entry.
+- **V5 source example**: `SRC04_S09` Lien Perfect Order (`strategy-seeds/cards/lien-perfect-order_card.md`; source: `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt`, Ch16 pp. 143-148): canonical long stack `SMA10>SMA20>SMA50>SMA100>SMA200`, entry 5 bars after formation if stack still holds and ADX>20.
+- **Disambiguation from**: `trend-filter-ma` (single-MA overlay filter, not entry trigger); `donchian-breakout` / `ath-breakout` (price-extreme trigger, not MA-order state trigger); `hmm-regime-blend` (probabilistic regime model, not deterministic MA-order state).
```

Ratification gate: apply only after CEO/CTO approve per `strategy_type_flags.md` addition process.
