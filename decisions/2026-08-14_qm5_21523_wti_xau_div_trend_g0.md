# QM5_21523 WTI/Gold Divergence Trend — G0 Decision

Date: 2026-08-14

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 handoff if
the factory CPU ceiling permits.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch and durably recorded before allocation in
`decisions/2026-08-14_wti_xau_div_trend_source_approval.md` at commit
`681cbf483`.

## Candidate

- EA: `QM5_21523_wti-xau-div-tr`
- Strategy ID: `MOP-CME-WTI-XAU-DIV-2026_S01`
- Source ID: `MOP-CME-WTI-XAU-DIV-2026`
- traded symbol/slot/magic: `XTIUSD.DWX` / 0 / `215230000`
- read-only state symbol: `XAUUSD.DWX`
- driver: exact twelve-completed-month WTI return-sign trend admitted only
  when gold's synchronized twelve-month return has the strict opposite sign
- lifecycle: one consumed monthly attempt, frozen `3.5 * ATR(20,D1)` hard
  stop, monthly renewal, forty-day stale guard, and 1,500-point spread cap

## Source Decision

The approved composite packet is
`strategy-seeds/sources/MOP-CME-WTI-XAU-DIV-2026/source.md`. It is bound to:

- the complete governed read of Moskowitz, Ooi, and Pedersen (2012), *Journal
  of Financial Economics* 104(2), 228-250, for the twelve-month own-return
  sign, monthly cadence, and explicit WTI membership; and
- the governed CME Group (2024) oil-through-gold packet for the structural
  distinction between energy and monetary/safe-haven commodity exposure.

Fresh retrieval of the CME public page was classified
`DEFERRED:SOURCE_POLICY` by the mandatory router. No new page content is used;
the durable pre-existing source packet and exact router receipt are retained.

Neither source tests the exact opposite-sign conjunction, synchronized CFD
month endpoints, WTI-only execution, fixed-dollar sizing, hard stop, spread
ceiling, or QM book. No source return, significance, drawdown, density, cost,
CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

At the first processed WTI D1 bar after each genuine broker-month transition:

1. Run lifecycle repair and close prior-month owned exposure before entry-only
   gates. Persist the new broker month as attempted before all fallible gates.
2. Intersect bounded completed WTI and gold D1 histories by exact timestamp.
   Derive exactly thirteen consecutive common broker-month endpoints ending
   in the immediately completed month.
3. Require positive finite closes, exact chronology, consecutive broker
   months, and a newest common endpoint no more than ten calendar days stale.
4. Calculate exact twelve-month log returns for WTI and gold. For each series,
   require the endpoint return to equal the sum of the twelve component
   monthly log returns within `1e-10`.
5. Buy WTI only when its return is greater than `1e-12` and gold's is less
   than `-1e-12`. Sell WTI only when its return is less than `-1e-12` and
   gold's is greater than `1e-12`.
6. Consume same-sign, tied, deadband, missing, stale, misaligned, or invalid
   states flat.
7. Open at most one WTI position with `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` stop, no take-profit, and the fixed spread cap. Close
   before monthly replacement or after forty days. Friday close and both news
   axes are OFF.

`XAUUSD.DWX` is read-only and may never receive a magic, order, position, or
package-PnL role. The exact endpoint count, timestamp intersection, strict
opposite signs, deadbands, monthly cadence, WTI-only carrier, fixed risk,
stop, hold, and no-retry policy are locked.

## Reputable-Source Criteria

- R1 `PASS_WITH_POLICY_DEFER`: one canonical source lineage backed by a
  complete peer-reviewed paper read and a governed CME exchange packet; the
  fresh CME route is deferred and contributes no inferred content.
- R2 `PASS`: exact common month endpoints, return decomposition check, strict
  divergence, direction, lifecycle, risk, stop, and stale guard are
  deterministic.
- R3 `PASS`: registered WTI and gold D1 data supply every runtime input; gold
  is read-only.
- R4 `PASS`: native arithmetic only, without trained output, prohibited signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,395 EA-registry rows and 491
root cards and returned `CLEAN` with no fuzzy neighbor. Manual review confirms:

- `QM5_12604_cme-oilgold-ratio` fades an absolute D1 oil/gold log-ratio
  z-score and orders both legs. This candidate forms no ratio or z-score,
  orders only WTI, and evaluates strict twelve-month sign divergence monthly.
- `QM5_12605_cme-oilgold-brk` follows a ratio channel with a paired basket;
  this candidate has neither a channel nor a gold position.
- `QM5_12863_oilgold-rspread` fades a short-window return-spread shock and
  orders both legs. This candidate follows the WTI trend rather than fading a
  relative shock.
- `QM5_12603_wti-tsmom12m` is unconditional. `QM5_21516` uses weak WTI/XNG
  daily correlation, `QM5_21518` same-sign Brent confirmation, and
  `QM5_21522` falling WTI/SP500 downside beta. None uses gold's opposite
  twelve-month sign as a WTI-only admission state.
- `QM5_12567` is a short-horizon, long-only XNG cumulative-RSI pullback and
  shares neither instrument, state, direction map, nor clock.

The synchronized WTI/gold month endpoints, two exact twelve-month returns,
strict opposite-sign gate, WTI-only topology, and consumed monthly attempt are
jointly load-bearing. Verdict:
`CLEAN_WTI_TWELVE_MONTH_TREND_IN_STRICT_GOLD_DIVERGENCE_STATE`.

## Allocation And Kill Boundary

The atomic allocator reserved `QM5_21523` on 2026-08-14. Expected cadence is
approximately five to eight completed positions per full post-warm-up year;
Q02 must retire below five/year or on nonpositive governed economics. Q09
alone may establish realized correlation with XAU, SP500, NDX, and XNG.

Fail on wrong month mapping, endpoint count, timestamp intersection,
nonconsecutive months, endpoint-chain mismatch, non-strict or same-sign entry,
gold order, same-month retry, missing stop, invalid risk mode, stale hold, or
nondeterminism. No failed result may change a locked rule or carrier.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision
excludes manual backtests; live, demo, shadow, stress, and optimization
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio-gate
edits; portfolio admission; and correlation waivers. If the paced factory CPU
ceiling is binding before enqueue, stop without starting, stopping, reserving,
reaping, or reprioritizing a terminal.
