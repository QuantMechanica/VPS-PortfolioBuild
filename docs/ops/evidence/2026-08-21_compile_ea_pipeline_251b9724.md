# COMPILE_EA governed compile phase and source-only enqueue

Date: 2026-08-21  
Router task: `251b9724-db74-416a-9da2-96e30a8806bc`  
Branch: `agents/board-advisor`  
Verdict: `PASS_FOR_REVIEW` — utility mechanism and held queue are complete; no gate verdict was created.

## Outcome

Compiling is now represented by the non-Q utility work-item phase `COMPILE_EA`. It uses the
existing `work_items` selector, terminal-worker claim, quiescent terminal slot, ownership CAS,
and evidence path. It does not launch `terminal64.exe` and it does not produce a pipeline gate
verdict.

The exact verified manifest contains 82 EAs and was enqueued atomically:

| Result | Count |
|---|---:|
| Requested from frozen manifest | 82 |
| Enqueued `COMPILE_EA` | 82 |
| Refused | 0 |
| Duplicate/open on first apply | 0 |
| Active rollout holds | 82 |
| Compiled at handoff | 0 |
| Failed at handoff | 0 |
| Pending at handoff | 82 |

The queue is intentionally held under `COMPILE_EA_WORKER_ROLLOUT_PENDING`, with
`release_on_restart=1`. Several resident terminal workers predate the new worker code. Releasing
the rows before the reviewed code is fleet-wide would allow an old worker to claim one and fail
it through the legacy EX5-required preflight. The existing governed release-on-restart ceremony
is the activation boundary; no terminal or active backtest was stopped or restarted here.

Artifacts:

- Candidate manifest: `docs/ops/evidence/2026-08-21_compile_ea_verified_candidates_251b9724.csv`
  — 82 rows, SHA-256
  `ad1f4528f8bb739ed22429415a59bb574f901ebc33c6edeedc1b5006696d37e1`.
- Per-EA status/failure report:
  `docs/ops/evidence/2026-08-21_compile_ea_batch_status_251b9724.csv` — 82 rows,
  SHA-256 `edd27af16692e8e4f86737557f528501a852825155986c3a297867beae0cd63b`.
  Every row records `work_item_id`, state, compiled/failed flags, failure classes, EX5 hash,
  setfile count, build-check result, evidence path, and activation hold.

## 195 versus 102: reconciled

The two earlier counts did not use the same identity relation:

- The drain census's 195 joined a source-only EA directory to the active lifecycle row in
  `framework/registry/ea_id_registry.csv`.
- The later 102-label reproduction joined the directory's numeric ID to an active row in
  `framework/registry/magic_numbers.csv`, then excluded an open/completed `build_ea` task. It did
  not require an active EA-ID lifecycle row, a zero-work-item history, an unbound setfile state,
  or a mechanically resolvable timeframe.

`ea_id_registry` is authoritative for whether the allocated EA identity is active.
`magic_numbers` is authoritative only for the executable symbol bindings. Therefore a compile
candidate must be in the intersection: one active EA-ID row plus at least one active magic row.
The magic join alone is unsafe: it currently includes two source-only EAs whose lifecycle rows
are retired, `QM5_30001_bollinger-bands-grid-waka-waka` and
`QM5_38007_codetrading-python-atr-grid-engine`.

The live reconciliation immediately before enqueue was:

| Read-only class | Count |
|---|---:|
| Exact-name `.mq5` present and exact-name `.ex5` absent | 317 |
| Above, joined to one active `ea_id_registry` row | 178 |
| Above, using the historical active-magic/no-build-task join | 88 |
| Intersection of those two joins | 86 |
| Exclude bound hash (`QM5_12929`) | 85 |
| Exclude unresolved timeframe (`QM5_1557`, `QM5_1581`, `QM5_9579`) | 82 |

No member of the 82 had prior `work_items`, a bound setfile hash, an existing EX5, an existing
open `COMPILE_EA` row, or an open/completed build task at classification time. No timeframe was
guessed. The three ambiguous cards above remain outside the queue for an explicit timeframe
decision.

## Exact read-only regeneration query

This is the exact historical query recorded by the 0/102 investigation. It produced 102 at that
snapshot and explains the active-magic join:

```python
import sqlite3, csv, re
from pathlib import Path

reg = Path(r"C:\QM\repo\framework\registry\magic_numbers.csv")
active_ids = {
    row["ea_id"].strip()
    for row in csv.DictReader(reg.open(encoding="utf-8-sig"))
    if (row.get("status") or "").strip().lower() == "active"
}
conn = sqlite3.connect(r"D:\QM\strategy_farm\state\farm_state.sqlite")
pending = {
    row[0]
    for row in conn.execute(
        "SELECT DISTINCT card_id FROM tasks "
        "WHERE kind='build_ea' AND status IN ('pending','active','done')"
    )
}
eas_root = Path(r"C:\QM\repo\framework\EAs")
for directory in sorted(eas_root.iterdir()):
    match = re.match(r"(QM5_(\d{4,5}))_(.+)$", directory.name)
    if not (directory.is_dir() and match):
        continue
    ea_id_full, numeric_id = match.group(1), match.group(2)
    mq5 = directory / f"{directory.name}.mq5"
    ex5 = directory / f"{directory.name}.ex5"
    if (
        mq5.exists()
        and not ex5.exists()
        and numeric_id in active_ids
        and ea_id_full not in pending
    ):
        print(directory.name)
```

