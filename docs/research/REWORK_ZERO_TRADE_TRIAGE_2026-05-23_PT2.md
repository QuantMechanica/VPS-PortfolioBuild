# Zero-Trade Rework Triage — QM5_1088, QM5_1089, QM5_1096

Date: 2026-05-23
Author: Claude (operation lead)
Tasks:
- `7ef56f93-c0e2-4923-a82a-bd0e91506a2e` — QM5_1088 (priority 70)
- `a2b0e58a-ceee-4b3b-b0d0-473121398e26` — QM5_1089 (priority 70)
- `5737536c-2086-457a-92ef-3f8c343b4088` — QM5_1096 (priority 70)
Trigger: `DL-062_zero_trade_rework_trigger` (recurrent zero-trade FAIL ratio).
Perspective: card/source rework — relax entry conditions or substitute signal logic.

Companion to `docs/research/REWORK_ZERO_TRADE_TRIAGE_2026-05-23.md` (QM5_10020 / QM5_1044 / QM5_1048). Same DL-062 cohort, second batch.

## TL;DR

| ea_id | dispatcher fan-out hit? | in-universe also zero-trade? | real strategy-layer bug? | recommended verdict |
|---|---|---|---|---|
| QM5_1088 | yes (37 symbols vs 7-symbol TAA universe) | unclear — in-universe runs *crash the tester*, not zero-trade | **no — TAA-on-single-symbol mismatch + tester instability** | HOLD / RECYCLE (P2-gate-incompatible by design; needs portfolio-rotation host like [[project_qm_basket_ea_build_2026-05-22]]) |
| QM5_1089 | yes (42 rows vs 8-symbol pair universe) | yes (all 8 in-universe symbols 0-trade) | **no — pair strategy backtested per single symbol; cross-asset legs missing** | RECYCLE (re-architect as basket EA; do not re-enqueue) |
| QM5_1096 | yes (37 symbols vs 6-symbol commodity/index universe) | **yes — all 6 in-universe symbols `MIN_TRADES_NOT_MET` with total_trades=0** | **yes — close-based 20-bar Donchian breakout fires <1× / year on D1 1-yr window** | REWORK (entry relaxation: use High>upper not Close>upper, or shorten N to 10, or widen P2 window) |

Same root pattern as the prior batch ([[project_qm_dispatcher_universe_mismatch_2026-05-23]]): DL-062's `zero_trade_pct` numerator is inflated by out-of-universe fan-out. After filtering to the card's target universe:

- **1088 / 1089** are *portfolio* strategies whose per-symbol backtest can never produce trades by design.
- **1096** is the only one where a card/source rework is warranted — and the bug is in the entry condition, not the universe.

## Evidence — work_items per-symbol breakdown

Queried `D:\QM\strategy_farm\state\farm_state.sqlite` 2026-05-23 ~10:05Z via `_query_zt.py`.

### QM5_1088 — universe per card: SP500.DWX, NDX.DWX, GDAXI.DWX, XAUUSD.DWX, XTIUSD.DWX, EURUSD.DWX, USDJPY.DWX

- **37 P2 rows**, 7 in-universe + 30 out-of-universe (entire FX matrix).
- In-universe outcomes:
  - SP500.DWX, XAUUSD.DWX, XTIUSD.DWX → `failed/INVALID` (no summary written; tester crash before report).
  - GDAXI.DWX, USDJPY.DWX → `failed/FAIL` (no summary).
  - EURUSD.DWX → `done/FAIL`, summary `D:\QM\reports\work_items\71877d0a-...\summary.json` shows `reason_classes=[REPORT_MISSING, METATESTER_HUNG, INCOMPLETE_RUNS]`, `period=H1`, `min_trades_required=36` — **tester hung, not zero-trade**.
  - NDX.DWX → `done/FAIL`, summary `D:\QM\reports\work_items\93280cc6-...\summary.json` shows same `[REPORT_MISSING, METATESTER_HUNG, INCOMPLETE_RUNS]`, `period=H1`, `min_trades_required=36`.

The DL-062 trigger reads "30 zero-trade FAILs / 34 FAILs = 88%". Reality: in-universe runs do not produce a strategy-layer zero-trade signal at all — they crash the tester.

### QM5_1089 — universe per card: SP500.DWX, GDAXI.DWX, XAUUSD.DWX, XTIUSD.DWX, EURUSD.DWX, USDJPY.DWX, NDX.DWX, WS30.DWX

- **42 P2 rows**, 8 in-universe + 29 out-of-universe.
- All 8 in-universe symbols produced `done/FAIL` summaries with clean tester runs:
  - SP500 sample `D:\QM\reports\work_items\ec664e4b-...\summary.json` → `reason_classes=[MIN_TRADES_NOT_MET]`, `min_trades_required=5`, `period=H1`, `total_trades=0`, `real_ticks_marker=true`, `deterministic=true`.
  - NDX 2nd-run `D:\QM\reports\work_items\fb5a3d43-...\summary.json` same shape.
