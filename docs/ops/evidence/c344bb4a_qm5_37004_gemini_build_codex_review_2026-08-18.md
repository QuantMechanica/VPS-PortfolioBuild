# Codex review: QM5_37004 Gemini build

- Review task: `c344bb4a-ff9f-4561-a47f-66e7c753a202`
- Gemini source task: `6d2369c0-a412-427e-afab-8c5feed10cc3`
- Source artifact: `C:/QM/repo/docs/ops/evidence/6d2369c0_qm5_37004_build_ea_2026-08-17.md`
- Reviewed tree HEAD: `59467c41c4e53ec72c6731c0378dc0f8c13c1e73`
- MQ5 SHA-256: `a79cd51d70b8ada686a08524c44de9603e3092df6a4c3c6f8e282a57485e2f60`
- Current EX5 SHA-256: `d46a00aeb2ac49268c66d3b0b98a570228c357f5eaf7003ea5b95ad3def3456a`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore reviewed the approved card,
implementation, producer result, registries, and focused checks directly.

## Findings

### 1. Critical: the named volatility target and half-Kelly sizing do not exist

The card requires annualized 20-day volatility, a 10% target, and a 0.50
fractional-Kelly multiplier in the position weight. The strategy inputs at
lines 44-51 contain neither volatility-target nor Kelly parameters. Entry
lines 113-160 provide only an ATR stop and leave size to the generic fixed-risk
framework. No rolling volatility or Kelly calculation exists anywhere in the
source. This is a different sizing model from the approved strategy.

### 2. High: exponential momentum is replaced by an endpoint price difference

The approved thesis specifies 12-month exponential momentum. Lines 67-72
compute only `Close[1] - Close[253]`, with no exponential weighting. The sign
can differ materially from the authorized momentum estimator.

### 3. High: the producer result is explicitly blocked and has no smoke evidence

`C:/QM/repo/artifacts/qm5_37004_build_result.json` has no smoke summary and a
non-empty `blocked_reason` from Custom-history admission. The canonical schema
therefore fails the mechanical build-result section; static compilation does
not establish a runtime verdict.

### 4. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path uses 3.0% daily and 0.0% portfolio drawdown instead.

### 5. Medium: entry-only filters can suspend the trailing stop

`OnTick` returns on rollover or expanded spread at lines 237-238 before
`Strategy_ManageOpenPosition` at line 240. The card's no-trade filters govern
entry; they do not authorize pausing the Chandelier/ATR protection on an open
position.

## Independent verification

- Fresh compile invocation: PASS, 0 errors / 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260818_152851/QM5_37004_volatility-targeted-momentum-kelly.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures / zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_152950.json`.
- Four active magic rows are collision-free and represented by the current
  generated-resolver hash.
- All four backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The tracked MQ5/EX5/SPEC identity exists, but the producer's blocked result
  still prevents acceptance; no runtime or pipeline verdict is inferred.

The compile orchestration refreshed only setfile `build_hash` comments. No
Gemini source, registry, work item, terminal, AutoTrading, or pipeline state
was changed.
