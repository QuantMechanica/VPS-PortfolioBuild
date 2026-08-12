# QM5_20018 XNG Wednesday Short - Q02 Enqueue Evidence

**Date:** 2026-07-20  
**Branch:** `agents/board-advisor`  
**EA:** `QM5_20018_xng-wed-short`  
**Status:** Q01 build PASS; one `XNGUSD.DWX` D1 Q02 item pending

## Edge and source boundary

The carrier implements one exact finding from Krzysztof Borowski (2016),
"Analysis of Selected Seasonality Effects in Markets of Future Contracts with
the Following Underlying Instruments: Crude Oil, Brent Oil, Heating Oil, Gas
Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs and Lumber," *Journal
of Management and Financial Sciences*, issue 26, pages 27-44.

- Official SGH issue archive:
  https://econjournals.sgh.waw.pl/JMFS/Archives_2015_2016
- Complete author-uploaded article:
  https://www.researchgate.net/publication/303285422_ANALYSIS_OF_SELECTED_SEASONALITY_EF-_FECTS_IN_MARKETS_OF_FUTURE_CONTRACTS_WITH_THE_FOLLOWING_UNDERLYING_INSTRUMENTS_CRUDE_OIL_BRENT_OIL_HEATING_OIL_GAS_OIL_NATURAL_GAS_FEEDER_CATTLE_LIVE_CATTLE_LEAN_HOGS_AND_LUMBER

The study covers NYMEX natural-gas futures from 1990-04-03 through 2016-03-31.
It reports a Wednesday mean daily return of `-0.2664%`, with equality against
the other-weekday population rejected at reported `p=0.0136`.

The source is tier B rather than treated as a track record. It searches many
commodities and calendar partitions without a reported multiple-comparison
correction, assumes normal populations in the mean-test method, ends before
the current regime, and studies futures settlements rather than Darwinex CFD
D1 boundaries. Those weaknesses are explicit Q02 falsification risks.

## Mechanical and non-duplicate decision

- On a genuine new `XNGUSD.DWX` D1 bar timestamped Wednesday, consume one
  broker-day attempt and submit one SELL.
- Persist the attempt before news, spread, ATR, price or order checks, and
  verify deal history, so a block, rejection, stop or restart cannot retry.
- Close on the first following D1 bar; retain rejected-close retries on later
  ticks, with a one-calendar-day stale guard and framework Friday close.
- Use completed-bar ATR(20) with a frozen 2.75 ATR hard stop, no take-profit,
  no price-direction filter and no parameter sweep.

The deterministic dedup tool returned CLEAN for slug `xng-wed-short`,
strategy `BOROWSKI-COMM-DOW-2016_S01`, the named author and the exact mechanic.
Manual repository inspection found no unconditional Wednesday-entry XNG EA.

- `QM5_12567` is an SMA/cumulative-RSI2 pullback, not calendar timing.
- `QM5_12818` buys Tuesday and `QM5_12819` sells Thursday.
- `QM5_12806` trades Monday and Friday.
- `QM5_20011` exits at Wednesday open and does not hold Wednesday's return.
- Event-window storage EAs require release and price state.
- `QM5_20017` is a monthly calendar-day-15 long from another paper result.

Different mechanics from the certified RSI2 sleeve do not prove low realized
correlation. Portfolio correlation remains a governed downstream kill test.

## Identity and Q01 evidence

- Atomic EA reservation: `QM5_20018`, strategy
  `BOROWSKI-COMM-DOW-2016_S01`.
- Magic slot 0: `XNGUSD.DWX` to `200180000`.
- Resolver retains 14,956 rows and embeds magic-registry SHA256
  `0C8FD4BCFB1DB42559E88ECE8995513FCE0FE15B43CFE05FA60DE4F19BE20D81`.
- Resolver generation retained the new row. Its strict invocation reported
  only the pre-existing absent legacy EA directories 1001, 1015 and 1016;
  no new row was dropped.
- Final strict compile: PASS, 0 errors, 0 warnings; log
  `framework/build/compile/20260720_150330/QM5_20018_xng-wed-short.compile.log`.
- Final strict build check: PASS, 0 failures, 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260720_150330.json`.
- P1 artifact check, G0 card lint, card schema, approved-card prebuild, build
  guard, SPEC validation, symbol scope and MQ5/setfile input parity: PASS.
- Symbol scope verdict: `SINGLE_SYMBOL_OK`; no foreign-symbol reference.
- MQ5 SHA256:
  `B2F8FAAA359E4F0430037FD0A2930AB5146A7537F495C015681EEA5CFFBF29E2`.
- EX5 SHA256:
  `499B128E9B1E913334C5935D852BEEDF6C9E258B292B4417DC6CE105B1BAC06C`.

## Risk and Q02 queue evidence

- Setfile:
  `framework/EAs/QM5_20018_xng-wed-short/sets/QM5_20018_xng-wed-short_XNGUSD.DWX_D1_backtest.set`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Setfile build hash:
  `2d0443d3c38b9319ea79b08f9991ca6c95d02db2a2a5f0143effd7bb3bce28c7`.
- Build task `7ed480eb-4f00-4bc9-91e0-b5887dee8d76`: done.
- Q02 work item `ebacde4d-02c8-405c-94b9-e42db26e75d3`: pending,
  attempt 0, unclaimed, `XNGUSD.DWX` D1.
- Enqueued at `2026-07-20T15:03:58+00:00` by governed build recording;
  exactly one item exists for `QM5_20018`.

The paced-fleet scan reached the backtest CPU ceiling with seven `terminal64`
and five `metatester64` processes, including five active factory terminals.
Smoke is recorded as `deferred_p2_smoke`; no dispatch tick, worker tick,
terminal launch, tester run, optimization or backtest was started by this
mission.

## Safety and falsification boundary

- Structural calendar arithmetic and ATR risk only; no ML or banned indicator.
- No live setfile, T_Live artifact/action, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio admission, KPI or portfolio gate was touched.
- Q02 must retire the carrier below five completed trades/year/symbol or for
  non-Wednesday entries, duplicate attempts, nondeterminism, risk mismatch or
  failure of governed net PF/DD thresholds.
- Futures-to-CFD transfer, costs, financing, gaps, broker-session mapping,
  post-2016 persistence, multiple comparisons and realized book correlation
  remain unproven kill risks.
