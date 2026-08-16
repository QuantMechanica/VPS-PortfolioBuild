# QM5_41021 WTI Dual-Horizon Momentum - Build And Q02 Enqueue Evidence

Date: 2026-08-16 (Europe/Berlin; queue timestamps below are UTC)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency energy sleeve was researched, approved,
allocated, built, validated, committed, and enqueued once for Q02:

- EA: `QM5_41021_wti-mdual-mom`
- strategy ID: `MOP-WTI-MDUAL-MOM-2026_S01`
- symbol / timeframe: `XTIUSD.DWX` / D1
- magic slot / magic: `0` / `410210000`
- cadence: at most one consumed attempt per broker month
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Q01: `PASS`
- Q02: `ENQUEUED; pending` at verification

This is a new outright WTI carrier outside the certified XAU, SP500, NDX,
and XNG book. Its underlying and lifecycle are structurally different, but
neither this build nor enqueue proves realized decorrelation. That remains a
downstream portfolio-correlation question.

## Locked Edge

The EA mechanizes one broker-month transition:

1. On the first executable D1 tick of a new broker month, reconstruct the
   immediately completed month's log return.
2. Independently reconstruct that same month's final five completed
   close-to-close intervals.
3. BUY only when both signs are positive and SELL only when both are
   negative. Disagreement, exact zero, or invalid endpoints consumes the
   month flat.
4. Normalize only the governed 24-48-hour prior-date energy label by one
   uniform calendar day and never enter outside the five-minute opening
   grace.
5. Persist the `yyyymm` attempt before history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry a consumed month.
6. Attach one frozen `3.5 * ATR(20,D1)` hard stop, no target, and close on the
   first tick of the sixth entry-month D1 bar.

There is exactly one setfile and its environment is `backtest`. Both news
axes and Friday close are OFF. No optimizer surface, ML, banned signal
indicator, external runtime feed, pending order, grid, martingale, pyramid,
scale-in, or partial exit was added.

## Source And Claim Boundary

The bounded packet is
`strategy-seeds/sources/MOP-WTI-MDUAL-MOM-2026/source.md`, approved before
card extraction in
`decisions/2026-08-16_wti_month_dual_momentum_source_approval.md`.

It traces to Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum,"
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete governed paper review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; its reviewed PDF SHA-256 is
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The paper supports only the own-return-sign continuation family and explicit
WTI membership in its commodity-futures universe. It does not test the
WTI-only nested one-month/final-five agreement state, exact CFD boundary,
five-session hold, hard stop, costs, or the QM portfolio. Those are disclosed
QM translations to be falsified downstream.

## Non-Duplicate Evidence

The canonical pre-allocation checker scanned 4,508 EA-registry rows and 604
root cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separated the material neighbors:

- `QM5_41016_wti-mclose-mom` follows the final-five sign alone.
- `QM5_20187_wti-tsmom1m` follows the completed-month sign alone and owns the
  full next month.
- `QM5_20056_wti-dual-mom` and `QM5_12711` compare medium/long monthly
  horizons, not a nested one-month/five-session state.
- `QM5_20244_wti-trend-sign` uses twelve-month return/sign breadth.
- `QM5_13049_xti-1w-mom-vol` is a rolling five-D1 magnitude/volatility rule.
- `QM5_41013_wti-mopen-mom` forms inside the new month and enters only when
  this candidate is due to flatten.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback.

