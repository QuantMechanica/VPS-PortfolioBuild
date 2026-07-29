# QM5_20182 WTI Summer Positive-Trend Counterfade — Q01 PASS / Q02 Enqueued

Date: 2026-07-29 (Europe/Berlin)

Branch: `agents/board-advisor`

Build commit: `ca57932a7ad78b61487abeaa6818c7e6a2b70a3c`

## Outcome

`QM5_20182_wti-sum-bull` is a new, low-frequency structural WTI candidate.
On the first tradable D1 bar of each broker week from July through November,
it may open one `XTIUSD.DWX` short only when the completed 252-D1 WTI log
return is strictly positive. It attaches a frozen `3.0 * ATR(20)` hard stop,
uses the framework Friday close at broker hour 21, and consumes the week before
fallible gates so a flat or rejected decision cannot retry.

The card, deterministic identities, source packet, EA, binary, spec, and one
locked `RISK_FIXED` backtest setfile were committed. Q01 passed. The canonical
build-result contract then enqueued exactly one pending Q02 work item. The
farm's authoritative `FACTORY_OFF.flag` remains in place, so no tester was
dispatched.

This is a research build, not a certification, portfolio admission, or
decorrelation result.

## Source and claim boundary

The composite packet uses two already-governed, completely reviewed,
peer-reviewed lineages:

- Ewald, Haugom, Lien, Stordal, and Wu (2022), *Energy Economics* 115,
  supplies the July-to-December WTI trading-time short direction.
- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), supplies a transparent completed 12-month own-return state.

The positive-state counterfade conjunction, continuous Darwinex CFD carrier,
weekly fixed-risk packaging, ATR stop, and QM portfolio behavior are explicit
QM hypotheses. Neither source is represented as having tested those choices.

## Non-duplicate boundary

Before allocation, the deterministic dedup check scanned 4,239 EA-registry
rows and 375 cards and returned `CLEAN` for strategy ID
`EWALD-MOP-WTI-SUMBULL-2026_S01` and mechanic
`July-November weekly WTI short only when completed 252-D1 return is positive`.

Manual semantic resolution established these boundaries:

- `QM5_20141_wti-sumtrend` is the closest sibling but requires the mutually
  exclusive negative 252-D1 state.
- `QM5_13107_wti-weekly-season` and `QM5_20093_wti-summer-short` are
  unconditional seasonal shorts.
- `QM5_12603_tsmom12m` is year-round symmetric trend following and would buy,
  rather than short, in this candidate's positive state.
- `QM5_20136_wti-caltrend` uses an adaptive same-calendar estimator and a
  completed 63-D1 trend.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The candidate supplies direct crude-oil exposure absent from the stated
XAU/SP500/NDX/XNG book. Realized return correlation remains a downstream gate;
no correlation waiver or diversification claim is made here.

## Frozen baseline

- Host/timeframe/slot: `XTIUSD.DWX`, D1, slot 0
- EA/magic: `20182` / `201820000`
- Decision clock: first tradable D1 bar of each Monday-anchored broker week
- Entry window: July through November inclusive
- State: `ln(Close[1] / Close[253]) > 0`
- Direction: one SELL; non-positive or invalid state stays flat
- Stop: frozen `3.0 * ATR(20)` above entry; no target or trailing
- Lifecycle: framework Friday close at hour 21; seven-calendar-day stale guard
- Entry spread ceiling: 1,500 points
- Attempt state: persistent consumed week before history/signal/spread/quote/
  news/stop/order gates
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- News axes: OFF

No optimization or alternative parameter set was created.

## Deterministic identities and hashes

- EA registry: `20182,wti-sum-bull,EWALD-MOP-WTI-SUMBULL-2026_S01`
- Magic registry: `20182,wti-sum-bull,0,XTIUSD.DWX,201820000`
- Card SHA-256:
  `8CED1633A6252CEE2AA4DFC79CCBCB099F840530BEA79BCAD6DE9A9AD26AB521`
- Source packet SHA-256:
  `3B03C4A8C86E9D6B0E117753BFB709F0C1F31C8A77337B3BA1673FE80ED6555A`
