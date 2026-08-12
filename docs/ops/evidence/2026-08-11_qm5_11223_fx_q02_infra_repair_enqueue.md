# QM5_11223 FX Q02 infrastructure repair and enqueue

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Farm repair claim: `634226be-7f93-42dd-a75c-3b8da40992e8`

## Outcome

`QM5_11223_ft-simple` was refreshed against the current V5 framework,
strictly rebuilt, and queued as one append-only GBPUSD Q02 canary. The new work
item is `4ceff07f-cebb-45ca-80c6-a9ae10858cdc`.

Immediate readback found the canary `pending`, attempt 0, unclaimed, and without
a verdict. This is an infrastructure-recovery handoff, not a performance,
certification, correlation, or portfolio-admission result.

## Selection and non-duplication

No clean approved build task satisfied the mission's low-frequency diversity
constraints. The sole fresh pending build was a roughly 400-trades/year M5
indicator stack; the other nominal build tasks carried missing-data/card
blockers or prior strategy/Q04 outcomes. Priority 2 was therefore selected.

`QM5_11223` was the highest-diversity unclaimed infrastructure-only candidate:

- approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11223_ft-simple.md`;
- reproducible single-source lineage to Gert Wohlgemuth's `Simple.py` at
  freqtrade-strategies commit
  `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`;
- fixed mechanical MACD/RSI/Bollinger expansion rules, no ML, adaptive fit,
  grid, or martingale;
- expected frequency 60 trades/year/symbol and a basket of three FX majors
  plus gold (`EURUSD`, `GBPUSD`, `USDJPY`, `XAUUSD`);
- every recorded Q02 verdict was `INFRA_FAIL`, with no economic or later-phase
  verdict for any host;
- no pending/active EA work item and no previous or competing repair claim at
  the transactional claim checkpoint.

The repair was bounded to one GBPUSD canary. The other three historical rows
remain terminal and were not re-enqueued.

## Diagnosis

The append-only predecessor
`11076597-bb17-47dc-98f5-5bb593757cee` is a real-MT5 Q02 run on GBPUSD M5. Its
summary is:

`D:\QM\reports\work_items\11076597-bb17-47dc-98f5-5bb593757cee\QM5_11223\20260727_235632\summary.json`

It ended `done / INFRA_FAIL` with `ONINIT_FAILED;INCOMPLETE_RUNS`, zero bars,
and no strategy verdict. The evidence binds the historical artifacts exactly:

- MQ5 SHA-256:
  `f247cf1cec69d82e764d80ee812c17f3510f91ecd56f5e1b3b15470242cb4ea3`;
- EX5 SHA-256:
  `f03fadfef116bb86978a2736de409b0b95fe9ea7bbf37bbd8d00bd61a2483de5`;
- GBPUSD setfile SHA-256:
  `32aab2f0edc09ed9a147dffc51e4acb0c22fd1d44b0f6c63877642c707bd1217`.

The old preset predated the current V5 input contract: it omitted the explicit
EA ID, RNG/news/stress inputs, and every strategy parameter, while carrying
legacy filter assignments no longer declared by this EA. The EA source also
predated the canonical runtime ordering and left `QM_EntryRequest` memory
uninitialized.

After that contract refresh, the build gate exposed a second deterministic
tester blocker: both quote guards rejected `ask == bid`. Zero modeled spread is
valid on `.DWX` tester data, so the old comparison would suppress every bar
even after initialization succeeded. The terminal journal that could identify
the historical `OnInit` subcode was not retained; the durable diagnosis is
therefore limited to the proven stale binary/preset contract plus this static
zero-trade defect, without inventing a more specific init cause.

## Mechanics-preserving repair

- Added the current V5 MAE lifecycle hook and canonical entry-only news-gate
  ordering so management and exits remain active through news windows.
- Zero-initialized `QM_EntryRequest` before every entry evaluation.
- Changed only invalid-quote handling from `ask <= bid` to `ask < bid`; the
  card's stop-relative maximum-spread guard remains unchanged.
- Regenerated all four presets from the approved card and explicitly bound
  current framework inputs, registered magic slots, `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and the unchanged card defaults.
- Recompiled against the current framework and magic resolver.

No entry threshold, exit threshold, stop multiple, ROI target, symbol, or
timeframe was changed.

## Verification

- Build-skill registry guard: PASS for EA registry row, active magic rows, and
  canonical EA directory.
- SPEC validation: `PASS  QM5_11223_ft-simple` (1/1).
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260811_133958.json`.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260811_133959\QM5_11223_ft-simple.compile.log`.
- Forbidden dependency/API scan: no ML runtime, `WebRequest`, DLL import, raw
  indicator handle, or direct `CopyBuffer` use.
- Repaired MQ5 SHA-256:
  `662645c2ce6afd42c4767264bee451e7c1c31826f2c3fbd353922645ce82f3a2`.
- Repaired EX5 SHA-256:
  `d53c437c0624f428b8eabf2e37ee4889a2296eaef69a5b599e5adc1d8503fb4b`.
- GBPUSD fixed-risk setfile SHA-256:
  `533c23cfced4f9a4f8c47d75af13b7cf07b6cecc79c1e734168937f341f4620a`.

## Q02 receipt

The capacity checkpoint found 6 active farm rows and 5 running T1-T10
terminals, below the ten-terminal ceiling. No terminal was launched or
interrupted manually.

The governed append-only enqueue created exactly one row:

- work item: `4ceff07f-cebb-45ca-80c6-a9ae10858cdc`;
- phase/kind: Q02 / backtest;
- symbol/timeframe: `GBPUSD.DWX` / M5;
- immediate state: pending, attempt 0, unclaimed, no verdict;
- predecessor: `11076597-bb17-47dc-98f5-5bb593757cee`, preserved as
  `done / INFRA_FAIL`;
- payload flags: `append_only_rerun=true`,
  `repaired_infra_rerun=true`, and
  `rerun_source_current_ex5_mismatch_verified=true`;
- risk binding: `risk_fixed=1000.0`, `risk_percent=0.0`;
- exact current MQ5, EX5, and setfile hashes match the verification values
  above.

Farm DB backups:

- before claim:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11223_q02_infra_claim_20260811T133513Z.sqlite`;
- before enqueue:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11223_gbpusd_enqueue_20260811T134126Z.sqlite`.

## Safety boundary

- No manual smoke, backtest, pump, or dispatch tick was run.
- No terminal or worker process was started, stopped, reaped, or altered.
- No Strategy Card, registry allocation, gate threshold, portfolio state, or
  live setfile was changed.
- T_Live, AutoTrading, the portfolio gate, the T_Live manifest, and deploy
  manifests were not touched.
