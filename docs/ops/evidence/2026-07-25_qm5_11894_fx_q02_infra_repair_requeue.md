# QM5_11894 diverse-FX Q02 infrastructure repair

Date: 2026-07-25  
Branch: `agents/board-advisor`  
Farm claim: `db10c130-fd12-40b4-8da4-ff14c66cbc29`

## Selection

- No approved forex, crypto, rates, or market-neutral build card remained both
  unbuilt and pre-allocated in the deterministic registries.
- `QM5_11894_carter-55-smma-channel-wpr-stoch` had no competing repair claim.
- Its latest EURUSD Q02 item
  `319464cf-a89c-43cc-9860-6e6694ffcf04` ended `INFRA_FAIL` with
  `NO_HISTORY;INCOMPLETE_RUNS`; it did not produce an economic strategy verdict.
- The source and deployed EX5 matched, but the EX5 dated 2026-07-09 and predated
  the current framework and runner. This made a stale-binary refresh the smallest
  safe recovery unit.

## Repair

- Recompiled the unchanged structural H1 strategy against the current framework.
- Regenerated the canonical backtest setfiles. They remain `ENV=backtest`,
  `RISK_FIXED=1000`, and `RISK_PERCENT=0`.
- No strategy mechanics, portfolio gates, deploy manifests, live setfiles,
  T_Live files, terminal settings, or AutoTrading state were changed.

## Deterministic evidence

- Strict compile: `D:\QM\reports\compile\20260725_143239\summary.csv`
  (`PASS`, 0 errors, 0 warnings)
- Final build check:
  `D:\QM\reports\framework\21\build_check_20260725_143302.json`
  (`PASS`, 0 failures, 0 warnings)
- MQ5 SHA256:
  `f173ddf81e32db84c1b4113dc0a9a7e55a177448093d9d5deb7463fef65c90f0`
- Refreshed EX5 SHA256:
  `ecee3433f4ff13a5d4bb9e75604bc279c471e04e2d9844cb3aff3befb24bea69`
- EURUSD setfile SHA256 after final build check:
  `c8b32f27125cfb5d7c767c4f4ec9ed4cb6d0bd70eb4ac9b92c953dcd23d2f956`
- Capacity check immediately before handoff: only T1 and T9 were running factory
  tester processes; the ten-terminal CPU ceiling was not reached.

## Handoff rule

Create exactly one fresh EURUSD Q02 work item only if no pending or active sibling
exists at insertion time. The factory, not this repair wake, runs the backtest.
