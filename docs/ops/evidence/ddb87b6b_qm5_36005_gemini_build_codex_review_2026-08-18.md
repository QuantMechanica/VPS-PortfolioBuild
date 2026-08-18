# Codex review: QM5_36005 Gemini build

- Review task: `ddb87b6b-a6db-4f8d-be8f-337341238a8c`
- Gemini source task: `cf9b27fd-11f6-465b-9731-8e551bb9c671`
- Source artifact: `D:/QM/strategy_farm/artifacts/builds/cf9b27fd-11f6-465b-9731-8e551bb9c671.json`
- Reviewed tree HEAD: `c4415c0f931ad4a5c27ca14d2bc06c42e5539fdc`
- Source SHA-256: `9e9d0716288e0be36f61e9240bd24963f9ea7efd85a4eb778e78a274416809b1`
- EX5 SHA-256: `767293967529ab5d8ff4fd9efb586b4a750d8676d658275efb1ac2d0b8796d57`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

Neither task-named review skill is installed, so Codex performed the mandatory
Gemini-code review directly against the card, source, producer result, and
strict repository checks.

## Findings

### 1. Critical: TP1 closes 100%, eliminating the approved runner

The card requires a 50% close at +1 ATR and a runner that exits on Trend Lord
color change. Lines 239-265 put a +1 ATR broker TP on the whole order and never
call a partial-close helper. The +1 ATR break-even trigger at lines 281-317 is
at the same level, so normal execution leaves no runner for the indicator exit.

### 2. High: a six-stage T3 replaces the card's Coral SMMA

The approved mathematical definition calls Coral an SMMA-smoothed baseline at
period 20 and coefficient 0.4. Lines 73-121 instead run six recursive EMAs and
combine them with T3 coefficients. That is a different filter with different
lag and turning points. The SPEC's later `SMMA/T3` wording cannot amend the
approved card after the fact.

### 3. High: Woodies CCI is added as an unauthorized runner exit

Card section 3.4 specifies only a Trend Lord color change for the runner.
Lines 328-349 close longs whenever CCI is below zero and shorts whenever it is
above zero. This additional exit can truncate trades even when Trend Lord has
not changed color and therefore changes the approved strategy.

### 4. High: the GMT and loss-limit contracts are missing

Lines 59-63 and 176-179 interpret broker `TimeCurrent()` as GMT, shifting the
23:55-00:05 window by UTC+2/+3. The EA also contains none of the card's 2.0%
daily entry halt, 2.5% daily hard stop, or 5.0% total-DD stop.

### 5. High: the producer result is blocked and no smoke ran

The source JSON has `smoke_report_path: null` and a non-empty
`blocked_reason` stating Custom-history isolation prevented `run_smoke`.
Canonical build-result rules therefore fail the result regardless of its
compile booleans, and no runtime behavior has been established.

### 6. High: the reviewed build is untracked

The MQ5, EX5, SPEC, and setfiles have no committed identity in the canonical
checkout. The current EX5 is 396,246 bytes, but it is not reproducibly bound to
the reviewed source. Rework must be committed and produce a fresh hash-bound
build result.

### 7. Medium: entry-only filters can suppress protection and exits

`OnTick` returns on rollover or expanded spread at line 385 before break-even
management and the Trend Lord/CCI exit at lines 387-397. The card does not
authorize those entry filters to suspend an open position's lifecycle.

## Independent verification

- Build guardrails at the mandatory 336-hour news ceiling: PASS.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_142702.json`.
- Three active magic rows are collision-free and appear once each in the
  generated resolver.
- All three backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No smoke summary was supplied; no runtime or pipeline verdict is inferred.

No Gemini code, registry, work item, or pipeline state was changed.
