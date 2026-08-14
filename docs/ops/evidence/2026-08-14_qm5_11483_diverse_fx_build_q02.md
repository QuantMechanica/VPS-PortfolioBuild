# QM5_11483 Diverse FX Q01 Build and Q02 Handoff

Date: 2026-08-14 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One approved, structural, low-frequency FX candidate was recovered from the
build backlog, brought onto the current V5 framework corset, strictly compiled,
and handed to the paced Q02 fleet:

- EA: `QM5_11483_williams-l-outside-bar-exhaustion-d1`.
- Instruments: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, and
  `USDCAD.DWX`, all D1.
- Card expectation: about 15 trades/year/symbol.
- Q01 build: PASS, 0 compile errors and 0 warnings.
- Q02: three stage-1 rows enqueued; two symbols retained in the farm's
  priority deferred-cohort sidecar.

This adds a five-symbol major-FX cohort to a funnel whose Q08 soft survivors
are concentrated in index, metal, and energy instruments. The handoff is not a
profitability, walk-forward, certification, decorrelation, or portfolio
admission verdict.

## Selection and Farm Claim

The mission-filtered backlog selection required an approved card with all
R1-R4 gates PASS, a reputable source, low expected frequency, structural
non-ML mechanics, exact active EA/magic registrations, and no competing open
claim. `QM5_11483` was the highest-diversity eligible row: five major-FX hosts
on D1 from the Williams/Goodwin published lineage. A nominally higher farm
score was an anonymous M5/high-frequency setup and did not satisfy the mission
constraints.

The farm claim was committed before repository mutation:

- Build task: `557db8df-51ab-4636-b361-58b314813f0b`.
- Agent task: `4ea1c363-eb57-4a9d-9ab3-3bbb8a9b4ce7`.
- Claim owner: `codex:agents/board-advisor`.
- Claim key:
  `manual:codex:agents/board-advisor:QM5_11483:q01-build-q02-handoff:2026-08-14T05:51:05+00:00`.
- Pre-claim online backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11483_build_claim_20260814T055105Z.sqlite`.
- Pre-record online backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11483_record_build_20260814T060650Z.sqlite`.
- Source and backup SQLite `quick_check`: `ok`; post-record source
  `quick_check`: `ok`.

## Frozen Edge and Registry Binding

The approved mechanics were not changed:

- A completed D1 outside bar must make both a higher high and lower low than
  the preceding D1 bar.
- A close below the preceding low triggers a next-bar long; a close above the
  preceding high triggers the mirrored short.
- Friday signal bars are skipped.
- Stop loss is fixed at 200 pips; a profitable trade exits at the next D1
  profit check, otherwise the hard exit is five D1 bars.
- One framework-governed position, a 25-pip spread cap, no ML, banned
  indicator, grid, martingale, pyramid, or scale-in.

Existing deterministic registrations were verified and left unchanged:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | `114830000` |
| 1 | `GBPUSD.DWX` | `114830001` |
| 2 | `USDJPY.DWX` | `114830002` |
| 3 | `AUDUSD.DWX` | `114830003` |
| 4 | `USDCAD.DWX` | `114830004` |

## Q01 Build Evidence

The prior governed attempt stopped at Q01 because its five raw `iTime`/OHLC
series calls violated the current framework guard. This repair replaced those
reads with two `QM_ReadBar` calls and refreshed only canonical lifecycle
wiring: per-tick MAE tracking, entry-only central news gating after
management/exits, and a zero-initialized entry request. Signal, exit, stop, and
direction mechanics remain card-exact.

- Approved-card copy matches the canonical farm card line-for-line.
- Seven-section SPEC validation: PASS, 1/1.
- Strict V5 static build check with a summary-linked schema-v1 logger sample:
  PASS, 0 failures and 0 warnings at
  `D:/QM/reports/framework/21/build_check_20260814_060141.json`.
- Single strict MetaEditor compile: PASS, 0 errors and 0 warnings at
  `D:/QM/reports/compile/20260814_060200/summary.csv`.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260814_060200/QM5_11483_williams-l-outside-bar-exhaustion-d1.compile.log`.
- All five canonical backtest setfiles use `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and D1.
- No smoke/backtest was launched during Q01: `qm-build-ea-from-card` is
  build-only, and the paced fleet owns the Q02 execution.

Artifact SHA-256 values at handoff:

| Artifact | SHA-256 |
|---|---|
| Approved/build card | `ffff39a8b46d6762a291d73f5baa00d3a202ab24263c7a1a0f3f6c3e6491e9d5` |
| MQ5 | `ccf77e0a8b73f57ed071796d18ebdac19d8b65ba8fd41d8a0808c2674c1f2d30` |
| EX5 | `a4c3c6632a36053cc822fa6d7aec7bac64463a7352a55816a39fbc0f6ddfcea6` |
| SPEC | `745274e4fa49a64e704805dc8395f9a69cc1ad4d99362655b1888d84e9580376` |
| AUDUSD setfile | `ce3eb03cdadaf97064f0b288acb335ca94a9024ff91238e4a09554c45563422d` |
| EURUSD setfile | `55cf39ae6662b8b584613565a1d234f47f63c9af5205c17306b277e2df648002` |
| GBPUSD setfile | `daf2a3629f076c368d1872f6190277d41efa130e4973f4e8f8a5cb21832ac055` |
| USDCAD setfile | `ba90a72104e3240a94f472c0721a5fa4a69f72d9d77b7193fc66a0645dc75904` |
| USDJPY setfile | `79a9db635f719a8b2a59e51f1c8af43169208b5aa3d477c38920b2668a9062fb` |
| Farm build result | `93a14d20d311ab4d7d32512741e6811c5e89f094b0dd16d9f13d5080c2551ef4` |
| Build-check report | `f3058bfad5e419bc10bfa0709821218d0829d51448e6ebee92d34292c29cd35c` |
| Compile summary | `26e5ea6396f99930db5c735d9f83356ad07d5a64cedc6807034a869c1fc541df` |
| Compile log | `42c9802429f6d6866f2d626fed0217c51d34d56a82444e183995dac555536091` |

## Paced Q02 Handoff

`farmctl record-build` accepted the clean result, marked the build task
`done`, and atomically created the first three exact Q02 rows:

| Work item | Symbol | State at final handoff observation |
|---|---|---|
| `5c9e46bc-880c-4056-af7f-e6d9641bf25b` | `EURUSD.DWX` | pending, attempt 0 |
| `eeeb1ec1-edfb-451b-8691-61fe1b2ad490` | `GBPUSD.DWX` | pending, attempt 0 |
| `baa07ca3-41ea-4400-a28b-cd1fc705bfe5` | `USDJPY.DWX` | pending, attempt 0 |

The farm's stage-1 cap is three. `AUDUSD.DWX` and `USDCAD.DWX` are recorded in
`D:/QM/strategy_farm/state/q02_deferred_symbols.json` with
`priority_track=true`, `q02_cohort_size=5`, and this exact build task ID. They
were deferred, not discarded.

Immediately before record-build, `farmctl mt5-slots` reported zero running
T1-T10 factory terminals, below the seven-terminal CPU ceiling. The observed
FTMO and `T_Live` processes were out of scope and untouched.

## Safety Boundary

- No manual backtest or pipeline phase was launched; the paced fleet owns Q02.
- AutoTrading was not toggled, and `T_Live` was neither accessed nor changed.
- The portfolio gate and T_Live deploy manifest were not touched.
- No registry row, resolver, deploy artifact, or live configuration was
  changed.
