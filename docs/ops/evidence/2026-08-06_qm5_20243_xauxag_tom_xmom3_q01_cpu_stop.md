# QM5_20243 XAU/XAG MOM-TOM Basket Q01 And CPU Stop

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 not enqueued because the binding backtest CPU ceiling
was exceeded.

## Outcome

`QM5_20243_xauxag-tom-xmom3` is a new low-frequency, opposite-direction
precious-metals basket. In the last-two/first-one broker-calendar TOM cycle it
freezes formation before the cycle month, averages exactly three synchronized
completed monthly returns for XAU and XAG, buys the higher-return metal, and
shorts the lower. It is flat outside the TOM window.

One package uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The fixed budget is split equally by independent
`3.5 * ATR(20,D1)` hard-stop risk. There is no target, Friday close, grid,
martingale, scale-in, trained state, external feed, or live configuration.

Q01 passed with zero compile errors or warnings and zero build-check failures
or warnings. The immediate path-anchored capacity sample found nine running
factory terminals against the binding ceiling of seven. Per the mission stop
rule, no Q02 dry-run, apply-mode enqueue, dispatch, or tester run was performed
after that observation.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026/source.md`.

- van Hemert (2014), SSRN 2515900, supplies only the last-two/first-one CTA
  turn-of-month flow hypothesis.
- Fuertes, Miffre, and Rallis (2010), *Journal of Banking & Finance* 34(10),
  2530-2548, DOI `10.1016/j.jbankfin.2010.04.009`, supply the source-declared
  three-month commodity cross-sectional average-return rank.

Neither source tests the intersection, a two-metal CFD cross-section, fixed
cash risk, ATR stops, costs, financing, or portfolio decorrelation. The pair
is opposite in direction and equal in stop-risk allocation; stronger
neutrality claims remain unproven.

The deterministic pre-allocation checker found no exact identity and only
three expected fuzzy XAU/XAG momentum siblings. Manual review separated this
candidate from `QM5_20184_xauxag-xmom3`, which holds the rank for an entire
month. QM5_20243 freezes formation before the TOM cycle, holds only the
source-backed three-date window, and immediately returns flat. Extending the
hold to a month is prohibited because it recreates QM5_20184.

## Allocation And Commit Boundary

- EA ID and slug: `20243,xauxag-tom-xmom3`.
- Strategy ID: `VANHEMERT-FMR-XAUXAG-TOMXMOM3-2026_S01`.
- Slot 0: `XAUUSD.DWX`, magic `202430000`.
- Slot 1: `XAGUSD.DWX`, magic `202430001`.
- Atomic registry, magic, and resolver allocation: artifact-pump commit
  `c6149d4c8`.
- Source, cards, decision, EA, setfile, Q01 evidence, and this CPU stop: the
  scoped branch commit containing this document.

## Q01 Evidence

- Canonical and approved card schema lint: PASS; no missing sections or ML
  hits.
- Canonical G0 card lint: PASS.
- Build authorization guard: PASS for numeric EA ID 20243 and the allocated
  directory.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Targeted compile log:
  `C:/QM/repo/framework/build/compile/20260806_075246/QM5_20243_xauxag-tom-xmom3.compile.log`.
- Targeted compile summary:
  `D:/QM/reports/compile/20260806_075246/summary.csv`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260806_075246.json`.
- V5 build guardrails: PASS, zero findings.
- Basket symbol-scope validation: `BASKET_OK`, zero violations.
- Seven-section SPEC validation: PASS.
- MQ5 SHA-256:
  `18D2A0AD3BBBF38F23B5748211597C35B6A2630BD7147C61B573611575012DA2`.
- Canonical set build hash:
  `DBCC04DCF1CB8BC0E47470D3DCD9DFE7C795BBABD68DB5EC0CB7CAEBC10C3665`.
- EX5 size: 388,178 bytes.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final strict build:

| Artifact | SHA-256 |
|---|---|
| Source packet | `C38AB7CDD1EF0F87DB6D269AED28DC6C423BDF815BADA3E8B525D30B0A247DD2` |
| MQ5 | `18D2A0AD3BBBF38F23B5748211597C35B6A2630BD7147C61B573611575012DA2` |
| EX5 | `ABBF719E3B7BF4AC2AD56745C4D8987E4D7D02A38A9626649B0C25459E830567` |
| SPEC | `ADA473C9390F443E2EA7FF2EBC1608B8DC722E3F6EE179549C63907508C35077` |
| Backtest set | `C2B10A27E696D1D32956918B31B0F80C70EB1AEB51972417DED1B37B61150A3A` |
| Basket manifest | `370115AF17C915F5E08035498D01254B3144C59AE77173731F3244BACFE5DE79` |

## Q02 Capacity Stop

The path-anchored process sample at `2026-08-06T07:49:04.8243545Z` found nine
exact factory terminals:

| terminal | PID |
|---|---:|
| T1 | 14560 |
| T2 | 17092 |
| T3 | 12204 |
| T4 | 16280 |
| T5 | 12232 |
| T6 | 2912 |
| T7 | 1044 |
| T8 | 12400 |
| T10 | 2640 |

Only executable paths matching `D:/QM/mt5/T1..T10/terminal64.exe` were
counted. `T_Live`, the FTMO terminal, and every other namespace were excluded.
The sample is 9/7 and binding; Q02 remains
`NOT_ENQUEUED_CPU_CEILING`.

The next paced operator may take a fresh immediate capacity sample and, only
when the exact count is below seven, run the logical-basket dry-run/apply pair:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20243 --symbols QM5_20243_XAU_XAG_TOM_XMOM3_D1 --max-part2-per-run 0
    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20243 --symbols QM5_20243_XAU_XAG_TOM_XMOM3_D1 --max-part2-per-run 0

This is a ready-but-blocked handoff, not a Q02 screening verdict.

## Safety Boundary

- No Q02 enqueue attempt, manual backtest, dispatch tick, or downstream phase
  was run after the ceiling observation.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
