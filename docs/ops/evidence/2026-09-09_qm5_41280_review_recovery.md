# QM5_41280 stale review-gate recovery

- Recorded: 2026-09-09
- EA: `QM5_41280_usdchf-ww-shift-tr`
- Router build task: `317b4d6a-3338-4603-8006-a4660ad6d5f1`
- Current compile work item: `ab67b01f-07e9-4133-8fce-0ebf43d8336f`
- Scope: non-live USDCHF diversity-funnel handoff only

## Finding

The build task remained `BLOCKED` on its 2026-09-02 pre-compile checkpoint even
after the governed compile successor completed on 2026-09-06. First-Q02 intake
therefore refused with `review_entry_gate_blocked`; this was stale task state,
not a current source, binary, setfile, or input-pin failure.

The current compile evidence records `compile_result=PASS`,
`build_check_result=PASS`, zero compile errors, zero compile warnings, and EX5
SHA-256
`05963c77914ebe36c7c68a0bfa27420a91dea1f7f83fa18e7bc6d543fafd7fe6`.
The canonical MQ5 SHA-256 is
`75fd627e5961fe144429bfc61162bbd2f724bbbd3fb23d21d894abcdfca7523c`.
Both files and the canonical `USDCHF.DWX` D1 backtest set are tracked and clean
at the branch HEAD.

The binding PACER audit was rerun against the exact MQ5 before this handoff:

```text
predicate=EA_FRAMEWORK_INPUT_PINNED
ok=true
hit_count=0
```

The setfile retains the approved backtest risk contract:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Disposition

The hash-bound build identity is preserved in
`docs/ops/evidence/2026-09-09_qm5_41280_build_identity.json`. The canonical
router may now move the existing build task to independent review. Q02 remains
blocked until that review is accepted; no duplicate compile or Q02 work item is
authorized by this receipt.

No tester was launched. No terminal, portfolio gate, deploy manifest,
`T_Live`, or AutoTrading state was touched.
