# Pattern-include runtime equivalence — acceptance escalation

- Router task: `9e707406-eedc-47b7-a3b3-d60a1bffe3c9`
- Date: 2026-08-26
- Branch/check-out of record: `agents/board-advisor`, `C:/QM/repo`
- Integration commit: `b0bdc4d72f23876398b707db72450a560718ef4a`
- Runtime acceptance: **NOT PROVEN**
- Operational recommendation: **STOP ordinary post-integration compile release until an exact retained pre/post pair passes the comparison below**

## Outcome

No byte- or field-exact before/after trade-list equality is claimed. The
available evidence cannot form the required executable pair: ordinary EAs
compiled after the integration have no completed pre-integration run with the
same set/window/model, while the one strongest historical candidate has its
pre-integration EX5 retained but not its governed post-integration EX5.

This is an evidence-chain deviation, not an observed trading-behaviour
deviation. It is escalated fail-closed because the requested runtime acceptance
cannot be reconstructed from hashes alone. Static no-op reasoning remains green
but does not authorize continued rollout.

## Compile/run census

The task payload referenced 52 `COMPILE_OK` rows. A read-only query at execution
time found 53 rows on 2026-08-26 (one later compile explains the moving count),
of which nine completed strictly after the integration commit time
`2026-08-26T10:36:25Z`:

| EA | Governed post EX5 SHA-256 | Completed UTC | Classification |
|---|---|---:|---|
| `QM5_12946` | `e29db930256711e1ce62c3501fcfc33937f9c69852305669c976211fb0909b2f` | 11:04:23 | ordinary common integration; no completed Q02 row |
| `QM5_12954` | `55994bc9636c6342285cba07e4dc11c3826ed679fb12db3473c61847e9a27ad5` | 11:07:10 | ordinary common integration; no completed Q02 row |
| `QM5_35005` | `59d116784db396fd081175503e6e43b154593925d781e01bb18bc8a9f2f95750` | 11:10:55 | ordinary common integration; historical candidate examined below |
| `QM5_36002` | `4f3f158c0d74e3c37d2293352137ba40c85b9c3bbfbde17fcdb1d4d1694616c7` | 11:16:07 | ordinary common integration; no completed Q02 row |
| `QM5_41133` | `54756684a45ec484107dc4756f413debed05ca14284c3da0085ad28170843628` | 11:19:06 | ordinary common integration; no completed Q02 row |
| `QM5_41136` | `447105f6ca3cf049edc98a0a07daf7e533c8105e34d7a31638355f1b19cf6c6c` | 11:24:01 | ordinary common integration; no completed Q02 row |
| `QM5_41161` | `d96c7435d66cd16bb8ad778f53abcbb51e81a37628dd29a925208ce4550417d5` | 11:34:10 | pilot, `QM_PATTERN_PERMISSION_EA_MANAGED`; not an ordinary-path proof |
| `QM5_41162` | `32ac75db71c957ea78fd65f34a3468f9241f91bc4a8ca05c1526b3b1fdcc1ccc` | 11:34:59 | pilot, `QM_PATTERN_PERMISSION_EA_MANAGED`; not an ordinary-path proof |
| `QM5_41163` | `8a7703322fa28d81d953c7725901fc12e0f44ebb8fc6643d58da80332e94e495` | 14:04:07 | pilot, `QM_PATTERN_PERMISSION_EA_MANAGED`; not an ordinary-path proof |

## Strongest ordinary candidate: QM5_35005

`QM5_35005_sma-crossover-pullback-system.mq5` is semantically unchanged from
pre-integration commit `82755f48a664abf1b0cc1fe5fa8833a8f3721aec` through the integration parent,
the integration commit, and current HEAD (`git diff` is empty for the source).
The Git-blob SHA-256 is the same at all four refs:
`20dd0c699f8f0feeaba859d0ce52c2cbca06207d0d5e1ec49df7326d645f0406`.
The filesystem CRLF form bound by the governed compile receipt is
`8c5457fc7cc7b10af168f89089b7320a5118d43078f87ed73232de18bbe0d4fc`.

