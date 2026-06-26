---
source_id: CORWIN-SCHULTZ-HL-SPREAD-2012
title: Corwin-Schultz high-low spread estimator with liquidity reversal supplement
status: cards_ready
created: 2026-06-26
created_by: Codex
source_type: academic_paper
uri: https://doi.org/10.1111/j.1540-6261.2012.01729.x
---

# Corwin-Schultz High-Low Spread Estimator Source Notes

## Source Identity

- Primary source: Corwin, S. A. and Schultz, P. (2012), "A Simple Way to Estimate Bid-Ask Spreads from Daily High and Low Prices", Journal of Finance. DOI: https://doi.org/10.1111/j.1540-6261.2012.01729.x.
- Supplementary source: Avramov, D., Chordia, T. and Goyal, A. (2005/2006), "Liquidity and Autocorrelations in Individual Stock Returns", SSRN abstract 555968, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=555968.

## Mining Scope

One card was extracted:

- `cs-spread-rev`: H1 high-low inferred spread shock reversal after an outsized return bar.

## Evidence Notes

- Corwin and Schultz provide a high-low based bid-ask spread estimator that can be computed from OHLC bars without tick or order-book data.
- The QM candidate uses the estimator as a Darwinex-native illiquidity proxy, not as a direct execution-cost estimate.
- Avramov, Chordia and Goyal are used only for the short-run reversal and illiquidity thesis. `QM5_10330_illiq-rev` already implements a related broker-spread/tick-volume variant, so this card is deliberately marked as a near-duplicate candidate for G0 review.
- Full-text retrieval of the primary DOI was not available in this workspace session. Before G0 approval or EA build, the exact Corwin-Schultz formula and edge-case handling must be verified against the paper or a trusted reference implementation.

## Guardrails

- No external data calls in the EA.
- No ML, no optimization learned at runtime, no grid, no martingale.
- No EA build should proceed until the formula verification note in the card is resolved.
- Duplicate review against `QM5_10330_illiq-rev`, `QM5_10328_residual-rev`, and `QM5_11071_spike-reversal` is mandatory.
