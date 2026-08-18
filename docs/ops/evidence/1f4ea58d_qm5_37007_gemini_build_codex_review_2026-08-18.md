# Codex review: QM5_37007 Gemini build

- Review task: `1f4ea58d-721b-4093-bea0-50a4558c1e9a`
- Gemini source task: `43dce7e4-3d61-4362-ad12-a4504e3e5137`
- Source artifact: `C:/QM/repo/artifacts/builds/43dce7e4-3d61-4362-ad12-a4504e3e5137.json`
- Reviewed tree HEAD: `59467c41c4e53ec72c6731c0378dc0f8c13c1e73`
- MQ5 SHA-256: `6bae90c742cae885c9a2e379e3b05c6e73cc9fbd488ac8d422f169a49f3c0c9b`
- Fresh EX5 SHA-256: `7cf9fa0d17241f046713920802725bf0b9e8f8e2ab84cd8d6f027686f4a41b17`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore reviewed the approved card,
implementation, producer result, registries, and focused checks directly.

## Findings

### 1. Critical: weekly factor rebalancing is absent and replaced by a fixed 2R TP

The approved exit is dynamic rebalancing at the end of each weekly cycle.
Lines 227-249 instead attach a full-position broker TP at twice the ATR stop,
while `Strategy_ExitSignal` always returns false at lines 259-262. There is no
week boundary, reranking exit, or removal of symbols that leave the selected
tails. This materially replaces the factor strategy's holding rule.

### 2. High: missing cohort data silently changes the strategy to time-series momentum

When fewer than two universe members are available, lines 140-170 rank the
host symbol's current return against its own prior returns and authorize entry.
The card defines a cross-sectional rank across seven symbols. Missing cohort
data must fail closed; it does not authorize a different time-series model.

### 3. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path uses 3.0% daily and 0.0% portfolio drawdown instead.

### 4. High: the reviewed source and binary have no committed identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. No commit binds
the reviewed source hash, rebuilt binary, and producer result.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 391,448 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_152720/QM5_37007_cross-sectional-momentum-factor-dispersion.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures and two call-graph warnings;
  report `D:/QM/reports/framework/21/build_check_20260818_152932.json`.
  Both warned `CopyClose` helpers are called only from
  `AdvanceState_OnNewBar()` after the new-bar gate.
- Seven active magic rows are collision-free and represented by the current
  generated-resolver hash.
- All seven backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The producer JSON satisfies the static build-result criteria but supplies no
  smoke summary (`smoke_result=deferred_p2_smoke`); no runtime or pipeline
  verdict is inferred.

Fresh compilation regenerated the untracked EX5 and refreshed only setfile
`build_hash` comments. No Gemini source, registry, work item, terminal,
AutoTrading, or pipeline state was changed.
