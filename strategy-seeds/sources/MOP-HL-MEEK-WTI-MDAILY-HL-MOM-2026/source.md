---
source_id: MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026
title: WTI completed-month daily-return Hodges-Lehmann momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-24_wti_monthly_daily_hodges_lehmann_momentum_source_approval.md
parent_source_ids:
  - MOP-WTI-HLRET-2026
  - MOP-MEEK-WTI-MDAILY-MED-2026
parent_sha256:
  MOP-WTI-HLRET-2026: E0E6CF16F7A4656B7613702C39C19657653424819EFB61EE1CEBD9CC46403D8C
  MOP-MEEK-WTI-MDAILY-MED-2026: 5A8D292F78176BE727885DD95A1FF31C027ED15CE28B32C242567772D33FDD21
created: 2026-08-24
created_by: Research+Development
cards_extracted:
  - wti-mdaily-hl-mom
---

# WTI Completed-Month Daily-Return Hodges-Lehmann Momentum Source Packet

## Approved Source Of Record

The primary trading source is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse
Heje Pedersen (2012), "Time Series Momentum," *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The governed packet `strategy-seeds/sources/MOP-TSMOM-2012/source.md` records
a complete read of the 23-page published paper retrieved from author Lasse
Heje Pedersen's NYU faculty site. Its receipt records the canonical URL,
976,459 bytes, 23 pages, and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The daily-return carrier source is Heather Meek and Susan A. Hoelscher
(2023), "Day-of-the-week effect: Petroleum and petroleum products," *Cogent
Economics & Finance* 11(1), DOI `10.1080/23322039.2023.2213876`. The governed
packet `strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md` records
a complete review of the 21-page open-access copy, including methods, tables,
limitations, and references.

The arithmetic precedent is the approved governed packet
`strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md`. It fixes inclusive
self/cross-pair averages, exact pair counts, ascending sort, and central
odd/even handling for a Hodges-Lehmann-style return-location estimator. Its
twelve-month formation horizon does not transfer.

The completed-month daily sampling precedent is the approved packet
`strategy-seeds/sources/MOP-MEEK-WTI-MDAILY-MED-2026/source.md`. It fixes the
uniform energy-label convention, immediately completed 17-23-session month,
adjacent older boundary, chronological daily log returns, endpoint identity,
and monthly lifecycle. Its ordinary raw-return median does not transfer.

All parent records and the momentum retrieval receipt were read completely
before source approval. Their exact hashes and durable OWNER authorization are
fixed in
`decisions/2026-08-24_wti_monthly_daily_hodges_lehmann_momentum_source_approval.md`,
committed before this extraction at `fd8b238d4`. No new public route, blocked
page, inaccessible table, inferred coefficient, secondary performance
summary, or unrecorded result is used.

## Source Findings Used

Moskowitz, Ooi, and Pedersen:

- test each instrument's own return at monthly lags one through sixty and
  report positive continuation over the first twelve monthly lags;
- form deterministic time-series-momentum positions from own past returns and
  renew them monthly;
- report a pooled commodity `k=1`, `h=1` implementation; and
- explicitly include NYMEX WTI crude in the commodity universe.

Meek and Hoelscher:

- study WTI and four other energy futures using close-to-close log returns;
- preserve the ending session's daily label for each return; and
- document heterogeneous WTI daily behavior across weekday coefficients.

Those findings support testing an own-price WTI monthly continuation carrier
while representing the immediately completed month through its typical daily
move rather than only its endpoint or one/two central observations. They do
not establish the exact daily-return pseudomedian, a WTI-only next-month
result, or a Darwinex CFD implementation. The papers use rolling futures,
different formation statistics, and, in the weekday paper,
conditional-variance models. No such model runs in this extraction.

The continuous CFD, broker-month normalization, 17-23-session package,
dynamic inclusive pair set, pseudomedian, fixed cash risk, ATR stop, spread
cap, and restart ledger are QM translations. No source alpha, return,
probability, density, Sharpe ratio, drawdown, cost, WTI-only efficacy, CFD
equivalence, neutrality, or portfolio-correlation statistic transfers.

## Bounded QM Mechanization

On the first executable `XTIUSD.DWX` D1 bar of a new uniformly normalized
broker month, reconstruct every completed D1 close whose normalized timestamp
belongs to the immediately preceding calendar month plus one adjacent older
close. Require 17 through 23 completed-month sessions.

Starting from the older boundary, form one chronological close-to-close log
return ending on every completed-month session. Enumerate every inclusive
pairwise average and compute the exact odd/even median:

```text
r[j] = ln(close[j] / close[j-1]), j = 0..n-1

k = 0
for i = 0..n-1:
  for j = i..n-1:
    w[k] = (r[i] + r[j]) / 2
    k += 1

m = n * (n + 1) / 2
require k == m
sorted = ascending(w[0], ..., w[m-1])

if m is odd:
  hl = sorted[floor(m/2)]
else:
  hl = (sorted[m/2 - 1] + sorted[m/2]) / 2

hl > 0 => BUY XTIUSD.DWX
hl < 0 => SELL XTIUSD.DWX
otherwise => FLAT
```

For 17 through 23 sessions, the exact pair count ranges from 153 through 276.
Every observed return contributes one self-pair, and every unordered
cross-pair contributes exactly once. Require positive finite closes, finite
returns and pairwise averages, exact pair counts, ascending order, and a
finite central value.

