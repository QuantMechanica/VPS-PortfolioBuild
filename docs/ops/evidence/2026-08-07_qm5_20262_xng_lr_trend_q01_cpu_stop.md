# QM5_20262 XNG Linear-Trend Quality Q01 And CPU Stop

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20262_xng-lr-trend` is built and Q01 is `PASS`. Q02 is
`NOT_ENQUEUED_CPU_CEILING`: the binding path-anchored capacity sample found
nine T1-T10 factory terminals executing against the paced ceiling of seven.
No target dry-run, apply-mode enqueue, dispatch command, or manual backtest was
run after that sample.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar of a genuine broker-month transition, the EA
reconstructs thirteen consecutive completed XNG month-end closes and fits an
ordinary least-squares line to their oldest-to-newest log prices. It trades the
slope direction only when `R^2 >= 0.50`; a flat, weak, malformed, stale, or
unavailable state consumes the month flat. Positions renew at the next broker
month, with one frozen `3.5*ATR(20,D1)` hard stop and a forty-calendar-day stale
guard.

The deterministic pre-allocation checker scanned 4,319 EA-registry rows and
436 cards, found no exact slug or strategy-ID collision, and returned six
expected source/mechanic-family fuzzy neighbors. Manual review resolved the
economically closest systems:

- `QM5_20261_wti-lr-trend` applies the same fixed path-quality rule to WTI;
  this build's exact XNG carrier is load-bearing and imports no WTI result;
- `QM5_20259_xng-mom-vote` votes on endpoint return signs rather than fitting
  the complete path;
- existing XNG time-series-momentum systems use endpoint returns or counts of
  monthly return signs rather than slope plus regression fit;
- `QM5_10581_mql5-lr-slope` is an H4 25-bar oscillator/signal-cross system on
  FX/XAU, without an XNG month-end path or fixed fit gate; and
- certified `QM5_12567_cum-rsi2-commodity` is a long-only daily cumulative
  RSI(2) pullback aligned with SMA(200), with a five-D1-bar maximum hold.

The XNG carrier, thirteen consecutive broker-month endpoints, log transform,
oldest-to-newest OLS orientation, slope direction, fixed `R^2` gate, consumed
monthly attempt, and monthly renewal are jointly load-bearing. The rule differs
materially from the incumbent XNG logic, but common carrier exposure does not
establish decorrelation; unchanged Q09 remains authoritative.

## Source And G0 Record

The tier-A source is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete governed paper review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded XNG extraction
is `strategy-seeds/sources/MOP-XNG-LRTREND-2026/source.md`.

The source supports monthly own-return continuation through twelve lags and
explicitly includes natural gas. The log-price regression and fixed fit gate
are transparent QM hypotheses, not author results. No source profitability,
XNG-constituent, CFD-equivalence, cost, density, or portfolio-correlation
result transfers.

G0 authorization is
`decisions/2026-08-07_qm5_20262_xng_lr_trend_g0.md`. The authorization is
commit `4e1167d50`, source/card approval `f07f504a5`, EA-ID reservation
`a570389f2`, magic allocation `e2f0aa29c`, deterministic artifact commit
`67d7fb3b7`, and source build commit `c380c8c32`.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20262` / `xng-lr-trend`.
- Strategy ID: `MOP-TSMOM-2012_XNG_LR12R2_S15`.
- Symbol/slot/magic: `XNGUSD.DWX` / 0 / `202620000`.
- Card schema/ML lint: PASS on the intake, canonical, and build cards; no
  missing sections or ML hits.
- Build prerequisite guard: PASS for EA registry, magic registry, and EA
  directory.
- SPEC validation: PASS, one target and zero failures.
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Target-scoped strict build gate:
  `D:/QM/reports/framework/21/build_check_20260807_085900.json` (`PASS`, zero
  failures and zero warnings).
- The gate's compiler invocation:
  `D:/QM/reports/compile/20260807_085900/summary.csv` (`PASS`, zero errors and
  zero warnings).
- Compile log:
  `C:/QM/repo/framework/build/compile/20260807_085900/QM5_20262_xng-lr-trend.compile.log`.
- EX5 size: 379,220 bytes.
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; generated header build hash
  `5f7b0136652f8cc6d7c6b5fc338f26fafbe2414e0a20f5f65eafa782613a9ca8`.
- Manual smoke/backtest: none.

Artifact SHA-256 values after the Q01/capacity-stop status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `DDCE60B671CD551D13C20FFC35F2066F6B2B77826A47972DD75EF02483C57C8D` |
| Canonical/build card | `29D097DD7E3D4EF82791E98934C024B74BE8FB3FA18FAA4D949DE9E9761F0C3E` |
| MQ5 | `2EB03E54B248477804914B69C0289427A5EFFBDBC9BB4ABA674F706D9DF6221E` |
| EX5 | `DD954FFAE0424E0BA930385BF2AEEC81ACB363234A4E3340C242DBB3E8D32145` |
| SPEC | `DEC55C7670762B664DDF03D732AC0E610E026EF9BB336DFD57219B00DBBE9733` |
| Backtest set | `62B60D7D95CB1E4B64FDADE0E519D41FD5EC7DF5101837A4558F0529106AAD1D` |

## Q02 Capacity Stop

`farmctl mt5-slots` sampled the governed processes at
`2026-08-07T09:03:28+00:00` and found nine exact factory terminals executing:

| Terminal | PID | Observed phase/state |
|---|---:|---|
| T1 | 15340 | Q02, `QM5_12512` |
| T2 | 15052 | Q09 news backfill |
| T3 | 18908 | Q09 news backfill |
| T4 | 13156 | Q04, `QM5_11353` |
| T5 | 7496 | Q02, `QM5_12538` |
| T7 | 17468 | Q07, `QM5_11177` |
| T8 | 15296 | Q02, `QM5_10369` |
| T9 | 19136 | Q09_NEWS, `QM5_11422` |
| T10 | 16108 | Q02, `QM5_20192` |

Only executing terminal processes rooted under
`D:/QM/mt5/T1..T10/terminal64.exe` count. The separate
`C:/QM/mt5/T_Live` and FTMO processes were observed but excluded and were not
accessed or changed. The governed sample is 9/7 and therefore binding.

Per the mission's CPU-stop condition, no enqueue dry run or apply command was
issued. A read-only `farmctl work-items --ea QM5_20262` check returned count
zero, so no Q02 work-item ID exists from this task. A later paced operator may
take a fresh immediate capacity sample and, only below the seven-terminal
ceiling, use the target-scoped sweep workflow for `QM5_20262` and
`XNGUSD.DWX`. This is a ready-but-capacity-blocked handoff, not a Q02 screening
verdict.

## Safety Boundary

- No apply-mode enqueue, dispatch tick, manual backtest, or downstream phase
  was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading and `T_Live` were not touched.
- The portfolio gate and T_Live manifest were not touched.
