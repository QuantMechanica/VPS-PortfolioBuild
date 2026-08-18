# Codex review: QM5_41001 Gemini build

- Review task: `fc3ed902-4615-4349-ad96-634e1a20710a`
- Gemini source task: `9fbca489-f822-4412-8066-a819bc100eb7`
- Source artifact: `docs/ops/evidence/9fbca489_qm5_41001_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41001_keith-fitschen-aberration-trading-system.md`
- Reviewed tree HEAD: `977ec37b150e950a2ecc54f64458ca3e58e974eb`
- Source build commit: `306510c29`
- MQ5 SHA-256: `4af795c44849d0081b4f4e4c2d4b92b687384b188439b9ca6aad35a5516426f4`
- Fresh EX5 SHA-256: `70fd2e84827eb3c5d70cec7cfcb9e35bb81d772805b1eba367762c494f7b7925`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: the open-position filter makes the midline exit unreachable

`Strategy_NoTradeFilter` returns true whenever this EA has an open position
(source lines 114-116). `OnTick` returns on that result at lines 272-273 before
calling `Strategy_ManageOpenPosition` at line 275. The approved SMA(30)
midline close implemented at lines 178-213 can therefore never execute while
there is a position to close. The same early return prevents the cached D1
bands and close from advancing for the duration of the trade.

### 2. Critical: a fixed 8R TP replaces the approved open-ended trend exit

The card explicitly specifies open-ended trend riding with no fixed TP and an
SMA(30) midline exit (card lines 95-99). Source line 41 defaults
`strategy_tp_rr_mult` to 8.0, and lines 159-168 attach that broker TP to every
entry. Because the midline exit is unreachable, actual behavior reduces to the
2.5 ATR broker SL or the unapproved 8R TP. The producer summary does not
disclose this fixed target.

### 3. High: the mandatory execution contract is undeclared

`OnInit` calls `QM_FrameworkInit` and then reports `INIT_OK` (source lines
229-250), but never calls `QM_FrameworkDeclareExecutionContract`. The D1 card
binding and Friday-close override therefore have no runtime mismatch check or
explicit declaration, contrary to the V5 fail-closed contract in
`QM_Common.mqh` lines 442-489. The strict static gate currently misses this.

### 4. High: missing close data leaves the prior signal armed

`AdvanceState_OnNewBar` returns at lines 80-81 before clearing
`g_last_signal` at line 92. If either close read is unavailable on a new bar,
the previous setup and ATR remain cached and can be submitted as a stale entry.
Reset readiness and signal state before any fallible read and fail closed for
that bar.

### 5. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown
(`QM_Common.mqh` line 298), which is not the approved contract.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 390,290 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_172658/QM5_41001_keith-fitschen-aberration-trading-system.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_172726.json`. The gate does
  not currently detect the unreachable lifecycle or undeclared contract.
- Three active magic rows are collision-free and all three values are present
  in the generated resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `507d7627dd5b6ba738c0601cbf537ca707fb7c57d54704bbb1da6a4132b3bbfc`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
