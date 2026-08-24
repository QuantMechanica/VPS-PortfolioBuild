# rb-411xx-build-gate evidence — 2026-08-23

Ticket: `rb-411xx-build-gate`

Authority: `router_ops_issue:50467e7e`

Worktree: `C:\QM\worktrees\rb-411xx-build-gate`

Runtime: `D:\QM\strategy_farm`

## Status

Source repair, generator-prompt prevention, unit tests, exact-hash append-only
enqueue, and per-EA Python build-gate validation are complete. The final
MetaEditor/PowerShell build-check proof is pending the governed factory compile
lane: live T1-T7 terminal processes correctly refused every ad-hoc compile and
even `build_check -SkipCompile`. No terminal was stopped, no factory state was
toggled, no guard was bypassed, and no unscoped build check was run.

The required `agents/board-advisor` merge was completed first as a fast-forward
from `978f9dc86` to `16120953d`. The canonical checkout stash was not popped or
modified.

## Root cause and rule disposition

The rule is correct and was not changed. `framework/scripts/build_check.ps1`
invokes `tools/strategy_farm/build_gate_hardening.py`; D10 rejects a dynamically
resized numeric or `CopyBuffer` target when an indexed access has no local proof
tied to its actual size/copy count (`build_gate_hardening.py:518-647`).

The commodity/XAUXAG build wave generated arrays with `ArrayResize`, but proved
indices only against requested/configured counters such as
`strategy_max_month_sessions`. A HEAD-versus-worktree census using the D10
checker found exactly 20 defective `QM5_411xx` sources and 30 failing accesses.
The worktree census is zero failures for all 20.

The shared generation defect was in the Codex build prompt: it prohibited raw
`CopyBuffer` but did not require actual-runtime-size proofs for other dynamic
numeric arrays. The prompt now requires `ArraySize`-bound access and explicit
`CopyBuffer` return-count validation
(`tools/strategy_farm/prompts/codex_build_ea.md:256-264`).

## Code changes

- Added local `ArraySize` guards before every defective access in all 20 affected
  EA sources. No strategy threshold, rule, entry/exit criterion, or gate contract
  changed; only fail-closed bounds proofs were added.
- Added the exact router authority and exact 20-label cohort to the governed
  COMPILE_EA source-repair contract
  (`tools/strategy_farm/compile_work_items.py:42-65`).
- Source repair refuses an unknown authority and refuses a usable `COMPILE_OK`
  for the current source hash; it may waive only the existing force-rebuild
  structural reasons, while preserving every prior row
  (`tools/strategy_farm/compile_work_items.py:369-535`).
- Enqueue is source-hash idempotent and checks all open rows again inside
  `BEGIN IMMEDIATE`, preventing a stale row from masking a current-hash row in a
  race (`tools/strategy_farm/compile_work_items.py:733-866`).
- Worker recheck recognizes only a correctly stamped source-repair row
  (`tools/strategy_farm/compile_work_items.py:1160-1178`).
- Exposed the exact authority through `farmctl enqueue-compile`
  (`tools/strategy_farm/farmctl.py:6570-6617`, `:26506-26524`,
  `:27075-27085`).
- Added prompt/cohort regression tests
  (`tools/strategy_farm/tests/test_build_gate_hardening.py:379-405`) and
  append-only, current-hash idempotence, worker-recheck, and usable-verdict
  refusal tests (`tools/strategy_farm/tests/test_compile_work_items.py:93-196`).

## Per-EA result and append-only work item

`Python gate` is the exact `build_gate_hardening.py --ea-label <label>` checker
called by `build_check.ps1`. Every row returned exit 0, one file scanned, zero
failures, and `D10=0`. Each also produced three existing non-failing warnings
because the checker could not locate a unique Strategy Card.

