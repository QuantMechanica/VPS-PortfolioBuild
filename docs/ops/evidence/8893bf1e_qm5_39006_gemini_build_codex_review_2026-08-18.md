# Codex review: QM5_39006 Gemini build

- Review task: `8893bf1e-0f1b-4270-a0f5-559def0c771b`
- Gemini source task: `68f93e30-9d19-4c6c-885e-0591cc38e19f`
- Source artifact: `docs/ops/evidence/68f93e30_qm5_39006_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39006_forexfactory-spudfyre-stochastic-ribbon.md`
- Reviewed tree HEAD: `921c0952a584766542923feedfa423e71058bc53`
- Source build commit: `8269f225e`
- MQ5 SHA-256: `e9db73fadc3a554fff98f4566e194574d44b5c11a0bb5934ccf626aefc608310`
- Fresh EX5 SHA-256: `b742e5d64cc0b8d860ec936ba838a319e9a84814abb16861927d23050d9f2d26`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: every intended H1 run fails the declared D1 contract

The approved card, SPEC, and all three setfiles use H1. `OnInit` nevertheless
calls `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` at source lines
220-223. The framework compares `_Period` to that value and returns false on a
mismatch (`QM_Common.mqh` lines 457-465), after which this EA returns
`INIT_FAILED`. The producer's compile-only evidence therefore cannot establish
a runnable build; the intended H1 Q02 surface is deterministically blocked.

### 2. Critical: pip values are multiplied by ten before pip-based helpers

`QM_StopRulesPipsToPriceDistance` accepts whole pips and itself applies the
broker digit factor (`QM_StopRules.mqh` lines 39-50). Source line 115 passes
`3.0 * 10`, producing a 30-pip structural buffer instead of the approved 3
pips. Source line 182 similarly passes `20.0 * 10` to
`QM_TM_MoveToBreakEven`, so the claimed 20-pip trigger is actually 200 pips;
its literal buffer argument `10` moves the stop 10 pips beyond entry. This is
neither the producer summary nor the card's +1R break-even rule.

### 3. High: the ATR cap can move the stop inside the approved swing boundary

The card requires the stop beyond the recent H1 swing plus/minus 3 pips. Lines
124-129 and 151-156 cap the resulting distance at 3.5 ATR and recompute the
stop from entry. Whenever the structural boundary is farther away, the cap
places the stop inside it and changes the 2R target; failure to obtain a swing
also substitutes an undocumented 1.5 ATR stop.

### 4. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown
(`QM_Common.mqh` line 298), which is not the approved contract.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 394,780 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_171303/QM5_39006_forexfactory-spudfyre-stochastic-ribbon.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_171333.json`. The static gate
  does not currently detect the runtime timeframe-contract mismatch or the
  doubled pip conversion.
- Three active magic rows are collision-free and all three values are present
  in the generated resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `a6dec41b59edbf5b98351f934ddb54ee6a68aeb33445fc7b382ba77b09528c39`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
