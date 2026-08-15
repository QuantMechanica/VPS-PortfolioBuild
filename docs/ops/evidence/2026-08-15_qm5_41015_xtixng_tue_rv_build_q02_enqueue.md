# QM5_41015 XTI/XNG Tuesday Relative Value — Build And Q02 Enqueue Evidence

Date: 2026-08-15

Branch: `agents/board-advisor`

## Outcome

One new low-frequency cross-energy sleeve was researched, approved, allocated,
built, validated, committed, and enqueued once for Q02:

- EA: `QM5_41015_xtixng-tue-rv`
- Strategy ID: `MEEK-HOELSCHER-XTIXNG-TUE-2026_S01`
- logical symbol: `QM5_41015_XTI_XNG_TUE_RV_D1`
- host / slot 0: `XTIUSD.DWX`, D1, SELL, magic `410150000`
- companion / slot 1: `XNGUSD.DWX`, D1, BUY, magic `410150001`
- cadence: at most one genuine-Tuesday package per broker week
- normal exit: both legs at broker Tuesday hour 21
- Q01: `PASS`
- Q02: `ENQUEUED; pending`

This is an approximately equal-dollar-notional relative-value package, not a
claim of beta neutrality, profitability, or realized portfolio decorrelation.
Only later governed portfolio analysis can establish the latter.

## Source And Translation Boundary

The governed source packet is
`strategy-seeds/sources/MEEK-HOELSCHER-XTIXNG-TUE-2026/source.md`. It binds
the translation to the complete-read packet for Meek and Hoelscher (2023),
"Day-of-the-week effect: Petroleum and petroleum products," *Cogent Economics
& Finance* 11(1), article 2213876, DOI
`10.1080/23322039.2023.2213876`.

WTI Table 2 reports Tuesday coefficients of `+0.000238`, `-0.000348`,
`-0.000285`, `-0.000086`, and `+0.000001`. Natural-gas Table 6 reports
`+0.001295`, `+0.001857`, `+0.001695`, `+0.001508`, and `+0.001620`.
Across the four asymmetric-variance specifications, the untested
natural-gas-minus-WTI differential is `0.002205`, `0.001980`, `0.001594`,
and `0.001619`, approximately 16-22 basis points.

The paper does not test this pair, equal-notional sizing, joint fixed risk,
Darwinex CFDs, transaction costs, legging, covariance, or the QM portfolio.
The source's close-to-close futures return label is translated to a
first-Tuesday-tick entry and Tuesday 21:00 close, so Q02 is falsification, not
confirmation.

The OWNER mission was durably recorded before card extraction in
`decisions/2026-08-15_xtixng_tuesday_relative_value_source_approval.md`.
The bounded G0 decision is
`decisions/2026-08-15_xtixng_tuesday_relative_value_g0.md`.

## Non-Duplicate Evidence

The canonical pre-card checker scanned 4,502 registry rows and 598 root cards
and returned no exact hit. Manual review separated the two fuzzy matches:

- `QM5_41014_xtixng-thu-rv` is the opposite-direction Thursday package;
- `xtixng-ecm-rv` is a rolling 252-D1 OLS error-correction residual.

The nearest carriers were also separated: `QM5_20016` is a Monday package,
`QM5_12610` is outright WTI Tuesday exposure, and `QM5_12818` is outright
XNG Tuesday exposure. None has this Tuesday source differential, joint risk
budget, equal-notional invariant, or atomic two-leg lifecycle.

Verdict:
`CLEAN_TUESDAY_XTI_XNG_SOURCE_DIFFERENTIAL_AFTER_MANUAL_REVIEW`.

## Locked Build

The EA implements exactly one synchronized package:

1. On the first executable tick within five minutes of a genuine broker
   Tuesday D1 boundary, require the completed XTI predecessor to map to Monday
   and current XTI/XNG D1 bars to be synchronized.
2. Consume and persist the Monday-anchored weekly attempt before fallible
   history, spread, news, sizing, or order gates.
3. Open SELL XTI slot 0 first, then BUY XNG slot 1.
4. Split one package-level `RISK_FIXED=1000` budget across frozen
   `3.5 * ATR(20,D1)` hard stops and require rounded absolute USD notionals
   within 15%.
5. Roll back the first leg if the second fails; flatten orphaned, duplicated,
   same-sided, wrong-symbol, wrong-magic, missing-stop, or materially
   imbalanced packages.
6. Flatten normally at Tuesday hour 21, with first-non-Tuesday and
   three-calendar-day stale repair paths.

There is exactly one setfile, for the logical basket on D1 in `backtest`
environment. It locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No ML, trained output, banned signal indicator,
external runtime feed, grid, martingale, scale-in, or pyramid is present.

## Q01 Validation

