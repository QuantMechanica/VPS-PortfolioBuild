# QM5_41454 XAU/XAG NR2 Body Momentum - Q01 PASS / Q02 CPU Stop

Date: 2026-09-12

The new market-neutral commodity sleeve identity is QM5_41454_xauxag-nr2-body-mom. It trades
only a synchronized XAU/XAG equal-notional basket after a strict two-week log-ratio range
contraction, continuing the strict newest completed ratio-week body for one week. It is distinct
from the adjacent WR2/body continuation, NR2/body reversion, NR2/CLV continuation and reversion,
and WR2/CLV continuation identities.

## Deterministic Gates

- Card schema/ML lint: PASS.
- PACER input-pin audit before compile enqueue: PASS, EA_FRAMEWORK_INPUT_PINNED hit count zero.
- Reference suite: 6 tests PASS.
- Governed compile work item: 78dda301-df4d-4fee-9d98-2f8f5fe6e245 on T1.
- Compiler: PASS, zero errors and zero warnings.
- Strict build check: PASS, zero failures and three non-gating optional-card warnings.
- MQ5 SHA-256: f8d3e2b93960f19cbd768df6ed16153af77a3e873be74cec21faa4001d9af2bc.
- EX5 SHA-256: 776f5057cb63e26f90d1ed58ae5612b845eeacec5f92900cea6d1c81649d9529.
- Q02 intake dry run: eligible; logical basket, both active magics, and all three fixed-risk
  presets passed admission.

## Q02 Stop

The mandatory whole-host CPU sample was 85.6, 94.5, 95.6, 98.1, 97.1%: average 94.18%,
maximum 98.1%, above the 97% ceiling. Q02 therefore stopped without an apply call or work-item
creation.

No manual backtest, terminal control, portfolio-gate edit, T_Live, deploy/live manifest,
AutoTrading, or live action occurred.
