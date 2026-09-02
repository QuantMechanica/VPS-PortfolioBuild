---
source_id: AI-CODEX-USDCHF-WW-SHIFT-20260902
title: USDCHF weekly fixed-block Mann-Whitney location-shift continuation
publisher: QuantMechanica governed synthesis of peer-reviewed trading and statistical-method records
source_type: ai_originated_peer_reviewed_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_usdchf_weekly_mann_whitney_shift_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026: 8D42ED6DF1415B6EDF7FF29AE9349BCA576F0F66204A8021E2E0B8D73B0AEDE0
created: 2026-09-02
created_by: Research+Development
cards_extracted:
  - usdchf-ww-shift-tr
---

# USDCHF Weekly Fixed-Block Mann-Whitney Shift Source Packet

## Approval And Complete-Read Boundary

The durable OWNER source approval is
`decisions/2026-09-02_usdchf_weekly_mann_whitney_shift_trend_source_approval.md`,
committed as `cae9a7497d` before this extraction. The current mission authorizes
one structural low-frequency forex edge after the diverse backlog and genuine
infrastructure-recovery lanes were exhausted. It requires fixed-risk non-live
testing and forbids portfolio and live mutations.

Every bounded parent record was read completely before source approval. Exact
paths, hashes, read scopes, method-file identities, and access limitations are
sealed in `retrieval_route_20260902.json`. No new public retrieval was needed.

## Sources Of Record

### Trading-family lineage

Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, is represented by the complete governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. Its retrieval receipt binds
the author-hosted 23-page published PDF to SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379` and
records an end-to-end read.

The paper supplies broad own-price continuation and fixed renewal lineage. The
existing governed packet is energy-oriented and does not independently
validate USDCHF, a weekly decision clock, twelve daily levels, the fixed split,
or the proposed risk lifecycle. No paper result transfers to this candidate.

### Statistical-method lineage

H. B. Mann and D. R. Whitney (1947), "On a Test of Whether one of Two Random
Variables is Stochastically Larger than the Other," *The Annals of
Mathematical Statistics* 18(1), 50-60, DOI
`10.1214/aoms/1177730491`, supplies the named peer-reviewed method identity.
The publisher body was classified `DEFERRED:SOURCE_POLICY`, is not claimed as
completely read, and contributes no text, table, probability, or result.

The complete pinned R Core Team `stats::wilcox.test` source and manual at
public `wch/r-source` commit
`7344a2d9d96b3c2b997535d3abc8c3a44af16e82` supply the operative definition.
For two samples without ties, the first sample's statistic is its combined
rank sum less the minimum possible rank sum, equivalently the number of
favorable cross-sample pairs. Exact blob IDs and hashes are inherited from the
complete retrieval receipt under
`MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026`.

## Source Findings Used

- Broad own-price continuation is a reputable falsification family; it does
  not establish this carrier or horizon.
- Mann-Whitney/Wilcoxon rank-sum supplies a deterministic ordinal comparison
  between two fixed samples.
- In a strict no-tie six-by-six construction, the newer-sample statistic can
  be calculated with exactly 36 pair comparisons and must complement the
  older statistic to 36.
- Statistic magnitude may select a side but never scale risk.

The records do not establish that USDCHF daily price levels exhibit a
predictive weekly location shift. That conjunction is pre-result
QuantMechanica synthesis.

## Exact Statistical Contract

For twelve completed, positive, finite, pairwise-distinct USDCHF D1 closes
`C[0]..C[11]`, oldest to newest, define:

```text
O = C[0..5]
N = C[6..11]

U_new = count(N[j] > O[i] for every i=0..5 and j=0..5)
U_old = count(O[i] > N[j] for every i=0..5 and j=0..5)

require 0 <= U_new <= 36
require 0 <= U_old <= 36
require U_new + U_old == 36