- strict compile: `PASS`, 0 errors, 0 warnings;
- compile log:
  `C:/QM/repo/framework/build/compile/20260815_193539/QM5_41015_xtixng-tue-rv.compile.log`;
- strict build check: `PASS`, no failures or warnings;
- build report:
  `D:/QM/reports/framework/21/build_check_20260815_193539.json`;
- targeted build guardrails: `PASS`, two files checked, zero findings;
- Strategy Card schema lint: `PASS` for canonical, approved, and build copies;
- SPEC validation: `PASS`;
- deterministic reference suite: eight tests, all `PASS`;
- P1 artifact validation: `PASS` at
  `D:/QM/reports/pipeline/QM5_41015/P1/P1_QM5_41015_result.json`;
- EX5 size: 382,394 bytes.

The repository-wide legacy dedup audit emitted its pre-existing EA-ID
formatting backlog. No global cleanup was attempted. The targeted dedup
checker, prerequisite guard, strict resolver generation, build guardrails,
strict compile, and P1 validation accepted the new 41015 artifacts.

## Commit Chain Before Enqueue Seal

| Commit | Purpose |
|---|---|
| `a2bb28671` | record source approval and governed translation packet |
| `a3ea1fb0f` | approve G0 card and deterministically allocate EA 41015 |
| `8dce0cefd` | register two basket magics, resolver, SPEC, and manifest |
| `b8fd9e585` | implement, compile, test, and seal the Q01 build |

## Artifact SHA-256 Values At Enqueue

| Artifact | SHA-256 |
|---|---|
| Source packet | `ABACA178E46C5C9633765975ABA1FD6D5D8718538A8CD8B708CCB5DD5630C8BC` |
| Source approval | `8BEF99730D54EBD6706DCBF872F9A0C0ACDC22CF504380AAD3455577CFD38EDF` |
| G0 decision | `1B81870756EA2EB80493F9A9BD97852E47FDBA594E7554CEB8B507507D98113F` |
| Canonical / approved / build card | `87E06A364BFDC567534BB0E91E8AE3F89A72A26A4A786595E6CCA4D5AA1FA17F` |
| MQ5 | `603A12C5FDFF5C99488BF18653D48A09427DC23C731915071C79C50D5A5DD03D` |
| EX5 | `C114B4142BF3F8BEC39D9389F960AD52D7CBAEC8DD61CA27F4A320B5E6082AF8` |
| SPEC | `FDC6A96213609B3DCD4A68255CFE88D0E9F09D1E9FDAD63FFC80166DADAC92DB` |
| Basket manifest | `3E36E8E7CCEA5801020C2224DF532594B5AAD5AC205555C2AC69B2AEF2A1F6AF` |
| Reference suite | `72BCE0D0B5C89DD6DD16A431D17CEB0FA67ECA2789793C71F5ED9E160532B44D` |
| Backtest set | `2F884C681E15453D589238F3DD9C6D194D01508A5D2F2DB7E903F838F6C830A5` |
| Generated magic resolver | `29ECC26D54767E2F40F0A67ACD8601BF29AF0832E060F85C58884FF621AE5CAD` |

## Q02 Capacity And Enqueue Evidence

The exact target-only no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41015 --symbols QM5_41015_XTI_XNG_TUE_RV_D1 --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero scoped skips,
zero stranded retries, zero deferred promotions, and one priority-track item.

A read-only process sample at `2026-08-15T19:38:23.3648676Z` found exactly
two governed terminal executables, T3 and T4. The binding ceiling is seven
factory terminals. The immediately pre-apply sample at
`2026-08-15T19:39:12.4565932Z` again found T3 and T4, so the CPU ceiling was
not binding. The exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41015 --symbols QM5_41015_XTI_XNG_TUE_RV_D1 --max-part2-per-run 0

It inserted exactly one never-tested priority-track item, with no retry,
deferred promotion, or skip. Direct read-only database verification returned:

| Field | Value |
|---|---|
| Work item | `58861191-13d9-4170-aa93-82de7aba2b9d` |
| Phase / kind | `Q02` / `backtest` |
| Logical symbol | `QM5_41015_XTI_XNG_TUE_RV_D1` |
| Host / timeframe | `XTIUSD.DWX` / D1 |
| Status at verification | `pending` |
| Attempt count | `0` |
| Claimed by | none |
| Created UTC | `2026-08-15T19:39:12+00:00` |
| Priority track | `true` |
| Date range | `2018.01.02` through `2024.12.31` |

The post-enqueue target count was exactly one and total pending depth was
1,016 against the helper's 7,000-row ceiling. A post-enqueue process sample
still found only two governed terminals. `FACTORY_OFF.flag` was absent.
The helper's shared sweep evidence path is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`; because it is
shared and mutable, this note relies on the scoped command receipts and the
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
