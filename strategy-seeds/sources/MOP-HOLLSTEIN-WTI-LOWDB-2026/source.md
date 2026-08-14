---
source_id: MOP-HOLLSTEIN-WTI-LOWDB-2026
parent_source_ids:
  - MOP-TSMOM-2012
  - HOLLSTEIN-DOWNBETA-2021
title: WTI Twelve-Month Trend In A Falling Equity-Downside-Beta State
publisher: QuantMechanica governed composite of two peer-reviewed sources
source_type: peer_reviewed_trading_papers_bounded_composite
status: approved_source_complete
approval_basis: decisions/2026-08-14_wti_lowdb_trend_source_approval.md
g0_decision: decisions/2026-08-14_qm5_21522_wti_lowdb_trend_g0.md
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  HOLLSTEIN-DOWNBETA-2021: C6699329DAEC54DE5B89FA25D268229DC5C758E821A7055E8D56F162C009F6F4
created: 2026-08-14
created_by: Research+Development
cards_extracted:
  - QM5_21522_wti-lowdb-trend
---

# WTI Falling-Downside-Beta Trend Source Packet

## Approved Sources Of Record

The complete governed parent packets were read before this extraction:

- Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
  "Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250.
  The complete published-paper review and content receipt are preserved at
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
- Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
  "Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
  11(4), article 2150017, DOI `10.1142/S2010139221500178`. The complete
  accepted-manuscript and online-appendix review is preserved at
  `strategy-seeds/sources/HOLLSTEIN-DOWNBETA-2021/source.md`.

The durable OWNER source approval is
`decisions/2026-08-14_wti_lowdb_trend_source_approval.md`. The parent hashes
in the frontmatter bind this extraction to the material that was actually
reviewed.

## Findings Used

Moskowitz, Ooi, and Pedersen define time-series momentum as the sign of an
instrument's own past return, with monthly decisions and holding periods.
Their selected twelve-month rule is positive across the broad futures sample,
and WTI crude oil is an explicit source contract. The paper does not report a
WTI-only return, a downside-beta gate, or a Darwinex CFD result.

Hollstein, Prokopczuk, and Tharann define commodity DownBeta from a regression
of daily commodity excess returns on daily market excess returns, estimated
only when the market return is below its own prior-twelve-month daily average.
They sort monthly. Their high-minus-low DownBeta spread is negative but
insignificant, their cross-sectional slope is null, and the sign is unstable
across subperiods. The paper concludes that DownBeta is mostly unpriced. That
adverse evidence is retained; it supplies no standalone positive-return
claim.

## Bounded Composite Mechanization

The card tests whether the established twelve-month WTI trend is less exposed
to the certified index sleeve when WTI's recent downside beta to SP500 is
lower than in the preceding disjoint year.

At the first processed WTI D1 bar after a genuine broker-month transition:

1. Reconstruct thirteen consecutive completed WTI broker-month endpoints and
   form `trend_12m = ln(C_latest / C_12_months_older)`.
2. Load exactly 505 synchronized completed WTI and SP500 D1 closes, newest
   endpoint before the decision bar, and form 504 chronological simple-return
   pairs.
3. Split them into a preceding block `0..251` and recent block `252..503`.
   The blocks share their boundary close and no return observation.
4. Within each block independently, calculate the mean of all 252 SP500
   returns and retain only rows with `r_SP500 < mean_SP500`.
5. Require at least 100 retained rows and positive finite SP500 variance, then
   estimate by intercept OLS:

```text
r_WTI,t = alpha + beta_down * r_SP500,t + error_t
```

6. Admit the trend only when
   `beta_down_recent < beta_down_preceding - 1e-12`.
7. Buy WTI for a strictly positive admitted trend, sell WTI for a strictly
   negative admitted trend, and remain flat on a beta-gate failure or trend
   tie.

The recent-lower-than-preceding comparison is a time-series translation of a
cross-sectional characteristic. Raw continuous-CFD returns implicitly set the
unavailable daily risk-free return to zero, and `SP500.DWX` is a backtest-only
price proxy rather than CRSP market excess return. The conjunction is not
tested by either paper. It is a predeclared falsifiable QM hypothesis, not a
replication.

## Exact Runtime Contract

