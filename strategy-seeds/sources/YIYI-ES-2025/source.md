---
source_id: YIYI-ES-2025
title: Commodity Futures Characteristics and Asset Pricing Models
publisher: Journal of Futures Markets
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directives 2026-07-11 and 2026-08-06
created: 2026-07-11
created_by: Research
last_updated: 2026-08-06
uri: https://onlinelibrary.wiley.com/doi/10.1002/fut.22559
cards_extracted:
  - energy-es-rank
  - xauxag-es-rank
---

# Qin et al. Commodity Expected-Shortfall Source Packet

## Approval And Review Scope

- The OWNER mission dated 2026-07-11 directs one new structural,
  low-frequency commodity or energy card, build, and Q02 enqueue.
- The complete open prepublication paper was reviewed end to end, including
  its data construction, all twenty characteristics, portfolio sorts, IPCA
  tests, sub-samples, panel regressions, appendices, tables, and bibliography.
- This packet extracts only the transparent expected-shortfall characteristic.
  The source's IPCA and latent-factor estimation are evidence context, not EA
  runtime logic.
- The OWNER mission dated 2026-08-06 authorizes the same locked characteristic
  as one paired `XAUUSD.DWX` / `XAGUSD.DWX` carrier extension. It does not
  authorize another characteristic, a tail-probability sweep, a direction
  change, or a post-result rescue.

## Primary Citation

Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025), "Commodity Futures
Characteristics and Asset Pricing Models," Journal of Futures Markets 45(3),
176-207. DOI: https://doi.org/10.1002/fut.22559.

Publisher record:
https://onlinelibrary.wiley.com/doi/10.1002/fut.22559

Open full paper:
https://acfr.aut.ac.nz/__data/assets/pdf_file/0006/927429/commodity_20240701.pdf

Earlier author paper:
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4746258

## Relevant Source Locations

- Data and characteristics, paper pp. 13-15: 34 commodity futures across five
  sectors, with all characteristics measured before prediction month t.
- Expected-shortfall definition, paper pp. 14-15 and Appendix A: average of
  the worst 5% of daily returns over months t-12 through t-1.
- Portfolio construction, paper pp. 13-16 and Table 3: rank characteristics
  cross-sectionally, form top and bottom portfolios, and hold during month t.
- Table 3, paper p. 42: the high-ES portfolio return exceeds the low-ES
  portfolio return in the broad source universe, although the full-sample
  one-way hedge t-statistic is only 1.36.
- IPCA tests, Sections 6.3-6.5 and Tables 5-7: expected shortfall is one of
  three characteristics consistently associated with latent-factor loadings.
- Conclusion, paper pp. 30-31: the authors attribute characteristic-sorted
  returns to changing risk exposures rather than unmodelled alpha.

## Bounded Mechanization

At the first tradable XTIUSD.DWX D1 bar of each broker month, use simple
close-to-close returns belonging to exactly the prior 12 completed broker
calendar months. For each energy leg:

    tail_count = ceil(valid_daily_returns * 0.05)
    ES = arithmetic_mean(the tail_count lowest daily returns)

Buy the higher-ES leg, whose worst tail is less negative, and short the
lower-ES leg, whose worst tail is more negative. Split RISK_FIXED=1000 equally
between XTI and XNG, attach frozen ATR hard stops, and close both legs at the
next month transition or the stale-time limit.

The paper ranks a broad futures universe. QM ranks two continuous broker CFDs,
uses raw CFD returns rather than collateralized futures-index excess returns,
and adds risk controls. This is a new carrier falsification, not a
replication. No source return, alpha, drawdown, correlation, or transaction
cost statistic is imported as a QM result.

The 2026-08-06 carrier extension,
`YIYI-ES-2025_XAU_XAG_S03`, preserves the same estimator, direction, formation
window, and monthly lifecycle:

- on the first tradable XAU D1 bar of a broker month, use synchronized simple
  returns whose ending timestamps fall inside exactly the prior twelve
  completed broker-calendar months;
- require every expected month plus at least 220 valid returns per metal;
- set `K = ceil(N * 0.05)` and average the `K` lowest daily returns per leg;
- buy the metal with the higher expected-shortfall statistic (the less
  negative lower tail) and short the metal with the lower statistic;
