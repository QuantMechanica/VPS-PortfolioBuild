## Research finding — 1017 D1 zero-trades is data-window-vs-card mismatch (Pipeline-Op P2 6-month window incompatible with `training_lookback=252` D1 strategy)

**Wake reason:** Track 1b 1017 D1 cohort completed (QUA-748 closeout 22:11:59Z) — PASS=0 / FAIL=7 / MIN_TRADES_NOT_MET = 7/7 across all 7 curated cadf-eligible pairs (AUDUSD/NZDUSD, EURUSD/GBPUSD, XAUUSD/XAGUSD, AUDCAD spot-proxy). Track 1b was the strongest CEO-actionable path in my synthesis comment 5ca73c17; CEO unblocked it directly with set-file generation in commit 24bf7b8b. **Track 1b also failed.**

I checked the actual trade counts: every D1 run produced `total_trades: 0` across both run_01 and run_02. **Same zero-trades pattern as 1009 M15.**

**But the cause is different from 1009. This one is card-spec-derivable.**

---

### Card § 4 + § 6 require 252 D1 bars of training BEFORE strategy fires

Card `chan-pairs-stat-arb_card.md` § 4 (verbatim):

```
TRAINING_LOOKBACK = 252                    // days; Chan: trainset = 1:252
COINTEGRATION_SIGNIFICANCE = 0.05          // i.e. require cadf t-statistic <= 5% critical value (-3.343 for 2-var case)
```

Card § 6 (deployment requirement):

> only deploy on pairs where cadf t-stat passes COINTEGRATION_SIGNIFICANCE (default 5%) on **the most recent TRAINING_LOOKBACK bars**; re-run cadf at every walk-forward boundary

Card § 9 (Chan verbatim):

> "training set = **first 252 daily bars** from 2006-05-23 onwards" (Example 3.6 MATLAB comment, p. 58)

EA implementation matches card spec: `input int training_lookback = 252` + `input bool cadf_gate_enabled = true` + cadf gate runs on every bar, blocking trade firing until 252 D1 bars of history are available AND the cadf t-stat ≤ -3.343.

---

### The data-window mismatch

`p2_baseline.py` runs the V5 standard P2 window: 6 months of 2024 (`year=2024`, defaulted to H1 backtest period).

| Layer | Available D1 bars | Required by card | Outcome |
|---|---|---|---|
| 6-month P2 test window (2024 H1) | ~125 D1 trading bars | training_lookback=252 → at least 252 bars BEFORE first eligible trade | Strategy never has 252 bars of training before test ends |
| MT5 tester pre-test warmup (default) | depends on tester config; standard MQL5 backtest does load some history for indicator init but NOT typically 1+ year for strategy-state | The EA's cadf gate runs every bar; it cannot pass the 252-bar requirement until 252 D1 bars have ELAPSED in the test/warmup window | cadf_gate ABORT_DEPLOY every bar = zero trades |

**Result:** the EA correctly enforces the card spec (do not trade until cadf training data is sufficient), but the test window is structurally too short for a 252-D1-bar training requirement to ever satisfy.

---

### How this differs from 1009 zero-trades

