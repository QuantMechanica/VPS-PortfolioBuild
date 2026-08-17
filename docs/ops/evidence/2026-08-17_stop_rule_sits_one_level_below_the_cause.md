# The poison-pill stop rule sits one level below the cause — six EAs fail broadly and never trip it

v6 §4 carries the rule *"eine Wiederholungsgrenze liegt auf der Ebene der Ursache."* This is a
measured instance of it in the running factory.

## The finding

`poison_pill_quarantine` counts **five consecutive same-reason `INFRA_FAIL` rows on one
`(ea_id, symbol, phase)` key** (`poison_pill_quarantine.py:3`, verdict filter at `:89`, table key
at `:25`). That is the right shape for a fault that is specific to a symbol or a phase.

It is the wrong shape for a fault that lives in the **EA binary**. An EA whose stream emitter is
broken fails once or twice on *each of many symbols* — broadly rather than deeply — so it never
accumulates five on any single key, and the stop rule never sees it.

| EA | class failures | distinct (symbol, phase) keys | max on any one key | quarantined |
|---|---:|---:|---:|---|
| QM5_1371 | **19** | 18 | 2 | no |
| QM5_1118 | 14 | 14 | 1 | no |
| QM5_10297 | 10 | 9 | 2 | no |
| QM5_11170 | 7 | 3 | 3 | no |
| QM5_10973 | 6 | 3 | 2 | no |
| QM5_11886 | 5 | 5 | 1 | no |
| | **61 rows** | | | |

QM5_1371 is the clearest case: it carries `stream_and_selfreport_missing` on **19 of its 21 Q04
rows**, spread over XAGUSD, XTIUSD, XNGUSD, USDJPY, USDCHF, USDCAD, UK100, SP500, NZDCHF, NZDCAD,
GDAXI, GBPUSD, GBPJPY, GBPCHF, GBPCAD, GBPAUD, EURUSD and EURAUD — clean only on NDX and EURGBP.
Two failures per symbol at most, so the counter never reaches five.

**The class is eligible for the counter**, so this is not a filtering exclusion: the rule accepts
any `verdict_reason`, and today's QM5_1371 (20:47:01) and QM5_10297 (20:44:36) rows are both
`INFRA_FAIL`. All 184 active quarantines carry a different reason — 183
`summary_missing_retries_exhausted`, 1 `run_smoke_fail` — and **none** carry this one.

## What it costs

61 `INFRA_FAIL` rows so far, and it does not self-limit: each new symbol dispatched to one of these
EAs produces one more. QM5_1371 and QM5_10297 alone account for 29.

These rows also read as infrastructure faults in every throughput and health surface, which is the
second cost: an EA-level defect is being counted as factory flakiness.

## Where the symbol story went

This surfaced as an apparent XAGUSD concentration — 5 of 9 XAGUSD Q04 rows in 24 h, and 7.43%
all-time on 148 rows against a 1.63% overall base rate. That is real but derivative: XAGUSD has low
total Q04 volume, and two carrier EAs each ran it twice. The carrier is the **EA**, not the symbol.
The two EAs that fail *specifically* on XAGUSD (QM5_1100 at 1 of 38 rows, QM5_1119 at 1 of 33) each
failed one XAGUSD run and passed the other — transients, not a symbol mechanism.

## My own error, caught by the control

The first pass reported six EAs in a "blind spot" and its positive control came back **MODEL
WRONG**: QM5_1386 is quarantined with a per-symbol max of 1, which the model said was impossible.

The model was right; **the control was wrong**. I compared per-symbol maxima computed *within the
`stream_and_selfreport_missing` class* against quarantine membership driven by an entirely
different reason (`summary_missing_retries_exhausted`) at a different phase (Q02). Apples to
oranges. The conclusion above is re-grounded on the rule as written in source rather than on my
inference from the table's contents.

Worth keeping: the control did its job. It stopped a claim that was correct from reaching the
report on reasoning that was not.

## Recommended shape, not applied

The counter's key should include a level at which a binary-level fault accumulates — a per-`ea_id`
counter alongside the existing per-`(ea, symbol, phase)` one, tripping on N distinct keys carrying
the same reason rather than N consecutive on one key. Not applied here: changing a stop rule is
behaviour-changing, needs its own threshold justification and a re-derivation of what it would have
caught historically.

The immediate, reversible step is narrower: these six EAs are candidates for a rebuild against the
current framework, which is the same remedy as
`docs/ops/evidence/2026-08-17_point_2_3_exits_are_present_direction_is_the_gap.md` identifies for
the stream schema generally — the emitter lives in the EA (`QM_Common.mqh:1717`), so a stale binary
is the common cause of both.

## Evidence

- rule: `tools/strategy_farm/poison_pill_quarantine.py:3` (contract), `:25` (key), `:89` (INFRA_FAIL filter)
- claim-time enforcement: `tools/strategy_farm/farmctl.py:1173-1177`
- counts re-derivable from `work_items` where `payload_json LIKE '%stream_and_selfreport_missing%'`
- quarantine census: 184 active, 183 `summary_missing_retries_exhausted`, 1 `run_smoke_fail`
