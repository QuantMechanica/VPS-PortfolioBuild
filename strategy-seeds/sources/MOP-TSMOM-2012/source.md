---
source_id: MOP-TSMOM-2012
source_type: paper
title: Time Series Momentum
authors: Tobias J. Moskowitz, Yao Hua Ooi, Lasse Heje Pedersen
publication: Journal of Financial Economics, 2012
url: https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve missions through 2026-08-06
created: 2026-06-27
created_by: Codex
last_reviewed: 2026-07-31
---

# Time Series Momentum

Canonical source for the governed WTI/XNG time-series-momentum extraction
family, including the bounded `wti-pulltrend` entry-timing experiment.

## Complete-paper review evidence

The complete 23-page published paper was retrieved from author Lasse Heje
Pedersen's NYU faculty site and read end to end on 2026-07-31. The retrieval
receipt is `retrieval_route_20260731.json`; the PDF SHA-256 is
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The PDF is not committed. The durable citation and content findings below are
the bounded extraction evidence.

Section 3.1 runs monthly return-predictability tests at lags 1 through 60 and
reports positive continuation for the first twelve monthly lags, including
the one-month lag. Section 3.2 defines the trading family mechanically: for
each instrument and month, take the sign of its own past `k`-month excess
return, go long when positive and short when negative, size inversely to ex
ante volatility, and hold for `h` months. Table 2 explicitly reports the
`k=1`, `h=1` commodity-futures portfolio (Panel B; alpha t-statistic 2.44).
Appendix A identifies WTI crude as one of the 24 commodity futures, sourced
from NYMEX.

Those facts do not establish a WTI-specific one-month result. Table 2 pools
the commodity universe, and the paper's security-level positive-results claim
is for the selected twelve-month strategy. The paper also uses excess returns
from rolling liquid futures and a 60-day-center-of-mass ex ante volatility
estimator. A Darwinex continuous CFD, close-to-close log return, fixed-risk
ATR stop, spread cap, and restart ledger are QM translations, not source
results.

## Source Scope

This source documents the broad time-series-momentum finding across liquid
futures markets, including commodities. QM cards port the source's structural
rule to DWX-tradable energy CFDs such as `XTIUSD.DWX` and `XNGUSD.DWX`, using
only MT5 D1 price history and broker calendar state at runtime.

## Extraction Notes

- Single-source lineage for R1: AQR/JFE page for Moskowitz, Ooi, and Pedersen,
  "Time Series Momentum".
- Extracted strategy: monthly 12-month return-sign momentum package on WTI.
- Extracted strategy: monthly 9-month return-sign momentum package on WTI with
  a 3-month same-sign confirmation filter.
- Extracted strategy: monthly WTI dual-horizon 6-month and 12-month
  return-sign momentum package requiring both horizons to agree.
- Extracted strategy: monthly WTI 12-month return-sign momentum package gated
  by a fixed ATR-as-percent-of-price volatility corridor.
- Extracted strategy: monthly natural-gas 12-month return-sign momentum package
  gated by a fixed ATR-as-percent-of-price volatility corridor.
- Extracted strategy: monthly natural-gas 3-month return-sign momentum package
  without the 12-month card's ATR/price volatility corridor; OWNER explicitly
  expanded this source lane for the 2026-07-23 commodity-sleeve mission.
- Extracted strategy: monthly WTI 2-month return-sign momentum package,
  distinct from existing 3-, 6-, 9-, and 12-month WTI rules; OWNER explicitly
  expanded this source lane for the 2026-07-23 commodity-sleeve mission.
- Extracted strategy: monthly WTI one-completed-calendar-month return-sign
  package with a one-month hold (`MOP-TSMOM-2012_XTI_S10`). The paper
  explicitly tests `k=1`, `h=1`; the OWNER 2026-07-31 mission authorizes the
  new structural commodity card and build. This is not a post-result rescue
  horizon.
- Extracted strategy: monthly natural-gas one-completed-calendar-month
  return-sign package with a one-month hold (`MOP-TSMOM-2012_XNG_S11`). This
  is the natural-gas carrier of the paper's source-declared `k=1`, `h=1`
  commodity rule, not an oscillator, a contrarian sign flip, or a parameter
  rescue of the existing three- and twelve-month XNG cards. The OWNER
  2026-08-02 commodity/energy sleeve mission authorizes its card and non-live
  build.
- Extracted strategy: monthly Brent 12-month return-sign momentum package on
  `XBRUSD.DWX`, kept separate from WTI TSMOM and Brent/WTI spread baskets.
- Runtime data deliberately excludes futures curves, open interest, inventory
  feeds, analyst forecasts, CSVs, APIs, and ML models.
- The EAs should be tested as energy sleeves, not as replacements for existing
  WTI calendar/event cards. The 9-month and dual-horizon cards are shorter or
  confirmation-filtered variants and must be duplicate-reviewed against the
  pure 12-month card.

