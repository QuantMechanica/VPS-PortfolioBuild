# Multi-symbol step 1 — governed execution

Date: 2026-07-27

Both arms compiled serially in one current-tree session with 0 errors and 0
warnings. QM5_20181 SHA256:
`60EE13B7828CA2DDDA11A1264CB2391EA2283DA9AF034915895D3DE4852221F9`.
QM5_9936 SHA256:
`5ACDAB8737C9579107CB7D2C05AC44034CC9FF9B368C13A8D5061255C29E3CD4`.

Full-window Model-4 USDJPY.DWX/H1 runs were submitted to the governed queue:

- joint runner: `a343f66e-d9c7-4965-81ac-f1e70166cb75`
- standalone: `588af557-300f-4e25-82a4-81974b04380a`

Both use exact 2017.01.01–2025.12.31 bounds, a 150-minute inner budget,
`RISK_FIXED=1000`, and `RISK_PERCENT=0`. No terminal was manually launched.

Three-way comparison remains pending durable completion of both governed runs:
runner versus same-vintage standalone (gate 1.0), standalone versus archive,
and runner versus archive. No premature fidelity or vintage verdict is claimed.

