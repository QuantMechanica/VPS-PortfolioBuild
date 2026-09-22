# Task 0ad35f22 — harness-v2 MT5 falsification

Router task: `0ad35f22-de1e-4bca-9341-4de2fbb7a535`

Disposition: **REVIEW — UNKNOWN for all three cells; governed execution is not representable by the bound EA/control plane**

## Outcome

No Q02 row was enqueued. No registry, Strategy Card, EA source/binary, roster, terminal, live setting, or historical verdict was
changed. The requested MT5 measurements would not test the registered harness-v2 A cells with the current QM5_41485 binary, so
enqueueing them under any available setfile would create false evidence.

QM5_41485 is a frozen C2/C3 implementation, not the A-anchor-configurable binary assumed by the ticket:

- `OnInit` accepts only `strategy_range_end_hour/minute=15:30`, `strategy_exit_hour/minute=23:00`,
  `strategy_grid_offset_minutes=30`, and `strategy_range_bars` in `{2,3}`. A2/A3 violate the frozen time/grid contract; A4 also
  violates the range-bars contract and returns `INIT_PARAMETERS_INCORRECT`.
- Harness anchor A is fixed GMT+3-equivalent, not a fixed raw broker hour. It maps to DXZ server `05:00/17:00` in winter and
  `06:00/18:00` in summer. QM5_41485 uses `TimeCurrent()` with one fixed server-hour input and deliberately contains no
  `QM_BrokerToUTC` normalization. One setfile therefore cannot encode the A schedule even if the `OnInit` freeze were relaxed.
- The approved card declares only USDJPY.DWX and EURUSD.DWX. The governed allocator dry-run reports the exact card as already
  allocated with those two rows; NZDJPY.DWX cannot receive a governed slot without changing the card, which this task forbids.
- Canonical `enqueue-backtest` rejects replacement setfiles for Q02 with
  `replacement_setfile_requires_cascade_phase`. Its universe-expansion path is for a new card-declared EA/symbol pair, so it
  cannot represent two additional USDJPY arms and also rejects undeclared NZDJPY.

The precise input derivation and seasonal broker-hour mapping are preserved in `cell_input_mapping.json`; no `.set` file was
emitted because none could be both single-file and executable against the bound binary.

## Golden comparison

The harness figures below are the registered SEL values from
`velocity_family_f1_sweep_v2.json`. DD is the harness's worst calendar-year drawdown in R. A dash means no authentic MT5 row
exists for this cell.

| cell | harness n | harness E[R] | harness PF | harness DD (R) | MT5 n / E[R] / PF / DD | golden verdict |
|---|---:|---:|---:|---:|---|---|
| NZDJPY.DWX A2 | 970 | +0.0570 | 1.122 | 21.00 | — | **UNKNOWN** |
| USDJPY.DWX A3 | 893 | +0.0675 | 1.161 | 21.87 | — | **UNKNOWN** |
| USDJPY.DWX A4 | 821 | +0.0753 | 1.184 | 18.56 | — | **UNKNOWN** |

`UNKNOWN` is neither `EQUIVALENT` nor `HARNESS_OVERSTATES`; there is no like-for-like MT5 observation. Because no SEL row ran,
the conditional VAL rows were not enqueued.

QM5_41485 remains permanent negative lineage `PRESCREEN_EXECUTION_MODEL_FALSE_POSITIVE`. This work confers no candidacy,
pipeline, roster, or deployment authority.

## Bound facts

| object | binding |
|---|---|
| harness-v2 sweep | `1f4fb67ed444ad34f63ac7aa20b5341d86bbd63c10be21fceacebce6a1a49264` |
| QM5_41485 MQ5 | `be665dc9068b1a163b0253c14cbc8f08bf03622a58f77e1ec10cdf6764d90b76` |
| QM5_41485 EX5 | `f6224fcc952a0094478498d9559fd621b838a680fe4b0bc717beac5bdfdfac19` |
| approved card | `f70740a7c2909d1c6ddbb972f0400ca40f5b056a599c47797bdfb1c8c114b54c` |
| magic registry | `7a3a71ea665415b7822c7f2995a0199b530dc3e2508b9180d2c0e6f47af23861` |
| magic resolver | `eb5e34d030929cff4d44264ae84c00ac9975cd5395161fbaf0bbccb255c31c2e` |
| canonical farmctl | `fa6256c2b81d313ca9caf06aec69d2741f1bc412037c25a252abf2f88269bb5b` |
| governed allocator | `ae3f84068380d5dba13852802526c91981629499a6b1a81a3a292ecec1768dc8` |
| existing USDJPY Q02 rows | `ffe3a8dc-182c-4713-b2b6-3baf3f8ea502`, `bae8cf20-1a3a-4c6f-9f49-7a6faea4e7f2` |
| no-change state | `7f30808ce607bb73961c8c9ff79ddd0fcaabfcb5cb12924e54ed9d556d7996e9` |

## Verification

- Static contract/time proof: PASS. The source freeze was matched byte-for-byte, and harness anchor A resolved to broker
  `05:00/17:00` for 2024-01-15 and `06:00/18:00` for 2024-07-15.
- Governed allocator exact-card dry-run: PASS, zero planned rows; decision `already_allocated`, symbols USDJPY.DWX and
  EURUSD.DWX only.
- Canonical enqueue guard probe: PASS (fail-closed), `enqueued=false`, reason
  `replacement_setfile_requires_cascade_phase`; the farm inventory remained 12 total rows / three terminal Q02 PASS rows for
  QM5_41485, with no pending or active row added.
- Focused tests initially produced 20 PASS and two unrelated/current-state failures: the checked-in QM5_41485 canonical
  setfiles do not all contain the explicit news input lines expected by their test, and a global allocator-lock test encountered
  `PermissionError` while another process owned the live lock. Neither failure was modified or bypassed. Targeted pure checks are
  recorded in `verification.json`.

## Required re-scope before execution

A valid follow-up needs an OWNER-authorized, separately reviewed test identity or binary that (1) implements fixed-GMT+3 A-anchor
normalization, (2) accepts N=2/3/4, (3) preserves the harness-v2 OCO/gap mechanics, and (4) is compiled after any governed NZDJPY
magic allocation. The control plane also needs a governed exact-arm Q02 identity that permits multiple frozen setfiles for one
EA/symbol without overwriting or relabelling historical rows. Those are source/control-plane changes, not setfile derivation, and
were not authorized by this ticket.

