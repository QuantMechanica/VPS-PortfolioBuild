---
source_id: MOP-SILV-WTI-FALLCORR-2026
title: WTI Trend In A Falling Equity-Correlation State
source_type: composite_peer_reviewed_packet
status: approved_source_complete
approval_basis: OWNER commodity/energy portfolio mission 2026-08-15
created: 2026-08-15
created_by: Research+Development
primary_url: https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum
correlation_url: https://doi.org/10.1016/j.intfin.2012.11.007
cards_extracted:
  - wti-fallcorr-tr
---

# WTI Trend In A Falling Equity-Correlation State

## Approval And Review Scope

The OWNER mission delivered to Codex on 2026-08-15 authorizes one new,
structural, low-frequency commodity/energy Strategy Card, deterministic EA
allocation, branch-only build, strict Q01 validation, and one paced non-live
Q02 enqueue. The candidate must be genuinely distinct from the certified
XAU/SP500/NDX/XNG book and the existing repository inventory. This packet
does not authorize a live, demo, shadow, optimization, or stress setfile; a
manual backtest; AutoTrading; T_Live access; a deploy manifest; a portfolio-
gate change; portfolio admission; or a correlation waiver.

The bounded source set was read completely before card extraction:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, the governed complete-
   paper extraction for Moskowitz, Ooi, and Pedersen (2012). The packet
   records a complete 23-page published-paper read and PDF SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
2. Silvennoinen and Thorp, *Financialization, Crisis and Commodity
   Correlation Dynamics*. The complete 46-page UTS Quantitative Finance
   Research Centre preprint was read end to end from
   `https://cfsites1.uts.edu.au/find/qfrc/files/rp267.pdf`; retrieved PDF
   SHA-256 `55CEAFBD91FB9484474BD8AA2710286F2ED3DC3ECE46A64F6634D64F5C5568AC`.
   The peer-reviewed article is in *Journal of International Financial
   Markets, Institutions and Money* 24 (2013), 42-65, DOI
   `10.1016/j.intfin.2012.11.007`.

The PDF is not committed. The durable citation, retrieval hash, complete-
review findings, adverse evidence, and mechanization boundary are preserved
below.