`PowerShell build_check` records the required scoped command
`build_check.ps1 -EALabel <label> -Strict -SkipCompile`. Each stopped at the
live-factory compile guard with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` before the
static scan. The standalone `compile_one.ps1 -EALabel
QM5_41109_xauxag-mmean-median-rv` was refused for the same reason; receipt:
`D:\QM\reports\compile\20260823_180118\summary.csv`.

| EA label | Repaired source line(s) | HEAD D10 | Python gate | PowerShell build_check | Append-only work item |
|---|---:|---:|---|---|---|
| `QM5_41104_xauxag-mmedian-shift-rv` | `:728`, `:767` | 2 | PASS, D10=0 | BLOCKED: live factory | `62ce0b4a-fc45-4b28-9381-4f58ed94827c` |
| `QM5_41109_xauxag-mmean-median-rv` | `:724` | 1 | PASS, D10=0 | BLOCKED: live factory | `cc09145c-a6d6-4cb0-88a4-e10ef58cc58d` |
| `QM5_41110_xauxag-moutside-res-rv` | `:791` | 1 | PASS, D10=0 | BLOCKED: live factory | `ec37ed6d-482e-4760-99df-ebf9cd3681fc` |
| `QM5_41111_wti-mdaybreadth-mom` | `:552` | 1 | PASS, D10=0 | BLOCKED: live factory | `cee2423d-d224-4581-a127-5fdfb548a5fa` |
| `QM5_41112_xauxag-mdaybreadth-rv` | `:722`, `:788` | 1 | PASS, D10=0 | BLOCKED: live factory | `b2cb3830-6542-4d61-ad87-ec63adb07cb2` |
| `QM5_41113_xauxag-mhalfagree-rv` | `:723`, `:793` | 1 | PASS, D10=0 | BLOCKED: live factory | `d62f097c-fedc-4643-a671-968a667a4f42` |
| `QM5_41116_xauxag-mthirdvote-rv` | `:727`, `:799` | 1 | PASS, D10=0 | BLOCKED: live factory | `65429bf8-28a5-46dd-a306-d7231ed7aa59` |
| `QM5_41118_xauxag-mlatehalf-dom-rv` | `:729`, `:797` | 1 | PASS, D10=0 | BLOCKED: live factory | `4c3f4186-8c20-40a3-a163-d53418aa2df7` |
| `QM5_41119_xauxag-mclose-quartile-rv` | `:722`, `:757` | 1 | PASS, D10=0 | BLOCKED: live factory | `2823303f-2984-49ff-a794-c34cd6a91527` |
| `QM5_41120_xauxag-mopen-residence-rv` | `:736`, `:768` | 2 | PASS, D10=0 | BLOCKED: live factory | `11348cba-e8bc-405b-acbb-a15cf45b1756` |
| `QM5_41121_xauxag-mseqdom-rv` | `:731`, `:764` | 2 | PASS, D10=0 | BLOCKED: live factory | `d3137a1c-2b0f-4120-8cc3-b3fd2840d0ca` |
| `QM5_41123_xauxag-mpath-eff-rv` | `:732`, `:764` | 2 | PASS, D10=0 | BLOCKED: live factory | `f1c50421-67c4-473f-b089-27e05acdd621` |
| `QM5_41124_wti-mrms-coherence-mom` | `:477`, `:506` | 1 | PASS, D10=0 | BLOCKED: live factory | `2de9682b-480f-42b5-a43c-bb3f387ab3c4` |
| `QM5_41125_xauxag-mrms-coherence-rv` | `:735`, `:781`, `:797` | 2 | PASS, D10=0 | BLOCKED: live factory | `9ea12411-fd99-4e38-9cac-a2aace69896b` |
| `QM5_41126_wti-mpath-eff-mom` | `:477`, `:506` | 1 | PASS, D10=0 | BLOCKED: live factory | `cc714ac2-ff1f-4604-ae08-7631ddf3b971` |
| `QM5_41127_wti-mdaily-persist-mom` | `:501`, `:531`, `:541` | 2 | PASS, D10=0 | BLOCKED: live factory | `76b9e5e3-d257-4957-88fa-a33d90a846c0` |
| `QM5_41128_xauxag-mdaily-persist-rv` | `:749`, `:795`, `:807`, `:825` | 3 | PASS, D10=0 | BLOCKED: live factory | `84fc53c7-e5a0-4fb0-9aa4-c2dbd15cfbb6` |
| `QM5_41130_wti-mopen-residence-mom` | `:487`, `:523` | 1 | PASS, D10=0 | BLOCKED: live factory | `0edf3c6a-c29d-4b90-9787-f099bb23d4e2` |
| `QM5_41131_wti-mdaily-tailtrim-mom` | `:492`, `:523`, `:531`, `:581` | 3 | PASS, D10=0 | BLOCKED: live factory | `34785097-be1a-448e-9a8e-28ee665e9ea6` |
| `QM5_41132_wti-mweekday-med-mom` | `:497`, `:536` | 1 | PASS, D10=0 | BLOCKED: live factory | `bdae4d54-e686-48e8-bde7-e3b5fdc95dd3` |

Today’s durable failing evidence existed for eight members before repair:

- `D:\QM\reports\work_items\37b24b40-92d0-4a56-9e5d-7913f6fe0c45\QM5_41104\COMPILE_EA\compile_evidence.json`
- `D:\QM\reports\work_items\55cdd439-9f1e-4d26-a917-66a23b783abe\QM5_41109\COMPILE_EA\compile_evidence.json`
- `D:\QM\reports\work_items\58d5cd89-d9db-4a82-82e1-66e93171b8cd\QM5_41110\COMPILE_EA\compile_evidence.json`
- `D:\QM\reports\work_items\4f496575-3813-43d1-9df4-5c3a81d0e4ff\QM5_41111\COMPILE_EA\compile_evidence.json`
- `D:\QM\reports\work_items\eb39f64b-4a53-4971-bb78-907fd067a0d9\QM5_41112\COMPILE_EA\compile_evidence.json`
- `D:\QM\reports\work_items\df4cc97d-a372-4036-935e-cc5a2ff72d88\QM5_41119\COMPILE_EA\compile_evidence.json`
- `D:\QM\reports\work_items\30ff1030-eb5b-412d-a293-f4bc3f275b85\QM5_41120\COMPILE_EA\compile_evidence.json`
- `D:\QM\reports\work_items\1fba43ee-aa57-4ee8-ba97-827467710cbd\QM5_41128\COMPILE_EA\compile_evidence.json`

## Enqueue evidence

The interrupted run had already appended the 20 authorized rows at
`2026-08-23T17:14:00+00:00`. Read-only URI query:

```sql
SELECT COUNT(*) AS rows,
       SUM(w.status='pending' AND w.verdict IS NULL) AS pending_without_verdict,
       SUM(h.active=1) AS active_holds,
       MIN(w.created_at), MAX(w.created_at)
