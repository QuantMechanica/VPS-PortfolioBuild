---
source_id: SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026
title: XAU/XAG thirteen-month pairwise-rank ratio reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed, exchange, and governed method research
source_type: peer_reviewed_exchange_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-27_xauxag_monthly_mann_kendall_rank_reversion_source_approval.md
parent_source_ids:
  - SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
  - MOP-WTI-RANKTREND-2026
parent_sha256:
  SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026: D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8
  MOP-WTI-RANKTREND-2026: A5AE6AC763357307C55141495985BFDD8359642454B52A83D6FEAE151DAD2EEC
created: 2026-08-27
created_by: Research+Development
cards_extracted:
  - xauxag-mkendall-rv
---

# XAU/XAG Thirteen-Month Pairwise-Rank Reversion Source Packet

## Approved Sources Of Record

The relationship source is Karsten Schweikert (2018), "Are gold and silver
cointegrated? New evidence from quantile cointegrating regressions,"
*Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`. The governed parent packet
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`
also preserves CME Group's official "Gold & Silver Ratio Spread" carrier
research. It records a related but state-dependent gold/silver relation,
shared precious-metal and USD drivers, and different monetary, safe-haven,
industrial, and business-cycle exposure.

The arithmetic parent is
`strategy-seeds/sources/MOP-WTI-RANKTREND-2026/source.md`. Its complete-read
peer-reviewed parent documents monthly own-price continuation in commodity
futures, while the bounded packet fixes the deterministic all-older/newer-
pair score commonly described as a no-tie Mann-Kendall score. Its outright
WTI carrier, continuation direction, and result boundary do not transfer.

Both parent packets were read completely before the durable OWNER source
approval. No new public URL was needed or represented as read.

## Source Findings And Claim Boundary

Schweikert supports testing a state-dependent gold/silver relation without
assuming one permanent equilibrium. CME supports the intermarket-ratio
carrier and gives an economic reason for relative displacements. The rank
packet supplies a completely specified, magnitude-free path-ordering
operator.

These records support a falsifiable paired-metal ratio experiment. They do
not establish that a strong ordinal trend in the ratio will reverse. The
thirteen-month sample, synchronized CFD mapping, no-tie rule, integer
boundary, contrarian sides, equal-notional target, fixed-dollar risk, hard
stops, spread caps, atomic sequence, consumed attempt, and lifecycle are
transparent QM choices.

No source return, alpha, probability, p-value, statistical significance,
density, Sharpe ratio, drawdown, cost, hedge ratio, neutrality, CFD
equivalence, decorrelation, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive, finite, exactly timestamp-matched completed month-end
close pairs, oldest to newest:

```text
r[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i = 0..12
require every r[i] pairwise distinct

S = 0
for every 0 <= i < j <= 12:
    S += +1 if r[j] > r[i] else -1

require exactly 78 comparisons
require -78 <= S <= 78 and S is even

SELL XAU / BUY XAG iff S >= 14
BUY XAU / SELL XAG iff S <= -14
FLAT otherwise
```

This is `tau=S/78` for a strict no-tie permutation. It is an ordinal
dominance gate, not a significance test; no variance estimate or p-value is
calculated at runtime. Magnitude beyond the inclusive boundary never changes
direction or risk. There is no fallback to endpoint displacement, adjacent
signs, Cox-Stuart, Spearman, slope, regression, rolling center or scale,
oscillator, seasonal direction, external series, or prior pipeline result.

The boundary was fixed before market testing. Exact inversion-count dynamic
enumeration across all `13! = 6,227,020,800` no-tie rank paths gives
`2,711,123,108` qualifying paths, split symmetrically. The two-tail rate is
`0.4353804483839206`, or about `5.224565380607047` qualifying months per
twelve random-order decisions. This is a design-density fact used to clear
the unchanged five-per-year Q02 floor, not evidence about gold/silver
behavior or independence.

## Exact Event And Execution Contract

1. Require exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1, and an entry
   attempt within 180 elapsed minutes of the raw current host D1 bar open in
   a genuine new broker month.
2. Persist current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry the month after a
   flat signal, invalid state, reject, stop, partial fill, or restart.
