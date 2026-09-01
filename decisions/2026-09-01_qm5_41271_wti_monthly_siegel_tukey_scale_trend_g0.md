# QM5_41271 WTI Monthly Siegel-Tukey Scale Trend - G0 Decision

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Strategy: `AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901_S01`
- EA identity: `QM5_41271_wti-msiegel-tukey-scale-tr`
- Decision: `APPROVED`
- Scope: branch build, deterministic reference tests, strict Q01, and one
  paced non-live Q02 enqueue only

## Authority

The current OWNER mission directs Codex to mechanize and build exactly one
new structural low-frequency commodity/energy edge outside the certified
XAU/SP500/NDX/XNG book, and explicitly permits a direct WTI trend edge. The
source was durably approved and committed in `2e39593ebe` before card
extraction. EA identity 41271 was then reserved in `b2bfd003ef`.

This decision approves the exact card at
`strategy-seeds/cards/approved/QM5_41271_wti-msiegel-tukey-scale-tr_card.md`.
It does not approve a result, threshold repair, optimization, portfolio
admission, deployment, live use, or any correlation waiver.

## Approved Hypothesis

On the first executable tick of a normalized broker month, compare the latest
eight completed WTI monthly log returns with the preceding eight using the
canonical Siegel-Tukey alternating-extremes ranks. Continue the recent eight-
month return direction for one month only when the recent block occupies the
more-dispersed inclusive half of the exact rank-sum support.

The direct `XTIUSD.DWX` carrier adds physical crude-oil supply, storage,
transport, refining, hedging, geopolitical, and end-demand exposure absent
from the stated certified book. This is a diversification hypothesis, not a
decorrelation result. Q09 alone owns measured overlap.

## Reputable-Source Gates

| gate | verdict | finding |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | The governed packet contains a complete-read peer-reviewed WTI carrier record, original peer-reviewed JASA method metadata with explicit body boundary, and a completely read official NIST algorithm page with a stable normalized-text hash. No source performance is imported. |
| R2 | `PASS` | The card fixes clock, 17 closes, 16 returns, 8/8 membership, strict no-tie sorting, exact score path, 12,870 assignments, `68/6698` boundary, direction, attempt state, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Exact registered `XTIUSD.DWX` D1 history and native MT5 state provide every runtime input; futures-to-CFD roll, basis, financing, and gap risks remain falsification risks. |
| R4 | `PASS` | Native timestamp, close, logarithm, sorting, integer-rank enumeration, ATR, quote, position, deal, and persistent-state operations only; no trained output or prohibited runtime feed. |

## Duplicate Review

The canonical fail-closed receipt
`artifacts/qm5_wti_msiegel_tukey_scale_tr_preallocation_dedup_20260901.json`,
SHA-256
`F3DA6AE29D70BC1BF5E210D7F61D64966A0908898DA4B2DCB6C0EBC7ACD62A72`,
checked 4,770 registry identities, 1,407 cards, and 45 Wiki nodes. It found no
exact identity and correctly raised `QM5_41261_wti-mab-scale-tr` as one fuzzy
neighbor for manual review.

Manual review passes the candidate as distinct. `QM5_41261` uses twelve
returns, six-by-six blocks, mirrored Ansari-Bradley scores, 924 assignments,
and a `21/522` boundary. QM5_41271 uses sixteen returns, eight-by-eight blocks,
the ordered Siegel-Tukey alternating-extremes permutation, 12,870 assignments,
and `68/6698`. Fixed fixtures in the source prove both decision-disagreement
directions with positive recent returns, so the difference is in the
qualification mechanic rather than the side gate.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_EIGHT_BY_EIGHT_SIEGEL_TUKEY_ALTERNATING_EXTREMES_RANK_SUM_EXACT_12870_LOWER_TAIL6698_RECENT_RETURN_CONTINUATION`.

## Exact Locked Contract

```text
C[0..16] = chronological completed WTI broker-month closes
r[i] = ln(C[i+1]/C[i]), i=0..15
old = r[0..7]; recent = r[8..15]
require all returns finite and pairwise distinct

sort pooled returns ascending and preserve membership
score path = 1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2
S = recent-label score sum
enumerate all C(16,8)=12,870 label assignments
tail = count(permutation score <= S)

qualify iff S<=68 and tail<=6698
BUY iff sum(recent)>+1e-12
SELL iff sum(recent)<-1e-12
FLAT otherwise
```

The boundary is the inclusive half-support activity gate, not a p-value or
significance assertion. One broker-month attempt is consumed before every
fallible entry gate. Use one frozen `3.5*ATR(20,D1)` stop, no target,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes
OFF, Friday close OFF, a 1,500-point spread ceiling, next-month exit, and a
forty-day stale repair.

## Frequency Prior And Falsification

Exact enumeration gives `6698/12870 = 0.5204351204351204`, or roughly 6.25
market-free qualified monthly states per full year before ties, neutral
return, history, spread, sizing, and execution gates. This is not a WTI
result. Q02 must retire zero-trade output or fewer than five completed
positions in any full post-warm-up year. Nonpositive governed economics or
any downstream gate failure also retires the candidate. No post-result change
to sample, score path, boundary, direction, stop, risk, or lifecycle is
authorized under this identity.

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
