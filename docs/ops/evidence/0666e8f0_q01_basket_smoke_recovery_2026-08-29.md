# Worker-bound Q01 basket smoke recovery — router task `0666e8f0-fe8d-4c25-ac8b-21c9a7d9bac9`

Date: 2026-08-29

Branch: `agents/board-advisor`

Targets: `QM5_12512`, `QM5_10050`, `QM5_12507`

Outcome: **Q01 COMPLETE: 12512/12507 PASS; 10050 ZERO-TRADE FAIL; PASSING LOGICAL Q02 SEEDS ENQUEUED**

## Admission diagnosis

The original direct `run_smoke.ps1` attempt for `QM5_12512` resolved an idle
factory slot but stopped before tester launch. The active Custom-history gate
correctly refused an invocation with no worker claim:

`active Custom-history isolation requires a worker-bound work item whose archives were privatized before run_smoke`

This was an infrastructure admission refusal, not a smoke FAIL. No direct
terminal was launched and no result was relabeled as PASS.

The canonical tree also lacked a setfile named for each basket's logical
symbol. Three fixed-risk logical setfiles were added, and
`QM5_10050_CORR_TRIAD_H1`'s invalid `_per_instance` host declaration was bound
to its implemented `EURUSD.DWX` host. Every new backtest set retains
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Exact worker-bound recovery

`q01_basket_smoke_recovery.py` is intentionally bounded to this router task,
these three approved review tasks, and these three logical symbols. It verifies
review approval, basket host/member declarations, current MQ5/EX5/setfile
hashes, and fixed-risk values before inserting deterministic append-only rows.
It never updates a historical build task or work item.

The exact rows were appended at `2026-08-29T08:37:09Z`:

| EA | Logical symbol | Q01 work item | EX5 SHA-256 | Setfile SHA-256 | Observed state |
| --- | --- | --- | --- | --- | --- |
| `QM5_12512` | `QM5_12512_FX_PAIRS_THRESHOLD_H1` | `9ca7d432-68b1-50e7-9de6-1e40710b6634` | `bb31cb2b92679e02916ba8e9b63b749d9c51af0e9b6474057f477604a8b21a1c` | `10697e9af07e0718fd4260a7dbc41f6cf59838e3122ac41badc2cf2aabf9b1d3` | `done / PASS` (628 trades) |
| `QM5_10050` | `QM5_10050_CORR_TRIAD_H1` | `f1cb6f6e-3375-500a-8fd2-c0ba99358fcf` | `d11c8829932e8077b34a0ecb720b0ba37c9084e18e0afc1e2387beab6a039edf` | `2c36056055a83b66596b42490e8d2b3b6d3db6bf5f4ee627e344e890d6c49817` | `done / FAIL` (`Q01_ZERO_TRADES`) |
| `QM5_12507` | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` | `7d1a179d-4d25-5d37-a69a-3a52fd78ae63` | `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa` | `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99` | `done / PASS` (632 trades) |

The rows carry the exact contract
`qm.q01.worker_bound_basket_smoke.v1`, the 2024 window, logical symbol,
physical host, complete basket member list, and immutable artifact hashes.
Resident workers therefore own the normal claim → Custom-history
privatization → reservation → `run_smoke` route. Basket serialization remains
unchanged: at most one multi-symbol job may run farm-wide.

At insertion time 1,956 priority-track `OPT_CENSUS` cells ranked ahead of an
otherwise unknown Q01 phase. A narrow selector correction gives only the exact
`kind=q01_smoke` + contract pair the existing prerequisite override used for
compile/harness work. It does not change a smoke criterion, gate verdict,
ordinary phase order, or any non-matching Q01 row. Activation is through a
normal future pump process or natural worker restart; no worker or active
T1–T10 backtest was stopped or restarted.

The finalizer is also append-only. It accepts only a terminal Q01 row whose
`run_smoke/v2` evidence matches the expected window, host, timeframe, expert,
MQ5, EX5, and setfile identities. Only then does it append the build-smoke
receipt consumed by the unchanged Q02 admission gate. Until that happens, the
three existing `enqueue-backtest --phase Q02` calls remain correctly refused.

## Verification

- `validate_build_guardrails.py` on all three EA directories: **PASS**, zero
  findings, `max_news_stale_hours=336`.
- Basket/Q02/recovery focused suite: **79 passed**.
- Exact prerequisite ordering plus recovery utility suite: **38 passed**.
- Recovery apply was idempotent and collision-checked; the first two live
  attempts failed closed during SQLite contention and inserted nothing, while
  the later bounded-timeout attempt atomically inserted all three rows.
- Code commits: `c26aee604`, `d1192d4f9`, `d010342ae`.

The current full `build_check.ps1 -SkipCompile` is not represented as clean:
it reports pre-existing post-review findings (explicit MAE hook/request
initialization on `12512`/`12507`, and legacy physical setfiles outside
`10050`'s card universe). The task authorized smoke qualification of the
already reviewed binaries, not a mechanics-changing rebuild. The mandatory
risk/news guardrail validator is clean; the broader static findings are
preserved here for reviewer visibility.

## Terminal outcomes and authenticated receipts

The resident workers completed all three rows. The bounded finalizer authenticated
the `run_smoke/v2` summaries against the declared window, physical host,
timeframe, expert, MQ5/EX5, and setfile identities, then appended immutable build
receipts:

| EA | Receipt task | Receipt artifact SHA-256 | Result |
| --- | --- | --- | --- |
| `QM5_12512` | `500c29f2-dbdc-52cb-b065-043544785d6e` | `A604743038EDBD324C2A1FEC53BCD78595339348183D4A59655E7010F1F7B752` | `passed`, 628 trades |
| `QM5_10050` | `a72cdad6-48c8-5acd-af8e-77cea985b3f8` | `80B4C079F993CE6955782C25FCEE3F8F61EFA03D28AA732AA3EE93B96DDDA400` | `zero_trades`, 0 trades |
| `QM5_12507` | `1b0e2710-c876-5add-8898-9e496b348a14` | `C470DB23E9ADFA516D72C2F065EBDAFE19414ADB2F94AE711B7A5F4163EEED1A` | `passed`, 632 trades |

The unchanged Q02 admission gate now has genuine passing smoke evidence for
`QM5_12512` and `QM5_12507`. Repeated canonical `enqueue-backtest --phase Q02`
attempts for those two reached the append operation but failed atomically with
`sqlite3.OperationalError: database is locked` while the scheduled farm pump
and tick were active. No logical Q02 row was partially created. `QM5_10050`
correctly remains inadmissible because its real Q01 result is zero trades; that
is a strategy/runtime outcome, not an infrastructure failure or waiver case.

## Logical Q02 seeds

After the scheduled writer released its transaction, the unchanged governed
Q02 path admitted the two passing receipts and appended exactly one logical
seed per basket:

| EA | Logical Q02 work item | Parent task | State at handoff |
| --- | --- | --- | --- |
| `QM5_12512` | `acbad967-bf94-4565-9e51-db193de01bf9` | `0acc8178-da83-4846-8b33-accb497217c7` | `pending` |
| `QM5_12507` | `547c4fd3-f3fd-4c59-b9dc-654e96521251` | `47e96b62-0ece-40a2-a22b-13704bd24e46` | `pending` |

`QM5_10050` was not enqueued: its authenticated Q01 zero-trade result remains
a legitimate fail-closed verdict and requires separately routed recovery if
further work is desired. At this review boundary there are **two Q01 PASS
outcomes, one legitimate Q01 zero-trade FAIL, and two pending logical Q02
seeds**. No Q02 or later pipeline verdict is asserted.
