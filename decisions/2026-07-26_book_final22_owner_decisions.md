# Decision: Sunday book FINAL22 + the 2026-07-26 midday OWNER decision batch

- Date: 2026-07-26 (midday chat, for the evening deployment)
- Status: accepted — OWNER answered the numbered decision list verbatim:
  „1: deine Empfehlung. 2: entfernen und Re-Qualifikation. 3: parken. 4: ja. 5: ja.
  6: folge Deiner Empfehlung. 7: ja. 9: ja heute Abend."

## Composition (deploy target FINAL22)

1. **12567/XNGUSD.DWX DROPPED** (Decision C = Claude recommendation): sealed Q08 FAIL_HARD
   twice (edge_decay 41.5 %, last-half PF 1.032), decay-audit UNKNOWN (no Q10 row), cap-1.0
   sleeve. Evidence: `D:/QM/reports/work_items/084a05e0-…/QM5_12567/Q08/XNGUSD_DWX/aggregate.json`,
   `D:/QM/reports/ultracode_20260726/wsc/q10_recency_audit.json`.
2. **10939/GBPUSD.DWX REMOVED + re-qualification** (OWNER went beyond the recommendation):
   WS-C decay audit DECAYED (half-vs-half decline 40.59 % under the Q08 convention). Sealed
   Q08 re-qualification enqueued 2026-07-26; re-admission only through the normal evidence
   chain (fresh Q08 → Q10 → Q09 admission), never automatic.
3. 10919/XTIUSD (UNKNOWN, 8 trailing-24m trades) and 13128/NDX (WATCH) remain in the book,
   explicitly OWNER-acknowledged as such.
4. **FINAL22 @ TOTAL_RISK 12.0**, capped inverse-vol cap 1.0: Sharpe 2.2058 (24b: 2.3440),
   MaxDD faithful 4.0065 % (24b: 3.4952 %), net 94,216, at-cap {10919, 12567/XAUUSD, 13128}.
   Base-reproduction gate passed before the delta (Sharpe exact, weight err 4.3e-7).
   Manifest: `D:/QM/reports/portfolio/portfolio_manifest_sunday_FINAL22_TOTALRISK12_20260726.json`;
   presets: `D:/QM/exports/tlive_presets_FINAL22_20260726/` (22 files, sum 12.0 verified).
   **Honest attribution:** both removals cost historical Sharpe (−0.138 vs FINAL24b) — they
   are evidence-integrity removals on the sleeves with the weakest current-edge evidence,
   two of which sat at cap 1.0.

## Further answered points

- **Decision D:** 10938/GDAXI + 10692/NDX PARKED as challengers (neither Sharpe-accretive;
  `admission_eval_20260726/admission_10938_10692_20260726.json`).
- **KS baselines:** deploy tonight (runbook step 7).
- **Swap capture:** terminal snapshot tonight per the WS-D capture spec (closes the
  current-rate scenario; embedded-swap verdict „not material" stands).
- **Recency axis:** ratified per recommendation — enforcement from the next Q10 cohort after
  tonight's WS-C merge + quarterly rolling sealed re-Q08 for live sleeves (separate record).
- **FTMO B1 contract:** D1 BOOK route, D2 FAIL_SOFT admissible soft-edge-only, D3 $100k,
  D4 objective O1 = P(pass Phase 1 by 30d) > 0.5 floor, D6 13301 → Q12 challenger. D5
  (min trading days) read from the new trial account, which OWNER creates tonight.
- Decision B's written manifest approval tonight applies to FINAL22 (composition changed
  after the original approval of FINAL24b).
