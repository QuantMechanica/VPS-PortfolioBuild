# Point 2.3 precondition — exits are present everywhere; **direction** is the gap, and only a Q08 re-run can close it

v6 §0 and §3.3 make this a gating question: *"ob 2.3 neben Eintritts- auch **Austritts**zeitpunkte
liefert (sonst ist 3.3 nicht rechenbar)"*, with §3.3 stating that if exits are missing, supplying
them belongs to 2.3 rather than 3.3.

**Measured: exits are present in 100% of records across 100% of sleeves. The precondition resolves
positive.** The missing field is **direction**, together with entry/exit prices.

## The census — 216 sleeves, 58,599 records, all `TRADE_CLOSED`

| what 3.3 needs | field | records | sleeves |
|---|---|---:|---:|
| **exit time** | `time` | 58,599 (100%) | **216 / 216** |
| volume | `volume` | 58,599 (100%) | 216 / 216 |
| symbol | `symbol` | 58,334 (99.5%) | 215 / 216 |
| entry time | `entry_time` | 41,375 (70.6%) | 138 / 216 |
| **direction** | `side` | **6,077 (10.4%)** | **17 / 216** |

`time` is the close timestamp (epoch seconds); on records carrying both, `entry_time < time`
throughout.

## What this changes for the critical path

**3.3 is not blocked on exits.** Reconstructing which positions were open simultaneously needs
entry and exit. Exits are universal; entries cover 138 sleeves.

**But the FTMO daily limit is not computable from most of this corpus.** v6 §3.3/§3.4 require the
intraday equity path including floating positions, because FTMO measures daily loss against
day-start balance *inclusive of open positions*. Marking an open position to market needs
direction, entry price and volume. Direction and prices exist for **10.4% of trades**:

- **closed-trade daily equity path** — 138 sleeves (70.6% of trades)
- **intraday mark-to-market path** — 17 sleeves (10.4% of trades)

The second is what v6 warns about twice ("Tagesschluss-Renditen unterschätzen das Risiko
systematisch, und für Grid gilt das doppelt"). It is presently a 10% sample.

## Why the 78 are missing: emitter generation — and the recovery is a re-run, not a re-parse

2.3 asks whether the 78 rows with `entry_time_records: 0` are a tester, parser or aggregation
fault. **It is none of the three.** The schemas form four strictly nested generations:

| generation | added keys | sleeves | median write time |
|---|---|---:|---|
| base | event, time, net, profit, swap, commission, volume, notional, symbol | **78** | 2026-07-08 |
| +entry_time | entry_time, mae_acct | 55 | 2026-07-17 |
| +magic | magic | 66 | 2026-07-24 |
| rich | money_basis, side, entry_price, exit_price, fee, entry/exit_commission | 17 | 2026-08-12 |

Nesting verified: `rich ⊆ magic ⊆ entry_time ⊆ all`; `magic \ entry_time = 0`, `rich \ entry_time = 0`.
**Positive control:** the four exclusive buckets sum to 216 with no file counted twice. A second,
independent signal agrees — median write time reproduces the generation order without using any key
information.

**The 78 base-generation sleeves are exactly the 78 rows carrying `entry_time_records: 0`.**

**The emitter is the EA, not a Python parser.** The Q08 aggregate records
`source_artifact_kind: "fresh_baseline_common_stream"` with
`source_artifact_path: …\MetaQuotes\Terminal\Common\Files\QM\q08_trades\<sleeve>.jsonl`, and the
writer is `framework/include/QM/QM_Common.mqh:1717`, emitting one JSON line per closed position
during the backtest. The **current** framework already emits the full rich schema — `money_basis,
magic, side, entry_price, exit_price, time, entry_time, mae_acct, net, profit, swap, fee,
commission, entry_commission, exit_commission, volume, notional, symbol`.

So nothing needs to be written. The non-rich sleeves are EAs whose Q08 ran under an older framework
build, and **no re-parse can recover a field the EA never emitted.** Recovery is: rebuild against
the current framework, re-run Q08.

## The cost of 2.3, scoped to the pool that matters

The corpus-wide 78/199 are not the cost — the 2.2 pool is. Of its **91 pairs**:

| stream generation | pool pairs | what it can support |
|---|---:|---|
| rich | **12** | full 3.3 incl. intraday mark-to-market |
| +entry_time (no side/prices) | 63 | closed-trade daily path only |
| base | 16 | neither |
| no stream | **0** | — |
| **sum** | **91** | control: equals pool size |

**12 of 91 pool pairs are 3.3-capable today. 79 need a Q08 re-run**, of which 16 lack even
`entry_time`. That is the real magnitude of 2.3, and it is a re-run cost, not a parsing cost.

## Two structural findings that outlive this point

**The streams have no committed producer on the Python side.** Repo-wide, 20 files *read*
`sleeve_streams`; none write it. The copy step from Common\Files to
`D:\QM\reports\portfolio\sleeve_streams\` is not in the repo. Same class as the near-miss register
fixed earlier today.

**The generations overlap in time, so this is not a completed migration.** Base-generation files
were written as late as 2026-08-16, well after the rich emitter appeared on 2026-08-03 — consistent
with EAs being rebuilt at different times rather than a clean cutover. The records carry no schema
version field, so the generation must be inferred from which keys are present. Any consumer that
assumes a field exists gets a silent partial answer instead of an error.

## My own errors in this measurement

**A key-format mismatch, for the third time today.** `pool_union_20260817.json` keys pairs as
`10094:GDAXI` (bare number) while my generation map used `QM5_10094:GDAXI`. Every lookup missed and
the first run reported "no stream at all: 91 of 91". The control caught it immediately — 91/91 in
one bucket is self-evidently wrong, and QM5_10145 was known to be rich. Same shape as this
morning's registry check and this evening's review triage. **This is now a recurring class, not
three incidents** — it belongs to 1.16.

**A filename regex that silently excluded a whole EA class.** `(\d+)_(.+)_DWX$` does not match
basket sleeves, whose streams are named `12712_QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1.jsonl`
without the `_DWX` suffix. Six pool pairs were reported as having no stream; all six have one
(1 base, 5 +entry_time). The corrected counts are in the table above.

## Evidence

- `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\*.jsonl` — 216 files, 58,599 records
- emitter: `framework/include/QM/QM_Common.mqh:1717` (and the buffering note at `:120-124`)
- provenance: `portfolio_stream.source_artifact_kind` / `source_artifact_path` in any Q08
  `aggregate.json`, schema `q08_aggregate/v2`, stream identity `q08_portfolio_stream/v2`
- pool: `artifacts/pool_union_20260817.json`, schema `qm.pool-union-2p2/v2`, 91 members
- blocked consumer: `tools/strategy_farm/portfolio/build_book_ftmo.py:167`
- relates to `docs/ops/evidence/2026-08-17_point_2_2_the_pool_union_is_91_not_over_100.md`
