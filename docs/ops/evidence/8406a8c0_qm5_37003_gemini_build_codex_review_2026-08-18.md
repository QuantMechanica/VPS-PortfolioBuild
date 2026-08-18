# Codex review: QM5_37003 Gemini build

- Review task: `8406a8c0-a126-46ed-858b-6515bb6a5528`
- Gemini source task: `6b9b31bd-8511-4f7b-8400-9e42162b0bd1`
- Source artifact: `C:/QM/repo/docs/ops/evidence/6b9b31bd_qm5_37003_build_ea_2026-08-17.md`
- Reviewed tree HEAD: `59467c41c4e53ec72c6731c0378dc0f8c13c1e73`
- MQ5 SHA-256: `978f434bc3a2a62bd277c4048f51ae5f9c5d57ddc167d3e5251b8c4b9affedd6`
- Current EX5 SHA-256: `f73bf23358e95c26bc37bafac1fed908a7ea636b6ba4aa0fa69cb860ee9acff5`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore reviewed the approved card,
implementation, producer result, registries, and focused checks directly.

## Findings

### 1. High: the producer result is explicitly blocked and has no smoke evidence

`C:/QM/repo/artifacts/qm5_37003_build_result.json` has no smoke summary and a
non-empty `blocked_reason` stating that Custom-history admission refused the
standalone smoke. Under the canonical build-result schema, that fails the
mechanical build-result section. Static compilation cannot erase the blocked
state or establish a runtime verdict.

### 2. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA implements none. Its generic
framework path uses 3.0% daily and 0.0% portfolio drawdown instead.

### 3. High: invalid midline targets are silently replaced by an unauthorized 1.5R exit

The approved mean-reversion TP is the Bollinger midline. Lines 211-224 replace
that target with `QM_TakeRR(..., 1.5)` when the cached midline is not beyond the
current quote. The card does not authorize a fixed-R fallback; that condition
must reject the entry or be specified upstream.

### 4. Medium: entry-only filters can suspend the Bollinger exit manager

`OnTick` returns on rollover or expanded spread at lines 338-339 before
`Strategy_ManageOpenPosition` at line 341. That manager enforces the midline
exit. Card no-trade filters govern entries and do not authorize leaving open
exposure unmanaged during a wide spread or rollover window.

## Independent verification

- Fresh compile invocation: PASS, 0 errors / 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260818_152754/QM5_37003_hurst-exponent-dynamic-regime-switch.compile.log`.
- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures / zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_152939.json`.
- Three active magic rows are collision-free and represented by the current
  generated-resolver hash.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- The tracked MQ5/EX5/SPEC identity exists, but the producer's blocked result
  still prevents acceptance; no runtime or pipeline verdict is inferred.

The compile orchestration refreshed only setfile `build_hash` comments. No
Gemini source, registry, work item, terminal, AutoTrading, or pipeline state
was changed.
