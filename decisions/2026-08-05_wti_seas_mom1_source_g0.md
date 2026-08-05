# WTI Physical-Season / One-Month Momentum G0 Authorization

Date: 2026-08-05

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch.

## Decision

Approve source packet `BURAKOV-MOP-WTI-SEASMOM1-2026` and authorize extraction
of exactly one V5 Strategy Card for `wti-seas-mom1`. The candidate may proceed
through the deterministic EA-ID allocator, card lint, magic allocation,
strict non-live build, one `RISK_FIXED` backtest setfile, and one paced Q02
enqueue.

The rule buys WTI in November-May only after a strictly positive immediately
completed broker-calendar-month return, and sells WTI in June-October only
after a strictly negative immediately completed month. Seasonal/momentum
disagreement consumes the month and remains flat. The prior package closes at
the next broker-month boundary.

This G0 approval does not pre-approve profitability, frequency, decorrelation,
certification, execution-contract promotion, or portfolio admission. The EA
ID must be assigned only by the atomic registry allocator after this decision;
no number is reserved by this document.

## Source Boundary

The governed packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-SEASMOM1-2026/source.md`. Its complete-
read parents are:

- Burakov, Freidin, and Solovyev (2018), "The Halloween Effect on Energy
  Markets: An Empirical Study," *International Journal of Energy Economics
  and Policy* 8(2), 121-126; and
- Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
  Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`.

The first supplies the positive November-May and negative June-October WTI
physical-season directions. The second supplies the exact one-month own-
return sign family and one-month hold. Neither tests this agreement rule, a
WTI CFD, fixed-risk ATR execution, transaction costs, or the QM book. No
source performance statistic transfers.

## Non-Duplicate Decision

The deterministic checker found no exact identity and one expected fuzzy
match to `QM5_20226_wti-seas-dow` because both mechanics begin with a fixed
WTI physical-season agreement label. Manual review resolves it: `QM5_20226`
uses a signed weekday event and one-session hold, whereas this candidate uses
the exact immediately completed month return and a month-to-month hold.

The other nearest builds are also mechanically distinct:

- unconditional seasonal builds have no price agreement gate;
- year-round one-month momentum has no fixed physical-season direction;
- winter/summer one-month momentum builds may trade against their seasonal
  direction and cover disjoint windows;
- `QM5_20222` uses twelve-return sign breadth rather than one exact completed
  month; and
- `QM5_12567` is a cumulative-RSI pullback.

The exact completed-month sign, fixed winter/summer direction, agreement-only
entry, disagreement-flat state, and monthly lifecycle are load-bearing.

## Frozen Contract And Kill Boundary

- carrier: `XTIUSD.DWX`, D1, slot 0;
- decision: first tradable D1 bar of each broker month;
- momentum endpoint: two consecutive completed month-end closes;
- winter direction: BUY November-May after a positive completed month;
- summer direction: SELL June-October after a negative completed month;
- equality, malformed history, or disagreement: flat after consuming the
  monthly attempt;
- exit: next broker-month boundary or forty-calendar-day stale guard;
- hard stop: frozen `3.5 * ATR(20,D1)`, no target;
- spread ceiling: 1,500 points;
- backtest risk: exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`; and
- expected cadence: five to seven packages/year; retire below five/year.

No parameter sweep, horizon substitution, unconditional fallback, season
shift, sign reversal, intramonth retry, or post-result rescue is authorized.

## Safety Boundary

This authorization excludes manual backtests; live, demo, and shadow
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; correlation waivers; and downstream
promotion. Q02 remains the first performance gate.
