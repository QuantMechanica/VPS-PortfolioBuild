---
source_id: AI-CODEX-WTI-MORDENTROPY-20260902
source_type: ai_originated_governed_synthesis
title: WTI monthly order-3 permutation-entropy-gated trend
author: OpenAI Codex
supporting_authors: Christoph Bandt; Bernd Pompe; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_ordinal_entropy_trend_source_approval.md
created: 2026-09-02
created_by: Codex
last_reviewed: 2026-09-02
cards_extracted:
  - wti-mordinal-entropy-tr
---

# WTI Monthly Order-3 Permutation-Entropy Trend

## Canonical origin and claim boundary

This is the single R1 lineage for one bounded AI-originated strategy under the
current explicit OWNER request for a new structural, low-frequency commodity
or energy sleeve. The rule was fixed before market testing: describe twenty-four
completed WTI monthly log returns by the ordinal patterns of eight disjoint
three-return blocks, admit only a low-complexity pattern distribution, and then
follow the sign of the newest twelve-month return for one broker month.

Bandt and Pompe (2002) define permutation entropy from the frequencies of
ordinal patterns in neighboring observations and recommend low orders including
three. Moskowitz, Ooi, and Pedersen (2012) support only the direct-WTI carrier,
own-return continuation over monthly horizons, and monthly renewal. The
disjoint triples, eight-pattern sample, normalized `0.80` gate, conjunction,
continuous-CFD mapping, fixed risk, stop, spread cap, attempt ledger, and
lifecycle are transparent, untested QM choices.

No source tests this exact rule or supplies its return, profit factor, p-value,
significance, drawdown, activity, transaction cost, CFD equivalence,
decorrelation, or portfolio fit. Q02 owns activity and economics; unchanged Q09
alone owns realized portfolio overlap.

## Supporting evidence and complete bounded reads

The complete method source is Bandt and Pompe (2002), "Permutation Entropy: A
Natural Complexity Measure for Time Series," *Physical Review Letters* 88,
174102, DOI `10.1103/PhysRevLett.88.174102`. The complete four-page official
APS-rendered paper was read end to end. It defines the order-type frequencies
and `H(n)=-sum(p*pi*log(p*pi))`, gives the order-three example, states the
`0 <= H(n) <= log(n!)` support, recommends orders three through seven, and
warns that the observation count should be large relative to `n!`. It also
notes monotone-transform invariance and treats exact ties as a special case.

The complete governed trading-paper record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
It records a complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. Appendix A includes NYMEX WTI. The paper
documents own-return continuation over one-to-twelve-month horizons while
making clear that pooled futures results are not a WTI-only performance claim.

Retrieval roles, scopes, and boundaries are preserved in
`retrieval_route_20260902.json`. The APS method is used as deterministic
arithmetic, not as evidence that low entropy predicts WTI returns. The MOP
paper is used for the carrier and continuation direction, not for the entropy
conjunction.

## Locked hypothesis and exact formula

Physical supply, storage, transport, refining, geopolitical, hedging, and
demand shocks can create persistent but irregular WTI paths. The candidate
tests whether a repeated low-order monthly return structure identifies a
lower-complexity state in which the established own-return continuation carrier
is more selective than an unconditional twelve-month trend rule.

At the first executable D1 tick after a genuine broker-month transition:

1. Reconstruct twenty-five consecutive completed `XTIUSD.DWX` broker-month-end
   closes, oldest to newest, excluding every current-month price.
2. Form twenty-four chronological log returns:

```text
r[i] = ln(close[i+1] / close[i]), i=0..23
```

3. Divide them into eight disjoint chronological triples
   `T[k]=(r[3k],r[3k+1],r[3k+2])`, `k=0..7`. Reject any within-triple tie under
   relative epsilon `1e-12`; random jitter is forbidden.
4. Map each triple to exactly one lexicographic rank pattern:

```text
0: 012 (a < b < c)       3: 120 (c < a < b)
1: 021 (a < c < b)       4: 201 (b < c < a)
2: 102 (b < a < c)       5: 210 (c < b < a)
```

5. Let `count[j]` be the number of triples in pattern `j`, require
   `sum(count)=8`, and compute:

```text
p[j]   = count[j] / 8
H      = -sum(p[j] * ln(p[j])) over nonzero counts
H_norm = H / ln(6)
```

6. Qualify only at inclusive `H_norm <= 0.80`. Consume the month flat above
   the boundary or on any invariant failure. Entropy never changes risk.
