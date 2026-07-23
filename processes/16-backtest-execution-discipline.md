---
title: Backtest Execution Discipline
owner: OWNER
last-updated: 2026-07-22
---

# 16 — Backtest Execution Discipline

A result is valid only when the tester actually ran the declared artifacts and
conditions. Labels, filenames, expected metrics, and reviewer assertions are not
evidence.

## Preflight

- source and compiled binary hashes match the intended build;
- source and deployed binary/setfile hashes match;
- symbol, custom-symbol validation, timeframe, terminal, account mode, and tester
  model are explicit;
- requested and actual date ranges are recorded separately;
- history coverage and relevant calendar/data dependencies are available;
- deposit, leverage, risk mode, commissions, spread, slippage, and other cost
  assumptions are explicit;
- tester journal is free of initialization, parameter, history, and report errors.

## Execution

1. Use a free T1-T5 tester slot and do not disrupt running workers.
2. Preserve tester configuration, journal, report, deployed artifacts, and summary.
3. Bind the summary to SHA-256 hashes of the tester config, report, source/deployed
   binary, source/deployed setfile, and relevant runner code.
4. Fail closed on drift, missing report, date mismatch, invalid parameters, history
   gaps, or an unparseable result.
5. A PASS needs the phase's numerical conditions and valid trade evidence. Zero
   trades follows [02-zt-recovery.md](02-zt-recovery.md).

## Verdict rules

- Infrastructure/setup failure is `INVALID` or `BLOCKED_INFRA`, never strategy
  FAIL and never PASS.
- A strategy FAIL keeps its report and exact artifact lineage.
- Rerunning with a changed binary, setfile, data interval, model, or costs creates
  new evidence and cannot retroactively validate the prior run.
- Smoke-test profitability is diagnostic only; strategy success requires the full
  prescribed development, out-of-sample, stress, and promotion evidence.
