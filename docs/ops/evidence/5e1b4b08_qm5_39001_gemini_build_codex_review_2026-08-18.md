# Codex review: QM5_39001 Gemini build

- Review task: `5e1b4b08-d5f4-420c-a0e0-765ee6f7e736`
- Gemini source task: `60d701a7-09cf-4b18-aaff-788ea1e799a5`
- Source artifact: `docs/ops/evidence/60d701a7_qm5_39001_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39001_forexfactory-trading-made-simple-tms.md`
- Reviewed tree HEAD: `56be1b34e03bf9bf3195f755da65326524bb9cc2`
- MQ5 SHA-256: `3d35f5f55581e79e656f3e8e79643b6da9f6ee44effaac634c4fb4169738a200`
- Fresh EX5 SHA-256: `5bf6b35574a922e8d744f3d95e26c8a51030f60bf633a0ad5a883df19719eb20`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: the open-position guard makes both managed exits unreachable

`Strategy_NoTradeFilter` returns true whenever the EA has an open position at
source lines 140-142. `OnTick` returns on that result at lines 336-337, before
calling `Strategy_ManageOpenPosition` at line 339. Consequently the approved
TDI exit and the implemented break-even lock at lines 215-276 cannot run while
there is a position to manage; live behavior falls back to the broker SL/TP.

### 2. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
`QM_FrameworkInit` path initializes the shared kill switch at 3.0% daily and
0.0% portfolio drawdown (`QM_Common.mqh` line 298), which is not the approved
contract.

### 3. High: the stop-distance cap can move the SL inside the required swing

The card requires the stop beyond the recent swing plus a 3-pip buffer. Lines
184-204 cap the distance at 3.5 ATR and then recompute the stop from entry. If
the swing-plus-buffer distance is larger, the cap places the stop inside the
authorized swing boundary and changes both the stop and 2R target.

### 4. High: the strict framework build gate fails

The fresh strict check reports two `EA_FRAMEWORK_RAW_SERIES_CALL` failures at
source lines 110-111 (`iLow` and `iHigh` without reviewer-approved annotations).
The producer's blanket build-pass claim is therefore not reproducible against
the current canonical framework gate.

### 5. High: reviewed source and binary have no committed identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. No commit binds
the reviewed source hash, freshly compiled binary, and producer evidence.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 399,136 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_164239/QM5_39001_forexfactory-trading-made-simple-tms.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: FAIL, two failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_164430.json`.
- Three active magic rows are collision-free and all three magic values are
  present in the generated resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated the untracked EX5 and refreshed only setfile
`build_hash` comments. No Gemini source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
