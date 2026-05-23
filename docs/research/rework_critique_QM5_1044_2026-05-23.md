---
ea_id: QM5_1044
slug: vpmacd-us-indices
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: 18c0fb57-abc5-4acc-af8f-99f9b3cbc841
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_1044_vpmacd-us-indices.md
author: claude
written_at: 2026-05-23
verdict: REWORK_BLOCKED_BY_PERF_REWORK_PREREQUISITE
related_memory: project_qm5_1044_perf_rework_2026-05-16
---

# QM5_1044 vpmacd-us-indices — zero-trade rework critique

Router flagged `zero_trade_fail_count=38 / 39` with `zero_trade_pct=0.97`. After inspecting the work_items evidence, the underlying failure is **not zero-trade** at the trader-decision level — it is a stack of three orthogonal infrastructure problems that the classifier's evidence-file fallback counts as MIN_TRADES_NOT_MET.

## 1. Evidence sample (work_items, latest 15)

The most recent 15 fails are dominated by `NO_HISTORY;INCOMPLETE_RUNS` (24 of 39 fails) and `INVALID_REPORT` variants. Only 2 fails carry a pure `MIN_TRADES_NOT_MET` reason class. Aggregate FAIL histogram:

```
NO_HISTORY;INCOMPLETE_RUNS                          24
INVALID_REPORT;INCOMPLETE_RUNS                       4
INVALID_REPORT;NO_HISTORY;INCOMPLETE_RUNS            5
NO_HISTORY;INVALID_REPORT;INCOMPLETE_RUNS            2
MIN_TRADES_NOT_MET                                   2
MIN_TRADES_NOT_MET;NON_DETERMINISTIC                 1
REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS       1
```

All 15 most-recent rows are dated 2026-05-18T22:26-22:28Z, suggesting a single batch enqueue that hit the M1/M5 history wall on the FX universe and aborted.

## 2. Three orthogonal failures, none of them strategy-level

### 2a. NO_HISTORY domination — wrong universe + intraday history gap

Card targets **SPX500 / NAS100 / US30** (DXZ equity-index CFDs). The 2026-05-18 batch enqueued on the full FX cross-set (USDCHF, NZDCHF, NZDJPY, NZDUSD, USDCAD, NZDCAD, GBPUSD, EURUSD, EURNZD, EURAUD, EURJPY, EURGBP, EURCHF, EURCAD, CHFJPY). Identical pattern to QM5_10020: card target list ignored by enqueue.

Per memory `project_qm_mt5_v5_m1_history_gap_infra_fail`: M1-based EAs stall when 2017-2022 M1 history is absent. The card's VP-adjustment formula explicitly reads intraday M5 bars within each daily session. On a fresh DXZ pull for non-index FX pairs the M5 history depth is shorter than what the VP aggregator needs → `NO_HISTORY`. This is **infrastructure**, not signal.

### 2b. Known per-tick full-EMA performance rework outstanding

Memory `project_qm5_1044_perf_rework_2026-05-16` notes the implementation recomputes EMAs from scratch every tick → unrunnable in MetaTester. Until the EA is rewritten with incremental EMA state, any P2/P3 run risks `METATESTER_HUNG` (already observed once) and timeout-driven INVALID_REPORT (5+4=9 fails). This explains why even the few non-NO_HISTORY runs failed with INVALID_REPORT/INCOMPLETE — the tester was hanging mid-run.

Re-running the EA without fixing the perf path will reproduce the same INVALID_REPORT pattern, regardless of any signal-logic change.

### 2c. Volume series caveat — known pre-build risk from the card

The card flags this explicitly: MT5 `Volume[]` on CFD feeds is tick-volume, not exchange volume. The paper's VP-MACD relies on real-volume weighting. The "edge survives on tick-volume" question is a P3 falsification target — it cannot be evaluated until the EA actually runs without timing out.

## 3. Why DL-062 over-counted to 38/39

The classifier in `tools/strategy_farm/farmctl.py:3998-4037` excludes NO_HISTORY/INVALID_REPORT from the work_items.payload_json check, but its **evidence_path fallback** reads `summary.json` from disk and the older summary files contain `MIN_TRADES_NOT_MET` because total_trades=0 was reported by the tester even when the underlying run was incomplete. So summary.json-based counting picks up an `MIN_TRADES_NOT_MET` flag the structured payload would have excluded.

Net: the 38/39 ratio is the classifier double-counting infra-aborted runs that happen to expose `total_trades=0`. The true zero-trade-with-clean-history count is ≤ 4.

This is a real ops-side false-positive pattern that will keep firing on any infra-broken EA. Worth a Codex follow-up to tighten `_is_zero_trade_failure_payload`'s evidence_path branch — but out of scope for this rework critique.

## 4. Recommended change vector

Reject the router's hint to relax entry / substitute signal. The EA cannot be evaluated yet — there is no clean signal evidence at all. Required actions, in dependency order:

1. **Codex (perf rework — blocker)**: rewrite VP-MACD with incremental EMA state per the existing perf-rework task. This is a prerequisite; no other change matters until this lands.
2. **Codex (enqueue scope)**: same fix as QM5_10020 — basket enqueue must honor `target_symbols`. For QM5_1044 the explicit target list is SPX500 / NAS100 / US30; the card front-matter is sloppy about this (no `target_symbols:` field), so as part of the rework, add the field with those three values.
3. **Codex (intraday history)**: confirm M5 history coverage for SPX500/NAS100/US30 over the P2 window (≥2018 if matching the paper's walk-forward); document evidence under `framework/registry/m5_coverage_*.csv`. Do not silently shorten the window — that's a P2-policy violation per memory `project_qm_p2_backtest_policy_2026-05-22`.
4. **Claude (P3 A/B falsification design)**: before re-enqueue, design the explicit "VP-MACD vs plain MACD" comparison the card already flags as the falsification — tick-volume CFD weighting may add no edge over a vanilla MACD, and that's a legitimate kill condition. Keep VP-MACD only if the A/B clears the lambda-tuned MACD baseline by a margin worth the carrying cost.
5. **Do NOT mark DEAD**. The strategy has a published April-2026 walk-forward through Feb-2026 in the source paper; insufficient evidence to kill.

## 5. Edge Lab compliance note

QM5_1044 predates the 2026-05-22 Edge Lab charter. Before rebuild, verify against the charter:
- News-blackout filter on FOMC/CPI/NFP — the card invokes "Standard V5 framework: QM_KillSwitch, news filter" generically; needs an explicit, mandatory blackout block (no `allow_fomc_hold`-type opt-out).
- DD constraint: card doesn't reference FTMO 10% total / 5% daily — the framework default RISK_FIXED=$1000 baseline should pass on indices, but verify on P3 sweep.
- Timeframe: D1 baseline is swing-horizon, charter-compliant.

## 6. Verification I ran

- `tools/strategy_farm/farmctl.py:3998-4037` — read classifier
- 15 most-recent + full FAIL histogram from `farm_state.sqlite`
- Card front-matter and implementation notes at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1044_vpmacd-us-indices.md`
- Cross-referenced memory: `project_qm5_1044_perf_rework_2026-05-16`, `project_qm_mt5_v5_m1_history_gap_infra_fail`, `project_qm_p2_backtest_policy_2026-05-22`
