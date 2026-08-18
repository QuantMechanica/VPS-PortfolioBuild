# Codex review: QM5_36002 Gemini build

- Review task: `b7868b8c-cd0e-4f22-b764-fe8a7d53408a`
- Gemini source task: `f7849572-7aad-4e79-ad7f-8c6d1fccf935`
- Source artifact: `docs/ops/evidence/f7849572_qm5_36002_build_ea_result_2026-08-17.md`
- Reviewed commit: `e0f0d81a719aed620141a2d5514dd50dc38b7852`
- Source SHA-256: `05c216d6b8368399379dd20533f6a2b44bd9b7117fc25b154f18b91a1c571c06`
- EX5 SHA-256: `306f9836ee139e90cd52fa9c4294be9d5b18220d8aaff71cf3ce5492e77ed5ee`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested review skills are not installed, so Codex reviewed the
approved card and committed build directly and reran the available strict
checks.

## Findings

### 1. Critical: the 50% TP1 plus runner is implemented as a full-position TP

The approved card requires a 50% close at +1 ATR and a runner that exits on a
Kijun re-cross. Lines 206-232 put a +1 ATR broker TP on the complete order and
there is no partial-close operation. Break-even is also triggered at +1 ATR at
lines 248-284, so the entire position normally closes before a runner exists.

### 2. High: the Damiani gate is materially weakened

The exact card rule is `Volat > AntiThresh`. Lines 124-134 instead return true
when `vol > anti OR vol >= 1.0`. The second disjunct admits trades whenever the
short ATR merely exceeds the long ATR, including cases where the approved
anti-threshold comparison is false. That is an unauthorized expansion of the
entry population.

### 3. High: the GMT rollover rule is implemented in broker time

Lines 56-60 and 142-145 pass `TimeCurrent()` directly to `TimeToStruct`.
Darwinex server time is UTC+2/+3, so the required 23:55-00:05 GMT blackout is
shifted and changes at DST.

### 4. High: the approved loss limits are absent

The EA does not implement the card's 2.0% daily realized-loss entry halt, 2.5%
daily drawdown hard stop, or 5.0% total drawdown stop. The shared framework is
initialized at different defaults and is not evidence of those thresholds.

### 5. High: strict build validation fails four raw-series calls

Fresh `build_check.ps1 -SkipCompile` rejects unannotated `iHigh`, `iLow`, and
`iClose` calls at source lines 80, 81, 96, and 97. Report:
`D:/QM/reports/framework/21/build_check_20260818_142639.json`.

### 6. Medium: entry-only filters suspend protection and the Kijun exit

`OnTick` returns on rollover or expanded spread at line 355 before the
break-even hook and Kijun exit at lines 357-367. The card does not authorize an
entry filter to suspend management of existing exposure.

## Independent verification

- Current EX5 size is 394,118 bytes, matching the source artifact.
- Build guardrails with the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: **FAIL**, four failures, zero warnings.
- Four active magic rows are collision-free and occur once each in the
  generated resolver.
- All four backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No smoke summary was supplied; no runtime or pipeline verdict is inferred.

No Gemini code, setfile, registry, work item, or pipeline state was changed.
