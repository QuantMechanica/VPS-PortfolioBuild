# Parked Register

_As of 2026-07-24. Rows that carry a real edge idea but violate a V5 hard constraint (ML, external runtime, external data, options/order-flow feeds, broker-specific swap). Each keeps a revisit trigger; none is discarded._

**Parked rows: 1**

### STR-084 — Neural-Network MACD Pattern (R/h2o)

- **Source:** ff_771822_statistics-combined-with-system-profitable-what-do-you.pdf (pp. 24-26)
- **Concept:** Train a deep neural network on MACD-indicator patterns across 28 pairs (JPY scaled by /100) to predict the next price change and automate entries/exits.
- **Park reason:** Deep neural network + external R/h2o runtime -- violates the V5 no-ML hard rule and the no-external-runtime constraint; rules only sketched (author defers to a personal website).
- **Revisit trigger:** only if reduced to a fully-specified non-ML linear/arithmetic proxy -- under V5's permanent no-ML hard rule the NN form itself is never eligible. Demo-only (148 trades over 3 weeks), unverifiable.

- **STR-014 — THV System Final Edition** (ff_127271): custom-indicator formulas withheld,
  MTF/repaint unresolved, discretionary exits (settled with codex control row 2026-07-24).
  Revisit trigger: auditable indicator formulas / native MQL5 source published.
