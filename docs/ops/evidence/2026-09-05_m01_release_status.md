# M01 release status — 2026-09-05

Task: `40812f0b-a7db-41a4-a5ec-1a02eb8608c6`. Status: REVIEW. Read-only canonical snapshot: 2026-09-05T12:29:58.586479+00:00.

Reference census, the new independent fast projection, builder population and physically bound bundle all return **8 pairs**. There are **9** terminal closure rows: EURUSD has two. The obsolete PASS-only diagnostic returns **7**, excluding QM5_11910 NZDUSD; the OWNER-ratified Q08 FAIL_SOFT rule keeps it in the authoritative population. No gate rule changed.

The existing book guard refuses: 8 < 25 qualified pairs and no matching OWNER book order. All eight scores match their current sealed stream bytes; they are screening values, each below 1, and establish no release economics. Each stream was re-sealed after its selected terminal closure. Exact parent-chain attestation and native operational acceptance remain unproven.

| Pair | Terminal binary (prefix) | FUND_SCORE | Missing witness bytes | Binary unmatched gates | Declared data window |
|---|---|---:|---|---|---|
| QM5_10706 GBPUSD.DWX | eaffda6f03c8 | 0.106901 | Q03, Q04, Q05, Q06 | Q03, Q04, Q05, Q06 | 2020 to 2022 |
| QM5_11421 EURUSD.DWX | 9dd7facd1da7 | 0.015577 | Q02, Q03, Q04, Q05, Q06 | Q03, Q04, Q05, Q06 | unknown to unknown |
| QM5_11422 USDCAD.DWX | 2b98e9e90231 | 0.157708 | Q02, Q03, Q04, Q05, Q06, Q07 | none observed | 2017 to 2022 |
| QM5_11910 NZDUSD.DWX | e18d477e63c4 | 0.094695 | none observed | none observed | 2018.07.02 to 2022.12.31 |
| QM5_13054 XTIUSD.DWX | 2e65488fccdb | 0.024265 | none observed | Q04, Q05, Q06, Q07 | unknown to unknown |
| QM5_1537 XAGUSD.DWX | 142a019e773a | 0.131237 | none observed | Q04, Q05, Q06, Q07 | 2017 to 2022 |
| QM5_20048 XTIUSD.DWX | 1312391ad7e6 | 0.032985 | Q02, Q03, Q04, Q05, Q06 | Q06 | 2017 to 2022 |
| QM5_21505 XAGUSD.DWX | 395c4747832a | 0.123500 | none observed | Q02, Q04, Q05, Q06, Q07 | 2017 to 2022 |

Data windows are declarations, with their original precision retained. The archive manifest identity is recorded but archive bytes were not revalidated. Witness selection prefers a matching terminal binary and otherwise exposes a historical witness; neither outcome proves an exact set/data/parent chain. Missing witness bytes are explicit research evidence risks, not retroactive gate verdicts.

`CONTIGUITY_CONTRACT_V1.md` and `2026-09-05_m01_release_status/release_status.json` hold the contract and all per-pair identities, evidence paths/hashes, uncertainty flags, responsible roles and next actions. The report grants no build or deployment authority. No standalone historical fast-census executable was located; its replacement parity projection is named explicitly.

Verification: 26 focused tests pass, including the 7/8/9 fixture, version translation, informational news rejection, wrong-gate FAIL_SOFT, invalid evidence, and a complete fixture projection with identical database bytes before/after. The canonical CLI completed read-only with reference/fast equality. The first test run exposed a missing required census argument; this was corrected. Phase/version lookups are cached per invocation to avoid repeated manifest reads.

All new ops artifacts use the canonical evidence directory as required by this scheduled cycle. Code and artifacts are committed only on agents/board-advisor; leave the task in REVIEW.
