---
source_id: AI-CODEX-XAUXAG-MKUIPER-RV-20260901
source_type: ai_originated_peer_reviewed_exchange_official_method_composite_bounded_mechanization
title: XAU/XAG monthly exact-permutation Kuiper distribution-shift reversion
author: OpenAI Codex
supporting_authors: Nicolaas H. Kuiper; Karsten Schweikert
status: approved_source_complete
approval_basis: decisions/2026-09-01_xauxag_monthly_kuiper_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-QC-2018
  - CME-GSR-SPREAD-2025
parent_sha256:
  SCHWEIKERT-QC-2018: 7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA
  CME-GSR-SPREAD-2025: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
created: 2026-09-01
created_by: Codex
last_reviewed: 2026-09-01
cards_extracted:
  - QM5_41263_xauxag-mkuiper-rv
---

# XAU/XAG Exact-Permutation Kuiper Reversion

## Canonical origin and complete evidence boundary

This packet is the single R1 lineage for one bounded AI-originated strategy.
The durable prompt and output trail is `prompt.md` and `output.md`; OWNER source
approval precedes extraction.

The following complete bounded evidence was read:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`,
   governing Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
   DOI `10.1016/j.jbankfin.2017.11.010`;
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   the official CME gold/silver ratio carrier record;
3. Kuiper (1960), *Indagationes Mathematicae (Proceedings)* 63, 38-47, DOI
   `10.1016/S1385-7258(60)50006-0`, complete-paper read recorded in
   `retrieval_route_kuiper_1960_20260901.json`; and
4. CRAN `twosamples` 2.0.1 and pinned source commit
   `4923388cdb14be4875a7041cddd69629a6bfc735`, recorded in
   `retrieval_route_cran_twosamples_20260901.json`.

Schweikert supplies state-dependent and asymmetric gold/silver relationship
evidence. Its adverse findings remain load-bearing: a constant relationship
is not uniformly supported, relevant states are not known ex ante, and the
paper does not deliver this forecast. CME defines the price-ratio/spread
carrier and distinguishes gold's stronger monetary role from silver's larger
industrial-cycle component. Futures liquidity, clearing, offsets, contract
ratios, and execution quality do not transfer to CFDs.

Kuiper defines a distribution-free two-sample distance between continuous
empirical distributions: the maximum positive gap plus the magnitude of the
maximum negative gap. Pinned CRAN source independently implements that sum
and a pooled-label permutation route. The EA imports neither source code,
random resampling, asymptotic normalization, paper critical values, nor a
p-value.

No source tests the complete trading conjunction. The data window, adjacent
log-ratio changes, six/six split, strict ties, exhaustive labels, boundary,
side, continuous-CFD mapping, equal target notionals, fixed-dollar risk,
stops, spreads, atomicity, and lifecycle are disclosed pre-result QM choices.
No performance, activity, neutrality, or decorrelation claim transfers.

## Exact statistical contract

At a broker-month transition reconstruct thirteen synchronized, positive,
finite, consecutive completed-month XAU/XAG close pairs. For chronological
endpoints `i=0..12`:

```text
q[i] = ln(XAU_close[i]) - ln(XAG_close[i])
r[i] = q[i+1] - q[i], i=0..11
old = r[0..5]; recent = r[6..11]
require all twelve r values pairwise distinct

pool and sort r ascending, retaining fixed old/recent labels
at pooled cut j=1..12:
  F_old    = old_seen / 6
  F_recent = recent_seen / 6
  D_plus  = max(D_plus,  F_recent - F_old)
  D_minus = max(D_minus, F_old - F_recent)
V = D_plus + D_minus

tail_count = 0
for every one of C(12,6)=924 choices of six recent ranks:
  compute V_perm from that label path
  if V_perm + 1e-12*max(1,abs(V)) >= V:
    tail_count++

require V + 1e-12 >= 0.5
require tail_count <= 798
W_recent = sum of the six pooled ranks tagged recent
SELL XAU / BUY XAG iff W_recent > 39
BUY XAU / SELL XAG iff W_recent < 39
FLAT otherwise
```

For six/six strict labels the only Kuiper distances and exact inclusive tails
are: `1/6 -> 924`, `1/3 -> 922`, `1/2 -> 798`, `2/3 -> 408`, `5/6 -> 108`,
and `1 -> 12`. Therefore the `V>=0.5` and `tail<=798` clauses are equivalent
cross-checks, not significance claims. Of 798 qualifying label assignments,
38 have neutral rank sum 39. The remaining 760 imply
`760/77 = 9.87012987` directional states per twelve combinatorial monthly
attempts. This is a market-free design prior; it assumes neither independent
returns nor uniform market ranks and says nothing about executions or profit.

## Locked trading translation

At the first synchronized executable `XAUUSD.DWX` D1 tick after a genuine
broker-month transition:

1. Normalize and persist current broker `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order gates. Never retry the month.
2. Exclude current-month prices. From a bounded 900-bar buffer select thirteen
   immediately prior consecutive broker months and the latest exactly
   timestamp-matched XAU/XAG D1 close pair in each. Reject missing, duplicate,
   unmatched, nonchronological, nonpositive, nonfinite, or endpoints separated
   from month end by more than ten calendar days.
