# Q08 entry-time coverage diagnosis — 2026-07-27

## Verdict

The 70 streams cannot be backfilled safely from the consolidated evidence as
stored. Do not infer entry times and do not modify the streams. Ten currently
gate-clean sleeves are ranked for capacity-approved Q08 reruns below.

## Coverage and cause

Direct parsing of
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/*.jsonl` found 192 current
files: 122 have complete `entry_time`; exactly 70 have none. Those 70 contain
14,217 trade records and **0 populated entry times**. This all-or-nothing split
is schema generation, not intermittent record loss.

Git history identifies the boundary. Commit `715b0c0770dbe6c6ca542ceff3fed50f1312919e`
(2026-06-30 21:23 +02) introduced the MAE state and changed the emitted
`TRADE_CLOSED` JSON from close-time/net fields to include `entry_time` and
`mae_acct`. Commit `234860d6e6b939ddcf68de1243a99376b50f1339`
later fixed SL/TP close capture. Current `QM_Common.mqh` obtains position time,
falls back to deal history, and emits it at lines 936–942. Therefore new runs
write the field now.

The missing/full file modification ranges overlap because consolidation and
copying happened after the emitter change; mtime is not run provenance and was
not used to invent a split. The causal split is **70 legacy-schema streams /
122 current-schema streams**.

## Recoverability check

Native `report.htm` files exist for some affected EAs, including QM5_12823, and
may contain order/deal rows. They are not a safe backfill source for the current
consolidated JSONL:

- legacy records carry close time, net, volume and symbol, but no deal,
  position, order, run, or work-item identity;
- multiple Q-phase/run reports exist for the same EA/symbol and overlapping
  periods;
- matching a close by timestamp/net is therefore an inference and can be
  ambiguous (partial closes and equal-valued deals make it non-bijective);
- no alternate JSONL under `D:/QM/reports/work_items/` contains `entry_time`.

Without a durable record-to-report lineage key, a parser could produce plausible
times but could not prove them. The fail-closed result is **rerun required**.
No stream was changed or backed up because no mutation was performed.

## Ranked rerun candidates

Latest completed Q02–Q07 verdicts were required not to be a known failure, and
Q08 had to be `PASS`, `PASS_SOFT`, `MULTI_SEED_PASS`, or `FAIL_SOFT`. Ten sleeves
qualify; ranking is by recoverable record count (more historical observations
first):

| Rank | Sleeve | Records | Current Q08 |
|---:|---|---:|---|
| 1 | 12823:USDJPY | 1,548 | FAIL_SOFT |
| 2 | 10115:GDAXI | 392 | FAIL_SOFT |
| 3 | 10815:EURUSD | 123 | FAIL_SOFT |
| 4 | 10943:NDX | 116 | FAIL_SOFT |
| 5 | 9929:XAUUSD | 115 | FAIL_SOFT |
| 6 | 12712:EURGBP/EURAUD cointegration basket | 87 | FAIL_SOFT |
| 7 | 11128:NDX | 75 | FAIL_SOFT |
| 8 | 10920:XAUUSD | 64 | FAIL_SOFT |
| 9 | 11129:SP500 | 43 | FAIL_SOFT |
| 10 | 11124:SP500 | 41 | FAIL_SOFT |

Tester cost is ten Q08 stream-producing runs (plus whatever deterministic
sub-runs each Q08 contract requires); wall-clock cost is NOT ESTABLISHED from
the stream evidence and is not guessed. The other 60 streams should not consume
tester capacity until their gate state becomes eligible.

No rerun, history import, factory switch, terminal action, queue mutation, or
live setting change was performed.
