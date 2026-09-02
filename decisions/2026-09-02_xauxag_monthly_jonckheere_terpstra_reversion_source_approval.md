# XAU/XAG Monthly Jonckheere-Terpstra Reversion - Source Approval

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural XAU/XAG relative-value hypothesis, one
  Strategy Card, one branch-only build, strict Q01, and one paced non-live
  logical-basket Q02 enqueue
- Proposed slug: `xauxag-mjt-rv`
- Proposed strategy ID: `AI-CODEX-XAUXAG-MJT-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MJT-RV-20260902`

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
`strategy-seeds/sources/AI-CODEX-XAUXAG-MJT-RV-20260902/source.md`.
`processes/qb_reputable_source_criteria.md` explicitly permits AI-originated
strategies when their source ID and prompt/output trail are durable.

Supporting evidence is bounded to:

1. Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, through the complete governed source
   packet and its full 32-page author-preprint read;
2. CME Group's official gold/silver ratio spread record;
3. the complete bounded NIST/SEMATECH Jonckheere-Terpstra method page;
4. the complete relevant method sections of Altunkaynak and Gamgam (2020),
   *The R Journal* 12(1); and
5. Jonckheere (1954), *Biometrika* 41(1-2), 133-145, DOI
   `10.1093/biomet/41.1-2.133`, limited to publisher metadata because the body
   was paywalled.

The retrieval scopes and explicit no-transfer boundaries are preserved in
`strategy-seeds/sources/AI-CODEX-XAUXAG-MJT-RV-20260902/retrieval_route_20260902.json`.
The method records support ordered-group pair counting only. They do not
support the time-series grouping, trading side, threshold, CFD mapping, risk,
performance, independence, or portfolio claims.

## Approved mechanic

At the first synchronized executable D1 boundary of a broker month:

```text
13 consecutive completed synchronized XAU/XAG month-end pairs
-> 12 adjacent changes in ln(XAU)-ln(XAG)
-> chronological groups G0=r[0..3], G1=r[4..7], G2=r[8..11]
-> reject any pooled tie under relative epsilon 1e-12
-> J=sum I(x<y) across every earlier-group/later-group pair
-> require exactly 48 comparisons
-> enumerate C(12,4)*C(8,4)=34,650 labeled rank allocations
-> inclusive two-sided tail counts abs(J_perm-24)>=abs(J-24)
-> qualify at tail<=18,034, equivalent to J<=19 or J>=29
-> J>=29: SELL XAU / BUY XAG
-> J<=19: BUY XAU / SELL XAG
-> opposed equal-target-notional package for one broker month
```

One normalized broker-month attempt is consumed before fallible gates. One
aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget is
split across per-leg `3.5*ATR(20,D1)` hard stops. Reject more than 20 percent
notional mismatch and XAU/XAG spreads above 1,500/500 points. Submit XAU first,
XAG second, flatten a malformed package immediately, and exit at the next
month or after forty days. Score magnitude never sizes risk.

Complete pre-data enumeration qualifies 18,034 of 34,650 assignments,
symmetrically split 9,017/9,017. That is a 52.0462 percent label-space density
and 6.246 theoretical states per twelve attempts, not market evidence or a
p-value. Receipt:
`artifacts/qm5_xauxag_mjt_rv_threshold_density_20260902.json`.

## Reputable-source findings

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_PEER_REVIEW_AND_OFFICIAL_METHOD_EVIDENCE` | One durable AI source; complete peer-reviewed gold/silver relationship packet with adverse evidence; official exchange carrier; complete bounded NIST and R Journal method records; original peer-reviewed metadata; explicit claim boundaries. |
| R2 | `PASS` | Month clock, synchronization, endpoints, changes, three groups, ties, 48 comparisons, 34,650-label enumeration, tail, side, attempt, aggregate risk, atomicity, and lifecycle are deterministic and locked. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5 state supply every runtime input. |
| R4 | `PASS` | Completed prices, logarithms, comparisons, bounded integer enumeration, ATR risk control, and native execution only; no ML, trained output, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Non-duplicate decision

The corrected-root checker receipt
`artifacts/qm5_xauxag_mjt_rv_preallocation_dedup_20260902.json`, SHA-256
`E103D2C5F4751B0AB5B228C898DFC85AD49C4C801D29939FB1A4D0C753CBB944`,
found no exact identity across 4,784 registry rows, 1,420 card files, and all
45 Strategy Wiki nodes. The five reported fuzzy matches share only the
XAU/XAG carrier and use channel, OLS, fixed-horizon reversal,
semivariance-jump, or median/MAD state functions.

Manual family review also separates the candidate from the within-month
three-block vote, WTI daily three-block ordinal classifier, and six/six
Mann-Whitney or Van der Waerden baskets. Fixed strict-rank fixtures prove
candidate-only, neighbor-only, and opposite-side decisions.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_THREE_BY_FOUR_CLASSIC_JONCKHEERE_TERPSTRA_48_ORDERED_WINS_EXACT_34650_TWO_SIDED_TAIL18034_CONTRARIAN_BASKET`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero completed packages, fewer than
five completed packages in any full scored post-warm-up year, nonpositive
governed economics, leakage, formula/fixture mismatch, missing stop, invalid
fixed-risk mode, malformed package, or nondeterminism. No post-result change
to sample, groups, score, tail, direction, carrier, risk, or hold may rescue a
failure. Q09 alone owns realized portfolio overlap.

Authorized after G0 and clean registries: branch-only non-live build,
reference tests, strict Q01, one logical fixed-risk preset plus two component
validation presets, and one paced logical-basket Q02 work item if CPU admission
permits. Excluded: manual tester run, live/demo/shadow/stress/optimization
presets, component Q02 rows, portfolio-gate edits, correlation waiver,
portfolio admission, deploy/live manifests, `T_Live`, AutoTrading, and
terminal control.
