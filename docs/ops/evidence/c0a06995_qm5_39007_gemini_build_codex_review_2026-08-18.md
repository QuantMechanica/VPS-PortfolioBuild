# Codex review: QM5_39007 Gemini build

- Review task: `c0a06995-41e2-48df-a94b-aaec3b29fa62`
- Gemini source task: `8b09ed22-3d26-41a0-8eb3-d7df0bd66331`
- Source artifact: `docs/ops/evidence/8b09ed22_qm5_39007_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39007_forexfactory-100-pips-early-bird-breakout.md`
- Reviewed tree HEAD: `7a2d3512ce5712b7ecd34d31fe936afb6fb04565`
- Source build commit: `8269f225e`
- MQ5 SHA-256: `c9334ba0056785f07704789aeb55862b98e66b5491529fb89cacbbe8b99ea84e`
- Fresh EX5 SHA-256: `67ca627d8976fcdc3a6c7514f9ff288f988d43d1150b354536806930a1c76bba`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: every intended M15 run fails the declared D1 contract

The approved card, SPEC, and both setfiles use M15. `OnInit` nevertheless calls
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` at source lines 259-262.
The framework compares `_Period` to that value and fails closed on a mismatch
(`QM_Common.mqh` lines 457-465), after which the EA returns `INIT_FAILED`. The
producer's compile-only evidence does not establish a runnable M15 build.

### 2. Critical: the pending-order straddle was replaced by a market breakout

The card requires simultaneous BUY_STOP and SELL_STOP orders at 07:00 UTC,
three pips outside the completed box (card lines 61 and 89-93). The EA places
no pending orders. It waits until a later M15 bar closes across a boundary
(source lines 144-153/178), then submits one `QM_BUY` or `QM_SELL` request with
`price=0` and no expiration (lines 166-174/191-199). This misses intrabar
breakouts, removes the straddle/OCO lifecycle, and tests a different strategy.

### 3. Critical: the range includes the breakout bar and omits 05:00-05:15

The box is computed only when closed bar `[1]` is timestamped 07:00, which is
the first tick around 07:15. The scan then uses shifts 1 through 8 (source lines
84-95): 07:00-07:15 through 05:15-05:30. The approved eight-bar 05:00-07:00
window is shifts 2 through 9 at that moment. The implementation both looks at
the first breakout bar when setting its threshold and drops the first box bar.

### 4. Critical: all configured pip distances are ten times their labels

`QM_StopRulesPipsToPriceDistance` accepts whole pips and applies the broker
digit factor itself (`QM_StopRules.mqh` lines 39-50). Source lines 148-150 pass
the configured 3/25/50-pip values after multiplying each by ten, producing
30/250/500-pip distances. The SL is then altered by an undocumented ATR clamp
while the 500-pip TP remains fixed, so the claimed 1:2 payoff is also lost.
The break-even call at line 213 similarly converts 20 pips to 200 and uses a
10-pip profit buffer.

### 5. Critical: TP2 is absent and noon cancellation becomes forced exit

The card specifies +50-pip TP1, +100-pip TP2, and cancellation of unfilled
orders at 12:00 UTC (card lines 95-99). The EA has one position and one TP, with
no split/partial exit or TP2. Because it has no pending orders to cancel,
`Strategy_ExitSignal` instead returns true after noon and closes every active
position at market (source lines 217-227 and 292-303), an unapproved holding
rule.

### 6. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown
(`QM_Common.mqh` line 298), which is not the approved contract.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 395,546 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_172005/QM5_39007_forexfactory-100-pips-early-bird-breakout.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_172035.json`. The static gate
  does not currently detect the runtime contract, order-type, range-index, or
  pip-unit defects.
- Two active magic rows are collision-free and both values are present in the
  generated resolver.
- Both backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `2dbdc4a8762bf590e3639011a26b3986c25df69de7e3fb7f55e4cb3b38d5ddaa`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
