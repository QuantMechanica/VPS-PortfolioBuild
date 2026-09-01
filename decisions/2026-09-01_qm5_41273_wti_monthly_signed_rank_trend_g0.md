# QM5_41273 WTI Monthly Signed-Rank Trend - G0 Decision

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Strategy: `AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901_S01`
- EA identity: `QM5_41273_wti-msigned-rank-tr`
- Decision: `APPROVED`
- Scope: branch build, deterministic reference tests, strict Q01, and one
  paced non-live Q02 enqueue only

## Authority

The current OWNER mission directs Codex to mechanize and build exactly one new
structural low-frequency commodity/energy edge outside the certified
XAU/SP500/NDX/XNG book, and explicitly permits a direct WTI trend edge. The
source was durably approved and committed in `3203deb0df` before card
extraction. EA identity 41273 was then reserved in `fb186317a5`.

This decision approves the exact card at
`strategy-seeds/cards/approved/QM5_41273_wti-msigned-rank-tr_card.md`. It does
not approve a result, threshold repair, optimization, portfolio admission,
deployment, live use, or any correlation waiver.

## Approved Hypothesis

On the first executable tick of a normalized broker month, rank the absolute
magnitudes of the latest twelve completed WTI monthly log returns. Continue
the direction of the centered signed-rank score for one month only when its
absolute value reaches the fixed inclusive activity boundary 18.

The direct `XTIUSD.DWX` carrier adds physical crude-oil supply, storage,
transport, refining, hedging, geopolitical, and end-demand exposure absent
from the stated certified book. This is a diversification hypothesis, not a
decorrelation result. Q09 alone owns measured overlap.

## Reputable-Source Gates

| gate | verdict | finding |
|---|---|---|
| R1 | `PASS_WITH_COMPOSITE_SOURCE_AND_CONTINUOUS_CFD_TRANSLATION_RISK` | The governed packet contains a complete-read peer-reviewed WTI trend record and complete pinned R Core implementation/manual evidence for the signed-rank arithmetic. No source performance is imported. |
| R2 | `PASS` | The card fixes the clock, thirteen closes, twelve returns, zero/tie rule, strict absolute ranks, centered score, inclusive `|S|>=18`, direction, attempt state, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Exact registered `XTIUSD.DWX` D1 history and MT5-native state provide every runtime input; futures-to-CFD roll, basis, financing, and gap risks remain. |
| R4 | `PASS` | Native timestamp, close, logarithm, sorting, integer-rank arithmetic, ATR, quote, position, deal, and persistent-state operations only; no trained output or prohibited runtime feed. |

## Duplicate Review

The canonical fail-closed receipt
`artifacts/qm5_wti_msigned_rank_tr_preallocation_dedup_20260901.json`, SHA-256
`AE49BB417E6B8D35EEFBF8EA86FB6B3E1C3786ADACAF62FA6AA2F51EADBCE337`,
checked 4,772 registry identities, 1,408 cards, and 45 Wiki nodes. It found no
exact or above-threshold fuzzy identity.

Manual review passes the candidate as distinct:

- `QM5_41191_wti-samecal-srank` uses five-to-ten disjoint prior-year returns
  for the upcoming calendar month and trades every nonzero score. QM5_41273
  uses exactly twelve contiguous latest returns and requires `|S|>=18`.
- `QM5_12603_wti-tsmom12m` keeps metric cumulative-return magnitude. Eleven
  positive returns `.01..11` plus `-1.00` make QM5_41273 buy at `S=54` while
  the cumulative return is negative; negation proves the reverse direction.
- A zero-threshold signed-rank rule buys the fixed assignment whose positive
  absolute ranks are `{7,10,11,12}` at `S=2`; QM5_41273 stays flat.
- Seven small positive ranks `1..7` against five larger negative ranks
  `8..12` give a positive sign majority but `S=-22`, so QM5_41273 sells.
- `QM5_41176_wti-mwilcoxon-shift-tr` is a two-sample six-old/six-new
  Mann-Whitney location-shift statistic and never computes a one-sample
  signed absolute-rank score.

Verdict:
`DISTINCT_WTI_MONTHLY_TWELVE_CONTIGUOUS_STRICT_SIGNED_ABSOLUTE_RANK_SCORE_ABS18_CONTINUATION`.

## Exact Locked Contract

```text
C[0..12] = chronological completed WTI broker-month closes
r[i] = ln(C[i+1]/C[i]), i=0..11

require all closes positive and finite
require all returns finite and abs(r[i]) > 1e-12
require pairwise-distinct abs(r[i]) beyond 1e-12

rank abs(r) strictly from 1 through 12
V_plus = sum(rank(abs(r[i])) for positive r[i])
T = 78
S = 2*V_plus - T
require rank_sum == 78 and -78 <= S <= 78

BUY  iff S >= 18
SELL iff S <= -18
FLAT otherwise
```

The boundary has exact sign-assignment support `2,124/4,096`, not a p-value
or significance interpretation. One broker-month attempt is consumed before
every fallible entry gate. Use one frozen `3.5*ATR(20,D1)` stop, no target,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
Friday close OFF, a 1,500-point spread ceiling, next-month exit, and a forty-
day stale repair.

## Frequency Prior And Falsification

Exact sign enumeration gives `2124/4096 = 0.5185546875`, or 6.22265625
market-free qualified monthly states per full year before ties, history,
spread, sizing, and execution gates. This is not a WTI result. Q02 must retire
zero-trade output or fewer than five completed positions in any full post-
warm-up year. Nonpositive governed economics or any downstream gate failure
also retires the candidate. No post-result change to the sample, tie rule,
score boundary, side, stop, risk, or lifecycle is authorized under this
identity.

## Build Boundary

Approved: create the exact EA directory, allocate slot-0 WTI magic after the
directory exists, regenerate and verify the resolver, implement the card, add
one canonical D1 fixed-risk backtest setfile, run deterministic reference
tests, strict Q01 compile, and enqueue exactly one Q02 item if a fresh five-
sample whole-host CPU window remains below the 97% hard ceiling.

Forbidden: manual backtest execution, optimization, stress/demo/shadow/live
setfiles, portfolio-gate mutation, portfolio admission, deploy/live manifest,
`T_Live`, AutoTrading, or any live account action.

## Decision

`G0 APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`.
