# Codex review: QM5_36004 Gemini build

- Review task: `80b2cb2a-07fc-4aa6-9df3-81aab754a622`
- Gemini source task: `22225e01-3ed6-4a1f-8fca-b55655117d01`
- Source artifact: `D:/QM/strategy_farm/artifacts/builds/22225e01-3ed6-4a1f-8fca-b55655117d01.json`
- Reviewed tree HEAD: `c4415c0f931ad4a5c27ca14d2bc06c42e5539fdc`
- Source SHA-256: `e90c6322920fc7b39fdc5a5634c61c28e823b1221ac1245b7f0738cad027793f`
- EX5 SHA-256: `a83f0c2b2088079e028605e414fae6f98b4e91ad5500bfab22f1b3b7e34896d4`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; no pipeline handoff**

The router-requested `code-review` and `gemini-output-review` skills are not
installed in this session. Codex therefore reviewed the approved card, current
implementation, producer result, and repository checks directly.

## Findings

### 1. Critical: the 50% TP1 plus runner is implemented as a full-position TP

The approved card requires a 50% partial close at +1 ATR, with the remaining
half protected and held for the QQE/ALMA exit. Source lines 281-307 instead put
a broker TP for the entire position at +1 ATR. No partial-close operation
exists. The break-even trigger at lines 323-359 is also +1 ATR, so the full TP
normally removes the position before there can be a runner. This changes the
strategy's payoff distribution and makes its principal exit path unreachable.

### 2. Critical: QQE state is substituted for the approved QQE crossover

Card sections 3.2-3.3 require `QQE Cross == UP/DOWN`. `Strategy_QQESignal`
(lines 93-163) computes only whether the current smoothed RSI is above or below
the current trail. It never calculates the preceding closed-bar relationship,
and entry lines 265-270 treat that persistent state as a new crossover. The EA
can therefore enter long after the authorized trigger bar.

### 3. High: the GMT rollover blackout is evaluated in broker time

Card section 3.1 requires 23:55-00:05 GMT. Lines 56-60 and 221-224 inspect raw
`TimeCurrent()` through `TimeToStruct`, which is Darwinex broker time (UTC+2 or
UTC+3). The blackout is shifted by two or three hours and drifts at DST.

### 4. High: the approved loss-limit contract is absent

The card requires a 2.0% daily realized-loss entry halt, a 2.5% daily hard
stop, and a 5.0% total-drawdown stop. The EA contains none of those thresholds.
Its generic `QM_FrameworkInit` path currently initializes the shared kill
switch at 3.0% daily and 0.0% portfolio DD, which is not the approved contract.

### 5. High: the producer result is explicitly blocked and has no smoke evidence

The source JSON has `smoke_report_path: null` and a non-empty `blocked_reason`
stating that Custom-history isolation prevented `run_smoke`. Under the
canonical `build_result.json` schema, a non-empty `blocked_reason` fails the
mechanical build-result section. Compilation and static-check claims cannot
erase that blocked state or establish a runtime verdict.

### 6. High: the reviewed source and binary have no committed identity

The MQ5, EX5, SPEC, and setfiles are untracked in the canonical checkout. The
current EX5 is 395,564 bytes, but no commit binds that binary and the reviewed
source. They require an intentional build commit and a fresh hash-bound result
after the code defects are repaired.

### 7. Medium: entry-only filters suspend protection and rule exits

`OnTick` returns on rollover or expanded spread at line 428 before the
break-even hook and QQE/ALMA exit at lines 430-440. Those conditions are
no-entry filters in the card; they do not authorize suspending management of
an existing position.

## Independent verification

- Build guardrails with `qm_news_stale_max_hours <= 336`: PASS, zero findings.
- SPEC validation: PASS.
- Strict static build check: PASS, zero failures/warnings; report
  `D:/QM/reports/framework/21/build_check_20260818_142617.json`.
- Four active magic rows are collision-free and each magic appears once in the
  generated resolver.
- All four backtest setfiles retain `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No smoke summary was supplied; no runtime or pipeline verdict is inferred.

No Gemini implementation, registry, work item, or pipeline state was changed.
