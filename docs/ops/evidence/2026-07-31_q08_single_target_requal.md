# Q08 single-target requalification controller — design and dry-run evidence

Date: 2026-07-31
Router task: `527228e3-971d-47e9-89a5-a62fa818205b`
Target: `95015420-11d0-4c11-bb98-25fa2a361048` (`QM5_10582` / `XAUUSD.DWX` / Q08)
Mode: implementation plus read-only live dry-run; **no apply**

## Outcome

The OWNER-scoped exception controller is implemented and tested. Its live dry
run is correctly **BLOCKED**. The target row and old INVALID evidence pass their
identity/preservation checks, but the mandatory parser precondition does not:
the base setfile parses six strategy assignments while all three ablation files
are refused for duplicate `strategy_fast_ema_period` assignments.

No requeue occurred. The result preserves the global MNT-007 invariant that Q08
invalid-report rows are non-retryable by recovery waves; the existing
`requeue_stranded_infra.py` classifier was not changed.

## Controller contract

Implementation: `tools/strategy_farm/q08_single_target_requal.py`

The controller is dry-run by default and has no cohort/wave selector. Its code
hard-bounds the only authorized target, OWNER decision source, reason class,
parser-fix commit, four original setfile hashes, and unchanged global invariant.
The exception JSON additionally binds the exact live row payload SHA, current
controller/parser source, MQ5, EX5, setfiles, archive root, and implementation
review state.

Apply is impossible unless all of the following are true in the same guarded
operation:

1. the caller supplies the exact exception-contract SHA-256;
2. Claude's implementation review is `APPROVED`, with a hash-bound receipt and
   reviewed controller commit containing the bound source bytes;
3. `parse_setfile_assignments` returns more than zero assignments for the base
   and all three ablations;
4. every code/build/setfile binding still matches (source hashes are LF-
   normalized to avoid checkout-EOL ambiguity; binary/setfile hashes are raw);
5. the target still matches status/phase/verdict/raw-payload SHA and setfile;
6. the old aggregate and whole work-item report root still exist, and the
   no-overwrite archive destination does not;
7. the hash-bound `FACTORY_OFF.flag` exists and active work-item count is zero;
8. the global Factory mutation lock is held and the row still matches inside a
   single `BEGIN IMMEDIATE` transaction.

An apply first fsyncs a durable journal with exact pre/post row states and the
archive move, then moves the whole report root under
`D:\QM\reports\work_items\_requal_archive\<row>\`, performs an exact one-row
CAS, and inserts a farm event in the same transaction. Failure compensates the
archive move. Revert requires expected journal and Factory-OFF hashes, zero
active rows, the exact post-state, the same mutation lock/transaction, restores
the report root before the row, and inserts a revert event. Nothing is deleted
or overwritten.

The requeued payload would retain the prior evidence reason while removing
stale runtime ownership keys and binding the contract, controller/parser
commit, MQ5/EX5, all setfiles, prior payload, and archive destination. It states
that no pipeline verdict is inferred.

## Durable artifacts and commits

- Exception contract:
  `docs/ops/evidence/2026-07-31_q08_10582_requal_exception.json`
  (dry-run binding SHA-256
  `fe1cb63aa5c39028007d0072af1b7532991c6215a5f2502446616b1ba6885ef8`)
- Live dry-run plan:
  `docs/ops/evidence/2026-07-31_q08_10582_requal_dry_run.json`
  (SHA-256
  `9111b0a463482fb917e3a29aeb4c833ab70321a8464304d2fb44cbe5364460d3`)
- `4d5af8558` — initial controller and tests
- `9c6db6bc2` — bind authorization to the committed OWNER decision
- `2aa9a704b` — make source identities deterministic across checkout EOLs
- `46a4a9151`, `e0ef3b470` — committed exception/dry-run artifacts and refreshed
  source bindings

The exception contract deliberately carries
`implementation_review.status=PENDING`; therefore the current bytes cannot be
applied even if an operator supplies mutation flags.

## Live dry-run, 2026-07-31T13:59:37Z

Command (no `--apply`):

```text
python tools/strategy_farm/q08_single_target_requal.py \
  --exception-contract docs/ops/evidence/2026-07-31_q08_10582_requal_exception.json \
  --plan-out docs/ops/evidence/2026-07-31_q08_10582_requal_dry_run.json
```

Passes:

- exact row CAS: `done / Q08 / INFRA_FAIL`, payload
  `b8b503e258034b…`, ablation-00 path unchanged;
- controller/parser Git provenance and parser-fix ancestor;
- all current code, build, and setfile identities;
- archive requirement: report root present, destination absent, old aggregate
  `42feb4cff2864371…` (12,886 bytes) preserved;
- base setfile: six strategy assignments.

Blockers:

- ablation 00/01/02: duplicate `strategy_fast_ema_period`, zero accepted
  assignments under the mandatory duplicate guard;
- Claude implementation review remains pending;
- `FACTORY_OFF.flag` absent;
- six active work items at the dry-run observation.

The duplicate condition is the same contradiction documented by the parser
fallback task: resolving it needs an explicit upstream vintage/precedence
decision. This controller must not weaken the duplicate guard or edit the four
byte-bound setfiles on its own.

## Focused verification

```text
python -m pytest -q tools/strategy_farm/tests/test_q08_single_target_requal.py
10 passed

python -m pytest -q \
  tools/strategy_farm/tests/test_q08_single_target_requal.py \
  framework/scripts/tests/test_q08_setfile_parser_fallback.py \
  tools/strategy_farm/tests/test_requeue_stranded_infra.py
44 passed in 9.77s

python -m compileall -q \
  tools/strategy_farm/q08_single_target_requal.py \
  tools/strategy_farm/tests/test_q08_single_target_requal.py
PASS
```

Fixtures cover exact-target/CAS refusal, mandatory archive refusal, parser gate,
Factory-OFF and active-row refusals, pending-review refusal, crash-safe apply
shape, successful guarded revert, and drifted-post-state revert refusal. All
apply/revert tests use temporary SQLite/report roots; none touch farm state.

## Safety statement

No live DB row/event, report root, setfile, EA/build, Factory flag, terminal,
backtest, queue, T5/T_Live/AutoTrading state, or pipeline verdict was changed.
The next permitted step is Claude implementation review. Even after approval,
apply remains fail-closed until the three duplicate-setfile blockers are
resolved under a separately reviewed evidence-vintage decision and a genuine
Factory-OFF/zero-active window exists.
