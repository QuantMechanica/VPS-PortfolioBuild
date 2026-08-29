# QM5_41198 WTI diversity build and Q02 handoff

Date: 2026-08-29

Branch: `agents/board-advisor`

Build task: `084ae29d-4ecb-4dcf-829f-2ccfaec060a3`

EA: `QM5_41198_collins-66mom-opt`

Outcome: **COMPILE_OK; exactly one fixed-risk XTIUSD.DWX Q02 row pending**

## Selection and collision control

The farm claim guard accepted the sole open build task for this EA and an
atomic paced-fleet claim assigned it to `codex:agents/board-advisor`. The card
is G0 APPROVED with bare PASS values for R1-R4, the deterministic EA registry
contains `41198,collins-66mom-opt`, and magic slot 0 is active for
`XTIUSD.DWX` as magic `411980000`. There were no prior work items for this EA
at claim time.

This was the highest-diversity clean build candidate after governed refusals
on stale/authority-exhausted FX candidates. It adds outright WTI exposure,
which satisfies the mission's explicit preference for energy beyond XNG. It
does not assert portfolio decorrelation or certification.

The approved derivative retains every trading rule from parent
`QM5_20266_collins-66mom`. Its only authorized behavioral surface is six
closed-D1 pattern-permission veto inputs, all disabled in the baseline.

## Build delta

The pre-existing derivative source was audited against the approved parent.
This unit:

- cached the completed-D1 reference timestamp used by the neutral pattern
  control path;
- corrected the INIT identity log to `collins-66mom-opt`;
- added a complete seven-section `SPEC.md` with Collins/Wiley citation and
  parent lineage;
- corrected the canonical preset identity and bound build hash;
- made the inherited RNG, DXZ news axes, Friday close, stress control, and all
  six neutral pattern inputs explicit in the fixed-risk preset.

The canonical preset has `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live preset was created.

## Governed compile

The build-task-bound classifier returned `ELIGIBLE` for source SHA-256
`c59d14f7f13e29faac36e29315288267978a6babe92ab181273620f9760d1d2e`.
The exact governed compile row was
`5d4f7971-02e1-4280-a4c8-e546c9e56858`. Its source-fresh rollout hold was
released with the bounded reviewed releaser; the backup was
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260829T141640Z_d6b1b02d.sqlite`
(SHA-256
`0ac8a86e884126974799da64b67a138c55225a31eb97193d42af721e9c8ba4e0`).

Resident worker T7 compiled the EA without terminal displacement:

- MetaEditor: PASS, 0 errors, 0 warnings;
- strict build check: PASS, 0 failures, 0 warnings;
- EX5 SHA-256:
  `7bc7b5ec70c3ed2687edfffdf9ff3208886f361af831316e5324672fa7ed57a3`;
- receipt:
  `D:/QM/reports/work_items/5d4f7971-02e1-4280-a4c8-e546c9e56858/QM5_41198/COMPILE_EA/compile_evidence.json`.

The staged-binary provenance guard independently matched the EX5 and MQ5 to
that exact COMPILE_OK receipt.

## Smoke and Q02 handoff

Exactly one build-smoke command was attempted for XTIUSD.DWX D1 in 2024. The
custom-history isolation gate refused it before tester launch because direct
`run_smoke` had no worker-bound work item whose archives had been privatized.
No report or strategy verdict was produced. The build recorder preserved this
as the original framework error, normalized the build to
`deferred_p2_smoke`, and marked `needs_p2_smoke_via_pump=true` while retaining
the successful compile and build-check facts.

The DL-089 matrix service created one worker-bound Q02 prerequisite as soon as
the governed binary became available:

- work item: `a5d5c14b-b613-5e08-97d1-a495970bc926`;
- status at handoff: `pending`, unclaimed, attempt 0;
- symbol/timeframe/window: `XTIUSD.DWX`, D1, 2017-2022;
- expected MQ5 and EX5 hashes exactly match the compile receipt;
- setfile SHA-256:
  `f7902ad402279032c58e1568a54e92486aa39cdbdb31f2d0a44180e0f33dd7e8`;
- setfile risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- pattern baseline: `opt_pp_buy1..3=0`, `opt_pp_sell1..3=0`.

`record-build` detected this pending row and skipped duplicate Q02 creation.
Thus the farm contains exactly one Q02 row for the EA/symbol pair.

## Verification and capacity

- `skill_build_ea_guard.py`: PASS for numeric EA ID 41198, registry, magic
  registry presence, and EA directory.
- `validate_spec_doc.py`: 1 PASS, 0 FAIL.
- `validate_build_guardrails.py`: PASS, zero findings.
- `build_gate_hardening.py`: PASS, zero failures/warnings.
- `validate_symbol_scope.py`: `SINGLE_SYMBOL_OK`.
- `opt_census.validate_base_setfile`: parsed the complete fixed-risk and six
  pattern-input bindings.
- `validate_ex5_commit_guard.py`: PASS against compile work item `5d4f7971`.

The fresh pre-smoke five-sample whole-host CPU window was 80.47%, 78.67%,
75.69%, 82.04%, and 83.30% (average 80.03%, maximum 83.30%). Both measures
were below the 97% hard ceiling. No backtest CPU stop bound during this unit.

## Safety boundary

No portfolio gate, portfolio-admission surface, T_Live manifest, deploy
manifest, or live preset was changed. AutoTrading was not toggled. T_Live and
unrelated terminal processes were observed only through read-only slot scans.
All unrelated shared-worktree and staged changes were preserved and excluded
from this unit's path-scoped commit.
