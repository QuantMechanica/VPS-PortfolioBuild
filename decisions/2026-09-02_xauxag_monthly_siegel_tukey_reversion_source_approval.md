# XAU/XAG Monthly Siegel-Tukey Reversion - Source Approval

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural XAU/XAG relative-value hypothesis, one
  Strategy Card, one branch-only build, strict Q01, and one paced non-live
  logical-basket Q02 enqueue
- Proposed slug: `xauxag-msiegel-tukey-rv`
- Proposed strategy ID: `AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902`

## Authority and ordering

The current explicit OWNER mission authorizes one new reputable-source,
structural, low-frequency commodity/energy sleeve, expressly identifies a
market-neutral-style gold/silver basket as eligible, requires real committed
non-duplicate work, and requests a fixed-risk Q02 enqueue. This durable record
approves the bounded source before card extraction. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

## Approved evidence and complete read

The single R1 lineage is the AI-originated packet
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902/source.md`.
`processes/qb_reputable_source_criteria.md` permits AI-originated strategies
when their prompt/output trail, source ID, and claim boundaries are durable.

Supporting evidence is bounded to:

1. Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, through the complete governed packet and
   its full 32-page author-preprint read;
2. CME Group's official gold/silver ratio spread packet;
3. Siegel and Tukey (1960), *Journal of the American Statistical
   Association* 55(291), 429-445, DOI
   `10.1080/01621459.1960.10482073`, limited to publisher metadata and
   abstract; and
4. the completely read official NIST Dataplot `SIEGEL TUKEY TEST` page and
   its stable visible-text hash.

The relationship and opposed-leg carrier transfer from the first two records;
the alternating-extremes rank arithmetic transfers from the method record.
The time-series blocks, half-support boundary, trading side, CFD mapping,
risk, stops, spreads, and lifecycle are disclosed pre-result QM choices.
Retrieval roles and limits are in
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSIEGEL-TUKEY-RV-20260902/retrieval_route_20260902.json`.

## Approved mechanic

At the first synchronized executable D1 boundary of each broker month:

```text
17 consecutive completed synchronized XAU/XAG month-end pairs
-> 16 adjacent changes in ln(XAU)-ln(XAG)
-> fixed old r[0..7] and recent r[8..15] blocks
-> reject any pooled tie under relative epsilon 1e-12
-> assign ascending-value ST scores 1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2
-> sum scores carrying recent labels
-> enumerate all C(16,8)=12,870 fixed-size label allocations
-> qualify at recent score <=68 and inclusive lower tail <=6,698
-> positive recent cumulative move: SELL XAU / BUY XAG
-> negative recent cumulative move: BUY XAU / SELL XAG
-> opposed equal-target-notional package for one broker month
```

One normalized month attempt is consumed before fallible gates. One aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget is split
across per-leg `3.5*ATR(20,D1)` stops. Reject more than 20 percent notional
mismatch and XAU/XAG spreads above 1,500/500 points. Submit XAU first, XAG
second, flatten a malformed package immediately, and exit at the next month or
after forty days. Statistic and move magnitude never size risk.

Complete pre-data enumeration qualifies 6,698 of 12,870 allocations, including
526 at score 68. That is 52.0435 percent of fixed label space and 6.245
theoretical states per twelve attempts, not market evidence or inference.
Receipt:
`artifacts/qm5_xauxag_msiegel_tukey_rv_threshold_density_20260902.json`.

## Reputable-source findings

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_PEER_REVIEW_EXCHANGE_AND_OFFICIAL_METHOD_EVIDENCE` | One durable AI source, complete peer-reviewed gold/silver packet with adverse findings, official exchange carrier, original peer-reviewed method metadata, complete NIST algorithm record, and explicit no-performance boundaries. |
| R2 | `PASS` | Month clock, synchronization, endpoints, changes, blocks, ties, score path, 12,870-label enumeration, inclusive 68/6,698 boundary, side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5 state supply every runtime input. |
| R4 | `PASS` | Completed prices, logarithms, sorting, bounded integer enumeration, ATR risk controls, and native execution only; no ML, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Non-duplicate decision

The corrected-root checker receipt
`artifacts/qm5_xauxag_msiegel_tukey_rv_preallocation_dedup_20260902.json`
finds no exact identity across 4,785 registry rows, 1,421 cards, and 45 Wiki
nodes. It raises the expected direct-WTI method parent and four XAU/XAG rank
neighbors for manual review.

- `QM5_41271` trades one direct WTI position and continues its move. This
  candidate trades a synchronized XAU/XAG ratio through opposed legs and fades
  the relative move, producing a different carrier, payoff, magic set, and PnL.
- The XAU/XAG fuzzy neighbors use twelve observations, six-by-six labels, and
  Van der Waerden, Cucconi, Kuiper, or Savage state functions. This candidate
  uses sixteen observations, eight-by-eight labels, and the nonmonotone
  alternating-extremes score path.
- Brown-Forsythe, centered Klotz, and centered Conover scale baskets use
  absolute deviations or within-block centering; this rule ranks raw changes.
- Frozen fixtures provide both disagreement directions: a score-61 candidate
  state leaves Van der Waerden and Savage flat; a score-70 candidate-flat state
  activates both of those latest-twelve neighbors.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_EIGHT_BY_EIGHT_SIEGEL_TUKEY_ALTERNATING_EXTREMES_LOWER_HALF_RECENT_MOVE_CONTRARIAN_BASKET`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero packages, fewer than five completed
packages in any full scored post-warm-up year, nonpositive governed economics,
future leakage, score/enumeration/fixture mismatch, missing stops, invalid
fixed-risk mode, malformed package, or nondeterminism. No after-result change
to sample, score, threshold, side, carrier, risk, or hold may rescue failure.
Q09 alone owns realized portfolio overlap.

Authorized after G0 and clean registries: branch-only non-live build,
deterministic reference tests, strict Q01, one logical fixed-risk preset plus
two component validation presets, and one paced logical-basket Q02 work item if
the whole-host CPU ceiling permits. Excluded: manual backtests; live, demo,
shadow, stress, or optimization presets; component Q02 rows; portfolio-gate
edits; correlation waivers; portfolio admission; deploy/live manifests;
`T_Live`; AutoTrading; and terminal control.
