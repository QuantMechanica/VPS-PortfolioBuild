# Q09 pre-interface requalification recheck

Router task: `635ad39b-6f6b-44fd-8550-437c420769c3`

## Disposition

The task's eight-row acceptance scope is no longer present in the live control
plane. A read-only query of `D:/QM/strategy_farm/state/farm_state.sqlite`
found only two active `Q09_AWAITING_SEALED_PLAN` holds, for QM5_11476/USDJPY.DWX
and QM5_10148/EURNZD.DWX. Neither is one of the eight EAs in this task.

The eight originally named rows have changed state since the task was routed:

| EA | Q09_NEWS current latest state | Q08 current latest state |
|---|---|---|
| QM5_11288 | pending, no active hold | `FAIL_SOFT` |
| QM5_20266 | `CONFIG_LOCKED` | `INVALID` |
| QM5_9641 | pending, no active hold | pending, held `BOOK_V2_STREAM_RECOVERED_RERUN_NOT_NEEDED` |
| QM5_12855 | `INVALID_EVIDENCE` | pending, held `BOOK_V2_STREAM_RECOVERED_RERUN_NOT_NEEDED` |
| QM5_12849 | `CONFIG_LOCKED` | pending, held `BOOK_V2_STREAM_RECOVERED_RERUN_NOT_NEEDED` |
| QM5_12708 | pending, no active hold | `PASS` |
| QM5_13054 | pending, no active hold | `PASS` |
| QM5_1537 | `CONFIG_LOCKED` | `PASS` |

The current health snapshot corroborates the scope change:
`q09_sealed_plan_hold_age` reports 2 stale sealed-plan holds, both outside the
task's eight-EA set. It also reports the build lane blocked by the existing
repo-dirty build guard. No build, requeue, plan bind, hold release, or database
mutation was performed in this recheck.

## Safety decision

No serial rebuild was authorized by the current state: the eight-row dam no
longer exists as eight held Q09 rows, several successor rows already have
terminal dispositions, and the remaining rows lack the task's original
sealed-plan hold context. Requalifying or rebinding them now would invent new
work and could overwrite or duplicate current pipeline lineage. The correct
next action requires a fresh OWNER-scoped task against the current row IDs and
their current Q08/Q09 lineage.

RESULT task=635ad39b state_changed=true original_scope_rows=8 active_matching_holds=0 current_matching_holds=2 action=DEFERRED verdict=STATE_CHANGED_REQUIRES_FRESH_SCOPE
