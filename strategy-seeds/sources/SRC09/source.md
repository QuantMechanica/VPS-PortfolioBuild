---
source_id: SRC09
source_id_status: CONFIRMED_OWNER_DELEGATED
source_type: paper
title: Intraday Patterns in FX Returns and Order Flow
authors: Francis Breedon and Angelo Ranaldo
publication: Journal of Money, Credit and Banking 45(5), 2013, 953-965
doi: https://doi.org/10.1111/jmcb.12032
working_paper_url: https://www.econstor.eu/bitstream/10419/97343/1/690223323.pdf
status: EXTRACTION_COMPLETE_CARD_APPROVED
created: 2026-07-17
created_by: Research
last_updated: 2026-07-17
approval_basis: "Explicit OWNER instruction in this workspace on 2026-07-17: alles freigegeben, los gehts!"
parent_issue: LOCAL_OWNER_APPROVAL_RECORD
---

# SRC09 — Breedon and Ranaldo, Intraday Patterns in FX Returns and Order Flow

## Source approval and boundary

OWNER explicitly approved the proposed sources and execution work on 2026-07-17. This repository record is the durable authorization under Process 13 and does not require a second role or external issue approval.

The next unused canonical numeric source slot found during the registry audit was SRC09. OWNER authorized the work on 2026-07-17; canonical local source, card, and registry artifacts are the durable coordination record.

## Source text and exhaustive read

- Full working paper: https://www.econstor.eu/bitstream/10419/97343/1/690223323.pdf
- 19 PDF pages, 475 extracted text lines.
- Read end-to-end on 2026-07-17, including tables, notes, conclusion, and references.
- Empirical sample: January 1997 to early June 2007.
- Primary EBS pairs: EUR/USD, USD/JPY, GBP/USD, EUR/JPY, USD/CHF, and AUD/USD.
- The paper uses firm EBS bid and ask quotes for its executable strategy-cost calculation.

## Distinct strategies extracted

One strategy package was identified:

| Slot | Slug | Card | Status |
|---|---|---|---|
| S01 | fx-session-flow | strategy-seeds/cards/fx-session-flow_card.md | APPROVED; source fidelity PASS and build contract frozen |

The European short and US long legs are not split into separate cards. They use the same market-inefficiency thesis and the same local-session rule, applied symmetrically to the base- and counter-currency trading centres. They remain independently ablatable parameters inside one Strategy Card.

No order-flow-prediction EA was extracted. The paper uses proprietary EBS and BNP Paribas order-flow data to explain the return pattern, but the tradable rule itself requires only time and EURUSD price quotes. External order-flow data would violate the Darwinex-native-data boundary and is not needed for the source rule.

## Source-faithful rule

For EURUSD:

- short EURUSD at 07:00 Europe/London,
- close that short at 08:00 America/New_York because the counter-currency session starts before the European session ends,
- after confirmed close, long EURUSD at 08:00 America/New_York,
- close the long at 16:00 America/New_York,
- use explicit and separate London and New York DST calendars.

The source reports that most tested pairs do not remain profitable after bid/ask costs. EURUSD is therefore the only primary implementation target. The other pairs are cross-sectional falsification probes, not automatic build symbols.

## Duplicate and lineage check

The strongest near-duplicate is QM5_10012 rw-fx-intraday-seas. It selects the best M30 slot in-sample from a secondary Robot Wealth source and holds for a chosen number of bars. SRC09_S01 instead fixes two source-defined session legs before testing and forbids slot selection. Different source plus different entry construction means a new Strategy Card is appropriate, with explicit correlation and family-cap review later.

Additional controls:

- fx-early-asia-drift was rejected because broker wallclock was misread as UTC and created a rollover artifact. SRC09_S01 therefore requires independent broker-time reconstruction, DST-mismatch slices, and report-level timestamp proof before Q02 can pass.
- QM5_12846 euro-night-mr-eurusd uses an overnight limit mean-reversion rule and is not a mechanical duplicate.
- No matching Breedon/Ranaldo source registration or card existed before this extraction.

## Source limitations carried into review

- The source sample ends in 2007; persistence in 2015-2026 is unproven.
- Reported executable costs are EBS interdealer bid/ask costs, not current FTMO/Darwinex CFD costs.
- The paper specifies time exits but no stop loss, position-sizing method, or maximum daily loss.
- Bank holidays may materially change the order-flow pattern.
- Session definitions are robust to small timing changes in the paper, but no hour optimization is authorized in V5.

These limitations are falsification requirements, not reasons to alter the source rule before baseline replication.

## Independent Quality-Business review

The 2026-07-17 read-only review returned `CHANGES_REQUIRED`, not `REJECT`:

- source fidelity and manual duplicate adjudication passed,
- the generic Friday 21:00-broker close would truncate the source's Friday US leg and needs a reviewed exception plus mandatory 16:00-New-York exit,
- the framework has no reviewed London-DST helper, so UK/US transition fixtures are a pre-build gate,
- one-shot entry behavior had to be separated from repeated-until-flat exit recovery and restart reconstruction,
- protective stop, virtual sizing, daily family risk, execution-cost capture, and holiday-data contract remain approval gates,
- canonical headings and the `modules_used` mapping were repaired in the card; the repository's competing legacy schema linter still needs process-level reconciliation.

## Completion state

Source extraction is complete with one card in terminal `APPROVED` state. Sequential production EA ID 4006 and EURUSD.DWX slot 0 are allocated by the local registry update dated 2026-07-17. Per the depth-first rule, the next source may now proceed. Build and pipeline evidence remain separate gates; deployment and AutoTrading are not authorized.
