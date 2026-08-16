# QM5_11888 GBPUSD Q02 recovery handoff

- Date: 2026-08-16
- Branch: `agents/board-advisor`
- Farm claim: `680396c0-36f7-4082-b2c9-f750bcb6d1d6`
- EA: `QM5_11888_lien-perfect-order-sma-stack`
- Target: `GBPUSD.DWX`, D1, Q02
- Outcome: rebuild PASS; Q02 admission deferred at the seven-terminal CPU ceiling

## Selection and authority

- The approved build backlog had no unclaimed, registry-complete higher-quality diversity candidate. The only registry-complete unbuilt FX candidate found in the screen was a tier-C generic GitHub indicator, so it did not meet the reputable-source preference.
- QM5_11888 is an approved structural, low-frequency FX strategy sourced to Kathy Lien, *Battle Tested Forex Trading Strategies* (2011), Perfect Order chapter.
- Card prebuild validation passed. The card has `g0_status: APPROVED`, R1-R4 PASS, an expected frequency of 6 trades/year/symbol, and active custom-history archive coverage for all ten `.DWX` FX symbols.
- EA registry row 11888 and all ten active magic rows were present. GBPUSD uses slot 1 and magic 118880001.
- The atomic claim transaction found no competing active agent task and no pending/active work item for QM5_11888.
- Pre-claim DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11888_gbpusd_claim_20260816T135929Z.sqlite`; `PRAGMA quick_check` returned `ok`.

## Failure evidence

Historical GBPUSD Q02 work item `f25f2758-f4db-4182-843e-8fd78b67b3ba` is preserved unchanged as `failed / INFRA_FAIL`. It ended with:

- `ACTIVE_TIMEOUT` / `summary_missing_retries_exhausted`;
- a 45-minute absolute ceiling;
- 85% progress followed by 29.12 minutes without forward progress;
- no completed summary;
- old bindings: MQ5 `c4648e41a72d72edf9a2d5cbffbd4f36112962985e404c3922bfeaea267afa2f`, EX5 `2e38cbf1880601afd72c891ace5df9ffc9f6b635fdbdc820c8c4db070037455c`, setfile `840046007c246ada16a92781a6f7032011feff7cfb14ad9c8b02b9c11898c1ca`.

That row predates the 2026-08-11 runtime repair. The repair replaced hundreds of repeated tick-time SMA reads with one bounded D1 close cache per completed bar while preserving every Perfect Order comparison, the 60-bar freshness rule, SMA50 buffered initial stop, SMA20 trail, and stack-break exit. Only EURJPY was admitted after that repair, so GBPUSD remained a valid unretried infrastructure recovery target.

## Rebuild

The repaired source was not changed. It was strictly recompiled in place against committed framework head `10baad7103bab873b32781aa2b06c325a2837a72`, which descends from the host-slot magic fix, and all backtest setfile build bindings were refreshed.

- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
- Compile log: `C:\QM\repo\framework\build\compile\20260816_140529\QM5_11888_lien-perfect-order-sma-stack.compile.log`.
- `build_check.ps1`: PASS, 0 failures, 0 warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260816_140612.json`.
- SPEC validation: PASS (1/1).
- Build skill guard: PASS for EA registry, magic registry, and EA directory.
- Every backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`; GBPUSD remains D1, slot 1.
- MQ5 SHA-256: `ff7224269223478933902c05ccb9213549115a4bef8ce7b6d1b28151f14a139a`.
- EX5 SHA-256: `dbbe38fc80530c863892056b8ee473dc4726b427dff9e09a38cdcdbbac6d191a`.
- GBPUSD setfile SHA-256: `1315aceaa4466729b53ff7f4df8915860873165ea7117041db0721c9c23af43f`.

The previous repaired EX5 hash was `4d1f24fc752117621e8aaec257534fa6ac2f952a6625e2a3669127ff50b90626`; the new binary is therefore a distinct current-framework artifact. No strategy threshold or mechanic changed.

## Q02 admission deferred at capacity

Immediately before the intended append-only retry, `farmctl mt5-slots` reported all seven managed terminals active: T2, T3, T4, T5, T6, T7, and T8. Five host CPU samples were 100%, 100%, 97%, 88%, and 96% (96.2% average).

The paced-fleet instruction says to stop at the backtest CPU ceiling. Therefore:

- no Q02 work item was enqueued;
- no terminal was dispatched or stopped;
- the historical failed row remains immutable;
- the next operator may append-only rerun `f25f2758-f4db-4182-843e-8fd78b67b3ba` once managed-terminal capacity is below the ceiling, binding the exact current EX5 SHA-256 above.

## Safety boundary

No T_Live file, deploy manifest, portfolio gate, terminal AutoTrading setting, or live-trading state was changed. No backtest was manually launched.
