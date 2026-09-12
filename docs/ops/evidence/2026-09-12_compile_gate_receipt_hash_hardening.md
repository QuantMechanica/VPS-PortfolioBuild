# Compile-gate receipt hash and time hardening

**Task:** `09a32b16-294a-4e7e-9470-f84e25fb413d`  
**Disposition:** REVIEW — implementation complete; feature remains Default-OFF.

## Result

`COMPILE_GATE_BROKEN_SOURCE` release now authenticates the successful
`COMPILE_EA` receipt against the current canonical EA files. A receipt releases
a hold only when all of these conditions agree:

- receipt schema, work-item id, EA id, PASS results and success flag;
- receipt `completed_at` is strictly newer than the hold `created_at`;
- the receipt's canonical EA label and absolute MQ5/EX5 paths;
- present, well-formed receipt `mq5_sha256` and `ex5_sha256` values; and
- fresh SHA-256 reads of both current files equal those receipt values.

The compile worker now emits the top-level MQ5 path/hash and re-hashes the
source after the build, failing with `SOURCE_CHANGED_DURING_COMPILE` if it
changed during compilation. Release events and notes retain both artifact
hashes, the receipt hash and completion time.

Missing hashes, changed source bytes, an old completion timestamp, path or
identity mismatch, missing files, and changed EX5 bytes all fail closed without
releasing a hold or changing a verdict.

## Default-OFF boundary

`QM_COMPILE_GATE_HOLD_ENABLED` was not set or activated. Dispatch continues to
skip the hold reconciler entirely while the flag is absent, preserving the
existing behavior. No production database row, hold, verdict, terminal,
scheduled task, or EA artifact was mutated.

## Verification

```text
python -m pytest -q tools/strategy_farm/tests/test_compile_gate_holds.py tools/strategy_farm/tests/test_phase_runner_process_lineage.py tools/strategy_farm/tests/test_q09_live_news_diagnostic.py
35 passed

python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/compile_work_items.py tools/strategy_farm/tests/test_compile_gate_holds.py
PASS

git diff --check -- <scoped implementation paths>
PASS
```

Focused tests include a fresh hash-bound release, current-source hash mismatch,
missing hashes, a receipt completed before the hold, and the existing flag-
unset behavior check.
