# QM5_10347 USDJPY Q02 infrastructure requalification

Date: 2026-08-13
Branch: `agents/board-advisor`
EA: `QM5_10347_et-donchian210`
Scope: one collision-free FX Q02 recovery and append-only handoff

## Selection and farm claim

- A farm/card/registry census found no collision-free, unbuilt, OWNER-approved forex, crypto, rates, energy-beyond-XNG, or market-neutral-pairs card eligible for the standard build lane. The genuinely diverse approved candidates were already built, already queued, or had reached later gates.
- The Q03 infrastructure rows inspected already had terminal Q04 outcomes, so replaying them would not advance a new sleeve through the funnel.
- Among unclaimed Q02 infrastructure blocks, `QM5_10347` was the only candidate satisfying the combined filters used here: approved R1 source, structural mechanics, at most 40 expected trades/year/symbol, no Q02 PASS, no Q03/Q04 row, and no pending/active row or live agent claim.
- USDJPY was selected over the remaining GBPUSD infrastructure row because it adds yen exposure rather than another European currency leg. The exact predecessor was `60983870-3fa7-4d7a-92e8-2ca9716ad14c`, whose latest verdict was `INFRA_FAIL` with `run_smoke_fail:NO_REAL_TICKS;INCOMPLETE_RUNS`.
- The atomic farm claim is agent task `a48096b0-2316-4da0-b624-6b8f772993ef`, claim key `manual:codex:agents/board-advisor:QM5_10347:USDJPY.DWX:20260813T003453Z`.
- The pre-claim SQLite backup is `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10347_usdjpy_claim_20260813_003453.sqlite`.

## Approved structural contract

- The farm-approved card and EA-local card are byte-identical, SHA-256 `3329b9593fff95e5c242ae4172847f122a6c99bfdb61c97b4bd06ac54bffe898`.
- Card status is G0 `APPROVED`, with R1-R4 `PASS`.
- Source: Chuck Krug, “Richard D. Donchian System,” Elite Trader, 2009-08-09, `https://www.elitetrader.com/et/threads/richard-d-donchian-system.172693/`.
- Mechanics remain the fixed D1 210-day Donchian stop-and-reverse system, estimated at four trades/year/symbol. No strategy logic, parameters, ML, adaptive indicator, grid, martingale, or pyramiding behavior was added.
- USDJPY has the deterministic registry row `10347,et-donchian210,2,USDJPY.DWX,103470002,...,active`.

## Infrastructure diagnosis

The June predecessor was executed as real MT5 evidence but predates execution-binding capture. Its immutable payload records terminal `T8`, the exact USDJPY D1 setfile, `NO_REAL_TICKS;INCOMPLETE_RUNS`, and a now-pruned report path. It is therefore an infrastructure result rather than a strategy verdict.

The ordinary authenticated rerun command failed closed with `q02_rerun_source_evidence_missing` and created no row. The purpose-built `farmctl seed-fresh-q02` path then verified that the predecessor is a terminal pre-binding row, authenticated the current canonical binary and setfile, preserved the old row, and accepted the requalification. No evidence gate was bypassed.

The current farm has private custom-history copy-on-claim. On 2026-08-11, the same repaired EA completed that path for EURUSD with `PASS_PRIVATIZED` and reached an economic `ZERO_TRADES` result rather than an infrastructure failure. That makes USDJPY a bounded test of the repaired execution path; it does not assert that the strategy will pass economically.

## Strict rebuild and guardrails

- MQ5 SHA-256: `4664dc94f4a5f466c1836bb3cdcb64d2c8642271eaf472c938f83c790fbf7044` (unchanged).
- Rebuilt EX5 SHA-256: `3f99f9a8eec8c22d539633f4358d11b19c271e460c6c53379089439b8a9ae105`.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log: `C:\QM\repo\framework\build\compile\20260813_003515\QM5_10347_et-donchian210.compile.log`
  - Log SHA-256: `2bf36a9249aad32cf694a9a01be6f9710e01abcb098eade883cfe0e060cd72a9`
- EA-scoped `build_check.ps1 -Strict`: PASS, 0 failures, 0 warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260813_003515.json`
  - Report SHA-256: `04e1320720aec4309ae441371d4928267125df748fa5a1a19800a0ca2c3643f6`
- The strict rebuild refreshed only the EX5 and deterministic build-hash comments in the five existing setfiles; it did not modify MQ5 mechanics.
- USDJPY setfile SHA-256: `9576ca0a4e1a6a8010d8e7cc6a320630e28519714fc975c8264e5a629ee340ee`.
- USDJPY backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, with magic slot offset 2.

No local smoke test or backtest was launched.

## Capacity and Q02 handoff

Immediately before enqueue, at `2026-08-13T00:36:03Z`:

- governed T1-T10 terminals running: 0;
- active Q02 work items: 0;
- pending Q02 work items: 900;
- three-sample CPU average/max: 19.4% / 22.1%;
- the only `terminal64.exe` process was the unrelated FTMO terminal, which was excluded and untouched.

The CPU ceiling was not reached. The canonical append-only pre-binding enqueue created exactly one successor:

- Work item: `a43be2a3-5658-4170-b8b7-ad525e0c7f74`
- Phase / symbol: Q02 / `USDJPY.DWX`
- Initial state: `pending`, attempt 0, unclaimed
- Preserved predecessor: `60983870-3fa7-4d7a-92e8-2ca9716ad14c` (`INFRA_FAIL`)
- Expected EX5 SHA-256: `3f99f9a8eec8c22d539633f4358d11b19c271e460c6c53379089439b8a9ae105`
- Expected MQ5 SHA-256: `4664dc94f4a5f466c1836bb3cdcb64d2c8642271eaf472c938f83c790fbf7044`
- Expected setfile SHA-256: `9576ca0a4e1a6a8010d8e7cc6a320630e28519714fc975c8264e5a629ee340ee`
- Matching pending/active USDJPY Q02 rows after enqueue: 1

No dispatch was forced; the paced farm owns terminal claim and execution.

No T_Live file, AutoTrading state, portfolio-admission gate, portfolio KPI/Q08 contribution file, or deploy manifest was readied or changed.
