# Smooth-drift sleeve candidates for the FTMO single-account KPI

Date: 2026-07-27  
Disposition: source shortlist, not a Strategy Card and not pipeline evidence

## Required derived specification

The search target is an intraday-flat, mechanical, non-ML sleeve which, at about
1% account risk per trade, can plausibly deliver about 150 trades/year and
0.13% account expectancy/trade while achieving `FUND_SCORE >= 1.0` (median
60-calendar-day gain divided by the 90th-percentile drawdown observed inside a
60-day window). The existing best sleeve reportedly scores 0.41. Therefore the
research problem is not to add raw per-trade edge; it is to find the same edge
with roughly 2.4 times better gain-to-tail-drawdown smoothness.

No cited source below establishes that complete target. `FUND_SCORE` is a
QuantMechanica measurement, and none of the papers reports it. Each candidate
is consequently a falsifiable hypothesis for Q-only evaluation, not a claim of
profitability.

## Ranked candidates

### 1. Cross-contract first-half-hour to last-half-hour momentum basket

Jin, Kearney and Li (published online 2019; *Journal of Futures Markets* 2020,
[doi:10.1002/fut.22084](https://doi.org/10.1002/fut.22084)) report that the
first half-hour return positively predicts the last half-hour return in four
Chinese commodity futures and that the relation is strongest in metals when
early volume or volatility is high. Gao et al. (2021, *Journal of Financial
Economics* 142, 377-403, [paper](https://www3.nd.edu/~zda/intramom.pdf))
study intraday momentum across a broader futures set and link the last
half-hour return to earlier-session information.

Mechanical translation: once per liquid DXZ-supported contract/day, measure the
first 30-minute signed return; enter in that direction only for the final
30-minute interval, with a predeclared volatility/volume eligibility filter,
ATR-normalized stop, fixed risk, mandatory news blackout, and forced flat at
the session close. Combine several low-correlated eligible contracts under one
portfolio risk cap rather than increasing risk on one instrument.

Why it may smooth: one short holding interval, one decision per instrument/day,
cross-contract breadth, and volatility-normalized allocation distribute the
same target trade count across independent observations. This is the strongest
source-backed candidate, but the exact exchange-session mapping to DXZ CFDs,
costs, and volume proxy are NOT ESTABLISHED.

### 2. Stocks-in-play 5-minute opening-range breakout basket

Zarattini, Barbon and Aziz (2024, revised 2025, Swiss Finance Institute Research
Paper 24-98, [SSRN 4729284](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4729284))
evaluate a mechanical five-minute opening-range breakout over more than 7,000
US stocks from 2016-2023, emphasizing unusually active “stocks in play” and
consistent, relatively uncorrelated returns.

Mechanical translation for research only: define the first five-minute high
and low; trade the first close beyond the range only when a numeric
activity/volatility threshold is met; one attempt per instrument/day; ATR stop
and time exit before the close. Reject discretionary news interpretation.

Why it may smooth: breadth and strict daily selection can avoid concentrating
losses in one index regime. However, DXZ does not provide the paper's 7,000-stock
universe, and a single index CFD is not an equivalent implementation. This
candidate is therefore `NEEDS-MARKET-MAPPING`, behind candidate 1. A 2026 MNQ
falsification study tested fourteen OHLCV signal families over 947 days and
found none met all of its cost-aware validation criteria
([arXiv:2605.04004](https://doi.org/10.48550/arXiv.2605.04004)); this is a
useful adverse result, not support).

### 3. Intraday session-time seasonal basket, Brent/metals only

Ewald et al. (2025, *Quantitative Finance*,
[doi:10.1080/14697688.2025.2535479](https://doi.org/10.1080/14697688.2025.2535479))
find statistically significant time-of-day patterns in ICE Brent futures using
one-minute data from 2010-2021. Iwatsubo, Watkins and Xu (2018, *Journal of
Commodity Markets*, [doi:10.1016/j.jcomm.2018.05.001](https://doi.org/10.1016/j.jcomm.2018.05.001))
document materially different intraday efficiency/liquidity regimes for gold
and platinum across Tokyo, London and New York sessions.

Mechanical translation: for XTIUSD/XAUUSD only, estimate a walk-forward,
predeclared signed return for fixed 30-60 minute clock buckets; trade a bucket
only when the sign is stable in every training subperiod, spread is below a
fixed threshold, and no mandatory-news blackout applies; force flat at bucket
end. Do not optimize arbitrary entry minutes.

Why it may smooth: multiple small, time-diversified exposures could generate
steady frequency without overnight risk. But Brent is not WTI, futures are not
DXZ CFDs, the cited metal paper documents microstructure rather than a profitable
rule, and DST/server-time translation is NOT ESTABLISHED. This is an exploratory
candidate with high data-mining risk.

### 4. Simple index-futures open-to-close trend with an intraday stop

Rentzler and Yu (2004, [SSRN 523762](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=523762))
study simple intraday exits applied to an index-futures trend-following base
strategy that enters at the open and exits at the close; their abstract reports
that intraday stop-loss rules add return to that base strategy.

Mechanical translation: define trend using only prior completed daily bars,
enter once at the cash-session open in the prior trend direction, fixed
volatility stop, no re-entry, and force flat at the close.

Why it may smooth: capped daily loss and one trade/day are directly compatible
with the desired frequency. The source is old, its abstract does not establish
modern net-of-cost performance, and a 2026 walk-forward study reports no
significant net edge for simple mean-reversion and intraday-breakout rules on
recent five-minute S&P 500 data
([SSRN 6977700](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6977700)).
Treat this as a low-priority control, not a lead candidate.

## Explicit rejects

- ICT/SMC and Wyckoff: closed by the brief; additionally depend on interpretive
  pattern taxonomies in common use.
- ML, reinforcement learning, and learned classifiers: outside the Edge Lab
  charter even if a paper reports attractive returns.
- Overnight/intraday reversal and overnight premia: incompatible with the
  intraday-flat requirement.
- Martingale, grid, averaging down, and loss-recovery sizing: prohibited and
  structurally hostile to the drawdown-tail objective.
- Single-instrument parameter-mined ORB/RSI/VWAP variants without independent
  source evidence: the recent MNQ falsification evidence makes these especially
  weak priors.

## Recommended next deterministic action

Source candidate 1 into one experimental specification covering only
DXZ-supported liquid index/metal/energy contracts. Freeze session definitions,
costs, news blackout, fixed-risk sizing, and the volume proxy before testing.
Require approximately 150 aggregate trades/year without relaxing eligibility.
Report expectancy, rolling-60-day gain distribution, within-window observed
equity drawdown distribution, `FUND_SCORE`, and per-contract contribution.

Pass to Strategy Card extraction only if out-of-sample `FUND_SCORE >= 1.0`,
expectancy is near 0.13% account/trade at the declared 1% risk, both drawdown
caps remain satisfied, and no single contract supplies more than half of total
profit. Otherwise stop; do not tune the threshold to the target.
