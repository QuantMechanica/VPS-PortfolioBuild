# Q04 stranded-infrastructure requeue recheck

Router task: `e685432a-42b6-4396-9151-4ba59f03457a`

## Live disposition

The requested 21-EA cohort has already been materially requeued in the live
control plane. A read-only query of
`D:/QM/strategy_farm/state/farm_state.sqlite` found 163 Q04 rows for the exact
21 EAs; 84 were created on or after the 2026-08-17 recovery wave start. Current
state is 146 `done`, 11 `failed`, 6 `pending`, and 0 `active`. The six pending
rows are existing successors, not missing work to duplicate:
`da4a947d`, `169a3481`, `a5263e59`, `c624cdb2`, `bd16e28a`, and `17022618`.

All 21 EAs remain `active` in `framework/registry/ea_id_registry.csv`. Each
has a canonical EX5, and its current SHA matched the latest non-INFRA Q04
binding recorded for that EA (21/21). No current source/binary mismatch was
found that would justify a new requeue.

The attempt-count check confirms the sentinel rule remains effective:

| Sentinel | Current rows |
|---|---:|
| `attempt_count=99` log-bomb sentinel | 11 |
| `attempt_count=50` active-timeout sentinel | 3 |
| total poison sentinels | 14 |

The recovery code defines values at or above `ATTEMPT_COUNT_POISON_FLOOR=12`
as deliberate non-retry sentinels; focused tests passed `24`.

## Safety decision

No row was requeued, rewritten, or mutated in this recheck. The live queue
already contains the staged recovery successors, and requeueing the six
pending rows or any sentinel row would create duplicate work or re-detonate a
known infrastructure failure. The current state is ready for ordinary worker
drain and separate diagnosis of any fresh INFRA_FAIL; it does not authorize a
third retry wave.

RESULT task=e685432a state=ALREADY_REQUEUED cohort_eas=21 post_wave_rows=84 q04_done=146 q04_failed=11 q04_pending=6 active=0 sentinels_99=11 sentinels_50=3 binary_matches=21 verdict=NO_DUPLICATE_REQUEUE
