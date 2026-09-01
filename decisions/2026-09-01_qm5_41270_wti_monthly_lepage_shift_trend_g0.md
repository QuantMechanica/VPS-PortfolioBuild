# QM5_41270 WTI Monthly Lepage Shift Trend - G0 Decision

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Strategy: `AI-CODEX-WTI-MLEPAGE-SHIFT-20260901_S01`
- EA identity: `QM5_41270_wti-mlepage-shift-tr`
- Decision: `APPROVED`
- Scope: branch build, deterministic reference tests, strict Q01, and one
  paced non-live Q02 enqueue only

## Authority

The current OWNER mission directs Codex to mechanize and build exactly one
new structural low-frequency commodity/energy edge outside the certified
XAU/SP500/NDX/XNG book, and explicitly permits a direct WTI trend edge. The
source was durably approved and committed in `b6d352b26b` before card
extraction. EA identity 41270 was then reserved in `fa54524615`.

This decision approves the exact card at
`strategy-seeds/cards/approved/QM5_41270_wti-mlepage-shift-tr_card.md`. It
does not approve a result, threshold repair, optimization, portfolio
admission, deployment, live use, or any correlation waiver.

## Approved Hypothesis

On the first executable tick of a normalized broker month, compare the latest
twenty-five completed WTI daily log returns with the preceding twenty-five by
the classical Lepage joint location-scale rank statistic. Continue the recent
twenty-five-return direction for one month only when the joint statistic
reaches the locked chi-square-two median activity gate.

The direct `XTIUSD.DWX` carrier adds physical crude-oil supply, storage,
transport, refining, hedging, geopolitical, and end-demand exposure absent
from the stated certified book. This is a diversification hypothesis, not a
decorrelation result. Q09 alone owns measured overlap.

## Reputable-Source Gates

| gate | verdict | finding |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | The governed packet contains a complete-read peer-reviewed WTI carrier record, the original Lepage peer-reviewed metadata with explicit body boundary, a complete 20-page author preprint, and complete official CRAN 1.0 source with hashes. No source performance is imported. |
| R2 | `PASS` | The card fixes clock, 51 closes, 50 returns, 25/25 membership, strict no-tie ranking, both component moments, joint statistic, median gate, direction, attempt state, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Exact registered `XTIUSD.DWX` D1 history and native MT5 state provide every runtime input; futures-to-CFD roll, basis, financing, and gap risks remain falsification risks. |
| R4 | `PASS` | Native timestamp, close, logarithm, sorting, rank, arithmetic, ATR, quote, position, deal, and persistent-state operations only; no trained output or prohibited runtime feed. |

## Duplicate Review

The canonical fail-closed receipt
`artifacts/qm5_wti_mlepage_shift_tr_preallocation_dedup_20260901.json`,
SHA-256
`FFF74031E1A7636A78816E6EB0AB67B6CA2731467577CA4D656D96A4B52C2A97`,
checked 4,769 registry identities, 1,406 cards, and 45 Wiki nodes. It found no
exact identity and correctly raised `QM5_41268_wti-mepps-shift-tr` as one
fuzzy neighbor for manual review.

Manual review passes the candidate as distinct. `QM5_41268` measures
empirical-characteristic-function mean differences through a pooled 4x4
feature covariance and guarded matrix inverse. QM5_41270 discards value
spacing after pooled ranking and combines a monotone Wilcoxon location score
with a mirrored Ansari-Bradley tail/center scale score. `QM5_41176` and
`QM5_41261` use separate six-by-six monthly location-only and scale-only
rules, not this fifty-daily-return joint quadratic state. The fixed joint
fixture in the source/card qualifies only through the sum of two individually
sub-threshold component squares.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_25_BY_25_DAILY_RETURN_LEPAGE_JOINT_WILCOXON_ANSARI_BRADLEY_LOCATION_SCALE_CHI_SQUARE_TWO_MEDIAN_GATE_RECENT_RETURN_CONTINUATION`.

## Exact Locked Contract

```text
C[0..50] = chronological completed WTI D1 closes
r[i] = ln(C[i+1]/C[i]), i=0..49
old = r[0..24]; recent = r[25..49]
require all returns finite and pairwise distinct

rank pooled returns ascending 1..50
W = recent ordinary-rank sum
A = recent min(rank,51-rank) sum
L = (W-637.5)^2/2656.25 + (A-325)^2/(32500/49)

qualify iff finite L >= 1.3862943611198906
BUY iff sum(recent)>+1e-12
SELL iff sum(recent)<-1e-12
FLAT otherwise
```

The threshold is exactly `2*ln(2)`, the median of the source asymptotic
chi-square-two reference. It is an activity gate, not a p-value or
significance assertion. One broker-month attempt is consumed before every
fallible entry gate. Use one frozen `3.5*ATR(20,D1)` stop, no target,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes
OFF, Friday close OFF, a 1,500-point spread ceiling, next-month exit, and a
forty-day stale repair.

## Frequency Prior And Falsification

The asymptotic median gate gives a rough half-state prior, or about six
qualified monthly states per full year before overlap, dependence, ties,
neutral return, history, spread, sizing, and execution gates. This is not a
WTI result. Q02 must retire zero-trade output or fewer than five completed
positions in any full post-warm-up year. Nonpositive governed economics or
any downstream gate failure also retires the candidate. No post-result change
to sample, rank scores, component moments, threshold, direction, stop, risk,
or lifecycle is authorized under this identity.

## Build Boundary

Approved: create the exact EA directory, allocate slot-0 WTI magic after the
directory exists, regenerate/verify the resolver, implement the card, add one
canonical D1 fixed-risk backtest setfile, run deterministic reference tests,
strict Q01 compile, and enqueue exactly one Q02 item if a fresh five-sample
whole-host CPU window remains below the 97% hard ceiling.

Forbidden: manual backtest execution, optimization, stress/demo/shadow/live
setfiles, portfolio-gate mutation, portfolio admission, deploy/live manifest,
`T_Live`, AutoTrading, or any live account action.

## Decision

`G0 APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`.
