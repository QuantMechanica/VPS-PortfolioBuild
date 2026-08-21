# QM5_41083 Q01 PASS and Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41083_xauxag-wlegdiv-rv`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New structural commodity sleeve

`QM5_41083` is a low-frequency market-neutral-design XAU/XAG relative-value
basket. On the first tradable D1 bar of a new Monday-anchored broker week, it
selects synchronized week-end close pairs from the two immediately preceding
consecutive broker weeks and computes the individual gold and silver log
returns over that same completed interval. It trades only when those returns
have strictly opposite nonzero signs, selling the weekly winner and buying the
weekly loser for one broker week.

The package targets equal absolute notional, shares one aggregate fixed-risk
budget, and carries one frozen ATR hard stop per leg. It is mechanically
different from the certified single-symbol XNG cumulative-RSI2 pullback and
from existing XAU/XAG rolling-ratio, residual, daily lead-lag, flow, relative-
return sequence, and within-week ratio-rank families. That structural
difference is a diversification hypothesis, not proof of low realized
correlation; Q09 alone owns the portfolio-correlation decision.

## Reputable-source and governance trail

The source basis is the peer-reviewed Schweikert (2018) gold/silver
cointegration study in the *Journal of Banking & Finance*, DOI
`10.1016/j.jbankfin.2017.11.010`, with CME Group's official Gold & Silver Ratio
Spread definition as the carrier reference. The completed-week individual-
leg sign state and one-week fade are explicitly disclosed as QM translations,
not source claims.

| Artifact | Commit / evidence |
|---|---|
| governed source approval | `55a658719` |
| deterministic EA-ID reservation | `b1c4e3988` |
| G0-approved card | `d5c6a3428` |
| magic allocation and resolver regeneration | `3dc125b72` |
| implementation and Q01 build | `16e4801dc` |
| strict compile summary | `D:/QM/reports/compile/20260821_040436/summary.csv` |
| strict build report | `D:/QM/reports/framework/21/build_check_20260821_040527.json` |
| static P1 report | `D:/QM/reports/pipeline/QM5_41083/P1/P1_QM5_41083_result.json` |

Q01 evidence:

- canonical pre-allocation dedup: CLEAN after repository-wide family review;
- deterministic reference suite: 9 tests passed;
- strategy-card schema and G0 lints: PASS;
- strict MetaEditor compile: 0 errors, 0 warnings;
- targeted build check: PASS, 0 failures, 0 warnings;
- static P1 validation: PASS;
- MQ5 SHA-256: `24E2CE2A20D330653451D146C457B5530C3996F139C52839B309A38B37FA5202`;
- EX5 SHA-256: `2AF6DFF7A31A0A2B6B7C846E73C23263523A7796153144B655FC28C59AB7D2AC`;
- setfile byte SHA-256: `D2207083C81C3A69B2ABA5292D421048039AAF8AE331E56DB84D59377EE285BF`;
- normalized set build hash: `3e3eab75a717a0aceea55564e517101e2ccd7080de24162119fc3dd86a827581`.

The only preset is the logical-basket D1 backtest baseline with aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF,
and Friday close OFF. No live, demo, shadow, stress, or optimization preset was
created.

## Q02 target preflight

The supported farm view had no existing work item:

```text
python -m tools.strategy_farm.farmctl work-items --ea QM5_41083
count=0
```

The non-mutating target-only preview found exactly one fresh baseline row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41083 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
part3 deferred: promoted=0 kept=0
priority_track items: 1
```

The preview carried no `--apply` flag. No farm row or priority was mutated.

## Binding CPU stop

The canonical read-only `farmctl mt5-slots` inventory at
`2026-08-21T04:07:17Z` reported six running and reserved governed research
terminals, below the paced ceiling of seven:

| Terminal | EA | Phase | Symbol / label |
|---|---|---|---|
| T1 | `QM5_12935` | Q07 | `XAUUSD.DWX` |
| T2 | `QM5_10796` | Q07 | `XAUUSD.DWX` |
| T3 | `QM5_10135` | Q08 | `pipeline_run` baseline; no work-item row |
| T4 | `QM5_20234` | Q03 | `QM5_20234_XAU_XAG_RSJ_D1` |
| T6 | `QM5_20176` | Q05 | `USDJPY.DWX` |
| T8 | `QM5_11167` | Q07 | `XAUUSD.DWX` |

The census reported zero duplicate terminal workers and zero orphaned terminal
processes. It observed the separate `T_Live` and FTMO terminals only to
exclude them from the governed research count; neither was accessed or
changed.

Because the terminal count was below its ceiling, five consecutive whole-host
`Win32_Processor` samples were taken across 16 logical processors:

| Sample UTC | Average | Maximum |
|---|---:|---:|
| `2026-08-21T04:07:51.1962796Z` | 100% | 100% |
| `2026-08-21T04:07:55.3118102Z` | 100% | 100% |
| `2026-08-21T04:07:59.3384539Z` | 100% | 100% |
| `2026-08-21T04:08:03.3980827Z` | 100% | 100% |
| `2026-08-21T04:08:07.4886403Z` | 100% | 100% |

Every sample exceeded the governed 97% hard CPU ceiling. The mission's
explicit CPU-stop rule was therefore applied before queue mutation. Q02 was
not enqueued, dispatched, reserved, or run. No terminal was stopped or
controlled, and no manual backtest was launched.

## Safe handoff

After a fresh whole-host CPU sample is below 97%, repeat the exact target
work-item query, target-only preview, and terminal census before using the
target-only `--apply` path for `QM5_41083`. Do not broaden the sweep.

This record does not authorize AutoTrading, `T_Live`, deploy/T_Live manifest
changes, portfolio-gate changes, portfolio admission, a correlation waiver,
or live use. Q02 must retire the identity on zero packages, fewer than five
completed packages per full post-warm-up year, nonpositive governed economics,
or any hard-rule violation.

Machine-readable evidence:
`artifacts/qm5_41083_q02_cpu_ceiling_stop_20260821T040751Z_board_advisor.json`.
