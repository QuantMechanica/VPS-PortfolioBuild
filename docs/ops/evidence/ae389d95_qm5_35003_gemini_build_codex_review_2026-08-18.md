# Codex review: QM5_35003 Gemini build

- Review task: `ae389d95-9df7-403d-8a0d-6da62c6e52e7`
- Gemini source task: `d761b379-3b40-4fd0-b91f-bbef202d5187`
- Source artifact: `docs/ops/evidence/d761b379_qm5_35003_build_ea_result_2026-08-17.md`
- Reviewed commit: `b4f5732d22ff12a9806383b56e1eb7e5b2e8a0b3`
- Source SHA-256: `4066e32da14be0a164df0b5d99f40a6b9f4b59fa090af66ed6bf76717ec368c5`
- EX5 SHA-256: `821621a1a6a0ea5746f5f20cc70e2752070c6a96203e4cd6fce43010ee39f852`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The requested review skills are not installed. Codex reviewed the approved
card, committed implementation, and current build evidence directly, then ran
the strict structural checks independently.

## Findings

### 1. High: the GMT rollover blackout is implemented in broker time

Card section 3.1 requires 23:55-00:05 GMT. Source lines 60-65 inspect raw
`TimeCurrent()` with `TimeToStruct`, so the EA instead blocks at Darwinex
server midnight (UTC+2/+3). The approved window is shifted by two or three
hours and drifts at DST. This requires the repository's DST-aware
broker-to-UTC/session conversion.

### 2. High: an ATR corridor silently replaces the exact SMA stop

The card requires the M5 SMA(60) baseline plus/minus exactly three pips. Source
lines 148-170 and 185-197 replace that price whenever its distance is outside
an invented 0.5-to-3.5 ATR corridor. This changes initial risk, lot sizing, TP,
and the +1R trigger. A broker-invalid exact stop should fail closed or follow a
card-authorized normalization rule; it must not become an ATR stop.

### 3. High: the card's loss limits are not enforced

There is no implementation of the card's 2.0% daily realized-loss entry halt,
2.5% maximum daily drawdown stop, or 5.0% total drawdown stop. The generic
framework call initializes different shared defaults and is not evidence of
the approved limits.

### 4. Medium: the no-trade gate disables open-position trailing

At source lines 325-327, rollover or expanded spread returns before the SMA
trailing hook runs. Those are entry filters in the card; an existing position's
protection should not be suspended by an entry-only condition.

### 5. High: strict build validation fails every setfile

Fresh `build_check.ps1 -SkipCompile` reports eight failures. Each of the four
AUDUSD, EURUSD, GBPUSD, and USDJPY backtest setfiles has an incomplete header
and is missing `build_hash`. Report:
`D:/QM/reports/framework/21/build_check_20260818_135645.json`.

## Independent verification

- Current EX5 size is 391,004 bytes, matching the source artifact.
- Build guardrails at the mandatory 336-hour news ceiling: PASS, zero findings.
- Strict static build check: **FAIL**, eight failures, zero warnings.
- All four setfiles still retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.

No Gemini code, setfile, registry, work item, or pipeline state was changed by
this review. The build requires strategy-fidelity and setfile rework and must
remain in REVIEW for independent close-out.
