---
title: Zero-Trades Recovery
owner: OWNER
last-updated: 2026-07-22
---

# 02 — Zero-Trades Recovery

Use this process when an EA was expected to trade but a real backtest produced zero
trades. Zero trades is a diagnostic result, not permission to reject the strategy,
weaken its rules, or manufacture trades.

## Trigger and scope

- The tested build, setfile, symbol, timeframe, interval, and model are known.
- The card implies trades should be possible in that interval.
- Cohort-wide zero trades or repeated zero trades across expected symbols raises
  priority; isolated symbol noise is documented without inventing a systemic fix.

Intentional no-trade modes and periods with no qualifying event are excluded.

## Recovery order

1. **Bind the run.** Record source/binary/setfile hashes and the tester's actual
   dates, symbol, timeframe, model, costs, terminal, report, and journal.
2. **Eliminate infrastructure causes.** Check history coverage, symbol mapping,
   custom-symbol validity, deployed binary/setfile drift, input parsing, calendar
   availability, initialization errors, and tester/report integrity.
3. **Instrument the decision path.** Emit bounded structured reasons for entry
   window, data, setup, direction, geometry, cost, risk, and order rejection.
4. **Locate the first false condition.** Compare the card's mechanical rules with
   the runtime values. Do not guess from the final trade count.
5. **Repair at the right layer.** Fix serialization, time-window matching, data
   access, framework plumbing, or a card-code mismatch at its source.
6. **Compile and rerun.** Use the exact repaired artifacts in a real backtest and
   retain both the zero-trade and repaired evidence.

## Version rule

- A deterministic implementation defect may be repaired in place while the build
  has not passed empirical qualification, with hashes proving the change.
- A change to the economic entry, exit, sizing, session, or filter mechanics is a
  new strategy version and restarts every required phase.
- Removing filters or loosening thresholds solely to force trades is prohibited.

## Exit

- **Recovered:** entry hooks fire, order decisions are explained, and a real
  artifact-bound run produces plausible trades or an evidence-backed legitimate
  no-trade outcome.
- **Infrastructure blocked:** exact missing data or environment precondition is
  recorded; no strategy verdict is issued.
- **Card mismatch:** the discrepancy is sent to OWNER for card correction or a new
  version decision.
- **Strategy falsified:** only valid phase evidence, not the absence of diagnostics,
  may support this result.
