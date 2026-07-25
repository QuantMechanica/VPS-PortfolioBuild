# QM5_9926 FX Q02 infrastructure repair and requeue

Date: 2026-07-25  
Branch: `agents/board-advisor`  
EA: `QM5_9926_ff-riverband-sop-m5`  
Outcome: repaired build package; one evidence-bound EURUSD Q02 work item is pending

## Why this unit

The available diverse build backlog was either already claimed or blocked by unavailable `.DWX`
instruments, so this unit used mission priority 2. `QM5_9926` is an approved FX candidate, unlike
the index/metal/energy concentration among the current late-gate survivors. Its G0 card records
R1-R4 PASS for a named ForexFactory source and a fixed, closed-bar liquidity-sweep/BOS state
machine with no ML, grid, martingale, or averaging. The declared cadence is 80 trades per
symbol/year, about 1.5 trades per week per symbol, with one active position per magic-symbol.

## Collision controls

- Agent task claim: `7158b874-786a-4047-b0b8-53e80e691d23`
- Claim key: `manual:codex:agents/board-advisor:QM5_9926:q02-infra-repair`
- Pre-claim DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_9926_claim_20260725T092529Z.sqlite`
- Pre-requeue DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_9926_q02_requeue_20260725T093755Z.sqlite`
- The transactional requeue required the claim to remain `IN_PROGRESS`, found no other open
  `QM5_9926` agent task, and found no other pending/active work item.
- A prior failed row was reset with compare-and-swap instead of creating a second open row:
  `c92e548b-9ca1-452d-ab7d-5ea4835f8ba4`.

## Diagnosis

The source failure row `aeaec6d2-38b7-49aa-918b-9e76ee96fb23` recorded
`run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`; a later orphan retry recorded
`summary_missing_retries_exhausted`.

The checked-in `.ex5` predated the current framework includes:

- pre-repair EX5: 280,808 bytes,
  SHA-256 `7a577515779ed3e4d0fd9b57c0b80a12a6d2ace265a593aef554d2b8d97976a8`
- MQ5: SHA-256 `2a810c7d61b0214e04ad4ddb0b80a321c2221851b65889ce91989a2fe10516af`
- the old setfiles had `card_defaults_source=not_found`, omitted `qm_ea_id`, and contained generic
  filter placeholders rather than the EA's declared strategy inputs

During the repair, the scheduled worktree janitor restored the tracked EX5 at 11:30 local before
it had been committed. A final strict compile was therefore run after the janitor, and that binary
was staged immediately. This transient cleanup event did not alter the queue until the final
binary hash was reverified.

## Repair

- Forced recompilation against the current V5 include tree.
- Regenerated all four backtest presets from the approved card/input defaults:
  EURUSD, GBPUSD, USDJPY, and XAUUSD on M5.
- Preserved fixed-risk backtest settings in every preset:
  `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Added `qm_ea_id=9926`, preserved unique magic offsets 0-3, and bound the actual Riverband
  strategy parameters.
- Requeued only EURUSD as the Q02 carrier, with evidence hashes and a ten-minute
  `launch_not_before_utc` delay so the branch commit precedes worker claim.

Final artifact bindings:

| Artifact | SHA-256 |
|---|---|
| EX5 | `f00206b0d682230cda0d424732d355d214f26a2bc897bd0736ef269d20306b05` |
| MQ5 | `2a810c7d61b0214e04ad4ddb0b80a321c2221851b65889ce91989a2fe10516af` |
| EURUSD set | `fcb58cc287f0343d62d49c265cf8d09a89273c2e737d62288d1bed4b1dc329a1` |
| GBPUSD set | `00c9e1b6ff763921ea7d80a7e58b177a022482c3dad176e68585c70275202e12` |
| USDJPY set | `49294035d681633c182f6aa8ffd08037628266fa2a674edb1594d14fdf47b3dc` |
| XAUUSD set | `5ae4c70265c3e5b1339d7e0befcae3907a4feaed5258bf796ff860a13ea1e909` |

## Verification

- Build check: PASS, 0 errors / 0 warnings.
  - compile log:
    `C:\QM\repo\framework\build\compile\20260725_092621\QM5_9926_ff-riverband-sop-m5.compile.log`
  - report:
    `D:\QM\reports\framework\21\build_check_20260725_092621.json`
- Final strict compile: PASS, 0 errors / 0 warnings.
  - compile log:
    `C:\QM\repo\framework\build\compile\20260725_093512\QM5_9926_ff-riverband-sop-m5.compile.log`
  - summary:
    `D:\QM\reports\compile\20260725_093512\summary.csv`
- Build guardrails at `2026-07-25T09:38:20Z`: PASS, five files checked, no findings.
- DB postcondition: exactly one pending/active `QM5_9926` work item; it is the EURUSD Q02 row
  above with attempt count 0, no claimant, `effective_min_trades=5`, and all three expected
  artifact hashes bound.

## Boundaries and remaining risk

No manual smoke/backtest was launched because other MT5 testers were active and the paced fleet
should own runtime capacity. Q02 is therefore the next runtime verification, not a strategy PASS.
No T_Live file, AutoTrading state, portfolio gate, deployment manifest, or live configuration was
touched.
