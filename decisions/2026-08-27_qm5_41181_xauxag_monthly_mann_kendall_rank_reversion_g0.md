# QM5_41181 XAU/XAG Monthly Pairwise-Rank Reversion — G0 Decision

Date: 2026-08-27

Verdict: `APPROVED` at G0 for one non-live V5 build, strict Q01 validation,
and one paced logical-basket Q02 enqueue below the factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission,
bounded by the source approval at
`decisions/2026-08-27_xauxag_monthly_mann_kendall_rank_reversion_source_approval.md`.
It expressly permits a structural XAUUSD/XAGUSD market-neutral-style basket,
requires reputable-source criteria and fixed-risk backtests, and excludes
live and portfolio-gate work.

## Approved Identity

- EA: `QM5_41181`
- slug: `xauxag-mkendall-rv`
- strategy ID: `SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026_S01`
- source ID: `SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026`
- slot 0: `XAUUSD.DWX`, D1, intended magic `411810000`
- slot 1: `XAGUSD.DWX`, D1, intended magic `411810001`
- logical tester symbol: `QM5_41181_XAU_XAG_MKENDALL_RV_D1`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41181_xauxag-mkendall-rv_card.md`

The deterministic command `farmctl.py reserve-ea-ids` with lower bound 41180
returned `reserved:true`, `count:1`, and EA ID 41181 on 2026-08-27. Magic
allocation remains a separate governed build preflight after the directory
exists.

## Source And Extraction Gate

Source approval commits: `796c2934a`, with exact enumeration count correction
`e44cdaa93`; both precede card extraction.

The source of record is
`strategy-seeds/sources/SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026/source.md`,
SHA-256 `7C8612A5D47D24D25349521C7A8FEA00651735A3E6BD00B9A28D9AE75290C117`.
It joins peer-reviewed, state-dependent gold/silver relationship evidence;
official CME ratio-carrier research; and a complete governed all-pair rank
arithmetic packet. The exact sample, threshold, contrarian direction,
continuous CFDs, risk, stops, atomicity, and lifecycle are disclosed QM
mechanizations. No source efficacy, significance, neutrality, or
decorrelation claim transfers.

Both card lints must pass before build.

## G0 R1-R4 Decision

- R1 `PASS_WITH_STATISTIC_AND_CARRIER_TRANSLATION_RISK`: named-author,
  peer-reviewed gold/silver evidence; official CME carrier research; and
  complete governed rank arithmetic. Exact conjunction explicitly untested.
- R2 `PASS`: thirteen synchronized month ends, all 78 pair signs, count/
  range/parity invariants, threshold, sides, consumed attempt, fixed risk,
  hard stops, atomicity, rollover, and stale repair are deterministic.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5 state supply every input.
- R4 `PASS`: logarithms, comparisons, integers, calendar, ATR risk, and
  execution state only; no trained signal or prohibited runtime feed.

## Locked Baseline

On the first synchronized executable D1 tick of a new broker month, consume
the month before any fallible gate. Reconstruct the latest exactly matched
XAU/XAG close pair in each of the immediately prior thirteen consecutive
completed months. Require freshness, chronology, positive finite prices,
and pairwise-distinct gold-minus-silver log ratios.

For every `0<=i<j<=12`, add `+1` when the newer ratio exceeds the older and
`-1` otherwise. Require 78 comparisons, even `S`, and `-78<=S<=78`. If
`S>=14`, SELL XAU/BUY XAG; if `S<=-14`, BUY XAU/SELL XAG; otherwise consume
flat. This is an ordinal dominance gate, not a runtime significance test.

Open one equal-target-notional package under aggregate `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen per-leg `3.5*ATR(20,D1)` hard
stops, no targets, 1,500/500-point spread caps, and at most 20% notional
mismatch. Submit XAU then XAG; flatten every owned leg on invalid package.
Exit at the next month boundary or after forty days. News and Friday close
are OFF; no consumed-month retry is allowed.

Exact enumeration of 13! no-tie rank paths gives rate
`0.4353804483839206`, about 5.22 opportunities/year under random ordering.
This pre-result density fact fixes the inclusive score 14 boundary to respect
the unchanged five-per-year Q02 floor; it is not market evidence.

## Non-Duplicate Decision

The canonical checker found no exact identity and one expected Spearman fuzzy
neighbor after scanning 4,680 registry identities, 1,331 cards, and 45 Wiki
nodes. Receipt:
`artifacts/qm5_xauxag_mkendall_rv_preallocation_dedup_20260827.json`.

`QM5_41174` weights squared time-rank displacement; this card gives each of
78 older/newer pairs one vote. The locked fixtures are functionally
separating: `[9,8,7,2,6,4,1,10,3,12,5,13,11]` is Spearman-only (`T=118`,
`S=12`), while `[1,6,13,3,7,4,12,8,10,5,9,2,11]` is this-rule-only
(`S=14`, `T=80`). The WTI/XNG pair-score systems follow one outright energy
series; this card fades a paired-metal ratio with atomic basket semantics.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ALL78_PAIR_RANK_S14_CONTRARIAN_BASKET`.

## Kill And Authorization Boundary

Q02 retires at zero trades, below five packages in any full post-warm-up
year, with nonpositive economics, or on timestamp, synchronization, ratio,
score, threshold, side, attempt, risk, atomicity, lifecycle, or determinism
defect. No result may be rescued by changing the sample, threshold,
direction, carrier, risk, stop, hold, spread, sequence, or adding a gate.

Equal notionals do not prove neutrality or decorrelation; Q09 owns overlap.
Q02 may be enqueued exactly once only after current strict compile/Q01 and
review PASS. If the CPU ceiling binds, stop without tester dispatch or
terminal control and preserve the committed build.

This decision excludes manual backtests; live/demo/shadow/stress/optimization
sets; AutoTrading; `T_Live`; deploy or live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; terminal control; and a
second Q02 row.
