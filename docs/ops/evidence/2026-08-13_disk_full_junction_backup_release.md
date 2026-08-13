# D: disk-full incident and junction-backup release — 2026-08-13

## Incident

`D:` reached **100% full (0 bytes free, 954 GB / 954 GB)**. Detected when a cockpit
render failed with `OSError: [Errno 28] No space left on device`. The farm state
database lives on `D:`, so the exposure was wider than the failed render.

The scheduled purge (`tester_cache_purge.ps1`, 11:37:28Z) reclaimed only **0.8 GB** —
it clears caches of *idle* terminals only, and three terminals held active work items.

Factory state during the incident: no `FACTORY_OFF.flag`, 3 factory terminals running,
3 active work items, T_Live trading unaffected.

## Root cause of the fill

Per-terminal tester `Bases` caches under Variant-A custom-history isolation are large by
design (T1 alone 107.7 GB). On top of that, **194.5 GB of stale migration rollback
directories** had never been released:

| Path | Size | Age at release |
|---|---:|---:|
| `D:\QM\mt5\T2\Bases.before_junction.20260523` | 46.69 GB | 82 d |
| `D:\QM\mt5\T3\Bases.before_junction.20260523` | 46.02 GB | 82 d |
| `D:\QM\mt5\T4\Bases.before_junction.20260523` | 46.13 GB | 82 d |
| `D:\QM\mt5\T5\Bases.before_junction.20260523` | 46.01 GB | 82 d |
| `D:\QM\mt5\T1\Tester.before_ndx_recovery_20260713_1315` | 9.59 GB | 31 d (KEPT) |
| `D:\QM\mt5\T5\Tester.failed_probe_20260727T1221Z` | 0.08 GB | 16 d (KEPT) |

## Authorization

These directories are the rollback tree of the 2026-05-23 junction migration. A standing
operating note says the rollback tree is to be kept, so **they were not released
autonomously**. OWNER was given the finding, the recommendation, and the trade-off, and
authorized release of the four `Bases.before_junction.20260523` directories only
(2026-08-13). The two smaller backups were deliberately kept.

## Pre-release safety verification

Each target was checked before deletion (deleting a junction would have destroyed the
live target instead of the backup):

```
T2: reparse=False nested_reparse=0 files=5260 lastwrite=2026-05-22 22:30:01
T3: reparse=False nested_reparse=0 files=5135 lastwrite=2026-05-22 22:30:01
T4: reparse=False nested_reparse=0 files=5200 lastwrite=2026-05-22 22:30:01
T5: reparse=False nested_reparse=0 files=5240 lastwrite=2026-05-22 22:30:01
```

All four were real directories with no reparse point at the root and none nested. Last
write 2026-05-22, i.e. immediately before the migration they back up.

## Execution and result

Released terminal by terminal, T2 first as a canary with a free-space readback:

- after T2: **81.7 GB free**
- after T3, T4, T5: **219 GB free** (954 GB total, 78% used)

Post-release factory verification: 3 factory terminals still running, 3 active work
items intact, T_Live terminal still up. No work item was cancelled, no terminal was
started or stopped, no factory flag changed, and no OFF/ON window was needed.

## Follow-up

- `D:` is now above the purge LowWater (150 GB) for the first time since the fill.
- The 2026-05-23 junction rollback tree no longer exists for T2–T5; the migration has
  been superseded twice (Variant-A custom-history isolation live since 2026-08-10) and
  was stable for 82 days before release.
- Open question for the ops-hardening ticket: the purge's protected-terminal rule means
  a sustained active-fleet period can drive free space to zero with no automatic relief.
  A low-water hard floor that pauses new claims (rather than only pausing on <40 GB per
  worker) should be evaluated.
