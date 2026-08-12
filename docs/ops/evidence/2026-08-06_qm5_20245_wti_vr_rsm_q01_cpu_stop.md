# QM5_20245 WTI Variance-Ratio / RSM Q01 And CPU Stop

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 not enqueued because the binding backtest CPU ceiling
was reached.

## Outcome

`QM5_20245_wti-vr-rsm` is a new low-frequency direct-WTI candidate on
`XTIUSD.DWX` D1. At each broker-month transition it reconstructs thirty-three
consecutive completed month-end closes, estimates the published q=2 robust
variance-ratio state over thirty-two monthly returns, and maps the newest
twelve binary monthly signs to the published RSM direction at `P=0.40`.
Significant persistence follows the RSM direction; significant
anti-persistence reverses it; insignificant memory consumes the month flat.

One package uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.0 * ATR(20,D1)` hard stop, no target,
monthly renewal, and a forty-day stale guard. There is no parameter sweep,
banned signal indicator, trained state, external feed, grid, martingale,
scale-in, live configuration, or portfolio-gate change.

Q01 passed with zero compile errors or warnings and zero build-check failures
or warnings. The immediate path-anchored capacity sample found ten running
factory terminals against the binding ceiling of seven. Per the mission stop
rule and established below-seven enqueue boundary, no Q02 dry-run, apply-mode
enqueue, dispatch, or tester run was performed after that sample.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/MEHLITZ-PAPAILIAS-WTI-VRRSM-2026/source.md`.

- Mehlitz and Auer (2024), *The European Journal of Finance* 30(8), 773-802,
  DOI `10.1080/1351847X.2023.2220118`, supply the thirty-two-month q=2 robust
  variance-ratio test, significance boundary, and persistence/anti-persistence
  direction matrix.
- Papailias, Liu, and Thomakos (2021), *Journal of Banking & Finance* 124,
  106063, DOI `10.1016/j.jbankfin.2021.106063`, supply the twelve binary
  completed-month signs and fixed 0.40 direction threshold.

Both peer-reviewed sources explicitly include WTI futures. Neither tests this
replacement of the latest one-month winner/loser state with twelve-month sign
breadth, a Darwinex continuous CFD, fixed cash risk, the ATR stop, costs,
financing, or portfolio decorrelation. The conjunction is a falsifiable QM
hypothesis, not a transferred source result.

The deterministic pre-allocation checker scanned 4,302 EA-registry rows and
419 canonical cards and returned `CLEAN`, with no exact or fuzzy match. Manual
review separated the mechanic from `QM5_13134_energy-vr-mom` (latest one-month
sign), `QM5_13150_wti-signmom` (no memory regime),
`QM5_20244_wti-trend-sign` (cumulative-return agreement),
`QM5_20222_wti-seas-sign` (fixed seasonal agreement),
`QM5_20242_xng-rsm-window` (XNG calendar carrier), and the incumbent
`QM5_12567_cum-rsi2-commodity` XNG oscillator pullback.

## Allocation And Commits

- EA ID and slug: `20245,wti-vr-rsm`.
- Strategy ID: `MEHLITZ-PAPAILIAS-WTI-VRRSM-2026_S01`.
- Slot 0: `XTIUSD.DWX`, magic `202450000`.
- Source packet, cards, and G0 authorization: `a6e348bc3`.
- Atomic directory, registry, magic, and resolver allocation: `883c12b1f`.
- EA source, EX5, SPEC, colocated card, fixed-risk setfile, and Q01 status:
  `bc43f4820`.

## Q01 Evidence

- Canonical, approved, and colocated card schema lint: PASS; no missing
  sections or forbidden-model hits.
- Build authorization preflight: PASS for approved G0 card, exact slug,
  numeric EA ID 20245, active registry row, active magic row, and allocated
  directory.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_093418/QM5_20245_wti-vr-rsm.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_093418/summary.csv`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260806_093417.json`.
- V5 build guardrails: PASS, zero findings.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Seven-section SPEC validation: PASS.
- Canonical set header build hash:
  `82fcfae6961a7cf45f3b1604293131c539d91db1d1df3518648b3ae9cf7805d4`.
- EX5 size: 374,774 bytes.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final build:

| Artifact | SHA-256 |
|---|---|
| Source packet | `0F0639658DA6D07DEF87C5BD032F4B55934E4D5A8C6CD34AE8E57AF194AA449B` |
| MQ5 | `82FCFAE6961A7CF45F3B1604293131C539D91DB1D1DF3518648B3AE9CF7805D4` |
| EX5 | `E8404AF7E0D061C5AE92F5C8FEFF5CA89AB946A19770F7BC687A3336CE245F07` |
| SPEC | `7CB282AE8FBB798E5C278980F74523286BBFE95017CBB35FB793D451703BADF3` |
| Backtest set | `975632D884A63DDF068318A5C758698D08BB39C11972281DF5BE7AA4EF3860C2` |

## Q02 Capacity Stop

The path-anchored process sample at `2026-08-06T09:36:44.8569816Z` found ten
exact factory terminals:

| terminal | PID |
|---|---:|
| T1 | 16216 |
| T2 | 2532 |
| T3 | 7036 |
| T4 | 9416 |
| T5 | 3584 |
| T6 | 16668 |
| T7 | 16456 |
| T8 | 3816 |
| T9 | 6908 |
| T10 | 15996 |

Only executable paths matching `D:/QM/mt5/T1..T10/terminal64.exe` were counted.
`T_Live`, FTMO, and all other namespaces were excluded. The sample is 10/7
and binding. A subsequent read-only query of the canonical farm database
returned zero `Q02`/`P2` rows for `QM5_20245`; Q02 remains
`NOT_ENQUEUED_CPU_CEILING`.

The next paced operator may take a fresh immediate capacity sample and, only
when the exact count is below seven, run the targeted dry-run/apply pair:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20245 --symbols XTIUSD.DWX --max-part2-per-run 0
    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20245 --symbols XTIUSD.DWX --max-part2-per-run 0

This is a ready-but-capacity-blocked handoff, not a Q02 screening verdict.

## Safety Boundary

- No Q02 enqueue attempt, manual backtest, dispatch tick, or downstream phase
  was run after the ceiling observation.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