The stricter manifest regeneration used the committed classifier below. It adds the active
EA-ID row, any-work-item, bound-hash, supported-symbol, and deterministic-timeframe guards. It
was run before enqueue; the CSV is the immutable replay boundary because a correct rerun after
enqueue sees the new rows as idempotently open.

```python
from pathlib import Path
from tools.strategy_farm import compile_work_items

root = Path(r"D:\QM\strategy_farm")
repo = Path(r"C:\QM\repo")
inventory = compile_work_items._inventory(root, repo)
eas_root = repo / "framework" / "EAs"
eligible = []
for directory in sorted(eas_root.iterdir()):
    mq5 = directory / f"{directory.name}.mq5"
    ex5 = directory / f"{directory.name}.ex5"
    if (
        directory.is_dir()
        and mq5.is_file()
        and not ex5.exists()
        and compile_work_items._label_parts(directory.name)
    ):
        result = compile_work_items.classify_candidate(
            root, repo, directory.name, inventory
        )
        if result.get("eligible"):
            eligible.append(result)
print("\n".join(row["ea_label"] for row in eligible))
```

## Implemented contract

- `farmctl enqueue-compile <EA label...>` applies the narrow positional form immediately.
  `--from-file` is a dry run unless `--apply` is explicit. Repeating the applied 82-row batch
  returned `enqueued_count=0`, `idempotent_open_count=82`, and `refused_count=0`.
- `farmctl compile-status` reports per-EA compiled/failed state and failure classes without
  changing state.
- The terminal worker handles `COMPILE_EA` before the generic EX5/setfile preflight. It generates
  backtest setfiles with `RISK_FIXED=1000` and `RISK_PERCENT=0`, invokes strict
  `build_check.ps1 -EALabel <exact label>`, and records compile result, EX5 SHA-256, setfile
  count, build-check result, and classified failures in an atomically replaced JSON evidence
  file.
- The worker binds the compile work-item ID and claimed `T1`-`T10` terminal through arguments
  and environment. The claimed terminal must be quiescent; `terminal64.exe` is never launched.
- Include mirroring uses one fixed global mutex at
  `D:\QM\strategy_farm\state\locks\include_mirror.lock`. Only include roots owned by the
  claimed terminal are mirrored. Other terminal profiles are listed as deferred.
- Every destination include file is written to a same-directory temporary file, flushed, and
  installed with `os.replace`. An interruption can leave a mixture of complete old/new files,
  never a partially written destination.
- `compile_one.ps1` and `build_check.ps1` refuse an ad-hoc compile while any `terminal64.exe`
  is live. The refusal names `python tools/strategy_farm/farmctl.py enqueue-compile <EA label>`
  and records `retry_attempted=false`; there is no retry loop.
- Generic `farmctl dispatch-work-items` observes active compile rows without treating the
  deliberately absent `terminal64.exe` as a dead terminal and leaves pending compile ownership
  to the resident terminal worker.

## Verification

Focused and adjacent regression suite:

```text
python -m pytest \
  tools/strategy_farm/tests/test_compile_work_items.py \
  tools/strategy_farm/tests/test_include_mirror.py \
  tools/strategy_farm/tests/test_pattern_fixture_harness_dispatch.py \
  tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py \
  tools/strategy_farm/tests/test_farmctl_scope_audit_isolation.py \
  tools/strategy_farm/tests/test_build_guardrails.py -q
100 passed in 40.91s
```

After adding the explicit unresolved-timeframe refusal, the focused three-file rerun was
`11 passed in 2.33s`. Python byte-compilation passed for `include_mirror.py`,
`compile_work_items.py`, `farmctl.py`, and `terminal_worker.py`; Windows PowerShell parser
validation passed for `compile_one.ps1` and `build_check.ps1`.

Live fail-loud verification, without starting MetaEditor or a terminal:

```text
build_check.compile_guard={... "failure_class":
"LIVE_FACTORY_AD_HOC_COMPILE_REFUSED", ... "retry_attempted": false}
BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED: ... Use the governed pipeline path:
python tools/strategy_farm/farmctl.py enqueue-compile <EA label>.
```

Post-apply database verification:

```text
COMPILE_EA: total=82 pending=82 active=0 verdicts=0 symbol_nonblank=0 setfile_nonblank=0
holds: total=82 active=82 release_on_restart=82 correct_hold_code=82
compile-status: compiled=0 failed=0 pending=82 activation_held=82 not_enqueued=0
canonical claim selector: COMPILE_EA pending=82 visible-to-claim=0
```

No `T_Live`, AutoTrading, terminal process, gate threshold, news-staleness limit, or active
backtest was changed.

## Commits and shared-checkout observation

- `21e1d46db390f27b982e00ef2746b7464b7e3fe6` — worker, scripts, mutex helper, classifier,
  and tests.
- `8a7988bfdd2d82afeb1e31eea61c6c8272c9eca1` — `farmctl` enqueue/status/dispatch integration.
- `9f27d30f9d976c1a6e8f410972b64825fabeb28e` — frozen candidate manifest.

The canonical checkout has an existing auto-commit/push process. While the first explicit
path set was staged, that process created `21e1d46db` with message `build: add completed EA
artifacts`; at evidence capture the remote refs showed that commit on both `origin/main` and
`origin/agents/board-advisor`. Codex did not invoke a push, merge, cherry-pick, reset, or any
operation against `main`. The rollout holds remain active so this unexpected shared-checkout
advance cannot activate the new queue. Review and main integration authority remain with the
Claude+OWNER close-out.
