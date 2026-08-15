# QM5_41014 XTI/XNG Thursday Relative Value — Build And Q02 Enqueue Evidence

Date: 2026-08-15

Branch: `agents/board-advisor`

## Outcome

One new low-frequency cross-energy sleeve was researched, approved, allocated,
built, validated, committed, and enqueued once for Q02:

- EA: `QM5_41014_xtixng-thu-rv`
- Strategy ID: `MEEK-HOELSCHER-XTIXNG-THU-2026_S01`
- logical symbol: `QM5_41014_XTI_XNG_THU_RV_D1`
- host / slot 0: `XTIUSD.DWX`, D1, BUY, magic `410140000`
- companion / slot 1: `XNGUSD.DWX`, D1, SELL, magic `410140001`
- cadence: at most one genuine-Thursday package per broker week
- exit: both legs at broker Thursday hour 21
- Q01: `PASS`
- Q02: `ENQUEUED; pending`

This is an approximately equal-dollar-notional relative-value package, not a
claim of beta neutrality, profitability, or realized portfolio decorrelation.
Q09 alone can establish the latter.

## Source And Translation Boundary

The governed source packet is
`strategy-seeds/sources/MEEK-HOELSCHER-XTIXNG-THU-2026/source.md`. It binds the
translation to the complete-read packet for Meek and Hoelscher (2023),
"Day-of-the-week effect: Petroleum and petroleum products," *Cogent Economics
& Finance* 11(1), article 2213876, DOI
`10.1080/23322039.2023.2213876`.

Across the paper's four asymmetric-variance specifications, WTI Table 2 gives
Thursday coefficients of `-0.000189`, `-0.000155`, `-0.000010`, and
`+0.000270`. Natural-gas Table 6 gives `-0.001339`, `-0.001333`, `-0.001432`,
and `-0.001323`, each marked significant at the source's 10% or 5% levels.
Their untested raw WTI-minus-natural-gas differential is approximately
11.5-15.9 basis points.

The paper does not test this pair, equal-notional sizing, joint fixed risk,
Darwinex CFDs, transaction costs, legging, covariance, or the QM portfolio.
The source's close-to-close futures return label is translated to a first-
Thursday-tick entry and Thursday 21:00 close, so Q02 is explicitly
falsification rather than confirmation.

The OWNER mission was durably recorded before card extraction in
`decisions/2026-08-15_xtixng_thursday_relative_value_source_approval.md`.
The bounded G0 decision is
`decisions/2026-08-15_xtixng_thursday_relative_value_g0.md`.

## Non-Duplicate Evidence

The canonical pre-card checker scanned 4,501 registry rows and 597 root cards
and returned no exact hit. Its only fuzzy result was `xtixng-ecm-rv`, whose
mechanic is a 252-D1 OLS error-correction residual rather than a weekday
coefficient package.

Manual review separated the nearest carriers:

- `QM5_20110`: Friday long-XTI/short-XNG, based on the separate Friday source
  coefficients and clock;
- `QM5_20016`: Monday short-XTI/long-XNG, with the opposite directions;
- `QM5_12819`: outright XNG Thursday fade, without an XTI hedge, joint budget,
  equal-notional invariant, or atomic package repair;
- existing price-state XTI/XNG baskets: state/residual rules rather than a
  genuine-Thursday source differential; and
- `QM5_12567`: cumulative-RSI logic, which this build does not use.

Verdict:
`CLEAN_THURSDAY_XTI_XNG_SOURCE_DIFFERENTIAL_AFTER_MANUAL_REVIEW`.

## Locked Build

The EA implements exactly one synchronized package:

1. Attach only within five minutes of a genuine broker-Thursday D1 boundary
   whose completed XTI predecessor is Wednesday and whose current XTI/XNG D1
   bars are synchronized.
2. Consume and persist the Monday-anchored weekly attempt before fallible
   gates; never retry that week.
3. Open BUY XTI slot 0 and SELL XNG slot 1.
4. Split one package-level fixed-dollar risk budget across frozen
   `3.5 * ATR(20,D1)` hard stops and require rounded absolute USD notionals to
   be within 15%.
5. Roll back the first leg if the second fails, and flatten malformed,
   orphaned, duplicated, same-sided, wrong-symbol, wrong-magic, or materially
   imbalanced packages.
6. Flatten normally at Thursday hour 21, with first-non-Thursday and
   three-calendar-day stale repair paths.

There is exactly one setfile, for the logical basket on D1 in `backtest`
environment. It locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No ML, trained output, banned signal indicator, external
runtime feed, grid, martingale, scale-in, or pyramid is present.

## Q01 Validation

- strict compile: `PASS`, 0 errors, 0 warnings;
- compile log:
  `C:/QM/repo/framework/build/compile/20260815_182700/QM5_41014_xtixng-thu-rv.compile.log`;
- strict build check: `PASS`, no failures or warnings;
- build report:
  `D:/QM/reports/framework/21/build_check_20260815_182700.json`;