The required two binaries are not both retained:

| Identity | SHA-256 | Retained bytes |
|---|---|---|
| pre-integration EX5 at `82755f48a...` | `28ef9a97341ab09666f4b8ac6a817bbdabe806c968fbc96279a0e1be0b2fbd59` | yes, Git and current repository file |
| governed post-integration compile work item `0ca4936f-d280-42bd-adc5-fa3f44f0d117` | `59d116784db396fd081175503e6e43b154593925d781e01bb18bc8a9f2f95750` | no retained copy found in repository, compile report directory, or deployed T1-T10 expert copies |

The compile log proves that the missing post binary was built through
`QM_Common.mqh` and explicitly included `QM_PatternPermission.mqh`, with 0
errors and 0 warnings. The current repository EX5 nevertheless hashes to the
old `28ef...` identity. The work-item database has no completed Q02 row for
`QM5_35005`; its three historical Q02 rows remain pending and bind the old
`28ef...` EX5. Therefore neither a post report nor a same-set deal list exists
for this candidate.

Recompiling was deliberately not improvised: there is no active governed
`COMPILE_EA` work item/terminal claim for this router task, T1-T10 are under the
factory scheduler, and an ad-hoc MetaEditor invocation would violate the compile
and terminal ownership contracts.

## Supporting input-echo evidence (not equivalence evidence)

The completed post-integration `QM5_41161` Q02 run is a managed-pilot
compatibility path, so it cannot close ordinary common-gate acceptance. It does
prove that the native report surface echoes all six inputs at zero:

```text
opt_pp_buy1=0
opt_pp_buy2=0
opt_pp_buy3=0
opt_pp_sell1=0
opt_pp_sell2=0
opt_pp_sell3=0
```

Bound identities for that supporting run:

- Work item: `7cd3787a-39df-5ac2-8e7d-c2e29bd258bc`
- EX5: `d96c7435d66cd16bb8ad778f53abcbb51e81a37628dd29a925208ce4550417d5`
- Set: `f53bbda887c3be7118c83ee6292934984b37e97266aed6e8ebac300e76efa32d`
- Tester INI: `4c480edbedac379182afe7dca41e35d5e63eff263624073bc2f5f1f4a10a5a1e`
- Native report: `b0e954af12b487053ee7d3819092f823ee847740800c987ddddd19ecf66606fa`
- Window/model: `2018.07.02`–`2022.12.31`, H1, model 4
- Result: 151 trades, deterministic run receipt

## Required closure

Before lifting the recommended ordinary compile release stop:

1. Create one append-only, governed compile successor for an unchanged ordinary
   EA such as `QM5_35005`, and retain the produced post EX5 as a hash-bound
   artifact instead of only recording its transient hash.
2. Run the retained Git pre EX5 and retained post EX5 hermetically with the same
   exact set bytes, symbol, window, timeframe, model 4, seed, data snapshot, and
   tester build.
3. Canonicalize the native report deal rows to a documented field schema and
   require both exact row equality and equal SHA-256. Report any field delta;
   do not reduce the check to aggregate metrics or trade count.
4. Bind native report input echoes for all six `opt_pp_*` values at `0` on the
   ordinary post binary.
5. If any deal field differs, retain both reports and recommend reverting or
   holding `b0bdc4d72` before further ordinary compiles.

No parent task, pipeline verdict, live terminal, AutoTrading setting, news stale
ceiling, or risk setfile value was changed in this investigation.

## Focused verification

```powershell
python -m pytest framework/scripts/tests/test_pattern_permission_contract.py tools/strategy_farm/tests/test_pattern_permission_framework_wiring.py -q
# 34 passed in 7.51s

git diff --check -- docs/ops/evidence/2026-08-26_9e707406_pattern_include_runtime_equivalence_escalation.md
# PASS (no output)
```
