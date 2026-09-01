# WTI Monthly Siegel-Tukey Scale Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE_AFTER_MANUAL_DISTINCT_REVIEW`
- Scope: one bounded structural WTI hypothesis, one Strategy Card, one branch
  build, strict Q01, and one paced non-live Q02 enqueue
- Proposed slug: `wti-msiegel-tukey-scale-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901_S01`
- Source ID: `AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901`

## Authority And Ordering

The current explicit OWNER mission authorizes one new reputable-source,
structural, low-frequency commodity/energy sleeve and expressly identifies a
direct WTI trend or seasonality edge as eligible. This durable record approves
the bounded source before Strategy Card extraction. It does not pre-approve
activity, economics, robustness, realized decorrelation, portfolio admission,
deployment, or live use.

## Approved Source And Mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901/source.md`,
with its origin prompt/output and retrieval record beside it. Moskowitz, Ooi,
and Pedersen (2012), Siegel and Tukey (1960), Crossref, and the complete NIST
Dataplot command page support only the WTI continuation carrier, original
method lineage, and canonical alternating-extremes rank construction. The
trading conjunction is pre-result QM synthesis:

```text
17 completed WTI broker-month closes -> 16 adjacent log returns
old = first 8; recent = last 8; require all 16 returns distinct
sort pooled returns ascending and retain old/recent labels
Siegel-Tukey score path by ascending rank:
  1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2
S = sum(scores occupied by recent labels)
enumerate every C(16,8)=12,870 recent-label assignment
qualify greater recent tail occupancy iff S<=68 and lower-tail count<=6,698
BUY iff sum(recent)>+1e-12; SELL iff sum(recent)<-1e-12; FLAT otherwise
```

Use exact `XTIUSD.DWX` D1, one consumed attempt per broker month, fixed
`RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop, a
1,500-point spread ceiling, next-month exit, and forty-day stale repair. The
inclusive half-support boundary is a disclosed activity gate, not a
conventional significance or efficacy claim.

## Gate Decision

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Durable AI prompt/output/source trail; complete-read peer-reviewed WTI carrier evidence; original JASA method metadata and abstract with body-access boundary; complete official NIST algorithm page. |
| R2 | `PASS` | Month clock, endpoint/return blocks, strict ties, exact score path, enumeration, boundary, direction, attempt, risk, stop, spread, and lifecycle are fixed. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native WTI D1 history and MT5 state only. |
| R4 | `PASS` | Deterministic bounded sorting, integer ranks, and enumeration; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate Decision

The fail-closed corrected-root receipt
`artifacts/qm5_wti_msiegel_tukey_scale_tr_preallocation_dedup_20260901.json`,
SHA-256
`F3DA6AE29D70BC1BF5E210D7F61D64966A0908898DA4B2DCB6C0EBC7ACD62A72`,
checked 4,770 registry rows, 1,407 cards, and 45 Wiki nodes. It returned one
fuzzy match at score `0.7142857142857143`,
`QM5_41261_wti-mab-scale-tr`, and therefore correctly required manual review.

The match is not the same mechanic. `QM5_41261` uses twelve completed monthly
returns in fixed six-by-six blocks and the mirrored Ansari-Bradley score path
`1,2,3,4,5,6,6,5,4,3,2,1`, qualifying at score/tail `21/522`. This source
uses sixteen returns in fixed eight-by-eight blocks and assigns consecutive
ranks by alternating between pooled extremes, producing the asymmetric
ordered path
`1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2`, with exact boundary
`68/6698` over 12,870 assignments.

Two fixed chronological rank fixtures prove both decision-disagreement
directions when the existing card is evaluated on its own latest-twelve
window:

- `[7,6,1,8,14,9,5,15,2,12,3,11,4,10,16,13]` gives new Siegel-Tukey
  score `61` (qualifies) and existing Ansari-Bradley score `22` (flat).
- `[15,14,7,3,5,10,1,11,12,6,13,8,4,2,16,9]` gives new Siegel-Tukey
  score `74` (flat) and existing Ansari-Bradley score `20` (qualifies).

Both fixtures have a positive recent return on each rule's own formation
window, so the disagreement comes from the load-bearing scale-state
construction rather than the direction gate.

Manual verdict:
`DISTINCT_WTI_MONTHLY_FIXED_EIGHT_BY_EIGHT_SIEGEL_TUKEY_ALTERNATING_EXTREMES_RANK_SUM_EXACT_12870_LOWER_TAIL6698_RECENT_RETURN_CONTINUATION`.

## Safety Boundary

The exact support is `6698/12870 = 0.5204351204`, implying roughly 6.25
market-free states per year before ties, neutral direction, data, and
execution gates. It is not a WTI trade-count or performance result. Q02 must
retire the candidate if any full post-warm-up year has fewer than five
completed positions. Q09 alone owns realized portfolio correlation.

Authorized after G0 and clean registries: branch-only build, deterministic
reference tests, strict Q01, one fixed-risk WTI backtest preset, and one paced
non-live Q02 enqueue if CPU admission permits. Excluded: manual tester run,
optimization, live/demo/shadow/stress presets, portfolio-gate changes,
deploy/live manifests, `T_Live`, AutoTrading, portfolio admission, and any
correlation waiver.