BUY  iff U_new >= 24
SELL iff U_new <= 12
FLAT otherwise
```

With `N` as the first sample, `U_new` also equals the combined rank sum of the
newer six closes less `6*7/2`. Exact ties fail closed; there is no average rank,
p-value, fitted location, variable split, maximum search, endpoint-return
confirmation, volatility confirmation, or fallback.

## Pre-Result Density Boundary

Exact enumeration of the `choose(12,6)=924` no-tie assignments of the combined
ranks produces 182 assignments at `U_new>=24` and 182 at `U_new<=12`. The
symmetric qualification support is `364/924 = 0.3939393939393939`.

Applied to at most 52 weekly attempts, that is approximately 20.48 qualifying
rank-label states under a combinatorial ordering model. It is not a
probability, serial-independence assumption, USDCHF trade count, significance
level, expected return, or performance claim. The operating prior is 10-25
completed positions per full post-warm-up year; Q02 owns the fact.

## Locked Trading Translation

At the first eligible exact `USDCHF.DWX` D1 tick after a genuine framework
week-key transition:

1. Persist the current week key before every fallible gate. A flat signal,
   invalid input, rejected order, stop, restart, or late tick never creates a
   second attempt that week.
2. Exclude the forming bar and load exactly twelve completed D1 bars. Reject
   missing, duplicate, nonchronological, nonpositive, nonfinite, or tied
   closes.
3. Split once after observation six, count all 36 cross-block comparisons in
   both directions, and prove the complement invariant.
4. Continue the shift: buy at `U_new>=24`, sell at `U_new<=12`, otherwise stay
   flat for the consumed week.
5. Open no more than one position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`. Size to a frozen normalized
   `3.0*ATR(20,D1)` broker hard stop, attach no target, and reject spread above
   50 points.
6. Use mandatory framework Friday close so the next weekly decision starts
   flat. A seven-calendar-day stale guard and malformed-position repair are
   authoritative fallbacks.

Both news axes and legacy news mode are OFF. Runtime uses native USDCHF D1
OHLC, framework week state, ATR, quotes, symbol metadata, positions, deals,
and terminal globals only. No interest-rate, futures-curve, macro, file, API,
forecast, trained-output, or portfolio input exists.

## Non-Duplicate Boundary

The fail-closed corrected-root receipt
`artifacts/qm5_usdchf_ww_shift_tr_preallocation_dedup_20260902.json`, SHA-256
`E0FD0C192E36312BA520D214FF3A4A800A36E42B0CF4A6FD5C860A7050881741`,
scanned 4,779 registry identities, 1,415 card files, and all 45 Strategy Wiki
nodes and returned `CLEAN` with no fuzzy match.

Manual review separates the candidate from the nearest families:

- `QM5_41176_wti-mwilcoxon-shift-tr` uses monthly WTI endpoints and a
  next-month lifecycle. Carrier, bar sampling, opportunity set, holding
  window, spread surface, and Friday state differ here.
- `QM5_10145_tsm-meanret` uses an endpoint/rolling-mean-return sign every D1
  bar across a broad universe. This candidate uses one fixed ordinal block
  comparison and one consumed weekly attempt.
- `QM5_1111_qp-fx-momentum-12m` ranks seven foreign currencies
  cross-sectionally over 252 days. This candidate is single-symbol,
  own-history, and contains no basket or currency inversion rank.
- the USDCHF cointegration family owns paired log spreads and frozen betas;
  this candidate has no second symbol or hedge ratio.

Verdict:
`DISTINCT_USDCHF_WEEKLY_FIXED_SIX_BY_SIX_D1_CLOSE_MANN_WHITNEY_U24_LOCATION_SHIFT_CONTINUATION_FRIDAY_FLAT`.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_CADENCE_TRANSLATION_RISK`: complete-read
  peer-reviewed broad continuation evidence, named peer-reviewed method
  lineage, complete pinned R Core method files, and explicit untested-
  synthesis boundary.
- R2 `PASS`: clock, bars, blocks, tie policy, pair counts, invariant,
  thresholds, side, attempt, fixed risk, hard stop, Friday exit, and stale
  repair are locked.
- R3 `PASS`: registered `USDCHF.DWX` native D1 history and MT5/framework state
  supply every runtime input.
- R4 `PASS`: deterministic comparisons, integer arithmetic, ATR risk, and
  execution state only; no ML, prohibited signal indicator, external feed,
  grid, martingale, averaging, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire or fail on zero trades, fewer than ten completed positions in any full
post-warm-up year, nonpositive governed economics, nondeterminism, or any
week-key, completed-bar, fixed-block, tie, comparison, invariant, threshold,
direction, attempt, stop, Friday-close, stale-repair, fixed-risk, or symbol
defect. No failed result may be rescued by changing the carrier, cadence,
sample, split, tie rule, boundary, direction, risk, stop, or hold.

This packet authorizes no manual tester run, optimization, live/demo/shadow/
stress preset, terminal control, portfolio-gate edit, correlation waiver,
portfolio admission, deploy/live manifest, `T_Live`, or AutoTrading. Q09 alone
owns realized portfolio overlap.

## Revision History

| version | date | change | state |
|---|---|---|---|
| v1 | 2026-09-02 | bounded USDCHF weekly rank-shift synthesis fixed before market testing | `APPROVED_SOURCE` |
