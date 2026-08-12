# QM5_11673 FX Q02 History-Lock Recovery

**UTC execution window:** 2026-08-12 22:35–22:42

**Branch:** `agents/board-advisor`

**Farm claim:** `ed7d3078-34d9-4a39-a38a-0ca09ef020ce`
**Disposition:** current-framework rebuild complete; one append-only EURUSD Q02 canary enqueued

## Selection

The live farm census found no unclaimed `TODO` or `BACKLOG` build task meeting the
mission's structural, low-frequency diversity constraint. After excluding EAs that
already had downstream evidence, `QM5_11673_tc-h1-s8-bb20-ema3-macd617-rsi` was the
highest-diversity unclaimed Q02 infrastructure case:

- approved mechanical H1 EURUSD/GBPUSD strategy;
- expected cadence 30 trades/year/symbol;
- 24 Q02 outcomes, all `INFRA_FAIL` and none economic;
- no Q03+ row, open work item, or prior agent repair claim.

The approved card is
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_11673_tc-h1-s8-bb20-ema3-macd617-rsi.md`.

## Diagnosis

The latest sealed predecessor is work item
`b22edf66-19f5-485c-ad2d-c51729a3faad`; its summary classified the run as
`ONINIT_FAILED;INCOMPLETE_RUNS` and bound the old EX5
`bd0de787cb094904956b5667e364fae2a77baf93522203369b96cf4ff267af6d`.

Retained T1 terminal journal evidence resolves the generic classification. At the
exact run start (`2026-07-28 19:37:57`), MT5 repeatedly emitted:

```text
History 'EURUSD.DWX' file opening or reading error [32]
```

Windows error 32 is a sharing violation. The failure occurred before a usable tester
context was created, so the missing tester-agent log and empty report caused the old
runner to label the failure as OnInit. There is no evidence of an EA parameter,
magic, or strategy-hook failure. The source still hashes to the predecessor's sealed
MQ5 hash.

The canonical setfiles were also obsolete build artifacts: both dated 2026-06-11,
used `build_hash: pending`, omitted `qm_ea_id`, omitted every strategy input, and
carried retired generic-filter keys. Those omissions did not authorize a strategy
change, but they prevented a clean current-artifact retry.

## Repair

- Left the approved `.mq5` strategy mechanics unchanged.
- Recompiled against the current V5 framework and magic resolver.
- Regenerated the EURUSD and GBPUSD H1 backtest presets with
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, the registered slots, `qm_ea_id=11673`,
  and all eleven explicit strategy defaults.
- Refreshed deterministic setfile build hashes.
- Recorded the artifact-only recovery in `SPEC.md`.

Current artifact bindings:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `424e546f121c48f9a4660c45790ee0575ff5861136283fbca3ed8463ec201f0d` |
| EX5 | `e38e996643bb8323d83098b3e990a2ec2e1d73d04b3407ca8bccba1b5da7cc99` |
| EURUSD H1 backtest set | `32cf3ecf81cd392a7b226da1dc0c75729d0414cebeadc7145280a5f74c659225` |
| GBPUSD H1 backtest set | `549cc53041a24cc4c988cdf7ae70b93e4ba3cb80a90fa7cabd3e846dd3f445f9` |

## Validation

- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings.
- `build_check.ps1 -EALabel ... -Strict`: PASS, 0 failures, 0 warnings.
  Report: `D:\QM\reports\framework\21\build_check_20260812_223955.json`.
- `validate_build_guardrails.py`: PASS, no findings.
- `validate_spec_doc.py`: PASS (1/1).
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, 0 violations.

## Q02 handoff

Immediately before enqueue, the farm reported 0 active work items and 0 running
factory terminals, below the ceiling of 7. `farmctl enqueue-backtest` then created
exactly one authenticated append-only successor:

| Field | Value |
|---|---|
| Work item | `81037b0f-058e-4f94-acc2-b6c5b5f84094` |
| Phase / host | `Q02` / `EURUSD.DWX` H1 |
| Initial state | `pending`, attempt 0, unclaimed |
| Rerun of | `b22edf66-19f5-485c-ad2d-c51729a3faad` |
| Reason | `CURRENT_FRAMEWORK_REBUILD_AND_CUSTOM_HISTORY_SHARING_VIOLATION_RECOVERY` |
| Risk binding | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

The predecessor remains unchanged. The factory worker will perform Custom-history
copy-on-claim isolation before execution. No tester was launched manually.

## Safety boundary

No T_Live path, AutoTrading setting, portfolio gate, deploy manifest, live setfile,
or framework include was modified.

Farm DB backups:

- `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11673_q02_claim_20260812T223541Z.sqlite`
- `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11673_q02_enqueue_20260812T224156Z.sqlite`
