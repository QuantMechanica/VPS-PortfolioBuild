---
source_id: MU-XNG-MONVOL-2007
title: Weather, Storage, and Natural Gas Price Dynamics - Monday volatility extraction
publisher: Energy Economics
source_type: peer_reviewed_paper
status: cards_ready
created: 2026-07-10
created_by: Codex
cards_extracted:
  - xng-mon-range
---

# Mu Natural-Gas Monday Volatility Source

## Source Identity

- Mu, Xiaoyi. "Weather, Storage, and Natural Gas Price Dynamics: Fundamentals
  and Volatility." *Energy Economics* 29(1), 2007, pp. 46-63.
  DOI `10.1016/j.eneco.2006.04.003`.
- Complete primary-author working paper: International Association for Energy
  Economics, December 2004,
  `https://www.iaee.org/en/students/best_papers/xiaoyi_mu2.pdf`.

The mission directive dated 2026-07-10 approved one structural, low-frequency
commodity/energy card and build. This bounded peer-reviewed source was selected
because its Monday natural-gas volatility result supplies a return driver not
present in `QM5_12567` cumulative-RSI2 logic.

## Complete Read And Bounded Extraction

The 31-page author manuscript was read end-to-end, including the natural-gas
market background, daily-return data, GARCH methodology, weather and storage
variables, empirical results, conclusion, references, figures, and Tables 1-5.
The paper finds no dependable intraweek mean-return pattern, but its Monday
conditional-variance dummy is positive and statistically significant for both
nearest- and second-month return series across reported specifications.

This extraction is limited to that Monday variance result. The source does not
publish a breakout strategy, so the QM card clearly labels its Friday-
compression/Monday-expansion rule as a falsifiable mechanization rather than an
author trading claim.

## Runtime Guardrails

- Native MT5 `XNGUSD.DWX` H4/D1 OHLC, spread, ATR, broker calendar, and
  framework position state only.
- No weather, storage, futures-curve, volume, open-interest, API, CSV, GARCH,
  ML, adaptive PnL fitting, grid, martingale, pyramiding, or discretionary
  input at runtime.
- One position on magic slot 0, `RISK_FIXED=1000` backtest setfile only.

## R-Rules

- R1 reputable source: PASS. Peer-reviewed *Energy Economics* paper, DOI, and
  complete primary-author manuscript.
- R2 mechanical: PASS. Fixed Friday compression, non-gap Monday H4 close
  breakout, structural stop, fixed-R target, and session/time exit.
- R3 data available: PASS. `XNGUSD.DWX` H4 and D1 are available to the V5
  factory.
- R4 no ML/banned logic: PASS. Native OHLC/ATR only; the source's GARCH model
  is not implemented in the EA.

