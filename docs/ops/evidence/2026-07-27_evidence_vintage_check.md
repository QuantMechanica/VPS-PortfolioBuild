# QM5_9936 evidence-vintage check — execution attempt

Date: 2026-07-27
Router task: `598dd8fe-cf28-414a-866a-e7839070c5a5`
Verdict: **NOT ESTABLISHED — current-tree functional equivalence was not measured**

## Archived provenance

The load-bearing archived stream is
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`.
Its provenance is established by
`D:/QM/reports/pipeline/QM5_9936/Q08/_baseline/QM5_9936/20260727_035506/summary.json`:

- EA/symbol/timeframe: QM5_9936 / USDJPY.DWX / H1.
- Window and model: `2017.01.01` through `2025.12.31`, model 4.
- Canonical set:
  `QM5_9936_ff-range-breakout-gmt3-h1_USDJPY.DWX_H1_backtest.set`,
  SHA-256 `be779ffa2a1617f3297b2e42dbe921dd7ddc1e24c072841c88379f271f752c61`.
- Archived EX5: 330,340 bytes, written 2026-07-14, SHA-256
  `a1de7a7be28a40b592400c1fa3631d1fbd3f7e45c03f4b1763b99acd44e868ca`.
- Source recorded by that run: SHA-256
  `aac82a7c08255372b63deef8060317c44f8e3cd4b2f8b364ba46896d0d7e364e`.
- Terminal: T10. Trade count: 1,252. Net profit: 149,396.39.
- Commission group: canonical Darwinex group SHA-256
  `25314333af81faf48e2afe2db5d52beea640cc74ec33a85a46b7c43aadb921dd`,
  restored to canonical after the run.
- Exact tester INI SHA-256:
  `ee9fe48ee20349bdb2864fb3ff1a62aa2236248c65a93f9d16daa06391a48e2a`.

This corrects the earlier erroneous attribution to the 05:17 neighborhood
perturbation: the durable stream is from the 03:55 canonical Q08 baseline.

## Current build

Current QM5_9936 compiled clean on 2026-07-27:

- compile log:
  `framework/build/compile/20260727_183750/QM5_9936_ff-range-breakout-gmt3-h1.compile.log`;
- 0 errors, 0 warnings;
- EX5 size 363,810 bytes;
- EX5 SHA-256
  `7ea6234d772aa161f00c66ebb06eb8df5f592251f143ca119fea64e4bed0929f`.

The byte difference is not itself a functional failure.

## Reproduction attempt

The current build was deployed through `run_smoke.ps1` to reserved T2 with the same
canonical set, model 4, H1, 2017-01-01 through 2025-12-31, USD 100,000 deposit,
1:100 leverage and the canonical commission group. The generated INI is:

`D:/QM/reports/timer_fidelity_9936/control/QM5_9936/20260727_184011/raw/run_01/tester.ini`

The attempt was not a completed backtest. The terminal recorded 19% progress and
then `"some error after pass finished"`; it produced neither a report nor a durable
trade stream. The reserved T2 lane was immediately reclaimed by its persistent
factory worker for work item `ef0303b5-cebd-45d3-948b-5b53201a3798`. Sharing or
interrupting that active factory terminal is forbidden, so no retry or bisect was run.

## Requested comparison

| measure | result |
|---|---|
| match rate | NOT ESTABLISHED |
| same-entry/same-volume/shifted-exit | NOT ESTABLISHED |
| different entry | NOT ESTABLISHED |
| extra/missing trades | NOT ESTABLISHED |
| trade-count delta | NOT ESTABLISHED |
| net P&L delta | NOT ESTABLISHED |
| med60 delta | NOT ESTABLISHED |
| \|wDay\| delta | NOT ESTABLISHED |
| wDD_p90 delta | NOT ESTABLISHED |
| FUND_SCORE delta | NOT ESTABLISHED |
| causal commit/mechanism | NOT APPLICABLE until divergence is observed |

## Verdict

The archived stream has reproducible documentary provenance, but whether the current
tree is functionally identical to it remains **NOT ESTABLISHED**. Consequently this
attempt cannot certify that the archived streams remain a valid basis for current-tree
book numbers, and it also cannot order regeneration. A valid retry must first obtain an
exclusive terminal that its live worker actually honors, complete the current-tree
control, and only bisect if the resulting trade stream diverges.