- MQ5 SHA-256:
  `8A3D70F6C9A349CA5D2A8B9A2EE3DD0EFABC15B11CD5153104728E9332F6A9ED`
- EX5 SHA-256:
  `E339DB4921CB9150B25271623CD149E4370759D174C4F79D625D7F6A4AE4529F`
- SPEC SHA-256:
  `43A49DC016F6D111EADCC8E4709A21F6BAE3AC01529CB80F779E9D567943575C`
- Setfile SHA-256:
  `BD95668EEE4D28B9D7F28BFB0B99D3DED1B48BA932208C5E920BDB195F898D07`
- Setfile build hash:
  `6add4b71fa6694a9dac916983450f127c7c02999677569e629e32f94ae692eca`
- EA-ID registry SHA-256:
  `5C7A0B465A3D0A24B6E5F6E708EACAC1E95C53B6BE4C15DA651AA1519D5BC0FB`
- Magic registry SHA-256:
  `40A6A6B19070D3EE66C990CC53456D593967208A1CEEF57C53E7A00277222F56`
- Generated resolver SHA-256:
  `E6E139D299339B59A35BD1FD4F6C6A69306F89BD506E79D1F92985003595A189`

The EA directory existed before the magic allocation, the resolver was
regenerated from the canonical registry, and magic `201820000` was verified in
the generated resolver. The repository-wide registry validator still reports
unrelated legacy malformed rows; the target row, collision check, resolver,
and strict EA build gates passed.

## Validation evidence

- Strategy-card schema lint: PASS; no missing sections and no ML hits.
- G0 card lint: PASS.
- Candidate build guard: PASS; registry, magic, EA directory, and slug agree.
- Seven-section SPEC validation: PASS.
- Strict V5 build check: PASS, 0 failures, 0 warnings.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260729_082958/QM5_20182_wti-sum-bull.compile.log`
- Compile summary:
  `D:/QM/reports/compile/20260729_082958/summary.csv`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260729_082958.json`

No smoke test, manual tester, or pipeline phase was run by this agent. Q02 is
pending for the paced fleet.

## Paced Q02 handoff

Immediately before enqueue at `2026-07-29T08:33:05Z`, the read-only MT5 slot
scan reported zero running factory terminals, zero terminal workers, and zero
reservations. It observed only the separate pre-existing `T_Live` terminal;
that process was not accessed or changed.

An initial targeted sweep command was:

`python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20182 --queue-ceiling 10000`

It returned:

`{"skipped":"FACTORY_OFF.flag set","flag":"D:\\QM\\strategy_farm\\state\\FACTORY_OFF.flag"}`

That sweep correctly refused to operate while the factory-off interlock was
set. The supported build-record handoff remains available under the interlock
because it writes a pending row without dispatching MT5. The repository card
was copied byte-for-byte to the farm's approved-card directory, then:

- Pre-build-task DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_20182_build_task_20260729T083700Z.sqlite`
- Build task: `3c6339bd-59c7-479f-891f-085483113394`, status `done`
- Build-result contract:
  `D:/QM/strategy_farm/artifacts/builds/3c6339bd-59c7-479f-891f-085483113394.json`
- Build-result SHA-256:
  `F7086596FCD8F66F470AD737562A3641B5CC86177D7787E5DC812F98BAF6C200`
- Pre-record DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_20182_record_build_q02_20260729T083757Z.sqlite`
- Auto-enqueue result: one enqueued, zero skipped
- Q02 work item: `60181936-0403-49bc-b221-dda4f35eb584`
- State: `pending`, unclaimed, attempt 0
- Symbol/timeframe: `XTIUSD.DWX` / D1
- Created: `2026-07-29T08:37:57+00:00`

The final work-item postcheck returned exactly one row and
`Q02_pending: 1`. A second MT5 slot scan at `2026-07-29T08:38:07Z` still
reported zero factory terminals and only the separate pre-existing `T_Live`
process. The current execution hold is the factory-off safety interlock, not
observed tester CPU saturation. No dispatch command was issued.

AutoTrading, the portfolio gate, the T_Live manifest, all T_Live files, and
live setfiles were not touched.
