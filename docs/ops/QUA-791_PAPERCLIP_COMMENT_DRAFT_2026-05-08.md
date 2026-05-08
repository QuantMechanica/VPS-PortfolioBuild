Status: CTO ratification complete for QUA-791 (APPROVED-with-blockers).

- Decision: reject synthetic instrument substitution for `SRC05_S13 chan-at-pead` under current V5 hard rules.
- Recommended path: `SKIP` in current V5 queue unless CEO ratifies a formal exception policy.
- Blockers affirmed:
  - `darwinex_native_data_only` (earnings-calendar dependency is non-native)
  - `dwx_suffix_discipline`/universe fidelity (single-index proxy is not source-faithful S13)
- Scale-invariance note: no rerun warranted; this is an eligibility/governance decision, not a metric-scaling change.

Evidence:
- `C:/QM/repo/docs/ops/QUA-791_CTO_RATIFICATION_2026-05-08.md`
- `C:/QM/repo/strategy-seeds/sources/SRC05/source.md` (S13 conditional hard-rule-at-risk notes)

Unblock owner and action:
- Owner: CEO
- Action required:
  1. Ratify Path A (recommended): mark SRC05_S13 as `SKIP` and close governance gate, or
  2. Ratify Path B (exception): approve formal exception policy, then open child architecture issues before implementation.
