# V5 Locked Basket — Snapshot 2026-04-18 / lock v3 2026-04-19

- Date locked: 2026-04-19 (v3)
- Source: `Company/Results/V5_COMPOSITION_LOCK_20260418.md` (laptop)
- Risk review: `Company/Results/V5_PORTFOLIO_RISK_REVIEW_20260418.md` (laptop)
- Pipeline boundary: at the P9 Portfolio Construction / P9b Operational Readiness gate. Open waivers prevent automatic promotion to P10 Shadow Deploy until closed.

## Locked 5-Sleeve Basket

| SM_ID | Symbol (lane) | Weight | Notes |
|---|---|---|---|
| `SM_124` | UK100 | 1.00x | P5b is a formal waiver artifact (no clean R002 receipt). |
| `SM_221` | AUDUSD | 0.25x | YELLOW: P5b strict 57.30% FAIL, proxy `<=1 breach` 71.50% PASS. Down-weighted to 0.25x. |
| `SM_345` | AUDNZD | 1.00x | P5b R002 PASS. P6 multi-seed waiver on disk. |
| `SM_157` | AUDNZD | 1.00x | P5b R002 PASS. P6 multi-seed waiver on disk. |
| `SM_640` | XTIUSD | 1.00x | P5b R002 PASS. P6 multi-seed waiver on disk. |

Locked basket gross units: `4.25` (per portfolio lock matrix). Proxy MaxDD `P50 -14.27`, `P95 -11.09`.

## Excluded Outliers (zero V5 weight)

| Sleeve | Verdict | Reason |
|---|---|---|
| `SM_890 AUDUSD` | `kill` lane + `sleeve-drop` | `PF 1.00`, `DD 28.71%`, `Trades 1352`, `NetProfit -1,066.25`, `OVER_DD`. |
| `SM_890 EURUSD` | `kill` lane + `sleeve-drop` | `PF 0.99`, `DD 22.06%`, `Trades 1356`, `NetProfit -9,422.45`, `NEG_EXPECTANCY_MILD`. |
| `SM_882 WS30` | `sleeve-drop` (revisit gated) | `PF 1.22`, `DD 20.82%`, `Trades 667`, `NetProfit 601,576.12`, `OVER_DD`. If revisited later, requires `weight-throttle <= 0.25x` and fresh P5b/P6/P8 receipts before deploy. |

Per `V5_PORTFOLIO_RISK_REVIEW_20260418.md`, with these three excluded the outlier findings do not breach the locked-basket risk budget.

## Open Waivers / Closure Items (must close before P10/Live)

1. `SM_124` P5b is a waiver, not a clean run receipt. Closure: produce real P5b R002 evidence or formally document why the waiver is permanent.
2. `SM_221` is YELLOW at 0.25x. Closure: either accept YELLOW with documented rationale, or produce a strict-PASS R002 at the chosen weight.
3. `SM_124 / SM_345 / SM_157 / SM_640` P6 multi-seed reports are waived (missing real per-sleeve P6 artifacts). Closure: run real per-sleeve P6 with seeds `42, 17, 99, 7, 2026` and replace the waiver entries.
4. `SM_890 AUDUSD/EURUSD` and `SM_882 WS30` have no P5b R002, P6, or P8 roll-up receipts on disk. Not blocking the locked basket; only needs closure if either is reconsidered.
5. Deploy folder choice (laptop): `Company/VPS/V5/` is missing; `Company/VPS/V6/README.md` is the current canonical path. OWNER must choose between (A) keeping `V6/` or (B) creating `V5/` for strict version parity before deploy packaging.
6. QUAA-31 finding #4: if `SM_890` is later added, deploy it symbol-filtered or replace with a symbol-stable comparator. Track in QUAA-26 close-out.

## Provenance / Citations (laptop paths)

- `Company/Results/V5_COMPOSITION_LOCK_20260418.md` (locked lineup, weights, outlier list)
- `Company/Results/V5_PORTFOLIO_RISK_REVIEW_20260418.md` (outlier metrics, mitigation decisions)
- `Company/Results/SM_221_P5B_YELLOW_DECISION_20260418.md`
- `Company/Results/V5_P6_MULTISEED_WAIVERS_20260418.md`
- `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
- `Company/Results/P5_CALIBRATED_NOISE_RECAL_SM_124_UK100_20260418_R002.md`
- `Company/Results/P5_CALIBRATED_NOISE_RECAL_SM_157_EURCAD_20260417_R002.md`
- `Company/Results/P5_CALIBRATED_NOISE_RECAL_SM_345_EURGBP_20260417_R002.md`
- `Company/Results/P5_CALIBRATED_NOISE_RECAL_SM_640_AUDUSD_20260417_R002.md`
- `Company/Results/P5_CALIBRATED_NOISE_RECAL_SM_221_AUDUSD_20260417_R002.md`
- `Company/Results/V5_WEIGHT_MATRIX_SM221_0.25X_5SLEEVE.md`
- `Company/Analysis/baseline_failure_taxonomy_post_restart_20260418.md`
- `Company/Analysis/edge_cluster_SM_890_20260418.md`

## Note on Symbol-vs-Lane Discrepancies

- `SM_345` and `SM_157` are both locked on AUDNZD per `V5_COMPOSITION_LOCK_20260418.md`, but the P5b receipts on disk reference `SM_157 EURCAD` and `SM_345 EURGBP`. This may indicate a lane reassignment between P5b and the v3 lock, or a documentation drift. To verify before P9b sign-off.
