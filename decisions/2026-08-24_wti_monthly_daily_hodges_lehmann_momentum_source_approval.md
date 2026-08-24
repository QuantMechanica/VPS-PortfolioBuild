# WTI completed-month daily Hodges-Lehmann momentum - Source Approval

Date: 2026-08-24

Decision: `APPROVED_SOURCE`

## Authority and scope

The current explicit OWNER commodity/energy portfolio instruction delivered to
Codex on branch `agents/board-advisor` authorizes one new structural,
low-frequency commodity edge, explicitly including a WTI trend carrier. It
requires reputable-source criteria, a `RISK_FIXED` backtest setfile, committed
non-duplicate work, and one paced Q02 enqueue. It forbids `T_Live`,
AutoTrading, portfolio-gate, and T_Live-manifest changes.

This decision approves bounded source intake for:

- proposed source ID: `MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026`;
- proposed strategy ID: `MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026_S01`;
- proposed slug: `wti-mdaily-hl-mom`;
- instrument: `XTIUSD.DWX`;
- decision period: D1, evaluated once on the first executable bar of a new
  uniformly normalized broker-calendar month.

This is source approval only. It permits extraction of one Strategy Card for
G0 consideration; it does not itself approve a build, backtest result,
portfolio admission, decorrelation claim, or live use.

## Complete governed source set read

The following bounded records were read completely before this approval:

| Source record | Role | SHA-256 |
|---|---|---|
| `strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md` | Approved exact inclusive-pair arithmetic and odd/even pseudomedian precedent on WTI monthly returns | `E0E6CF16F7A4656B7613702C39C19657653424819EFB61EE1CEBD9CC46403D8C` |
| `strategy-seeds/sources/MOP-MEEK-WTI-MDAILY-MED-2026/source.md` | Approved completed-month daily WTI return selection, labeling, endpoint identity, and monthly lifecycle precedent | `5A8D292F78176BE727885DD95A1FF31C027ED15CE28B32C242567772D33FDD21` |
| `strategy-seeds/sources/MOP-TSMOM-2012/source.md` | Peer-reviewed own-price monthly momentum evidence with explicit WTI membership | `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042` |
| `strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md` | Peer-reviewed complete-read evidence for close-to-close daily WTI log returns and heterogeneous daily behavior | `0C6BBF1285C7C196F4D04FEB2254A62D9A9D89EDCA9E4DBBAC3D003EB3E88FDE` |
| `strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` | Reproducible receipt for the 23-page author-hosted published paper | `ECBCC76CC878F0CC6FBF8C40B23D72084EC6ED03C6375438E3232CC24A33D38F` |

The primary trading source is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse
Heje Pedersen (2012), "Time Series Momentum," *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete
author-hosted PDF receipt records 976,459 bytes, 23 pages, and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The paper tests each instrument's own past return, reports positive
continuation through the first twelve monthly lags, reports a pooled commodity
`k=1,h=1` implementation, and explicitly includes NYMEX WTI crude.

The daily-return carrier source is Heather Meek and Susan A. Hoelscher (2023),
"Day-of-the-week effect: Petroleum and petroleum products," *Cogent Economics
& Finance* 11(1), DOI `10.1080/23322039.2023.2213876`. Its complete 21-page
open-access copy was reviewed in the governed packet. The paper constructs
close-to-close log returns for WTI and documents heterogeneous daily behavior.

The approved `MOP-WTI-HLRET-2026` packet fixes inclusive self/cross-pair
averages, exact pair counts, ascending sort, and central odd/even handling for
a Hodges-Lehmann-style return-location estimator. Its twelve-month formation
window does not transfer. The approved `MOP-MEEK-WTI-MDAILY-MED-2026` packet
fixes the immediately completed 17-23-session broker month, older boundary
close, return orientation, endpoint identity, and uniform energy-label
contract. Its ordinary raw-return median does not transfer.

No source tests the exact pseudomedian of every daily return inside one
completed WTI month. The within-month estimator, continuous CFD carrier,
broker-month normalization, fixed-dollar risk, ATR stop, spread ceiling,
restart ledger, and one-month lifecycle are transparent QM translations. No
source alpha, return, probability, density, profit factor, drawdown, trade
count, cost, WTI-only efficacy, CFD equivalence, neutrality, or
portfolio-correlation result transfers.

No new public route is needed or used; this approval depends only on the
complete, already approved, hash-bound repository records above.

## Approved deterministic extraction

On the first executable `XTIUSD.DWX` D1 bar of a new uniformly normalized
broker month:

1. Select every completed D1 session whose uniformly normalized timestamp is
   in the immediately preceding calendar month, plus exactly one adjacent
   older boundary close. Exclude all current-month bars.
2. Require 17 through 23 completed-month sessions, strict reverse-time
   chronology in the source series, unique timestamps, positive finite
   closes, and the adjacent older boundary.
3. Reverse the selected closes into chronological order. Form exactly one
   close-to-close log return ending on every completed-month session. Verify
   that the sum of all daily returns equals the direct boundary-to-final log
   return within `1e-10`.
4. For every inclusive pair `(i,j)` satisfying `0 <= i <= j < n`, form
   `w[k]=(r[i]+r[j])/2`. Require exactly `m=n*(n+1)/2` values, including every
   self-pair `w(i,i)=r[i]`. For `17 <= n <= 23`, require `153 <= m <= 276`.
