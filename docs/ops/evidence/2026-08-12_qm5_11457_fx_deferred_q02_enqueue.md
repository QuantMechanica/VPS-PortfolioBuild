# QM5_11457 structural repair and FX Q02 breadth enqueue

Date: 2026-08-12

Branch: `agents/board-advisor`

Status: Q01 PASS; USDJPY and USDCAD Q02 rows created and autonomously claimed; no verdict claimed

## Selection boundary

The frozen 66-pair FX cointegration frontier is already fully mechanized. The
requested anchors are not blocked: `QM5_12532` is beyond Q02 and later failed
Q05, while `QM5_12533` is beyond Q02 and later failed Q04. The only current
cointegration Q02 rows without verdicts were already pending once each, so a
new pair Card, duplicate basket, or retry would not be honest work.

The existing-card fallback selected
`QM5_11457_goodwin-6day-extreme-3day-stop-entry-d1`. It is a low-frequency D1
FX port of Andrew Goodwin's published six-day closing-extreme / three-day
recovery-stop system. The entry is structural OHLC arithmetic, ATR is used
only for bounded risk, and there is no banned signal indicator, ML, grid,
martingale, or adaptive PnL logic. Expected cadence is 5-12 trades per year
per symbol.

Its stage-one AUDUSD, EURUSD, and GBPUSD hosts had each passed Q02, but the
registered USDJPY and USDCAD remainder had never received a Q02 row. This
handoff advances those two declared hosts; it does not requeue any terminal
row or change strategy parameters. GBPUSD's later Q07 failure remains
terminal and unmodified.

## Q01 repair and validation

The current strict build gate found four direct D1 `iClose` reads without the
required bounded/new-bar performance annotation. Each read already occurs in
`Strategy_EntrySignal` after the framework `QM_IsNewBar` gate. The source now
documents that contract on the four calls; trading mechanics and parameters
are unchanged. The SPEC revision records the repair. A strict compile also
refreshed the generated build-hash comments in the EA's existing baseline and
stress presets.

- Strict build check: PASS, zero failures and zero warnings.
- MetaEditor compile: PASS, zero errors and zero warnings.
- SPEC validation: PASS.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260812_060608.json`.
- Compile summary: `D:\QM\reports\compile\20260812_060608\summary.csv`.
- MQ5 SHA-256:
  `2cc18e832dd7338d19738201e858b0b550749cab57eb45de16f6796ed74e448b`.
- EX5 SHA-256:
  `4ec8029be1e00ed6ceb99edb64f372f40c73f1bd1a1bee3305a8a02f18deb4aa`.
- SPEC SHA-256:
  `ed40efc639262a2e5f6fb23778406ff74c1e5a8f995d584ff052c621254e0827`.
- USDJPY setfile SHA-256:
  `58febc8310644f006cfe814ef028f19794af2deef678083a4868c0a0d033cd89`.
- USDCAD setfile SHA-256:
  `7d027b2453b9244061d305648731cb15ae87d1f4139f2a6ea74cdedbb7be9e04`.
- Both presets retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Active magic bindings: USDJPY slot 2 / `114570002`; USDCAD slot 4 /
  `114570004`.

An online farm-state backup was written before the deferred-state mutation:

`D:\QM\strategy_farm\state\backups\farm_state_pre_qm5_11457_fx_deferred_20260812T060916Z.sqlite`

## Q02 enqueue

A target-only dry run selected exactly the two missing hosts. The last
pre-enqueue fleet sample at `2026-08-12T06:10:28Z` observed three factory
terminals (`T2`, `T6`, and `T10`), below the binding seven-terminal ceiling.
The lock-aware apply created exactly these rows at `2026-08-12T06:12:17Z`:

| Host | Work item | State at verification | Binary binding |
|---|---|---|---|
| `USDJPY.DWX` / D1 | `4c107118-7ea8-4124-a24c-848ed900f6ca` | active, claimed by managed worker T9, attempt 0 | EX5 SHA-256 `4ec8029b...b4aa` verified |
| `USDCAD.DWX` / D1 | `3d8b9e31-c965-4d15-adca-f3b66fa6db53` | active, claimed by managed worker T3, attempt 0 | EX5 SHA-256 `4ec8029b...b4aa` verified |

The deferred sidecar entry was consumed and removed. Background workers
claimed the rows automatically; no dispatch tick, tester command, terminal
reservation, process launch/stop, or phase runner was invoked by this handoff.
A post-enqueue sample at `2026-08-12T06:13:08Z` observed two running factory
terminals, still below the ceiling. No Q02 result is asserted here.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, live setfile, AutoTrading state, or deploy artifact changed.
- T_Live and FTMO processes were only observed to exclude them from the
  factory-terminal count; neither was controlled.
- Existing unrelated dirty-worktree files were not staged or modified for
  this handoff.
