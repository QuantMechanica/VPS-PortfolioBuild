# Codex review: QM5_35004 Gemini build

- Review task: `c7f41f38-507d-4b36-921b-2aefb42b206c`
- Gemini source task: `c2e1b160-70bb-49bf-afd2-6dc52e784ad5`
- Source artifact: `docs/ops/evidence/c2e1b160_qm5_35004_build_ea_result_2026-08-17.md`
- Reviewed commit: `fcae381938d5b464d5026e556b186ceb2d49768d`
- Source SHA-256: `7a8c80c5878c32528c1cce2396d988394f5add9ef806f724e694df21cde535a8`
- EX5 SHA-256: `d90ab915cd2642632fc122a381cf3aabc85d77a4118a7ce70f7880a3e62b6e70`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The requested review skills are unavailable, so Codex performed the mandatory
Gemini-code review directly against the approved card, source, repository
session-time contract, and strict build tools.

## Findings

### 1. Critical: all GMT strategy windows are evaluated in broker time

The card defines the Asian box as 00:00-06:00 GMT, entry as 07:00-09:00 GMT,
and mandatory close as 16:00 GMT. `CalculateAsianBox` uses raw `iTime` values
and `TimeToStruct` (lines 62-86); entry uses the same raw bar clock (150-155),
and exit uses raw `TimeCurrent` (295-301). There is no broker-to-UTC/GMT
conversion.

DXZ broker time is GMT+2/+3 and DST-aware, as recorded in
`docs/ops/CODEGEN_SYSTEMIC_BUG_PREVENTION_SPEC_2026-06-16.md`; that contract
requires `QM_BrokerToUTC` or the DST-aware session helpers. The EA therefore
builds the wrong six-hour box, enters in the wrong window, and closes at the
wrong instant, with a seasonal one-hour drift. This invalidates the strategy
identity.

### 2. High: the mandatory 16:00 exit is behind an entry-only filter

`OnTick` evaluates `Strategy_NoTradeFilter` at line 333 before calling
`Strategy_ExitSignal` at line 337. An expanded spread at 16:00 suppresses the
mandatory time exit. Position management and forced exits must be evaluated
before an entry-only spread/rollover gate.

### 3. High: incomplete Asian sessions are accepted and the midpoint stop is changed

The card defines the full 00:00-06:00 range (24 M15 bars). Lines 98-100 accept
only 16 bars, allowing a partial box. Lines 169-171 and 181-193/208-220 also
clamp the exact midpoint stop into an unapproved 0.5-to-4.0 ATR corridor. Both
choices change entries, risk, and exits without card authority.

### 4. High: strict build check fails all three setfiles

Fresh `build_check.ps1 -SkipCompile` reports six failures: every EURUSD,
GBPUSD, and USDCHF backtest setfile has an incomplete header and is missing
`build_hash`. Report:
`D:/QM/reports/framework/21/build_check_20260817_205355.json`.

## Independent verification

- Build guardrails at the mandatory 336-hour news ceiling: PASS, zero findings.
- Strict build check: **FAIL**, six failures, zero warnings as detailed above.
- Source and current EX5 sizes match the committed files, but the source
  artifact still supplies no commit hash, hashes, compiler log, or strict
  report path.

No source, setfile, registry, work item, or pipeline state was changed. The
build cannot advance; both the clock contract and strict setfile contract need
rework, followed by a new independently bound compile/build packet.
