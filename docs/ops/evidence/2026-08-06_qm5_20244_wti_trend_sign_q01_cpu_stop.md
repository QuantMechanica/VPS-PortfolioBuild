# QM5_20244 WTI Trend / Return-Sign Concordance Q01 And CPU Stop

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 not enqueued because the binding backtest CPU ceiling
was reached.

## Outcome

`QM5_20244_wti-trend-sign` is a new low-frequency direct-WTI candidate on
`XTIUSD.DWX` D1. At each broker-month transition it reconstructs thirteen
consecutive completed month-end closes, calculates the cumulative twelve-month
log-return direction, and counts the non-negative signs of the same twelve
monthly log returns. It opens one monthly package only when the cumulative
direction agrees with the published return-sign state (`P >= 0.40` long,
otherwise short). Disagreement and exact-zero cumulative return remain flat.

One package uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5 * ATR(20,D1)` hard stop, no target,
monthly renewal, and a forty-day stale guard. There is no parameter sweep,
banned signal indicator, trained state, external feed, grid, martingale,
scale-in, live configuration, or portfolio-gate change.

Q01 passed with zero compile errors or warnings and zero build-check failures
or warnings. The immediate path-anchored capacity sample found seven running
factory terminals against the binding ceiling of seven. Per the mission stop
rule and the established below-seven enqueue boundary, no Q02 dry-run,
apply-mode enqueue, dispatch, or tester run was performed after that sample.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/MOP-PAPAILIAS-WTI-TRENDSIGN-2026/source.md`.

- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, supply the cumulative
  twelve-month own-return direction and monthly cadence.
- Papailias, Liu, and Thomakos (2021), *Journal of Banking & Finance* 124,
  106063, DOI `10.1016/j.jbankfin.2021.106063`, supply the twelve binary
  completed-month signs and fixed 0.40 direction threshold.

Both peer-reviewed sources explicitly include WTI futures. Neither tests this
agreement filter, a Darwinex continuous CFD, fixed cash risk, the ATR stop,
costs, financing, or portfolio decorrelation. The adverse WTI drawdown evidence
in Papailias et al. remains a kill risk rather than being hidden.

The deterministic pre-allocation checker scanned 4,301 EA-registry rows and
418 canonical cards and returned `CLEAN`, with no exact or fuzzy match. Manual
review separated the common-window cumulative/sign concordance from pure WTI
TSMOM, `QM5_13150_wti-signmom`, `QM5_20056_wti-dual-mom`,
`QM5_20222_wti-seas-sign`, `QM5_20239_wti-pulltrend`, and the incumbent
`QM5_12567_cum-rsi2-commodity` XNG oscillator pullback.

## Allocation And Commits

- EA ID and slug: `20244,wti-trend-sign`.
- Strategy ID: `MOP-PAPAILIAS-WTI-TRENDSIGN-2026_S01`.
- Slot 0: `XTIUSD.DWX`, magic `202440000`.
- Source packet, cards, and G0 authorization: `744ccf4c8`.
- Atomic directory, registry, magic, and resolver allocation: `71dd5ec14`.
- EA source, EX5, SPEC, colocated card, fixed-risk setfile, and Q01 status:
  `7397b0f5d`.

## Q01 Evidence

- Canonical and approved card schema lint: PASS; no missing sections or ML
  hits.
- Build authorization guard: PASS for numeric EA ID 20244, registry row,
  magic row, and allocated directory.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_082948/QM5_20244_wti-trend-sign.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_082948/summary.csv`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260806_083052.json`.
- V5 build guardrails: PASS, zero findings.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Seven-section SPEC validation: PASS.
- Canonical set header build hash:
  `66bf76a61a52c8cf1882d166d2110e970e323e2f6b7e783e0e286fb33ec0f248`.
- EX5 size: 372,122 bytes.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final build:

| Artifact | SHA-256 |
|---|---|
| Source packet | `746D49541C4884CBA313DFA44C287F50E4B83DD08833238C566AD405ADE9AAB8` |
| MQ5 | `8E2C80D73391A3971ED796A8DE974DE940D09E7C2ADC4033E97B8394E372389D` |
| EX5 | `90BBEC2FEE576C23127C90271D8F9C36791D280654B8F8F0873D4DF763666A06` |
| SPEC | `BD71B51D8B02339B037E683A3AE6E67D88023688E8C5E965F1DB846B74B2099E` |
| Backtest set | `3335042BA1379E662169A2B3A80DFB2A210059096A4400B240E0BEA99F3C52A7` |

## Q02 Capacity Stop

The path-anchored process sample at `2026-08-06T08:33:19.8554263Z` found
seven exact factory terminals:

| terminal | PID |
|---|---:|
| T1 | 15320 |
| T2 | 15364 |
| T4 | 5436 |
| T5 | 14784 |
| T6 | 16668 |
| T7 | 10300 |
| T8 | 12372 |

Only executable paths matching `D:/QM/mt5/T1..T10/terminal64.exe` were counted.
`T_Live`, FTMO, and all other namespaces were excluded. The sample is 7/7 and
binding; Q02 remains `NOT_ENQUEUED_CPU_CEILING`.

The next paced operator may take a fresh immediate capacity sample and, only
when the exact count is below seven, run the targeted dry-run/apply pair:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20244 --symbols XTIUSD.DWX --max-part2-per-run 0
    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20244 --symbols XTIUSD.DWX --max-part2-per-run 0

This is a ready-but-capacity-blocked handoff, not a Q02 screening verdict.

## Safety Boundary

- No Q02 enqueue attempt, manual backtest, dispatch tick, or downstream phase
  was run after the ceiling observation.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
