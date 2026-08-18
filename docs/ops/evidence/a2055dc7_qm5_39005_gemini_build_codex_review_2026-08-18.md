# Codex review: QM5_39005 Gemini build

- Review task: `a2055dc7-5e44-4ba0-a130-235c9e6a2c75`
- Gemini source task: `57041b21-12da-464d-b275-c91cb3fa8673`
- Source artifact: `docs/ops/evidence/57041b21_qm5_39005_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_39005_forexfactory-genesis-matrix-scalper.md`
- Reviewed tree HEAD: `6608425c25bc2fc9b4522598b9ce60edae5aa022`
- Source build commit: `8269f225e`
- MQ5 SHA-256: `6e22f33987f1d3a3c2c270c54e234ca3d0d976bd9bad84c931a57c4e594f2224`
- Fresh EX5 SHA-256: `02857202a3fa0b120dc96108f6076eac15801240f07d7819828626a430ebb6fa`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: every intended M5 run fails the declared D1 contract

The approved card, SPEC, and both setfiles use M5. `OnInit` nevertheless calls
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` at source lines 344-347.
The framework compares `_Period` to that value and fails closed on a mismatch
(`QM_Common.mqh` lines 457-465), after which the EA returns `INIT_FAILED`. The
producer's compile-only evidence does not establish a runnable M5 build.

### 2. Critical: pip values are multiplied by ten before pip-based helpers

`QM_StopRulesPipsToPriceDistance` accepts whole pips and applies the broker
digit factor itself (`QM_StopRules.mqh` lines 39-50). Source line 228 passes
`2.0 * 10`, producing a 20-pip structural buffer instead of the approved 2
pips. Source line 293 passes `15.0 * 10` to `QM_TM_MoveToBreakEven`, so the
producer's claimed 15-pip trigger is actually 150 pips; the literal buffer
argument `10` then moves the stop 10 pips beyond entry. The card does not
authorize that fixed break-even mechanic.

### 3. High: matrix-data failures are converted into trading state

`CalculateTVI` explicitly returns false when its history copy is short (lines
76-104), but `AdvanceState_OnNewBar` ignores every TVI, T3-CCI, and GHL return
value at lines 172-190. Default zeros are then counted as bearish matrix
components and can force an open long's matrix exit or contribute to a false
short setup. Indicator readiness must fail closed for the entire bar rather
than silently becoming a score.

### 4. High: GHL neutral-state persistence is not implemented

The Gann High-Low Activator is stateful: direction persists while price is
between its high/low averages. `CalculateGHL` has no stored prior direction;
for the neutral band it derives direction solely from the immediately previous
close (lines 147-169), effectively treating any previous close above its low
average as UP. That proxy changes the fourth matrix color and therefore both
entries and mandatory matrix exits.

### 5. High: the ATR cap can move the stop inside the approved swing boundary

The card requires the stop beyond the recent M5 swing plus/minus 2 pips. Lines
236-241 and 262-267 cap the distance at 3.5 ATR and recompute from entry. When
the structural boundary is farther away, the cap places the stop inside it;
failure to obtain a swing also substitutes an undocumented 1.5 ATR stop.

### 6. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown
(`QM_Common.mqh` line 298), which is not the approved contract.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 402,028 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_171743/QM5_39005_forexfactory-genesis-matrix-scalper.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_171819.json`. The static gate
  does not currently detect the runtime timeframe mismatch, unit error, or
  ignored readiness results.
- Two active magic rows are collision-free and both values are present in the
  generated resolver.
- Both backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `e16edab5c15247864dff55c27835c79f939d3e4ab04c1e4217e9a19b488544b8`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
