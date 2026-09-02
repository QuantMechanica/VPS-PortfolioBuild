---
source_id: AI-CODEX-WTI-MLZ76-TREND-20260902
source_type: ai_originated_governed_synthesis
title: WTI monthly LZ76 sign-complexity-gated trend
author: OpenAI Codex
supporting_authors: Abraham Lempel; Jacob Ziv; Janusz Szczepanski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_lz76_complexity_trend_source_approval.md
created: 2026-09-02
created_by: Codex
last_reviewed: 2026-09-02
cards_extracted:
  - wti-mlz76-tr
---

# WTI Monthly LZ76 Sign-Complexity-Gated Trend

## Canonical origin and claim boundary

This packet is the single R1 lineage for one bounded AI-originated strategy
under the current explicit OWNER request for a new structural, low-frequency
commodity or energy sleeve. The rule was fixed before any market test: encode
twenty completed WTI monthly log-return signs as a binary word, admit only a
word whose raw Lempel-Ziv 1976 exhaustive-history complexity is at most six,
and follow the sign of the newest twelve-month cumulative log return for one
broker month.

Szczepanski's complete method manuscript restates the Lempel-Ziv exhaustive
history, proves that its component count is the LZ76 complexity, and treats
the finite-word complexity distribution. Moskowitz, Ooi, and Pedersen supply
only the direct-WTI carrier, one-to-twelve-month own-return continuation, and
monthly renewal. The twenty-sign window, binary return map, raw component
ceiling of six, conjunction, continuous-CFD translation, fixed risk, stop,
spread cap, attempt ledger, and lifecycle are transparent untested QM choices.

No cited paper tests this exact trading rule or supplies its return, profit
factor, significance, drawdown, activity, transaction cost, CFD equivalence,
decorrelation, or portfolio fit. Q02 owns activity and economics. The
unchanged downstream Q09 gate alone owns realized portfolio overlap.

## Supporting evidence and complete bounded reads

The exact executable method definition comes from the complete four-section
manuscript by Janusz Szczepanski, "On the Distribution Function of the
Complexity of Finite Sequences," later published in *Information Sciences*
179(9), 1217-1220 (2009), DOI `10.1016/j.ins.2008.12.019`; the complete
manuscript is available at `https://arxiv.org/abs/math/0009084`. Sections I-IV,
Definitions 1-3, the theorem, both corollaries, final remarks, and references
were read end to end. The paper states that a new phrase is the shortest
substring not seen previously, defines a unique exhaustive history, and
identifies the number of its components as the LZ76 complexity.

The originating method citation is A. Lempel and J. Ziv (1976), "On the
Complexity of Finite Sequences," *IEEE Transactions on Information Theory*
22(1), 75-81, DOI `10.1109/TIT.1976.1055501`. Its IEEE/Crossref bibliographic
record was verified, but inaccessible full text was not represented as a
complete read. The executable definition is therefore bounded to the complete
Szczepanski manuscript rather than inferred from inaccessible pages.

The complete governed trading-paper record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
It records the complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. Appendix A explicitly includes NYMEX WTI.
The paper documents own-return continuation over one-to-twelve-month horizons;
its pooled futures results are not a WTI-only or CFD performance claim.

Retrieval roles, scopes, and boundaries are preserved in
`retrieval_route_20260902.json`. LZ76 is used as deterministic finite-word
arithmetic, not as evidence that low complexity predicts WTI. The MOP paper is
used for carrier and direction, not for the LZ conjunction.

## Locked hypothesis and exact formula

WTI supply, storage, transport, refining, hedging, geopolitical, and demand
adjustments can create persistent but irregular regimes. This candidate tests
whether a repetitive monthly direction word identifies a more structured
state in which the established twelve-month own-return continuation signal is
more selective than unconditional WTI momentum.

At the first executable D1 tick after a genuine broker-month transition:

1. Reconstruct twenty-one consecutive completed `XTIUSD.DWX` broker-month-end
   closes, oldest to newest, excluding every current-month price.
2. Form twenty chronological log returns:

```text
r[i] = ln(close[i+1] / close[i]), i=0..19
```

3. Encode a fixed binary word `S=s[0]...s[19]`: `s[i]=1` when
   `r[i] > 1e-12`, `s[i]=0` when `r[i] < -1e-12`. A return inside the inclusive
   tie band consumes the month flat. Random or ordinal tie breaking is
   forbidden.
4. Parse the word from left to right into its unique LZ76 exhaustive history.
   At component start `p`, choose the shortest nonempty phrase `S[p..q]` that
   does not occur as a contiguous substring of `S[0..q-1]`, the prefix ending
   immediately before the phrase's final bit. If no new phrase exists before
   the word ends, the remaining suffix is the permitted non-exhaustive final
   component. Let `C(S)` be the number of components.
