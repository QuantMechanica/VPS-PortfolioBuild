# DL-063 — Keep `framework/EAs/` flat; partition by registry status, not by path

**Date:** 2026-05-23
**Status:** Decided (OWNER + Claude)
**Supersedes:** none
**Related:** PIPELINE_REWRITE_PROPOSAL_2026-05-23.md (build queue of ~1,917 EAs)

## Context

The 2026-05-23 pipeline rewrite produces a build queue of ~1,917 strategy
cards yet to be turned into EAs (2,133 cards − 216 EAs already built). With
the new Q01 zero-trade revision loop spawning `_v2` / `_v3` variants, the
EA count could reach 5,000+ within a month. Open question: should the
filesystem layout `framework/EAs/QM5_*/` partition (status-based,
range-based, hybrid) or stay flat?

## Decision

**Keep `framework/EAs/` flat. Use the registry, not the filesystem, for
status partitioning.**

## Rationale

| Consideration | Flat | Status-partitioned | Range-partitioned |
|---|---|---|---|
| Filesystem performance at 10K dirs | ✓ NTFS handles fine | ✓ | ✓ |
| Operational `ls` view at 5K dirs | ✗ unwieldy | ✓ | ✓ |
| Code coupling cost (path resolvers everywhere) | ✓ none | ✗ high | ✗ medium |
| Log path stability (`MQL5/Logs/QM/...`) | ✓ stable | ✗ breaks on move | ✓ stable |
| EA status changes (revision, close, re-activate) | ✓ no-op | ✗ requires dir-move per transition | ✓ no-op (ID stable) |
| Git diff readability of layout change | ✓ no change | ✗ 200+ renames | ✗ 200+ renames |
| Backup / cold-storage extraction | partial via script | ✓ rsync the dir | partial |

The "operational `ls` view" disadvantage of flat is solved by a query, not
by a layout change. The "code coupling" and "log path stability"
disadvantages of partitioning are real, present, and irreversible — moving
back from partitioned to flat is also a 200-rename diff.

**Querying is cheap. Filesystem moves are expensive.**

## What this means in practice

1. `framework/EAs/QM5_<NNNN>_<slug>/` stays the canonical path. No subfolders.
2. `framework/registry/ea_id_registry.csv` is the source of truth for status
   (`active / closed / revision / archived`). Already exists.
3. New helper `tools/strategy_farm/ea_view.py` provides:
   - `ea_view.py --status active` → filtered list
   - `ea_view.py --status closed --since 2026-04-01` → time-windowed
   - `ea_view.py --range 1000-1999` → ID-range view
   This replaces `ls framework/EAs/` as the operator-facing listing.
4. Dashboards (cockpit, strategies.html, EA detail pages) already filter
   by registry status. No changes needed there.

## Future cold-storage (NOT NOW)

When an EA has been `status=closed` for ≥ 90 days AND no open task references
it, a future batch script `archive_old_eas.py` may:

1. Tarball the EA directory: `framework/EAs/QM5_<id>_<slug>/` →
   `framework/EAs_archive/<YYYY>/QM5_<id>_<slug>.tar.zst`
2. Remove the live directory.
3. Update the registry: `status=archived`, `archive_path=<tarball>`.

The dashboard EA detail page handles archived EAs by linking to the tarball
(downloadable via a small static-file server) rather than rendering live data.

This is a future optimisation, not part of the 2026-05-23 rewrite. Triggered
only when `framework/EAs/` grows beyond ~10K active+closed entries OR disk
pressure makes it relevant.

## Rejected alternatives

### Alternative 1: Status-partitioned `framework/EAs/{active,closed,revision}/`

Rejected because EA status changes frequently. Every revision, every
closeout, every re-activation would require:
- `git mv` of the EA directory (200+ files per EA, large diff per move)
- Update of log file path in scheduled tasks (per terminal)
- Update of `magic_numbers.csv` path references
- Update of `gen_setfile.ps1` directory resolver
- Update of every Q-runner script

Risk of broken evidence trail if any update is missed.

### Alternative 2: Range-partitioned `framework/EAs/{1000-1999,2000-2999,...}/`

Rejected because:
- One-time migration cost is the same as Alternative 1 (~200 renames now)
- All path resolvers in code still need updating
- The only benefit (faster `ls`) is solved more cheaply by `ea_view.py`

### Alternative 3: Hybrid (`active/<range>/`, `closed/<range>/`)

Rejected — combines the worst of both: per-transition moves AND range
bucketing.

## Implementation

1. Document this decision (this file).
2. Write `tools/strategy_farm/ea_view.py` (~50 lines) as the operator-facing
   listing helper.
3. No filesystem changes required.
4. No code changes to existing path resolvers.
