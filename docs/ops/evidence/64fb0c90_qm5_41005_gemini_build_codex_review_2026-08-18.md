# Codex review: QM5_41005 Gemini build

- Review task: `64fb0c90-8022-45f3-b413-7f404fa3a82c`
- Gemini source task: `30ceeacd-0647-485a-9886-725af2139d61`
- Source artifact: `artifacts/builds/30ceeacd-0647-485a-9886-725af2139d61.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41005_richard-donchian-50day-cta-benchmark.md`
- Reviewed tree HEAD: `410ffe3c8c7aa87f91c16c2839fe7321bae4f952`
- Source build commit: `8269f225e`
- MQ5 SHA-256: `c7d7329e7b8d8d00bdac084061e3bc0e8a0c6fd0e6bf4deb8f37936eeed5df96`
- Fresh EX5 SHA-256: `12e35b8185adb912bc6023947a5cea20c5c7a540e16542669c924d1aa0b585d6`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. High: the mandatory execution contract is undeclared

`OnInit` calls `QM_FrameworkInit` and immediately reports `INIT_OK` (source
lines 150-159), but never calls `QM_FrameworkDeclareExecutionContract`. The V5
framework contract requires that fail-closed binding to the card timeframe and
an explicit Friday-close mode/reason (`QM_Common.mqh` lines 442-489). As built,
the D1 timeframe and the framework's unapproved Friday-close override have no
runtime declaration or mismatch check. The current strict static gate also
misses this omission.

### 2. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop (card lines 87 and 110-113). The EA
implements none. Its generic framework path supplies 3.0% daily and 0.0%
portfolio drawdown (`QM_Common.mqh` line 298), which is not the approved
FTMO-oriented capital-preservation contract.

### 3. High: the 20-day exit rescans raw history on every tick

`Strategy_ExitSignal` calls `QM_Sig_Range_Breakout` inside the position loop
(source lines 116-139), and `OnTick` invokes it before any new-bar gate (lines
168-200). The helper performs 20 `iHigh` plus 20 `iLow` reads. A D1 position
held for weeks therefore repeats 40 historical reads on every market tick even
though the signal can change only on a new D1 bar. Cache the opposite-channel
exit on the new-bar path to avoid deterministic tester-timeout exposure.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 387,442 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_172242/QM5_41005_richard-donchian-50day-cta-benchmark.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_172314.json`. The gate does
  not currently enforce the execution-contract declaration or include-helper
  hot-path scan.
- Four active magic rows are collision-free and all four values are present in
  the generated resolver.
- All four backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `136f86acf0fce1abaaf285591a15880fd935a5c29a51e2c5d762e44b8102e80c`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls in the EA source.
- Producer smoke was explicitly deferred to governed Q02 dispatch; no runtime
  or pipeline verdict is inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
