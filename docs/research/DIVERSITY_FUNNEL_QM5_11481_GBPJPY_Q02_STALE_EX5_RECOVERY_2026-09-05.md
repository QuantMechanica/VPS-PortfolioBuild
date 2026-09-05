# Diversity funnel — QM5_11481 GBPJPY stale-generation Q02 recovery

Date: 2026-09-05 UTC (`2026-09-05T07:18:39Z`); 2026-09-05 09:18
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `d9fa02109159781ae5256315d25f33ca5fece6f4`

Status: one current-binary, append-only Q02 requalification seed was created
for `QM5_11481_carter-t-ny-open-box-m5 / GBPJPY.DWX / M5`. The paced fleet
subsequently claimed it on T3 without a manual dispatch from this session.

## Capacity admission

The fresh five-sample whole-host CPU window immediately before the mutation
was `74.7092%`, `86.9100%`, `83.4961%`, `79.6083%`, and `96.2896%`.
Average CPU was `84.2026%` and maximum CPU was `96.2896%`; both were strictly
below the binding `97%` ceiling.

The earlier read-only fleet scan observed four non-live factory terminals on
T3, T4, T5, and T6. `T_Live` was visible only as an excluded non-pipeline
process and was not controlled.

## Priority-order disposition

No collision-free priority-1 build was eligible. The nominal rates candidate
`QM5_1457_as-predict-bonds` remains non-executable from native `.DWX` inputs
because its Treasury/bond-series data contract is unavailable. The leading
forex cards in the pending task view already had committed MQ5 and EX5 builds,
so rebuilding them would duplicate work. New identities through QM5_41343
were also already represented by concurrent farm activity.

The selected priority-2 target is a structurally timed FX breakout with no
indicator or trained signal. It forms a prior-hour price box around the New
York open, permits at most one direction per session, and exits by fixed price
or time rules. Its approved card records R1-R4 PASS, identifies Thomas Carter
as the named source author, and declares native M5 `.DWX` coverage. Although
the carrier is M5, execution is bounded to one daily session attempt rather
than continuous intraday signal generation.

## Infrastructure diagnosis and repaired generation

The exact GBPJPY pair had three historical Q02 infrastructure failures and no
economic Q02/Q03 verdict, later gate, pending successor, or active successor
at the collision read immediately before enqueue. The latest immutable
predecessor was work item `afb12fd5-d0d0-42fa-80ad-212b3a89e4d2`, preserved
at `done / INFRA_FAIL` with
`verdict_reason=run_smoke_fail:BARS_ZERO;INCOMPLETE_RUNS`. Its short prescreen
had passed, but the full run failed on 2026-07-10. The row predates execution
binding and has null MQ5, EX5, and setfile hashes. Its canonical payload hash,
recorded by the seed helper, is
`2235884ddde26e6ad63d61c69d37349752ca3f7c2f1d228d00e94b903ed6b6dc`.

Commit `0e962aec1573068bdc0c736d9654a3e7abd1c132` then replaced only this EA's
EX5 on 2026-07-14, increasing it from 274,496 to 325,702 bytes. The old and
new Git blob IDs are `90c641c54bf4be55e9aee911a7a8bb0ba4ab7cc2` and
`6479faddf72c6ea6adffaf01533adaffb31095cb`, respectively. The current EX5
generation therefore did not exist when the full predecessor failed. This is
a stale-generation infrastructure requalification, not a strategy-mechanics
change and not an economic override.

## Atomic current-binary Q02 seed

`farmctl seed-fresh-q02` preserved the predecessor, verified that it was a
terminal pre-binding row, found no competing exact-pair work, authenticated
the active custom-history archive, and appended exactly one Q02 row:

- work item: `2f7da8d4-ca6c-4722-a6ad-e3b7dede2e64`;
- enqueue event: `events.id=384938`,
  `fresh_q02_pre_binding_seed_enqueued`;
- state at the first post-enqueue readback: `active`, claimed by T3, attempt 0;
- gate contract: `v4`, with `sh3_enforced=1`;
- MQ5 SHA-256:
  `b45b9045e26ef3cc61fd1d371f5da0ac744bd3982a0269d901e9849fc008c701`;
- EX5 SHA-256:
  `a2269a3144891410c2e81c9168743aa09aa1f7e86e42af02b2d0afe9bdaf05d1`;
- setfile SHA-256:
  `ff726269b5e8542650d502ba52d9d46a92db154da453bf1bb98380d4339cebcc`;
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- test window: 2018-07-02 through 2022-12-31;
- custom-history activation SHA-256:
  `61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`;
- OWNER-approved archive manifest SHA-256:
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`.

The worker claim occurred through the already-running paced fleet. This
session did not call `dispatch-tick`, reserve or release a terminal, launch a
manual backtest, or control any MT5 process.

## Safety boundary

No EA source, binary, setfile, Strategy Card, registry, magic resolver,
portfolio gate, portfolio-admission surface, deploy manifest, or live manifest
was changed. `T_Live` and AutoTrading were untouched. Existing unrelated
shared-worktree changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_qm5_11481_gbpjpy_q02_stale_ex5_recovery_20260905T071839Z_board_advisor.json`.
