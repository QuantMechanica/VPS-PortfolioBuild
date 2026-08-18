# Codex review: QM5_41003 Gemini build

- Review task: `7c616d3f-20ef-449f-820b-3819beb800cc`
- Gemini source task: `8de78517-0995-43b1-9c4e-30e0a0f1b1df`
- Source artifact: `docs/ops/evidence/8de78517_qm5_41003_build_ea_result_2026-08-18.md`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41003_kaufman-ready-set-go-momentum.md`
- Reviewed tree HEAD: `e9f8ffb650847ad73dc7f89bee08c9b76cfb74ca`
- Source build commit: `306510c29`
- MQ5 SHA-256: `be9a3f245b6167b1731e080329c104c0ed92d8c1431f9f9102e4d2d2b23df689`
- Fresh EX5 SHA-256: `80eea2b6c7507d69b2203098fb0a4b735f03148aba8c1f5a7ccd3ed857d8fc83`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. Critical: the approved Ready statistic is replaced by ATR(30)

The card defines Ready as `ATR(10)[1] < SMA(ATR(10), 30)[1]` (card lines 61
and 76). Source lines 81-92 instead compare `ATR(10)[1]` directly with
`ATR(30)[1]`. A 30-period ATR is not the 30-sample simple average of the
10-period ATR series, so the volatility-compression regime and every entry are
materially different from the approved model.

### 2. Critical: the five-bar momentum input reads Close[6]

The card's Go test is `Close[1] - Close[5]` (card line 77). With the default
`strategy_momentum_bars=5`, source line 76 reads shift
`1 + strategy_momentum_bars`, i.e. `Close[6]`, while lines 96-101 label it as
Close[5]. Both long and short signals therefore use the wrong horizon.

### 3. High: missing close data leaves the prior signal armed

`AdvanceState_OnNewBar` returns at lines 78-79 before clearing
`g_last_signal` at line 87. If either close read is unavailable on a new bar,
the prior bar's signal and ATR remain cached and `Strategy_EntrySignal` can
submit that stale setup. Reset readiness/signal state before any fallible read
and fail closed for that bar.

### 4. High: the mandatory execution contract is undeclared

`OnInit` calls `QM_FrameworkInit` and then reports `INIT_OK` (source lines
195-216), but never calls `QM_FrameworkDeclareExecutionContract`. The H1 card
binding and Friday-close override therefore have no runtime mismatch check or
explicit declaration, contrary to the V5 fail-closed contract in
`QM_Common.mqh` lines 442-489. The strict static gate currently misses this.

### 5. High: the spread filter uses ATR(10), not the approved ATR(14)

The card specifies spread greater than 1.8 times H1 ATR(14) (card line 85).
Source lines 124-128 compare against cached `g_fast_atr`, which is ATR(10).
This changes entry eligibility precisely under the expansion conditions the
filter is intended to control.

### 6. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown
(`QM_Common.mqh` line 298), which is not the approved contract.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 390,182 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_172452/QM5_41003_kaufman-ready-set-go-momentum.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_172519.json`. The gate does
  not currently detect these card-formula or execution-contract differences.
- Three active magic rows are collision-free and all three values are present
  in the generated resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `cbaa8f6aae6a60a71d98c84d88091b7fffce30cf6421f084e47e67bea50690f5`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- The producer supplied no smoke summary. No runtime or pipeline verdict is
  inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