- split one `RISK_FIXED=1000` package equally, attach frozen per-leg ATR hard
  stops, renew at the next month transition, and repair an orphan; and
- consume a numerical tie or invalid-data month without a trade or retry.

This is a two-CFD carrier falsification of a broad commodity characteristic,
not a source result for gold versus silver. Opposite directions and equal
fixed-risk halves do not establish dollar, beta, volatility, factor, or
portfolio neutrality. The public full-paper URL was routed again on
2026-08-06 and generic automated retrieval was policy-deferred; the receipt is
`strategy-seeds/sources/YIYI-ES-2025/retrieval_route_20260806.json`. No new
source content was inferred from that deferred route.

## Non-Duplicate Boundary

- QM5_12567 is short-horizon long-only cumulative-RSI2 pullback logic.
- QM5_13129 energy-rsj ranks one completed month by normalized positive versus
  negative squared returns; expected shortfall uses the mean of the lower 5%
  over twelve complete months.
- QM5_13130 xti-xng-lowmax averages the five largest positive daily returns;
  this card averages the worst 5% negative tail and follows the source's
  opposite high-versus-low orientation.
- QM5_13118 energy-skew-rank uses the third standardized moment and QM5_13131
  energy-kurt-rank uses the fourth moment; neither estimates a tail mean.
- QM5_13133 energy-ivol measures regression-residual dispersion.
- QM5_13141 energy-ie-rank counts quadratic-factor residual observations above
  and below fixed half-sigma thresholds; it does not average raw downside-tail
  magnitudes.
- No registry slug, strategy ID, card, SPEC, or EA source implements a monthly
  XTI/XNG average-worst-5%-return rank.

The canonical checker returned only lexical energy-rank fuzzy matches. Manual
signal-input, transform, direction, formation-window, and exit review verdict:
CLEAN_AFTER_MANUAL_REVIEW before atomic allocation.

For `S03`, the deterministic pre-allocation checker scanned 4,292 EA-registry
rows and 408 canonical cards. It found no exact identity and the expected
same-source fuzzy sibling:

- `QM5_13143_energy-es-rank` uses the identical locked expected-shortfall
  characteristic on XTI/XNG. `S03` is a predeclared XAU/XAG carrier test, not a
  parameter variant or repair, and it inherits no sibling performance result.
- `QM5_20233_xauxag-skew-rank` estimates the centered third moment over twelve
  months; `QM5_20234_xauxag-rsj` compares one month of separately squared
  positive and negative returns; `QM5_20202_xauxag-rev18` uses an eighteen-
  month return sign. None averages the worst five percent of raw daily returns.
- Existing XAU/XAG ratio, OLS-residual, quantile-channel, calendar, momentum,
  idiosyncratic-volatility, and shock baskets use different information
  objects, directions, or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback rather than an opposite-side monthly tail-risk rank.

The prior-twelve-complete-month window, raw simple returns, five-percent lower-
tail mean, ceiling count, higher-ES-long/lower-ES-short direction, XAU/XAG
carrier, and monthly lifecycle are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## R1-R4

- R1 source: PASS. Peer-reviewed Journal of Futures Markets paper, DOI,
  publisher record, open full text, and bounded reproducible locations.
- R2 mechanical: PASS. Fixed twelve-month calendar window, fixed 5% lower-tail
  mean, high-minus-low direction, monthly hold, equal fixed risk, hard stops,
  deal-history restart guard, and orphan cleanup.
- R3 data: PASS with carrier risk. Registered XTI/XNG D1 histories provide
  closes, calendar timestamps, ATR, spreads, and broker metadata for `S02`;
  registered XAU/XAG D1 histories provide the same native inputs for `S03`.
- R4 deterministic/no ML: PASS. No IPCA, PCA, regression, option input,
  futures curve, external runtime feed, banned indicator, ML, grid,
  martingale, pyramiding, or adaptive PnL fit.

## Safety Boundary

The 2026-08-06 mission authorizes one durable G0 record, card, branch-only
non-live build, strict compile, and paced Q02 enqueue for `S03`. It excludes a
manual backtest; live, demo, or shadow setfiles; AutoTrading; `T_Live`; deploy
or T_Live manifests; portfolio admission; portfolio-gate changes; and
correlation waivers.
