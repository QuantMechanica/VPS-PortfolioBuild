# Codex review: QM5_35005 Gemini build

- Review task: `3281881e-4597-4243-9a2b-e8d7c4fa6360`
- Gemini source task: `da39e160-b043-4528-8592-4a23f672fc55`
- Source artifact: `framework/EAs/QM5_35005_sma-crossover-pullback-system/QM5_35005_sma-crossover-pullback-system.mq5`
- Reviewed tree HEAD: `6be2a520a1b9c957454c8e5a90c0b38fb2ecd9af`
- Source SHA-256: `deb2750e74c65a7cfe518844a6ca423df52e1fd0eed87d1862d2d106e1050d00`
- EX5 SHA-256: `28ef9a97341ab09666f4b8ac6a817bbdabe806c968fbc96279a0e1be0b2fbd59`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore reviewed the approved card and
current implementation directly and reran the available strict structural
checks.

## Findings

### 1. High: the reviewed source and binary have no committed identity

The MQ5, EX5, and SPEC are untracked in the canonical checkout. The source
task supplied the MQ5 path rather than a durable build-evidence packet and
supplied no commit, compiler report, or source/binary hashes. The current EX5
is 393,332 bytes, but there is no reproducible chain binding it to the reviewed
source. The build must be committed intentionally and recompiled into a
hash-bound evidence packet before it can be accepted.

### 2. High: the GMT rollover rule is evaluated in broker time

Card section 3.1 requires a 23:55-00:05 GMT blackout. Source lines 66-71 pass
raw `TimeCurrent()` through `TimeToStruct`, which is Darwinex broker time and
changes between UTC+2 and UTC+3. The blackout therefore occurs two or three
hours away from the approved window and drifts at DST. Use the repository's
DST-aware broker-to-UTC/session helper.

### 3. High: the card's loss limits are not implemented

The card requires an entry halt at 2.0% daily realized loss, a 2.5% maximum
daily drawdown hard stop, and a 5.0% maximum total drawdown stop. The EA has no
card-specific calculation or thresholds. Its generic `QM_FrameworkInit` path
currently initializes the shared kill switch at a 3.0% daily threshold and no
local portfolio-DD threshold (`QM_Common.mqh`, line 298), which is not the
approved contract.

### 4. Medium: entry-only filters suspend trailing management

`OnTick` returns on rollover or expanded spread at line 210 before calling the
150-pip trailing logic at line 212. The card defines those conditions as a
no-entry/idle filter, not permission to suspend protection of an open trade.

## Independent verification

- Build guardrails with the mandatory 336-hour news ceiling: PASS, zero
  findings.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_135658.json`.
- All three backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.

No Gemini implementation, registry, work item, or pipeline state was changed.
The structural checks do not resolve the time, risk, or provenance failures;
the build remains REVIEW-only for independent close-out.
