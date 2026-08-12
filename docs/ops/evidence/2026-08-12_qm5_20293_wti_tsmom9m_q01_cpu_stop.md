# QM5_20293 WTI Nine-Month TSMOM — Q01 PASS / CPU-Ceiling Stop

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20293_wti-tsmom9m` is a new low-frequency outright WTI structural-
trend candidate. It is built and Q01 is `PASS`. Q02 is
`NOT_ENQUEUED_CPU_CEILING`: the binding path-anchored capacity sample found
seven executing T1-T10 factory terminals against the paced ceiling of seven.
The immediate target readback returned zero work items. No apply-mode enqueue,
dispatch, smoke test, or manual backtest was run.

## Edge And Mechanical Contract

At the first processed `XTIUSD.DWX` D1 bar after a genuine broker-month
transition, the EA reconstructs ten consecutive completed WTI month-end closes
`C[0]..C[9]`, oldest to newest. It buys when the exact endpoint return
`ln(C[9]/C[0])` is positive, sells when it is negative, and consumes an
exact-zero or invalid month flat. The prior package closes before replacement
at the next month boundary. A terminal-persistent attempt marker is written
before data and order gates. A frozen `3.5 * ATR(20,D1)` broker hard stop and
forty-calendar-day stale exit protect the one-position package.

The only setfile is `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. It locks the nine-month
horizon, 500-D1 bounded reconstruction, ATR period and multiplier, hold cap,
and 1,500-point spread ceiling. Both news axes and Friday close are OFF. There
is no trained output, prohibited signal indicator, external runtime feed,
grid, martingale, scale-in, or pyramid.

WTI is direct crude-oil exposure absent from the current XAU, SP500, NDX, and
XNG book. Carrier novelty and structural logic do not prove low realized
portfolio correlation; the unchanged downstream correlation gate owns that
decision if the candidate survives Q02-Q08.

## Source And Non-Duplicate Review

The primary source is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed complete-read parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, whose source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`;
its 23-page paper receipt records PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
The paper explicitly includes NYMEX WTI crude in its commodity universe and
supports testing monthly own-price trend. It does not report this standalone
WTI nine-completed-broker-month CFD rule or prescribe its sizing, stop,
spread, and lifecycle mechanizations.

The bounded carrier packet is
`strategy-seeds/sources/MOP-WTI-TSMOM9-2026/source.md`; durable G0
authorization is
`decisions/2026-08-12_qm5_20293_wti_tsmom9m_g0.md`.

The canonical pre-allocation check scanned 4,358 EA-registry rows and 469
cards. It found no exact slug, strategy-ID, or mechanic identity and returned
11 expected fuzzy same-source neighbors for manual review. Existing exact
completed-month WTI carriers use one, two, three, four, six, or twelve months.
The superficially closest `QM5_12616_tsmom-9m-commodity-xtiusd` instead uses
189 completed D1 bars, a 1.5% neutral threshold, and a 63-D1 same-sign
confirmation. This package uses ten consecutive completed broker-month
endpoints, pure endpoint sign with no threshold or confirmation, and monthly
renewal. Verdict:
`CLEAN_NON_DUPLICATE_AFTER_MANUAL_REVIEW`.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20293` / `wti-tsmom9m` /
  `MOP-TSMOM-2012_XTI_9M_S30`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202930000`.
- Resolver generation kept 15,904 rows and dropped zero; embedded registry
  SHA-256:
  `608DE45BBE302F695619B93BC4CAD1A9476DC03927652B2247F6EDB00D275019`.
- Strict compile:
  `D:/QM/reports/compile/20260812_181052/summary.csv`, PASS with zero errors
  and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260812_181052/QM5_20293_wti-tsmom9m.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_181142.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20293/P1/P1_QM5_20293_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20293_wti-tsmom9m/docs/test_nine_month_return_reference.py`,
  PASS for positive, negative, exact-zero, endpoint/path identity, chronology,
  invalid inputs, and four-/twelve-month neighbor divergence.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation,
  target registry uniqueness/formula, and canonical/intake/build-card
  synchronization: PASS.
- Setfile header build hash:
  `684d4dea679672a9262c0592e06faa8576ecdba0f7d4534923d7a9d85f00dca3`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `CF077674C4D82F7F8539A938939DC70DB637DFE750D09B341F2A998333CB8D3C` |
| Bounded source packet | `DC2D7E58F1E7EDAA710C54D6EB631BBD28061F0EC241151F4FEF14111478F22B` |
| Canonical/intake/build card | `D9649BE9C1E35BA098FD82B3E4781D45FCF0BB89189EC8EA89F1A1BEBE2E9D70` |
| MQ5 | `ACF0DD6A3A3008521DCE2770BDC94A3342C5D2079C179774A63864BAE036D68B` |
| EX5 | `1F138E3D788EEAFBA7F58D7D810D6C253DBE603B62A76108529C3E50BF411DDE` |
| SPEC | `A205910AA3044560EDB22542779DC15D369214230DCA1C06ED458A204E629795` |
| Backtest set | `F3DF23204D684D6789A990853267FE687E735D2C1A51CDF46AF94EAE83257B8C` |
| Reference test | `71D3AE1A5AFFA48AB05FC49A6B05EDD442BDE7780AA0A1A4F1EF290C84ADA05F` |
| Generated resolver | `2147751F4FD9840F9F9C6EC9D2CCCEA33990B02C8034A41F84A2F7C14BBC7AD8` |

## Q02 Capacity Stop

The one binding path-anchored sample was taken at
`2026-08-12T18:15:59.0156924Z`. Only executables exactly rooted under
`D:/QM/mt5/T1..T10/terminal64.exe` count. It found:

| Terminal | PID |
|---|---:|
| T1 | 16172 |
| T2 | 18480 |
| T4 | 8060 |
| T5 | 17372 |
| T6 | 11464 |
| T8 | 14236 |
| T9 | 18756 |

Seven governed processes equal the seven-job ceiling, so the sample is
binding. The subsequent read-only command
`python tools/strategy_farm/farmctl.py work-items --ea QM5_20293` returned
`count=0`. No target dry-run or apply command was issued, and the capacity
sample was not retried.

A later paced operator may take a fresh immediate capacity sample and, only
below the ceiling, run one target-only dry run followed by exactly one bounded
apply:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20293 --symbols XTIUSD.DWX --max-part2-per-run 0
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20293 --symbols XTIUSD.DWX --max-part2-per-run 0
python tools/strategy_farm/farmctl.py work-items --ea QM5_20293
```

This is a ready-but-capacity-blocked handoff, not a Q02 screening verdict.

## Scoped Commits Before Closing Evidence

- `b5fa1e15f` — durable G0 decision, bounded source packet, and synchronized
  approved/intake cards.
- `33f495a75` — deterministic EA-ID, magic allocation, and generated resolver.
- `3d6aa3c30` — target SPEC scaffold.
- `631da1830` — EA source, EX5, fixed-risk setfile, reference test,
  synchronized cards, and Q01 bindings.

## Safety Boundary

- No apply-mode enqueue, dispatch tick, manual backtest, smoke test, or
  downstream phase was run after the binding sample.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, T_Live deploy/manifest, or
  portfolio-gate file was changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the capacity stop.
