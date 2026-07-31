# Factory_ON/OFF Live-Fixes — adversarial Codex review

Date: 2026-07-31

Router task: `bebaf455-9426-420f-83e7-21cdcc219040`

Scope: commits `f01423c07`, `d052657f6`, `a8339d57c`,
`26ab194ea`, `fb885818d`, `b9771f554`, plus hardening of builder commit
`12b830c45`.

## Outcome

Overall verdict: **CONFIRM_WITH_BUILDER_HARDENING**.

The six Factory_ON/OFF live-fix commits preserve the existing fail-closed
authorization, state, process, task, and health predicates. They repair
representation or error-channel handling, except for the timeout change, which
changes only the maximum wait and not the required success state. No reviewed
fix authorizes Factory_ON, releases a hold, accepts a weaker task map, changes
T5/T_Live policy, or suppresses a non-zero validator result.

The original one-off builder had real hardening gaps. Those findings are
resolved in the attached tool changes and executable tests. No Factory_ON or
Factory_OFF run was made during this review. No scheduled task, Factory flag,
database, process, terminal, hold, T5, T_Live, or AutoTrading state was
mutated.

## Commit-by-commit verdicts

| Commit | Verdict | Review evidence |
|---|---|---|
| `f01423c07` | **CONFIRM** | `Factory_OFF.ps1:320-352` reads the exact bytes, skips exactly one leading `EF BB BF` sequence via an offset, and retains strict UTF-8 decoding, schema/state comparison, exact task-key/value comparison, and SHA-256 over the original full file. The new cross-runtime test executes both BOM and BOM-less records, confirms the file bytes remain unchanged, and confirms malformed UTF-8 still fails closed. |
| `d052657f6` | **CONFIRM** | `Factory_ON.ps1:342-383` now constructs two array candidates with counts 7 and 8. The executable harness invokes the real function with stubs for process inspection, accepts only the exact base and `-NoPause` forms, and rejects an extra argument. Host-image and element-by-element comparisons remain unchanged. |
| `a8339d57c` | **CONFIRM** | `Factory_ON.ps1:385-426` and `Factory_OFF.ps1:595-640` select the last non-empty merged-output line only after a zero native exit code, then require `authorized=true` or `validated=true`; downstream exact map and binding checks remain. Leading interpreter stderr is no longer mistaken for JSON. Trailing noise is deliberately rejected as invalid JSON in the executable test, so ambiguous output remains fail-closed. |
| `26ab194ea` | **CONFIRM** | The local `ErrorActionPreference='Continue'` scopes are bounded by `finally` and restore the prior value at `Factory_ON.ps1:396-402`, `Factory_ON.ps1:1074-1079`, and `Factory_OFF.ps1:744-753`. Validator exit codes are still checked. OFF pacer cleanup still records success only on exit 0. The rollback pacer remains best-effort only after OFF reassertion/preservation, task disablement, and process stop; this was its pre-change success semantics. Tests execute all scopes under `EAP=Stop` with native stderr on PS5.1 and PS7 and assert restoration to `Stop`. |
| `fb885818d` | **CONFIRM** | `Factory_ON.ps1:1336-1349` uses `IDictionary.Contains`, which is the key-membership API shared by `OrderedDictionary` and `Hashtable`. Missing keys still default to disabled. The executable loop test uses an ordered map and proves `A=true` enables, `B=false` disables, and absent `C` disables. |
| `b9771f554` | **CONFIRM** | `Factory_ON.ps1:128-132` changes only the caller timeout to 1800 seconds. `factory_restart_health.ps1:297-370` still exits early only on the full healthy predicate and otherwise throws at the deadline; its parameter maximum is exactly 1800. Hold release remains after the health result. This is not a guard waiver. The calibration risk is recorded below. |

## Builder findings and remediation

The initial `12b830c45` builder was suitable only as a one-off script and was
not safe enough as a reusable authority-artifact builder:

1. Critical checks used Python `assert`, which disappears under `python -O`.
2. Repository/flag/decision identity was hard-coded; no argparse contract or
   classified exit codes existed.
3. It did not verify the pinned preparation file's SHA/commit/blob provenance
   or whether its manifest-creation authorization window was still active.
4. It wrote the decision and sidecar directly, with no pre-publication or
   post-publication validation and no pair rollback.
5. The declared `EXPECTED_FLAG_SHA` was unused. This created false confidence;
   the actual safe contract is to bind the exact bytes read and revalidate that
   same hash before publication.
6. JSON parsing did not reject duplicate keys, and BOM removal used `lstrip`
   rather than removal of one exact prefix.

The hardened builder now provides:

- `--repo-root`, `--flag`, and required `--decision-id` arguments
  (`build_runtime_activation_decision.py:481-490`);
- exit 2 for argparse errors, 3 for preconditions, 4 for candidate
  self-verification, 5 for publication/rollback, and 10 for unexpected internal
  failures;
- explicit exceptions instead of security-relevant `assert` statements;
- an explicit clean-repository check including untracked files, followed by
  content/index/untracked rechecks after source-byte normalization
  (`build_runtime_activation_decision.py:290-409`);
- exact preparation SHA-256, commit, and blob validation;
- exact schema-v2 OFF state, 21-boolean task map, template map pin, and
  raw-byte flag binding;
- preservation of the required `core.autocrlf=true` behavior: each of the 12
  source worktree files is normalized, when necessary, to the committed LF blob
  bytes before its raw SHA/blob binding is made
  (`build_runtime_activation_decision.py:186-230`);
