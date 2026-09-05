# DL-089 B5 + B2 staged admission — implementation for review

Router task: `bd9505ce-17cd-4873-9f6f-5032c1a537a6`. Authority: receipt row 13, `OWNER-DEC-D1-PRESCREEN-20260905`. Result: code and focused verification ready for CEO review; production activation remains OFF. No factory database rows were changed by this task.

Code commit: `c13d5a489ed9972adf614ea0ded34816b8484c43` on `agents/codex-census-prescreen-20260905`, in the isolated Codex worktree. The accompanying `2026-09-05_census_prescreen_b5_b2_implementation.patch` contains the nine-file change; SHA256 `b46c1c2004e9b1ab0cec339a708104fc0933b101bf5012d1aea53f6a12aa1e1a`. Canonical tooling and main were not integrated or activated.

## Behavior and preserved declaration

The declaration still contains 154 non-baseline arms and seven annual cells per arm, plus seven baselines: 1,085 cells. B5 requires at least five predicate fires in each admitted year. Stage 1 is 2019 and 2020. Stage 2 waits for the complete stage-1 disposition, then requires at least 5% relative net-profit improvement against each year's baseline in **both** years. The immutable prior walk-forward selection rule and its hash are unchanged.

The implementation uses the existing selector's strictly positive baseline convention for relative uplift: `baseline > 0` and `arm - baseline >= 0.05 * baseline`, evaluated with Decimal. A zero or negative baseline does not qualify. This is explicit in the sealed contract and is material to the dry run: the 41196 2019 baseline is -325.62; the 41197 2020 baseline is -102.36. CEO review should retain or explicitly revise this convention before activation; the tool does not silently reinterpret negative denominators.

The new ledger preserves the complete cell declaration and records a validated, contiguous admitted-year prefix per arm. Existing rows retain their status, payload, verdict and evidence. Any year already containing a row when the policy is introduced is protected and uses legacy admission for missing cells. A new `SKIPPED_PRESCREEN` row is a terminal **unmeasured** disposition, with a create-only receipt carrying the reason, annual fire count where applicable, threshold, tool/counter/D1/manifest/contract hashes, and native report plus summary proofs. It supplies no fabricated return or trade metrics. Downstream selection treats it as an unmeasured exclusion, while the declared-trial denominator remains 154. Frontier, matrix-owner validation, finalization, lifecycle and clean-view consumers recognize the disposition. B5 is year-local and does not imply that an arm can never fire again.

The existing harness and Q02 preconditions remain in the enqueue path. Partial staging cannot rebind a program to another Q12 owner or declaration. All production SQL in the new path is insert-only; no existing row update is performed. A database/ledger write interruption fails closed on admission mismatch and requires ordinary recovery; this change does not introduce automatic crash reconciliation.

## Focused verification

- Initial six new tests plus census, selector and matrix tests: **63 passed** in 37.69 seconds.
- Expanded nine tests plus same-program replay, clean-view, lifecycle, rebaseline, stream-bundle and predicate tests: **636 passed** in 25.13 seconds.
- After tightening contract shape, year-prefix validation and counter pinning: **9 passed** in 17.11 seconds.
- Committed diff passes whitespace checking with `cr-at-eol` for the repository's existing CRLF file. The ordinary whitespace checker identifies the added CRLF token line as trailing CR; there is no trailing space change.

The fixtures prove stage-1-to-stage-2 admission, the exact 5% threshold, append-only skip receipts, full 1,085-cell/154-trial reconciliation, pending and running row preservation, protected-year behavior, receipt/manifest tamper rejection, matrix ownership rejection and kill-switch recovery. The kill switch continues to work if a mutable D1 export is no longer available; it never removes prior receipts or restarts active work.

The prior `2026-09-04_pattern_fire_count_prescreen.md` reports zero false NEVER_FIRES across 480 measured cells (154 EUR and 326 GBP), with its stated coverage limits. This task cites that result and does not repeat TKC parity. These exports are explicitly accepted as MT5 **server civil time**, not UTC bars, under the new OWNER receipt.

## Read-only live-program dry run

`2026-09-05_census_prescreen_dry_run.py` opens a read-only database snapshot and pins existing native reports. Full results, arm classifications and input hashes are in `2026-09-05_census_prescreen_b5_b2_dry_run.json` (SHA256 `e90c5b38edbc49e2f26d930c2568e9345f1eb14f8d7397668f7c6e0b90683f55`). This is a counterfactual admission estimate, not a pipeline verdict.

| Year | 41196 B5 below five | 41196 combined hypothetical skips | 41197 B5 below five | 41197 combined hypothetical skips |
|---|---:|---:|---:|---:|
| 2019 | 111 | 111 | 145 | 145 |
| 2020 | 113 | 113 | 143 | 143 |
| 2021 | 110 | 154 | baseline pending | at least 149 |
| 2022 | 111 | 154 | baseline pending | at least 149 |
| 2023 | 114 | 154 | baseline pending | at least 149 |
| 2024 | 112 | 154 | baseline pending | at least 149 |
| 2025 | 117 | 154 | baseline pending | at least 149 |

41196 has 124 arms rejected by stage-1 B5 and 30 further arms rejected by B2. 41197 has 146 rejected by B5, three further B2 rejections and five awaiting stage-1 measurements. Unknown results remain unknown; they are not counted as measured failures. The table concerns the 154 arms per year and excludes the annual baseline.

**Effective saving is zero for both programs:** each already has all 1,085 annual rows enqueued. Neither pending nor active historical work can be retrospectively skipped under this implementation. Potential savings apply only to eligible future, unenqueued years/programs after approval.

Pinned manifests (also embedded in the dry-run JSON):

- XAUUSD: `D:/QM/reports/dl089_prescreen/manifest_20260905T090852515536Z.json`, SHA256 `58ab29aaf03da31453c3678b6dfd4c1f1ac5410114191e4e7731c8371f2be9ca`; D1 SHA256 `105aa27a6d0aff0818b9b76b0eb081d917ea8fb90ec077b599a33ea65ab12f13`.
- GBPUSD: `D:/QM/reports/dl089_prescreen/manifest_20260905T090908910737Z.json`, SHA256 `c309e81f411fa7d5f34ad72d3bfb7de41faddb0a628e35e5a703c765e228814a`; D1 SHA256 `c354b33f801382b8cc508180238c1d4d04e1d743d5d76f1ce7f0634f3ce5b5ea`.

## Activation and rollback handoff

Default `QM_DL089_PRESCREEN` is `0`. After CEO review and controlled integration, an explicit `QM_DL089_PRESCREEN=1` on the matrix-service process enables admission for eligible future work. Roll back with `QM_DL089_PRESCREEN=0`: previously missing cells use legacy admission, existing rows and skip receipts remain immutable, and no running job is touched. No service was restarted and no production environment variable was set during this task.

Disposition: **REVIEW — IMPLEMENTED_TESTED_NOT_ACTIVATED**. Main integration and production approval belong to Claude+OWNER close-out.
