# SP-A4 — Q11 full-chain requalification readiness ledger

Date: 2026-08-22  
Router task: `6086fecc-d3b6-4251-aff5-8e6555b9908d`  
Disposition: DEFER — upstream DL-089 current-chain evidence is incomplete  
Detailed sleeve ledger: `2026-08-22_sp_a4_q11_full_chain_requal_readiness.csv`

## Decision

Do not create a second per-EA rebuild or Q11 wave. SP-A4 is the portfolio/Q11
continuation of OWNER-ratified DL-089, and its acceptance condition is not yet
reachable from the measured state. The existing governed work remains the sole
producer of current-chain evidence.

No queue row was inserted, retried, claimed, superseded, or edited during this
task. No factory or deployed binary was recompiled, and no live terminal or
AutoTrading state was touched.

## Bound baseline

The SP-A1 runtime pointer gives a deterministic 24-sleeve / 21-EA census:

| Identity layer | Measured value |
|---|---|
| Pointer file SHA-256 | `f5f23f3c597f07217ef4406a34f929a2cb50e580986007eefe758d4e27b1704a` |
| Pointer schema / written | `qm.live_deployment_pointer.v1` / `2026-08-22T10:06:38Z` |
| Pointer authentication | `signed:false` — correct pending OWNER/ROT activation |
| Manifest SHA-256 | `8c719b080e18d30d83432f0999d694f699f2859cef72c0ce7738631fb084eab6` |
| Expected roster | 24 sleeves, 21 EAs |
| Sleeve identity SHA-256 | `9aa10411d99adf81861503a0023832874873de39eeaacfa880bfc4368fcf84d0` |
| Binary/setfile fingerprint | `8e476e5b807450cbaea92f12b92fcaa285e372a47533b5071996d114a3116035` |
| Missing deployed binaries | 0 |

The pointer's `manifest_sha256` was independently recomputed against
`D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json` and
matched. Because the pointer is unsigned, 24 is an expected roster count, not a
newly minted OWNER-authenticated target. SP-A4 does not sign it.

## Current DL-089 frontier

Read-only queries of `D:/QM/strategy_farm/state/farm_state.sqlite` show:

| Current-chain stage | EAs | Interpretation |
|---|---:|---|
| Rebuilt and current Q02 PASS | 5 | QM5_10403, 10440, 10513, 10706, 10911 |
| Governed `COMPILE_EA` PASS, Q02 not yet present | 4 | QM5_10919, 11132, 11165, 12567 |
| Governed `COMPILE_EA` FAIL | 12 | Exact failure classes are retained in each work-item receipt and summarized in the CSV |
| Current DL-089 Q14 / Q15 / Q16 rows | 0 | Wave 2 cannot be represented as complete |
| Current DL-089 Q11 lineage rows | 0 | Legacy `portfolio_candidates` rows predate DL-089 and cannot close the new-binary chain |
| Sleeves with Card→current EX5→setfile→data→report→Q02…Q16→Q11 closed | 0 / 24 | SP-A4 acceptance not met |

The 12 failed compile rows are evidence-bearing terminal outcomes, not pending
work that this task may silently retry. Four failures are compiler/build-check
failures, while the remainder expose hardening defects including missing MAE
hooks, unbounded indicator buffers, raw-series calls, or uninitialized trade
requests. Their exact governed work-item IDs and reasons are in the CSV.

The existing `portfolio_candidates` rows are dated June/July (with several
explicitly `EVIDENCE_STALE`) and refer to pre-DL-089 Q08/Q09 evidence. Counting
them as current Q11 would splice old reports onto new or failed binaries and
break the required hash chain.

## Dependency reconciliation

- SP-A1 (`105cb532`) is APPROVED. It supplies the roster and fingerprints, but
  activation/signature remains OWNER/ROT and its epoch discrepancy is separately
  documented. That does not authorize SP-A4 to sign or deploy anything.
- DL-089 batch 1 (`4b88e5bf`) is PASSED for 5/21 EAs.
- The obsolete ad-hoc batch-2 row (`b2bf2460`) is FAILED-final and superseded by
  the governed compile rows; it must not be re-run.
- The governed batch-2 enablement (`05084e43`) is APPROVED. Its 16 exact rows
  have now produced 4 PASS and 12 FAIL results. They are not duplicated here.

## Exact unblock contract

SP-A4 becomes executable only after the existing DL-089 lineage provides, for
every retained roster identity (or a newly OWNER-signed target roster):

1. governed current-framework compile PASS and its MQ5/EX5 hashes;
2. append-only current-binary Q02 through Q10 evidence;
3. Q14, Q15, and sealed Q16 evidence under the unchanged optimization contract;
4. dual-book Q11 evidence whose inputs bind those exact upstream hashes;
5. a resulting cohort roster/fingerprint suitable for OWNER book ceremony.

Any strategy that fails the governed chain may be excluded from the next book;
that does not mutate the currently deployed book. Gate thresholds and historical
verdicts remain unchanged.

## Focused verification

- SP-A1 pointer: 24 unique `(ea_id, symbol, magic_number)` rows; binary missing
  count 0; pointer and manifest hashes recomputed.
- Router dependencies: SP-A1 APPROVED, batch 1 PASSED, obsolete batch 2
  FAILED-final, governed continuation APPROVED.
- DL-089 live DB census since 2026-08-21: 5 Q02 PASS, 4 COMPILE_OK, 12
  COMPILE_FAIL, and no Q14/Q15/Q16 current-chain rows.
- CSV structure verification is performed before commit: 24 unique magic rows,
  21 unique EAs, and no row marked `Q11_CURRENT_CLOSED`.

This artifact is a measured readiness gate, not a pipeline or profitability
verdict.
