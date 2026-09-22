# Native execution probe — synthetic mechanics only

NautilusTrader 1.221.0: 45 bounded fixtures, two identical runs. All expected fills, fees, lifecycle ordering and expected failure cases matched. Deterministic result SHA256: `eac454fbff7c9021496c7df4570563f982e3740e806c771a8b4878b37fefb282`.

MESM9.GLBX metadata come from the locally hash-verified definition (multiplier $5/point, tick 0.25, USD). Every price event is synthetic. The three frozen assumptions are BASE ($1.90 RT, 1 tick/side, 100 ms), ADVERSE ($2.50, 2 ticks, 250 ms), SEVERE ($3.00, 4 ticks, 750 ms). Fees are charged per contract per side.

| BASE counterexample | Native temporal/default behavior | Fresh-gated custom-fill behavior |
|---|---|---|
| Sparse quote latency | Timer fills old ask at 5000.50 after 100 ms | First new ask fills 5002.50 after 1 s |
| Stop 4998 through bid gap | Default L1 fills 4998.00; custom-priced standing stop fills 4994.75 immediately | Client stop fills 4994.25 after 100 ms |
| Quantity selection | Decision-frozen quantity 2 remains 2 | First eligible quote implies quantity 1 |

Native default market/stop fixtures keep frozen fees but deliberately omit the frozen slippage/latency adapters. Native-latency and standing-stop fixtures use the custom N-tick prices but preserve native temporal handling. Fresh-gated fixtures wait for QuoteGate eligibility and then submit a zero-additional-latency native market order. The sizing-at-decision fixture freezes quantity early and submits after eligibility; queued-order cancellation/resizing is not tested.

Both BUY and SELL, quantities 1 and 2, all three cost scenarios, exact latency boundaries, equal receive timestamps in source order, gap stops, native 15:55 New York timer and a missed 15:59:30 flat deadline are covered. The missed deadline correctly leaves open exposure and an explicit invalid reason. Same-time later quotes do not overwrite the first eligible quote.

The custom fill model has only synthetic depth 10 and quantity <=2. This is **not evidence of real liquidity**, partial fills, actual provider fees, or usable live execution. Fresh native market orders are **not a complete native strategy runner**. Real-session signal/status integration, DBN-to-native ordering, per-event marked equity/risk parity, cancellation races and full strategy lifecycle remain open. The frozen economic trial remains **NOT_RUN**; no market replay, account connection, credential access or download occurred.
