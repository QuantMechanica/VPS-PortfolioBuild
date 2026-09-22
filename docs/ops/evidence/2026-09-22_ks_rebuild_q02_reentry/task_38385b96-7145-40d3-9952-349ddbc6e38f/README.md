# Kill-switch rebuild Q02 re-entry — task 38385b96

## Disposition

STOP / REVIEW. Four rebuilt sleeves are identity-exact, one rebuilt sleeve diverges, and one sleeve was refused before Q02 because its parameter-change provenance is not authenticated. The six-sleeve D2g6 deployment is therefore not authorized.

| EA | Append-only Q02 | Identity proof | Deal result | Disposition |
|---|---|---|---:|---|
| 13213 | PASS (80e6a407-0549-4c20-a1b4-f3b7c46d3c43) | EQUIVALENT_EXACT | 1777 / 1777 | inherited evidence may carry |
| 10706 | base-control PASS (972a6d85-d5d0-4a5b-92d6-2a138adbc08d); selected ablation-02 refused | NOT_EQUIVALENT on base control | 303 / 303; 1 identity-field mismatch | STOP; no inheritance |
| 10700 | PASS (126caeb4-825b-4604-8900-60c628424da4) | EQUIVALENT_EXACT | 403 / 403 | inherited evidence may carry |
| 11422 | PASS (87522e35-4451-4594-aaf8-167e0f414b3f) | EQUIVALENT_EXACT | 223 / 223 | inherited evidence may carry |
| 10403 | not enqueued | not run | n/a | STOP; provenance authentication required |
| 41219 | PASS (9b764ccb-9f7d-40d3-96e6-571336958be5) | EQUIVALENT_EXACT | 65 / 65 | inherited evidence may carry |

The 10706 mismatch is deal 15: its open time is 2018.09.12 13:03:44 in the sealed base-preset predecessor and 2018.09.12 13:03:47 in the rebuild. PnL and volume are exact, but the governing proof contract requires every checked identity field to match, so the three-second difference is a hard divergence. A lineage cross-check also found that the D2g6-selected sleeve is ablation-02. Its actual predecessor Q02 row 7cf004b7-f4cf-42cb-80cc-d5c98f119ce4 cannot enter requalification because that historical row lacks source_ex5_sha256. Thus the selected configuration has no new Q02 or proof in this cycle; the base-control divergence is an additional STOP, not a substitute for selected-set proof.

10403 was rejected by farmctl requalify-q02 with parameter_change_provenance_not_authenticated. The current set adds qm_ea_id and removes eleven legacy filter inputs relative to the sealed predecessor; the referenced rebuild authority has no matching hash-bound registrations entry. No weaker enqueue path was used.

Machine-readable bindings are in [q02_results.json](q02_results.json), [blockers.json](blockers.json), and the copied append-only receipts under [q02_receipts](q02_receipts/). Each proof and sidecar is under [identity_equivalence](identity_equivalence/); identity_equivalence_proof.py verify succeeded for all five generated proofs, including integrity verification of the divergent verdict.

## Evidence inheritance and news correction

[inheritance.json](inheritance.json) carries prior Q-phase evidence only for the four exact sleeves. It preserves negative verdicts as negative evidence; in particular, 13213's Q09_PORTFOLIO verdict remains FAIL_PORTFOLIO. Nothing is inherited for 10706 or 10403.

All selected Q10 evidence is bound to news-calendar hash 86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1. Calendar validity is explicitly delegated to correction task f50a0bba-a85d-4203-a18b-ad3b198f5ee9; this task does not claim that correction or promote any sleeve on news evidence.

## Review-only deploy package

The package at [deploy_package_review_only](deploy_package_review_only/) binds the six current EX5 hashes, active magic rows (see [magic_registry_check.json](magic_registry_check.json)), ENV=live provenance, RISK_FIXED=0, positive RISK_PERCENT, qm_news_stale_max_hours=336, qm_ftmo_execution_mode=QM_FTMO_EXECUTION_GOVERNED, qm_ftmo_book_tag=FTMO_DEMO_BOOK_V3_D2G6_20260918, and qm_ftmo_anchor_mode=MAX_BALANCE_EQUITY. It is marked install_authorized=false and REVIEW_ONLY_BLOCKED_IDENTITY throughout.

The source/hash planner validated all 14 planned copies. The canonical demo_install.py --dry-run then refused with autotrading_must_be_disabled, because the FTMO demo target currently reports AutoTrading enabled. No terminal or AutoTrading state was changed. This refusal is an additional deployment STOP, not a package-hash failure.

Required runtime markers and acceptance criteria are in [runtime_proof_plan.json](runtime_proof_plan.json). Runtime proof was not attempted because installation and terminal interaction were outside this task and the identity gates are not clear.

## Verification summary

- Five append-only Q02 rows were created without mutating their predecessors; all five reached Q02 PASS. Four are the D2g6-selected strategy sets; the 10706 row is a base-preset control, while the selected ablation-02 predecessor was refused fail-closed.
- Five proof files were generated and re-verified: four EQUIVALENT_EXACT, one NOT_EQUIVALENT.
- Six presets passed explicit governed-input, risk, stale-news, output-hash, EX5-hash, roster, and collector validation.
- Canonical target dry-run refused fail-closed on AutoTrading; no install, chart, T_Live, terminal, or AutoTrading mutation occurred.
- No pipeline verdict or deploy authorization is asserted by this artifact.
