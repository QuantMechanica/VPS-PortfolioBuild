# Review — BUILD-13128-NEW-IDENTITY (router task ee266d6d)

- Task: `ee266d6d-8a67-446f-9559-80332896c299` (ops_issue), state REVIEW, assigned claude.
- Worker deliverable: `docs/ops/evidence/2026-08-23_13128_new_identity.md`.
- Verdict: **APPROVED** (formally clean; Q02 enqueue correctly deferred to post-compile).

## What was verified (read-only)

| Claim | Check | Result |
|---|---|---|
| New EA dir forked | `ls framework/EAs/QM5_41129_pre-fomc-drift-ndx-v2/` | present: `.mq5`, `SPEC.md`, `sets/…_NDX.DWX_H1_backtest.set` |
| ea_id row | `ea_id_registry.csv:4630` | `41129,pre-fomc-drift-ndx-v2,nyfed-sr512-pre-fomc-drift-v2,active,claude,2026-08-23` ✓ |
| magic row + formula | `magic_numbers.csv:17862` | `41129,…,0,NDX.DWX,411290000` = 41129*10000+0 ✓ |
| new `.mq5` sha256 | `sha256sum` | `00d3944a…` = doc claim ✓ |
| new `.mq5` == drifted source (identity lines only) | `diff 4112f5b07:…mq5` vs new | only 2 lines differ: `#property description` and `input int qm_ea_id 13128→41129` ✓ |
| old `.mq5` reverted to EX5-producing source | `sha256sum` = `e2bd93a2…`; `git show 027f45752:…mq5 \| sha256sum` = `e2bd93a2…` | exact match to `4112f5b07^`=`027f45752` ✓ |
| old `.ex5` untouched | `sha256sum` = `59b9d16…` = doc claim | hard constraint honored ✓ |
| compile queued (governed, not direct) | DB `work_items` `7c31701a` | `kind=compile, phase=COMPILE_EA, ea_id=QM5_13128?`→`QM5_41129`, `status=pending` ✓ |
| old compile row kept as OBSOLETE | DB `work_items` `3c893190` | `QM5_13128, COMPILE_EA, pending` — not deleted ✓ |
| Q02 for 41129 NOT enqueued | DB scan `ea_id LIKE %41129%` | only the compile row exists — no Q02 bound to a nonexistent binary ✓ |

## Framework conformity of the new EA (goes to Q02 next cycle)

- `#include <QM/QM_Common.mqh>` (line 27); `RISK_PERCENT=0.0` / `RISK_FIXED=1000.0` backtest convention (lines 36-37); `QM_FrameworkTrackOpenPositionMae()` present and first on tick (line 349); news gate deliberately OFF under the OWNER-ratified event-anchored exemption (`decisions/2026-07-24_news_blackout_exemptions.md`, lines 15-25/361-369) — the timed 20:00 flat-before-statement exit IS the news-risk management; no ML libs; no hardcoded commission/swap. Magic via `qm_ea_id` input = 41129.

## Notes (non-blocking)

1. The deliverable doc §1 characterizes the `4112f5b07` behavior delta as "removed the
   `QM_FrameworkTrackOpenPositionMae()` call". The diff actually shows the hook was **relocated**
   (removed at old site, re-added with a "direct and first on every tick" comment) — it is still
   present in both the drifted source and the new EA. The doc's conclusion (genuine
   logic/diagnostics delta → new identity) still holds; only the one-line description of the delta
   is imprecise. No effect on the deliverable.
2. Acceptance line "Q02 NDX.DWX enqueued" is **not** satisfied this cycle, but correctly so:
   `seed-fresh-q02` binds to the exact `.ex5`, which does not exist yet (compile is queued through
   the governed COMPILE_EA path, not run, per the factory-running hard constraint). Forcing Q02
   now would bind to nothing / fail the exact-binary check. Documented as next-cycle carryover
   (§4) — this is the sanctioned "pending-Zeile mit ID im Report" branch of the acceptance bar.

## Carryover (next cycle, not this review's scope)

- COMPILE_EA worker builds `QM5_41129…ex5` from `7c31701a`; then `build_check -EALabel` finalizes
  the setfile `build_hash`; then `seed-fresh-q02` for `QM5_41129`/`NDX.DWX` from the exact binary.
- `3c893190` (old drifted compile row) stays untouched/obsolete.

## Verdict

**APPROVED** — new identity cleanly created, registry + magic correct, source drift correctly
diagnosed and the old identity reconciled to its EX5-producing source (git-verified), compile
routed through the governed queue, all hard constraints honored. Q02 enqueue is legitimately
deferred until the binary exists.
