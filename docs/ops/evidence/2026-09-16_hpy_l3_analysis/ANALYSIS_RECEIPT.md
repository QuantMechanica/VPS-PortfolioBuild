# H-PY L3 root-cause analysis — evidence receipt (2026-09-16T06:44Z)

**Authority:** Kimi research role under the interim OWNER delegation
(OWNER_DIRECT_SESSION_DELEGATION 2026-09-15/16). **Scope:** research-design
analysis for the Family-A bounded-pyramiding candidate H-PY
(QM-RESEARCH-2026-0007, QM5_41479). No commits (central pass), no registry
rows, no farm/DB/terminal writes. The 0007 preregistration stays sealed
(record_sha256 `f601ba6a43beeadb14104114a07988fe2d4445b4e9e1731cfebf7f6b8866cfcb`,
re-verified unchanged after all work). The frozen 2021-2024 holdout was not
read at any point (all computations ran on the 2018-2020 in-sample feed).

## Commands
- `HPY_OUT=.tmp/hpy_repro_5896.json python strategy-seeds/sources/QM-RESEARCH-2026-0007/h_py_pilot.py` — deterministic reproduction of the frozen pilot.
- `python strategy-seeds/sources/QM-RESEARCH-2026-0007/h_py_l3_analysis.py` — instrumented replay + 5 single-rule counterfactuals (`h_py_l3_analysis.json`).
- `python strategy-seeds/sources/QM-RESEARCH-2026-0008/h_py2l_pilot.py` — two-level variant pilot with parent consistency check.
- `python tools/strategy_farm/research/mechanization_check.py strategy-seeds/sources/QM-RESEARCH-2026-0008/H_PY2L_card.md --research-json strategy-seeds/sources/QM-RESEARCH-2026-0008/research.json` — MECHANIZE gate.
- `python tools/strategy_farm/research_source.py mint/remint path` (via driver, parent_version_id=QM-RESEARCH-2026-0007, version=2), `preregister.build_preregistration/write_preregistration`, `research_source.py seal QM-RESEARCH-2026-0008 --status preregistered`, `research_source.py verify`.
- `python tools/strategy_farm/strategy_risk_contract.py` validation handle — `validate_contract=[]`, `is_unbounded=False` on the 0008 contract.

## Results
- **Reproduction:** fresh pilot output byte-identical to the committed
  `h_py_pilot.json` (sha256 `12b3eec3a15fc8b5421b8f59aade9a4aaed5858c5e7c8a7419570671f1f5639d`).
- **L3 root cause (classification a):** structural, not statistical. Entries
  fill 17:00-18:00 UTC; earliest L2 fill is the 19:00 bar; adds may not fill
  into the flatten-hour bar (20:00); L3 may only trigger on a bar strictly
  after the L2 fill. All 22 L2 fills were at 19:00; 10 of 22 closed ≥ +2.0 ATR
  on that very bar and 3 more met +2.0 ATR on the L2 trigger bar — the price
  condition was satisfied 13 times, the fill barred 13 times. Counterfactuals
  (no giveback / no trail / no time stop / no flatten exit / shock-skips off)
  all still produce 0 L3 fills. Giveback vs trail: giveback tighter on 12/22
  L2 baskets below +2.43 ATR peak (corridor arithmetic), but neither binds
  before the clock. Full detail: `strategy-seeds/sources/QM-RESEARCH-2026-0007/ANALYSIS.md`.
- **0008 minted** (variant lineage, parent 0007): Family A bounds tightened,
  never widened — `max_levels` 3→2, progression [1.0,0.75,0.5]→[1.0,0.75]
  (aggregate 2.25→1.75 legs), `add3_trigger_atr`/`level3_size_mult` removed,
  all other rules identical to the frozen 0007 card. Mechanization gate PASS
  (23 bounded parameters, zero findings, numeric provenance backed,
  codex_implementable=true). Preregistration record_sha256
  `c4f63ce4055df1b1fc3331571063cb35605559f317ee3779a81bd74ac97084db`.
  Two-level pilot reproduces the parent pilot exactly (consistency check
  all_match over baskets/L2/exit mix/r_sum).
- **Card copy:** `artifacts/cards_approved/QM5_41480_tail-pyramid-2lvl-index-session-h1.md`
  — G0 APPROVED under the delegation, review_status REVIEW_PENDING (critic
  seats gated). ea_id 41480 verified free (zero references anywhere in the
  repo) before writing; **no registry row allocated** (filename-convention
  reservation, matching the 41479 card convention).
- **Verify state:** 0008 `research_source verify --card` resolves and hash-
  binds; the only findings are the empty critic-skeleton fields — identical
  expected state to 0007/0006 (cross-vendor critic PENDING by design).

## New-file inventory (sha256)
```
6124fc3c392258aea2dcf6eab5838a6f6c48242427205d47491347fa7337b3eb  strategy-seeds/sources/QM-RESEARCH-2026-0007/h_py_l3_analysis.py
e31dfa6f787c00f44269f63bd69cf1044e1ae8ebc5c4564955e21b8b173ed85e  strategy-seeds/sources/QM-RESEARCH-2026-0007/h_py_l3_analysis.json
1e580fc342df4304e1e5b9fe6d34d798b0ec9bc33b76fe5c8e9d6eb0151a0be8  strategy-seeds/sources/QM-RESEARCH-2026-0007/ANALYSIS.md
b8a85a485999e7a2078f538e87dd2a6e34813f84e8396799f6821e90c06f681b  strategy-seeds/sources/QM-RESEARCH-2026-0008/H_PY2L_card.md
73f8cdd1b1f4cf5b316bab17a5b86959e1be26df8eb3ec14834643767918609c  strategy-seeds/sources/QM-RESEARCH-2026-0008/h_py2l_pilot.py
5182b64f874d8ff144f8cdcbf2a8622c559e4112cb5aeb13c2301e781d6b0b74  strategy-seeds/sources/QM-RESEARCH-2026-0008/h_py2l_pilot.json
ca37b646d8c50f9d405456f7768a9645a7895148ac8e5a17b2e9f92339f7c1c7  strategy-seeds/sources/QM-RESEARCH-2026-0008/risk_contract.json
2f8ca44acf724f53ac560762a854556e0550abd363ddf48dd2d3a3b3122e2674  strategy-seeds/sources/QM-RESEARCH-2026-0008/mechanization_result.json
7501c62b9a8046c12156c12242e6a246ae7d44279018c3b03c5766093e7a1976  strategy-seeds/sources/QM-RESEARCH-2026-0008/preregistration.json
91dd994d662e8feee88fb17ca67888a323c3adaeeffdbeb86c03b641c8fc50de  strategy-seeds/sources/QM-RESEARCH-2026-0008/source.md
0708c41ef32c249ff40bd04327f65e36b09271878d7aa2c637e20a0e0f63a51e  artifacts/cards_approved/QM5_41480_tail-pyramid-2lvl-index-session-h1.md
```
(plus 0008 research.json / lineage.json / critic_receipt.json sealed inside
the 0008 store; 0007 store gained only the three analysis files above — its
sealed files are byte-untouched.)

## Notes
- Ledger: three rows appended for QM-RESEARCH-2026-0008
  (`draft mint` v2, `preregistered` v1, `preregistered status_change` v2) in
  `D:/QM/reports/state/research_source_ledger.jsonl`; no other ledger writes.
- The joint-tail stream candidate list for the wave-2 engine is in
  `joint_tail_stream_candidates.md` (same content as ANALYSIS.md §7).