- Host and trade only `XTIUSD.DWX` on D1, slot 0, magic `215220000`.
- `SP500.DWX` is read-only. It has no magic, order, position, or package-PnL
  authority.
- Require exactly 505 synchronized completed D1 closes per beta input, strict
  chronology, positive finite closes, and an endpoint no more than ten
  calendar days stale.
- Use simple returns for DownBeta, block-local SP500 means, strict `<`
  down-day selection, sample covariance/variance, and an intercept-equivalent
  OLS slope. Use log returns only for the separate twelve-completed-month WTI
  trend.
- Consume the broker month before history, signal, news, spread, quote, ATR,
  sizing, or order gates. No stopped, blocked, failed, or flat decision may
  retry in the same month.
- Use one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` broker hard stop, no take-profit, and a 1,500-point entry
  spread cap.
- Close before monthly replacement or after forty calendar days. Friday close
  and both news axes are OFF for the source-aligned monthly hold.

No population variance, pooled block mean, overlapping return, `<=` down-day
selection, absolute beta threshold, reversed beta gate, trend-free direction,
score-sized risk, external equity series, signal indicator, trained output,
or fallback estimator is equivalent.

## Evidence And Claim Boundary

- The momentum paper pools 58 futures and does not establish WTI-only alpha.
- The DownBeta paper's characteristic is insignificant and explicitly weak;
  it is used only as a structural state variable.
- The source DownBeta market input is CRSP excess return. Raw SP500 CFD return
  and risk-free-zero substitution are material proxy errors.
- The source uses fixed-maturity collateralized futures. Darwinex CFDs contain
  different roll, financing, gap, and execution effects.
- A low recent downside beta does not prove low full-sample, upside, tail,
  volatility, or portfolio correlation. Q09 alone may evaluate realized book
  overlap.
- No source or sibling performance, significance, cost, density, drawdown,
  neutrality, or correlation statistic transfers.

## Non-Duplicate Boundary

The canonical pre-allocation check was `CLEAN` across 4,394 registry rows and
490 root cards. Manual review separates the closest families:

- `QM5_13203_energy-downbeta` performs one concurrent cross-sectional XTI/XNG
  DownBeta rank and trades both legs. This card compares two disjoint WTI
  DownBeta histories, uses the lower recent state only as a gate, and trades
  one WTI leg in a separately measured twelve-month trend direction.
- `QM5_21516_wti-decoup-trend` gates the same trend family with weak absolute
  63-D1 WTI/XNG correlation. This card has no XNG input and instead uses
  block-local SP500 down-day conditional OLS over 504 returns.
- Pure WTI TSMOM is unconditional. WTI volatility-beta, jump-beta, realized-
  VoV, tail, moment, calendar, event, breakout, reversal, and robust-location
  systems do not estimate this equity-downside-beta state.
- `QM5_12567_cum-rsi2-commodity` is a long-only short-horizon XNG cumulative-
  RSI pullback and shares no carrier, state, direction map, or clock.

Verdict: `CLEAN_WTI_FALLING_DOWNSIDE_BETA_GATED_TWELVE_MONTH_TREND`.

## Reputable-Source Criteria

- R1 `PASS_WITH_ADVERSE_EVIDENCE`: two peer-reviewed primary sources, DOI
  lineage, complete governed reads, explicit WTI membership, and the DownBeta
  null preserved.
- R2 `PASS`: exact synchronized support, two disjoint blocks, block-local
  down-day OLS, strict falling-beta gate, trend sign, attempt, risk, stop,
  rollover, and stale guard.
- R3 `PASS_FOR_DISCLOSED_PROXY`: registered WTI and SP500 D1 closes suffice;
  risk-free and CRSP fidelity are unavailable and are not claimed.
- R4 `PASS`: deterministic native arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Q02 retires below five completed positions per full post-warm-up year or on
nonpositive governed economics. Do not rescue failure by changing the trend
horizon, beta history, block offsets, down-day definition, row floor,
regression, beta direction, cadence, risk, stop, hold, spread, retry policy,
or carrier.

This packet authorizes one branch-only non-live build and one paced Q02
handoff. It authorizes no manual backtest, live/demo/shadow/stress/optimization
setfile, AutoTrading action, `T_Live` or deploy manifest, portfolio-gate edit,
portfolio admission, or correlation waiver.
