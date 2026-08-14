# QM5_1626 FX Q02 stale compiled-resolver repair

Date: 2026-08-14  
Branch: `agents/board-advisor`  
EA: `QM5_1626_hopwood-bermaui-stoch-h4`  
Disposition: `REPAIRED_AND_ENQUEUED`

## Outcome

The unchanged approved MQ5 was force-recompiled against the current synchronized
V5 include tree, all four existing H4 backtest presets were sealed by the strict
build check, and exactly one EURUSD.DWX Q02 successor was enqueued through the
guarded append-only repair path.

No entry, exit, sizing, filter, symbol, timeframe, or strategy parameter was
changed. This is an infrastructure repair and Q02 handoff, not evidence that the
strategy is trade-capable or qualified.

## Selection and coordination

- Priority 1 had no eligible non-duplicate low-frequency diverse build whose
  approved card, EA allocation, magic rows, and absent EX5 all satisfied the
  standard build gate.
- This was the only current unclaimed low-frequency diverse-FX EA whose latest
  Q02 result was infrastructure-only rather than economic.
- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1626_hopwood-bermaui-stoch-h4.md`.
  It records `g0_status: APPROVED`, R2-R4 PASS, H4 operation, 12 expected
  trades/year/symbol, and fixed deterministic Bermaui-Stochastic/D1-regime
  mechanics with no ML, grid, or martingale.
- Farm claim: `666727b4-6938-466f-8bd9-fa4100d0bd49`, type/state
  `q02_infra_repair / IN_PROGRESS`, assigned to
  `codex:agents/board-advisor` after an atomic collision recheck.
- Pre-claim online DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1626_q02_stale_resolver_claim_20260814T194849Z.sqlite`.

## Bound failure and first failed layer

The retained source work item is
`4e6af0f9-f6d8-474d-80fb-5f155bb38a2b` (`Q02`, `done / INFRA_FAIL`).
Its canonical evidence path, as bound in the farm row, is:

`D:\QM\reports\work_items\4e6af0f9-f6d8-474d-80fb-5f155bb38a2b\QM5_1626\20260811_170200\summary.json`

Evidence SHA-256:
`45f1544705856aa8430af545c04053eeef3f25d73cd728d612001c2b6e43da91`.

The execution identity was stable throughout the failed run:

- MQ5 SHA-256:
  `0e00c0dd9b35b0b69b001187bd3faf016b3123611cf40bd57f9804a8b5141211`;
- old EX5 SHA-256:
  `10fd465da8d8b2bc64068c624b32a2a0ee61654feede1a037717667a5bf11e6b`;
- old EURUSD setfile SHA-256:
  `ae3a71399923501afbf71145c2d55e452698ac72f1a24985ced62a96e3341980`;
- actual test identity: `EURUSD.DWX / H4`, real ticks,
  `2022-07-01..2022-12-31`.

The tester synchronized history and real ticks successfully before initialization.
`D:\QM\mt5\T8\Tester\logs\20260811.log:73838` then records:

`EA_MAGIC_NOT_REGISTERED: ea_id=1626 slot=0 magic=16260000`

Line 73839 immediately records the non-zero `OnInit` stop. The report therefore
had zero bars and zero trades because setup failed; it is not a strategy verdict.

The active registry and generated resolver both contain the exact four authorized
tuples `1626 / slots 0..3 / magics 16260000..16260003`. The resolver dry-run kept
15,958 rows, dropped none, and produced canonical registry SHA-256
`0C59C6D012CD277374FBEE28CE6D01C26BFA8BF8BF7549B6BE90DE33FB28A5E7`.
The old binary's runtime behavior was therefore inconsistent with the canonical
mapping—a stale or mis-synchronized compiled include binding—not missing history
or an entry-rule defect.

## Repair and verification

`compile_one.ps1 -Strict` force-deleted the old binary before compiling, synced
the current framework includes into the build terminal trees, and rebuilt the
unchanged source.

- Compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260814_195317\QM5_1626_hopwood-bermaui-stoch-h4.compile.log`.
- Compile-log SHA-256:
  `62cb2323a840cc4ad45d899c63d50bd42cbbf10d73ff7a71963601e2fe364b61`.
- MQ5 SHA-256 remained
  `0e00c0dd9b35b0b69b001187bd3faf016b3123611cf40bd57f9804a8b5141211`.
- Rebuilt EX5 SHA-256:
  `787e0b05c68e63e2cf4961dac1445caa251dd29a36752ab4b8bf15a1f6e0a22c`.
- Rebuilt EX5 size: 383,080 bytes.
- Approved-card build guard: PASS.
- SPEC validation: PASS.
- Build guardrails: PASS, zero findings.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero leaks.
- EA-scoped strict build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260814_195505.json`.
- Artifact commit:
  `dae9a48fc426e58244197e2bb269fdde366cd4c7`.

The four existing backtest presets remain H4 and retain `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and their registered magic slots. The queued EURUSD preset
SHA-256 is
`a911f5f5656df8e149b0022cf28cce0f81ceccf6161dfb2a076c43ccdc419f94`.

## Append-only Q02 handoff

At the binding capacity check, only T8 was executing factory work (1 of the
configured 7-job ceiling). No terminal was stopped or manually dispatched.

The governed `farmctl.append_only_exact_row_rerun` path preserved the failed
source row and created exactly one successor:

- successor work item:
  `733f6c43-795f-436c-85c8-e0a357ed9f75`;
- initial state: `pending`, unclaimed, attempt 0;
- symbol/timeframe: `EURUSD.DWX / H4`;
- predecessor: `4e6af0f9-f6d8-474d-80fb-5f155bb38a2b`;
- expected EX5 SHA-256:
  `787e0b05c68e63e2cf4961dac1445caa251dd29a36752ab4b8bf15a1f6e0a22c`;
- expected MQ5 SHA-256:
  `0e00c0dd9b35b0b69b001187bd3faf016b3123611cf40bd57f9804a8b5141211`;
- expected setfile SHA-256:
  `a911f5f5656df8e149b0022cf28cce0f81ceccf6161dfb2a076c43ccdc419f94`;
- risk binding: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- `repaired_infra_rerun=true` and
  `historical_work_item_preserved=true`.

The paced dispatcher owns execution. No local smoke was started.

## Zero-trades recovery record

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_1626 | `4e6af0f9`, EURUSD.DWX H4, 2022-07-01..2022-12-31 | Compiled artifact rejected registered slot 0 during `OnInit`; setup failed after healthy history/tick sync | Force-rebuild unchanged MQ5 against synchronized current includes, seal four fixed-risk presets, append one exact Q02 successor | PASS, 0 errors / 0 warnings | Pending Q02 | Pending Q02 | Must produce a valid artifact-bound Q02 report with plausible trades, then pass Q04 and every later gate |

## Safety boundary

No `T_Live` file or process, AutoTrading setting, live setfile, deploy manifest,
portfolio gate, or portfolio KPI artifact was changed.