- targeted build guardrails: `PASS`, two files checked, zero findings;
- Strategy Card schema lint: `PASS` for canonical, approved, and build copies;
- SPEC validation: `PASS`;
- deterministic reference suite: seven tests, all `PASS`;
- P1 artifact validation: `PASS` at
  `D:/QM/reports/pipeline/QM5_41014/P1/P1_QM5_41014_result.json`;
- EX5 size: 382,612 bytes.

The repository-wide legacy registry validator was also sampled read-only and
reported its pre-existing global legacy-ID/slug backlog. No global cleanup was
attempted. Targeted build checks, the build guard, strict resolver generation,
strict compile, and P1 validation accepted the new `41014` rows and artifacts.

## Commit Chain Before Enqueue Seal

| Commit | Purpose |
|---|---|
| `0e47c6be8` | record source approval and governed translation packet |
| `0f7f48405` | approve G0 card and deterministically allocate EA 41014 |
| `1cd8a2f80` | register two basket magics, resolver, SPEC, and manifest |
| `5eb229926` | implement, compile, test, and seal the Q01 build |

## Artifact SHA-256 Values At Enqueue

| Artifact | SHA-256 |
|---|---|
| Source packet | `9AEA944918EDBE48CE226BCFD6F31926EE60914506A8DC0A0FA6C991EB9DF1B0` |
| Source approval | `F3FB5BBB489D0D14625EE9AFA108CCF5E28FC1DE78DFDF503C441F134AAED7FE` |
| G0 decision | `3BF4F90333B7DCCAD424BAB1A1CD875A5BC489B4023B1ACFAFF9C5D602A4271A` |
| Canonical / approved / build card | `DD0D3F850DF20864697500509C67D60E21AA4439BA3B278612D51E3361450600` |
| MQ5 | `FAF23D355994CB0875CF00EC7384AF8A0ACB97F132CE46E6F5E6E7BCB1CF4FCA` |
| EX5 | `CD4D40F1532B34734E953B6595143A7CC95A6BADB540FB1715B1D1E1E4C80C89` |
| SPEC | `BF75798AF65DD3C415E76392FDACA11D85360B8F9A6233D2620FE38F5FEEF221` |
| Basket manifest | `B1B85B143AA68C4AAE961D627E00FB1CF4923A0D2ABB54146109FB6FF1B99D8B` |
| Reference suite | `D44F2AA1E79C3C49950730FE55970E4FE4B48CEC547AD2B142D92194111D80A8` |
| Backtest set | `E6239A65F9210F00900C22DE610610F7711F3070EE90C46B4CC8D494E65C304E` |
| Generated magic resolver | `5643B4A18621BDF963C87E3365F6B967824BDE97A206547506FAD203D875E51C` |

## Q02 Capacity And Enqueue Evidence

The exact target-only no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41014 --symbols QM5_41014_XTI_XNG_THU_RV_D1 --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero scoped skips,
zero stranded retries, zero deferred promotions, and one priority-track item.
The target had zero pre-existing work items.

A read-only process sample at `2026-08-15T18:32:19.5996943Z` found exactly two
executables rooted under governed `D:/QM/mt5/T1..T10/terminal64.exe` paths:
T3 and T7. The binding ceiling is seven factory terminals.

The immediately pre-apply sample at `2026-08-15T18:32:39.1801630Z` again
found T3 and T7, so the ceiling was not binding. The exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41014 --symbols QM5_41014_XTI_XNG_THU_RV_D1 --max-part2-per-run 0

It inserted exactly one never-tested priority-track item, with no retry,
deferred promotion, or skip. Direct read-only database verification returned:

| Field | Value |
|---|---|
| Work item | `60cde14d-6d7a-4024-990b-79a582c4b373` |
| Phase / kind | `Q02` / `backtest` |
| Logical symbol | `QM5_41014_XTI_XNG_THU_RV_D1` |
| Host / timeframe | `XTIUSD.DWX` / D1 |
| Status at verification | `pending` |
| Attempt count | `0` |
| Claimed by | none |
| Created UTC | `2026-08-15T18:32:39+00:00` |
| Priority track | `true` |

The read-only post-enqueue count was 1,016 pending items against the helper's
7,000-row queue ceiling. `FACTORY_OFF.flag` was absent. The helper's shared
sweep evidence path is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`; because that file
is shared and mutable, this note relies on the scoped command receipts and
unique database row.

## Safety Boundary

- No manual backtest, smoke run, phase runner, dispatch tick, terminal
  reservation, tester launch, process mutation, or factory-lock bypass was
  performed.
- No live, demo, shadow, stress, or optimization setfile was created.
- No terminal was started, stopped, reserved, reaped, or altered.
- AutoTrading was not toggled.
- Neither the portfolio gate nor the T_Live manifest was touched.
- Q02 enqueue is not a Q02 verdict, certification, profitability evidence,
  realized decorrelation evidence, portfolio admission, or live-use
  authorization.
