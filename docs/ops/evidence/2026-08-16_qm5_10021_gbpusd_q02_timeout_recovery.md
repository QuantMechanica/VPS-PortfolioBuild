# QM5_10021 GBPUSD Q02 timeout recovery

Date: 2026-08-16

Branch: `agents/board-advisor`

Farm claim: `ca8f638a-14b0-4e3b-ae63-f484edf2e1c3`

## Scope and selection

`QM5_10021_rw-fx-abs-mom` is the approved Robot Wealth D1 absolute-momentum strategy for AUDUSD, EURUSD, GBPUSD, and USDJPY. The card is `g0_status: APPROVED`, R1-R4 PASS, structural, fixed-rule, and expected to trade about 20 times per year per symbol.

The build backlog had no eligible non-duplicate diversity build with its required deterministic registry allocation. GBPUSD was therefore selected under the Q02-Q03 infrastructure-recovery priority: the same EA already has Q02 PASS evidence on AUDUSD (`c0117585-f28b-44b3-b1e8-380e12b12542`), EURUSD (`d6a4db34-f4cb-4103-971c-1fd258a3239f`), and USDJPY (`150d542f-7aaf-49ca-919d-cf72fdc356ca`).

## Diagnosis

The terminal GBPUSD row `cb5d37a3-b498-4a74-9fa6-8f2cf2a3a275` ended `INFRA_FAIL / ACTIVE_TIMEOUT` on T5 after the legacy 45-minute outer timeout. The farm stopped the worker and terminal, but produced neither an evidence path nor the referenced worker log. Because three sibling symbols completed Q02 PASS with the same implementation, this is an orphaned fleet-execution failure rather than an entry/exit defect.

The checked-in EX5 was also stale against the current V5 include surface:

- prior EX5 SHA-256: `6e12960aa7451e7ff4afd9fad6581a2d5be6f16b6869407e781e20cdf20b3517`
- current MQ5 SHA-256 (source unchanged): `279e023b724d9fd9d413de71dee8bfd2f1aa89f8797bd8544bfb4f0403be0c07`
- refreshed EX5 SHA-256: `6a1d669698f30ce4a7b80237fef27cca44ac9e8f1ce22d2480d21c33ad24225f`

## Repair and validation

`framework/scripts/build_check.ps1 -EALabel QM5_10021_rw-fx-abs-mom -Strict` recompiled the EA and returned PASS with 0 failures and 0 warnings. Evidence:

- build check: `D:\QM\reports\framework\21\build_check_20260816_152440.json`
- compiler log: `C:\QM\repo\framework\build\compile\20260816_152440\QM5_10021_rw-fx-abs-mom.compile.log`
- compiler summary: `D:\QM\reports\compile\20260816_152440\summary.csv`

The strict check replaced each canonical setfile's placeholder `build_hash: pending` with its deterministic build hash. No executable set parameter changed. All four backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`; the GBPUSD setfile SHA-256 is `9381501befd3db138c7a480c5b8e74ea19043d0f302feab2fa099cbbd44065ce`.

The pre-claim database backup is `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10021_gbpusd_q02_claim_20260816T152230Z.sqlite`, SHA-256 `0c13e93f2da8b1e6c2fe50e9231b73f7a05aa6d48e4fc8d79c575d8fc44993bf`; `PRAGMA quick_check` returned `ok`.

## Q02 handoff

`farmctl seed-fresh-q02` preserved the historical failure and appended current-binary work item `a1aa0e0e-52cd-448f-ba70-b1282017504e` for `GBPUSD.DWX / D1`. At handoff it is `pending`, unclaimed, and bound to the exact MQ5, EX5, and setfile hashes above. Custom-history archive admission is ACTIVE.

Capacity before enqueue was four running factory terminals (T5, T6, T7, T10), below the fleet ceiling of seven. No dispatch tick or manual backtest was started.

## Safety

- T_Live and its manifest were not touched.
- AutoTrading was not touched.
- Portfolio gates were not touched.
- No strategy mechanics, risk settings, card, registry, or magic rows were changed.
