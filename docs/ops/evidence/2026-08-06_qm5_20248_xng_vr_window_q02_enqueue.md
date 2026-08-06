# QM5_20248 XNG Variance-Ratio Physical Window Q02 Enqueue

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; exactly one Q02 work item pending

## Outcome

`QM5_20248_xng-vr-window` is a new low-frequency natural-gas candidate on
`XNGUSD.DWX` D1. On the first D1 bar of each eligible broker month it
reconstructs thirty-three consecutive completed month-end closes, computes the
published `q=2` heteroskedasticity-robust variance-ratio state over thirty-two
monthly returns, and applies that state to the immediately completed return.
Significant persistence follows the return; significant anti-persistence
reverses it. The rule is active only in the source-defined May-September and
November-January physical-volatility windows.

The fixed Q02 package uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, a frozen `3.0 * ATR(20,D1)` hard stop, no target, monthly
renewal, and a forty-day stale guard. There is no parameter sweep, prohibited
signal indicator, trained state, external runtime feed, grid, martingale,
scale-in, live configuration, portfolio-gate change, or T_Live artifact.

Q01 passed with zero compile errors or warnings and zero build-check failures
or warnings. The immediate path-anchored capacity samples were below the
binding seven-terminal ceiling, so the guarded dry-run/apply sequence enqueued
exactly one priority Q02 row. No manual tester or dispatch command was run.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/SUENAGA-MEHLITZ-XNG-VRWIN-2026/source.md`.

- Suenaga, Smith, and Williams (2008), *Journal of Futures Markets* 28(5),
  438-463, DOI `10.1002/fut.20317`, supply the natural-gas physical-volatility
  windows.
- Mehlitz and Auer (2024), *The European Journal of Finance* 30(8), 773-802,
  DOI `10.1080/1351847X.2023.2220118`, supply the thirty-two-month `q=2`
  robust variance-ratio state, significance boundary, latest-return direction,
  and persistence / anti-persistence matrix.

Both sources have durable complete-read records. Neither tests this
intersection, a Darwinex continuous CFD, fixed cash risk, the ATR stop, costs,
financing, or portfolio decorrelation. The conjunction is a falsifiable QM
hypothesis, not a transferred source result.

The deterministic pre-allocation checker scanned 4,305 registry rows and 422
canonical cards. It found no exact collision and surfaced only the expected
fuzzy neighbor `QM5_20242_xng-rsm-window`. Manual review separates that
twelve-month binary-sign-share rule from this significant serial-dependence
state and anti-persistent reversal. Other clear boundaries are year-round WTI
memory `QM5_13134`, XNG magnitude trend `QM5_20052`, year-round XNG sign
momentum `QM5_13116`, and incumbent two-day cumulative-RSI pullback
`QM5_12567`.

## Allocation And Commit Chain

- EA ID and slug: `20248,xng-vr-window`.
- Strategy ID: `SUENAGA-MEHLITZ-XNG-VRWIN-2026_S01`.
- Slot 0: `XNGUSD.DWX`, magic `202480000`.
- Source packet, card, G0 authorization, and directory reservation:
  `2d30637ea`.
- Registry, magic, and resolver allocation: `fb6e65315`.
- Generated backtest setfile seed: `994ae1f73`.
- EA source, EX5, SPEC, colocated contract, approved contract, fixed-risk
  setfile build binding, and Q01 status: `ce0ea3c00`.

## Q01 Evidence

- Canonical and approved card schema lint: PASS; no missing sections or
  forbidden-model hits.
- Approved and colocated execution-contract copies match byte-for-byte.
- Exact slug, numeric EA ID 20248, active registry row, active magic row, EA
  directory, and resolver values were verified before compile.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_111821/QM5_20248_xng-vr-window.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_111821/summary.csv`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260806_111926.json`.
- Canonical set header build hash:
  `d92f1b8a82a1436a917c79c5b5aee325e96c9fd407587a945203d9fe64d51e3b`.
- EX5 size: 376,522 bytes.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final build:

| Artifact | SHA-256 |
|---|---|
| Source packet | `AA60AA196BD1A532A1CD438A14FB1C2A542215997DC101D8474E505683718115` |
| MQ5 | `7DBD521599882CE86A0CA3904EEB496E128BE82CC51401DB79939BD81778CB5C` |
| EX5 | `A27373D02AFAEEF8F7A9D5BDA57AF375C420664B1E28F6E9AE84A1EB3A67A11E` |
| SPEC | `82D195AA13C2ADE3A91FB7AE6FFAC2CCB23F0FDC2B80CDD539C7F153051236C5` |
| Backtest set | `2DB702C2EB1CB23B36A6D862E66DAA4ADC1C2FFA1B30CB17E182B5B41C5147BB` |

## Q02 Capacity And Queue Evidence

Only executable paths matching
`D:/QM/mt5/T1..T10/terminal64.exe` were counted. T_Live, FTMO, and every other
namespace were excluded.

- `2026-08-06T11:21:20.7120022Z`: 6/7 exact factory terminals; enqueue allowed.
- Guarded dry run: one never-tested `QM5_20248` / `XNGUSD.DWX` Q02 row, zero
  skips, zero stranded rows.
- `2026-08-06T11:22:08.9377611Z`: 5/7 exact factory terminals immediately
  before apply; enqueue allowed.
- Apply evidence:
  `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, generated at
  `2026-08-06T11:22:18Z` with target EA `QM5_20248`, target symbol
  `XNGUSD.DWX`, one priority row, and zero skips.
- Canonical work-item query after apply: exactly one row,
  `178a7b59-3bb7-49e7-9c28-36b7841be600`, phase `Q02`, status `pending`,
  attempt count `0`, unclaimed.

No dispatch tick, worker claim, terminal reservation, or tester launch was
performed by this work session.

## Safety Boundary

- No manual backtest, downstream phase, terminal-control action, or live action
  was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate, T_Live manifest, and deploy manifests were not touched.
