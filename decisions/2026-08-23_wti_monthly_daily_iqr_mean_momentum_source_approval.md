# WTI completed-month daily-return interquartile-mean momentum - Source Approval

Date: 2026-08-23

Decision: `APPROVED_SOURCE`

## Authority and scope

The OWNER commodity/energy portfolio instruction delivered to Codex on branch
`agents/board-advisor` authorizes one new structural, low-frequency commodity
edge, explicitly including a WTI trend or seasonality carrier. It requires a
reputable-source record, a `RISK_FIXED` backtest setfile, committed
non-duplicate work, and one paced Q02 enqueue. It forbids `T_Live`,
AutoTrading, portfolio-gate, and T_Live-manifest changes.

This decision approves bounded source intake for:

- proposed source ID: `MOP-MEEK-WTI-MDAILY-IQRMEAN-2026`
- proposed strategy ID: `MOP-MEEK-WTI-MDAILY-IQRMEAN-2026_S01`
- proposed slug: `wti-mdaily-iqrmean-mom`
- instrument: `XTIUSD.DWX`
- decision period: D1, evaluated once on the first executable bar of a new
  normalized broker-calendar month

This is source approval only. It permits one bounded source packet and one
Strategy Card for G0 consideration. It does not itself approve an EA build,
backtest result, portfolio admission, or live use.

## Complete governed source set read

The following bounded records were read completely before this approval:

| Source record | Role | SHA-256 |
|---|---|---|
| `strategy-seeds/sources/MOP-TSMOM-2012/source.md` | Peer-reviewed own-price monthly momentum evidence; WTI is explicitly in the commodity universe | `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042` |
| `strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md` | Peer-reviewed complete-read evidence for close-to-close daily WTI log returns and heterogeneous daily behavior | `0C6BBF1285C7C196F4D04FEB2254A62D9A9D89EDCA9E4DBBAC3D003EB3E88FDE` |
| `strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` | Reproducible receipt for the 23-page author-hosted published paper | `ECBCC76CC878F0CC6FBF8C40B23D72084EC6ED03C6375438E3232CC24A33D38F` |

The primary source is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete author-hosted PDF receipt records
976,459 bytes, 23 pages, and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The paper tests each instrument's own past return, reports positive
continuation at monthly lags through twelve, reports a pooled commodity
`k=1,h=1` implementation, and explicitly includes NYMEX WTI crude.

The secondary source is Meek and Hoelscher (2023), "Day-of-the-week effect:
Petroleum and petroleum products," *Cogent Economics & Finance* 11(1), DOI
`10.1080/23322039.2023.2213876`. Its complete 21-page open-access copy was
reviewed in the governed packet. The paper constructs close-to-close log
returns for WTI and documents heterogeneous daily behavior.

Neither source tests a WTI-only central-half mean of the daily returns inside
one completed month. The primary paper supports own-price monthly
continuation; the secondary paper supplies direct WTI daily-return and
ending-session lineage. The interquartile trim, continuous CFD carrier,
broker-month labels, fixed-dollar risk, ATR stop, spread ceiling, restart
ledger, and one-month lifecycle are transparent QM translations.

No source alpha, return, probability, density, profit factor, drawdown, trade
count, cost, WTI-only efficacy, CFD equivalence, or portfolio-correlation
result transfers.

## Approved deterministic extraction

On the first executable `XTIUSD.DWX` D1 bar of a new normalized broker month:

1. Select every completed D1 session whose uniformly normalized timestamp is
   in the immediately preceding calendar month, plus exactly one adjacent
   older boundary close. Exclude all current-month bars.
2. Require 17 through 23 completed-month sessions, strict reverse-time
   chronology in the source series, unique timestamps, positive finite
   closes, and an adjacent older boundary.
3. Reverse the selected closes into chronological order. Form exactly one log
   return ending on each completed-month session. Verify that the sum of all
   daily returns equals the direct boundary-to-final log return within
   `1e-10`.
4. Sort all `n` finite daily returns ascending without rounding. Define
   `trim_each_tail = floor(n/4)`, require the retained indexes
   `[trim_each_tail, n-trim_each_tail-1]`, and average every retained return
   exactly once. For the allowed 17-23 sessions this removes 4 or 5 returns
   from each tail and retains 9-13 central observations.
5. BUY when the central-half mean is strictly positive, SELL when it is
   strictly negative, and consume the month flat when it is exactly zero or
   any state is invalid. The raw endpoint return is an identity check and
   diagnostic only; it may agree or disagree. Neither statistic scales risk.
6. Persist the normalized decision `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order submission. No failure, stop,
   rejection, or restart may retry the month.
7. Permit at most one owned WTI position. Use `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry-spread
   ceiling.