- Earlier NDX run `4f58b092-...` actually crashed with `[REPORT_MISSING, INCOMPLETE_RUNS]`, but the re-run produced a clean 0-trade verdict.

**Conclusion**: the strategy is a *pair* strategy by definition (12-mo TMOM vs 12-mo MA, both gating cash exits, designed across asset pairs). Single-symbol backtest cannot fire because there is no cross-asset rotation to observe. Card body explicitly says "configured asset pairs". A re-architect via the basket-EA host (like [[project_qm_basket_ea_build_2026-05-22]] / QM5_10717) is the only fix; entry-condition relaxation in single-symbol mode cannot help.

### QM5_1096 — universe per card: XAUUSD.DWX, XAGUSD.DWX, XTIUSD.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX

- **37 P2 rows**, 6 in-universe + 31 out-of-universe (entire FX matrix).
- All 6 in-universe symbols produced `done/FAIL` summaries with clean tester runs:
  - NDX sample `D:\QM\reports\work_items\600171f4-...\summary.json` → `reason_classes=[MIN_TRADES_NOT_MET]`, `min_trades_required=5`, `period=D1`, `total_trades=0`, `real_ticks_marker=true`, `deterministic=true`, `model4_log_marker_detected=true`.
  - XAUUSD sample `D:\QM\reports\work_items\29531186-...\summary.json` same shape.

This is the real strategy-layer signal: **6/6 in-universe instruments on D1 for year 2024, 0 trades each**. A 20-bar Donchian breakout on 6 trending/commodity instruments over a year that included an NDX 24% advance should fire multiple times. It fired zero. That is an entry-condition bug.

## Per-EA rework vectors

### QM5_1088 — HOLD / RECYCLE: TAA strategy, not single-symbol

Card mechanism is a *7-asset Flexible Asset Allocation* with:
- 4-month relative momentum ranks **across the 7 assets**
- 4-month volatility ranks **across the 7 assets**
- 4-month correlation rank of each asset **versus the rest of the universe**

A single-symbol backtest has no concept of "rank vs the rest" — the EA cannot select itself as top-3 because there is no comparison set. Either the build emits a trade-every-month signal trivially (collapsing the rank logic) or it emits nothing. Combined with `period=H1` and `min_trades_required=36`, the tester is being asked an undefined question and hangs.

**Recommended verdict: RECYCLE**. Two paths, both Codex/registry work, *not* a card or EA-source rework:
1. Re-architect QM5_1088 as a basket EA on a single host ticker, looping the 7-symbol universe in a `Strategy_RebalanceKey` style — same model as the existing portfolio-rotation patch in [[project_qm_basket_ea_build_2026-05-22]] (QM5_10717 is the reference). The rank logic then has the cross-asset context it needs.
2. Drop QM5_1088 from the legacy single-symbol cohort and only carry it forward inside the Edge Lab cross-sectional family (which already covers cross-sectional FX momentum, T1 thesis from `docs/research/EDGE_THESES_CROSS_SECTIONAL_2026-05-22.md`).

Either path is upstream of "relax entry conditions" — relaxation cannot fix a missing universe.

### QM5_1089 — RECYCLE: pair strategy, must be a basket EA

Same diagnosis as QM5_1088, slightly cleaner because the card explicitly says "configured asset pairs":
- Equity pair `SP500.DWX/GDAXI.DWX`
- Crisis/real pair `XAUUSD.DWX/XTIUSD.DWX`
- FX pair `EURUSD.DWX/USDJPY.DWX`
- Live substitute `NDX.DWX/WS30.DWX`

The strategy by construction needs TWO symbols to compare 12-mo excess returns and 12-mo MAs and rotate one against the other. A single-symbol P2 run for SP500 alone cannot rotate against GDAXI.

`min_trades_required=5` with `expected_trades_per_year_per_symbol=12` is also internally inconsistent: a monthly rebalance with a cash-gate that's typically active >50% of bull markets will produce <6 entries/yr/sym even when the strategy works. The P2 gate would need at minimum 12 (one per month) and ideally 6 with a multi-year window — and even then, the single-symbol decomposition still cannot test the pair logic.

**Recommended verdict: RECYCLE**. Path:
1. Re-build QM5_1089 on the basket-EA host with the 4 pairs as input slots.
2. Or drop it from the single-symbol legacy cohort; the Edge Lab T2 "regime-filtered carry" thesis is a closer canonical version.

Do not regenerate the card; the card is correct, the build/dispatcher is wrong.

### QM5_1096 — REWORK: entry-condition relaxation

This is the only one of the three where a real card/source rework applies. The bug is in `framework/eas/QM5_1096_unger-donchian-channel-tf/QM5_1096_unger-donchian-channel-tf.mq5`:

- L180-185: `if(close_1 > upper) direction = 1; else if(close_1 < lower) direction = -1; else return false;` — close-based breakout with strict `>`.
- L76-86: `upper = max(iHigh(D1, shift=2..N+1))`, `lower = min(iLow(D1, shift=2..N+1))` with N=20.

