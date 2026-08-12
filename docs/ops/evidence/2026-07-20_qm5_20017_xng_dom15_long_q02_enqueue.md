# QM5_20017 XNG DOM15 - Q02 Enqueue Evidence

**Date:** 2026-07-20  
**Branch:** `agents/board-advisor`  
**EA:** `QM5_20017_xng-dom15-long`  
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
- Journal review policy:
  https://econjournals.sgh.waw.pl/JMFS/reviewing

The study covers NYMEX natural-gas futures from 1990-04-03 through 2016-03-31.
For numbered calendar days, it reports the largest natural-gas daily-return
mean on day 15 at `+0.9881%`, with equality against other days rejected at
reported `p=0.0008`.

The source is tier B rather than treated as a track record. It searches 31
numbered days and other calendar partitions without a reported
multiple-comparison correction, assumes normal populations in the mean-test
method, ends before the current regime, and studies futures rather than the
Darwinex CFD. Those weaknesses are explicit Q02 falsification risks.

## Mechanical and non-duplicate decision

- On a genuine new `XNGUSD.DWX` D1 bar dated exactly the 15th, consume one
  broker-month attempt and submit one BUY.
- If the 15th has no D1 bar, skip the month; never shift to another date.
- Persist the monthly attempt before news, spread, ATR, price or order checks,
  and verify deal history, so rejection, stop or restart cannot retry.
- Close on the first following D1 bar; retain close retries across later ticks,
  with a one-calendar-day stale guard and framework Friday close at hour 21.
- Use completed-bar ATR(20) with a frozen 2.75 ATR hard stop, no take-profit,
  no price-direction filter and no parameter sweep.

Repository-wide card/source/EA searches found no recurring one-session XNG
DOM15 carrier. `QM5_12567` is SMA/RSI pullback; `QM5_12818`, `QM5_12819` and
`QM5_20011` are weekday effects; `QM5_13009` is turn-of-month; `QM5_20013`
and `QM5_20014` use multi-month/month-channel states; `QM5_12813` is a broad
paired May-August regime. Different mechanics do not prove low correlation,
so portfolio correlation remains a governed downstream kill test.

## Identity and Q01 evidence

- EA reservation: `QM5_20017`, strategy
  `BOROWSKI-XNG-DOM15-2016_S01`.
- Magic slot 0: `XNGUSD.DWX` to `200170000`.
- Resolver retains 14,955 rows and embeds magic-registry SHA256
  `098901A1C158E9E588266A7BDC64AD41980097EEA956ACD21BF95DEAF3F151DD`.
- Resolver generation included the new row. Its `--strict` invocation also
  reported the pre-existing absent legacy EA directories 1001, 1015 and 1016;
  no new row was dropped. The build guard and resolver/hash checks passed.
- Final strict compile: PASS, 0 errors, 0 warnings; log
  `framework/build/compile/20260720_133414/QM5_20017_xng-dom15-long.compile.log`.
- Final strict build check: PASS, 0 failures, 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260720_133438.json`.
- G0 card lint, approved-card schema/prebuild, build guard, SPEC validation,
  symbol scope and MQ5/setfile input parity: PASS.
- MQ5 SHA256:
  `87BE34509CF4C0DFAD4345551BEC72B9E440A22B74A0EDF1CE1DAC9F9BA1F1B3`.
- EX5 SHA256:
  `1976C417BC3D992CA363DEEA0C3BFE401B08ED9BC7C5F457FCAECF4239C15018`.

## Risk and Q02 queue evidence

- Setfile:
  `framework/EAs/QM5_20017_xng-dom15-long/sets/QM5_20017_xng-dom15-long_XNGUSD.DWX_D1_backtest.set`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Setfile build hash:
  `c57481cf585e9ba1220adbe1101aa2b115180c8bfa586a0dcbe0e9ba0b53bd17`.
- Build task `ebce7a4e-0194-4136-87cd-878ed302f4c2`: done.
- Q02 work item `1403b76c-3b38-4b22-81f7-81ced9d64380`: pending,
  attempt 0, unclaimed, `XNGUSD.DWX` D1.
- Enqueued at `2026-07-20T13:29:13+00:00` by `farmctl record-build`;
  one item enqueued and none skipped.

The paced-fleet scan hit the backtest CPU ceiling earlier in the mission with
eight `terminal64` and six `metatester64` processes. The final pre-handoff
scan still showed six terminals and four metatesters. Smoke is recorded as
`deferred_p2_smoke`; no dispatch tick, worker tick, terminal launch, tester
run, optimization or backtest was started by this mission.

## Safety and falsification boundary

- Structural calendar arithmetic and ATR risk only; no ML or banned indicator.
- No live setfile, T_Live artifact/action, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio admission, KPI or portfolio gate was touched.
- Q02 must retire the carrier below five completed trades/year/symbol or for
  shifted-date behavior, duplicate attempts, nondeterminism, risk mismatch or
  failure of governed net PF/DD thresholds.
- Futures-to-CFD transfer, costs, financing, gaps, post-2016 persistence,
  multiple comparisons and realized book correlation are unproven kill risks.
