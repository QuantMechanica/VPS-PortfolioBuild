# QM5_11434 EURUSD Q02 stale-resolver repair

Date: 2026-08-10  
Branch: `agents/board-advisor`  
Disposition: `REPAIRED_Q02_REENQUEUE_DEFERRED_CPU_CEILING`

## Scope and claim

- Farm claim: `a4557ee2-961a-4911-84af-a522943f6e05`
- Claim key: `manual:codex:agents/board-advisor:QM5_11434:q02-stale-resolver-recovery:2026-08-10T20:14:41.256667+00:00`
- Pre-claim DB backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11434_q02_magic_repair_20260810T201441Z.sqlite`
- Exact source work item: `eb93641d-e23b-4d8f-a87c-a0e9dc11a7dc`
- Exact target: `QM5_11434_carter-t-sma32hl-psar-sma200-h1 / EURUSD.DWX / Q02`
- No pending or active Q02 row existed for this exact EA/symbol at claim time.

## Diagnosis

The source row ended `done/INFRA_FAIL` with
`run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`. Its authenticated tester log is:

`D:\QM\reports\work_items\eb93641d-e23b-4d8f-a87c-a0e9dc11a7dc\QM5_11434\20260810_195201\raw\run_01\20260810.log`

The decisive terminal line is:

`EA_MAGIC_NOT_REGISTERED: ea_id=11434 slot=0 magic=114340000`

This was not missing governance data. `framework/registry/magic_numbers.csv`
contains five active rows for EA 11434, including slot 0 / EURUSD.DWX / magic
114340000. The current generated resolver also contains EA 11434 and magic
114340000, and its declared registry SHA-256 exactly matches the current CSV:

`4533da2b4dd58bb2ef6e1bbf234e3495be4be7475035b9e1b1f4a1d412e9d601`

The failed work item proved that its staged binary was stable and hash-correct,
but that binary did not recognize the governed magic row. Therefore the failure
was a stale resolver include embedded in the EX5, not an economic or strategy
verdict.

## Repair and verification

- Recompiled the unchanged MQ5 against the current generated resolver.
- Previous EX5 SHA-256:
  `6d6c98242b6f8abdbde948021d51967f56d0bc5299e12f61dfb92c2e1984096b`
- Repaired EX5 SHA-256:
  `5d910ca9a2e997164e7c93bddbb43e195b38e1e6f10d7372e5a09c2ffdf54b27`
- MQ5 SHA-256 remained unchanged:
  `000b5528bc3135134e5d9b50c59fad9ed6a85eab73028ac0d8819dce2ed9948a`
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260810_201718\QM5_11434_carter-t-sma32hl-psar-sma200-h1.compile.log`
- Build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260810_201718.json`
- All five backtest setfiles had their generated build hashes refreshed by the
  strict build check. The EURUSD set remains `RISK_FIXED=1000` and
  `RISK_PERCENT=0`; the source tester evidence binds Model 4.
- No strategy source, registry CSV, framework include, portfolio gate, deploy
  manifest, T_Live file, or AutoTrading state was changed.

## Capacity stop and deterministic continuation

At 2026-08-10T20:18:23Z, the read-only capacity check showed host CPU at 100%
and eight active farm rows (seven Q02 plus one Q04). Factory terminals T1, T3,
T7, and T8 were actively running bound work items. The mission's backtest CPU
ceiling therefore applied: no smoke, manual dispatch, or Q02 enqueue was
performed.

Once the governed capacity check is below the ceiling, create exactly one
append-only successor of the immutable source row:

```powershell
python C:\QM\repo\tools\strategy_farm\farmctl.py enqueue-backtest `
  --ea QM5_11434 `
  --phase Q02 `
  --append-only-rerun-of eb93641d-e23b-4d8f-a87c-a0e9dc11a7dc `
  --rerun-reason "stale resolver EX5 repaired; retry EURUSD Q02 after CPU ceiling clears" `
  --expected-current-ex5-sha256 5d910ca9a2e997164e7c93bddbb43e195b38e1e6f10d7372e5a09c2ffdf54b27
```

Before invoking it, recheck that the current EX5 still has that exact hash and
that no pending/active `QM5_11434 / EURUSD.DWX / Q02` row exists.
