# QM5_21518 WTI-Brent Confirmed Trend Q02 Enqueue

Date: 2026-08-14

Branch: `agents/board-advisor`

Owner: Codex

## Edge built

- EA: `QM5_21518_wti-brent-cfm`
- Strategy ID: `MOP-CME-WTI-BRENT-CFM-2026_S01`
- Traded host: `XTIUSD.DWX`, D1, slot 0, magic `215180000`
- Read-only companion: `XBRUSD.DWX`, D1; no slot, magic, or order authority
- Signal: reconstruct thirteen synchronized completed WTI/Brent broker-month
  endpoints, calculate each benchmark's exact twelve-month log return, and
  trade WTI only when the two strict signs agree. Positive/positive buys WTI;
  negative/negative sells WTI; equality or disagreement consumes the month
  flat.
- Exit: next broker-month transition, 40-day stale guard, malformed-state
  repair, or frozen `3.5 * ATR(20,D1)` hard stop; no take-profit or Friday
  flatten.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Source and claim boundary

The governed composite packet uses only prior approved repository reviews:

- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), DOI `10.1016/j.jfineco.2011.11.003`, for instrument-own-return
  time-series momentum and WTI membership; and
- CME WTI-Brent Financial futures, ICE Brent/WTI Futures Spread, and U.S. EIA
  WTI-Brent benchmark analysis for the linked but distinct crude-benchmark
  structure.

Those sources do not test the exact strict same-sign confirmation rule,
synchronized continuous-CFD endpoints, WTI-only execution, one-attempt clock,
fixed-dollar risk, ATR stop, costs, performance, or QM book correlation. Those
are explicit falsifiable QM choices. R1-R4 are PASS; no ML, external runtime
series, banned indicator, optimizer, or PnL adaptation is used.

## Non-duplicate boundary

- `QM5_12603_wti-tsmom12m` is unconditional WTI trend and never reads Brent.
- `QM5_12843_wti-brent-spread`, `QM5_12848_wti-brent-brk`, and
  `QM5_12860_wti-brent-rshock` form and trade two-leg spread or relative-value
  states; this EA never forms a spread and never orders Brent.
- Brent trend sleeves order Brent itself, while internal WTI confirmation
  sleeves compare WTI horizons or daily technical states rather than an
  independently reconstructed Brent twelve-month sign.

The canonical pre-allocation checker found no exact collision across 4,390
registry rows and 486 intake cards. Four lexical fuzzy neighbors were manually
separated before allocation. Verdict:
`CLEAN_AUTHORIZED_WTI_BRENT_BENCHMARK_CONFIRMED_TREND`.

## Artifacts

- Card: `strategy-seeds/cards/wti-brent-cfm_card.md`
- Approved card:
  `strategy-seeds/cards/approved/QM5_21518_wti-brent-cfm_card.md`
- Source packet:
  `strategy-seeds/sources/MOP-CME-WTI-BRENT-CFM-2026/source.md`
- G0 decision: `decisions/2026-08-14_qm5_21518_wti_brent_cfm_g0.md`
- EA: `framework/EAs/QM5_21518_wti-brent-cfm/QM5_21518_wti-brent-cfm.mq5`
- EX5: `framework/EAs/QM5_21518_wti-brent-cfm/QM5_21518_wti-brent-cfm.ex5`
- Q02 setfile:
  `framework/EAs/QM5_21518_wti-brent-cfm/sets/QM5_21518_wti-brent-cfm_XTIUSD.DWX_D1_backtest.set`
- Build record: `artifacts/qm5_21518_build_result.json`

## Q01 validation

- Card schema lint: PASS on root, approved, and EA-doc copies; no ML hits or
  missing sections.
- SPEC schema: PASS, 1/1.
- Deterministic arithmetic reference: PASS, 6/6, covering exact endpoint
  returns, component-chain agreement, sign direction, disagreement, equality,
  and month continuity.
- Symbol scope: `SINGLE_SYMBOL_OK`, 0 violations. `XBRUSD.DWX` is a read-only
  state input and has no trading slot.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260814_072443\QM5_21518_wti-brent-cfm.compile.log`
  - EX5 size: 386472 bytes.
- Framework build check: PASS, 0 failures, 0 warnings.
  - Report:
    `D:\QM\reports\framework\21\build_check_20260814_073500.json`.
- P1 artifact: PASS.
  - Report:
    `D:\QM\reports\pipeline\QM5_21518\P1\P1_QM5_21518_result.json`.
- EX5 SHA-256:
  `256fb2ee38024739bd7b68432925eeb054ab6bf21d1720a564e20e98df749a08`.

The targeted EA-ID, magic, resolver, and build guardrails pass. The broad
repository registry audit continues to report unrelated pre-existing legacy
row and duplicate-magic debt; none of its findings references `QM5_21518`.

## Q02 queue

The targeted governed never-tested sweep selected and created exactly one
priority work item, which was read back before handoff.

- Work item: `baee9255-3daf-4a85-b300-07a4f57ac0cf`
- Phase/kind: `Q02` / `backtest`
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Read-only companion: `XBRUSD.DWX`
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_21518_wti-brent-cfm\sets\QM5_21518_wti-brent-cfm_XTIUSD.DWX_D1_backtest.set`
- Status at verification: `pending`, attempt count 0, unclaimed.
- Created UTC: `2026-08-14T07:27:21+00:00`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`

The capacity scan at `2026-08-14T07:30:23+00:00` showed two active factory
terminals (`T3`, `T5`) out of ten and four total `terminal64` processes
including non-factory terminals. The backtest CPU ceiling was not hit. No
terminal was started, stopped, reserved, released, or reaped by this work, and
no manual tester or smoke run was launched; the paced fleet owns Q02.

## Safety

No MT5 live trading, AutoTrading toggle, `T_Live` file, deploy/T_Live
manifest, portfolio gate, portfolio admission, correlation waiver, or
portfolio KPI file was touched.