## Primary Trend Source

Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`.

The governed MOP packet records the paper's monthly rule: take the sign of
an instrument's own past return, go long after a positive return and short
after a negative return, and renew monthly. WTI crude is explicitly in the
paper's commodity-futures universe. The source supports the twelve-month own-
return sign and monthly cadence at the diversified futures-family level; it
does not establish a WTI-only result or the correlation conjunction below.

## Correlation-State Source

Silvennoinen, Annastiina, and Thorp, Susan (2013), "Financialization,
Crisis and Commodity Correlation Dynamics," *Journal of International
Financial Markets, Institutions and Money* 24, 42-65, DOI
`10.1016/j.intfin.2012.11.007`.

### Complete-review findings

- The paper studies Wednesday-to-Wednesday collateralized log returns from
  May 1990 through July 2009 for 24 commodity futures, including WTI crude,
  against total-return equity indices including the S&P 500.
- It models conditional means, conditional variances, and pairwise
  correlations with a double smooth-transition correlation GARCH model. The
  method can move among up to four correlation states driven by time, VIX,
  and non-commercial open-interest measures.
- The sample unconditional WTI/S&P 500 weekly-return correlation in Table 3
  is `0.06`; this full-sample number is not a trading threshold and does not
  transfer to continuous CFDs.
- Section 3.4 and Table 4 find time-varying commodity/equity integration.
  WTI/S&P 500 correlation moves from a negative estimated extreme state to
  a positive state during the global financial crisis. The preferred WTI
  model is driven by time, not VIX.
- The authors conclude that commodity/equity correlations often rose from
  near zero toward materially positive levels and that diversification
  benefits weakened. They do not show that low or falling WTI/equity
  correlation forecasts WTI returns, improves trend following, or creates a
  profitable strategy.
- The source uses multi-contract collateralized futures returns, weekly
  observations, factor-adjusted conditional means and variances, and a
  fitted nonlinear correlation model. QM cannot claim fidelity from a raw
  D1 Pearson correlation on XTIUSD.DWX and SP500.DWX.

## Bounded Price-Native Translation

At the first processed `XTIUSD.DWX` D1 bar of each broker month, the proposed
card will:

1. reconstruct exactly thirteen consecutive completed WTI broker-month-end
   closes and take the sign of the exact twelve-month log return;
2. intersect completed positive finite WTI and read-only SP500 D1 closes by
   exact timestamp and retain exactly 127 newest common closes;
3. form exactly 126 simple returns and split them into two adjacent,
   non-overlapping 63-return blocks, with each block using its own sample
   means and Pearson correlation;
4. admit the WTI trend only when the absolute correlation in the recent
   block is strictly lower than in the preceding block by more than
   `1e-12`; and
5. trade WTI only, with SP500 read-only, one monthly attempt, fixed-dollar
   risk, a frozen ATR hard stop, monthly replacement, and a stale guard.

This is a deliberately simple state proxy, not a replication of DSTCC-GARCH
and not an empirical claim that financialization is reversing. The two 63-
return blocks, strict absolute-correlation comparison, daily simple returns,
continuous-CFD mapping, WTI-only execution, ATR stop, fixed-dollar risk,
spread ceiling, restart ledger, and lifecycle are transparent QM choices.
No source return, Sharpe ratio, coefficient, significance, density, cost,
drawdown, neutrality, decorrelation, or portfolio result transfers.

## Reputable-Source Criteria

- R1 `PASS_FOR_DISCLOSED_PROXY`: peer-reviewed JFE trend evidence with WTI in
  the source universe plus a complete peer-reviewed WTI/S&P correlation-
  dynamics paper. Neither source tests the conjunction, and that limitation
  is binding.
- R2 `PASS`: completed-month trend endpoints, exact timestamp intersection,
  two fixed disjoint correlation blocks, estimator, direction, attempt,
  risk, stop, spread, and exit are deterministic and locked before Q02.
- R3 `PASS`: registered XTIUSD.DWX and SP500.DWX D1 histories provide every
  runtime input. SP500 is read-only and may never receive a magic or order.
- R4 `PASS`: closed-form native arithmetic and framework state only; no
  trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, or pyramiding.

## Non-Duplicate Boundary

The canonical pre-allocation checker returned `CLEAN` across 4,499 registry
rows and 595 root-card files for slug `wti-fallcorr-tr` and strategy ID
`MOP-SILV-WTI-FALLCORR-2026_S01`.

Manual review fixes the important boundaries:

- `QM5_21516_wti-decoup-trend` compares one 63-return WTI/XNG correlation
  magnitude with a fixed 0.30 ceiling. The proposed card compares two
  disjoint WTI/SP500 correlation blocks and has no XNG input or fixed
  correlation-level threshold.
- `QM5_21522_wti-lowdb-trend` estimates two 252-return conditional downside-
  beta slopes on below-mean SP500 days, requires at least 100 selected days
  per block, and compares signed beta. The proposed card uses all 126 rows,
  two 63-return blocks, symmetric Pearson correlation, and absolute
  correlation decline.
- `QM5_21523_wti-xau-div-tr` compares twelve-month WTI and gold return signs.
  It has no equity factor or correlation estimator.
- `QM5_13203_energy-downbeta` is a two-leg XTI/XNG cross-sectional package;
  the proposed card is a one-leg WTI time-series trend.
- `QM5_1178_qp-oil-equity-lag-sign` and `QM5_12397_oil-eq-reg` use oil to
  trade an equity index. The proposed card never orders SP500 and uses it
  only to gate an outright WTI trend.

Verdict:
`CLEAN_WTI_TREND_FALLING_ABSOLUTE_EQUITY_CORRELATION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately five to seven completed WTI positions per
full post-warm-up year. Q02 must retire on zero trades, fewer than five
completed positions per full post-warm-up year, or nonpositive governed
economics. Q09 alone may measure realized correlation with the certified
book. A falling in-sample correlation statistic does not prove a distinct
return stream.

Failure may not be rescued by changing the carrier, trend horizon, return
type, block length, absolute-value comparison, threshold tolerance,
direction, risk, stop, hold, spread, or retry policy.
