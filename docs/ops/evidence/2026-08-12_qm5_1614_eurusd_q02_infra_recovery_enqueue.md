# QM5_1614 EURUSD Q02 infrastructure-recovery enqueue

- Date: 2026-08-12
- Branch: `agents/board-advisor`
- Farm task: `fb5c1bc6-1aa4-4a5e-8b1b-595757c4b51d`
- EA: `QM5_1614_aa-dsp-fbank-turn`
- Instrument / timeframe: `EURUSD.DWX` / `D1`

## Outcome

The diverse FX candidate was repaired under the current strict compiler and re-entered through the supported append-only Q02 path. New work item `9ce2ad69-178a-4108-bb2a-d67faabd2926` was created from preserved Q02 PASS row `cb8347ae-acf8-42fd-9a9b-ccbec530a98b`. On the first readback it was `active` on T9 with the refreshed EX5 staged and hash-verified. No new strategy or certification verdict is claimed here.

Direct Q03 re-enqueue was intentionally not used: the current MQ5 and setfile identities no longer matched the historical Q02 evidence. The Q02 stale-PASS rerun route keeps the old result immutable and forces the refreshed execution identity back through the funnel in order.

## Selection and collision control

At claim time, the approved diversity-build backlog contained no eligible unbuilt low-frequency card with both registered DWX instruments and reputable-source support. In particular, the FX carry candidate was already built and queued, the available rates cards lacked registered history, an M5 Tier-C candidate did not meet this fleet brief, and another diverse candidate was already assigned to a different agent. The work therefore moved to mission priority 2.

`QM5_1614` was the deepest unclaimed diverse-instrument recovery candidate:

- structural six-band DSP turning-point rules on D1;
- approved source: Henry Stern, "Trend-Following Filters - Part 3," Alpha Architect, 2021-04-08, <https://alphaarchitect.com/trend-following-filters-part-3/>;
- `G0: APPROVED`, with R1-R4 PASS in `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1614_aa-dsp-fbank-turn.md`;
- EURUSD Q02 had passed and the sibling GBPUSD Q03 row had passed on the same historical binary;
- no open EURUSD Q02 row existed immediately before enqueue.

The farm claim was recorded as agent task `fb5c1bc6-1aa4-4a5e-8b1b-595757c4b51d`, assigned to `codex:agents/board-advisor`. Database safeguards:

- pre-claim backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1614_q03_claim_20260812T202532Z.sqlite` (`quick_check=ok`);
- pre-enqueue backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1614_eurusd_q02_enqueue_20260812T203616Z.sqlite`, 380,481,536 bytes (`quick_check=ok`);
- preserved predecessor canonical row SHA-256 before and after enqueue: `19a5f3522dfebac914e1f9d5d2984da0374c93bda8112d8cc158fb0984ce7009`.

## Infrastructure diagnosis

The latest EURUSD Q03 row was `be3feaaf-1e3e-4d76-b90f-feff88bdf487`, terminal verdict `INFRA_FAIL`. Its evidence at `D:\QM\reports\work_items\be3feaaf-1e3e-4d76-b90f-feff88bdf487\QM5_1614\20260724_114721\summary.json` records:

- `NO_HISTORY` and `INCOMPLETE_RUNS`;
- four of four attempts invalid with `BARS_ZERO`, `EMPTY_EXPERT`, `EMPTY_SYMBOL`, `M0_1970_PERIOD`, `NO_HISTORY_LOG`, and `HISTORY_CONTEXT_INVALID` markers;
- `oninit_failure_detected=false`;
- MQ5, EX5, and setfile identities stable during the run;
- prior failure context `shared_bases_history_lock_storm`.

The OWNER-approved Custom-history isolation path was subsequently enabled for T1-T10 on 2026-08-09 (`activation_sha256=61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`) and ramped to all ten terminals on 2026-08-10. This makes an append-only recovery attempt materially different from the July failure without changing strategy mechanics.

## Artifact repair and gates

The only MQ5 logic-area edit removes `ArraySetAsSeries` from a statically allocated one-element `CopyClose` buffer. That call was a no-op and produced the sole current-framework strict warning. EA property version `5.0` was advanced to `5.1` to create an explicit refreshed executable identity; signal, sizing, and exit rules were not changed. The build gate refreshed the build-hash header in all registered backtest setfiles.

- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log: `framework/build/compile/20260812_203419/QM5_1614_aa-dsp-fbank-turn.compile.log`.
- Compile-log SHA-256: `8cf24f56079bd8d684b9f2362414ffc6dea8b8289bef88b5a1f11586f9dc5fe7`.
- Spec validation: PASS, 1/1.
- Framework build check: PASS, 0 failures, 0 warnings.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260812_203513.json`.
- Build-check report SHA-256: `5a43207428779b5d5ebe81ebe20c5e94ef958157c9a3491fbd2a13cbc378379b`.
- Current MQ5 SHA-256: `88679db69da8907fa2a29f569b27e67562d3b62a3c504c09ee764df3649eb41f`.
- Current EX5 SHA-256: `0b567d0b1da0a84ca63f0cad67cd2188e53a779150a1f6551f1155bfb8a2a091`.
- Current EURUSD setfile SHA-256: `56851a43a111939f6ad541c838e923df4562ba74d36d91ba3880bf83d642d282`.
- Backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`; registered magic slot remains 6 (`16140006`).

## Append-only receipt

Immediately before enqueue, `farmctl mt5-slots` reported one active factory terminal (T5) against the seven-terminal ceiling. The enqueue created exactly one row and skipped none:

- new work item: `9ce2ad69-178a-4108-bb2a-d67faabd2926`;
- phase: Q02;
- symbol / period: `EURUSD.DWX` / `D1`;
- append-only predecessor: `cb8347ae-acf8-42fd-9a9b-ccbec530a98b` (`done/PASS`);
- payload flags: `append_only_rerun=true`, `stale_pass_rerun=true`, `historical_work_item_preserved=true`;
- bound MQ5 / EX5 / setfile hashes match those listed above;
- first post-enqueue readback: `active`, claimed by T9 at 2026-08-12T20:37:03Z, EX5 dispatch verified at 2026-08-12T20:37:05Z.

No local/manual Strategy Tester run was launched. T_Live, AutoTrading, the portfolio gate, and the live manifest were not modified.
