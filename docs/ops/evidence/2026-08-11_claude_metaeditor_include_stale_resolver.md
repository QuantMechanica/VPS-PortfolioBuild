# MetaEditor stale-include-profile — smoke FAIL across all builds in claude-orchestration-3, 2026-08-11

## Summary

Every EA built in worktree `C:/QM/worktrees/claude-orchestration-3` on 2026-08-11
(`QM5_20074`, `QM5_20075`, `QM5_20076`, `QM5_20082`, `QM5_20085`, `QM5_20086`) compiled
cleanly (`build_check.ps1` PASS, `compile_one.ps1` PASS) but **failed smoke** with either
`EA_MAGIC_NOT_REGISTERED` (`OnInit` FAIL) or `BARS_ZERO` / `INCOMPLETE_RUNS`. This is an
infra fault in the compile→smoke path on this worker, **not a code defect** in any of the
six EAs — `.mq5` sources and the worktree's `framework/include/QM/QM_MagicResolver.mqh`
are correct.

## Root cause

`framework/scripts/compile_one.ps1` (`Resolve-TerminalIncludeTargets`) syncs
`framework/include` to:
- the SYSTEM-account MetaQuotes profile
  (`C:/Windows/System32/config/systemprofile/AppData/Roaming/MetaQuotes/Terminal/*`)
- `D:/QM/mt5/T1..T10/MQL5/Include`

But the MetaEditor binary actually invoked by `compile_one.ps1`
(`D:/QM/mt5/T1/metaeditor64.exe`) resolves `<QM/...>` includes from the
**Administrator-account** profile:
`C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/AE0A37E2EC2BC870ED414E4143BA21BF/MQL5/Include`
— a path `Resolve-TerminalIncludeTargets` never writes to.

That Administrator-profile copy of `QM_MagicResolver.mqh` is stale (15807 rows at the
time of this finding, unrelated content, last touched 2026-08-11T01:53Z) and does not
contain the freshly self-allocated magic rows for any of today's new EAs (e.g.
`QM5_20085` slots 0-8 / magic `200850000-200850008`, confirmed present at indices
15171-15179 of the correct worktree resolver but absent from the Administrator-profile
copy). Every `.ex5` compiled today therefore embeds a resolver that is missing its own
EA's magic rows, so the tester's `OnInit` fails with `EA_MAGIC_NOT_REGISTERED`.

`QM5_20082`'s smoke failed with a different symptom (`BARS_ZERO` / `INCOMPLETE_RUNS`, 4/4
runs on T5) rather than `EA_MAGIC_NOT_REGISTERED` — same class of tester/include-sync
infra fault, different manifestation; not separately root-caused here.

## Evidence

- `D:/QM/reports/smoke/QM5_20085/20260811_004421/summary.json` — `FAIL ONINIT_FAILED`,
  `EA_MAGIC_NOT_REGISTERED ea_id=20085 slot=0 magic=200850000`, reproduced on 2 runs
  (20260811_003824, 20260811_004421) including one post clean-recompile.
- `D:/QM/reports/smoke/QM5_20086/20260811_005915/summary.json` — same class,
  `ea_id=20086 slot=0 magic=200860000`.
- `D:/QM/reports/smoke/QM5_20082/20260811_000955/summary.json` — `FAIL`,
  `reason_classes=[BARS_ZERO, INCOMPLETE_RUNS]`, 4/4 tester runs on T5.
- Worktree resolver correctness verified directly: `framework/include/QM/QM_MagicResolver.mqh`
  in `C:/QM/worktrees/claude-orchestration-3` contains all of today's new magic rows
  (20074/20075/20076/20082/20085/20086) with 0 unexpected drops (aside from a pre-existing,
  unrelated gap: ea_ids 1001/1015/1016 have `magic_numbers.csv` rows but no EA dir
  materialized in this worktree yet — separate rekey-in-progress condition, not part of
  this fault).

## Impact

- All 6 EAs above are otherwise build-complete (spec PASS, build_check PASS, compile PASS,
  setfiles generated, committed to `agents/claude-orchestration-3` and pushed) and are in
  router state REVIEW. Their smoke evidence should be treated as **not yet obtained**
  rather than **FAIL** — re-run smoke once the include-sync gap below is closed.
- Any other build lane invoking `D:/QM/mt5/T1/metaeditor64.exe` under the Administrator
  account is exposed to the same gap; this is not scoped to claude-orchestration-3.

## Recommended fix (not applied here — out of scope for a build_ea task)

Add the Administrator-account MetaQuotes `Terminal/*/MQL5/Include` path(s) to
`Resolve-TerminalIncludeTargets` in `framework/scripts/compile_one.ps1` (or invoke
MetaEditor in `/portable` mode so it resolves includes relative to the terminal data
path instead of the OS user profile), then recompile + re-smoke the six affected EAs.

## Provenance

Discovered 2026-08-11 during three sequential capacity-spilled `build_ea` router tasks
(`QM5_20082`/`QM5_20085`/`QM5_20086`) executed by Claude in
`C:/QM/worktrees/claude-orchestration-3`. Filed by Claude.
