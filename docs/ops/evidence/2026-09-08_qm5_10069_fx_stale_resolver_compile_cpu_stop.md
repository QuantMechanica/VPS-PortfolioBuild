# QM5_10069 FX stale-resolver recovery — governed compile queued, CPU stop

Date: 2026-09-08
Branch: `agents/board-advisor`
EA: `QM5_10069_mql5-hs-rev`
Farm task: `4e3fda2a-4481-4791-942b-6b7bca56ad7f`
Outcome: **STALE-RESOLVER CAUSE ISOLATED; EXACT COMPILE AUTHORITY ADDED;
GOVERNED COMPILE QUEUED; Q02 DEFERRED AT THE CPU CEILING**

## Diversity selection and collision control

No eligible priority-1 approved-card build was both unbuilt and unclaimed after
checking the pending build inventory against materialized EA/EX5 identities.
The apparently attractive GBPJPY D1 repair, QM5_36007, was already claimed by
another paced agent and was excluded.

QM5_10069 was the highest-value unclaimed priority-2 recovery found: its
structural H1 head-and-shoulders rule has an OWNER-authorized 13-symbol
expansion, and its four newly measured FX symbols (AUDUSD, NZDUSD, USDCAD and
USDCHF) all stop at `OnInit` rather than producing an economic verdict. This is
materially more diverse than adding another index, metal or energy build.

An atomic collision recheck found no open task and no pending/active work item
for QM5_10069. It then inserted the exclusive `infra_repair / active` task
above, assigned to `codex:agents/board-advisor`. The pre-claim online SQLite
backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10069_stale_resolver_claim_20260908T214619Z.sqlite`

Backup SHA-256:
`10c6b2a33a26f2a19e3732adf47f5d8621f3736e8736c2ef3027f5413f2da67e`.

## Bound failure and root cause

The selected immutable Q02 row is
`995f4c1c-531d-4a46-a4d8-8e6723318058` (`AUDUSD.DWX / H1`,
`done / INFRA_FAIL`). Its canonical summary is:

`D:\QM\reports\work_items\995f4c1c-531d-4a46-a4d8-8e6723318058\QM5_10069\20260907_155514\summary.json`

That evidence records synchronized execution identity followed by the decisive
tester line `tester stopped because OnInit returns non-zero code 1`, zero bars
and zero trades. It binds:

- MQ5 SHA-256
  `b74e0a8ec9397a404a22cf798eb16793a2a517015252def2e99171ede5a644ea`;
- deployed/canonical EX5 SHA-256
  `823215f8ec9f29b5b4d7905d2831343a482e548874dc9283437619e16317e785`;
- EX5 last-write time `2026-06-16T11:21:12Z`;
- AUDUSD setfile SHA-256
  `279fcc6af94be3512fb4bbc769c62f408dff84a1d33ecbcc2c96258ea9856c13`;
- `qm_magic_slot_offset=4`, `RISK_FIXED=1000`, `RISK_PERCENT=0`.

The active registry did not add slots 4-12 until 2026-08-23 under
`Codex OWNER-DEC-13036-XAU`. It now contains AUDUSD slot 4 / magic 100690004,
NZDUSD slot 7 / magic 100690007, USDCAD slot 10 / magic 100690010, and USDCHF
slot 11 / magic 100690011; the current generated `QM_MagicResolver.mqh`
contains each exact magic. The June binary necessarily predates those rows.
The repeated new-slot `OnInit` failures are therefore stale compiled-resolver
infrastructure, not market history, zero-trade mechanics or a Q04 verdict.

## Exact compile authorization and PACER guard

`compile_work_items.py` now recognizes exactly one authority/task/EA pair:

`router_q02_infra_repair:4e3fda2a-4481-4791-942b-6b7bca56ad7f`

for `QM5_10069_mql5-hs-rev` only. The ordinary classifier remains fail-closed
for every other label and authority. Focused tests prove wrong-label and
wrong-task rejection and prove that only the exact authority can append a
compile recovery when historical Q02 work and an EX5 already exist:

`python -m pytest tools/strategy_farm/tests/test_compile_work_items.py -k "10069 or 36007" -q`

Result: `4 passed, 74 deselected`.

No MQ5 strategy mechanics were changed. Immediately before enqueue, the
binding PACER audit was run against the absolute source path:

`python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_10069_mql5-hs-rev/QM5_10069_mql5-hs-rev.mq5"`

Result: `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.

## Governed compile handoff

The sanctioned source-hash-bound enqueue accepted exactly one utility row:

- COMPILE_EA work item: `7b58b41d-6175-4841-9f46-b3025387b73d`;
- initial/current status: `pending`;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- symbol count: 13;
- timeframe: H1 from existing setfiles;
- no gate verdict.

The row remains in the normal resident-worker path. No ad-hoc compile, terminal
stop, hold bypass or manual tester launch occurred.

## Binding CPU-ceiling stop

After enqueue, five whole-host `Processor(_Total)` samples averaged 95.53% and
peaked at 98.34%, with seven `terminal64` processes present. The peak exceeded
the mission's 97% ceiling. Work therefore stopped before releasing the compile
hold or appending a Q02 successor.

Once the CPU ceiling is clear, let the governed compile row reach `COMPILE_OK`
and require a changed EX5 hash plus strict build-check PASS. Then dry-run and
apply `farmctl rebind-q02` against the immutable AUDUSD predecessor, binding
the new EX5 hash. Do not rebind while the compile row is pending.

The pre-existing EA directory still lacks `SPEC.md`, and the four May-era
setfiles omit explicit session inputs; the current guardrail validator reports
those as legacy hygiene findings. They do not explain the slot-4 `OnInit`
failure and were not silently widened into this artifact-only repair. Any
future source/hygiene repair must receive its own source-hash-bound authority
and rerun the PACER input-pin audit before compile enqueue.

## Safety boundary

No `T_Live` file or process, AutoTrading setting, live setfile, deploy manifest,
portfolio gate, portfolio KPI artifact or certification verdict was changed.
No Q02 successor exists yet, and no strategy/economic PASS is claimed.