- candidate staging inside the Git directory, validator import rather than a
  subprocess, validation before publication, validation after publication,
  and restoration of the prior artifact pair on failure
  (`build_runtime_activation_decision.py:244-286`, `:425-467`);
- compact JSON result/error records and a caller-supplied decision ID.

`factory_runtime_activation.validate_runtime_activation_candidate`
(`factory_runtime_activation.py:498-524`) shares the complete production
validator. It omits only commit provenance for the two candidate files that
cannot yet be committed. Preparation, time window, exact flag, task map,
worker/T5 policy, seven-hold set, and all 12 committed source bindings are
still checked. The production entry point remains
`validate_runtime_activation_decision`, which always requires decision and
sidecar commit provenance. A focused test proves an uncommitted candidate
accepted by candidate validation is rejected by the production entry point.

### Preparation-window decision

The preparation expiry is relevant at artifact creation time. The pinned
preparation record grants
`manifest_creation_authorized_after_prerequisites=true` only inside
`authorized_at_utc <= now < authorization_expires_at_utc`. Minting a new
`OWNER/APPROVED` runtime artifact after that interval would extend stale
creation authority, so the builder now refuses it.

The builder does not cap an already valid runtime decision to the preparation
expiry. A runtime decision created while manifest creation is authorized has
its own independently validated, maximum-24-hour window. Production validation
continues to enforce that runtime window.

## Executable regression coverage

New test module:
`tools/strategy_farm/tests/test_factory_live_fix_regressions.py`.

Each scenario runs once under
`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` (Windows
PowerShell 5.1) and once under
`C:\Program Files\PowerShell\7\pwsh.exe`:

1. Real `Assert-CanonicalFactoryOnHostProcess` comparison body: allowed
   candidate counts 7/8, exact base and `-NoPause` acceptance, extra-argument
   rejection.
2. Real `Assert-PublishedFactoryOffRecord`: BOM and BOM-less round trips,
   unchanged bytes/full-file SHA, malformed UTF-8 rejection.
3. Real Factory_ON runtime-validator function and extracted Factory_OFF
   restore-validator block: native stderr before final compact JSON, final-line
   parse, `authorized/validated=true`, non-zero exit rejection, trailing-noise
   rejection, and EAP restoration.
4. Extracted Factory_OFF pacer cleanup and real
   `Invoke-FailClosedRollback`: native stderr under `EAP=Stop`, cleanup exit
   semantics, rollback completion, preservation of an external OFF record, and
   EAP restoration.
5. Exact quiescence loop with an `[ordered]` map: `.Contains` key semantics and
   absent-key fail-closed disable behavior.

New focused builder module:
`tools/strategy_farm/tests/test_build_runtime_activation_decision.py`.
It covers the CLI contract and classified error record, dirty-tree rejection,
expired-preparation rejection, candidate-validation rejection without
publication, production/candidate provenance separation, exact sidecar/flag
binding, double self-validation, and the required CRLF-to-committed-LF raw-byte
normalization.

The stale pre-fix timeout assertion was corrected from 300 to 1800. The stale
canonical-artifact absence test was replaced with a stronger check that the
consumed canonical artifact is exactly sidecar-bound and rejects at its expiry.
No test was skipped, xfailed, or weakened.

## Verification record

Focused and surrounding guard suites:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_factory_live_fix_regressions.py \
  tools/strategy_farm/tests/test_build_runtime_activation_decision.py \
  tools/strategy_farm/tests/test_factory_runtime_activation.py \
  tools/strategy_farm/tests/test_factory_off_on_serialization.py \
  tools/strategy_farm/tests/test_factory_restore_intent.py \
  tools/strategy_farm/tests/test_factory_quiescence.py \
  tools/strategy_farm/tests/test_factory_mutation_lock.py \
  tools/strategy_farm/tests/test_factory_restart_post_start_health.py
```

Final result:

```text
90 passed in 63.56s
```

Full-file PowerShell AST parse:

```text
Windows PowerShell 5.1: AST PASS: Factory_ON.ps1 + Factory_OFF.ps1
PowerShell 7:           AST PASS: Factory_ON.ps1 + Factory_OFF.ps1
```

Python bytecode compilation and `git diff --check` both completed with exit 0.
The Git output contained only the expected `core.autocrlf=true` future-CRLF
notices.

## Open risks and boundaries

1. **1800-second calibration:** a read-only
   `schtasks /Query /TN "QM_StrategyFarm_Pump_5min" /XML` during review showed
   `<ExecutionTimeLimit>PT10M</ExecutionTimeLimit>`. A 30-minute gate may
   therefore wait across multiple Pump attempts and retain the guarded restart
   window longer than necessary when Pump is persistently unhealthy. The cited
   warm run was about 257 seconds, while the cold-backlog claim lacks a durable
   per-item/runtime model. A future change should calibrate from measured cold
   percentiles or derive a bound from the task execution limit. This is an
   availability/rollback-latency risk, not an authorization or health-predicate
   weakening.
2. **Final-line protocol:** success depends on the pinned validators maintaining
   their contract that the authoritative compact JSON is the last non-empty
   output. Trailing native noise fails closed, as tested. A future multi-line
   output protocol should use separated stdout/stderr capture or an explicit
   framed record.
3. **Builder authority boundary:** `--decision-id` identifies an OWNER decision
   but is not a cryptographic signature. Filesystem/operator access control and
   the still-live pinned preparation authorization remain prerequisites. The
   builder must not be treated as self-granting OWNER authority.
4. **No live-operation claim:** these results prove source semantics with
   synthetic subprocess harnesses and read-only inspection. They do not claim a
   Factory restart, task mutation, hold release, or pipeline verdict.
