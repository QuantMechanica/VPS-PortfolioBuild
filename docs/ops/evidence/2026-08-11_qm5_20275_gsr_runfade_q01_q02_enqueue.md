# QM5_20275 Gold/Silver Fresh-Run Fade — Q01 PASS / Q02 Enqueued

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20275_gsr-runfade` is a new low-frequency precious-metals
relative-value candidate. It passed Q01 and has exactly one Q02 work item:
`2384e96c-5240-4c0c-8829-c2fab47702b3`.

Immediate and later readbacks found the row pending, attempt 0, unclaimed,
and without a verdict. Enqueue is a screening handoff, not an efficacy,
certification, neutrality, decorrelation, or portfolio-admission result.

## Edge And Non-Duplicate Boundary

On each new `XAUUSD.DWX` D1 host bar, the EA aligns seven completed XAU and
XAG closes and computes `r[k]=ln(XAU[k])-ln(XAG[k])` and
`d[k]=r[k]-r[k+1]`. Five newest strictly positive `d` values with a
nonpositive sixth value form a fresh upper run; the EA fades it with SELL XAU
and BUY XAG. Five newest strictly negative values with a nonnegative sixth
value form a fresh lower run; the sides are reversed. Zero breaks the newest
five-return run, while equality is a valid sixth-return break.

The opposite-leg package closes on the first completed counter-return,
invalid composition/state, or twelve elapsed calendar days. Each leg has a
frozen `3.5 * ATR(20,D1)` hard stop. One persistent attempted-event timestamp
is consumed before execution gates, so rejection, failure, stop, or restart
cannot retry the completed event.

The deterministic pre-allocation check scanned 4,339 EA-registry rows and 448
cards and returned `CLEAN`. Manual review separated the event from existing
XAU/XAG arithmetic z-scores, rolling OLS residuals, median/MAD scores,
empirical-tail fades, failed channels, calendar rules, moment estimators, and
monthly rank/momentum families. No existing card requires the exact five
strict same-sign daily relative returns, sixth-return break, inverse package,
and first-counter-return exit.

This paired relative-value carrier is economically different from outright
XAU, SP500, NDX, and XNG direction, but opposite legs and equal stop-risk do
not prove market, beta, volatility, factor, dollar, or portfolio neutrality.
Q09 alone may establish realized portfolio correlation if the candidate
reaches it.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/SCHWEIKERT-CME-GSR-RUN-2026/source.md`. Its governed
parents are Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021), *Resources
Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME Group's
exchange education on the Gold & Silver Ratio Spread.

The peer-reviewed sources support investigating a potentially
state-dependent long-run gold/silver relationship; CME supports the
intermarket ratio carrier. None specifies the five-return run, break rule,
inverse sides, exit, CFD mapping, risk sizing, or lifecycle. No source
performance, CFD equivalence, neutrality, or correlation result is imported.
G0 authorization is
`decisions/2026-08-11_qm5_20275_gsr_runfade_g0.md`.

Reputable-source checks R1-R4 pass: named peer-reviewed DOI records plus an
exchange carrier, complete governed reads and durable hashes; exact mechanical
rules; registered XAU/XAG D1 routes; and deterministic native arithmetic with
no ML, trained output, banned signal indicator, external runtime feed, grid,
martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20275` / `gsr-runfade` /
  `SCHWEIKERT-CME-GSR-RUNFADE-2026_S04`.
- Host/slot/magic: `XAUUSD.DWX` / 0 / `202750000`.
- Second leg/slot/magic: `XAGUSD.DWX` / 1 / `202750001`.
- Backtest risk contract: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`, split equally by per-leg stop-risk.
- Resolver generation: 15,800 rows kept, zero dropped; both target magics are
  present in the committed resolver.
- Strict compile: `D:/QM/reports/compile/20260810_230519/summary.csv`, PASS
  with zero errors and zero warnings.
- Strict compile log:
  `C:/QM/repo/framework/build/compile/20260810_230519/QM5_20275_gsr-runfade.compile.log`.
- Final targeted build check:
  `D:/QM/reports/framework/21/build_check_20260810_231938.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20275/P1/P1_QM5_20275_result.json`, PASS.
- Card-schema/ML lint on canonical and intake cards, G0 lint,
  build-prerequisite guard, SPEC validation, and canonical/build-card
  identity: PASS.
- Generated setfile header build hash:
  `b0d361346047ed8d0e3563301227e9a22afd10c37e9b07c0147c1e1a0b9200ac`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at Q02 handoff:

| Artifact | SHA-256 |
|---|---|
| Bounded source packet | `F5BC9077F1ED16DDC3E4A381A02FA54E9C56F059C54482E162D3E4A1C044182C` |
| Canonical/build card | `F892ED242F9715186E22A5130AD423F805C81A51244418EA76BD0673427B1B6B` |
| MQ5 | `C895B2F70A9610F24F8FA9B0A07F085965FB81B71412A701A860856F967B9BC7` |
| EX5 | `0B91AA559F19500F602EB584EE5135BA27BA735D0A13DD702AAFE09A05D253CB` |
| SPEC | `73B87A977FE6EF875D626FEA28E852F96F653ACF06B73AEDE0DAF370E674E5FF` |
| Basket manifest | `BD44B6EE370FB21E98CCAB185596A1031F3357D3539FF7CFD978DEC93C605FAA` |
| Backtest set | `6A5762945FE0A2F1418CC23E784085672D2A672D0D8D1FF0CC7B52D526C34E88` |

## Paced Q02 Handoff

Before mutation, target readback found zero prior work items. The exact-EA
dry run selected one never-tested priority logical-basket row, no stranded
retry, and no deferred promotion. It found 1,140 pending rows against the
queue ceiling of 7,000.

The binding `farmctl mt5-slots` sample at
`2026-08-10T23:14:38+00:00` found six executing T1-T10 factory terminals
against the ceiling of seven: T1, T2, T4, T5, T8, and T10. T_Live and the
FTMO terminal were outside the factory count and were not changed. The CPU
ceiling was not reached.

The single lock-guarded apply enqueued:

- Work item: `2384e96c-5240-4c0c-8829-c2fab47702b3`.
- Created: `2026-08-10T23:14:52+00:00`.
- Phase/kind: Q02 / backtest.
- Logical symbol/timeframe: `QM5_20275_XAU_XAG_RUNFADE_D1` / D1.
- Physical basket: host `XAUUSD.DWX`; traded legs `XAUUSD.DWX` and
  `XAGUSD.DWX`.
- Setfile:
  `QM5_20275_gsr-runfade_QM5_20275_XAU_XAG_RUNFADE_D1_D1_backtest.set`.
- Priority: `priority_track=true`.
- Readback state: pending, attempt 0, unclaimed, no verdict.

## Commits Before This Closing Evidence

- `0b4bbeacc` — OWNER mission authorization and exact G0 decision.
- `f81fc18e2` — bounded source packet plus approved/intake cards.
- `c91ce3414` — deterministic EA-ID reservation.
- `7ada03464` — basket magic allocation and resolver.
- `a0422a030` — EA source, EX5, basket manifest, and fixed-risk setfile.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered by this
  mission; the standing factory remains responsible for later claiming.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; T_Live was not changed.
- The portfolio gate and T_Live manifest were not touched.
- No efficacy, certification, neutrality, decorrelation, or portfolio-
  admission result is inferred from enqueue.
