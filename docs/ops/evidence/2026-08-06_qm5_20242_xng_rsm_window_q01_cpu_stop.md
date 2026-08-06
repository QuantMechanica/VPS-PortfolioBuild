# QM5_20242 XNG Seasonal RSM Window Q01 And CPU Stop

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 not enqueued because the binding backtest CPU ceiling
was exceeded.

## Outcome

`QM5_20242_xng-rsm-window` is a new structural, low-frequency direct
natural-gas candidate on `XNGUSD.DWX` D1. On the first tradable D1 bar of each
broker month it:

- consumes one persistent attempt and closes the prior monthly package;
- remains flat in February-April and October;
- reconstructs thirteen consecutive completed broker-month closes in
  May-September and November-January;
- counts the twelve non-negative monthly returns, including equality; and
- buys when `positive_count / 12 >= 0.40`, otherwise sells.

Risk is a frozen `3.5 * ATR(20,D1)` hard stop, no target, monthly rollover, a
forty-day stale guard, and exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

Q01 passed with zero compile errors or warnings and zero build-check failures
or warnings. The immediate path-anchored capacity sample found nine running
factory terminals against the binding ceiling of seven. In accordance with
the mission stop rule, no Q02 dry-run, apply-mode enqueue, dispatch, or tester
run was performed after that observation.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/SUENAGA-PAPAILIAS-XNG-SEASRSM-2026/source.md`.

- Suenaga, Smith, and Williams (2008), *Journal of Futures Markets* 28(5),
  438-463, DOI `10.1002/fut.20317`, supply only the May-September and
  November-January natural-gas physical volatility windows.
- Papailias, Liu, and Thomakos (2021), *Journal of Banking & Finance* 124,
  106063, DOI `10.1016/j.jbankfin.2021.106063`, supply the twelve completed
  monthly binary signs, fixed `q=0.40` direction, and monthly renewal.

Neither source tests this intersection, a Darwinex continuous CFD, fixed cash
risk, the ATR stop, costs, financing, or portfolio decorrelation. Those remain
falsifiable QM hypotheses.

The deterministic dedup checker scanned 4,299 EA-registry rows and 416
canonical cards before allocation and returned `CLEAN`, with no exact or fuzzy
hit. Manual comparison separated the mechanic from year-round
`QM5_13116_xng-signmom`, magnitude-return `QM5_20052_xng-seas-trend`, and the
incumbent `QM5_12567_cum-rsi2-commodity` two-day long-only oscillator
pullback. The two source windows, twelve binary completed-month signs, fixed
threshold, off-window flat state, and monthly lifecycle are jointly
load-bearing.

## Allocation And Commits

- EA ID and slug: `20242,xng-rsm-window`.
- Strategy ID: `SUENAGA-PAPAILIAS-XNG-SEASRSM-2026_S01`.
- Slot 0: `XNGUSD.DWX`, magic `202420000`.
- Initial registry row and magic allocation: artifact-pump commit
  `cdce93ccf` (the pump also collected one unrelated pre-existing factory
  artifact).
- Source packet, G0 decision, cards, and corrected registry-resolver hash:
  `271f89dd1`.
- EA source, EX5, specification, exact colocated card, fixed-risk setfile, and
  Q01 PASS status: `e9eeeec55`.
- CPU-stop status and this evidence: the commit containing this document.

## Q01 Evidence

- Canonical and approved card schema lint: PASS; no missing sections or ML
  hits.
- Canonical and approved G0 card lint: PASS.
- Build authorization guard: PASS for EA ID 20242 and its allocated directory.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Initial strict compile log:
  `C:/QM/repo/framework/build/compile/20260806_063558/QM5_20242_xng-rsm-window.compile.log`.
- Initial strict compile summary:
  `D:/QM/reports/compile/20260806_063558/summary.csv`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings; its compile also
  reported 0 errors and 0 warnings.
- Targeted compile log:
  `C:/QM/repo/framework/build/compile/20260806_063642/QM5_20242_xng-rsm-window.compile.log`.
- Targeted build report:
  `D:/QM/reports/framework/21/build_check_20260806_063642.json`.
- The generated set header has build hash
  `6f4b53f2ba4d105e1eb39bd575347dac8ff48d1fdcce33da4993fb94f3e97020`.
- EX5 size: 375,446 bytes.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the CPU-stop status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `C50E399C51473D56FCE7FEEB1A6C3005C6E6A1FA5A5895CB9650059BC7411450` |
| Canonical card | `E37F411B5301B3AFC99B42919F35410CF4961EE38D8E70ACEF11E60C1AC149DA` |
| Approved/local card | `A884B3C8FCE6693C52329637DFA32092FA4D02D678716E68A5EF14EFEE2F5A0C` |
| MQ5 | `E8B19292913016C007D18452103D208472B60DD543E6381EF42A78C52DC939B0` |
| EX5 | `989C89C6316EECE2D0A720B80F465CA9BDD223397E01799949684D245B7E0F63` |
| SPEC | `3A886DB04DA0CE3F5BB9FDC2C64158957997F367F8C99161C55FBF1A9B4FDFCC` |
| Backtest set | `47BCB140E713F5C19113031798EED1B5D3D3BC8A23B93A43108C775C6596CD4F` |

## Q02 Capacity Stop

The path-anchored process sample at `2026-08-06T06:41:46.4185981Z` found
nine exact factory terminals:

| terminal | PID |
|---|---:|
| T1 | 12668 |
| T2 | 11144 |
| T3 | 11764 |
| T5 | 16672 |
| T6 | 2912 |
| T7 | 16140 |
| T8 | 7160 |
| T9 | 17176 |
| T10 | 1964 |

Only executables matching
`D:/QM/mt5/T1..T10/terminal64.exe` were counted. `T_Live` and every other
terminal namespace were excluded by the matcher. The sample is 9/7 and is
therefore binding; Q02 remains `NOT_ENQUEUED_CPU_CEILING`.

The next paced operator may take a fresh immediate capacity sample and, only
when the exact count is below seven, run the targeted dry-run and apply pair:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20242 --symbols XNGUSD.DWX --max-part2-per-run 0
    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20242 --symbols XNGUSD.DWX --max-part2-per-run 0

This document records a ready but blocked handoff, not a Q02 screening
verdict.

## Safety Boundary

- No Q02 dry-run, apply-mode enqueue, manual backtest, dispatch tick, or
  downstream phase was run after the ceiling observation.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
