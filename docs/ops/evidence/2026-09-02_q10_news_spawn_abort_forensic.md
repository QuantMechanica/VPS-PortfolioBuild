# Q10_NEWS silent-abort forensic and no-rerun disposition

**Router task:** `4a9d6cfa-69af-4f00-b842-ca8cb00c72ee`

## Result

All three rows are launch faults caused by missing immutable predecessor
evidence, not RAM/commit kills, sharing violations, setfile failures, or MT5
test failures. No replacement was enqueued and no hold was released. Replaying
the same sealed plan would deterministically fail its authenticated input check;
the rows remain fail-closed pending a separately governed fresh-lineage path.

| row | durable stderr finding | process timing | disposition |
|---|---|---:|---|
| `745671a4-...` · `QM5_11129/SP500.DWX` | bound Q07 aggregate `e3187d46-...` is missing | Python PID 10504 exited in 4.67 s | no rerun |
| `77bd97c2-...` · `QM5_10700/XAUUSD.DWX` | bound Q08 aggregate `fb35a79a-...` is missing | Python PID 6280 exited in 1.97 s | no rerun |
| `dd7b14a0-...` · `QM5_11910/NZDUSD.DWX` | bound Q08 aggregate `0cb83f40-...` is missing | Python PID 35864 exited in 5.52 s | no rerun |

## Evidence chain

The SQLite payload on each pending row retains the exact child-process stderr
tail, PID, Windows process-creation key, launch time, terminal, and sealed-plan
binding. The stderr reaches `q09_news_runner._verify_hash` and raises
`RunnerError: ... evidence missing` before any matrix cell starts.

The three `run_plan.json` files still exist and their SHA-256 values exactly
match the row payload:

- `745671a4-...`: `8189aaba33eb00e847dbd62fc60e70d26a4916dacbd960c2821bc010571e878a`;
- `77bd97c2-...`: `eb2538b34a5fc2b2640ad2f3ebb9e73667eb22fa60d73eef4f01324128bd7c18`;
- `dd7b14a0-...`: `82e98c9127a8d9a8592483657d96c0d47a3a03fd90c88279db02959049c4b06a`.

The payload-declared work-item logs under
`D:\QM\strategy_farm\logs\work_item_<id>.log` are no longer present. That
retention gap is recorded rather than hidden; the durable payload stderr is the
remaining runner output. Searches of the corresponding launch-terminal and
tester journals (`T5/20260829`, `T3/20260829`, `T1/20260828`) found zero target
EA-name entries. This is consistent with authentication failing before MT5 was
launched for a cell. The later T10/T2/T7 values in `news_runner_spawn_abort`
identify the workers that detected the already-dead process, not a test run.

Windows System event log contains zero resource-exhaustion event 2004 records
for 2026-08-28 through 2026-08-29. The host currently exposes 63.12 GB RAM, but
today's separate headroom pressure and 13:45Z discussion post-date these exits
by four days and do not explain 2–6 second authenticated exceptions.

Machine-readable row evidence is in
`docs/ops/evidence/2026-09-02_q10_news_spawn_abort_forensic.json`.

## Governed recovery boundary

`enqueue-backtest --append-only-rerun-of` is appropriate only for a transient
infrastructure abort with still-authentic inputs. Here, the bound Q07/Q08 files
are absent, so exact reruns would be knowingly invalid. Creating fresh upstream
Q07/Q08 evidence and allowing a newly sealed Q10 row is a separate lineage
recovery decision; this task did not invent or enqueue that work. Historical
rows, holds, sealed criteria, queue priority, and pipeline verdicts are
unchanged.
