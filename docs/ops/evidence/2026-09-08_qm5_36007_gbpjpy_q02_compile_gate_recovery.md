# QM5_36007 GBPJPY Q02 compile-gate recovery

Date: 2026-09-08

Branch: `agents/board-advisor`

Farm task: `dd61cfa6-2ee4-4c0e-b226-b05e848bcb2d` (`infra_repair`)

EA: `QM5_36007_nnfx-vidya-trix-fisher-momentum`

Target: `GBPJPY.DWX`, D1

## Selection and diagnosis

The approved-build backlog had no higher-diversity unclaimed candidate that was
both eligible and not already being handled by another paced session.  The
next priority was therefore a diverse built EA stranded between Q02 and Q03.
QM5_36007 is a low-frequency D1 FX strategy spanning EURUSD, GBPJPY, and
NZDCAD. EURUSD and NZDCAD already had terminal Q02 economic verdicts; GBPJPY
had four terminal `INFRA_FAIL` rows at `compile_gate:COMPILE_FAILED`, latest
`aaf5b6cf-0f38-438a-b22f-bf7231948ffc`.

The canonical MQ5 had been hardened after the last EX5 was emitted:

- current MQ5 SHA-256: `5dd37c9f921b4c3d942d29c610a1b8b5daad057c958872e454e3f57ff36f60ee`
- stale EX5 SHA-256: `1697c53bb1be220da295e39a8854095e0cd3128b9dcd3cf6402327d2e0e9464a`
- source-hardening commit: `2097b7151a21fea2014d10f08af570951f36dd8e`

An ad-hoc strict compile was attempted only as a diagnostic and refused safely
with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` / `INCLUDE_MIRROR_REFUSED` because
factory terminal processes were active. No direct compile occurred.

## Guard and governed compile

Before every compile enqueue attempt, the binding PACER source-pin audit was
run against the exact absolute MQ5 path. It returned `ok=true`, `hit_count=0`.
The source does not pin RNG, news, Friday-close, or stress-probability defaults.

The compile classifier initially refused the stale binary with
`EX5_ALREADY_PRESENT`, `WORK_ITEMS_EXIST`, and `BUILD_TASK_EXISTS`. A narrowly
scoped authority was added for this exact farm task and exact EA label:
`router_q02_infra_repair:dd61cfa6-2ee4-4c0e-b226-b05e848bcb2d`. It authorizes
only an append-only current-source compile successor and grants no strategy,
backtest, verdict, or cross-EA authority.

Governed compile work item `22e33cea-1bd3-4f18-9751-a9ff9b6f5a7d` completed
`COMPILE_OK` on T2. Evidence:
`D:/QM/reports/work_items/22e33cea-1bd3-4f18-9751-a9ff9b6f5a7d/QM5_36007/COMPILE_EA/compile_evidence.json`
(SHA-256 `9b7b39d5f2cb7e02886c7af5e415958bae5cab806777e5e364fdcc018a9c19a7`).
The resulting EX5 SHA-256 is
`0da9611c9105f0951aadba4f67f6b83cf1b8b382f31319ac8f510ebf962777db`.
The compile also refreshed the three canonical D1 setfiles:

- EURUSD: `9c99d847c9dae39457e0594cb82e82b32dba90465d6a69646f639e1cf513b2f7`
- GBPJPY: `b3084636270b7d1279ce9b983bfff78ef73471cf70f82141335df441fd797928`
- NZDCAD: `ce14065156855709d2ca17d3e8c99f5fc6ede1fe7f81d832441d91e6a75c7b76`

All remain `RISK_FIXED=1000`, `RISK_PERCENT=0`, with their registered magic-slot
offsets. No strategy input changed.

## Fail-closed Q02 recovery path

The historical GBPJPY compile-gate rows predate setfile-hash capture. Ordinary
`rebind-q02` and `requalify-q02` therefore refused with
`source_setfile_sha256_missing`. The recovery path now recognizes only the
exact terminal sentinel
`EVIDENCE_UNAVAILABLE:spawn_refusal:compile_gate:COMPILE_FAILED`, requires the
matching structured `spawn_refusal`, and then requires a hash-bound
source-repair-authorized `COMPILE_OK`. Other missing or conflicting historical
setfile identities remain refused. Because the tester was proven never to have
launched, the successor binds the current canonical setfile without inventing
a historical hash.

Tests: `83 passed` across
`test_compile_work_items.py` and
`test_q02_post_binding_requalification.py`.

The exact live dry-run for predecessor
`aaf5b6cf-0f38-438a-b22f-bf7231948ffc` is eligible with zero parameter changes,
current EX5 `0da9611c...`, current GBPJPY setfile `b3084636...`, fixed risk
1000/0, and compile provenance `22e33cea...`.

## CPU-ceiling stop

The final read-only slot scan found seven active factory tester terminals:
T1, T5, T6, T7, T8, T9, and T10. This is the documented seven-job backtest CPU
ceiling. In accordance with the mission's explicit stop condition, the eligible
Q02 dry-run was not applied. No manual tester run, live-terminal mutation,
AutoTrading change, portfolio gate, or live manifest was performed. The next
paced operator action is to repeat the exact `requalify-q02` dry-run and apply
it only after the fleet drops below the ceiling.
