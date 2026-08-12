# QM5_13301 one-second timer deviation

Date: 2026-07-28  
Router task: `35dee95d-f2c8-4ca3-b2df-28828663107f`  
Verdict: **BUILD PASS; GOVERNED PAIR QUEUED; DEVIATION NOT ESTABLISHED**

## Scope and operational meaning

The joint EA is a **backtest-only measurement instrument**. Live realization of
this three-sleeve book remains three gated EAs, one per symbol and chart, with the
gated QM5_13301 receiving real `OnTick` events. Neither this variant nor a joint EA
is authorized for live deployment.

The separate source
`framework/EAs/QM5_13301_timer-measurement/QM5_13301_timer-measurement.mq5`
includes the untouched gated source with only its event functions renamed. Its
wrapper leaves closed-bar entry evaluation on `OnTick` and moves
`Strategy_ManageOpenPosition` plus `Strategy_ExitSignal` handling to a one-second
`OnTimer`. The same kill-switch, news, Friday-close and strategy no-trade guards
remain fail-closed on both paths.

The gated source was not edited. No terminal was launched manually, T5 and T_Live
were excluded, and AutoTrading was not changed.

## Same-vintage serial build

Both arms were compiled serially against the same current include tree:

| arm | compile evidence | result | MQ5 SHA-256 | staged EX5 SHA-256 |
|---|---|---|---|---|
| gated tick control | `framework/build/compile/20260728_145319/QM5_13301_balke-minute-range-breakout.compile.log` | 0 errors, 0 warnings | `ee72c9299d0e5155d9f3a5e7083823a2f978c72f510fc3f1cf912701c10a446f` | `3f3deac97d4819bf030bcf3e5153bc21f439a6aedb0ca430b3967fcbb236c625` |
| timer 1 s | `framework/build/compile/20260728_145338/QM5_13301_timer-measurement.compile.log` | 0 errors, 0 warnings | `eaaf57d0c68fa04b87b0e5b800093628646bc17d579631787786375078690726` | `08e55289829a1aef2670322c0da3755b31f268ef6f69f4785bb88a4b59fdfe82` |

Immutable staging roots are
`D:/QM/strategy_farm/artifacts/ex5_staging/13301_timer_deviation_35dee95d/tick/`
and `.../timer_1s/`. Each work item requires its recorded SHA before and after
execution.

The fixed-risk sets use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Focused
`validate_build_guardrails.py` validation passed both EA directories with no
findings and the enforced maximum news staleness of 336 hours. The extended
comparator regression suite passed (`2 passed`).

## Governed measurement

Both Q02 arms use Model 4, GDAXI.DWX/M5, the common 2018-07-02 through
2025-12-31 window, current FILE_COMMON news seed, and `skip_terminals=["T5"]`.

| arm | work item | state at handoff |
|---|---|---|
| gated tick control | `efc84bc7-8e44-4cb0-8e05-a03ed24d8f7d` | pending |
| timer 1 s | `bbe93c4f-4b5c-4e24-878c-ef21ca9beec6` | pending |

The busy governed queue had not claimed either item during this single-pass
orchestration cycle. Therefore no report or trade stream exists for either new
arm and the requested comparison is not yet computable.

| measure | gated tick | timer 1 s | delta |
|---|---:|---:|---:|
| trade count | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| exact / shifted-exit / different-entry / extra / missing | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| net P&L | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| med60 | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| \|worst day\| | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| wDD_p90 | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |
| FUND_SCORE | NOT ESTABLISHED | NOT ESTABLISHED | NOT ESTABLISHED |

No 5-second or bar-close arm was queued: the required 1-second decision pair must
first produce valid evidence, and adding optional arms ahead of it would consume
fleet capacity without resolving the OWNER decision.

## Preregistered acceptance proposal

Proposed bound, for OWNER acceptance rather than agent self-approval:

1. every economic component (`net`, `med60`, `|worst day|`, `wDD_p90`,
   `FUND_SCORE`) differs by no more than 10% relative, with both the absolute and
   relative deltas reported;
2. the timer arm introduces no single-day loss worse than the gated arm's worst
   day;
3. entries remain identical; deviations are confined to same-entry,
   same-volume shifted exits attributable to one-second scheduling;
4. median absolute exit-time shift is at most one simulated second and the
   maximum shift is explicitly reported and explained.

If a gated value is zero, the relative test is undefined and OWNER must decide
from the absolute delta. The bound is preregistered before results and must not be
relaxed after observing them.

## Future joint-instrument error bar

For the proposed three-sleeve joint EA, the host runner remains native `OnTick`;
timer-safe satellites retain their measured closed-bar behavior; QM5_13301 would
be the one-second timer-simulated satellite. Any joint result must carry the
measured QM5_13301 deviation as a known error bar. Any live decision references
the three gated per-symbol EAs, never the joint instrument.

OWNER decision once both work items finish:

> Choose slot 2 = **13301-timer** if the preregistered bound passes; otherwise
> choose **13108**.
