# QM5_9936 evidence-vintage bisect

Date: 2026-07-28  
Router task: `54d1c57d-e0c5-46d0-af06-07ac48867636`

## Verdict

**The published 0.835463 mismatch is not a valid common-window statistic.**
The fresh run actually starts at `2018-07-02`, while the archived stream contains
113 trades before that boundary. The earlier comparator fed the entire 1,252-row
archive to the 1,143-row fresh stream and called the result a common-window
comparison. Its `109 missing` category is therefore predominantly a window
artifact, not entry suppression.

After filtering the archive by `entry_time >= 2018-07-02`, the evidence is:

| measure | fresh | archive overlap |
|---|---:|---:|
| rows | 1,143 | 1,139 |
| exact `(entry, exit, net, volume)` | 1,046 | 1,046 |
| same entry and volume, changed exit/net | 72 | 72 |
| unmatched after same-entry pairing | 25 | 21 |
| net extra fresh rows | 4 | — |
| exact / larger stream | **0.915136** | — |

The remaining 97 non-exact fresh rows are real, but their causal commit is **NOT
ESTABLISHED** by the durable evidence available in this cycle. No governed
historical probe has completed, so naming a commit as measured fact would invent
pipeline evidence.

## Provenance and reproducible checks

The archived provenance is the 2026-07-27 Q08 baseline summary:

`D:/QM/reports/pipeline/QM5_9936/Q08/_baseline/QM5_9936/20260727_035506/summary.json`

It records EX5 SHA-256
`a1de7a7be28a40b592400c1fa3631d1fbd3f7e45c03f4b1763b99acd44e868ca`,
written 2026-07-14, and 1,252 trades. The fresh governed summary is:

`D:/QM/reports/work_items/588af557-300f-4e25-82a4-81974b04380a/QM5_9936/20260727_215505/summary.json`

It proves `FromDate=2018.07.02`, EX5 SHA-256
`5acdab8737c9579107cb7d2c05ac44034cc9ff9b368c13a8d5061255c29e3cd4`,
and 1,143 trades. Direct JSONL census found 113 archived entries before the fresh
boundary (2017-10-09 through 2018-06-29).

The overlap decomposition uses multiset intersections, avoiding the extended
comparator's greedy ordinal pairing after the first mismatch. The direct identities
are `(entry_time,time,round(net,2),round(volume,2))`; the secondary identity is
`(entry_time,round(volume,2))`.

## Content-filtered suspect list

Tracing `QM5_9936_ff-range-breakout-gmt3-h1.mq5` through `QM_Common.mqh` leaves
these behavior-capable changes since the archived binary:

| commit | content | relevance |
|---|---|---|
| `2b7e73b83229` | `QM_Common.mqh` execution-contract machinery | No call was added to 9936; static-only for this EA. |
| `ae029ce59da3` | `QM_NewsFilter.mqh` fresh/boundary APIs | Existing 9936 entry path does not call the new fresh API. |
| `cb944ba48a4b` | `QM_Entry.mqh`, `QM_RiskSizer.mqh`, `QM_TradeContext.mqh`, `QM_TradeManagement.mqh` | Replaces entry sizing's approximate margin rail with `OrderCalcMargin`; behavior-capable, but fresh log has zero `RISK_CLAMP` and only 14 broker rejects. It does not explain shifted exits. |
| `5b21b9b1d485` | `QM_Entry.mqh` pending duplicate guard plus risk/news audit changes | Behavior-capable entry suppression. Fresh log contains zero `pending_order_same_magic_symbol_type`, excluding it for this run. |
| `37196e79dc7a` + `7dc4751ca188` | trade-modify suppression/stops precheck, then tester-only rollback | The final state explicitly keeps historical tester behavior; not established as causal. |
| `6e92c806264d` | equity-stream/logger/news evidence controls | Evidence plumbing; no established trade-decision mechanism. |
| `6f2393373146` | kill-switch persisted state | Tester path bypasses persisted restore; not causal in this governed test. |
| `f0301ecf78a9` | 43-line change to the 9936 EA: include and call `QM_PropFirm.mqh` | Only post-vintage commit that changes 9936's `.mq5`. Default `prop_phase=OFF` returns allow/true, so static reading does not prove a mechanism. This is the first probe boundary, not a verdict. |
| `a35c083382f6`, `d5917a9ff061`, `07c4b18444d` | `QM_PropFirm.mqh` rewrite/fixes | Included by current 9936, but all relevant default-OFF paths claim no-op. Requires the same probe as `f0301ecf`. |
| `3ce7e67e2cb9` | news coverage warning | Logging-only for tester verdicts. |

`QM_MagicResolver.mqh` pump commits were excluded after content inspection: the
9936 mapping remains `99360000`; rows for unrelated EAs cannot explain its stream.
Basket, market-calendar and joint-EA module changes are not in the standalone
9936 decision graph.

The highest-information governed probe is therefore one short dense window
compiled at `f0301ecf^` versus `f0301ecf`, with identical current calendar seed,
set, model and terminal harness. Until it completes, intentional-versus-accident
is **NOT ESTABLISHED**.

## FUND_SCORE drift

The established screening formula was applied directly to both durable streams:

| stream | rows | net (stream) | med60 | \|worst day\| | wDD p90 | FUND_SCORE |
|---|---:|---:|---:|---:|---:|---:|
| archived full vintage | 1,252 | 164,460.68 | 3.34246% | 1.76437% | 8.18219% | **0.40850** |
| fresh (2018-07-02 onward) | 1,143 | 132,405.79 | 3.01905% | 1.92851% | 8.31314% | **0.36317** |

The raw delta is `-0.04534` (`-11.1%`) in FUND_SCORE. It combines implementation
drift with the unequal start window, so it is not a clean causal estimate.
Nevertheless the direction is adverse and large enough that the archived 0.41
9936 score and any 0.641 book composition depending on it must not be represented
as current-tree measurements.

## Decision and bill

Do **not** revert a framework commit on this evidence: the causal boundary is not
measured. Do **not** regenerate all sleeves yet either: that would spend tester
capacity before distinguishing a 9936-local prop wrapper from a shared-framework
change.

Required next bill, through the governed queue:

1. two short-window 9936 probes bracketing `f0301ecf` (serial compiles, SHA-256
   recorded);
2. if that boundary reproduces the 72 shifted exits, classify the prop-wrapper
   change and either repair/revert it or accept it as intentional;
3. if it does not, binary-search the remaining behavior-capable commits above;
4. only for an intentional shared-framework change, regenerate the 15 gate-clean
   sleeve streams and rerun the 35 Q09 compositions; for a 9936-local change,
   regenerate 9936 and every composition containing it.

Tester cost for step 4 is **NOT ESTABLISHED** from the present artifacts; the only
measured full 9936 governed run had a 150-minute inner budget, but elapsed tester
minutes per each of the other 14 sleeves were not collected here.

