---
source_id: AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
title: WTI monthly lag-one ADF persistence-gated trend
publisher: QuantMechanica governed synthesis from a complete Wiley extraction and complete peer-reviewed WTI continuation record
source_type: ai_originated_book_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-03_wti_monthly_adf_persistence_trend_source_approval.md
parent_source_ids:
  - SRC05
  - MOP-TSMOM-2012
created: 2026-09-03
created_by: Research+Development
cards_extracted:
  - wti-madf-persist-tr
---

# WTI Monthly Lag-One ADF Persistence-Gated Trend

## Approval and complete bounded read

The durable approval is
`decisions/2026-09-03_wti_monthly_adf_persistence_trend_source_approval.md`.
The current explicit OWNER mission authorizes one new structural low-frequency
commodity/energy sleeve, expressly permits direct WTI trend logic, requires
fixed-risk backtests, and requests one paced Q02 enqueue.

The supporting records, immutable hashes, and exact read scopes are bound in
`retrieval_route_20260903.json`. No new online page was fetched or represented
as read.

Chan (2013), *Algorithmic Trading: Winning Strategies and Their Rationale*,
Wiley, pp. 41-44, describes the ADF regression intuition: price changes are
regressed on a lagged level and lagged changes; the lagged-level coefficient
divided by its standard error is compared on the negative tail. His Example
2.1 uses chronological prices, a nonzero offset, zero deterministic drift,
one lag, and displays a 10% critical value of `-2.594` for its sample.

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, documents monthly own-return
continuation across liquid futures and names NYMEX WTI in the commodity
universe. The repository packet records a complete 23-page published-paper
read and pins its author-hosted PDF hash.

Chan's example is USD/CAD and seeks evidence of mean reversion. The momentum
paper has no ADF gate. Neither source validates the combined WTI rule, the
60-month sample, the inclusive translated threshold, a continuous CFD, fixed
risk, costs, density, profitability, or book correlation. Those are explicit
pre-result QuantMechanica choices.

## Locked hypothesis and formula

WTI has physical supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand drivers absent from the certified index/metal
carriers and distinct from natural-gas weather/storage exposure. The
hypothesis is that a twelve-month WTI move is more suitable for continuation
when a lag-one ADF regression does not show strong negative error correction.

At the first executable D1 tick after a genuine normalized broker-month
transition, reconstruct exactly sixty consecutive completed broker-month-end
closes `C[0..59]`, oldest to newest. Exclude every current-month price and set
`x[t]=ln(C[t])`.

For `t=2..59`, create 58 regression observations:

```text
y[t] = x[t] - x[t-1]
z[t] = x[t-1]
w[t] = x[t-1] - x[t-2]
y[t] = alpha + gamma*z[t] + phi*w[t] + error[t]
```

Compute the intercept OLS exactly by centered cross-products:

```text
Szz = sum((z-mean(z))^2)
Sww = sum((w-mean(w))^2)
Szw = sum((z-mean(z))*(w-mean(w)))
Szy = sum((z-mean(z))*(y-mean(y)))
Swy = sum((w-mean(w))*(y-mean(y)))
det = Szz*Sww-Szw^2

gamma = (Szy*Sww-Swy*Szw)/det
phi   = (Swy*Szz-Szy*Szw)/det
alpha = mean(y)-gamma*mean(z)-phi*mean(w)
SSE   = sum((y-alpha-gamma*z-phi*w)^2)
s2    = SSE/55
se_gamma = sqrt(s2*Sww/det)
adf_t = gamma/se_gamma
mom12 = x[59]-x[47]
```

Require finite arithmetic, positive `Szz`, `Sww`, `det`, `SSE`, and
`se_gamma`, with `det > 1e-12*Szz*Sww` and energy floors of `1e-18`.

```text
BUY  iff adf_t >= -2.594 and mom12 > +1e-12
SELL iff adf_t >= -2.594 and mom12 < -1e-12
FLAT otherwise
```

