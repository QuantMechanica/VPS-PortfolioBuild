# QM5_20259 XNG Momentum Vote Q01 And CPU Stop

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20259_xng-mom-vote` is built and Q01 is `PASS`. Q02 is
`NOT_ENQUEUED_CPU_CEILING`: the binding path-anchored capacity sample found all
ten T1-T10 factory terminals active against the paced ceiling of seven. No
target dry-run or apply-mode enqueue was issued after that sample. No dispatch
command or manual backtest was run.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar of a genuine new broker-month transition, the EA
derives thirteen consecutive completed XNG month-end closes. It calculates the
signs of natural gas's completed one-, three-, and twelve-month log returns
from the common newest endpoint and trades their fixed two-of-three majority.
A zero component, invalid arithmetic, nonconsecutive history, or stale endpoint
consumes the month flat. One frozen `3.5*ATR(20,D1)` stop protects the position,
which exits at the next broker month or after forty calendar days.

The deterministic pre-allocation checker scanned 4,316 EA-registry rows and
433 cards, found no exact slug or strategy-ID collision, and returned three
expected source/mechanic-family fuzzy neighbors. Manual review resolved them
and the economically closest XNG systems:

- `QM5_20258` is the WTI carrier of the same fixed vote; this build trades only
  XNG and imports no WTI result;
- `QM5_20204`, `QM5_20063`, and `QM5_12804` follow one XNG horizon alone;
- `QM5_13116` measures the breadth of twelve individual monthly signs at a
  fixed 0.40 threshold rather than three nested cumulative returns;
- `QM5_12358` uses rolling 20/60/120 D1 bars, a daily clock and daily reversal
  exit, and does not register XNG; and
- certified `QM5_12567` is a long-only two-day cumulative-RSI(2) pullback with
  SMA(200) alignment and at most a five-D1-bar hold.

The exact XNG carrier, consecutive broker-calendar-month endpoints, nested
one/three/twelve horizons, strict nonzero components, majority mapping,
persisted monthly attempt, and monthly renewal are jointly load-bearing. The
signal clock and directionality differ from `QM5_12567`, but shared XNG
exposure does not establish decorrelation; unchanged Q09 remains authoritative.

## Source And G0 Record

The tier-A source is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete governed review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded XNG vote
extraction is `strategy-seeds/sources/MOP-XNG-MOMVOTE-2026/source.md`.

The source supplies explicit natural-gas membership and monthly own-return-sign
rules across formation lags. The two-of-three aggregation is a transparent QM
hypothesis, not an author result. No source profitability, density,
XNG-constituent, cost, or portfolio-correlation result transfers.

G0 authorization is
`decisions/2026-08-07_qm5_20259_xng_mom_vote_g0.md`. The authorization is
commit `ace7f29a7`, source/card approval `24f22a40b`, deterministic registry
allocation `2fa603207`, and build `662d64e56`.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20259` / `xng-mom-vote`.
- Strategy ID: `MOP-TSMOM-2012_XNG_MAJ1312_S13`.
- Symbol/slot/magic: `XNGUSD.DWX` / 0 / `202590000`.
- Card schema/ML lint: PASS on both intake and canonical cards; no missing
  sections or ML hits.
- SPEC validation: PASS, one target and zero failures.
- Target-scoped build gate:
  `D:/QM/reports/framework/21/build_check_20260807_041819.json` (`PASS`,
  0 failures, 0 warnings).
- The gate's compiler invocation:
  `D:/QM/reports/compile/20260807_041819/summary.csv` (`PASS`, 0 errors,
  0 warnings).
- Compile log:
  `C:/QM/repo/framework/build/compile/20260807_041819/QM5_20259_xng-mom-vote.compile.log`.
- EX5 size: 378,460 bytes.
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; generated header build hash
  `065e8e22b848db751a692256602899e271f244b5342a188823f8a69107d8fe1a`.
- Manual smoke/backtest: none.

Artifact SHA-256 values after the CPU-stop card-status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `621BE5DBE96A509C9076EC928529D9E6FCC65E727FFFEA51F072599757DB9739` |
| Canonical/build card | `FC97725D9D955E310EDB243814E98A1A11A5CAAF6DEE5F4C3BA2E123A15FE4AC` |
| MQ5 | `B20A14F9E37456559CDA7401EEFED8D0EE9F825E7F1D476C8029BBD704026D9F` |
| EX5 | `F0CE52638BFA875AF6D6025C5D5D414E14BE09C27630278C1959796E07CE17AF` |
| SPEC | `030765D78FEE21577898676AE17B3D83D2D6AF19AA979C3D88772BBF712AADDA` |
| Backtest set | `BBC1F43730631EC86BBFFA6DFA8A54E5F4735EA62D43F11E651336F63392E344` |

## Q02 Capacity Stop

`farmctl mt5-slots` sampled the governed processes at
`2026-08-07T04:21:48+00:00` and found ten exact factory terminals:

| Terminal | PID | Active phase |
|---|---:|---|
| T1 | 20092 | Q02 |
| T2 | 20512 | Q09_NEWS backfill |
| T3 | 19796 | Q02 |
| T4 | 15400 | Q02 |
| T5 | 11048 | Q02 |
| T6 | 19636 | Q07 |
| T7 | 4368 | Q02 |
| T8 | 4084 | Q02 |
| T9 | 8800 | Q09_NEWS |
| T10 | 9136 | Q02 |

Only executables rooted under `D:/QM/mt5/T1..T10/terminal64.exe` count. The
separate `C:/QM/mt5/T_Live` and FTMO processes were observed but excluded and
were not accessed or changed. The governed sample is 10/7 and therefore
binding.

An earlier exploratory `sweep_enqueue_built_eas.py --help` call was treated by
that script as its default global dry run. Its output explicitly reported
`APPLY=False`; no queue mutation occurred. After the binding capacity sample,
no target dry-run, apply, work-item mutation, dispatch, or terminal command was
issued.

The next paced operator may take a fresh immediate capacity sample and, only
below the seven-terminal ceiling, run:

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20259 --symbols XNGUSD.DWX --max-part2-per-run 0
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20259 --symbols XNGUSD.DWX --max-part2-per-run 0
python tools/strategy_farm/farmctl.py work-items --ea QM5_20259
```

This is a ready-but-capacity-blocked handoff, not a Q02 screening verdict.

## Safety Boundary

- No apply-mode enqueue, dispatch tick, manual backtest, or downstream phase
  was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading and `T_Live` were not touched.
- The portfolio gate and T_Live manifest were not touched.
