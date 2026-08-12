# QM5_20231 WTI Seasonal Twelve-Month Momentum Build And Q02 Enqueue

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; one priority Q02 work item PENDING

## Outcome

One new structural, low-frequency direct-energy candidate was researched,
approved, allocated, built, committed, strictly validated, and enqueued:

- EA: `QM5_20231_wti-seas-mom12`.
- Carrier: exact `XTIUSD.DWX`, D1, slot 0, magic `202310000`.
- Mechanic: on each broker-month boundary, reconstruct thirteen consecutive
  completed month-end closes. Buy in November-May only when the cumulative
  twelve-calendar-month return is strictly positive; sell in June-October
  only when it is strictly negative. Disagreement or equality consumes the
  month and stays flat.
- Lifecycle: close before monthly renewal, forty-day stale guard, frozen
  `3.5 * ATR(20,D1)` hard stop, no target, and restart-safe attempt state.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Planning cadence: 5-8 completed packages/year; Q02 must retire below five
  per full post-warm-up year.

Q02 priority work item `aeb35f94-4dfd-4ffc-9d68-76166e601ec7` was created at
`2026-08-05T20:32:24Z` for `XTIUSD.DWX`. It was pending, unclaimed, and at
attempt zero at handoff. No manual backtest or dispatch was run.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-SEASMOM12-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply positive November-May and
  negative June-October WTI physical-season directions.
- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), 228-250, supply monthly own-return-sign time-series momentum,
  selected twelve-month security-level evidence, and WTI in the commodity
  universe.

Neither source tests this interaction, continuous CFD carrier, exact broker-
month reconstruction, fixed cash risk, ATR stop, costs, financing, or the QM
portfolio. No source performance or correlation statistic transfers.

The deterministic pre-allocation checker found no exact slug or strategy-ID
identity across 4,288 registry rows and 404 cards. Manual review separates
the candidate from year-round twelve-month momentum, the winter-only and
summer-only 252-D1 interactions, twelve-sign breadth, one-month momentum,
same-calendar, weekday, reversal, weekend-gap, and commodity-RSI systems. The
fixed physical-season map, thirteen exact month endpoints, cumulative return
sign, agreement-only entry, and monthly lifecycle are jointly load-bearing.

## Allocation And Commit Chain

- Source packet and durable G0 decision: `59ba725fc`.
- Canonical card and EA-ID allocation: `08786a159`.
- Magic slot and regenerated 15,506-row resolver: `e3606ce53`.
- Compiled binary and initial setfile pump commit: `39aca2d69`.
- EA source, SPEC, card copies, final fixed-risk setfile, and Q01 state:
  `f40c837a3`.

The registry rows are `20231,wti-seas-mom12` and `XTIUSD.DWX`, slot 0,
magic `202310000`.

## Q01 Evidence

- Card extraction schema lint: PASS; no missing sections or prohibited
  library hits.
- G0 card lint: PASS; all required metadata and four module sections present.
- Seven-section SPEC validator: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_202746/QM5_20231_wti-seas-mom12.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260805_202746/summary.csv`.
- Strict V5 build check: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260805_202958.json`.
- EX5 size: 372,578 bytes.

Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Source packet | `B7FEC1411DA9BF46F079F4A16187BE83D66D4EB17E35D5C77B77015E52FFA60E` |
| G0 decision | `84C6AE43C08298B9ABE00F22E63E4C3FA0B92B28F976E08309D12B0C78872674` |
| Canonical/approved/build card | `66E0B37933F5AA9639D28AF7594BEACF222FA12BEF3BE4A93A4B3B10791A8616` |
| MQ5 | `87695AF82918777D54E972AC1A86B1FBF6B9825B9F6D403A158D1ACB9BFE25CD` |
| EX5 | `5079AAECFBD9B52C2FB869A289D96321CE99981AFBF461CE06E09AEBEAA0DA93` |
| SPEC | `EB7D67C37C15D96A1BA56EFA2D80507906247E7BBD7100D0AE203AA3AD5040A1` |
| Backtest set | `6D688FFE25A8C26E07CBF9C1DDC8B52F4A9F9F516994C82F133AEE11E2A78EC9` |

## Q02 Enqueue And CPU-Ceiling Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20231 --symbols XTIUSD.DWX --max-part2-per-run 0

It selected one `never_tested` priority item and no stranded/recovery item.
The queue had 1,529 pending rows against its separate 7,000-row ceiling.

Before apply, a read-only process scan anchored exactly to
`D:\QM\mt5\T1..T10\terminal64.exe` and excluding `T_Live` found six active
factory terminals: T2, T3, T4, T5, T7, and T9. The binding backtest CPU
ceiling is seven, so the mission permitted one paced queue mutation. The exact
apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20231 --symbols XTIUSD.DWX --max-part2-per-run 0

It inserted exactly one priority Q02 item. The post-enqueue scan at
`2026-08-05T20:33:18.4375210Z` still found the same six factory terminals.
`T_Live` was observed only to confirm its explicit exclusion; it was not
accessed or altered.

## Safety Boundary

- No manual backtest, dispatch tick, terminal reservation, or tester launch
  was run.
- No live, demo, or shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- No terminal was started, stopped, reserved, reaped, or altered.
- The portfolio gate and T_Live manifest were not touched.
- Existing unrelated working-tree changes were preserved and excluded from
  every task commit.
