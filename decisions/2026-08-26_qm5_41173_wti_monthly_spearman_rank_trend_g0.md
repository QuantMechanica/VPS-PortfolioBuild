# QM5_41173 WTI Monthly Spearman Price-Rank Trend — G0 Decision

Date: 2026-08-26

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-26_wti_monthly_spearman_rank_trend_source_approval.md`.

Scope: approve one card, one registered V5 identity, one non-live build,
strict Q01 validation, independent review, and at most one paced Q02 enqueue.
This is not a performance, certification, correlation, portfolio-admission,
deploy, or live decision.

## Approved Identity

- EA ID: `QM5_41173`
- slug: `wti-mspearman-tr`
- strategy ID: `MOP-SPEARMAN-WTI-MRANK-TREND-2026_S01`
- source ID: `MOP-SPEARMAN-WTI-MRANK-TREND-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41173_wti-mspearman-tr_card.md`
- host and traded symbol: `XTIUSD.DWX`, slot 0
- timeframe: D1
- risk for every backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The governed `farmctl reserve-ea-ids` allocator returned `reserved:true`,
`count:1`, and EA ID 41173 only after the source gate and canonical dedup scan
passed. Registry slug and strategy ID match the card.

## Source And Extraction Gate

Source approval commit: `86bde74ea`.

Bounded records:

- complete governed Moskowitz-Ooi-Pedersen WTI source packet;
- Spearman (1904), *The American Journal of Psychology* 15(1), DOI
  `10.2307/1412159`, with the article body explicitly not claimed as
  completely read; and
- complete relevant R Core `stats::cor` source and manual at public mirror
  commit `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`, defining Spearman rho as
  ordinary correlation after rank-transforming both inputs.

Evidence hashes:

- governed composite source packet:
  `38B53FD42A8E9CBA533957D5A376D8F8D4E5CA0F8EBB249D8464F761C8D2AB98`;
- retrieval receipt:
  `14A50F63A6908AF17C9BD4EEB8C0057398BAB37A1F5CFCFCE00425083EF65590`;
- canonical dedup receipt:
  `B7296C4BDEEC4624F25909AD9AD48A1F0020D57955676B84819855373EAD91F8`;
- approved card:
  `40A433746360469EA1292E49DD30B817857C89F6F24FD9A15D69093B455886AE`.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` returned
`status: ok`; the strategy-card lint found no prohibited-token hit or missing
required section.

## Locked Strategy Contract

At the first executable D1 tick of each genuine new broker month:

1. Persist the normalized broker `yyyymm` before every fallible gate.
2. Select the latest D1 close in each of the immediately preceding thirteen
   consecutive completed broker months. Exclude the current month. Require
   positive, finite, pairwise-distinct closes, strict chronology, and newest
   endpoint staleness no greater than ten calendar days.
3. Assign strict ranks `R[i]` from 1 through 13 and compute
   `D=sum((R[i]-(i+1))^2)` and `T=364-D`. Require the exact rank permutation,
   `0<=D<=728`, `-364<=T<=364`, and even D/T.
4. Buy when `T>=104`, sell when `T<=-104`, and consume the month flat
   otherwise. This is exactly `abs(rho)>=2/7`; no p-value, average-rank tie
   handling, or fallback is permitted.
5. Attach one frozen `3.5*ATR(20,D1)` hard stop, no target, and reject spread
   above 1,500 points. Own at most one slot-zero WTI position.
6. Exit on the first later broker month or after forty calendar days. Repair
   malformed, duplicate, wrong-side, wrong-symbol, wrong-magic,
   invalid-volume, or stopless owned exposure immediately.

News temporal mode is OFF, news compliance is NONE, legacy news is OFF, and
Friday close is OFF. Signal-strength sizing, endpoint fallbacks, alternate
thresholds, fitting, scale-in, grid, martingale, and external runtime data are
forbidden.

## Gate Findings

| Gate | Verdict | Basis |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete-read peer-reviewed WTI carrier evidence, named Spearman method record, and complete pinned R Core implementation; exact conjunction disclosed as untested. |
| R2 | PASS | Clock, month reconstruction, strict ranks, D/T invariants, threshold, side, attempt, risk, stop, and lifecycle are mechanical. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered `XTIUSD.DWX` D1 archive and native MT5 state provide every runtime input. |
| R4 | PASS | Deterministic ranks, integer arithmetic, timestamps, ATR risk controls, and state only; no trained signal or prohibited runtime dependency. |

The card linters and R1-R4 consistency remain build preconditions. G0 does not
transfer any expected performance, significance, or density claim.

## Non-Duplicate Gate

The canonical fail-closed checker returned `CLEAN` across 4,672 registry rows,
1,323 cards, and 45 Strategy Wiki nodes.

Manual review establishes exact functional separation:

- Mann-Kendall counts pair signs; Spearman weights squared displacement from
  each exact calendar rank;
- Cox-Stuart, Foster-Stuart, Bartels, turning-point, and Pettitt neighbors use
  fixed pairs, records, adjacent movement, local extrema, and a central split,
  respectively;
- the H4 FX Spearman EA uses a zero-crossing event rather than completed-month
  WTI time-price rank continuation; and
- four locked rank fixtures in the source/card produce qualify/flat
  disagreements in both directions against Mann-Kendall and Pettitt.

The incumbent certified XNG sleeve is a two-day long-only oscillator pullback
on a different carrier and clock.

Verdict: `CLEAN_WTI_MONTHLY_SPEARMAN_TIME_PRICE_RANK_T104_CONTINUATION`.

## G0 Authorization And Kill Boundary

The card is approved for build because the source is durable, the rule is
mechanical, the identity is clean, the data route exists, and the proposed EA
uses permitted structural arithmetic. It is not approved because an edge or
decorrelation has been observed.

Exact enumeration of every 13! no-tie rank path yields a random-order
qualification rate of `0.3436382463986631`, approximately 4.12 qualified
months/year. This pre-result density fact supports a four-to-eight completed
position prior; it is not a statistical-significance or WTI-performance claim.
Retire below four completed positions in any full post-warm-up year, at zero
trades, with nonpositive governed economics, any state/rank/score/side/risk
defect, nondeterminism, or any downstream gate failure. A failed result cannot
be rescued by changing the sample, threshold, direction, risk, stop, hold,
carrier, or by adding a filter.

Before compile or Q02, the paced fleet must pass its current resource-capacity
check. If the binding backtest CPU ceiling is encountered, stop without tester
dispatch or terminal control and preserve the committed build state. Q02 may
be enqueued exactly once only after a current strict compile/Q01 PASS and
independent review PASS.

Excluded: manual backtests, live/demo/shadow/stress/optimization setfiles,
`T_Live`, AutoTrading, deploy or live manifests, portfolio-gate edits,
portfolio admission, correlation waiver, and any claim of certification.