7. Compute `mom12=sum(r[12..23])`. Buy at `mom12 > 1e-12`, sell at
   `mom12 < -1e-12`, and consume flat otherwise.
8. Risk one fixed budget, attach a frozen `3.5*ATR(20,D1)` hard stop, and close
   at the next genuine broker month or after forty elapsed calendar days.

The eight disjoint triples avoid double-counting a monthly return inside two
ordinal observations. They remain a short and dependent financial sample, so
the entropy is a state descriptor only. There is no estimator-consistency,
independence, efficiency, or forecasting claim.

## Exact pre-data activity boundary

There are `6^8=1,679,616` possible eight-label pattern strings. Exhaustive
enumeration, without market values, gives `782,496` strings at normalized
entropy no greater than `0.80`, a fraction of
`0.46587791495198905` or `5.590534979423868` theoretical qualifying states per
twelve monthly clocks. The greatest admitted discrete entropy is
`0.773705614469`; the next possible value, `0.833915022608`, is excluded.

This label-space calculation assumes uniformly distributed pattern labels and
is not a market frequency, forecast, p-value, or test result. Receipt:
`artifacts/qm5_wti_mordinal_entropy_tr_threshold_density_20260902.json`.
Q02 retires zero positions or fewer than five completed positions in any full
scored post-warm-up year.

## Non-duplicate boundary

The fail-closed corrected-root checker scanned 4,793 registry identities,
1,422 card files, and all 45 Strategy Wiki nodes. It found no exact identity
and no fuzzy hit at its configured threshold. Receipt:
`artifacts/qm5_wti_mordinal_entropy_tr_preallocation_dedup_20260902.json`.

Manual review additionally resolves the nearest semantic families:

- `QM5_9520_mql5-entropy` is an M15 multi-symbol up/down/flat Shannon-entropy
  crossover and compression strategy. It does not use monthly WTI returns,
  six order-three permutations, disjoint triples, or a twelve-month trend.
- `QM5_12603_wti-tsmom12m` follows the twelve-month WTI return every month.
  This candidate consumes high-ordinal-entropy months flat and therefore owns
  a different state and trade stream.
- `QM5_20273_wti-signrun-tr`, `QM5_20272_wti-qtrvote-tr`, and
  `QM5_41111_wti-mdaybreadth-mom` reduce history to signs or fixed block sums.
  They cannot distinguish equal sign counts with different within-triple order
  patterns.
- Rank-location, distribution-shift, scale, same-calendar, event, and price
  channel WTI builds use different clocks or statistics. Certified
  `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG pullback.

Verdict:
`CLEAN_WTI_MONTHLY_24_RETURN_EIGHT_DISJOINT_ORDER3_PATTERN_NORMALIZED_PERMUTATION_ENTROPY_080_GATED_12M_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_PEER_REVIEWED_EVIDENCE`: one durable
  AI source ID, a complete official APS method-paper read, a complete governed
  JFE trading-paper read, hashes where retained, and explicit no-result
  boundaries.
- R2 `PASS`: month clock, endpoints, returns, triple membership, order codes,
  tie rejection, entropy formula, inclusive gate, side, consumed attempt,
  fixed risk, stop, spread, and exits are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state supply every runtime input; roll,
  financing, gaps, and broker-month labels remain risks.
- R4 `PASS`: timestamps, completed prices, logarithms, comparisons, bounded
  counts, entropy arithmetic, ATR risk control, and native execution only; no
  ML, trained output, prohibited signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

The packet establishes no profitability, significance, decorrelation, or
portfolio fitness. Q02 kills the unchanged baseline on zero positions, fewer
than five completed positions in any full scored post-warm-up year,
nonpositive governed economics, future leakage, formula/fixture mismatch,
missing stop, invalid fixed-risk mode, malformed lifecycle, or nondeterminism.
No post-result change to the sample, triples, entropy boundary, momentum side,
carrier, stop, or hold may rescue a failure.

Authorized scope is one approved card, deterministic identity and magic
allocation, one branch-only non-live build, strict Q01, and one paced Q02
enqueue if the whole-host CPU ceiling permits. It excludes manual tester runs,
live/demo/shadow/stress/optimization presets, terminal control, AutoTrading,
`T_Live`, deploy/live manifests, portfolio-gate edits, correlation waivers,
portfolio admission, and any live-use authority.
