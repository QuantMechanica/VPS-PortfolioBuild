# QM5_1196 FX Q02 fallback — CPU-ceiling stop

Date: 2026-08-10

Branch: `agents/board-advisor`

Repository head at the guarded preflight: `842e8fedd17215eead6d3a584493ad0a90d6ef21`

Status: the governed 66-pair FX cointegration frontier is exhausted; one
approved low-frequency FX fallback was fully qualified for an append-only Q02
retry, but the retry was not enqueued because the immediate paced-fleet sample
reached the binding seven-terminal CPU ceiling.

## Non-duplicate frontier decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` is the controlling
66-pair scan. Its two positive-beta survivors are already built and past Q02:

- `QM5_12532` (`AUDUSD.DWX` / `NZDUSD.DWX`) has logical-basket Q02 PASS and
  Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` (`EURJPY.DWX` / `GBPJPY.DWX`) has logical-basket Q02 PASS,
  followed by Q04 FAIL.

The frozen sign-aware extension is already mechanized through rank 64. Rank
65 is an explicit pair slot in `QM5_1156`, and rank 66 is the dedicated
`QM5_12803` basket. Creating another card, EA, magic allocation, setfile, or
basket manifest would duplicate existing work.

## Existing-card fallback selected

The fallback selected was `QM5_1196_qp-fx-meanrev-linear`, host
`AUDUSD.DWX`, D1. Its approved local card is
`framework/EAs/QM5_1196_qp-fx-meanrev-linear/docs/strategy_card.md`.

The card is a deterministic monthly currency-basket mean-reversion sleeve
derived from Quantpedia's named-author article, "How to Build Mean Reversion
Strategies in Currencies." It uses fixed linear exposure, monthly rebalance,
ATR emergency stops, and no ML or banned runtime dependency. The selected
setfile preserves the required backtest contract:

```text
RISK_PERCENT=0
RISK_FIXED=1000
```

Deterministic bindings checked before the enqueue attempt:

| Binding | Value |
|---|---|
| EA registry | `1196,qp-fx-meanrev-linear,...,active` |
| AUDUSD magic | slot `3`, magic `11960003`, `active` |
| EX5 SHA-256 | `f0ea458c155624c547eeb738f37bd8e3af5afd7a4585680eaf22f6e1135dc703` |
| MQ5 SHA-256 | `2dcdd2868e2bb5a2be9e02bb30a4e940bff063e6b845b87291f54e33bbfa7825` |
| Setfile SHA-256 | `59a81facbec11453556b22b6202219c2ea678050865545de45974b426c8eeadf` |

The exact terminal source row was
`bc25ee6c-2922-4df3-bf88-d5e15eaa4c72`. It is a terminal
`INFRA_FAIL`, not a strategy verdict, with evidence at
`D:\QM\reports\work_items\bc25ee6c-2922-4df3-bf88-d5e15eaa4c72\QM5_1196\20260802_134545\summary.json`.
The summary classifies all three attempts as `BARS_ZERO` /
`INCOMPLETE_RUNS`, before the 2026-08-10 Variant-A custom-history governed
reload documented in
`docs/ops/evidence/2026-08-10_ramp10_serialization_gate_statonly_fix.md`.

Database preflight proved:

- no pending or active `QM5_1196` / `AUDUSD.DWX` Q02 row;
- no non-infrastructure terminal Q02 verdict for that EA/symbol;
- the predecessor's symbol, D1 period, EX5, MQ5, and setfile hashes match the
  current canonical artifacts;
- `QM5_1196` is not on the Q02 requeue exclusion list.

## Binding CPU stop

The append-only command was wrapped in a fail-closed immediate terminal-count
interlock. At `2026-08-10T23:00:20+02:00`, `farmctl mt5-slots` observed seven
factory terminals:

```text
T1, T3, T4, T5, T8, T9, T10
```

Seven equals the binding ceiling, so the wrapper exited with
`CPU_CEILING_REACHED_NO_ENQUEUE` before invoking `enqueue-backtest`.

A post-stop read-only query proved that `QM5_1196` / `AUDUSD.DWX` still has
13 historical Q02 rows, zero pending/active rows, and zero rows created after
the terminal sample. No queue row was inserted, claimed, or dispatched, and no
tester or terminal process was launched or controlled.

Machine-readable evidence:
`artifacts/qm5_1196_fx_q02_cpu_ceiling_stop_20260810T210020Z.json`.

## Safety

- No Strategy Card, EA source/binary, setfile, basket manifest, or registry was
  changed.
- No portfolio-admission, portfolio KPI, or Q08-contribution artifact was
  touched.
- No `T_Live`, AutoTrading, deploy manifest, or live setfile was touched.
- Existing unrelated worktree changes were left untouched.

## Next paced action

After a fresh immediate sample is strictly below seven factory terminals,
repeat the exact append-only Q02 retry from predecessor
`bc25ee6c-2922-4df3-bf88-d5e15eaa4c72`, bound to EX5 SHA-256
`f0ea458c155624c547eeb738f37bd8e3af5afd7a4585680eaf22f6e1135dc703`.
Normal paced workers must own dispatch.
