# QM5_20203 Q02 basket-identity recovery and append-only requeue

## Selection and farm claim

- Branch: `agents/board-advisor`.
- Farm claim task: `569da306-e97f-4165-899c-15e0348f5f71`.
- EA: `QM5_20203_eurusd-audjpy`.
- Logical sleeve: D1 EURUSD/AUDJPY cointegration pair with AUDUSD and USDJPY
  conversion-only dependencies.
- Failed Q02 row: `803cfaaa-d1e4-4d5c-a599-4d33b536ea9f`.
- Logical symbol: `QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`.

The approved unbuilt diversity backlog had no claimable registry-complete
forex, crypto, rates, or new-energy card. This built, low-frequency FX
market-neutral candidate was therefore selected under the mission's Q02-Q03
infrastructure-recovery priority. Its Strategy Card is OWNER-approved at G0,
uses the Tier-A Ernest Chan pair-trading method, freezes the fitted parameters,
and declares a structural, deterministic, learned-model-free D1 implementation.

The farm claim was inserted only after an atomic collision check showed no open
Q02 row or active agent task for this EA. The pre-claim online database backup
is:

`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_20203_claim_20260805T131820Z.sqlite`

Its `PRAGMA quick_check` result was `ok`.

## Infrastructure diagnosis

The source row exhausted three cold-cache attempts on T5, T7, and T10 and ended
as `INFRA_FAIL` with
`cold_cache_retries_exhausted:NO_HISTORY`. The evidence rules out an EA,
setfile, or stale-binary defect:

- The final summary reports `oninit_failure_detected=false`,
  `log_bomb_detected=false`, and a valid Model-4 marker.
- The source and deployed EX5 hashes match and remain stable during the run.
- All three generated tester configurations use the intended expert,
  `EURUSD.DWX` host, D1 period, fixed setfile, and 2018-07-02 through
  2022-12-31 window.
- The invalid reports have empty execution identity, zero bars, and
  `NO_HISTORY`; they contain no strategy verdict.
- The T5, T7, and T10 tester logs record
  `EURUSD.DWX: history synchronization error`, followed by tester
  disconnection. The host history fails before a meaningful EA run can start.

The exact repository bindings at recovery time are:

- MQ5 SHA-256:
  `d75788d24eadcff9c699a2f8964ab2cfd5ad924296b34df0b1d4a0a6853365cb`.
- EX5 SHA-256:
  `4d57f2bc03a14ce0be3f7f18245adfff280955287cda5af1119d502d33d96270`.
- Basket setfile SHA-256:
  `dcac19dcd0882c24ba0c772b36e47c816c582d3f612b35445ce909bfc8e846d8`.
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

Current farm evidence shows the history outage is no longer fleet-wide. The
latest retained Q02 PASS for each required symbol is EURUSD on T8
(`e4ba1f78-fde8-4c59-a07e-0933b9985a95`), AUDUSD on T3
(`9083d58e-4a64-4965-8d3d-3ae2b46625ba`), USDJPY on T4
(`33e6e2b0-7746-4087-b735-215f3fd18930`), and AUDJPY on T6
(`aab42a96-8118-481a-b0f5-9f3e0f3eb757`). A bounded infrastructure retry is
therefore justified without changing strategy mechanics.

## Funnel repair

The governed append-only Q02 rerun initially failed closed with
`historical_execution_identity_mismatch`. Its authenticator assumed the
`work_items.symbol` value must equal the MT5 `expected_symbol`. That is correct
for single-symbol EAs but impossible for baskets: the row key is the logical
basket symbol while the tester host is `EURUSD.DWX`.

`farmctl` now resolves these identities separately:

- a basket row must retain an exact `logical_symbol` match to its row key;
- a basket must declare a non-empty `host_symbol`;
- artifact and tester bindings use that host as `expected_symbol`;
- single-symbol rows keep their previous identity behavior.

A regression test reproduces the logical-basket/host-symbol split and proves
that an authenticated append-only Q02 rerun retains the logical row key while
binding execution to the host.

## Validation and queue handoff

- `python -m unittest tools.strategy_farm.tests.test_farmctl_cascade`: PASS,
  23 tests.
- The pre-write online backup is
  `D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_20203_q02_rerun_20260805T132535Z.sqlite`
  with `PRAGMA quick_check=ok`.
- Active farm test terminals at the mutation boundary: 5, below the ceiling of
  7. No manual tester was launched.
- New Q02 row: `85be20b6-d19d-46a2-9084-8786d9837399`.
- Enqueued at: `2026-08-05T13:25:38+00:00`.
- Initial readback: `pending`, verdict `NULL`, attempt count 0, unclaimed.
- The new row is explicitly append-only and points to the failed source row.
  The source remains unchanged as `failed/INFRA_FAIL`, attempt count 3, with its
  evidence path and learned terminal history intact.
- The rerun preserves the logical basket identity, host, four-symbol manifest,
  exact MQ5/EX5/setfile hashes, D1 period, dates, and fixed-risk contract.

The farm claim task is closed as `PASSED` after the branch commit, with this
evidence file as its artifact.

No portfolio gate, portfolio manifest, deploy manifest, `T_Live` path,
AutoTrading state, or live configuration was touched.
