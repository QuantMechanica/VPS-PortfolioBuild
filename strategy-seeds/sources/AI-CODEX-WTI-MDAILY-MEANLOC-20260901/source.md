---
source_id: AI-CODEX-WTI-MDAILY-MEANLOC-20260901
source_type: ai_originated_governed_synthesis
title: WTI completed-month daily mean-location continuation
author: OpenAI Codex
supporting_authors: Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_daily_mean_location_trend_source_approval.md
created: 2026-09-01
created_by: Codex
last_reviewed: 2026-09-01
cards_extracted:
  - QM5_41262_wti-mdaily-meanloc-tr
---

# WTI Completed-Month Daily Mean-Location Continuation

## Canonical origin and evidence boundary

This packet is the single R1 lineage for one bounded AI-originated strategy.
The durable prompt and output trail is `prompt.md` and `output.md`. The current
OWNER mission expressly authorizes one new structural, low-frequency direct-
WTI edge outside the certified XAU/SP500/NDX/XNG book.

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete read of Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. It supplies reputable support only for a
monthly own-return continuation carrier across liquid futures and explicit
WTI membership. It does not test this within-month mean-location statistic,
a Darwinex continuous CFD, fixed-dollar risk, an ATR stop, or this portfolio.

The mean-location formula, session-count bounds, strict sign boundary,
continuous-CFD translation, execution controls, and lifecycle below are
pre-result QM choices. No source PF, alpha, drawdown, activity, cost, or
correlation result transfers.

## Pre-result hypothesis

Within a completed WTI broker month, the final daily close's position relative
to the arithmetic center of that same month's daily closes summarizes whether
late-month price accepted above or below the path's average level. Continue
that direction for one broker month. This uses direct price-path structure;
it is not a trained model, named signal indicator, seasonality table, or
external-data event rule.

WTI adds crude-oil supply, transport, refining, producer-hedging, geopolitical,
and end-demand exposure absent from the incumbent index/metal carriers and
different from natural-gas weather/storage exposure. That economic distinction
is not realized decorrelation; unchanged Q09 alone may establish correlation.

## Exact frozen mechanic

At the first executable tick after a genuine normalized broker-month change,
and no more than 180 elapsed minutes after the raw D1 bar open:

1. Read a bounded 45-bar D1 buffer from exact `XTIUSD.DWX`.
2. Exclude the current normalized month. Select all closes in the immediately
   completed normalized broker month and require 17 through 23 observations.
3. Require at least one valid older bar whose normalized month differs from
   the completed month, proving the history buffer crosses its boundary.
4. Require chronological timestamps, positive finite closes, and finite sum.
5. Compute `mean_close=sum(closes)/count`, take `final_close` from the newest
   completed-month bar, and compute
   `location=final_close/mean_close-1`.
6. Buy iff `location>1e-12`; sell iff `location<-1e-12`; equality or invalid
   history consumes the month flat.
7. Persist the normalized month before history, signal, news, spread, quote,
   stop, sizing, margin, or order gates. Never retry an outcome that month.
8. Hold at most one position to the next normalized month; repair after forty
   elapsed calendar days.
9. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

Both framework news axes, legacy news mode, and Friday close are OFF. Runtime
may not read a futures curve, inventory, volume, open interest, files, APIs,
forecasts, trained output, optimizer results, or portfolio state.

## Non-duplicate decision

The canonical receipt
`artifacts/qm5_wti_mdaily_meanloc_tr_preallocation_dedup_20260901.json`,
SHA-256
`382847E3030752E00354B681D27E722AAEFD0B7F35E6E7ACE6F7ED3171183BFB`,
returned `CLEAN` across 4,761 registry identities, 1,398 card files, and 45
Strategy Wiki nodes.

Manual review separates the closest WTI monthly families:

- `QM5_13100_wti-dmac16` compares one month-end endpoint with the arithmetic
  mean of six month-end endpoints and uses a 2.5% neutral band. This rule
  compares the newest daily close with all daily close levels inside one
  completed month, uses no six-month state, and has only a numerical epsilon.
- `QM5_41133_wti-mdaily-median-mom` sorts individual daily returns and trades
  their median sign. This rule never forms daily returns or sorts; it compares
  one endpoint with the arithmetic mean of price levels.
- `QM5_41105_wti-mclose-location-mom` locates the monthly close in the monthly
  high-low range. This rule reads closes only and uses neither highs nor lows.
- `QM5_41130_wti-mopen-residence-mom` counts closes above/below the month open.
  This rule uses neither the open nor a residence count.
- `QM5_20187` uses a raw boundary-to-endpoint one-month return. This rule's
  within-month path mean can give the opposite decision.

Fixed disagreement fixtures are load-bearing. With boundary 100 and completed
closes `[110 x 19, 101]`, raw one-month return is positive while this rule is
SELL because the final close is below the path mean. With boundary 100 and
closes `[90 x 19, 101]`, this rule is BUY while the median of the nineteen
zero daily returns plus one positive return is zero and the median-return rule
is flat.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL_D1_CLOSE_VERSUS_SAME_MONTH_ARITHMETIC_MEAN_CLOSE_STRICT_SIGN_CONTINUATION`.

## Reputable-source criteria

- **R1 — PASS.** Durable AI prompt/output/source trail plus a complete-read,
  peer-reviewed monthly WTI continuation record with explicit translation and
  claim boundaries.
- **R2 — PASS.** Symbol, month normalization, data window, 17-23 count,
  boundary proof, arithmetic, strict sign, consumed attempt, risk, stop,
  spread, and lifecycle are deterministic and locked before testing.
- **R3 — PASS_WITH_CONTINUOUS_CFD_BASIS_RISK.** Registered native
  `XTIUSD.DWX` D1 and MT5 state provide every runtime input; roll, basis,
  financing, gap, and broker-label risks remain.
- **R4 — PASS.** Timestamps, completed close levels, bounded arithmetic,
  comparisons, ATR risk, quotes, positions, deals, and persistent state only;
  no ML, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Kill and safety boundaries

Retire on a failed fixture, accepted malformed history, zero trades, fewer
than ten completed positions in any full post-warm-up year, or failed governed
economics. Do not repair the statistic, sign, count bounds, or hold after Q02.

Authorized after card G0 and clean registries: one branch build, reference
tests, strict Q01 compile, one D1 fixed-risk backtest set, and one paced
non-live Q02 enqueue if CPU admission permits. Excluded: manual tester launch,
optimization, live/demo/shadow/stress presets, `T_Live`, AutoTrading, deploy or
live manifests, portfolio-gate changes, portfolio admission, and correlation
waivers.
