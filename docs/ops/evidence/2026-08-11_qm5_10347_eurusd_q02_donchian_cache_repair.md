# QM5_10347 EURUSD Q02 Donchian cache repair and handoff

Date: 2026-08-11
Branch: `agents/board-advisor`
EA: `QM5_10347_et-donchian210`
Scope: existing-FX fallback, one EA and one Q02 successor

## Frontier and duplicate audit

- The positive-hedge discovery anchors are not blocked at governed basket Q02:
  - `QM5_12532` has basket-symbol Q02 PASS (`e4890d77-b865-4a48-b946-315faefca920`), Q04 PASS, and a terminal Q05 FAIL.
  - `QM5_12533` has basket-symbol Q02 PASS (`76cb11ee-7e9d-4d75-be9d-626c205bca62`) and a terminal Q04 FAIL.
- The sign-aware 66-pair ranking and the committed duplicate-guard/frontier records map every ranked relationship to an existing EA, including the final two ranks. Creating another basket card would therefore duplicate an already mechanized sleeve.
- This handoff follows the requested fallback: advance an existing approved forex card instead of minting a duplicate pair.

Audit inputs:

- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `docs/research/FX_COINTEGRATION_FRONTIER_DUPLICATE_GUARD_2026-07-24.md`
- `docs/research/FX_COINTEGRATION_FRONTIER_Q02_CPU_CEILING_STOP_2026-08-07.md`

## Approved structural candidate

- Card: `QM5_10347_et-donchian210`, G0 `APPROVED`, R1-R4 `PASS`.
- Reputable source: Chuck Krug, “Richard D. Donchian System,” Elite Trader (2009-08-09), `https://www.elitetrader.com/et/threads/richard-d-donchian-system.172693/`.
- The farm-approved card and the EA-local card are byte-identical, SHA-256 `3329b9593fff95e5c242ae4172847f122a6c99bfdb61c97b4bd06ac54bffe898`.
- Mechanics remain fixed and structural: prior 210-day high/low breakout and opposite-channel exit/reversal, approximately four trades/year/symbol. No ML, adaptive indicator, grid, martingale, or pyramiding logic was added.
- The latest EURUSD predecessor, `f50a5de8-bd13-4b1b-80e4-d2d7571b5798`, ended Q02 as `INFRA_FAIL`; there was no pending or active successor at selection time.

## Repair

The current static gate rejected eight direct `iHigh`/`iLow` calls. The same 211 closed D1 bars are now read as one bounded `CopyRates` snapshot:

- index 0 remains the signal bar (shift 1);
- indices 1 through 210 remain the prior Donchian window (shifts 2 through 211);
- the snapshot refreshes only when the closed signal-bar timestamp changes;
- the per-tick exit path performs only the framework `QM_ReadBar` freshness read between D1 changes.

This preserves the card's window and signals while removing repeated 210-bar per-tick series calls. The EA was also rebuilt against the current generated magic resolver. Build commit: `c964e3cbd3b3275254f122bdece115abfc63efa2`.

## Build verification

- MQ5 SHA-256: `4664dc94f4a5f466c1836bb3cdcb64d2c8642271eaf472c938f83c790fbf7044`.
- EX5 SHA-256: `a4a3e997aa00d7844f798e3d414b6db13a081b24f62a888e52715bb9f64db71a`.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log: `C:\QM\repo\framework\build\compile\20260811_123704\QM5_10347_et-donchian210.compile.log`
  - Log SHA-256: `0d365996d0931937f332aa3c7c6577eab16064f3f7f34f2c67b65cdfe2e172ce`
- EA-scoped static build gate: PASS, 0 failures, 0 warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260811_123743.json`
  - Report SHA-256: `c783bf26fa2dc9c94f9b2c4ab87b9c12f81be4f25077a74bec8ed7b7973bbe02`
- All five backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`; the gate pinned their deterministic build-hash comments.
- EURUSD setfile SHA-256: `15a6f2f128a087c088a325f298fa4e2e0c013890cf4b576c497e4463306c9ff0`.

No local smoke test or backtest was launched.

## Paced Q02 handoff

At `2026-08-11T12:38:32Z`, four factory terminals were running (`T2`, `T3`, `T9`, `T10`), below the seven-terminal paced ceiling. T_Live and the unrelated FTMO process were excluded from the factory count and were not controlled.

The hash-locked, append-only enqueue created exactly one successor:

- Work item: `73ca4921-5e1e-4547-9e9d-5c00ccb96e4e`
- Phase / symbol: Q02 / `EURUSD.DWX`
- Initial state: `pending`, attempt 0, unclaimed
- Predecessor: `f50a5de8-bd13-4b1b-80e4-d2d7571b5798` (`INFRA_FAIL`)
- Expected EX5 SHA-256: `a4a3e997aa00d7844f798e3d414b6db13a081b24f62a888e52715bb9f64db71a`
- Expected setfile SHA-256: `15a6f2f128a087c088a325f298fa4e2e0c013890cf4b576c497e4463306c9ff0`
- Matching pending/active EURUSD Q02 rows immediately after enqueue: 1

One earlier pre-commit seed attempt failed closed on an EX5 hash mismatch and created no row. No dispatch was forced; the paced farm owns claim and execution.

No T_Live file, AutoTrading state, portfolio-admission gate, portfolio KPI/Q08 contribution file, or deploy manifest was changed.
