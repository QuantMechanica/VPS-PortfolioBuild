# Build-gate hardening for recurring review defects — 2026-08-21

**Router task:** `57faa292-45a5-4531-945f-2dcf7715086e`  
**Implementation commit:** `a834b1e20` (`fix(build): gate recurring review defects`)  
**Branch:** `agents/board-advisor`

## Outcome

The six mechanically decidable defect classes from the 50-review close-out now
stop before a Codex EA review is created:

| Deliverable | Enforcement | Named result |
|---|---|---|
| D1 strict-build process leak | `agent_router.update_task`, before a Gemini `build_ea -> REVIEW` transition | `D1_STRICT_BUILD_FAIL` / `strict_build_check_failed_review_dispatch_refused` |
| D2 card loss-limit contract | `build_check.ps1` via `build_gate_hardening.py` | `EA_CARD_LOSS_LIMIT_MISMATCH` or `EA_CARD_LOSS_LIMIT_UNWIRED` |
| D3 pip ×10 conversion | same static build gate | `EA_PIP_DOUBLE_CONVERSION` |
| D4 unreachable management | same static build gate | `EA_MANAGEMENT_UNREACHABLE_OPEN_GUARD` |
| D5 broker/GMT window | same static build gate | `EA_BROKER_TIME_USED_FOR_GMT_WINDOW` |
| D6 build identity | router review-dispatch boundary | `D6_BUILD_IDENTITY_*` / `D6_BUILD_HASH_MISSING` |

D6 requires the producer JSON to carry a passing strict result, exact MQ5 and
EX5 SHA-256 values, at least one setfile with a 64-hex `build_hash`, and MQ5,
EX5, and setfile bytes that are tracked and clean at the same Git `HEAD`. This
places the identity check after compilation can regenerate EX5 bytes but before
a reviewer can receive the build.

## Real D1 refusal

A real router invocation attempted to move historical Gemini build task
`9fbca489-f822-4412-8066-a819bc100eb7` to `REVIEW` using the known strict-FAIL
producer artifact
`D:/QM/strategy_farm/artifacts/builds/000a34ed-c00b-4017-838c-11d65c4380d9.attempt_0.json`
(`build_check_passed=false`). The router returned:

```json
{
  "allowed": false,
  "gate_code": "D1_STRICT_BUILD_FAIL",
  "reason": "strict_build_check_failed_review_dispatch_refused",
  "updated": false
}
```

Read-back proved the source task stayed `RECYCLE` and retained its prior
`updated_at=2026-08-21T07:49:23+00:00`. The farm event ledger recorded
`review_dispatch_refused` at `2026-08-21T08:49:38+00:00` with the named gate,
artifact, and requested state. No new review task or source-task transition was
created by the probe.

## Static-gate evidence

The controlled fixtures include an explicit passing and failing case for every
new check. They prove:

- matching 2.0% entry-halt, 2.5% daily-hard-stop, and 5.0% total-DD inputs pass;
  a changed daily-hard-stop value fails;
- raw pip values pass known pip-native helpers; an argument multiplied by 10
  fails;
- management before admission passes; a helper proven to return true for an
  open position and called by an earlier return fails;
- `QM_BrokerToUTC(TimeCurrent())` passes a card-declared GMT window; raw
  `TimeCurrent()` hour comparison fails;
- explicit strict PASS plus committed, hash-matching MQ5/EX5/setfile bytes can
  create the Codex review; explicit strict FAIL or untracked bytes cannot.

The same new build gate was run read-only (`-SkipCompile -SkipSetValidation` and
all unrelated checks skipped) against the reviewed QM5_39003 defect. It failed
at the cited source line 156 for the ×10 pip call and also exposed the three
missing card loss-limit inputs. Durable report:
`D:/QM/reports/framework/21/build_gate_hardening_20260821/build_check_20260821_085024.json`
(4 failures, 1 warning). No EA or setfile was changed.

Focused verification:

- `51 passed` — router, router state-exit/stale-lease, and build-gate fixture tests;
- `Test-BuildCheckMaeHook=PASS`;
- `Test-BuildCheckEventVocabulary=PASS`;
- Python bytecode compilation PASS for the router and static checker;
- `git diff --check` PASS for all five implementation/test paths.

A broader unrelated P1 test run reached 54 passes and one pre-existing/current
tree failure in `test_tester_news_selftest_is_strict_and_precedes_loaded_event`;
the failing `QM_NewsFilter.mqh` path is outside this task and was not modified.

## False-positive policy

| Check | Blocking boundary | False-positive treatment |
|---|---|---|
| D1 | only an explicit `build_check_passed=false` or nested strict `FAIL` | Block: a failed strict result is never legitimate review input. Missing evidence is separately D6. |
| D2 | only percentages on the three exact card labels, compared with numeric, consumed EA inputs | Block when the labeled contract is clear. Missing, unreadable, or non-unique card is WARN/undecidable; no percentage is guessed. |
| D3 | only literal ×10 expressions inside argument positions of known pip-native helpers | Block: whole-pip APIs already convert units; an intentional 30-pip value can be written as 30 without changing behavior. |
| D4 | only an early return before a strategy manage/exit call whose condition is proven to become true from open-position state | Block. Generic readiness, kill-switch, and unrelated early returns are not classified by this check. |
| D5 | card explicitly declares a clock-form GMT/UTC window and source has raw broker-hour logic without a recognized conversion | Block. Missing/ambiguous card or unclassifiable clock flow is WARN. A documented `build-gate-allowed: broker-time-window` exception is WARN and still requires reviewer sign-off. |
| D6 | exact producer hashes and Git/setfile identity | Block until committed. This is provenance, not a strategy verdict; committing the exact compiled bytes resolves it. |

No active-inventory EA was recompiled. No factory, backtest, terminal,
AutoTrading, or T_Live action was started, and no pipeline verdict is inferred.
