# QM5_11888 EURJPY Q02 runtime repair

- Date: 2026-08-11
- Branch: `agents/board-advisor`
- Farm claim: `40a89873-eb54-456b-af95-05c05b994adb`
- EA: `QM5_11888_lien-perfect-order-sma-stack`
- Canary: `EURJPY.DWX`, D1, Q02

## Selection and authority

- Priority 1 was unavailable: the unclaimed approved build backlog lacked the pre-allocated ACTIVE magic rows required by the V5 build gate.
- This priority-2 candidate is an approved, structural, low-frequency FX strategy sourced to Kathy Lien, *Battle Tested Forex Trading Strategies* (2011), Perfect Order chapter.
- Card gates R1-R4 are PASS, `g0_status` is APPROVED, and expected frequency is 6 trades/year/symbol.
- EURJPY supplies the forex/cross-instrument diversity requested by the paced-fleet mission. Ten existing magic rows for EA 11888 are ACTIVE, including the EURJPY slot.
- The claim transaction found no competing active agent task and no pending/active work item for EA 11888.

## Failure evidence and diagnosis

Historical EURJPY Q02 row `e3f6e275-a3ae-4e4d-9ead-f60b4f27a9d5` ended `INFRA_FAIL` on 2026-06-24. It predates execution-binding capture and has no durable summary, so it was retained as an immutable pre-binding predecessor.

The same binary's later bound GBPUSD row `f25f2758-f4db-4182-843e-8fd78b67b3ba` corroborates the runtime failure mode: `ACTIVE_TIMEOUT`, 45-minute ceiling, 85% progress, 29.12 minutes without forward progress, and no completed summary.

The source performed unnecessary indicator-buffer work at tick frequency:

- entry freshness evaluated five SMAs at the current bar plus five SMAs across each of 60 prior bars: 305 framework SMA reads per entry bar;
- exit state evaluated five closed-D1 SMAs on every tick, even with no matching position;
- trailing management evaluated another closed-D1 SMA on every tick.

All of those values are invariant between D1 closes. This made a runtime infrastructure failure plausible without changing the card's entry or exit mechanics.

## Repair

- Replaced repeated pooled-indicator reads with one bounded 260-close `CopyClose` cache per completed D1 bar.
- Derived SMA10/20/50/100/200 values from prefix sums and retained the exact strict Perfect Order comparisons.
- Preserved the 60-bar freshness window (prior shifts 2 through 61), SMA50 +/- 25-pip initial stop, SMA20 trail, and stack-break exit.
- Cached closed-bar state for per-tick risk management and exit checks.
- Restored current framework safety wiring: MAE sampling is the first `OnTick` action, management/exits remain active during news blackouts, same-tick exit/re-entry is blocked, and entry requests are zero-initialized.

No strategy threshold, symbol list, timeframe, risk amount, or source mechanic changed.

## Verification

- Formula equivalence: PASS for 100 deterministic synthetic price windows x 61 shifts x 5 SMA periods at `1e-12` tolerance.
- SPEC validation: PASS (1/1).
- `build_check.ps1`: PASS, 0 failures, 0 warnings. Report: `D:\QM\reports\framework\21\build_check_20260811_003638.json`.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings. Log: `C:\QM\repo\framework\build\compile\20260811_003741\QM5_11888_lien-perfect-order-sma-stack.compile.log`.
- EURJPY setfile contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, D1, magic slot 7.
- MQ5 SHA-256: `ff7224269223478933902c05ccb9213549115a4bef8ce7b6d1b28151f14a139a`.
- EX5 SHA-256: `4d1f24fc752117621e8aaec257534fa6ac2f952a6625e2a3669127ff50b90626`.
- EURJPY setfile SHA-256: `9148ed01a26e787daa075888cc9e9ca7a51cc314542f7cb0aee6094887b736af`.
- The farm's deterministic artifact pump committed the rebuilt EX5 and bound setfiles in `099a4e354` while the repair was in progress.

## Q02 enqueue

Capacity immediately before admission was 6 managed MT5 terminals against the ceiling of 7. No manual dispatch was performed.

The guarded `seed-fresh-q02` path preserved the pre-binding EURJPY row and created current-binary work item `d94fb811-1143-4169-8633-7235977ddcef` at 2026-08-11T00:41:43Z. Initial state was `pending`, with the MQ5, EX5, setfile, symbol, D1 period, and fixed-risk contract sealed in its payload.

Farm DB backups:

- claim: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11888_eurjpy_q02_claim_20260811T003236Z.sqlite`
- enqueue: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11888_eurjpy_q02_seed_20260811T004107Z.sqlite`

## Safety boundary

No T_Live file, deploy manifest, portfolio gate, terminal AutoTrading setting, or live-trading state was readied or changed. No backtest was manually launched.