## One-month WTI mechanization boundary

The S10 carrier evaluates only on the first tradable `XTIUSD.DWX` D1 bar of a
new broker month. It reconstructs the last two consecutive completed
broker-calendar month-end closes. A positive log return buys WTI; a negative
log return shorts WTI; equality or invalid history stays flat. The position is
renewed at the next month boundary. One attempt is persisted before history,
signal, spread, quote, news, stop, or order gates.

The baseline uses one `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
`3.5 * ATR(20,D1)` stop, no take-profit, and a forty-day stale guard. Friday
close and both news axes are off because the source hold is a full month and
the signal uses native prices only. These execution and risk choices are
falsifiable QM adaptations; no source PF, drawdown, WTI-only alpha, CFD basis,
or portfolio-correlation claim transfers.

## Reputable-source criteria for S10

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  article, DOI, author-hosted published PDF, and complete 23-page read.
- R2: PASS. Exact completed-month endpoints, sign mapping, one-month renewal,
  persistent attempt, stop, spread cap, and stale exit are fixed.
- R3: PASS. `XTIUSD.DWX` D1 is registered and already used by governed WTI
  builds; runtime requires no external data.
- R4: PASS. Native price, calendar, ATR, position, deal-history, and framework
  state only; no trained model, banned indicator, grid, martingale, scale-in,
  or pyramiding.

## One-month XNG mechanization boundary and reputable-source criteria

The S11 carrier applies the same source-declared one-month formation and hold
to `XNGUSD.DWX`. It evaluates only on the first tradable D1 bar of a new
broker month, reconstructs the latest two consecutive completed month-end
closes, buys after a positive log return, shorts after a negative log return,
and renews at the next month boundary. Equality or invalid history consumes
the month without an entry. The baseline keeps the S10 risk and lifecycle
contract locked except for a carrier-specific 3,000-point XNG spread ceiling:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen `3.5 * ATR(20,D1)` hard stop,
no take-profit, a forty-day stale guard, both news axes off, and Friday close
off.

- R1: PASS. Peer-reviewed *Journal of Financial Economics* paper with DOI,
  author-hosted complete text, durable retrieval hash, and natural gas in the
  paper's commodity universe.
- R2: PASS. Consecutive completed-month endpoints, same-sign direction,
  monthly renewal, persisted attempt, hard stop, spread cap, and stale exit
  are fixed before testing.
- R3: PASS. `XNGUSD.DWX` D1 is a registered, already exercised factory route;
  runtime requires no external data.
- R4: PASS. Native OHLC, calendar, ATR, quote, position, deal-history, and
  framework state only; no trained output, grid, martingale, scale-in, or
  pyramiding.

## WTI pre-pullback trend mechanization boundary

The OWNER commodity/energy sleeve mission dated 2026-08-06 authorizes one
additional bounded WTI card, `MOP-WTI-PULLTREND-2026_S01`. At the first
tradable D1 bar of a broker month, it reconstructs fourteen consecutive
completed broker-month endpoints. The slow state is the sign of the exact
twelve-completed-month log return ending one full month before the newest
endpoint. The newest completed-month return must have the opposite sign. The
EA then enters in the older twelve-month trend direction and holds one monthly
package.

Only the twelve-month own-return trend and monthly decision/hold cadence come
from Moskowitz, Ooi, and Pedersen. The non-overlapping one-month counter-move
gate is a transparent QM entry-timing hypothesis. The paper does not test this
conjunction, a skipped newest month, the Darwinex continuous CFD, an ATR hard
stop, fixed-dollar risk, spread caps, or the QM portfolio. No source return,
volatility, Sharpe ratio, drawdown, trade count, cost, or correlation result
transfers.

The construction is distinct from pure one-, two-, three-, six-, nine-, or
twelve-month WTI time-series momentum because an aligned newest month blocks
entry rather than confirms it. It is also distinct from unconditional WTI
reversal, fixed-season pullbacks, day-of-month trend, daily channel pullbacks,
event sleeves, XTI/XNG relative value, and the incumbent XNG cumulative-RSI2
pullback. The twelve-month trend endpoint, separate newest-month endpoint,
opposite-sign conjunction, monthly attempt clock, and trend-following trade
direction are jointly load-bearing.

- R1: PASS. The existing source packet records a complete read of the
  peer-reviewed *Journal of Financial Economics* paper, its DOI lineage, and
  durable retrieval hash; WTI is an explicit source commodity.
- R2: PASS. Fourteen consecutive completed month ends, two non-overlapping
  return intervals, strict sign rules, one consumed monthly attempt, frozen
  ATR stop, monthly rollover, and stale exit are deterministic.
- R3: PASS. Registered `XTIUSD.DWX` D1 history and MT5-native execution state
  are the only runtime dependencies.
- R4: PASS. Closed-form return arithmetic only; no trained model, banned
  indicator, external feed, grid, martingale, scale-in, or pyramiding.