FROM work_items w
LEFT JOIN work_item_holds h ON h.work_item_id=w.id
WHERE w.phase='COMPILE_EA'
  AND json_extract(w.payload_json,
      '$.compile_source_repair_authority')='router_ops_issue:50467e7e';
```

Result: `rows=20`, `pending_without_verdict=20`, `active_holds=19`, and both
timestamps `2026-08-23T17:14:00+00:00`. A separate read-only hash census proved
all 20 payload `mq5_sha256` values equal their repaired worktree source hashes.

The required worktree-only `farmctl enqueue-compile` call used the documented
single-process `QM_ALLOW_NONCANONICAL=1` override and the exact 20 labels plus
`--source-repair-authority router_ops_issue:50467e7e`. Result:
`ok=true`, `requested_count=20`, `idempotent_open_count=20`,
`enqueued_count=0`, `refused_count=0`. Thus the interrupted enqueue was retained
and no duplicate rows were added.

## Test evidence

- `python -m pytest -q tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_compile_work_items.py`
  — `45 passed in 356.98s`.
- Final post-dedup test:
  `python -m pytest -q tools/strategy_farm/tests/test_compile_work_items.py`
  — `16 passed in 3.32s`.
- Final focused touched-path run (two D10/prompt regressions plus the complete
  compile-work-item suite) — `18 passed in 4.21s`.
- `python -m py_compile tools/strategy_farm/compile_work_items.py tools/strategy_farm/farmctl.py tools/strategy_farm/build_gate_hardening.py`
  — exit 0.
- `git diff --check` — exit 0 (only expected LF→CRLF checkout warnings).
- Per-EA hardening runner — 20/20 exit 0, 20/20 zero failures, 20/20 D10=0.

## Rollback

Revert this ticket’s commit with `git revert <commit>`; do not reset the branch.
That restores the previous EA source and prompt/tooling bytes. The 20 runtime
work-item rows are append-only evidence and must not be deleted or have verdicts
overwritten. If code is reverted before they run, their source-hash binding will
fail closed at worker recheck; disposition/release must use a separately
authorized governed action.

## Remaining operational proof

After this commit reaches the canonical checkout and a governed compile slot is
available, the queued rows must produce `COMPILE_OK` evidence. Until then, there
is no honest standalone `COMPILE_OK` claim for the repaired source. The block is
the active live-factory compile interlock, not D10 or an MQL compiler error.

## Review fixes (2026-08-23, FIX_REQUIRED remediation)

Review verdict `FIX_REQUIRED` raised two findings against the pre-merge branch.
Disposition:

### P0 — merged tree fails the branch's own QM5_411* census test

Root cause confirmed by trial merge: `agents/board-advisor` carries the sibling
EA `QM5_41133_wti-mdaily-median-mom` (absent from this branch pre-merge, held at
CPU ceiling / never compiled) whose source contained the identical
`EA_INDICATOR_BUFFER_UNBOUNDED` defect class the branch's
`test_qm5_411xx_sources_have_no_unbounded_numeric_buffers` census guards. Because
that test globs the whole `QM5_411*` family, the merged factory tree was red on a
touched suite even though the pre-merge branch was green.

Resolution (fix, not test-narrowing): `agents/board-advisor` was merged into this
branch (`merge(board-advisor): pull sibling 411xx EA QM5_41133 into build-gate
branch`; auto-merged cleanly, no textual conflicts) and the same mechanical
`ArraySize(...)` guard class was extended to `QM5_41133`. Three plain-identifier
dynamic-buffer accesses were bounded (the checker's combined-`||`-with-nested-
`ArraySize` form is not recognized because its `[^)]*` cannot cross the inner
`)`; the guards were split / added as standalone fail-fast checks, logically
identical to the prior combined conditions):

- `month_closes[index]` (loop `Strategy_LoadDailyMedianSignal`) — split the
  combined guard into two standalone `if(... >= ArraySize(...)) return false;`.
- `daily_returns[return_count]` — same split.
- `daily_returns[index]` (post-`ArraySort` validation loop) — added
  `if(index >= ArraySize(daily_returns)) return false;` at loop top.
- `daily_returns[center]` (median center block) — added
  `if(center >= ArraySize(daily_returns)) return false;` after the existing
  `return_count` guard.

`daily_returns[index-1]` / `daily_returns[center-1]` are non-identifier indices
and outside this narrow check; no change. The census now covers 21 EAs.

Verification on the merged tree:
- `python -m pytest tools/strategy_farm/tests/test_build_gate_hardening.py::test_qm5_411xx_sources_have_no_unbounded_numeric_buffers`
  — `1 passed` (was `1 failed` immediately post-merge, reporting
  `QM5_41133_...:526` and `:535`).
- `python -m pytest tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_compile_work_items.py`
  — `45 passed`.

### P1 — no standalone COMPILE_OK artifact for the repaired EAs

Unchanged at fix time and NOT actionable inside this FIXER's authority: this seat
is read-only on `D:/QM`, must never enqueue, never toggle the factory, and never
compile ad-hoc (the live-factory interlock `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`
refuses every `build_check` / `compile_one.ps1`). COMPILE_OK therefore remains
deferred to the governed compile lane, exactly as the "Remaining operational
proof" section already discloses. The D10 static gate passes for all 20 original
EAs and now for `QM5_41133` (buffer-bound census green). Two consequences to
surface for the governed lane / OWNER:

- The 20 append-only `COMPILE_EA` rows (authority
  `router_ops_issue:50467e7e`) stay source-hash-bound and must produce
  COMPILE_OK when a governed slot opens.
- `QM5_41133`'s source hash changed with this repair; it has NO governed
  COMPILE_EA row of its own (it was previously held at CPU ceiling, never
  compiled). It needs a separately authorized governed COMPILE_EA enqueue with
  its new repaired hash before it can claim COMPILE_OK. This FIXER cannot enqueue
  it; it is surfaced as the P1 residual and belongs to the governed compile lane.

Net: P0 fixed (merged tree green on the touched suite); P1 is the pre-existing,
honestly-disclosed COMPILE_OK deferral, now extended to include QM5_41133, and
requires the governed compile lane plus explicit OWNER acceptance of the deferral
before this merge lands in the factory.

## Governed-lane follow-up — 2026-08-24

The blanket statement above that there was no standalone `COMPILE_OK` is now
closed. A read-only URI query of the exact 20 source-repair work-item IDs plus
the `QM5_41133` row returned `rows=21`, `COMPILE_OK=1`, `pending=20`,
`active=0`, and `active_holds=20`. No pending row was changed or released.

The successful row is `cc09145c-a6d6-4cb0-88a4-e10ef58cc58d` for
`QM5_41109_xauxag-mmean-median-rv`, completed
`2026-08-23T22:17:28+00:00`. Its durable artifact chain is:

- evidence: `D:\QM\reports\work_items\cc09145c-a6d6-4cb0-88a4-e10ef58cc58d\QM5_41109\COMPILE_EA\compile_evidence.json`;
- build-check report: `D:\QM\reports\framework\21\build_check_20260823_221618.json`;
- MetaEditor log: `C:\QM\repo\framework\build\compile\20260823_221622\QM5_41109_xauxag-mmean-median-rv.compile.log`;
- compile summary: `D:\QM\reports\compile\20260823_221622\summary.csv`;
- recorded result: compile `PASS`, build-check `PASS`, zero errors, zero
  warnings, recorded EX5 SHA-256
  `269058afe6b11abab89286ee9a8d3efe535c5298b2eee0001e0fe27da867d16c`.

The source binding remains current: all 20 original source-repair rows match
their worktree MQ5 hashes. `QM5_41133` is the exception in the 20+1 cohort:
its held row `1fb58c79-e46f-4d72-9af1-26eb4656e0d5` is bound to pre-repair MQ5
SHA-256 `7c8aeb3382bf3d8b84325661dfb699458bd115c84455e04c9a0c5a34f08ded04`,
while the repaired source is
`9d7f41c8db3991e626c9577512be267699574ce6df08fd95f327c3013e761ff5`.
It was left pending as directed; it is not current-hash compile proof.

There is also binary-path drift to preserve explicitly: the current canonical
EX5 at the path named by the successful evidence hashes to
`e6acd7a248f836fd2b916dcd211c8393975d22dc3da24645df52bb0bed420a00`
(the earlier compile's hash), not the successful row's recorded EX5 hash. The
immutable DB row, evidence JSON, report, log, and summary prove the governed
compile occurred, but the exact successful EX5 bytes are no longer present at
that mutable canonical path. Therefore the prior **zero-COMPILE_OK** deferral is
closed for `QM5_41109`; complete wave proof remains deferred for the 20 rows
still pending, and artifact retention drift remains open.
