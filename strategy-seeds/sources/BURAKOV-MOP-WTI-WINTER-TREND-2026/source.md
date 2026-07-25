---
source_id: BURAKOV-MOP-WTI-WINTER-TREND-2026
title: WTI winter-season time-series-momentum composite
publisher: International Journal of Energy Economics and Policy / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-07-25
created_by: Codex
last_updated: 2026-07-25
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-07-25
strategy_ids:
  - BURAKOV-MOP-WTI-WINTER-TREND-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - MOP-TSMOM-2012
---

# WTI Winter-Season Time-Series-Momentum Source

## Source identity

This packet joins two already governed peer-reviewed source lineages:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study,"
   *International Journal of Energy Economics and Policy* 8(2), 121-126.
   Official article:
   https://www.econjournals.com/index.php/ijeep/article/view/6092
   and open full text:
   https://www.econjournals.com/index.php/ijeep/article/download/6092/3608/15549.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250. DOI:
   https://doi.org/10.1016/j.jfineco.2011.11.003
   and institutional research page:
   https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

The bounded repository packets
`strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` were read completely for
this extraction. The Burakov packet records a complete six-page paper review,
including the conflicting abstract/table labels and the methods-section
resolution. The MOP packet is the existing governed JFE/AQR lineage for
own-past-return momentum across futures, including commodity ports.

## Findings used

- Burakov, Freidin, and Solovyev define their alternative-two WTI winter
  interval from the last October close through the following last May close.
  Their WTI sample reports a higher winter than summer return, but that result
  is historical source evidence rather than a Darwinex return forecast.
- Moskowitz, Ooi, and Pedersen supply the structural time-series-momentum
  premise: an instrument's own trailing return sign determines its directional
  trend state.
- Neither paper tests the interaction of those two findings, a monthly
  `XTIUSD.DWX` CFD package, an ATR hard stop, fixed-risk renewal, or the QM
  execution contract.

## Bounded mechanization

`BURAKOV-MOP-WTI-WINTER-TREND-2026_S01` is one predeclared interaction:

- host and only traded symbol: `XTIUSD.DWX`, D1, magic slot 0;
- decision: first tradable D1 bar of each broker month;
- active months: November through May; flat June through October;
- direction: sign of the completed 252-D1 close-to-close log return;
- positive sign: buy one monthly package;
- negative sign: sell one monthly package;
- exact zero or invalid history: remain flat;
- close and, when eligible, renew at the next broker-month boundary;
- frozen `4.0 * ATR(20)` hard stop, 35-day stale guard, spread ceiling, and
  one consumed attempt per broker month; and
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, backtest-only execution.

Seven calendar months are eligible in every complete year. The sign rule has
no fitted deadband, so exact equality is the only valid flat signal after
warm-up. A missing bar, blocked entry, failed close, stop, or rejected order
does not permit a same-month retry. Q02 must retire the carrier if realized
completed packages average below five per year.

The symmetric sign state deliberately does not import Burakov's positive
winter result as an unconditional long instruction. Burakov supplies the
fixed regime boundary; MOP supplies direction. Whether trend direction adds
anything inside that regime is a QM falsification hypothesis.

## Non-duplicate boundary

The pre-allocation deterministic check returned `CLEAN` for slug
`wti-winter-trend` and strategy ID
`BURAKOV-MOP-WTI-WINTER-TREND-2026_S01`. Manual review resolved the nearest
mechanics:

- `QM5_12603_wti-tsmom12m` applies the 252-D1 return sign year-round and uses
  no seasonal entry or forced season-end boundary.
- `QM5_20015_wti-halloween-winter` is unconditional long-only
  November-May; it has no price-conditioned direction.
- `QM5_20046_wti-halloween-ls` maps calendar months directly to long/short
  direction and does not read a trailing return.
- `QM5_12576_eia-wti-season` uses different refined-product demand months,
  an SMA(84), and a 21-D1 return confirmation with Friday flattening.
- `QM5_20052_xng-seas-trend` trades natural gas in Suenaga's two volatility
  windows with a 126-D1 horizon and a two-percent deadband.
- `QM5_12963_wti-winter-exhaust` is a short-only winter exhaustion fade with
  a separate price-stretch state.
- `QM5_12567_cum-rsi2-commodity` is a two-day cumulative-RSI pullback with a
  multiday exit, not a monthly WTI trend-regime package.

The load-bearing state is therefore the conjunction of the fixed WTI
November-May regime and the completed 252-D1 own-return sign. It is not a
renamed parameter port of either parent EA. Realized book correlation is
unknown until the unchanged downstream portfolio gate measures it.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed papers with DOI or official
  journal/institutional pages and existing durable repository review records.
- R2: PASS. Fixed months, lookback, sign map, package cadence, hard stop,
  stale exit, spread cap, and retry state are deterministic and frozen.
- R3: PASS. The registered `XTIUSD.DWX` D1 route supplies all runtime data.
- R4: PASS. Runtime uses only MT5 OHLC, ATR, broker calendar, executable
  quotes, position/deal history, and framework state; there is no ML, banned
  indicator, external feed, grid, martingale, scale-in, or pyramiding.

## Claim and safety boundary

No source performance number, book-correlation estimate, futures-roll
assumption, transaction-cost result, or portfolio-admission claim is imported.
The continuous Darwinex CFD differs from both papers' source data, and monthly
fixed-risk renewal differs from a continuous futures position.

This OWNER-approved packet authorizes one Strategy Card, deterministic
registry allocation, V5 build, strict compile, one `RISK_FIXED` backtest
setfile, and one paced Q02 enqueue. It does not authorize a live setfile,
AutoTrading, `T_Live`, a deploy or T_Live manifest, portfolio admission, a
portfolio-gate change, or a correlation waiver.
