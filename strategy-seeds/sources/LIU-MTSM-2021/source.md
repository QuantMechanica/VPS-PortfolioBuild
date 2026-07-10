---
source_id: LIU-MTSM-2021
title: Managed commodity time-series momentum using asymmetric partial moments
publisher: International Review of Financial Analysis
source_type: peer_reviewed_paper
status: cards_ready
created: 2026-07-10
created_by: Codex
cards_extracted:
  - xti-mtsm-s2
---

# Liu, Lu, and Wang Managed Time-Series Momentum Source

## Source Identity

- Liu, Zhenya; Lu, Shanglin; and Wang, Shixuan (2021), "Asymmetry,
  tail risk and time series momentum," *International Review of Financial
  Analysis* 78, article 101938.
- DOI: https://doi.org/10.1016/j.irfa.2021.101938.
- University of Reading accepted manuscript:
  https://centaur.reading.ac.uk/100824/1/FINANA-D-21-00329-R1.pdf.
- The complete 39-page repository copy, including methodology, both MTSM
  variants, robustness sections, limitations, and references, was reviewed on
  2026-07-10.

## Bounded Extraction

The paper starts with a time-series-momentum direction determined by the sign
of the cumulative return over a fixed lookback. It then separates the latest
five daily returns into an upper partial moment (mean squared positive returns)
and a lower partial moment (mean squared negative returns). Recursive 80th
percentiles of each partial-moment history divide the state into four regions.

This source contains two distinct managed rules, MTSM-S1 and MTSM-S2. The
selected card extracts MTSM-S2 because the authors identify it as the relevant
post-2013 rule and carry that conclusion through their COVID-period check. Its
actions are deterministic:

- both partial moments in their tails: flat;
- lower partial moment alone in its tail: long regardless of base momentum;
- upper partial moment alone in its tail: short regardless of base momentum;
- neither in its tail: retain the base momentum direction.

No second card is opened for MTSM-S1 in this mission. That variant is a
historical-regime alternative whose opposite Region-2/Region-4 actions would
create an overlapping parameter/regime sibling, not an independent sleeve for
the requested new portfolio exposure.

## QM Translation

The source tests a diversified portfolio of 31 Chinese commodity futures, not
WTI or a Darwinex CFD. `XTIUSD.DWX` is therefore a portability experiment, not
an asserted replication. The EA preserves the paper's 30-D1 momentum state,
five-D1 upper/lower partial moments, 80th-percentile four-region map, and S2
actions. To keep the computation bounded and strictly free of future data, the
recursive reference distribution is represented by the 252 observations that
end before the current signal bar. Q03 may test only the card-declared 126,
252, and 504-observation histories.

V5 fixed-risk sizing replaces the paper's daily 40%-volatility targeting. The
paper itself notes that allocation is important, so this is a material
translation risk. An ATR hard stop and framework Friday flatten bound each CFD
risk package. Persistent target states may re-enter after the weekend; target
changes close or reverse on the next D1 decision.

## Evidence And Limitations

- Data: daily close-to-close returns for 31 liquid Chinese commodity futures,
  January 2007 through December 2019, plus a December 2019-May 2020 check.
- Signal: sign of cumulative return for lookbacks from 20 through 250 trading
  days; the worked MTSM example uses 30 days.
- Tail state: five-day upper and lower partial moments, each compared with its
  recursively generated 80th percentile.
- The authors report improved risk-adjusted portfolio results across multiple
  lookbacks, but they do not establish a WTI-specific result.
- The study omits transaction costs and uses a changing-market-structure
  explanation for why S1 and S2 differ across subsamples.
- None of the paper's portfolio performance is imported as a QM expectation.
  Q02 and later gates are the only evidence for this single-symbol port.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed 2021 journal article with DOI and
  author manuscript in an institutional repository.
- R2 mechanical: PASS. Fixed momentum, partial-moment, quantile-region, S2
  action, stop, and exit rules.
- R3 data available: PASS. Only registered `XTIUSD.DWX` D1 closes, ATR,
  spread, broker calendar, and V5 position state are required.
- R4 no ML/banned logic: PASS. Deterministic arithmetic and order statistics;
  no learned model, external runtime feed, grid, martingale, or pyramiding.

