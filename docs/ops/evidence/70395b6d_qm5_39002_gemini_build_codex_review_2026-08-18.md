# Codex review: QM5_39002 Gemini build

- Review task: `70395b6d-ee55-4906-bb55-91d75157213b`
- Gemini source task: `92af0f37-cfdf-41b4-b187-0fd19f00b722`
- Source artifact: `docs/ops/evidence/92af0f37_qm5_39002_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39002_forexfactory-sonic-r-system.md`
- Reviewed tree HEAD: `56be1b34e03bf9bf3195f755da65326524bb9cc2`
- MQ5 SHA-256: `40b4de9be6e7423feb443590d3f613c476eae8949efb886c67f529c24aa5a1bb`
- Fresh EX5 SHA-256: `13be3036433bb6cdd8182170b530cbf5278b69d8dde89acf59cc7611d2b1471d`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: the open-position guard makes break-even management unreachable

`Strategy_NoTradeFilter` returns true whenever an open position exists at
source lines 107-109. `OnTick` returns at lines 288-289 before calling
`Strategy_ManageOpenPosition` at line 291. The approved +1R break-even logic at
lines 182-229 therefore cannot execute while a trade is open.

### 2. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. The generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown instead.

### 3. High: the stop-distance cap can move the SL inside the Dragon boundary

The card requires the stop beyond the outer Dragon edge plus 3 pips. Lines
151-171 cap the distance at 3.5 ATR and recompute the stop from entry. When the
Dragon-plus-buffer distance is larger, the cap places the stop inside the
authorized boundary and changes the 2.5R target.

### 4. High: the strict framework build gate fails

The fresh strict check reports three `EA_FRAMEWORK_RAW_SERIES_CALL` failures at
source lines 74-76 (`iClose`, `iLow`, and `iHigh` without reviewer-approved
annotations). The producer's blanket build-pass claim is not reproducible
against the current canonical framework gate.

### 5. High: reviewed source and binary have no committed identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. No commit binds
the reviewed source hash, freshly compiled binary, and producer evidence.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 397,246 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_164346/QM5_39002_forexfactory-sonic-r-system.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: FAIL, three failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_164504.json`.
- Three active magic rows are collision-free and represented in the generated
  resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated the untracked EX5 and refreshed only setfile
`build_hash` comments. No Gemini source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