3. Select the latest exactly timestamp-matched close pair in each of the
   immediately prior thirteen consecutive broker months. Require positive
   finite closes, strict chronology, no current-month close, and no more than
   ten calendar days of newest-endpoint staleness.
4. Compute thirteen chronological gold-minus-silver log ratios, reject exact
   ties, enumerate all 78 older/newer comparisons, prove score count/range/
   parity, and fade only inclusive `abs(S)>=14`.
5. Open at most one opposite-side equal-target-absolute-USD-notional package
   under aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally and size each leg against a
   frozen `3.5*ATR(20,D1)` hard stop. Attach no target, cap spreads at 1,500
   XAU points and 500 XAG points, and require no more than 20% realized
   notional mismatch.
6. Submit XAU first and XAG second. Retain only one correctly directed,
   registered, stop-protected position in each slot. Flatten every owned leg
   after any partial or final package-validation failure.
7. Close both legs on the first processed tick in a later broker month or
   after forty calendar days. Immediately repair an orphaned, duplicated,
   same-side, wrong-symbol, wrong-magic, stopless, stale, or notional-invalid
   package.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 histories, timestamps, calendar, quotes, symbol metadata,
ATR, positions, deals, terminal global variables, and V5 services.

## Non-Duplicate Boundary

The fail-closed checker scanned 4,680 registry identities, 1,331 cards, and
45 Strategy Wiki nodes. It found no exact match and surfaced one expected
fuzzy neighbor, `QM5_41174_xauxag-mspearman-rv`. The receipt is
`artifacts/qm5_xauxag_mkendall_rv_preallocation_dedup_20260827.json`, SHA-256
`613D32B36DDA35E438C5F0D24C89265EEBDF27C3927EB622ACB363D3EC3409C9`.

Manual functional review resolves the fuzzy match:

- `QM5_41174` sums squared displacements between ratio ranks and time ranks;
  one far displacement can dominate. This rule gives every older/newer pair
  exactly one sign vote and discards displacement size.
- Rank vector `[9,8,7,2,6,4,1,10,3,12,5,13,11]` gives Spearman `T=118`
  (qualified) but pair score `S=12` (flat here).
- Rank vector `[1,6,13,3,7,4,12,8,10,5,9,2,11]` gives pair score `S=14`
  (qualified here) but Spearman `T=80` (flat there).
- `QM5_20264_wti-rank-trend` and `QM5_20267_xng-rank-trend` use the same
  arithmetic family on one outright energy series and follow its sign. This
  packet builds a synchronized metal ratio, fades the sign, and owns an
  atomic equal-notional two-leg lifecycle.
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  fixed-pair, split-block, change-point, slope, and robust-consensus systems
  calculate different state objects and thresholds.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly paired-metal ordinal basket.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ALL78_PAIR_RANK_S14_CONTRARIAN_BASKET`.

## Reputable-Source Criteria

- R1 `PASS_WITH_STATISTIC_AND_CARRIER_TRANSLATION_RISK`: named-author
  peer-reviewed gold/silver relation evidence, official exchange carrier
  research, and a complete governed pairwise-rank arithmetic packet; exact
  trading conjunction untested.
- R2 `PASS`: clock, synchronization, ratio orientation, all 78 comparisons,
  score invariants, threshold, sides, attempt, aggregate risk, atomicity,
  and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5 state supply all runtime inputs.
- R4 `PASS`: deterministic logarithms, comparison, integer arithmetic,
  calendar, and execution state only; no trained output, banned signal
  method, external feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire on zero trades, fewer than five completed packages in any full post-
warm-up year, nonpositive governed economics, downstream gate failure, or
any synchronization, endpoint, score, threshold, side, attempt, risk,
notional, atomicity, lifecycle, or determinism defect. No failure may be
rescued by changing the sample, score, threshold, direction, risk, hold, or
by adding a filter.

Equal target notionals are market-neutral-style construction, not proof of
market, factor, dollar, beta, volatility, or portfolio neutrality. Q09 alone
owns realized overlap. This packet authorizes no manual backtest; live,
demo, shadow, stress, or optimization setfile; AutoTrading; `T_Live`; deploy
or live manifest; portfolio-gate change; portfolio admission; correlation
waiver; or terminal process control.