5. Require the phrases to concatenate exactly to all twenty input bits, each
   non-final phrase to be new under the definition, and `2 <= C(S) <= 9`.
   Qualify only when `C(S) <= 6`. Raw fixed-length component count is used;
   no asymptotic or empirical normalization is permitted.
6. Compute `mom12=sum(r[8..19])`. Buy when `mom12 > 1e-12`, sell when
   `mom12 < -1e-12`, and consume flat otherwise. Complexity and momentum
   magnitude never change risk.
7. Open at most one slot-0 WTI position with one fixed risk budget, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread cap.
8. Close at the next genuine broker month or after forty elapsed calendar
   days. Both news axes and Friday close stay off to preserve the monthly hold.

The method-paper example `0011011101110110` parses as
`0 | 01 | 10 | 111 | 01110110` under this definition and has complexity five.
The fixed reference implementation must reproduce that vector.

## Exact pre-data activity boundary

There are `2^20=1,048,576` binary words of length twenty. Exhaustive
enumeration without market values gives this exact LZ76 component-count
distribution:

```text
C=2:       4
C=3:     396
C=4:  11,552
C=5: 125,696
C=6: 452,428
C=7: 410,944
C=8:  47,508
C=9:      48
```

The inclusive `C<=6` gate admits `590,076` words, a fraction of
`0.5627403259277344`, or `6.7528839111328125` states per twelve monthly clocks
under an equiprobable-word reference. This is not a market-frequency,
independence, significance, or efficacy result. Receipt:
`artifacts/qm5_wti_mlz76_tr_threshold_density_20260902.json`.

Q02 retires zero positions or fewer than five completed positions in any full
scored post-warm-up year.

## Non-duplicate boundary

The fail-closed corrected-root checker scanned 4,794 registry identities,
1,423 card files, and all 45 Strategy Wiki nodes. It found no exact identity
and no fuzzy hit at its configured threshold. Receipt:
`artifacts/qm5_wti_mlz76_tr_preallocation_dedup_20260902.json`.

Manual semantic review separates the closest families:

- `QM5_41308_wti-mordinal-entropy-tr` retains return magnitudes and counts six
  order-three permutations across eight disjoint triples, then applies
  Shannon entropy. This candidate discards magnitudes for its state, parses
  one twenty-bit sign word into novel variable-length phrases, and has no
  pattern-frequency entropy.
- `QM5_20273_wti-signrun-tr` and the Wald-Wolfowitz relatives reduce history
  to adjacent sign runs or a two-sample run statistic. LZ76 phrase novelty
  depends on repeated substrings of variable length, not only transitions.
- WTI sign-count, breadth, majority-vote, block-vote, endpoint-momentum,
  regression, rank, distribution-shift, scale, calendar, event, and channel
  EAs do not build an exhaustive phrase history.
- Two balanced words can share sign and run counts but straddle this gate:
  `00000001101110100100` has seven ones, nine runs, and `C=6`, whereas
  `00000001101110101000` has the same seven ones and nine runs but `C=7`.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a symmetric monthly direct-WTI structural stream.

Verdict:
`CLEAN_WTI_MONTHLY_20_RETURN_SIGN_LZ76_EXHAUSTIVE_HISTORY_COMPLEXITY_LE6_GATED_12M_CONTINUATION`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_METHOD_AND_TRADING_READ`: one durable
  AI source ID; complete accessible LZ76-definition manuscript; verified
  original IEEE provenance; complete governed peer-reviewed WTI trading-paper
  read; and explicit no-result boundaries.
- R2 `PASS`: month clock, twenty-one endpoints, twenty returns, binary map,
  tie rule, phrase search prefix, last-component rule, component bounds,
  inclusive ceiling, direction, consumed attempt, fixed risk, stop, spread,
  and exits are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state supply every runtime input; roll,
  financing, gaps, and broker-month labels remain risks.
- R4 `PASS`: timestamps, completed prices, logarithms, comparisons, bounded
  strings, substring equality, integer counts, ATR risk, and native execution
  only; no ML, trained output, prohibited runtime feed, random tie breaking,
  grid, martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
decorrelation, or portfolio fitness. Kill on wrong endpoint or return order,
current-month leakage, wrong sign map, accepted tie, wrong exhaustive-history
prefix, wrong phrase boundary, omitted final phrase, word/phrase reconstruction
failure, complexity boundary error, wrong momentum slice or side, repeated
attempt, missing stop, invalid fixed-risk mode, hold beyond forty days, fewer
than five full-year positions, nonpositive governed economics, or
nondeterminism. There is no after-result threshold, horizon, carrier,
direction, stop, spread, hold, or retry rescue.

Authorized scope is one durable card, deterministic allocation, branch-only
non-live build, reference fixtures, strict Q01, and one paced Q02 enqueue while
the governed whole-host CPU ceiling is clear. Excluded: manual backtests;
live, demo, shadow, stress, or optimization presets; terminal control;
AutoTrading; `T_Live`; deploy/live manifests; portfolio admission;
portfolio-gate changes; and correlation waivers.