3. Calculate twelve adjacent log-ratio changes, preserve old/recent membership,
   reject exact ties, and calculate the complete Kuiper rank path.
4. Enumerate all 924 fixed-size label assignments and consume flat unless the
   observed inclusive tail is at most 798, `V>=0.5`, and rank sum is not 39.
5. Fade a high recent distribution by selling XAU and buying XAG; fade a low
   recent distribution with the opposite package.
6. Open at most one opposite-side equal-target-notional package under one
   aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget.
   Split frozen-stop risk equally, use per-leg `3.5*ATR(20,D1)` hard stops,
   reject spreads above 1,500/500 points, and reject rounded target-notional
   mismatch above 20 percent.
7. Submit XAU first and XAG second. Keep exposure only when exactly one correct,
   stopped position exists under each registered magic; otherwise flatten all
   owned legs immediately.
8. Close on the first tick in a later broker month or after forty elapsed
   calendar days. No intramonth flip, convergence target, trail, break-even,
   partial close, Friday close, or news exit is authorized.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered native D1 history/timestamps, logarithms, sorting, bounded integer
loops, comparisons, broker calendar, quotes, metadata, ATR, positions, deals,
and terminal-persistent attempt state.

## Non-duplicate decision

The fail-closed receipt
`artifacts/qm5_xauxag_mkuiper_rv_preallocation_dedup_20260901.json`, SHA-256
`CBEA9419A218F75324605F679CEC778FEC42D513A0E6A2E5BB516BAE46A4D5F7`,
scanned 4,762 registry identities, 1,399 cards, and all 45 Strategy Wiki nodes.
It found no exact identity and surfaced only `QM5_41260_xauxag-mad2-rv` as a
same-carrier fuzzy neighbor.

- `QM5_41187_xauxag-mks-rv` examines ratio levels and keeps only the largest
  signed KS gap. This rule examines adjacent ratio changes and adds both
  opposing ECDF extremes.
- `QM5_41260_xauxag-mad2-rv` accumulates squared discrepancies at every rank
  with tail weights. This rule retains only the two extreme opposing gaps.
- `QM5_41177_xauxag-mwilcoxon-shift-rv` thresholds one rank sum on ratio levels.
  Here rank sum directs a trade only after a distinct Kuiper change-distribution
  state qualifies.
- `QM5_41247_xauxag-mcusum-rv` mean-centers changes and searches a cumulative
  time-path deviation; this rule mean-centers nothing and fixes old/recent
  empirical samples.

Fixed strict-label fixtures prove functional disagreement. Path
`RROROROOROOR` has Kuiper `V=1/2` and qualifies here, KS maximum gap `1/3`
and Anderson-Darling tail 532, so both neighbors are flat. Path
`RROROROROORO` has Kuiper `V=1/3` and is flat here while Anderson-Darling
qualifies at tail 428. Complements reverse direction. The result is distinct,
not a version of either mechanic.

## Reputable-source criteria

- **R1 — PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE.** Durable
  prompt/output/source trail, complete governed peer-reviewed relationship
  evidence with adverse findings, official exchange carrier evidence, complete
  primary method paper, pinned official software source, and explicit limits.
- **R2 — PASS.** Clock, synchronization, endpoints, state orientation, fixed
  blocks, strict ties, formula, all 924 labels, inclusive tolerance, boundary,
  side, attempt, aggregate risk, package atomicity, and lifecycle are locked.
- **R3 — PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK.** Registered
  native XAU/XAG D1 histories and MT5 state provide every runtime input; basis,
  financing, calendar, and legging risks remain.
- **R4 — PASS.** Deterministic bounded arithmetic and framework state only; no
  trained output, prohibited signal indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Kill and safety boundaries

Retire on a failed formula or enumeration fixture, nondeterministic count,
zero packages, fewer than five completed packages in any full post-warm-up
year, nonpositive governed economics, downstream gate failure, or a month,
endpoint, synchronization, change, tie, rank, statistic, side, attempt, risk,
package, lifecycle, or determinism defect. Do not rescue a failure by changing
the sample, split, boundary, side, carrier, risk, or hold.

Equal target notionals and opposite legs are market-neutral-style construction
only. They do not establish dollar, beta, volatility, factor, market, or
portfolio neutrality. Unchanged Q09 alone owns realized overlap.

Authorized after card G0 and clean registries: one branch-only non-live build,
reference tests, strict Q01, three fixed-risk component/logical-basket backtest
presets, and one paced logical-basket Q02 enqueue below the CPU ceiling.
Excluded: manual tester run, optimization, live/demo/shadow/stress preset,
component-leg Q02 row, `T_Live`, AutoTrading, deploy/live manifest, portfolio-
gate change, portfolio admission, correlation waiver, or terminal control.
