# QM5_20247 WTI Variance-Ratio Calendar Regime Q01 And CPU Stop

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 not enqueued because the binding backtest CPU ceiling
was reached.

## Outcome

`QM5_20247_wti-vr-calreg` is a new low-frequency direct-WTI candidate on
`XTIUSD.DWX` D1. At each broker-month transition it reconstructs thirty-three
consecutive completed month-end closes and estimates the published `q=2`
robust variance-ratio state over thirty-two monthly returns. Significant
persistence follows the source-defined November-May long / June-October short
physical-season direction; significant anti-persistence reverses it;
insignificant memory consumes the month flat.

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
`strategy-seeds/sources/BURAKOV-MEHLITZ-WTI-VRCAL-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply the alternative-two WTI
  November-May positive / June-October negative physical-season partition.
- Mehlitz and Auer (2024), *The European Journal of Finance* 30(8), 773-802,
  DOI `10.1080/1351847X.2023.2220118`, supply the thirty-two-month `q=2`
  robust variance-ratio test, significance boundary, and persistence /
  anti-persistence direction matrix.

Both peer-reviewed sources explicitly cover WTI. Neither tests this calendar
state inside the memory matrix, a Darwinex continuous CFD, fixed cash risk,
the ATR stop, costs, financing, or portfolio decorrelation. The conjunction is
a falsifiable QM hypothesis, not a transferred source result.

The deterministic pre-allocation checker scanned 4,304 EA-registry rows and
421 canonical cards and returned `CLEAN`, with no exact or fuzzy match. Manual
review separated the mechanic from `QM5_13134_energy-vr-mom` (latest one-month
sign), `QM5_20245_wti-vr-rsm` (twelve-month sign breadth), unconditional WTI
calendar carriers `QM5_20015` and `QM5_20046`, seasonal price-state cards
`QM5_20222`, `QM5_20227`, `QM5_20231`, and `QM5_20241`, and the incumbent
`QM5_12567_cum-rsi2-commodity` XNG oscillator pullback.

## Allocation And Commits

- EA ID and slug: `20247,wti-vr-calreg`.
- Strategy ID: `BURAKOV-MEHLITZ-WTI-VRCAL-2026_S01`.
- Slot 0: `XTIUSD.DWX`, magic `202470000`.
- Source packet, cards, and G0 authorization: `f65d825aa`.
- Registry, magic, and resolver allocation: `d6931432d`.
- Atomic EA directory reservation: `319b981cf`.
- EA source, EX5, SPEC, colocated card, fixed-risk setfile, and Q01 status:
  `273b20935`.

## Q01 Evidence

- Canonical, approved, and colocated cards match byte-for-byte.
- Canonical and approved card schema lint: PASS; no missing sections or
  forbidden-model hits.
- Build authorization preflight: PASS for approved G0 card, exact slug,
  numeric EA ID 20247, active registry row, active magic row, and allocated
  directory.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_101727/QM5_20247_wti-vr-calreg.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_101727/summary.csv`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260806_101805.json`.
- Canonical set header build hash:
  `9cd18cb5b473b2ffa28bf943d7c0e786895d240bf585e8b29d35a06bf9c97129`.
- EX5 size: 376,194 bytes.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final build:

| Artifact | SHA-256 |
|---|---|
| Source packet | `737137B5C63E02A9AFCB6D1D5FA996C5310433CD8EE1CBCB071028238EBCD6A3` |
| MQ5 | `2990CAC3C5DC270CB2E59A27E5349F4F91BBC387A4B6557082A7BF178F06BDCB` |
| EX5 | `1D38E2B2CFB10C3C1F70D054C8A841075306F9892D5D7C6599951F82D551EC87` |
| SPEC | `0C73F71F05B90C60FE8EBEEC6DD4E640B60B745875C10609382CAD31880DA789` |
| Backtest set | `E0957D163CB53C099C29F171D6E1DF36A08005BD7D4247BAC1350189E020FBD3` |

## Q02 Capacity Stop

The path-anchored process sample at `2026-08-06T10:20:01.7708155Z` found ten
exact factory terminals:

| terminal | PID |
|---|---:|
| T1 | 15692 |
| T2 | 7428 |
| T3 | 17056 |
| T4 | 15088 |
| T5 | 10160 |
| T6 | 16668 |
| T7 | 15576 |
| T8 | 1096 |
| T9 | 6340 |
| T10 | 11704 |

Only executable paths matching `D:/QM/mt5/T1..T10/terminal64.exe` were counted.
`T_Live`, FTMO, and every other namespace were excluded. The sample is 10/7
and binding. A subsequent read-only canonical farm query returned zero work
items of any phase for `QM5_20247`; Q02 remains
`NOT_ENQUEUED_CPU_CEILING`.

The next paced operator may take a fresh immediate capacity sample and, only
when the exact count is below seven, run the targeted dry-run/apply pair:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20247 --symbols XTIUSD.DWX --max-part2-per-run 0
    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20247 --symbols XTIUSD.DWX --max-part2-per-run 0

This is a ready-but-capacity-blocked handoff, not a Q02 screening verdict.

## Safety Boundary

- No Q02 enqueue attempt, manual backtest, dispatch tick, or downstream phase
  was run after the ceiling observation.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
