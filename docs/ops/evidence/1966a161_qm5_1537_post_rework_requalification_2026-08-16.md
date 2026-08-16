# QM5_1537 post-rework requalification and FX disposition

**Router task:** `1966a161-cbaa-438d-b977-a21b3381b87d`  
**EA:** `QM5_1537_aa-vol-sma10`  
**Branch:** `agents/board-advisor`  
**Date:** 2026-08-16  
**Disposition:** REVIEW — one current-binary XTIUSD Q02 successor enqueued; the deferred FX cohort retired as proven no-signal; no pipeline verdict asserted

## Decision

The two requested cohorts have different evidence:

- `XTIUSD.DWX` is selected in the verified full-universe monthly calendar and therefore remains economically informative. Its only historical Q02 row, `914978c8-57c2-4f54-b791-663115c03611`, is terminal `INVALID` on EX5 `3e70db2a...`. A corrected current binary must be able to requalify that disposition.
- The 28 deferred FX hosts are never selected in the exact 37-symbol calendar over the Q02 window. Releasing even a two-symbol sample cannot add economic information: the unchanged top-three rule prevents every FX host from reaching an entry evaluation. The 28 rows are therefore retired as genuine no-signal instead of consuming about two factory-hours to reproduce a deterministic zero.

This is a row/cohort disposition, not a family or live-use verdict. The already accepted XAUUSD, UK100, and SP500 no-signal dispositions are unchanged. XAGUSD and the proven XNGUSD canary are also unchanged.

## Governed stale-INVALID requalification path

The existing paths had an actual gap:

- `seed-fresh-q02` correctly refused the binding-era row with `fresh_q02_seed_requires_pre_binding_source`.
- `enqueue-backtest --append-only-rerun-of` accepted only `PASS`, `INFRA_FAIL`, and `DRAFT_DEFECT`, so it refused a corrected binary solely because the historical evidence disposition was `INVALID`.

Commit `c6d269d2c` closes only that gap. The Q02 append-only path now accepts `INVALID` when all of the following hold:

1. the source row is terminal, unclaimed, and has complete historical MQ5/EX5/set/symbol/period/expert bindings;
2. the operator-supplied current EX5 hash matches the canonical binary;
3. the current EX5 differs from the historical EX5 while symbol, period, and expert identity remain exact;
4. durable source evidence exists (the terminal worker log is accepted and SHA-256-bound when no aggregate was publishable);
5. the current setfile satisfies `RISK_FIXED > 0` and `RISK_PERCENT = 0`;
6. no current-binary terminal result, open exact row, or prior successor already exists.

Same-binary `INVALID` retries remain refused. Other economic verdicts, including `ZERO_TRADES`, remain outside this mechanism.

The actual append-only enqueue created successor `c13fcc4d-8a38-464b-b26d-8630b420b7b9` from the preserved source row. It binds:

| Binding | Value |
|---|---|
| Current EX5 SHA-256 | `142a019e773a493def0640722efb9d591d094650b35a69d5de39f6af3a048106` |
| Current MQ5 SHA-256 | `7edf9ade3dec02496e739c3cf1c653eb33bcc4339a223907877f2c78a393fc32` |
| Current XTIUSD set SHA-256 | `cb304f2812ce7b6b155e24559c648c61050165d05dda31132791ad6f0038c23f` |
| Historical runner-log SHA-256 | `1e52c787c22069d4fcd527071cf8217c6ed063a9d00ab30e2312e26284f3eef3` |
| Risk contract | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

## Exact FX no-signal proof

The bound calendar `framework/EAs/QM5_1537_aa-vol-sma10/calendar/QM5_1537_monthly_sleeves_v1.csv` has SHA-256 `401e0d91e2428dab4abff17c1df651f1c7bc716b7160b71a06d1a3eca9b5288b`. Its ranking contract and the independent 1,986/1,986 equivalence result were accepted in `a96ddcdd_qm5_1537_bound_monthly_sleeve_rework_2026-08-16.md`.

For 2018-07 through 2022-12, the 28 FX hosts contribute 1,400 eligible host-months and zero selected host-months:

