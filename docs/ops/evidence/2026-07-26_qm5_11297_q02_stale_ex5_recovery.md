# QM5_11297 Q02 stale-EX5 recovery

- Recovery target: `QM5_11297_cs-sma9-cross`, `EURUSD.DWX`, Q02
- Claimed failed work item: `9f6319af-be04-487b-b9f1-1a8b4c3cdebd`
- Prior evidence: `D:\QM\reports\work_items\9f6319af-be04-487b-b9f1-1a8b4c3cdebd\QM5_11297\20260726_022354\summary.json`
- Prior verdict: `INFRA_FAIL` (`ONINIT_FAILED`, `INCOMPLETE_RUNS`)
- Prior deployed EX5 SHA-256: `80ef280c40eba29656622a611850d5e5f38115ae0e8e263632ea9bb1c3399ef8`
- Diagnosis: the source and binary dated 2026-06-25 predated the current shared V5 framework includes. Rebuilding in place refreshes the statically linked framework code without changing card-authorized strategy logic.
- Command: `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_11297_cs-sma9-cross/QM5_11297_cs-sma9-cross.mq5 -Strict`
- Result: `PASS`, 0 errors, 0 warnings
- Compile log: `framework/build/compile/20260726_110339/QM5_11297_cs-sma9-cross.compile.log`
- Fresh EX5 SHA-256: `56b36db142f0d8d72425d5fbf03bf732fb33318e4a9339f3f65addc0c82e3fd0`
- MQ5 SHA-256: `448d6e662a3ed56e19abb337de3e19076a5342243c5722ef1810bde657df572c`
- Backtest setfile SHA-256: `386ff49dc3a94c08a5cc4f12ae565ec025fdface1517ab486a26728c0a12d7e9`
- Risk contract: canonical backtest setfile retained (`RISK_FIXED`); no live files or controls touched.

- Replacement Q02 work item: `b7c42446-cfd8-4a63-a756-cd55bd16238c` (`pending`)

No backtest was run by this recovery unit.
