# Multi-symbol step 1 — governed execution

Date: 2026-07-27

## Controlled build

Both arms were compiled serially in the same session from the current canonical
tree and include tree. Each compile returned 0 errors and 0 warnings.

- QM5_20181 runner SHA256:
  `60EE13B7828CA2DDDA11A1264CB2391EA2283DA9AF034915895D3DE4852221F9`
- QM5_9936 standalone SHA256:
  `5ACDAB8737C9579107CB7D2C05AC44034CC9FF9B368C13A8D5061255C29E3CD4`

## Governed work items

Both full-window Model-4 runs were submitted to the persistent terminal-worker
queue with priority-track and basket-Q02 dispatch metadata, exact
`2017.01.01`–`2025.12.31` bounds, USDJPY.DWX/H1 setfiles, and a 150-minute inner
budget:

- joint runner: `a343f66e-d9c7-4965-81ac-f1e70166cb75`
- standalone: `588af557-300f-4e25-82a4-81974b04380a`

The setfiles satisfy the build guardrail (`RISK_FIXED=1000`,
`RISK_PERCENT=0`). No terminal was launched manually, reserved factory work was
not interrupted, and neither T5 nor T_Live was touched.

## Three-way comparison

Pending governed-run completion. The required comparisons are:

1. runner-only versus same-vintage standalone (fidelity gate: 1.0);
2. standalone versus archived `9936_USDJPY_DWX.jsonl`;
3. joint runner versus the archive.

No comparison verdict is asserted before both durable worker artifacts exist.

