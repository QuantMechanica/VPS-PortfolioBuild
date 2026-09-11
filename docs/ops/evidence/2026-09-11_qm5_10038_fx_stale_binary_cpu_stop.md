# QM5_10038 FX stale-binary recovery — CPU ceiling stop

Date: 2026-09-11
Branch: `agents/board-advisor`
EA: `QM5_10038_ff-4x25ema-mtf-h4`
Farm task: `19a2692f-020e-4d5c-a0fd-76011c9b51f4` (`infra_repair`, active)
Outcome: **STALE-BINARY CAUSE ISOLATED; REQUALIFICATION DRY RUNS ELIGIBLE;
NO Q02 WORK ENQUEUED BECAUSE THE PACER CPU CEILING WAS HIT**

## Diversity selection and collision control

No eligible unclaimed priority-1 diversity build remained. The only newly
incomplete build candidate already had an open compile work item, older pending
build rows had either reached Q02+ or lacked mandatory prerequisites, and the
first priority-2 candidate (`QM5_10269`) gained a Q02 successor during the
pre-claim backup. Its atomic claim correctly refused.

`QM5_10038` was then selected as the next distinct low-frequency structural FX
recovery. The APPROVED card defines H4 four-timeframe EMA alignment with an
expected 20-45 trades/year/symbol. An atomic collision recheck found no open
`infra_repair` task and no pending/active Q02, Q03, or COMPILE_EA row before the
exclusive claim was inserted.

Pre-claim online SQLite backup:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10038_oninit_claim_20260911T105100Z.sqlite`

Backup SHA-256:
`cb7a10bb1a87a2d6556d2d2643c47f2ee7c84c10bd46a6d1b9c13112fc334788`.

## Bound failures and root cause

The three immutable Q02 failures are:

- `447bd7e4-7176-483a-8df6-1ed6c4ea68c2` — `NZDUSD.DWX`, slot 7;
- `d49c771b-bc51-474b-a968-7b4633f56b10` — `USDCAD.DWX`, slot 10;
- `50ffaa26-5159-4804-accf-cdd1f92a997a` — `USDCHF.DWX`, slot 11.

All report `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS` and bind the same old
2026-06-21 EX5 SHA-256:
`61833c537bb10b731ea9c63717ccea8b720d91cf8c671fa469d2ebe06a313891`.
The three slots were added to `magic_numbers.csv` on 2026-08-23, after that
binary was compiled.

The current 2026-09-09 binary SHA-256 is
`bbd1786046941d20cb33f618bf1143c537058aad14f900ede5dcb6428fa1b0b3`;
its source SHA-256 is
`a2ab7f4f493be1528312f7b649febf7da0e61cebb504a60d0ec280c652fbbb66`.
Work item `5599a328-80cf-465d-bcf1-b4fbfc54843a` proves this current binary
initializes and completes Q02 on newly added `AUDUSD.DWX` slot 4 with 201
trades. The affected setfiles retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
the registered slot offsets. This is stale compiled-resolver infrastructure,
not missing history, a strategy defect, or an economic zero-trade result.

## PACER guard and dry-run evidence

Before any contemplated queue mutation, the binding audit ran against the
absolute source path:

`python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_10038_ff-4x25ema-mtf-h4/QM5_10038_ff-4x25ema-mtf-h4.mq5"`

Result: `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.

`farmctl requalify-q02 --dry-run` returned `eligible=true`,
`would_enqueue=true`, and `parameter_change_count=0` for each of the three
failed work-item IDs. Each dry run recovered the exact historical setfile bytes
and bound the current EX5/source hashes above.

The immediate CPU sample was `100, 100, 93, 76, 85` percent (average 90.80%,
peak 100%) with five `terminal64` processes. The binding 97% ceiling was hit.
Therefore no `--apply`, Q02 enqueue, compile enqueue, tester process, or
backtest was started.

## Next action

When a later paced turn measures CPU below the ceiling, revalidate that this
farm task is still the exclusive open repair and that no successor exists, run
the source-pin audit again, repeat the three `requalify-q02 --dry-run` checks,
then apply exactly one append-only Q02 successor for each failed identity using
the current EX5 hash above. Preserve the failed rows as evidence.

## Safety boundary

No EA source, setfile, registry, framework include, portfolio gate, T_Live
manifest/process, AutoTrading setting, live artifact, or certification verdict
was changed.
