# WTI Monthly Three-Block Rank Trend - Source Approval

Date: 2026-09-01

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue. Enqueue does not authorize manual tester execution or
work above the active whole-host CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It asks for exactly one new structural,
low-frequency commodity or energy edge outside the certified
XAU/SP500/NDX/XNG book, identifies direct WTI trend or seasonality as eligible,
requires reputable-source criteria and `RISK_FIXED` backtests, and excludes
the portfolio gate, live manifests, `T_Live`, and AutoTrading.

## Candidate Identity

- proposed slug: `wti-m3block-rank-tr`
- proposed strategy ID:
  `AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901_S01`
- proposed source ID: `AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901`
- proposed symbol / host: exact `XTIUSD.DWX`, D1, slot 0
- decision clock: first executable tick after a genuine broker-month
  transition
- signal: ordinal dominance of the last fifteen completed D1 closes of the
  immediately completed WTI month, split into three chronological five-close
  blocks and scored through all 75 earlier-block/later-block comparisons

The deterministic registry owns the EA ID. This source decision neither
predicts nor reserves an identity.

## Approved Source Basis

The bounded parent record was read completely before this decision:

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
preserves a complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
*Time Series Momentum*, *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. It documents own-return continuation at
monthly horizons, explicitly reports a one-month formation/one-month holding
commodity portfolio, and identifies NYMEX WTI in the commodity universe.

The paper does not test this WTI-only within-month rank path, daily close
blocks, a continuous CFD, fixed-dollar risk, an ATR stop, or the QM book. The
three-block partition, all-pairs ordinal score, center split, tie rule,
continuous-CFD translation, execution gates, and lifecycle are transparent
pre-result QM choices. No source return, WTI-only alpha, p-value, probability,
trade count, cost, drawdown, CFD equivalence, decorrelation, or portfolio
result transfers.

An exploratory public-method search was not admitted as source evidence: the
QM trading-source skill permits generic public pages only through its
policy-gated router, and the OWNER supplied no individual URL. This approval
therefore relies on the complete governed peer-reviewed trading record above
and on fully disclosed deterministic arithmetic, not on snippets or an
unread method paper. The score is a classifier, not a significance test.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible entry gate. One
   month may produce at most one consumed attempt.
2. Exclude every current-month price. Reconstruct the immediately completed
   broker month and require 17 through 23 chronological completed D1 sessions.
3. Select its final fifteen closes in chronological order, `C[0]..C[14]`.
   Require positive finite values and reject the month if any two closes are
   equal within `0.5 * _Point`.
4. Split the closes into fixed blocks `G0=C[0..4]`, `G1=C[5..9]`, and
   `G2=C[10..14]`. For every earlier block `a`, later block `b`, close `x` in
   `Ga`, and close `y` in `Gb`, count one win when `y>x`. Require exactly 75
   comparisons and `0<=W<=75`.
5. BUY when `2*W>75`; SELL when `2*W<75`. With the strict tie rejection,
   equality is unreachable because `2*W` is even. Score magnitude never
   changes risk.
6. Open at most one position under `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`, sized against one frozen `3.5*ATR(20,D1)` broker hard
   stop. Attach no target and reject a genuinely positive entry spread above
   1,500 points.
7. Close on the first tick in a later broker month or after forty elapsed
   calendar days. Immediately repair duplicate, wrong-symbol, wrong-magic,
   wrong-side, invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 OHLC/timestamps, broker time, quotes, contract metadata,
positions, deals, terminal global variables, and V5 framework services.

## Activity Boundary

There is one consumed decision per broker month. Every valid strict-order
state maps to exactly one side because `2*W` cannot equal 75. The market-free
upper bound is therefore twelve qualified states per full year before
history, tie, quote, spread, ATR, sizing, margin, or execution gates. This is
an activity design bound, not a probability or WTI performance claim.

Q02 must retire zero-trade output or fewer than five completed positions in
any full post-warm-up calendar year.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,773 registry identities,
1,409 card files, and all 45 Strategy Wiki nodes. It found no exact identity.
Its sole fuzzy hit was `QM5_41273_wti-msigned-rank-tr`, at score 0.75 from
shared author/WTI/monthly naming rather than shared arithmetic. Evidence:
`artifacts/qm5_wti_m3block_rank_tr_preallocation_dedup_20260901.json`,
SHA-256
`2CC07EFAA3F1A5618442E1DA8B17E42A24B14B3E3561C12B985AC740E26D828D`.

Manual semantic review fixes the load-bearing boundaries:

- `QM5_41115_wti-mthirdvote-mom` takes three cumulative return signs anchored
  to a parent-month close and votes two of three. This candidate uses no
  parent anchor or cumulative block sign; it counts all 75 cross-block close
  comparisons. With parent close 5 and closes
  `[1,2,3,4,10,11,12,13,14,9,15,16,17,18,8]`, this candidate has `W=68`
  and buys while the cumulative-block vote has signs `+,-,-` and sells.
- `QM5_41111_wti-mdaybreadth-mom` counts adjacent daily return signs and
  requires endpoint agreement. This candidate counts cross-block close-level
  order and has no endpoint gate.
- `QM5_20264_wti-rank-trend` scores all 78 ordered pairs among thirteen
  monthly endpoints. This candidate scores 75 cross-block pairs among fifteen
  daily closes inside one completed month.
- `QM5_41273_wti-msigned-rank-tr` ranks the absolute sizes of twelve
  consecutive monthly returns and applies an absolute-18 score gate. This
  candidate ranks no return magnitudes and consumes a disjoint daily path.
- `QM5_20187_wti-tsmom1m` follows the completed-month endpoint return. Closes
  `[100,101,102,103,104,105,106,107,108,109,110,111,112,113,99]`
  produce `W=65` and a BUY here even though the final close is below the first
  and the endpoint rule is negative.
- certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback and shares neither carrier, information set, direction,
  nor lifecycle.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL15_CLOSE_THREE_BLOCK_75_PAIR_ORDINAL_DOMINANCE_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK`: a
  complete-read peer-reviewed WTI trend paper with DOI and durable PDF hash
  supports only the carrier, monthly cadence, and broad continuation premise;
  the exact daily-rank conjunction is explicitly untested QM synthesis.
- R2 `PASS`: month clock, session range, final-fifteen selection, fixed blocks,
  tie rule, all 75 comparisons, strict center split, side, attempt, risk,
  stop, spread, and lifecycle are deterministic and locked before Q02.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5-native state supplies every runtime input;
  futures-to-CFD roll, basis, financing, gaps, and broker-month labels remain
  falsification risks.
- R4 `PASS`: deterministic timestamps, completed prices, comparisons, integer
  counts, ATR risk controls, and execution state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Kill And Safety Boundary

Retire or fail on a clock, month membership, chronology, session count,
final-fifteen selection, tie, block membership, comparison count, win count,
side, attempt, fixed-risk, stop, lifecycle, or determinism defect; fewer than
five completed positions in any full post-warm-up year; zero trades;
nonpositive governed economics; or any downstream gate failure. No failed
result may be rescued by changing the sample, blocks, score, threshold,
carrier, direction, risk, hold, or by adding another filter.

Direct WTI supplies crude-oil exposure absent from the stated
XAU/SP500/NDX/XNG book, but it does not prove factor or portfolio
decorrelation. Unchanged Q09 alone owns overlap. This approval excludes manual
backtests; optimization; live, demo, shadow, and stress presets; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; and terminal control.
