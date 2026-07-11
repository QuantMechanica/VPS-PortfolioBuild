---
source_id: YIYI-ES-2025
title: Commodity Futures Characteristics and Asset Pricing Models
publisher: Journal of Futures Markets
source_type: peer_reviewed_paper
status: approved_source_complete
approval_basis: OWNER commodity-sleeve mission directive 2026-07-11
created: 2026-07-11
created_by: Research
uri: https://onlinelibrary.wiley.com/doi/10.1002/fut.22559
cards_extracted:
  - energy-es-rank
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

## R1-R4

- R1 source: PASS. Peer-reviewed Journal of Futures Markets paper, DOI,
  publisher record, open full text, and bounded reproducible locations.
- R2 mechanical: PASS. Fixed twelve-month calendar window, fixed 5% lower-tail
  mean, high-minus-low direction, monthly hold, equal fixed risk, hard stops,
  deal-history restart guard, and orphan cleanup.
- R3 data: PASS with carrier risk. Registered XTI/XNG D1 histories provide
  closes, calendar timestamps, ATR, spreads, and broker metadata.
- R4 deterministic/no ML: PASS. No IPCA, PCA, regression, option input,
  futures curve, external runtime feed, banned indicator, ML, grid,
  martingale, pyramiding, or adaptive PnL fit.
