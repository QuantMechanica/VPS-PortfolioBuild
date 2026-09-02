# FX cointegration paced CPU-ceiling stop

Recorded: 2026-09-02T21:31:29.7905410Z (23:31 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `a83deac0bdf3935703c484122232088a875408fb`

## Outcome

The governed 66-pair FX cointegration frontier still has no eligible unbuilt
relationship. The preferred anchors do not need Q02 repair: `QM5_12532` and
`QM5_12533` have canonical logical-basket Q02 PASS evidence. The latest
eligibility audit identifies the existing structural D1 fallback as
`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`, with one priority-bound
`Q09_NEWS` continuation.

A fresh capacity check reached 99% CPU against the mission's 97% hard ceiling.
The wake therefore stopped before rereading or mutating that fallback row. No
Card, EA, basket manifest, setfile, queue item, priority mark, claim, dispatch,
compile, or backtest was created.

## Capacity evidence

The five whole-host samples were `96%`, `84%`, `85%`, `94%`, and `99%`.
Average CPU was `91.6%`; maximum CPU was `99%`. The rule binds when either the
average or maximum is at least 97%, so the maximum required an immediate stop.

This is a later observation than the 20:49Z fallback audit and was taken
against repository head `a83deac0bd`. It confirms that capacity remained
unavailable after that audit without duplicating its queue classification or
writing another priority marker.

## Safety and continuation

The portfolio gate and its admission/KPI/Q08-contribution surfaces, the
`T_Live` manifest and terminal, AutoTrading, and all live/deploy surfaces were
untouched. Unrelated shared-worktree changes were preserved.

On a later paced wake, sample CPU first. Only if both average and maximum are
strictly below 97% should the exact existing `QM5_12778` `Q09_NEWS` row be
reread and allowed to proceed through its ordinary paced-worker path. Do not
enqueue, reprioritize, manually claim, or dispatch a duplicate.

Machine-readable companion:
`artifacts/fx_cointegration_paced_cpu_stop_20260902T213129Z_board_advisor.json`.
