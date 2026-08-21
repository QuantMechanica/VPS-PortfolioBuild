# Compile + setfile + build_check batch for source-only EAs — blocked on live-factory contention

Date: 2026-08-21. Author: Claude (orchestrator, headless cycle). Branch: agents/board-advisor.
Router task: `e7cc7b8a-1f7b-4551-b657-b6796dc1a9c7`.
Context: `docs/ops/evidence/2026-08-21_pipeline_drain_census_and_programme.md` §5 — this exact
work item is listed there as commissioned to the **Codex** lane ("mechanical, high volume"),
not Claude; the router nonetheless routed it to Claude (Codex was at 5/5 max_parallel when
the census cycle ran). Investigated it here rather than skipping, per "do not choose work
outside the deterministic router."

## What was verified (durable, safe, read-only)

Reproduced the census's "active registry, `.mq5` source present, no `.ex5`, no existing
build_ea task" filter directly against the live registry + DB:

```
framework/EAs/*/*.mq5 present, *.ex5 absent:        334 directories
  ... AND numeric ea_id status=active in
      framework/registry/magic_numbers.csv:          -> subset
  ... AND no existing tasks row (kind='build_ea',
      status IN pending/active/done) for that
      ea_id:                                          -> 102 EA labels
```

(102, not the census's 195 — the census's exact join key/filter differs by a script generation
this session doesn't have visible; the discrepancy doesn't change the finding below, which
applies to the whole class. The verified 102-label list is not attached inline here to keep
this doc short; re-run the query below to regenerate it, it is read-only and takes <5s.)

```python
import sqlite3, csv, re
from pathlib import Path
reg = Path(r"C:\QM\repo\framework\registry\magic_numbers.csv")
active_ids = {row["ea_id"].strip() for row in csv.DictReader(reg.open(encoding="utf-8-sig"))
              if (row.get("status") or "").strip().lower() == "active"}
conn = sqlite3.connect(r"D:\QM\strategy_farm\state\farm_state.sqlite")
pending = {r[0] for r in conn.execute(
    "SELECT DISTINCT card_id FROM tasks WHERE kind='build_ea' AND status IN ('pending','active','done')")}
eas_root = Path(r"C:\QM\repo\framework\EAs")
for d in sorted(eas_root.iterdir()):
    m = re.match(r"(QM5_(\d{4,5}))_(.+)$", d.name)
    if not (d.is_dir() and m):
        continue
    ea_id_full, numeric_id = m.group(1), m.group(2)
    mq5, ex5 = d / f"{d.name}.mq5", d / f"{d.name}.ex5"
    if mq5.exists() and not ex5.exists() and numeric_id in active_ids and ea_id_full not in pending:
        print(d.name)
```

## Why 0/102 were actually compiled: confirmed live-factory contention, not a fluke

Attempted `framework/scripts/build_check.ps1 -EALabel <label>` (the canonical single-EA
compile+validate entrypoint, per CLAUDE.md's build-guardrail note and the
`build_check OHNE -EALabel` incident memory) on the first candidate,
`QM5_1009_lien-fade-double-zeros`. It failed twice in a row, each time on a **different**
locked file under a **different** terminal's MetaQuotes profile:

```
Attempt 1: The process cannot access the file
  ...Terminal\5BC264D6982E3750B5E72ADD672A4CB1\MQL5\Include\QM\QM_FilterRegime.mqh
  because it is being used by another process.
Attempt 2: The process cannot access the file
  ...Terminal\2A75F04AEFC0DD58D685C4B1FBE49B9B\MQL5\Include\news_rules\5ers.mqh
  because it is being used by another process.
```

No `metaeditor64` process was running at the time (`Get-Process metaeditor*` empty both
times), ruling out a self-collision with a concurrent manual compile. Read
`framework/scripts/compile_one.ps1`'s `Resolve-TerminalIncludeTargets`: by design it mirrors
the freshly-compiled include tree into **every materialized terminal profile** under the
account's `AppData\Roaming\MetaQuotes\Terminal\*\MQL5\Include` (all T1-T10 + any other
terminal whose `origin.txt` matches this MetaEditor install). `farmctl health` at cycle start
showed the factory live with 4-5/10 terminal daemons alive and 2249 pending backtests — i.e.
those terminal profiles are actively open by running `terminal64.exe` processes right now.

**This is structural, not transient.** A raw `build_check.ps1` invocation against the live
factory races every active terminal's include directory by design. Retrying in a loop would
not fix it (confirmed: two consecutive attempts, two different terminals/files) — it would
just keep re-losing the race, and worse, risks leaving a terminal's include tree
partially/inconsistently written mid-copy while that terminal is actively reading it for its
own compile/init path. Per CLAUDE.md ("Do not interrupt active T1-T10 backtests unless OWNER
explicitly says so") and the Hard Rules' evidence-over-claims principle, this is exactly the
kind of live-system collision the standing rules exist to prevent — so this task stopped here
rather than forcing 100+ more attempts through a confirmed-racy path.

## Disposition

**0/102 compiled. Verdict: correctly did not proceed, not a failure to make progress.** The
real, durable output of this cycle is: (a) a reproducible, verified candidate list generator
for this EA class, (b) a confirmed, documented root cause for why ad-hoc compilation of this
batch is unsafe against the live factory, (c) a concrete recommendation below.

**Recommendation:** this batch belongs in the existing coordinated `build_ea` task-queue path
(`tasks` table, `kind='build_ea'`) that the live factory's own dispatcher already serializes
against active terminal state — not a manually-invoked `build_check.ps1` loop from an
orchestration cycle. This also matches the original commissioning in
`2026-08-21_pipeline_drain_census_and_programme.md` §5, which lists this exact work as the
Codex mechanical/high-volume lane. Concretely: either (1) create 102 `build_ea` rows in
`tasks` via the same path the card-approval auto-build bridge uses
(`farmctl.py` — see `_has_auto_build_task_file` / the auto-build bridge writer around
`farmctl.py:13771`) so the factory's normal dispatcher (which already knows how to pick an
idle terminal) picks them up, or (2) re-route this router task to Codex now that its queue has
headroom. Both are safer than continuing manual invocation. Not executed here (creating 102
task rows is itself a capacity/queue-order decision the drain programme's own risk #2 flags as
"a stated choice, not a side effect" — leaving that choice for the next cycle/OWNER rather than
making it unilaterally inside this investigation).

## Reproduction

```powershell
cd C:/QM/repo
Get-Process | Where-Object { $_.ProcessName -like '*metaeditor*' }   # confirm none running
powershell.exe -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel "QM5_1009_lien-fade-double-zeros"
# -> fails with a terminal Include-tree file lock; re-run to see it hit a different terminal/file each time
```
