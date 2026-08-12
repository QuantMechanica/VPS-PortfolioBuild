# QM5_20241 WTI Seasonal 52-Week Anchor Q01 And CPU Stop

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 not enqueued because the binding backtest CPU ceiling
was exceeded.

## Outcome

`QM5_20241_wti-seas-anchor` is a new structural, low-frequency direct-crude
candidate on `XTIUSD.DWX` D1. On the first tradable D1 bar of each broker
month it combines:

- the November-May positive and June-October negative WTI physical-season
  map;
- proximity of the newest completed close to the trailing 252-D1 closing
  high or low; and
- an exact completed 63-D1 log-return confirmation in the seasonal direction.

It buys November-May only when `C0/H252 >= 0.94` and `ln(C0/C63) >= 0.02`.
It sells June-October only when `C0/L252 <= 1.08` and
`ln(C0/C63) <= -0.02`. Disagreement consumes the month flat. Risk is a frozen
`3.5 * ATR(20,D1)` hard stop, no target, monthly rollover, a forty-day stale
guard, and exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

Q01 passed with zero compile errors or warnings and zero build-check failures
or warnings. Q02 readiness was identified by a no-apply sweep, but all ten
exact factory terminals were running against the binding ceiling of seven.
No apply-mode enqueue or tester run was performed by this session.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-BIANCHI-WTI-SEAS52W-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply the WTI physical-season
  direction.
- Bianchi, Drew, and Fan (2016), *Journal of Banking & Finance*, DOI
  `10.1016/j.jbankfin.2016.06.010`, supply the commodity 52-week-anchor
  lineage.

Neither source tests this conjunction, its thresholds, a Darwinex continuous
CFD, fixed cash risk, the ATR stop, costs, financing, or portfolio
decorrelation. Those remain falsifiable QM hypotheses.

The deterministic dedup checker scanned 4,298 EA-registry rows and 415
canonical cards and returned `CLEAN`, with no fuzzy match above threshold.
Manual comparison separated the mechanic from the year-round WTI 52-week
anchor, unconditional Halloween long/short, winter-only raw 252-D1 trend,
summer weekly trend, twelve-month seasonal momentum, monthly-sign breadth,
and the incumbent XNG two-day oscillator sleeve. The fixed two-season map,
closing-extreme location, distinct 63-D1 threshold, agreement-flat state,
and monthly lifecycle are jointly load-bearing.

## Allocation And Commits

- EA ID and slug: `20241,wti-seas-anchor`.
- Strategy ID: `BURAKOV-BIANCHI-WTI-SEAS52W-2026_S01`.
- Slot 0: `XTIUSD.DWX`, magic `202410000`.
- Research, G0 decision, allocation, and resolver commit: `5b23e710c`.
- Compiler artifact-pump commit for the EX5 and fixed-risk set:
  `2d8e49b43` (the pump also collected one unrelated pre-existing fleet
  artifact).
- EA source, specification, colocated card, and Q01 card status commit:
  `7f4e92de7`.
- CPU-stop status and this evidence: the commit containing this document.

## Q01 Evidence

- Canonical and approved card schema lint: PASS; no missing sections or ML
  hits.
- G0 card lint: PASS.
- Build authorization guard: PASS for EA ID 20241 and its allocated directory.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_052436/QM5_20241_wti-seas-anchor.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_052436/summary.csv`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260806_052510.json`.
- The generated set header has build hash
  `0e08957d74506d1cd7417f0f8077bfc6ff9fd77abf6fdb721dce44f21882777b`.
- EX5 size: 374,430 bytes.
- Manual smoke or backtest run: none.

The repository-wide registry validator remains nonzero on pre-existing legacy
registry debt. The target build guard passed for EA 20241, its active EA row,
slot-0 magic, and directory; no unrelated registry debt was changed.

Artifact SHA-256 values after the CPU-stop status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `CDF56203620C1B2BAB8DFE2764F4D3BE6FAFFB05D2B0977E6086B8BE69CC64D3` |
| Canonical card | `C5BD2F5BC81BD8E9345F87F1239BDE84F4BCE53F53A823C7BAAE7C3920B6BC0A` |
| Approved/local card | `C5BD2F5BC81BD8E9345F87F1239BDE84F4BCE53F53A823C7BAAE7C3920B6BC0A` |
| MQ5 | `EB8701ECAF1015753D7AB37E148BD0528FB0FAB178BE68B5B7D76BA444AC6420` |
| EX5 | `E135948E9E687CA4D8A4FA8413D0B4E6EE4A94B9817DC181EDF5D945F496D341` |
| SPEC | `09F05B384609E2923CF6F62E55C92558E64D40AC68AB3CCBD3A81A79D133068F` |
| Backtest set | `B03B7CF2B64DD0DC6E6F7F01368233918D616022757E5FDD9B4AB343282DDF3A` |

## Q02 Dry Run And Enforced Stop

While inspecting the legacy sweep interface, this no-apply command was run:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --help

The script has no conventional help handler and treated the unknown flag as
its default fleet dry run. It did not mutate the database. The evidence file
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, generated at
`2026-08-06T07:30:17+02:00`, records `apply=false`, 1,495 pending rows, a
7,000-row queue ceiling, and explicitly selected this never-tested priority
item:

| EA | Symbol | Setfile | Priority |
|---|---|---|---|
| `QM5_20241` | `XTIUSD.DWX` | `QM5_20241_wti-seas-anchor_XTIUSD.DWX_D1_backtest.set` | true |

The immediate path-anchored process scan and the confirming sample at
`2026-08-06T07:31:51+02:00` found ten running factory terminals:
`T1,T2,T3,T4,T5,T6,T7,T8,T9,T10`. Only executables matching
`D:/QM/mt5/T1..T10/terminal64.exe` were counted. This is 10/7 and therefore
binding. `T_Live` and every other terminal namespace were excluded by the
path matcher.

The next paced operator may repeat a targeted dry run and apply only after a
fresh immediate path-anchored sample is below seven:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20241 --symbols XTIUSD.DWX --max-part2-per-run 0
    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20241 --symbols XTIUSD.DWX --max-part2-per-run 0

This document records a ready but blocked handoff, not a Q02 screening
verdict.

## Safety Boundary

- No apply-mode Q02 enqueue, manual backtest, dispatch tick, or downstream
  phase was run after the ceiling observation.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
