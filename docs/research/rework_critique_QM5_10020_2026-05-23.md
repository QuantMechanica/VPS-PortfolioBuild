---
ea_id: QM5_10020
slug: rw-spx-overnight
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: 61bd7b8c-cbc4-4914-8135-e954c2440b6b
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_10020_rw-spx-overnight.md
author: claude
written_at: 2026-05-23
verdict: REWORK_FALSE_POSITIVE_REENQUEUE_AFTER_SCOPE_AND_TIMEFRAME_FIX
---

# QM5_10020 rw-spx-overnight — zero-trade rework critique

Router classified this EA as zero-trade-dead after 20/40 fails with `zero_trade_pct=1.0`. After reading the card and the per-run evidence, the dominant failure mode is **not strategy mortality** — it is a chain of upstream P2-enqueue and build configuration mismatches.

## 1. Evidence sample (work_items, latest first)

| run                | symbol     | phase | period | result | reason                              |
|--------------------|------------|-------|--------|--------|-------------------------------------|
| 2026-05-21 17:13Z  | NDX.DWX    | P3    | H1     | FAIL   | run_smoke_fail:ONINIT_FAILED        |
| 2026-05-21 16:57Z  | GDAXI.DWX  | P3    | H1     | FAIL   | run_smoke_fail:ONINIT_FAILED        |
| 2026-05-21 16:57Z  | SP500.DWX  | P3    | H1     | FAIL   | MIN_TRADES_NOT_MET, 0 trades, year=2024 |
| 2026-05-21 16:12Z  | NDX.DWX    | P2    | H1     | FAIL   | MIN_TRADES_NOT_MET                  |
| 2026-05-20 03:30+  | USDJPY/GBPJPY/GBPCHF/GBPNZD/EURNZD/NZDJPY/EURCAD/CHFJPY/XAUUSD/WS30 | P2 | — | FAIL | MIN_TRADES_NOT_MET (14×) |

Aggregate FAIL histogram: `MIN_TRADES_NOT_MET=14`, `INVALID_REPORT;INCOMPLETE_RUNS=4`, `ONINIT_FAILED;INCOMPLETE_RUNS=2`.

## 2. Three independent root causes — none of them is "the edge is dead"

### 2a. P2 enqueue ran the EA on FX / metals / non-index symbols

Card `target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]`. The strategy is a US-equity-index overnight-premium effect — close-to-open of the cash session, gated by a 20-day rolling overnight-minus-intraday filter. On USDJPY / GBPJPY / GBPCHF / GBPNZD / EURNZD / NZDJPY / EURCAD / CHFJPY / XAUUSD / WS30 the session/close-to-open mechanic does not apply, so 0 trades is the **correct** signal output — not a failed test of the strategy. 14 of the 20 zero-trade FAILs sit on symbols the card never authorized.

This is a P2-enqueue scope bug, not an EA bug.

### 2b. SP500.DWX itself was tested on **H1**, not the card-specified **D1**

`summary.json` for the canonical 2026-05-21 SP500.DWX run shows `"period": "H1"`, `"year": 2024`, `min_trades_required=30`. Card front-matter says `period: D1`, and the entire entry/exit mechanic is daily-session-close to next-session-open. Running it on H1 over a single year with `min_trades_required=30` is structurally incompatible with the rule: at most ~250 sessions/yr = ~250 candidate entries, gated by the 20-day positive-overnight filter (~50% pass-through historically) and by spread/Friday-skip → expected ~100 trades on a clean year, but the H1 build is likely mis-resolving "session close" against a candle granularity that never coincides with the broker's 22:00/23:00 NY-cash-close bar.

Effect: zero entries fired even on the one symbol the strategy was actually designed for. **This is a build-side timeframe mismatch, not an edge failure.**

### 2c. NDX/GDAXI P3 reruns ONINIT_FAILED

The two P3 entries dated 2026-05-21 are `ONINIT_FAILED;INCOMPLETE_RUNS` — a build/init regression independent of trade counts. Cannot be diagnosed as zero-trade.

## 3. Why the DL-062 trigger fired

The classifier (`_is_zero_trade_failure_payload` in `tools/strategy_farm/farmctl.py:3998`) correctly excludes `NO_HISTORY/INVALID_REPORT`, but counts every MIN_TRADES_NOT_MET fail as a zero-trade failure regardless of whether the symbol was inside the card's authorized universe. For wide-DWX-basket enqueue against a strategy with an explicit 3-symbol target list, this guarantees ~85% spurious zero-trade attribution. **The DL-062 trigger here is a false positive driven by enqueue scope, not strategy degeneracy.**

## 4. Recommended change vector

Reject the router's hint to relax entry conditions / substitute signal logic. The card is internally coherent and faithfully implements the Robot Wealth source. Required actions, in order:

1. **Ops (codex)**: fix P2/P3 enqueue to honor `target_symbols` from the card front-matter. Confirm that the basket loader does not auto-expand to the full DWX universe for strategies that declare an explicit target list. This is the same enqueue-scope pattern the basket cards run on; it must not silently override.
2. **Build (codex)**: verify the compiled EA / set file uses `period=D1` end-to-end. If H1 is being injected by `framework/scripts/gen_setfile.ps1` or by a P3 sweep template, override for this strategy.
3. **Broker-time alignment (claude/codex)**: explicitly document and test whether the EA's "session close" maps to the DXZ NY-Close broker time (GMT+2 outside US DST, GMT+3 during, per memory `project_qm_broker_time`). The 16:00 NY → 22:00 / 23:00 broker-time bar is the only one the entry rule can use.
4. **Re-enqueue**: P2 baseline on SP500.DWX + NDX.DWX + WS30.DWX only, D1, multi-year (≥5y, since paper claims ~180 trades/yr/symbol → need broader window for filter-warmup + sample).
5. **Edge Lab compliance check**: this card predates the 2026-05-22 Edge Lab charter; before any further pipeline time, confirm the news-blackout filter (FOMC/CPI per card) and DD constraints (FTMO 10% total, 5% daily) survive on the indices. Card already declares FOMC/CPI skip until P8 — that aligns; verify implementation.
6. **Do NOT mark DEAD**. Do NOT relax the 20-day rolling overnight-minus-intraday filter — relaxing it is the kind of in-sample tuning the pipeline exists to prevent.

## 5. Falsification — when this critique becomes wrong

If after steps 1–4 the EA still produces 0 trades on SP500.DWX + NDX.DWX + WS30.DWX on a clean ≥5y D1 backtest with the unaltered card rules, then the critique is wrong and the edge has either (a) decayed post-2020 / been arbed out, or (b) the broker-time mapping is so misaligned with NYSE cash hours on DXZ that the close-to-open mechanic is structurally untradable on this feed. Either outcome is a legitimate kill verdict, but the current evidence does not yet support it.

## 6. Verification I ran

- `tools/strategy_farm/farmctl.py:3998` — read classifier logic
- Latest 15 work_items rows + full FAIL histogram via direct sqlite query against `D:\QM\strategy_farm\state\farm_state.sqlite`
- `D:\QM\reports\work_items\1707dc2a-…\summary.json` — confirmed period=H1, year=2024, 0 trades both deterministic runs
- Card front-matter at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10020_rw-spx-overnight.md` — confirmed target_symbols + period=D1
