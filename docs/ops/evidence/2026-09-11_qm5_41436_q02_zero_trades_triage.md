# QM5_41436 Q02 Zero-Trades Triage

Date: 2026-09-11

The governed Q02 work item `ae5f4df7-e2ac-437d-b736-b99e5b635c6c` completed with
`ZERO_TRADES`. This is not a PASS and is not treated as an automatic strategy rejection.

## Bound Execution

- Window: 2018-07-02 through 2022-12-31
- Route: `XTIUSD.DWX`, D1, Model 4; real-tick marker present
- Source SHA-256: `2272eaa66d1ff84050c9a39f45c2937f9d5605843c95025794d44f1c42637cc6`
- EX5 SHA-256: `36b99f86771e817486894df4e37399306d5a4281d3d6e369b547092ebda43054`
- Set SHA-256: `64eeb70a1434ed905054e18b10db8e1057d1aea1b371e53f354785e6dd5699d2`
- Report SHA-256: `594abcfca2380a14ff56e48473803a7421e46a60a43cc82d0f9103befaa05dc7`
- Authenticated logger sample SHA-256: `57607f542143f7fdc96ff28e7268636dd1598c522c127316656b834b00d11be9`
- Summary: `D:/QM/reports/work_items/ae5f4df7-e2ac-437d-b736-b99e5b635c6c/QM5_41436/20260911_085944/summary.json`

## First Failed Layer

Harness identity is stable, the report is nonempty, the requested route/window is present, the
deployed EX5 and set match their sources, initialization succeeded, and the history warm-up loaded.
The first failed layer is therefore the entry hook: 1,174 authenticated logger events contain zero
`STRATEGY_STATE` decision markers, zero signal-fire markers, and zero order attempts. The exact
clock rejection cannot be proven because the current EA emits diagnostics only after the decision
clock accepts a bar. Label-offset rejection is a hypothesis, not a finding.

No economics, threshold, session, stop, or parameter was changed. No retry was enqueued. A future
same-lineage repair requires bounded default-off decision-clock diagnostics, a governed recompile,
and the identical evidence-bound test; any mechanics change requires a new OWNER-approved card.

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_41436 | `ae5f4df7-e2ac-437d-b736-b99e5b635c6c` | unresolved no-decision-marker failure at entry hook | none | Q01 `COMPILE_OK`, 0/0 | 0 | 0 | instrument decision clock; identify first reject; identical bound rerun; all later pipeline and portfolio gates |

No `T_Live`, AutoTrading, live/deploy manifest, portfolio gate, or portfolio admission action was
taken.
