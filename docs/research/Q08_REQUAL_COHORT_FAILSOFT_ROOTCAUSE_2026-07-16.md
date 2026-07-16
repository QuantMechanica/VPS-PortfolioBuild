# Q08 requal-cohort FAIL_SOFT — root cause + unblock spec (Codex handoff)

**Owner:** Claude diagnosis 2026-07-16. **Lane:** Codex (holds the approved-card params + requal tooling).
**Impact:** 5 of 9 requal-cohort sleeves stuck at Q08 FAIL_SOFT = the bottleneck to the requalified DXZ book.

## Headline
The cohort's Q08 FAIL_SOFT is **NOT merit-based.** The core gates pass (e.g. 10476: Sharpe 2.47,
233 trades, cost-cushion 6.56, 8.1/8.2/8.3/8.6/8.7/8.8/8.9/8.11 all PASS). FAIL_SOFT is driven by
two fixable classes:

### Class A — INVALID sub-gates = degenerate neighborhood/PBO baseline (TOOLING, re-runnable)
`8.5_neighborhood: INVALID` on 4/5 sleeves, `8.7_pbo: INVALID` on 1/5. Root cause (from the
aggregate evidence): **`degenerate_baseline: trades=0, params={}`** — the neighborhood runner's
baseline backtest ran with the wrong/empty setfile → 0 trades → INVALID. Per-sleeve flavor:

| Sleeve | Q08 symbol | Set state | Fix |
|---|---|---|---|
| 11708 anon-market-squeeze | EURUSD/AUDUSD D1 | base sets have **0 strategy params** (setgen-param-empty) | regenerate baseline from approved Card params |
| 10476 mql5-pamxa | **USDCAD** H1 | sets are param-filled (11) but only for AUDUSD/EURUSD/GBPUSD — **no USDCAD set** | generate the USDCAD baseline set from the approved Card (requal defines 10476=USDCAD H1) |
| 10513 mql5-ichimoku | XAUUSD D1 | base set 0 params; ablations have 7 | point neighborhood at the approved param-filled set, not the empty base |
| 12567 cum-rsi2 | XAUUSD D1 | sets filled (9) | confirm the neighborhood/PBO baseline uses the filled set (8.7 pbo INVALID too) |
| 12969 gotobi | USDJPY M30 | sets filled (5) | verify why 8.5 baseline degenerated despite a filled set |

**Fix**: the `q08_5_neighborhood_runner.py` baseline must load the **param-filled approved-Card
setfile matching the tested symbol** (`load_params_from_setfile` currently accepts an empty-param
baseline → degenerate). Regenerate the missing symbol sets (esp. 10476 USDCAD) from the approved
Cards, then **re-run Q08** for the 5 sleeves. INVALIDs should clear.

### Class B — residual soft classifications = OWNER calibration call (not a bug)
After the INVALIDs clear, the residual non-PASS items are soft/expected, not merit failures:
- `8.4_seasonal: EDGE_SOFT` (5/5) — e.g. 10476 has 3 losing months [May, Jul, Sep] = the N_SEASON=3
  soft boundary. Marginal, not a hard fail.
- `8.10_regime_crisis: EDGE_SOFT` (4/5) — regimes still profitable (10476: low/normal/high all +).
- `8.2/8.8/8.9: LOW_SAMPLE` (2/5) — the low-freq XAU D1 sleeves (10513, 12567). **DL-070 precedent:
  ~10 trades/yr is acceptable for swing.** LOW_SAMPLE ≠ fail.

**OWNER decision needed:** does the requalified book admit sleeves whose only residual is
EDGE_SOFT-seasonal / LOW_SAMPLE (low-freq swing)? DL-070 says yes for low-freq; the Q6 design wants
clean gates. This is the calibration line that decides how many cohort sleeves qualify.

## Evidence
Aggregates: `D:\QM\reports\work_items\<wid>\QM5_<ea>\Q08\<SYMBOL>\aggregate.json` —
10476 f7f379d3 · 10513 7a53d77f · 11708 d4d139bf · 12969 74a089c5 · 12567 3f89b9ec.
Runner: `framework/scripts/q08_5_neighborhood_runner.py` (`load_params_from_setfile` line ~113–142).

## Success
INVALIDs cleared via correct baseline sets + re-run; a clear OWNER calibration line on
EDGE_SOFT/LOW_SAMPLE admissibility → the number of qualifying cohort sleeves is then known and the
requalified book can be assembled.
