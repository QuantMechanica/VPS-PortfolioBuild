# QM5_20280 WTI Four-Month TSMOM — Q01 PASS / CPU-Ceiling Stop

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20280_wti-tsmom4m` is a new low-frequency outright WTI structural-
trend candidate. It is built and Q01 is `PASS`. Q02 is
`NOT_ENQUEUED_CPU_CEILING`: the binding path-anchored capacity sample found
seven executing T1-T10 factory terminals against the paced ceiling of seven.
The pre-sample target readback returned zero work items. No apply-mode enqueue,
dispatch, smoke test, or manual backtest was run.

## Edge And Non-Duplicate Boundary

At the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month change,
the EA reconstructs five consecutive completed WTI month-end closes
`C[0]..C[4]`, oldest to newest. It buys when the exact endpoint return
`ln(C[4]/C[0])` is positive, sells when it is negative, and consumes an exact-
zero or invalid month flat. The prior package closes before replacement at the
next month boundary. A frozen `3.5 * ATR(20,D1)` hard stop and forty-calendar-
day stale exit protect the position.

The canonical pre-allocation checker scanned 4,345 EA-registry rows and 456
cards. It found no exact identity and returned expected fuzzy matches sharing
the same peer-reviewed source and WTI trend vocabulary. Manual review separated
the absent exact four-completed-month mechanic from registered one-, two-,
three-, six-, nine-, and twelve-month carriers and from vote, weighted-return,
robust-return, regression, rank, path, run, calendar, and event rules. The five
endpoints, consecutive month keys, `(C[0],C[4])` orientation, symmetric sign,
persisted monthly attempt, and renewal lifecycle are jointly load-bearing.

The independent reference vectors prove positive, negative, and exact-zero
states; endpoint-versus-chained-log identity; chronology reversal; invalid
input rejection; and a path where the four-month signal is long while both the
three- and six-month neighbors are short.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and mechanic novelty do not prove low realized correlation;
unchanged downstream gates, including Q09, own that decision if the candidate
survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-TSMOM4-2026/source.md`. Its complete-read parent
is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in the commodity-futures universe.

The paper supports testing monthly own-price trend in WTI, but does not report
a standalone WTI four-month result or prescribe the Darwinex continuous CFD,
broker-month reconstruction, fixed-dollar sizing, ATR stop, spread cap, or
lifecycle. Those are explicit pre-result QM mechanizations. No source
performance, CFD equivalence, or portfolio-correlation result is imported.
Durable G0 authorization is
`decisions/2026-08-11_qm5_20280_wti_tsmom4m_g0.md`.

Reputable-source checks R1-R4 pass: one named peer-reviewed DOI record with a
complete governed read and durable hash; exact mechanical rules; a registered
WTI D1 route; and deterministic native arithmetic with no ML, trained output,
banned signal indicator, external runtime feed, grid, martingale, scale-in, or
pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20280` / `wti-tsmom4m` /
  `MOP-TSMOM-2012_XTI_4M_S28`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202800000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Resolver generation: 15,871 rows kept and zero dropped; the EA-ID and magic
  tuple each occur exactly once. Resolver SHA-256 is
  `1BFA2CE5FAA8E0CE2969E619D37347EE43D99AD3CE1FA16372A4D4EBFA0F2868`.
- Strict compile: `D:/QM/reports/compile/20260811_132811/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260811_132811/QM5_20280_wti-tsmom4m.compile.log`.
- Targeted build check:
  `D:/QM/reports/framework/21/build_check_20260811_132811.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20280/P1/P1_QM5_20280_result.json`, PASS.
- Independent statistic reference test:
  `framework/EAs/QM5_20280_wti-tsmom4m/docs/test_four_month_return_reference.py`,
  PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/build-card identity: PASS.
- Generated setfile header build hash:
  `eff9f719bd94d121b371c44c954d200c7ec4a5cf303cdf5ceda22a0fb2950a38`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at the capacity stop:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `6C9D1A0A4FB8BF77F629A978A3CE78BF662EA6021BC8F6E893A6B5DA206561AA` |
| Canonical/build card | `272BEA2B2320259D1713255B37E362FACDB1FFB262C64ED3E1978537ECD15F21` |
| MQ5 | `40995D4378F15C61515E76F637253212A03C59DA61479B0C9026ED4434D6DC73` |
| EX5 | `427A7AB0AC3CFE97D6A6746CCA6EA2DF3FC8C95EF1C1DCA99DA8EDD613C554F1` |
| SPEC | `0ACCA2B05A3C017AAF94037007E7A7A9DBF82F26633201B89237CDE892555F05` |
| Backtest set | `834B384B89ED60CA57E49D1DA3C434820194396F9D2D244F6A0B6EAC1BAC6EF3` |
| Reference test | `88BAF8F520863E292FF717A575B29C17EB59D56D0FFD0522818597FBDE657FB6` |

## Q02 Capacity Stop

The target-only non-mutating sweep at `2026-08-11T13:33:49+00:00` selected
exactly one never-tested priority-track row for
`QM5_20280 / XTIUSD.DWX`, zero stranded rows, and zero deferred rows. It
observed 1,114 pending items against the 7,000 queue ceiling. Its evidence was
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, `apply=false`,
with SHA-256
`9DF94090C65B0FD093E569C040CFAECDF3C27ABD196BBC52F681F6CC25860BD8`.
The paired target-only `farmctl work-items --ea QM5_20280` readback returned
`count=0`.

The required path-anchored process sample at
`2026-08-11T13:34:23.4269163Z` found seven exact factory terminals:

| Terminal | PID |
|---|---:|
| T1 | 9656 |
| T2 | 5172 |
| T3 | 6164 |
| T5 | 9084 |
| T7 | 11292 |
| T8 | 6492 |
| T10 | 16300 |

Only executables rooted under `D:/QM/mt5/T1..T10/terminal64.exe` count. The
machine-wide terminal count was nine, but the other two processes were outside
the governed factory paths and were excluded. The governed sample is exactly
7/7 and is therefore binding. No apply command was issued, and the sample was
not retried.

A later paced operator may take a fresh immediate capacity sample and, only
below the ceiling, run a fresh target dry run followed by exactly one bounded
apply:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20280 --symbols XTIUSD.DWX --max-part2-per-run 0
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20280 --symbols XTIUSD.DWX --max-part2-per-run 0
python tools/strategy_farm/farmctl.py work-items --ea QM5_20280
```

This is a ready-but-capacity-blocked handoff, not a Q02 screening verdict.

## Commits Before This Closing Evidence

- `af2802c07` — OWNER mission authorization and exact G0 decision.
- `f1ae92905` — bounded source packet plus approved/intake cards.
- `c95080c76` — deterministic EA-ID reservation.
- `26d59d041` — target SPEC scaffold.
- `8860c554d` — slot-0 WTI magic allocation and resolver generation.
- `f95fe48a3` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.

## Safety Boundary

- No apply-mode enqueue, dispatch tick, manual backtest, smoke test, or
  downstream phase was run after the binding sample.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the capacity stop.