The ADF comparison is inclusive. The `-2.594` number is a frozen state
boundary borrowed transparently from Chan's displayed example, not a claimed
finite-sample critical value for this 60-month CFD regression. Non-rejection
does not prove a unit root, trend, persistence, or predictability. Only
`mom12` chooses side; neither statistic magnitude changes size.

## Attempt, execution, risk, and lifecycle

Persist the normalized broker month as attempted before history, signal,
news, spread, quote, ATR, sizing, margin, or submission. A flat or rejected
month is never retried. Permit no foreign WTI position and at most one owned
position.

Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget, a
frozen completed-D1 `3.5*ATR(20)` broker hard stop, no target, and an inclusive
1,500-point spread ceiling. Both news axes, legacy news mode, Friday close,
and stress rejection are off. Close at the first processed tick in a later
broker month or after forty elapsed calendar days. Close malformed owned
exposure defensively. There is no intramonth signal exit or flip, target,
trail, break-even move, partial close, scale-in, grid, martingale, or pyramid.

## Reputable-source criteria

- **R1 — PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_BOOK_PAPER_EVIDENCE.** One
  durable AI lineage binds a complete governed Wiley extraction and complete
  peer-reviewed WTI paper record, precise bounds, immutable hashes, and
  explicit non-transfer limits.
- **R2 — PASS.** Month clock, endpoints, logarithms, lag-one constant/no-trend
  regression, centered OLS, residual degrees of freedom, inclusive boundary,
  momentum side, attempt, fixed risk, hard stop, spread, and lifecycle are
  mechanical and locked.
- **R3 — PASS_WITH_CONTINUOUS_CFD_BASIS_RISK.** Registered native
  `XTIUSD.DWX` D1 history, quotes, metadata, positions, deals, and broker time
  provide every runtime input.
- **R4 — PASS.** Deterministic bounded price/calendar arithmetic and native V5
  execution only; no trained output, prohibited signal indicator, external
  runtime feed, grid, martingale, scale-in, pyramid, or random path.

## Non-duplicate boundary

The fail-closed corrected-root scan at
`artifacts/qm5_wti_madf_persist_tr_preallocation_dedup_20260903.json` returned
`CLEAN` across 4,804 registry identities, 1,433 cards, and 45 Wiki nodes.

- KPSS `QM5_41317` sums partial demeaned log-level residuals and divides by a
  fixed-lag Newey-West long-run variance. This rule fits an intercept OLS of
  first differences on lagged levels and one lagged difference and uses the
  lagged-level coefficient t-statistic.
- Ljung-Box, ARCH-LM, BDS, Jarque-Bera, entropy, von Neumann, variance-ratio,
  rank, and robust-block families operate on different information objects.
- Pure time-series momentum has no error-correction-state gate; calendar,
  event, channel, seasonality, and XTI/XNG relative-value cards use different
  clocks and payoff triggers.
- Certified `QM5_12567` is a long-only two-day cumulative-RSI XNG pullback,
  not symmetric monthly direct-crude persistence.

The synthetic fixture contains upward and downward paths that qualify and a
strongly mean-reverting oscillatory path that is flat. Verdict:
`CLEAN_WTI_MONTHLY_LAG1_CONSTANT_NO_TREND_ADF_T_GE_MINUS2P594_GATED_12M_CONTINUATION`.

## Claim, kill, and safety boundary

The sources support separate ADF mechanics and monthly WTI continuation, not
this conjunction. Q02 must retire on zero positions, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
formula/fixture mismatch, current-month leakage, invalid fixed risk, missing
hard stop, malformed lifecycle, or nondeterminism. No threshold or mechanic
may be changed after observing a failure. Q09 alone may establish realized
portfolio decorrelation.

This packet authorizes one Strategy Card, deterministic identity and magic
allocation, one branch-only non-live V5 build, reference tests, strict Q01,
one D1 fixed-risk backtest set, and one paced Q02 enqueue while CPU admission
remains clear. It authorizes no manual backtest, optimization, live/demo/
shadow/stress preset, terminal control, portfolio-gate edit, correlation
waiver, portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or
live use.
