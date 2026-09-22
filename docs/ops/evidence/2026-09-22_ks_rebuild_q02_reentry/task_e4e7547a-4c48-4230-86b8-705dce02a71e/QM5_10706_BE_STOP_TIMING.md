# QM5_10706 break-even stop timing and live consequence

This note separates two clocks that coexist in the rebuilt EA but do not share
a trade-operation path.

## The one-second timer is kill-switch infrastructure

`QM_FrameworkInit` arms `EventSetTimer(1)` only outside the tester and only
when the governed FTMO contract or chart UI requires it. `OnTimer` delegates to
`QM_FrameworkOnTimer`, which refreshes the FTMO kill-switch broker day and the
chart UI. It does not call the strategy entry signal, open-position manager, or
a trade operation.

The kill-switch's live Prague clock begins with `TimeGMT()`, derives the MT5
server and Europe/Prague offsets, and therefore advances on weekends or other
no-tick periods when `TimeCurrent()` can remain frozen. The timer can emit and
persist rollover state such as `KS_DAY_ROLLOVER`; it cannot create an entry or
move the strategy's break-even stop.

## The break-even stop remains tick-driven

`QM5_10706_tv-mon-ls.mq5::OnTick` calls
`Strategy_ManageOpenPosition()` on each eligible tick. The manager arms the
lock when profit reaches `BeTriggerR` or age reaches `BeBars`, calculates a
stop at `BeLockFrac` of initial risk, and sends `MON_SWEEP_BE_LOCK` only if the
new stop is on the valid market side and improves the existing stop. If the
time branch has armed but price has not cleared the lock, it waits for a later
tick instead of repeatedly sending invalid-stop requests.

In the retained Model=4 base-control comparison, deal 15 is the only shifted
deal: the predecessor exits at `2018.09.12 13:03:44`; the rebuild installs the
break-even SL at `13:03:45` and the stop fills at `13:03:47`. All 151 entry
times and every compared non-time deal field are exact. This is a later-tick
stop installation caused by the market-side guard, not a timer-driven entry or
exit.

## Live consequence

The one-second `TimeGMT` path improves Prague-day rollover correctness during
no-tick periods. It does not make strategy execution one-second deterministic.
Break-even management still waits for market ticks and a valid broker-side
stop. A position can therefore remain exposed for extra ticks; on another tick
path the eventual exit time, fill price, or PnL can differ. The mechanics
change is not economically null in general, so the base-control pair remains
`NOT_EQUIVALENT` and cannot carry evidence for the selected ablation-02 preset.
That selected preset requires its own Q02 and append-only Q03-Q10 chain.
