# Evidence: EDGE-2 Pre-Event Volatility Compression and Expansion in Indices — Task `18a4b282-3c9d-4e75-8457-60e411171622`

- **Task ID:** `18a4b282-3c9d-4e75-8457-60e411171622`
- **Agent:** `gemini`
- **Priority:** 55
- **Hypothesis Ref:** `docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md §4 EDGE-2`
- **Measurement Tool:** `tools/strategy_farm/research/edge_lab_stats.py`
- **Unit Tests:** `tools/strategy_farm/tests/test_edge_lab_stats.py` (105 passed)
- **Output Directory:** `docs/research/edge_lab/20260915_r4/EDGE-2/`
- **Overall Verdict:** `REFUTED`

---

## 1. Executive Summary

Hypothesis EDGE-2 posits that ahead of scheduled high-impact US macro releases, index futures liquidity thins and realised volatility compresses in the 60 minutes prior to release, followed by reliable post-release range expansion. The rule trades a breakout of the pre-release range in the first 15 minutes after release, exited at a 2x range target, midpoint stop, or 60-minute time stop, evaluated on `NDX.DWX` and `SP500.DWX`.

The measurement was conducted over the top-5 US macro events (Nonfarm Payrolls, CPI m/m, Fed Interest Rate Decision, Retail Sales m/m, Initial Jobless Claims) using verified timestamps from the native calendar export (`T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv`), bypassing the legacy calendar's unresolved 17-hour displacement defect documented in `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md`.

### Sealed Refutation Criteria & Empirical Findings:
1. **Sample Size:** Criterion requires $n \ge 150$ events in IS (2018–2023).
   - **Observed:** $n=399$ events on NDX and $n=488$ events on SP500 ($n \ge 150$ satisfied).
2. **Expansion Consistency Hurdle:** Post-release 60-min range must be $\ge 1.8\times$ the pre-release range in $\ge 70\%$ of events (2018–2023).
   - **Observed:** Post-release range $\ge 1.8\times$ occurs in only **47.62 %** of events on NDX and **45.49 %** on SP500. Both fail the $70\%$ consistency requirement by over 22 percentage points.
3. **Breakout Trade Expectancy:** Breakout trade expectancy after 1 pt round-trip cost must be $> 0$ with $t \ge 2$.
   - **Observed:** Breakout trade expectancy is positive (+10.45 pts on NDX with $t=3.38$; +2.07 pts on SP500 with $t=2.74$).
4. **Holdout Expansion Ratio:** 2024–2025 holdout must keep expansion ratio $\ge 1.5$.
   - **Observed:** OOS mean expansion ratio is 2.80x on NDX and 2.84x on SP500.

**Verdict:** `REFUTED`. While mean expansion is large (> 2.3x) and trade expectancy is positive, the failure of the sealed 70% consistency hurdle strictly refutes the hypothesis.

---

## 2. In-Sample Results (2018–2023)

| Symbol | Era | n_events | Mean Ratio | Frac >= 1.8x | Trades | Mean Net PnL (pts) | t-stat | Verdict |
|---|---|---|---|---|---|---|---|---|
| `NDX.DWX` | IS | 399 | 2.40x | **47.62 %** | 329 | +10.45 | 3.38 | **REFUTED** |
| `SP500.DWX` | IS | 488 | 2.28x | **45.49 %** | 413 | +2.07 | 2.74 | **REFUTED** |

---

## 3. Out-Of-Sample Results (2024–2025 Holdout)

| Symbol | Era | n_events | Mean Ratio | Frac >= 1.8x | Trades | Mean Net PnL (pts) | t-stat | Verdict |
|---|---|---|---|---|---|---|---|---|
| `NDX.DWX` | OOS | 166 | 2.80x | 57.23 % | 145 | +15.42 | 2.50 | SUPPORTED |
| `SP500.DWX` | OOS | 166 | 2.84x | 57.83 % | 152 | +2.30 | 1.67 | SUPPORTED |

---

## 4. Methodological Compliance & Evidence Integrity

- **Time Base:** Evaluated with explicit DST-aware broker-to-UTC mapping (`qm.dst_rule.us.v1` ported from `QM_DSTAware.mqh`).
- **Data Source:** M15 BID bar history from `D:/QM/mt5/T_Export/MQL5/Files/` (`NDX.DWX_M15.csv`, `SP500.DWX_M15.csv`).
- **Calendar Alignment:** Release timestamps drawn directly from MT5 native export `T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv` (column `broker_time` = true UTC epoch) to prevent contamination from the known 17-hour legacy Forex Factory displacement defect.
- **Cost Deductions:** 1.0 point round-trip cost explicitly deducted from every entered breakout trade.
- **Reproducibility Command:**
  ```bash
  python -X utf8 tools/strategy_farm/research/edge_lab_stats.py \
      --hypothesis EDGE-2 --out docs/research/edge_lab/20260915_r4 \
      --now-utc 2026-09-15T00:00:00Z
  ```

---

## 5. Artifact Manifest

| Path | File Description |
|---|---|
| `docs/research/edge_lab/20260915_r4/EDGE-2/summary.json` | JSON summary containing schema, cell params, arm metrics, and REFUTED verdict |
| `docs/research/edge_lab/20260915_r4/EDGE-2/events.csv` | Per-event table of pre/post range expansion, breakout direction, MFE/MAE and PnL |
| `docs/research/edge_lab/20260915_r4/EDGE-2/manifest.json` | Hash-pinned manifest of all input files, git commit, and execution parameters |
| `docs/research/edge_lab/EDGE_LAB_MEASUREMENT_LOG.md` | Formal measurement log entry appended under `2026-09-15 — r4` |
| `docs/ops/OPEN_ITEMS_STATUS.md` | RESULT line logged |