8. Close on the first tick carrying a later normalized broker month, with a
   forty-calendar-day stale repair. Flatten malformed, duplicated,
   wrong-symbol, wrong-magic, or stopless owned exposure immediately.

News filtering and Friday close are OFF because the hypothesis uses only
native completed prices and owns a full monthly package. No oscillator,
moving average, fitted threshold, trained output, external feed, grid,
martingale, scale-in, pyramid, trailing stop, break-even move, partial close,
or opposite-signal exit is permitted.

## Reputable-source criteria

- R1: `PASS_WITH_WITHIN_MONTH_IQR_MEAN_TRANSLATION_RISK`. A named-author,
  peer-reviewed JFE momentum paper with DOI, complete-read receipt, durable
  PDF hash, and explicit WTI membership is joined to a named-author,
  peer-reviewed open-access WTI daily-return paper with a complete-read
  record. The exact central-half estimator is explicitly untested.
- R2: `PASS`. Month selection, older boundary, observation limits, return
  endpoints, identity tolerance, ascending sort, `floor(n/4)` tail count,
  retained indexes, arithmetic mean, direction, zero handling, attempt,
  risk, stop, spread, and lifecycle are fixed before any candidate result.
- R3: `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history and native MT5 calendar/execution state supply every
  runtime input; Q02 must validate the local route and labels.
- R4: `PASS`. Deterministic timestamps, logarithms, addition, integer
  division, sorting, comparison, ATR, and execution state only; no trained
  output, prohibited signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-duplicate boundary

The canonical pre-allocation check is
`artifacts/qm5_wti_mdaily_iqrmean_mom_preallocation_dedup_20260823.json`. It
returned `CLEAN` across 4,633 registry identities, 1,301 cards, and 45
Strategy Wiki nodes, with no exact or fuzzy match.

Manual mechanic review separates the nearest families:

- `QM5_20187_wti-tsmom1m` follows the unpartitioned completed-month endpoint.
- `QM5_20270_wti-trimmean-mom` sorts twelve disjoint completed *monthly*
  returns spanning a year and deletes exactly two per tail. This extraction
  sorts all 17-23 daily returns inside one immediately completed month and
  removes the dynamic outer quartiles.
- `QM5_41111_wti-mdaybreadth-mom` counts positive versus negative daily
  returns and additionally requires raw endpoint agreement. This extraction
  retains central magnitudes, has no sign count, and has no endpoint gate.
- `QM5_41127_wti-mdaily-persist-mom` estimates adjacent demeaned-return
  persistence and follows the endpoint. This extraction discards adjacency
  after reconstruction and follows a central order-statistic average.
- `QM5_41131_wti-mdaily-tailtrim-mom` deletes exactly one minimum and one
  maximum and sums the other 15-21 daily returns. This extraction removes
  four or five values per tail and averages only the central 9-13 returns;
  the retained membership and possible direction are materially different.
- `QM5_41132_wti-mweekday-med-mom` groups returns by ending weekday before
  taking a median of five bucket means. This extraction has no weekday state.
- `QM5_41133_wti-mdaily-median-mom` uses only the one or two exact central
  observations. This extraction averages a 9-13-observation central band.
- `QM5_20276`, `QM5_20277`, `QM5_20282`, `QM5_20283`, `QM5_20285`, and
  `QM5_20286` apply pseudomedian, Winsor, MAD cap, trimean, Huber, or bisquare
  transforms to twelve monthly returns rather than one month's daily sample.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG
  oscillator pullback above a slow trend filter.

The exact WTI carrier, immediately completed month, older boundary, every
daily return ending in the month, ascending sort, dynamic integer-quartile
tail removal, central-band arithmetic mean, symmetric continuation, consumed
month, fixed risk, and next-month exit are jointly load bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_INTERQUARTILE_MEAN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Claim, kill, and safety boundary

Every valid nonzero central-half mean can qualify, so the pre-result density
prior is near twelve decisions per year. This is not market evidence. Q02
must retire the candidate below five completed positions in any full
post-warm-up year, at zero trades, with nonpositive governed economics, or on
any label, month, return, trim, mean, side, attempt, risk, lifecycle, or
determinism defect.

Direct WTI exposure is economically different from the certified XAU,
SP500, NDX, and XNG carriers but does not prove decorrelation. Q09 alone owns
the realized portfolio result. No failure may be rescued by changing the
sample, quartile rule, direction, carrier, risk, hold, or by adding endpoint
agreement, weekday, seasonal, event, volatility, external, or prior-result
state.

This approval authorizes one bounded source packet and one Strategy Card for
G0 consideration. It does not authorize a manual backtest, live/demo/shadow/
stress/optimization setfile, `T_Live`, AutoTrading, deploy manifest,
portfolio-gate change, portfolio admission, correlation waiver, terminal
start/stop, or a second queue row.