5. Sort all pairwise averages ascending without rounding. If `m` is odd, use
   `sorted[m/2]`. If `m` is even, use
   `(sorted[m/2-1]+sorted[m/2])/2`. Reject any invalid count, index, self-pair,
   nonfinite value, or ordering defect.
6. BUY when the pseudomedian is strictly positive, SELL when it is strictly
   negative, and consume the month flat when it is exactly zero or any state
   is invalid. The raw month endpoint is an identity diagnostic only; it may
   agree or disagree with the pseudomedian. Neither magnitude scales risk.
7. Persist the normalized decision `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order submission. No failure, stop,
   rejection, or restart may retry the month.
8. Permit at most one owned WTI position. Use `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry-spread
   ceiling.
9. Close on the first tick carrying a later normalized broker month, with a
   forty-calendar-day stale repair. Flatten malformed, duplicated,
   wrong-symbol, wrong-magic, or stopless owned exposure immediately.

News filtering and Friday close are OFF because the hypothesis uses native
completed prices and owns a full monthly package. No oscillator, moving
average, regression, fitted threshold, trained output, external feed, grid,
martingale, scale-in, pyramid, trailing stop, break-even move, partial close,
or opposite-signal exit is permitted.

## Reputable-source criteria

- R1: `PASS_WITH_WITHIN_MONTH_PSEUDOMEDIAN_TRANSLATION_RISK`. A named-author,
  peer-reviewed JFE momentum paper with DOI, complete-read receipt, durable
  PDF hash, and explicit WTI membership is joined to a named-author,
  peer-reviewed open-access WTI daily-return paper with a complete-read
  record. The exact within-month pseudomedian rule is explicitly untested.
- R2: `PASS`. Month selection, older boundary, observation limits, return
  endpoints, identity tolerance, inclusive pair enumeration, dynamic pair
  count, self-pair identity, ascending sort, odd/even center formula,
  direction, zero handling, attempt, risk, stop, spread, and lifecycle are
  fixed before any candidate result.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history and native MT5 calendar/execution state supply every
  runtime input; Q02 must validate the local route and labels.
- R4: `PASS`. Deterministic timestamps, logarithms, addition, division,
  sorting, comparison, ATR, and execution state only; no trained output,
  prohibited signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-duplicate boundary

The canonical pre-allocation check is
`artifacts/qm5_wti_mdaily_hl_mom_preallocation_dedup_20260824.json`. It
authenticated and scanned 4,638 registry identities, 1,306 cards, and 45
Strategy Wiki nodes. It found no exact identity and surfaced one expected
fuzzy neighbor, `QM5_41133_wti-mdaily-median-mom`, for manual review.

Manual mechanic review returns `CLEAN / ROBUST-LOCATION FAMILY SIBLING`:

- `QM5_41133` sorts the 17-23 observed daily returns and uses only the one
  central raw return or the average of the two central raw returns. This
  extraction retains every return both alone and in every unordered
  cross-pair, creates 153-276 derived averages, and takes the exact median of
  that derived distribution.
- `QM5_41134_wti-mdaily-iqrmean-mom` removes `floor(n/4)` raw observations per
  tail and averages the retained 9-13 returns. This extraction removes no raw
  observation and estimates a different pairwise-average location functional.
- `QM5_20276_wti-hl-mom` uses the same arithmetic family on exactly twelve
  disjoint monthly WTI returns spanning a year. This extraction uses all daily
  returns inside only the immediately completed month and therefore has a
  different state, formation horizon, dynamic pair count, and warm-up.
- `QM5_41138_xauxag-mdaily-hl-rv` applies the dynamic arithmetic to
  synchronized gold-minus-silver daily relative returns, fades its sign, and
  owns an atomic two-leg package. This extraction applies it to outright WTI
  daily returns, follows the sign, and owns one energy position.
- `QM5_20187_wti-tsmom1m` follows only the unpartitioned completed-month
  endpoint. `QM5_41111_wti-mdaybreadth-mom` counts return signs and also
  requires endpoint agreement. Neither enumerates pairwise return averages.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback above a slow trend filter; it shares neither carrier,
  state, direction symmetry, nor lifecycle.

The exact WTI carrier, immediately completed month, older boundary, every
daily return ending in the month, inclusive self/cross-pair enumeration,
dynamic 153-276 count, exact odd/even pseudomedian, symmetric continuation,
consumed month, fixed risk, and next-month exit are jointly load bearing.
Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Claim, kill, and safety boundary

Every valid nonzero pseudomedian can qualify, so the pre-result density prior
is near twelve decisions per year. This is not market evidence. Q02 must
retire the candidate below five completed positions in any full post-warm-up
year, at zero trades, with nonpositive governed economics, or on any label,
month, return, pair, sort, median, side, attempt, risk, lifecycle, or
determinism defect.

Direct WTI exposure is economically different from the certified XAU,
SP500, NDX, and XNG carriers but does not prove decorrelation. Q09 alone owns
the realized portfolio result. No failure may be rescued by changing the
sample, pair convention, estimator, direction, carrier, risk, hold, or by
adding endpoint agreement, weekday, seasonal, event, volatility, external,
or prior-result state.

This approval authorizes one bounded source packet and one Strategy Card for
G0 consideration. It does not authorize a manual backtest, live/demo/shadow/
stress/optimization setfile, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
start/stop, or a second queue row.
