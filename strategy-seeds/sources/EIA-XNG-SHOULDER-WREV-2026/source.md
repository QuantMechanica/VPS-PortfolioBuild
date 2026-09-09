---
source_id: EIA-XNG-SHOULDER-WREV-2026
title: XNG shoulder-season completed-week reversal
publisher: QuantMechanica governed extraction of U.S. Energy Information Administration source
source_type: official_government_source_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_xng_shoulder_weekly_reversal_source_approval.md
parent_source_id: EIA-XNG-SHOULDER-2026
created: 2026-09-09
created_by: Research+Development
cards_extracted:
  - xng-shoulder-wrev
---

# XNG Shoulder-Season Completed-Week Reversal

## Complete-Read Record

The bounded parent packet is
`strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md`. It records the U.S.
Energy Information Administration's official description of recurring winter
heating and summer electric-generation demand peaks, with lower-demand spring
and fall shoulder periods and storage rebuilding outside winter stress. The
packet was read end to end for this extraction.

The public EIA URL was routed through the mandatory trading-source reader on
2026-09-09. The generic adapter returned `PERMISSION_REQUIRED`,
`lead_status=DEFERRED:SOURCE_POLICY`, and `adapter_state=ROUTER_ONLY`, so no new
web text is treated as retrieved evidence. This card relies only on the
already-preserved local packet and makes no claim about unread page content.

## Source Finding And Translation Boundary

The source supplies only the structural seasonal-demand context. It does not
publish a trading rule, weekly reversal result, CFD result, parameter, return,
profit factor, drawdown, correlation, or portfolio claim.

QM tests a transparent price-only translation: during April, May, September,
and October, fade the sign of the immediately completed normalized broker
week. These four months isolate the spring and autumn shoulder regimes while
still supplying roughly seventeen weekly opportunities per year. This exact
calendar/return conjunction is an unproven hypothesis owned by Q02 onward.

## Bounded Mechanization

At the first tradable `XNGUSD.DWX` D1 bar of a new normalized broker week:

1. Require the new week's Monday anchor month to be April, May, September, or
   October.
2. Aggregate exactly the immediately prior adjacent three-to-five-session
   week and compute `r = ln(final_close / first_open)`.
3. Buy when `r < 0`, sell when `r > 0`, and consume exact zero or invalid
   state flat.
4. Persist one attempt before fallible history, news, spread, quote, ATR,
   sizing, or order gates; never retry that week.
5. Hold only within the entry week, with ten elapsed days as stale repair.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

`QM5_12567` is a short-horizon cumulative-RSI pullback with a slow trend
filter. `QM5_13102` fades a five-D1 move only in an all-year elevated realized-
volatility regime and uses neutral-return/time exits. Existing shoulder-season
XNG systems are directional calendar/trend, failed-rally, or breakout rules.
No existing identity combines the four fixed shoulder months with the exact
immediately completed normalized-week open-to-close sign, contrarian side,
and one-week lifecycle.

## Runtime And Falsification

Runtime uses only configured-symbol D1 OHLC, broker calendar, quotes, spread,
ATR, symbol metadata, positions, deals, and terminal-global attempt state. It
does not read EIA data, storage reports, weather, power load, futures curves,
files, APIs, portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, wrong weekly package,
same-week retry, missing stop, wrong exit, nonpositive governed economics, or
nondeterminism.
