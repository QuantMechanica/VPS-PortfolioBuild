# XAU/XAG Monthly Sn Dispersion Reversion - Source Approval

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural XAU/XAG relative-value hypothesis, one
  Strategy Card, deterministic allocation, one branch-only non-live build,
  strict Q01, and one paced logical-basket Q02 enqueue if CPU capacity permits
- Proposed slug: `xauxag-msndisp-rv`
- Proposed strategy ID: `AI-CODEX-XAUXAG-MSNDISP-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MSNDISP-RV-20260902`

## Authority and ordering

The current explicit OWNER mission authorizes one new reputable-source,
structural, low-frequency commodity/energy sleeve, expressly names a
market-neutral-style gold/silver basket as eligible, requires real committed
non-duplicate work, and requests a fixed-risk Q02 enqueue. This durable record
approves the bounded source before card extraction. It does not pre-approve
activity, economics, robustness, decorrelation, portfolio admission,
deployment, or live use.

The governed allocator owns the numeric EA identity. This record neither
predicts nor hand-allocates it.

## Approved evidence and complete read

The single R1 lineage is the AI-originated packet
`strategy-seeds/sources/AI-CODEX-XAUXAG-MSNDISP-RV-20260902/source.md`.
`processes/qb_reputable_source_criteria.md` permits one AI lineage source when
its prompt/output trail and claim boundaries are durable.

Supporting evidence is bounded to three completely read governed packets:

1. Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, through its complete 32-page author-
   preprint record and binding adverse evidence against a constant spread;
2. CME Group's official gold/silver ratio-spread packet; and
3. Rousseeuw and Croux (1993), *Journal of the American Statistical
   Association* 88(424), 1273-1283, DOI
   `10.1080/01621459.1993.10476408`, plus CRAN `robustbase` 0.99-7 commit
   `54c5cc98e27050a78bbd03be15f07a7ba88de62a`, through the existing complete
   paper and source-code receipts.

Their paths and immutable hashes are in the composite source and
`retrieval_route_20260902.json`. No new public URL was needed, fetched, or
represented as read. The relationship, carrier, and raw Sn arithmetic transfer;
the completed-month pairing, three-core boundary, contrarian side, CFD mapping,
risk, stops, spreads, and lifecycle remain disclosed QuantMechanica choices.

## Approved mechanic

At the first synchronized executable D1 boundary of each broker month:

```text
immediately completed broker month
-> require 17..23 synchronized XAU/XAG D1 close pairs
-> keep final 17 chronological pairs
-> q[i]=ln(XAU[i])-ln(XAG[i])
-> 16 adjacent relative changes r[i]
-> net=sum(r), verified against q[16]-q[0]
-> for each r[i], eighth of 15 sorted leave-one-out absolute distances
-> eighth of 16 sorted inner values = raw sn_core
-> omit 1.1926 and finite-sample multipliers
-> SELL XAU / BUY XAG iff net >= 3*sn_core
-> BUY XAU / SELL XAG iff net <= -3*sn_core
-> consume flat otherwise; hold one broker month
```

Require `sn_core>1e-12`, endpoint error at most `1e-10`, and finite valid
arithmetic. One normalized month attempt is consumed before all fallible
gates. One aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` budget is split across per-leg `3.5*ATR(20,D1)` hard
stops. Target equal absolute notionals by volume reduction, reject more than
twenty percent mismatch and XAU/XAG spreads above 1,500/500 points, flatten a
malformed pair, and exit next month or after forty days. Statistic magnitude
never sizes risk.

The arithmetic receipt
`artifacts/qm5_xauxag_msndisp_rv_reference_fixture_20260902.json` contains no
market data and fixes candidate-only and neighbor-only paths in both ratio
directions.

## Reputable-source findings

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_PEER_REVIEW_EXCHANGE_AND_PRIMARY_SOFTWARE_EVIDENCE` | One durable lineage source binds complete governed peer-reviewed relationship and Sn records, an official exchange carrier, pinned primary software, hashes, adverse evidence, and explicit no-performance boundaries. |
| R2 | `PASS` | Month clock, synchronization, session bounds, final-seventeen pairs, ratio changes, endpoint identity, 240 distances, exact nested lower medians, omitted multipliers, inclusive threshold, side, attempt, aggregate risk, atomicity, and lifecycle are locked. |
| R3 | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5 state supply every runtime input. |
| R4 | `PASS` | Completed prices, logarithms, sorting, bounded arithmetic, ATR risk controls, and native execution only; no trained output or external runtime feed. |

## Non-duplicate decision

The corrected-root receipt
`artifacts/qm5_xauxag_msndisp_rv_preallocation_dedup_20260902.json`, SHA-256
`29BE590ADC03C5F327E868D193ACDA508C2B3278E88EF87796EE1FBA25F0C1F0`,
returned `CLEAN` across 4,803 registry identities, 1,432 cards, and 45 Wiki
nodes. Manual family review distinguishes:

- direct-WTI Sn continuation `QM5_41277` by carrier, single-leg construction,
  and opposite payoff;
- rolling ratio median/MAD fresh-cross `QM5_20263` by state, cadence, and exit;
- monthly-block Siegel-Tukey `QM5_41286` by sample unit, old/recent labels,
  rank path, and permutation enumeration;
- cross-horizon XAU/XAG rank disagreement `QM5_20194`; and
- the Brown-Forsythe, Klotz, Conover, Anderson-Darling, Cucconi, Kuiper,
  Savage, Van der Waerden, MAD, Qn, L1, and RMS families.

Fixed fixtures prove two-way signal disagreement with Qn/L1/RMS neighbors.
Verdict:
`FUZZY_FAMILY_REVIEW_RESOLVED_DISTINCT_XAUXAG_COMPLETED_MONTH_FINAL17_SYNCHRONIZED_D1_RATIO_CHANGE_RAW_SN_THREE_CORE_CONTRARIAN_BASKET`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero packages, fewer than five completed
packages in any full post-warm-up year, nonpositive governed economics,
current-month leakage, formula/fixture mismatch, invalid fixed risk, missing
stops, malformed package, or nondeterminism. No post-result change to sample,
median convention, threshold, side, carrier, risk, or hold may rescue failure.
Q09 alone owns realized portfolio correlation.

Authorized after G0 and clean registries: branch-only non-live build,
deterministic reference tests, strict Q01, one logical fixed-risk preset plus
two component validation presets, and one paced logical-basket Q02 work item
if a fresh whole-host CPU sample is below the binding ceiling. Excluded:
manual backtests; live, demo, shadow, stress, or optimization presets;
component Q02 rows; portfolio-gate edits; correlation waivers; portfolio
admission; deploy/live manifests; `T_Live`; AutoTrading; terminal control; and
live use.
