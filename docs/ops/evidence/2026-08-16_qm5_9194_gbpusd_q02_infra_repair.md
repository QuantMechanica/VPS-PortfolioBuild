# QM5_9194 GBPUSD Q02 infrastructure repair

Date: 2026-08-16 Europe/Berlin

Branch: `agents/board-advisor`

Outcome: stale runtime artifact repaired and validated; the append-only Q02
retry was intentionally deferred because the farm was at the backtest CPU
ceiling.

## Selection and ownership

- The approved build backlog had no unclaimed, registry-complete reputable
  diversity build. The apparent remaining diverse builds were either already
  built/advanced, missing governed magic rows, low-quality tier-C sources, or
  concurrently claimed.
- `QM5_9194_mql5-rvgi-cci` was selected under mission priority 2. It is an
  approved structural H1 FX strategy sourced to named author Christian
  Benjamin's MQL5 article, with R1-R4 PASS and an expected 24 trades per year
  per symbol.
- Farm task `36537f06-548f-4475-92c7-d5876757d32d` claimed the GBPUSD repair
  for `codex:agents/board-advisor` before mutation. The atomic claim found no
  competing active agent task and no open Q02/Q03 work item for this EA.
- Online pre-claim DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_9194_gbpusd_q02_claim_20260816T161712Z.sqlite`.
  `PRAGMA quick_check` returned `ok`.

## Failure evidence and diagnosis

- Latest-created GBPUSD Q02 work item
  `c1e10b3e-0ddc-48a2-8f9a-61bba87a92ac` is preserved unchanged as
  `failed / INFRA_FAIL`; its terminal reason is
  `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`.
- Two earlier durable EURUSD smoke summaries also classified both repeated
  runs as `ONINIT_FAILED`:
  `D:\QM\reports\smoke\QM5_9194\20260610_102504\summary.json` and
  `D:\QM\reports\smoke\QM5_9194\20260610_102835\summary.json`.
- The only economic Q02 answer is a separate GDAXI row that failed minimum
  trades. It does not answer whether the GBPUSD sleeve can initialize and run.
- Before repair, the canonical EX5 was a 2026-06-21 artifact with SHA-256
  `f4e04c5e0851e0f1db0885807bdd88a999207cf4a598acae5564211bceac3f09`.
  It predated the current framework/magic resolver. Recompilation was therefore
  the bounded stale-runtime repair; the historical logs do not support a
  stronger claim that stale identity resolution was the sole init-failure cause.

## Repair

- Strategy source was left byte-for-byte unchanged. MQ5 SHA-256 remains
  `692c1954459d36e961b1c73403ab0379c1fe0bf6129c3d94cf93e07ea9f4778f`.
- The EA was strictly recompiled against framework head
  `72bf9ff9b34322887c0366173c8b0f2cd5d3d191` and resolver SHA-256
  `4b591ddbfc3c2df0b9d09b8ace519486bbaac6ad1df263b872e606639ec4bc43`.
- New EX5 SHA-256:
  `07f467ba5c918036516465365b6c152d0e420b6e98690b7848c1134c690f55df`.
- The compile tool refreshed only the three backtest setfile build hashes.
  Every set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`; GBPUSD remains H1,
  slot 1, magic 91940001.
- No entry, exit, stop, target, sizing, filter, timeframe, universe, or
  low-frequency mechanic changed.

## Verification

- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260816_161744\QM5_9194_mql5-rvgi-cci.compile.log`.
- Durable compile summary:
  `D:\QM\reports\compile\20260816_161744\summary.csv`.
- `build_check.ps1`: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260816_161814.json`.
- SPEC validation: PASS (1/1).
- Build guardrails: PASS, no findings.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`.
- Governed registry preflight: matching active EA allocation present; active
  magic rows 91940000/1/2 present for EURUSD/GBPUSD/GDAXI.

## Q02 admission deferred at capacity

Immediately before the intended append-only retry, `farmctl mt5-slots`
reported all seven managed terminals active: T1, T3, T4, T5, T7, T9, and T10.
Five host CPU samples were 100%, 100%, 98%, 89%, and 82% (93.8% average,
100% peak). The hard backtest CPU ceiling was therefore reached.

Per the paced-fleet stop instruction:

- no Q02 work item was enqueued;
- no backtest, dispatch tick, terminal reservation, or process-control action
  was run;
- the failed predecessor remains immutable;
- a later operator may create one append-only GBPUSD Q02 retry derived from
  `c1e10b3e-0ddc-48a2-8f9a-61bba87a92ac`, bound to EX5 SHA-256
  `07f467ba5c918036516465365b6c152d0e420b6e98690b7848c1134c690f55df`,
  once governed capacity is below the ceiling.

## Safety boundary

No portfolio gate, T_Live artifact, deploy manifest, AutoTrading setting, or
live-trading state was changed. Unrelated shared-worktree changes were left
unstaged.
