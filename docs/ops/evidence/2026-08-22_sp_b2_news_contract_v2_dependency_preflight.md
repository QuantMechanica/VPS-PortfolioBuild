# SP-B2 News Calendar Semantics V2 Dependency Preflight

Date: 2026-08-22

Router task: `84c988e6-fe11-47ed-b9f3-413096628bd2` (`SP-B2`)

## Verdict

DEPENDENCY_HOLD — implementation and shared-data mutation were not started.
SP-B1 is approved, but both remaining gates named by the routed task are open:

1. ROT-2 (the OWNER impact-taxonomy / authoritative-source decision) is still
   unratified; and
2. the Q09_NEWS pilot plus its dependent rerun wave are not complete.

Starting the requested implementation now would require inventing the missing
impact policy and would risk changing calendar semantics underneath an active
Q09_NEWS measurement. Both actions are forbidden by the task's own
`depends_on`, collision note, and hard constraints.

No source, calendar seed, FILE_COMMON copy, Q09 evidence, pipeline verdict,
work item, terminal, or AutoTrading state was changed during this preflight.

## Dependency evidence

### SP-B1 — satisfied

Router task `4fd8126c-2792-44d0-8b59-e7779a531176` (`SP-B1`) is `APPROVED`.
Its contract is committed as
`docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md` at commit `24bc6efe8`.

The approved review verdict explicitly states that SP-B2 remains gated until
the Q09 rerun and OWNER mapping decision.

### ROT-2 — not satisfied

The normative SP-B1 contract's OWNER decision section records:

```text
Recorded as: pending, no OWNER response yet as of this document's date
(2026-08-22).
```

Repository and active-router searches found no
`decisions/YYYY-MM-DD_news_impact_taxonomy.md`, no ratified authoritative
source, and no active OWNER decision row superseding that pending status.

Without ROT-2, the following acceptance items cannot be implemented honestly:

- exactly one authoritative source for impact-sensitive consumption;
- the `qm.news_impact_mapping.v1` source-field and policy meaning;
- the mapping fingerprint shared by backtest and live evidence; and
- reconciliation of the two sources' documented 41.7% impact disagreement.

Choosing any of those in code would be an invented policy value.

### Q09 pilot / rerun — not satisfied

Read-only farm DB and filesystem observations during this preflight:

- pilot work item:
  `b2468d2e-92a5-4fd8-a6ae-29967da0ca08`;
- EA / symbol: `QM5_11294` / `XAUUSD.DWX`;
- state: `active`, claimed by `T2`, no verdict and no evidence path;
- sealed plan size: 40 cells;
- durable cell receipts at observation: 22;
- cells without a receipt at observation: 18;
- `q09_news_tests` final row: absent;
- final aggregate: absent.

The active runner was not interrupted. The 41-row append-only rerun ticket
`14487282-3868-43cb-b22d-00ea049de0b8` remains `BLOCKED`; its review verdict
requires the pilot to reach 40/40 receipts and receive review before that wave
may start.

The routed SP-B2 text names both `b2468d2e` and `14487282` and says common data
may be changed only after the colliding Q09 rerun completes. Therefore neither
the current 22/40 pilot nor the still-blocked downstream wave satisfies the
gate.

## Checks performed

- Read SP-B1 contract in full and confirmed its implementation prerequisite
  and pending OWNER decision.
- Read the router records for SP-B1, SP-B2, and `14487282`.
- Opened `farm_state.sqlite` read-only and confirmed the pilot's active claim,
  absent final verdict, absent `q09_news_tests` row, and absent evidence path.
- Counted 22 `cell_receipt.json` files across the 40 sealed cell directories.
- Confirmed the pilot log's current runner invocation is on T2.
- Searched canonical decisions/docs and active task payloads for a ratified
  ROT-2 decision; only the pending decision template exists.

## Deterministic resume conditions

SP-B2 may be re-routed only when all of the following durable facts exist:

1. an OWNER-ratified ROT-2 decision artifact names the authoritative calendar
   source or exact reconciliation policy;
2. pilot `b2468d2e` has 40/40 terminal receipts, a final aggregate, and review;
3. the gated `14487282` append-only rerun wave has completed to its own reviewed
   terminal state; and
4. no Q09_NEWS run remains active against the shared V1 calendar inputs that
   SP-B2 would replace.

At that point implementation must use the approved
`qm.news_calendar_semantics_contract.v2` contract without altering existing
verdicts, and must produce the March plus October/November DST tests,
duplicate-source tests, 3,502-row before/after audit, fail-closed 0/>1-source
loader evidence, and matching backtest/live fingerprints required by SP-B2.
