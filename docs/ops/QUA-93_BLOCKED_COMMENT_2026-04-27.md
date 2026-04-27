Status: **blocked** (defer)

- Issue: QUA-93
- Parent: QUA-19
- Symbol: XAUUSD.DWX
- Verdict: FAIL_tail_mid_bars
- bars_got: 0
- tail_shortfall_seconds: 1775444399.867
- acceptance_met: False
- last_checked_local: 2026-04-27T09:49:42+02:00
- last_evidence_path: lessons-learned\evidence\2026-04-27_qua93_xauusd_rerun_evidence.json

Unblock owners:
- Verifier/import owner (D:\QM\mt5\T1\dwx_import\verify_import.py + XAU export pipeline): Refresh aligned XAU tick/M1 exports, rebuild XAUUSD.DWX custom history + sidecars, rerun verifier

Handoff artifacts:
- investigation: lessons-learned/2026-04-27_qua93_xauusd_verifier_failure_investigation.md
- rerun evidence: lessons-learned\evidence\2026-04-27_qua93_xauusd_rerun_evidence.json
- tail alignment: lessons-learned/evidence/2026-04-27_qua93_xauusd_tail_alignment_check.json
- desktop nudge evidence: lessons-learned/evidence/2026-04-27_qua93_csv_tail_mismatch_nudge_validation.json
