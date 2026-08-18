# Codex review: QM5_41009 Gemini build

- Review task: `1bd8fddf-b1b4-4bab-ad15-d0fc10da1e98`
- Gemini source task: `0fd1b0a8-c415-4309-9778-4ebefa05a1cf`
- Source artifact: `artifacts/builds/0fd1b0a8-c415-4309-9778-4ebefa05a1cf.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41009_volume-profile-value-area-rejection.md`
- Reviewed tree HEAD: `3797a34b4ec2e74192e07138d6300753694cadc6`
- Source build commit: `8269f225e`
- MQ5 SHA-256: `de66a2e42717f59343968a6c55b50f3f6430ff51ecc51c871abf4dabd754457f`
- Fresh EX5 SHA-256: `da2ad0e1343ffaf9b466e0de4bbbbc09871214754b5e4d07b549de174b7266c8`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused checks directly.

## Findings

### 1. High: the mandatory execution contract is undeclared

The profile, entries, and ATR all use `PERIOD_CURRENT`, but `OnInit` calls
`QM_FrameworkInit` and reports `INIT_OK` without ever calling
`QM_FrameworkDeclareExecutionContract` (source lines 380-389). The approved M5
binding and Friday-close override therefore have no runtime mismatch check or
explicit declaration, contrary to the V5 fail-closed contract in
`QM_Common.mqh` lines 442-489. Running this source on any other chart timeframe
silently changes the profile and strategy.

### 2. High: an unapproved 1.8R target replaces an invalid POC setup

The card's TP is the previous day's POC (card lines 95-98). When POC is not on
the profitable side of entry, source lines 295 and 312 substitute a fixed 1.8R
target. That is a different exit with no card authorization. Such a setup
should fail closed or the card must explicitly specify and approve the
fallback before it is tested.

### 3. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path supplies 3.0% daily and 0.0% portfolio drawdown
(`QM_Common.mqh` line 298), which is not the approved contract.

### 4. Medium: the profile-capacity rejection is unevidenced for both targets

`BuildPriorProfile` rejects any prior session requiring more than 500 buckets
(source lines 91 and 132-134), with a default bucket width of ten quote points.
The producer provided no symbol-spec or representative-day evidence that
SP500.DWX and NDX.DWX daily ranges stay inside that limit. Because rejection
sets `g_profile_valid=false` and suppresses every entry, this needs a focused
capacity fixture before Q02 to exclude a systematic zero-trade build defect.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 393,208 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_173121/QM5_41009_volume-profile-value-area-rejection.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_173152.json`.
- Two active magic rows are collision-free and both values are present in the
  generated resolver.
- Both backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The approved-card copy in Git matches the canonical approved card byte for
  byte (SHA-256 `3f19ad956bd58417f0de5ba9ac2ab7bb68a12a3ce35f323ba5e9d7c3d3be8cf7`).
- Focused forbidden scan found no direct indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML calls.
- Producer smoke was explicitly deferred to governed Q02 dispatch. No runtime
  or pipeline verdict is inferred, and no active tester was interrupted.

Fresh compilation regenerated only the tracked EX5 and refreshed setfile
`build_hash` comments. No Gemini MQ5 source, registry, resolver, work item,
terminal, AutoTrading, or pipeline state was changed.