Verify that the sum of chronological returns equals the direct older-boundary
to final-close log return within `1e-10`. The raw endpoint is diagnostic only.
It may agree or disagree with the pseudomedian and never gates direction. A
zero pseudomedian or invalid state consumes the month flat. Neither magnitude
changes risk.

## Exact Event Contract

1. Require exact `XTIUSD.DWX`, D1, and entry no later than 180 elapsed minutes
   after the raw first host D1 bar open of a new normalized broker month.
2. Choose one energy-label convention for current and historical bars. Permit
   raw broker date or a uniform `+1` calendar-day correction only. Reject
   mixed, colliding, or other offset state.
3. Within a fixed 45-bar buffer, require the newest completed bar to belong to
   the immediately prior month, 17-23 unique completed-month bars in strict
   reverse-time order, and one adjacent older boundary bar. Exclude every
   current-month close.
4. Reverse closes into chronological order and form every log return ending
   in the completed month exactly once. Verify endpoint identity within
   `1e-10`.
5. Enumerate every inclusive `(i,j)` pair in nested ascending order with
   `0 <= i <= j < n`. Require exactly `n*(n+1)/2` averages and explicit
   self-pair identity `w(i,i)=r[i]` within numerical tolerance.
6. Sort all averages ascending without rounding. Use one central element for
   odd pair count or the mean of the two central elements for even pair count.
   Follow the strict pseudomedian sign; equality and invalid state stay flat.
7. Persist current normalized decision `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order submission. No outcome retries
   the month.
8. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry
   spread ceiling.
9. Close on the first tick in a later normalized broker month, with a
   forty-calendar-day stale repair. Flatten malformed, duplicated,
   wrong-symbol, wrong-magic, or stopless owned exposure immediately.

Both news axes and Friday close are OFF. Runtime uses registered MT5 history,
calendar, quotes, symbol metadata, ATR, position/deal state, and persistent
terminal state only.

## Non-Duplicate Boundary

The fail-closed canonical checker scanned 4,638 registry identities, 1,306
cards, and 45 Strategy Wiki nodes using the actual Company Reference root. It
found no exact identity and surfaced only
`QM5_41133_wti-mdaily-median-mom` as a fuzzy neighbor. Evidence is
`artifacts/qm5_wti_mdaily_hl_mom_preallocation_dedup_20260824.json`.

Manual semantic review fixes a new mechanic:

- `QM5_41133` uses only the one/two raw center observations. This extraction
  retains every raw return, creates 153-276 inclusive pairwise averages, and
  uses the exact median of that derived distribution.
- `QM5_41134_wti-mdaily-iqrmean-mom` removes both raw tails and averages only
  the retained center half. This extraction removes no observation and uses a
  different pairwise-average location functional.
- `QM5_20276_wti-hl-mom` uses the same arithmetic family on twelve disjoint
  monthly WTI returns spanning a year. This extraction uses 17-23 daily
  returns inside one immediately completed month.
- `QM5_41138_xauxag-mdaily-hl-rv` uses synchronized intermetal relative
  returns, fades the pseudomedian, and owns a two-leg package. This extraction
  uses outright WTI returns, follows the pseudomedian, and owns one energy
  position.
- endpoint momentum, sign breadth, trimmed return sums, weekday buckets,
  persistence, path, RMS, and sequence cards do not enumerate inclusive
  pairwise return averages.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback.

The carrier, immediately completed month, older boundary, every daily return,
inclusive pair enumeration, dynamic pair count, exact pseudomedian,
continuation direction, consumed month, fixed risk, and next-month lifecycle
are jointly load bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_WITHIN_MONTH_PSEUDOMEDIAN_TRANSLATION_RISK`. The lineage
  preserves a named-author peer-reviewed JFE momentum paper with DOI,
  complete-read receipt, durable PDF hash, and explicit WTI membership plus a
  named-author peer-reviewed open-access WTI daily-return paper. The exact
  daily pseudomedian is explicitly untested.
- R2: `PASS`. Clock, labels, month, boundary, observations, returns, endpoint
  identity, inclusive pair bounds, pair count, self-pairs, sort, odd/even
  median, direction, attempt, risk, stop, spread, and lifecycle are fixed.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history and MT5-native state supply every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, arithmetic, sorting,
  comparison, ATR, and execution state only; no conditional-variance model,
  trained output, banned signal, external feed, grid, martingale, scale-in,
  or pyramid.

## Claim And Kill Boundary

Every valid nonzero pseudomedian may qualify, giving a pre-result density prior
near twelve positions per year. This is not market evidence. Q02 must retire
below five completed positions in any full post-warm-up year, at zero trades,
with nonpositive governed economics, or on any label, month, return, pair,
median, side, attempt, risk, lifecycle, or determinism defect.

Direct WTI exposure is economically different from the certified XAU,
SP500, NDX, and XNG carriers but does not prove decorrelation. Q09 alone owns
the realized portfolio result. No failure may be rescued by changing the
sample, pair convention, estimator, direction, carrier, risk, hold, or by
adding endpoint agreement, fitted center or scale, weekday, seasonal, event,
volatility, external, or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, one branch-only V5 build, strict
compile/Q01, and one paced non-live Q02 handoff only. It does not authorize a
manual backtest, live artifact, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
control, or decorrelation claim.
