# Codex review: QM5_36006 Gemini build

- Review task: `599e1cb1-ab22-4d53-88f1-c39cd9e51dcb`
- Gemini source task: `0d34c3bd-8853-499b-b357-aa59d82fb534`
- Source artifact: `docs/ops/evidence/0d34c3bd_qm5_36006_build_ea_result_2026-08-17.md`
- Reviewed tree HEAD: `07a691f79257a7f798b129f674e800769de5269b`
- Source SHA-256: `601e9a37f7a326b57a099b55e9e28cbe02dfab6d42f7dfa916220b4ac39b8cbb`
- Fresh EX5 SHA-256: `287e1a11af8421bd061d6090abf2c3bac090c7d1bf364804c9106f68c9f47583`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested review skills are unavailable. Codex independently
reviewed the approved card, Gemini evidence, source, binary, and focused V5
checks.

## Findings

### 1. Critical: TP1 closes the complete position, leaving no runner

The card requires a 50% close at +1 ATR, break-even protection, and a remaining
HalfTrend runner. Entry lines 267-294 attach a +1 ATR broker TP to the entire
order, and no partial-close operation exists. Break-even is triggered at the
same +1 ATR level at lines 309-346, so the full broker TP normally removes the
position before a runner can survive.

### 2. Critical: the implemented HalfTrend is not the card's stated formula

The card defines `EMA(P,2) +/- 2.0 * ATR(100)`. Lines 82-121 instead run a
custom high/low hysteresis using SMA(high/low), and line 101 reduces the ATR
deviation to `ATR / 100`. It neither calculates the stated EMA baseline nor
uses the stated two-ATR displacement, changing both entry and runner exits.

### 3. High: the purported Jurik JMA is a triple-EMA/TEMA expression

`Strategy_JMA` at lines 125-145 applies a fixed EMA alpha three times and
returns `3*e1 - 3*e2 + e3`. It contains none of the adaptive phase/power
mechanics needed to establish a Jurik moving average. The resulting velocity
is an invented TEMA derivative, not the approved Jurik Velocity confirmation.

### 4. High: the producer's build-check claim is false under the current strict gate

Fresh strict `build_check.ps1 -SkipCompile` fails 10 unreviewed raw-series
calls at lines 78, 79, 88, 97, 98, 138, 164, 165, 189, and 190. Report:
`D:/QM/reports/framework/21/build_check_20260818_150559.json`. The source
artifact is also prose Markdown rather than the canonical build-result JSON,
so it cannot supply `build_check_passed` and `compile_succeeded` fields.

### 5. High: a full HalfTrend history walk runs on every tick

`Strategy_ExitSignal` rebuilds the 50-bar HalfTrend state at lines 356-359,
and `OnTick` calls it at line 419 before the new-bar gate at line 441. The
nested raw-series and pooled-indicator reads therefore repeat on every D1
tick while a position is open.

### 6. High: GMT and loss-limit contracts are not implemented

Lines 209-212 interpret raw broker `TimeCurrent()` as the card's GMT rollover
window. The EA also lacks the required 2.0% daily entry halt, 2.5% daily hard
stop, and 5.0% total-drawdown stop.

### 7. Medium: entry-only filters suspend management and exits

`OnTick` returns on rollover or expanded spread at line 415 before break-even
and HalfTrend exit handling at lines 417-429. Existing exposure can therefore
remain unmanaged because an entry filter is active.

### 8. High: the reviewed build is untracked

The MQ5, EX5, SPEC, and setfiles have no committed identity in the canonical
checkout. They must remain review-only until a repaired, hash-bound build is
committed by the authorized close-out path.

## Independent verification

- Fresh compile: PASS, 0 errors / 0 warnings; EX5 size 396,220 bytes; log
  `C:/QM/repo/framework/build/compile/20260818_145840/QM5_36006_nnfx-halftrend-jurik-coppock-engine.compile.log`.
- Build guardrails at `qm_news_stale_max_hours <= 336`: PASS.
- SPEC validation: PASS.
- Strict static build check: **FAIL**, 10 failures, zero warnings.
- Three active magic rows are collision-free and present in the resolver.
- All three backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No smoke summary was supplied; no runtime or pipeline verdict is inferred.

Fresh compilation regenerated the untracked EX5 only. No Gemini source,
setfile, registry, work item, terminal, AutoTrading, or pipeline state was
changed.