1009 lien-fade-double-zeros has **no training-window requirement** — only needs 20 M15 bars of SMA warmup (5 hours). Card § 4 specifies no minimum-history gate. So 1009 zero-trades cannot be explained by data-window-mismatch; it remains EA-implementation-bug territory (CTO's QM-00085 H1/H2/H3 hypothesis ladder).

1017's zero-trades **is fully explained by card-spec data-window requirement** without any EA bug. The EA is doing exactly what the card says. The mismatch is between Pipeline-Op's standard 6-month P2 window and Chan's 1-year-training + walk-forward strategy class.

---

### Three resolution paths for OWNER / CEO / Pipeline-Op

**Path X1 (recommended): extend P2 test window for training_lookback-bound EAs**

Pipeline-Op's `p2_baseline.py` should support per-EA test-window override based on card § 4 minimum-history requirement. For 1017 D1 with training_lookback=252, the test window needs to be at least 252 + 60 = ~312 D1 bars (~14 months of historical D1 data, e.g., 2023-01 through 2024-06 for a 6-month effective testing window after warmup).

This is a card-implied invariant: any strategy with explicit training-lookback or warmup requirement must have ≥ training_lookback bars of in-test history before the effective measurement window. Could be implemented as:

- Pipeline-Op reads card § 4 / § 8 for `training_lookback` and similar warmup parameters
- p2_baseline.py automatically extends test window: `effective_start = test_start − ceil(max_warmup * 1.5)` to give the strategy headroom
- Falls back to default 6-month window for EAs without warmup requirements (e.g., 1003, 1009)

This is the same structural fix shape as CEO QM-00083 (set files write card § 4 defaults). Card spec → pipeline behavior; not handled implicitly.

**Path X2: reduce `training_lookback` for the redeploy**

Card § 8 P3 sweep includes `training_lookback ∈ [126, 189, 252, 378, 504]`. Reducing to 126 D1 bars (~6 months) MAY allow the cadf gate to pass within a 12-month test window. **But this is not a clean test of Chan's strategy** — Chan's example uses 252 explicitly, and shorter training windows have higher cadf false-positive rates (would deploy on non-cointegrating pairs that look correlated by chance over 6 months).

P3 sweep is the right place for this (after a baseline measurement on training_lookback=252 with adequate test window). Not a substitute for fixing the data window.

**Path X3: accept Track 1b as not-Phase-3-eligible; defer 1017 to a longer test window after Phase 3 closure**

If Path X1 takes too long to implement, Track 1b is functionally blocked the same way as Track 1a (broker activation). Phase 3 closure path becomes path 3 (acceptance-criterion revision under DL-023 class 4) by elimination.

---

### What this means for the Phase 3 closure decision

Updated path lens:

- **1003**: gate did its job ruling Davey baseline non-edge-bearing; not Phase-3-blocking (per prior synthesis)
- **1004**: Track 1a OWNER-blocked on QUA-770 (Darwinex US500 activation)
- **1009**: CTO QM-00085 debug; non-blocking parallel
- **1017**: Track 1b card-aligned redeploy ZERO trades — **explained by data-window-vs-card mismatch, NOT strategy-edge or EA-bug**; resolution requires Path X1 (Pipeline-Op enhancement) OR Path X2 (P3 sweep on training_lookback=126)

**Track 1a is now the only remaining path to positive-edge evidence within the current pipeline configuration.** OWNER's QUA-770 unblock decision is the critical-path gating event.

If Track 1a unblocks today/tomorrow → Path 1 recoverable (1004 on US500 produces evidence)
If Track 1a stays blocked → Path 3 (acceptance-criterion revision) is the only remaining closure route

---

### Recommended actions

**For Pipeline-Op / CTO:** file the Path X1 enhancement (`p2_baseline.py` reads card § 4 training_lookback and extends test window automatically) as a follow-up to QM-00083 (set-file param-write enhancement). Same architectural pattern: card → pipeline-behavior, not implicit.

**For CEO:** decision-log entry that Track 1b 1017 D1 zero-trades is data-window-vs-card mismatch, not strategy weakness. Track 1b is structurally suspended pending Path X1 OR Path X2 P3 sweep.

**For Research (this comment):** card-spec source of truth. No card edits — card § 4 + § 6 + § 9 are correct as-authored; Chan's strategy genuinely requires 252 D1 bars of training. The gap is on Pipeline-Op's P2 test-window default not being card-aware.

---

### Cross-cutting CEO observation echoed

This is the **third sister gap** of the same pattern:

1. **Deployment-vs-card-spec** (markets/timeframes) — flagged 09:33Z + 13:37Z; CEO accepted; Pipeline-Op redeploys queued
2. **EA-vs-card-spec** (parameter defaults / variant flags) — flagged 19:48Z; CEO accepted; CTO QM-00082 reverted; QM-00083 enforces card → set-file
3. **Test-window-vs-card-spec** (training/warmup requirements) — this comment

All three share the root: **the card is treated as a research deliverable, not a constraint on the pipeline.** The card declares strategy properties (markets, timeframes, parameters, training requirements); the pipeline must enforce these properties on deployments and tests. Without that enforcement chain, every measurement is at risk of being a measurement of misconfiguration rather than strategy edge.

CEO's prior commitment to file these as DLs after the redeploys land is the right call. This third gap belongs in the same DL bundle.

---

### What is NOT changing this heartbeat

- No card edits — `chan-pairs-stat-arb_card.md` § 4 + § 6 + § 9 are correct as-authored (verbatim Chan quotes; 252 is Chan's number, not mine)
- No new issue filed — the resolution is Pipeline-Op / CTO work; CEO will route via Kanban
- No 1017 cohort rerun this heartbeat — Pipeline-Op needs the data-window enhancement OR a card-§8-sanctioned P3 sweep first

---

### References

- Card: `strategy-seeds/cards/chan-pairs-stat-arb_card.md` § 4 (TRAINING_LOOKBACK=252) + § 6 (cadf-gate deployment requirement) + § 8 (training_lookback sweep [126, 189, 252, 378, 504]) + § 9 (Chan verbatim "training set = first 252 daily bars")
- 1017 D1 cohort summary: `D:/QM/reports/pipeline/QM5_1017/P2/p2_QM5_1017_result.json` (PASS=0/FAIL=7)
- 1017 individual run summary (sample): `D:/QM/reports/pipeline/QM5_1017/P2/QM5_1017/20260507_220913/summary.json` (AUDUSD D1 trades=[0,0])
- Track 1b unblock by CEO: QUA-740 + QUA-748 comments 2026-05-07T22:08Z (commit 24bf7b8b set-file generation)
- Track 1b run by Pipeline-Op: QUA-748 22:11:59Z closeout
- Prior Research input chain: comments 7b387fbc + 54f79913 + 57cc35c2 + 5ca73c17 (all CEO-accepted)
