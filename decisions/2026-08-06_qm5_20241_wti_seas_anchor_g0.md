# QM5_20241 WTI Seasonal 52-Week Anchor G0 Authorization

Date: 2026-08-06

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 research card and non-live build for
`QM5_20241_wti-seas-anchor`. On the first processed XTI D1 bar of each broker
month, combine the source-backed WTI physical-season direction with the
source-backed commodity 52-week closing-price anchor:

- buy only in November-May when the newest completed close is at least 94%
  of the trailing 252-D1 closing high and the completed 63-D1 log return is
  at least +2%;
- sell only in June-October when the newest completed close is at most 108%
  of the trailing 252-D1 closing low and the completed 63-D1 log return is at
  most -2%; and
- consume the month without exposure when the calendar and anchor states do
  not agree.

The candidate may proceed through deterministic card lint, EA and magic
allocation, strict compile, one `RISK_FIXED` backtest setfile, and one paced
Q02 enqueue. G0 does not pre-approve efficacy, crude-oil diversification,
decorrelation, certification, execution-contract promotion, or portfolio
admission.

## Source Boundary

The approved source packet is
`strategy-seeds/sources/BURAKOV-BIANCHI-WTI-SEAS52W-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply the November-May positive and
  June-October negative WTI physical-season directions. The official open
  paper was reviewed completely in the governed parent packet.
- Bianchi, Drew, and Fan (2016), *Journal of Banking & Finance*, DOI
  `10.1016/j.jbankfin.2016.06.010`, supply the commodity 52-week high/low
  anchor lineage. The governed parent packet preserves the peer-reviewed
  source and approved WTI price-only translation.

The papers do not test this agreement filter, a continuous CFD, the exact
thresholds as a combined system, fixed package risk, the ATR stop, costs,
financing, or the QM portfolio. Those are transparent QM hypotheses. No
paper coefficient, performance result, trade count, drawdown, or correlation
claim transfers.

## Non-Duplicate Decision

The deterministic checker scanned 4,298 registry rows and 415 canonical cards
and returned `CLEAN` for slug `wti-seas-anchor`, strategy ID
`BURAKOV-BIANCHI-WTI-SEAS52W-2026_S01`, and the complete mechanic. Manual
review separates the candidate from:

- `QM5_12780_wti-52w-anchor`, which trades the anchor year-round without a
  physical-season agreement requirement;
- `QM5_20046_wti-halloween-ls`, which trades the calendar direction without
  any annual-extreme or quarterly-return price state;
- `QM5_20135_wti-winter-trend`, which can buy or sell only in November-May
  from a raw 252-D1 return sign;
- `QM5_20141_wti-sumtrend`, a weekly July-November short with a raw 252-D1
  trend state and Friday exit;
- `QM5_20231_wti-seas-mom12`, which uses one cumulative twelve-calendar-month
  endpoint return rather than annual extreme proximity plus a distinct
  63-D1 threshold;
- sign-breadth, one-month momentum, reversal, weekday, event, oil/gas, and
  gold/silver systems; and
- `QM5_12567_cum-rsi2-commodity`, the incumbent short-horizon XNG oscillator
  pullback.

The fixed two-season map, annual closing-extreme location, separate 63-D1
return threshold, strict agreement, disagreement-flat state, and monthly
package clock are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Allocation And Kill Boundary

- EA ID: `QM5_20241`
- slug: `wti-seas-anchor`
- strategy ID: `BURAKOV-BIANCHI-WTI-SEAS52W-2026_S01`
- slot 0: `XTIUSD.DWX` / magic `202410000`
- cadence: estimated 5-7 completed packages/year after warm-up; Q02 must
  establish the actual count
- retire below five completed packages per full post-warm-up year
- retire on wrong season, wrong anchor window, wrong return interval,
  wrong-side entry, repeat attempts, nonpositive governed economics, or later
  portfolio-correlation rejection
- no post-result direction, threshold, horizon, season, retry, or carrier
  rescue is authorized

## Safety Boundary

This authorization excludes manual backtests; live, demo, and shadow
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; and downstream promotion. Q02 uses exactly
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