| Host | Eligible months | Best zero-based rank | Worst zero-based rank | Selected months |
|---|---:|---:|---:|---:|
| `AUDCAD.DWX` | 50 | 23 | 34 | 0 |
| `AUDCHF.DWX` | 50 | 12 | 20 | 0 |
| `AUDJPY.DWX` | 50 | 3 | 13 | 0 |
| `AUDNZD.DWX` | 50 | 30 | 36 | 0 |
| `AUDUSD.DWX` | 50 | 8 | 22 | 0 |
| `CADCHF.DWX` | 50 | 15 | 30 | 0 |
| `CADJPY.DWX` | 50 | 6 | 19 | 0 |
| `CHFJPY.DWX` | 50 | 22 | 34 | 0 |
| `EURAUD.DWX` | 50 | 15 | 28 | 0 |
| `EURCAD.DWX` | 50 | 18 | 33 | 0 |
| `EURCHF.DWX` | 50 | 31 | 36 | 0 |
| `EURGBP.DWX` | 50 | 17 | 35 | 0 |
| `EURJPY.DWX` | 50 | 13 | 34 | 0 |
| `EURNZD.DWX` | 50 | 17 | 29 | 0 |
| `EURUSD.DWX` | 50 | 18 | 34 | 0 |
| `GBPAUD.DWX` | 50 | 6 | 29 | 0 |
| `GBPCAD.DWX` | 50 | 9 | 34 | 0 |
| `GBPCHF.DWX` | 50 | 12 | 30 | 0 |
| `GBPJPY.DWX` | 50 | 7 | 19 | 0 |
| `GBPNZD.DWX` | 50 | 6 | 33 | 0 |
| `GBPUSD.DWX` | 50 | 11 | 26 | 0 |
| `NZDCAD.DWX` | 50 | 17 | 32 | 0 |
| `NZDCHF.DWX` | 50 | 13 | 26 | 0 |
| `NZDJPY.DWX` | 50 | 4 | 16 | 0 |
| `NZDUSD.DWX` | 50 | 8 | 21 | 0 |
| `USDCAD.DWX` | 50 | 20 | 34 | 0 |
| `USDCHF.DWX` | 50 | 22 | 34 | 0 |
| `USDJPY.DWX` | 50 | 17 | 34 | 0 |

The calendar stores `host_rank` as a zero-based index: `0`, `1`, and `2` are the selected top three, while `3` is fourth place. Thus even `AUDJPY.DWX` at its best recorded value of `3` is outside the sleeve. The executable `selected` flag is zero for every FX host-month.

## State mutation receipt

An online SQLite backup was taken before the cohort mutation:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1537_fx_retirement_online_20260816T103107Z.sqlite
SHA-256 5cd8ed90fae91f36cca4d556a0df459399fa4450bfed44b9924030a18f9ac599
PRAGMA integrity_check = ok
```

At `2026-08-16T10:36:47.793443+00:00`, one `BEGIN IMMEDIATE` transaction performed an exact compare-and-set over the 28 expected symbols. Every target was still `pending`, unclaimed, verdict-null, and deferred to `2026-08-25T00:00:00+00:00`. Each row became `done/RETIRE`, retained its prior payload, and gained the calendar hash, per-host rank proof, task/evidence binding, and durable reason. Event `q02_fx_no_signal_cohort_retired` records the complete symbol and work-item lists.

| Receipt field | Value |
|---|---|
| Rows changed | 28 |
| Pending FX rows afterward | 0 |
| Bound retirement rows afterward | 28 `done/RETIRE` |
| Pre-mutation row snapshot SHA-256 | `33a3329486ca748a8244b6a05e667a8c4bbf351fb69091a5f9604225335149b4` |
| Sorted work-item-ID list SHA-256 | `1a1ce7eb2e495f697bb427e200b840116dfafe4b989bc014e5f2f4f6fd91b685` |
| Event count for this task | 1 |

The XTIUSD source remains unchanged as `failed/INVALID`. Its sole successor was independently claimed by `T1` after enqueue and was `active` at the post-mutation read; it was not part of the retirement transaction and no attempt was made to interrupt it.

## Focused verification

| Check | Result |
|---|---|
| Python compile of farmctl and focused tests | PASS |
| `pytest tools/strategy_farm/tests/test_candidate_repair_enqueue.py -q` | PASS, 37/37 |
| Stale INVALID successor regression | PASS; historical row preserved and runner log hash-bound |
| Same-binary INVALID regression | PASS; refused with `q02_invalid_source_not_stale` |
| Other-economic-verdict regression | PASS; `ZERO_TRADES` remains refused |
| XTIUSD append-only enqueue | PASS; exactly one current-binary successor created, then normally claimed by `T1` |

No MT5 terminal was started manually, no active tester was interrupted, and no Q02 or later pipeline verdict is claimed here.
