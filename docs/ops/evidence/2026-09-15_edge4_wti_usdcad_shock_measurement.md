# Evidence: EDGE-4 Cross-Asset Lead-Lag (WTI Shocks into USDCAD) — Task `169586d4-7ee9-4ead-8bdc-c834be02ebd8`

- **Task ID:** `169586d4-7ee9-4ead-8bdc-c834be02ebd8`
- **Agent:** `gemini`
- **Priority:** 62
- **Hypothesis Ref:** `docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md §4 EDGE-4`
- **Measurement Tool:** `tools/strategy_farm/research/edge_lab_stats.py`
- **Unit Tests:** `tools/strategy_farm/tests/test_edge_lab_stats.py` (105 passed)
- **Output Directory:** `docs/research/edge_lab/20260915_r4/EDGE-4/`
- **Overall Verdict:** `REFUTED`

---

## 1. Executive Summary

Hypothesis EDGE-4 posits a cross-asset lead-lag information transmission edge from large intraday crude oil moves (XTIUSD 15-minute return shock $> 2.0\sigma$ over a trailing 60-day rolling window) into USDCAD forward returns at +5m, +15m, and +30m. The theoretical premise assumes FX dealers update quotes on price rather than oil tape, creating a tradeable short lag.

The measurement was conducted over `XTIUSD.DWX` and `USDCAD.DWX` across 2018–2023 (In-Sample) and 2024–2025 (Holdout).

### Sealed Refutation Criteria & Empirical Findings:
1. **Sample Size:** Criterion requires $n \ge 400$ shocks in IS (2018–2023).
   - **Observed:** $n = 8,178$ shocks detected in IS ($n \ge 400$ satisfied).
2. **Effect Magnitude Floor:** Conditional 30-min USDCAD return in the expected direction must have mean $\ge 0.20\sigma$ in IS.
   - **Observed:** Conditional 30-min forward return in USDCAD is only **+0.20 bp**, yielding an effect size of **0.0217 sigma**.
   - **Deficit:** The observed effect of $0.0217\sigma$ fails the sealed floor of $0.20\sigma$ by a factor of 9.
3. **Execution Feasibility:** All returns are gross bid-to-bid. Typical USDCAD spread (0.8–1.0 pip = ~0.6–0.8 bp) completely eliminates the tiny 0.20 bp gross move.

**Verdict:** `REFUTED`. The transmission effect is economically negligible and strictly fails the sealed effect floor.

---

## 2. In-Sample Results (2018–2023)

| Symbol Pair | Era | n_shocks | Mean 5m (bp) | Mean 15m (bp) | Mean 30m (bp) | Effect Sigma | t-stat | Verdict |
|---|---|---|---|---|---|---|---|---|
| `XTIUSD` -> `USDCAD` | IS | 8,178 | +0.08 | +0.14 | +0.20 | **0.0217** | 1.96 | **REFUTED** |

---

## 3. Out-Of-Sample Results (2024–2025 Holdout)

| Symbol Pair | Era | n_shocks | Mean 5m (bp) | Mean 15m (bp) | Mean 30m (bp) | Effect Sigma | t-stat | Verdict |
|---|---|---|---|---|---|---|---|---|
| `XTIUSD` -> `USDCAD` | OOS | 1,224 | +0.12 | +0.19 | +0.37 | 0.0618 | 2.16 | SUPPORTED |

---

## 4. Methodological Compliance & Evidence Integrity

- **Time Base:** Evaluated with explicit DST-aware broker-to-UTC mapping (`qm.dst_rule.us.v1` ported from `QM_DSTAware.mqh`).
- **Data Source:** M15 bar history for XTIUSD (`XTIUSD.DWX_M15_TICKS_2018_2025.csv`) and M5 bar history for USDCAD (`USDCAD.DWX_M5.csv`).
- **Rolling Window:** 60-day rolling window variance calculation for shock z-score threshold $\ge 2.0\sigma$.
- **Reproducibility Command:**
  ```bash
  python -X utf8 tools/strategy_farm/research/edge_lab_stats.py \
      --hypothesis EDGE-4 --out docs/research/edge_lab/20260915_r4 \
      --now-utc 2026-09-15T00:00:00Z
  ```

---

## 5. Artifact Manifest

| Path | File Description |
|---|---|
| `docs/research/edge_lab/20260915_r4/EDGE-4/summary.json` | JSON summary containing schema, cell params, arm metrics, and REFUTED verdict |
| `docs/research/edge_lab/20260915_r4/EDGE-4/shock_events.csv` | Granular table of detected WTI shocks and forward USDCAD returns |
| `docs/research/edge_lab/20260915_r4/EDGE-4/manifest.json` | Hash-pinned manifest of all input files, git commit, and execution parameters |
| `docs/research/edge_lab/EDGE_LAB_MEASUREMENT_LOG.md` | Formal measurement log entry appended under `2026-09-15 — r4` |
| `docs/ops/OPEN_ITEMS_STATUS.md` | RESULT line logged |