Verdict:
`CLEAN_WTI_MONTH_AND_CLOSING_SEGMENT_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Q01 Validation

- build prerequisite guard: `PASS`;
- strict compile: `PASS`, 0 errors, 0 warnings;
- final compile log:
  `C:/QM/repo/framework/build/compile/20260816_093059/QM5_41021_wti-mdual-mom.compile.log`;
- strict targeted build check: `PASS`, 0 failures, 0 warnings;
- build report:
  `D:/QM/reports/framework/21/build_check_20260816_093059.json`;
- Strategy Card schema/ML lint: `PASS` for canonical, approved, and build
  copies; all three copies are byte-identical;
- G0 card lint and SPEC validation: `PASS`;
- deterministic mechanic reference suite: eight tests, all `PASS`;
- static P1 artifact validation: `PASS` at
  `D:/QM/reports/pipeline/QM5_41021/P1/P1_QM5_41021_result.json`;
- EX5 size: 384,004 bytes.

The repository-wide registry validator emitted its pre-existing legacy
backlog. No unrelated registry cleanup was attempted. The target build guard,
magic row, regenerated resolver, strict compile, and strict build check all
accepted EA 41021. The resolver contains 15,979 active rows and magic
`410210000`.

## Commit Chain Before Enqueue Seal

| Commit | Purpose |
|---|---|
| `c147775f2` | record source approval before extraction |
| `52065efc2` | persist deterministic EA-registry allocation for 41021 |
| `decf2674a` | approve the governed source packet, card, and G0 decision |
| `95f0cedf6` | register magic, build, compile, test, and seal Q01 |

## Artifact SHA-256 Values At Enqueue

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `3856D9680C207E3306416156C6C96673654C773BDB0BA41CAA1A64717244A469` |
| Complete parent source review | `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042` |
| Source approval | `2EB5FE6918FA226A2344942663C98ECC5062021B535B48FA2F3CC6DE4D26264B` |
| G0 decision | `5D702C2B3812941FD2BC8E5062580119845A9C4FBC0BC68369AF2E9921CD2E16` |
| Canonical / approved / build card | `320826E5CCB71F2594275FD101697ABDC5E410B1AFA80BB197CB5919E05D3751` |
| MQ5 | `BE87538C04026EE20098A0F84E09B2851A6161FCD3F796B3D7BE536130785024` |
| EX5 | `57DB97F8580CC69E44407E204178D18D42CF54FFF62AA4D3AEB5218943AE3A17` |
| SPEC | `A6C585B222E00C68D2FDA5BEE1EEBD26F01CE2E57149215738E1DDC481F4BEBD` |
| Reference suite | `678F92EC8B23879D218AC33313142BC6519647BBAC3F0E336BA7076B86874FD6` |
| Backtest set | `FA91B0500B1E2DD4DD2394414ADF8D2BD17CFE261E33E87A6BE5659642A1B9FD` |
| Generated magic resolver | `77FB8636694307F0AFF9239C66AE2EFBB2ADB53B8BC8C7B2AC4B4F4468EF1A8A` |

The machine-readable receipt is
`artifacts/qm5_41021_wti_mdual_mom_q02_enqueue_20260816T093701Z.json`.

## Q02 Capacity And Enqueue Evidence

The target-only no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41021 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero skips, zero
stranded retries, zero deferred promotions, and one priority-track item.

Immediately before apply, the exact factory-terminal sample at
`2026-08-16T09:37:01.7523650Z` found T5, T7, and T8: 3 of the governed
ceiling of 7. The CPU ceiling was therefore not binding. `T_Live` and an
unrelated FTMO terminal were visible to diagnostics but were not factory
slots and were not touched.

The exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41021 --symbols XTIUSD.DWX --max-part2-per-run 0

It inserted exactly one never-tested priority-track item, with no retry,
deferred promotion, or skip. Read-only database verification returned:

| Field | Value |
|---|---|
| Work item | `d23c5d11-4bd5-409f-9927-ab9683dbee15` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Status at verification | `pending` |
| Attempt count | `0` |
| Claimed by | none |
| Created UTC | `2026-08-16T09:37:01+00:00` |
| Priority track | `true` |

The helper reported 965 pending rows before insertion against its 7,000-row
ceiling. A post-enqueue sample at `2026-08-16T09:37:51.2592743Z` found T5,
T7, T8, and T9, still below the 7-terminal ceiling. The helper's shared
receipt is `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`; because
that file is shared and mutable, the scoped receipt and unique queue row are
the durable evidence here.

## Safety Boundary

- No manual backtest, pipeline phase runner, dispatch tick, terminal
  reservation, tester launch, process mutation, or factory-lock bypass was
  performed.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, stress, or optimization setfile was created.
- AutoTrading was not toggled.
- Neither the portfolio gate nor the `T_Live` manifest was touched.
- Q02 enqueue is not a Q02 verdict, certification, profitability result,
  realized-decorrelation result, portfolio admission, or live authorization.