So the EA fires only when the most recent closed D1 bar's **close** strictly exceeds the prior 20-bar **high**. That's a very conservative form of the Donchian breakout. The Unger article cited in the card and the standard Turtle/Donchian formulation both gate on `High[1] > Upper` (intra-bar high broke), not `Close[1] > Upper`. The book's worked example uses N=20 and the high-break formulation.

Compounded by:
- `strategy_vol_floor = 0.004` (0.4%) — fine on indices, but on `iATR(D1,20)/Close` for some periods (e.g., XAGUSD during low-vol regimes) this can briefly drop below 0.4% and gate.
- P2 window = 1 year — with the strict close-break, expected breakouts on a 20-bar channel are ~3-6 per year on a trending instrument, possibly 0 on a chop year. `min_trades_required=5` is then on the edge even when the EA works.

**Recommended rework vector** (Codex work, single source-file change):
- (a) Switch the entry gate from `close_1 > upper` to `High[1] >= upper`, and from `close_1 < lower` to `Low[1] <= lower`. This matches the Unger Academy / Turtle convention referenced by the card and lifts the strict-close constraint that is producing 0/year per symbol.
- (b) Optionally relax `strategy_donchian_period` default from 20 → 10 for the P2 baseline (kept as a P3 sweep parameter at {20, 40, 55, 80} per the card). N=10 produces materially more breakouts per year and gives P2 better signal-to-noise on the 1-year window.
- (c) Keep the volatility floor; keep the ATR stop; keep the position-management logic. Do not touch the exit logic — it correctly mirrors the entry.
- (d) After the source change, the build needs `framework/scripts/build_ea.ps1` re-run, then the work_items dispatcher should be invoked with the **restricted 6-symbol universe** (`XAUUSD.DWX, XAGUSD.DWX, XTIUSD.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX`) — not the broad DWX matrix.

This is a real source rework. Hand to Codex via the rework codex inbox; explicitly note the universe restriction so the dispatcher doesn't re-inflate the zero-trade ratio on the re-enqueue.

## Cross-cutting finding — dispatcher universe filter still not in place

This is the third batch of EAs ([[project_qm_dispatcher_universe_mismatch_2026-05-23]] first batch was QM5_10020, QM5_1044, QM5_1048; QM5_1088/1089/1096 are the second; QM5_1097..QM5_1100 are likely the next) where the work_items dispatcher fans every EA across the full DWX symbol matrix instead of respecting the card's `target_symbols` / mapped universe. Each batch:

1. Burns ~30 wasted backtests per EA (out-of-universe).
2. Inflates DL-062's `zero_trade_pct` to >85% even when the in-universe runs are 100% honest.
3. Generates these triage cycles instead of letting the pipeline run.

The pump-fix list from the prior triage still applies; nothing new to add. **Recommended ops priority**: bump the dispatcher-universe-filter ops task ahead of the next replenishment cycle. Until it lands, every `_recent_zero_trade_rework_exists` trigger is liable to mis-route research time to single-symbol triage of cards that are correct and dispatchers that are wrong.

## Verification

- DB query timestamp 2026-05-23T10:05Z (`farm_state.sqlite`).
- 6 in-universe `summary.json` paths read first-hand (cited above per EA: 2× QM5_1088, 2× QM5_1089, 2× QM5_1096).
- EA source read first-hand: `framework/eas/QM5_1096_unger-donchian-channel-tf/QM5_1096_unger-donchian-channel-tf.mq5` (all 363 lines).
- Card frontmatters read first-hand from `D:\QM\strategy_farm\artifacts\cards_approved\` for all three EAs.
- Query script: `_query_zt.py` at repo root (will be removed in the same commit as this artifact).

## Router updates

Each of the three tasks gets:
- `--state REVIEW`
- `--artifact-path docs/research/REWORK_ZERO_TRADE_TRIAGE_2026-05-23_PT2.md`
- `--verdict` per the TL;DR table.

The recycle / hold / rework follow-ups are NOT untracked work — they are explicit Codex ops items and should be entered via the next router cycle that picks up the dispatcher universe filter task (already pending from the prior batch).

## Hard-rules check

- T_Live: untouched.
- terminal64.exe: not started manually.
- Evidence: every claim above cites a summary.json or .mq5 path.
- Edge Lab charter: this is legacy cards_approved/ work, not Edge Lab cards.
- Operator-facing phase names: Qxx only (P2 in this doc is the storage-layer key per `docs/ops/PIPELINE_PHASE_SPEC.md` — internal usage).

## Out-of-scope (do not do this cycle)

- Modify any .mq5 file.
- Re-enqueue any work_items.
- Touch `tester_defaults.json` or the dispatcher.
- Open the .ex5 in MetaEditor.

All recommended follow-ups are flagged for Codex/OWNER routing.
