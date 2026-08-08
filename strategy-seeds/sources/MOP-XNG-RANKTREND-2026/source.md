---
source_id: MOP-XNG-RANKTREND-2026
title: XNG monthly pairwise rank-trend extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-08_qm5_20267_xng_rank_trend_g0.md
parent_source_id: MOP-TSMOM-2012
created: 2026-08-08
created_by: Research+Development
cards_extracted:
  - xng-rank-trend
---

# XNG Pairwise Rank-Trend Source Packet

## Approved Source Of Record

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
https://doi.org/10.1016/j.jfineco.2011.11.003.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site. The reproducible receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
retrieval time, canonical faculty URL, 976,459 bytes, page count 23, and PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

## Source Findings Used

- Section 3.1 tests own-return predictability at monthly lags one through
  sixty and reports continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from each
  instrument's own price history and renews positions monthly.
- The complete-read parent packet records natural gas in the paper's
  commodity-futures universe.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling. It does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that a persistent
own-price path may contain directional information in natural gas at a monthly
clock. They do not establish an XNG-specific result, the rank statistic, its
threshold, trade density, or performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XNGUSD.DWX` month-end closes, ordered oldest to newest.
Compare every older/newer pair and sum `+1` when the newer close is higher and
`-1` when it is lower. Exact ties fail closed. Across thirteen observations
there are 78 comparisons, so `tau = S/78`. Buy when `S >= 28`, sell when
`S <= -28`, and otherwise consume the month flat. Renew at the next
broker-month boundary.

For thirteen observations without ties,
`Var(S)=n(n-1)(2n+5)/18=268.666...`. The continuity-corrected normal score at
`abs(S)=28` is approximately `1.647`, precommitting the conventional two-sided
ten-percent rank-trend boundary. The threshold is not selected from a QM
backtest.

The pairwise rank score, fixed boundary, continuous-CFD carrier, completed-
month reconstruction, no-tie rejection, one-attempt ledger, `RISK_FIXED`
sizing, ATR hard stop, XNG spread ceiling, and stale exit are transparent QM
choices. The paper does not specify or test them. No source return, alpha,
Sharpe ratio, drawdown, trade count, cost, threshold efficacy, CFD equivalence,
neutrality, or portfolio correlation is imported.

## Exact Statistical Contract

For positive finite completed month-end closes `P_0..P_12`, oldest to newest:

```text
S = 0
for every i from 0 through 11:
  for every j from i+1 through 12:
    require P_j != P_i
    S += +1 if P_j > P_i else -1

tau = S / 78
signal = BUY  when S >= +28
         SELL when S <= -28
         FLAT otherwise
```

There is no fallback to endpoint return, adjacent-return sign count, moving
average, OLS, oscillator, calendar direction, external series, or previous
pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation review on 2026-08-08 found no
`xng-rank-trend` slug, `MOP-TSMOM-2012_XNG_MK12_S17` strategy identity, or
XNG Mann-Kendall/all-pairs rank rule in the EA registry, intake cards, approved
cards, decisions, or source packets. The expected same-source WTI implementation
`QM5_20264_wti-rank-trend` is the locked carrier template, not an XNG sleeve.

The nearest XNG systems are materially different:

- `QM5_20262_xng-lr-trend` fits log-price OLS slope and gates on `R^2`; return
  magnitudes and squared residual dispersion are load-bearing.
- `QM5_20259_xng-mom-vote` votes on one-, three-, and twelve-month cumulative
  return signs.
- `QM5_13116_xng-signmom` counts the signs of adjacent monthly returns.
- `QM5_12804_xng-tsmom12m-atr` uses one endpoint return plus an ATR/price
  participation corridor.
- `QM5_12567_cum-rsi2-commodity` is a daily, long-only, short-horizon RSI(2)
  pullback with a five-bar lifecycle.

The XNG carrier, all-pairs ordering, tie rejection, integer score, fixed
critical boundary, monthly consumed attempt, and renewal clock are
load-bearing. Replacing the score with OLS, a cumulative return, adjacent-sign
counting, or RSI would collapse the candidate into an existing family.

## Reputable-Source Criteria

- R1: PASS. One canonical lineage to a named-author, peer-reviewed *Journal of
  Financial Economics* paper with DOI and a durable complete-read record.
- R2: PASS. Endpoint selection, all-pairs score, fixed boundary, direction,
  monthly attempt, stop, sizing, and exits are mechanical.
- R3: PASS. Registered `XNGUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, and deal state supply every runtime input.
- R4: PASS. Deterministic comparisons and integer arithmetic only; no trained
  model, adaptive PnL fit, external runtime feed, grid, martingale, scale-in,
  or pyramiding.

## Safety Boundary

This source packet supports research, one V5 build, strict compile/Q01, and one
paced non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that a new sleeve is
uncorrelated before Q09 evidence.
