# DL-090 implementing job: report_retention_purge.py

**Router task:** `b24d7875-1417-4e75-8452-76e8e9df51ea` (`QM-TODO-20260823-506`)
**Decision:** `decisions/DL-090_backtest_report_retention_policy.md` (OWNER-ratified
2026-08-23, adopted by a concurrent Codex session before this task was picked
up — see "Concurrent actor" below).
**Author:** Claude (headless orchestration cycle), 2026-08-23.
**Artifact:** `tools/strategy_farm/report_retention_purge.py`

## Concurrent actor note

By the time this cycle reached router task `b24d7875`, `decisions/DL-090_backtest_report_retention_policy.md`
was already committed (`26cb49463`, author "QuantMechanica Codex", 2026-08-23
14:01:49 +0200) and explicitly reads "Implementation: commissioned as router
task `b24d7875`" — i.e. a concurrent Codex actor made and got OWNER
ratification for the policy call, anticipating this same task would do the
implementation. This matches the known duplicate-actor-on-shared-queue pattern
from earlier today. No conflict: the policy in DL-090 is unambiguous and this
task's payload's own recommendation ("(b) plus (c)") matches it, so I
implemented DL-090 §4 directly rather than re-deciding the policy.

## What this script does

Read-only classification (`work_items_clean` view, same MNT-016 taxonomy the
Strategy Archive Matrix uses) of every `work_items` row whose `evidence_path`
resolves to a still-existing directory under `D:\QM\reports\work_items\**`
that actually contains a native `report.htm` (recursively, since the real
report lives at `<run_dir>/raw/run_NN/report.htm` for multi-seed phases, not
directly in the run directory — this was the one bug caught during
verification, see below).

Per DL-090 §2:
- `keep_pass_family` — `verdict_taxonomy == 'strategy'` and verdict starts
  with `PASS` (covers `PASS`, `PASS_SOFT`, `PASS_LOWFREQ`, `PASS_PORTFOLIO`).
- `keep_standing_rejection` — the newest `strategy`-taxonomy non-PASS row per
  `(ea_id, symbol, phase)`, recomputed from the live DB every run (never
  cached, per §4.5).
- `age_out_superseded_strategy` — every non-newest row in that same group.
- `age_out_infra_invalid` — `verdict_taxonomy in ('infra', 'invalid')`.
- `keep_unclassified_taxonomy` — everything else (review/governance/
  draft_defect/measurement/open/unknown). DL-090 §2 names only two "age out"
  classes; §4.1 requires "never delete without a live classification", so
  taxonomies the rule doesn't name are kept, not aged out.
- `skip_open_status` — `status in (pending, active, claimed)` is never
  touched regardless of taxonomy (§4.6).

Fail-closed behavior implemented per DL-090 §4:
1. DB unreachable / classify() raises → no filesystem action taken at all,
   logged and reported (exit code 2).
2. Quarantine before deletion: `quarantine()` **moves** eligible `age_out_*`
   run directories (age ≥ `--min-age-days`, default 30) into
   `D:/QM/reports/_purge_quarantine/report_retention/<YYYYMMDD>/<work_item_id>/`;
   only `reap_quarantine()` (a separate step, `--quarantine-reap-days`,
   default 30) actually deletes, and only dated buckets past that age.
3. Path guard (`FORBIDDEN_PREFIXES`) rejects `C:\QM\mt5\T_Live`,
   `D:\QM\reports\state`, and `decisions/` even if a row somehow pointed
   there; in practice every candidate path is constrained to
   `D:\QM\reports\work_items\**` by construction (`evidence_path` values from
   other phases — `D:\QM\reports\pipeline\**`, `.log` paths under
   `D:\QM\strategy_farm\logs\**` — are excluded by the root-prefix check).
4. Every action (dry-run or real) logs count + bytes to
   `D:\QM\reports\state\report_retention_purge.log`, matching the convention
   of `reports_log_purge.ps1` / `tester_cache_purge.ps1`.
5. Standing rejection is recomputed from a fresh query every invocation.
6. `skip_open_status` enforces the open-row rule independently of taxonomy.

Compression (`compress_kept`) gzips the kept set's `report.htm` / `.json` /
`.ini` files in place, recursively, once ≥ `--min-age-days` old, skipping
anything already compressed.

Everything defaults to dry-run (`--execute` required for any real filesystem
mutation; `--classify-only` never touches disk regardless of `--execute`).

## Verification (dry-run against the live DB, 2026-08-23T12:1x UTC)

```
python tools/strategy_farm/report_retention_purge.py --classify-only
```

```json
{
  "age_out_infra_invalid":        {"count": 2618, "bytes": 308782998},
  "age_out_superseded_strategy":  {"count": 266,  "bytes": 29687209},
  "keep_pass_family":             {"count": 4896, "bytes": 13732609541},
  "keep_standing_rejection":      {"count": 3033, "bytes": 401251110},
  "keep_unclassified_taxonomy":   {"count": 123,  "bytes": 132314872},
  "skip_open_status":             {"count": 0,    "bytes": 0},
  "total_rows_seen": 10936
}
```

Kept set = 4896+3033+123 = 8052/10936 = **73.6%** of rows that still carry a
native report on disk, ~14.27 GB. Age-out set = 2884/10936 = 26.4%, ~338 MB.
This is the same shape DL-090 measured (kept set dominated by PASS-family
attempts; age-out set small relative to the kept set) — DL-090's own
figures were computed against a slightly different denominator (all runs,
including ones whose report already vanished) and at an earlier point in the
same day, so the percentages are not expected to match exactly, only the
shape.

Full pipeline (dry-run, `--execute` omitted):

```
python tools/strategy_farm/report_retention_purge.py --output <tmp>.json
```

```
DRYRUN would quarantine 1303 run dir(s) (~0.092GB), 0 already missing, min_age_days=30
REAP skip: quarantine root absent, nothing to reap
DRYRUN would compress 13360 file(s) in kept set (~3.143GB -> ~3.143GB), 0 already compressed, min_age_days=30
```

Confirmed no filesystem mutation occurred: `D:\QM\reports\_purge_quarantine\report_retention`
does not exist after the dry run. The only disk write in dry-run mode is the
append-only log line at `D:\QM\reports\state\report_retention_purge.log`,
which is the required audit trail (§4.4), not a policy action.

## One bug caught during verification

The first classify pass (before the fix now in the committed script) checked
for `report.*`/`*.htm` directly inside the run directory and found only 61
rows. The native report actually lives one level deeper, at
`<run_dir>/raw/run_NN/report.htm` (one `run_NN` per seed/attempt for
multi-seed work items) — confirmed by listing several on-disk run
directories. Switched the check and the byte-accounting to `rglob` before
trusting any number in this doc.

## What this cycle did NOT do

- **No `--execute` run.** Quarantining or deleting 2,884 real backtest run
  directories is exactly the kind of hard-to-reverse action this repo's
  operating rules ask to confirm before taking, even though DL-090 already
  carries OWNER ratification of the *policy*. The *first live execution* of
  a new purge job is a distinct, reversible-by-not-doing-it decision; I built
  and dry-run-verified the tool this cycle and I'm leaving the first
  `--execute` (plus scheduling it, e.g. a `QM_StrategyFarm_ReportRetention`
  scheduled task mirroring `reports_log_purge.ps1`'s installer) to a
  follow-up cycle or to Codex, so a second pair of eyes sees the live-run
  numbers before anything is moved.
- No `.set` file handling: those are versioned EA assets under
  `framework/EAs/**/sets/`, not per-run ephemeral artifacts, and are out of
  scope for a `D:\QM\reports\work_items` purge.

## Disposition

Task moves to `REVIEW`, not `APPROVED`/`PIPELINE` — first `--execute` run and
scheduled-task installation still need a look before this touches real data
at scale.
