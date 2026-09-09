# Fleet session clock audit — 2026-09-09

Task: `95b48188-1d1a-461f-96cb-3ceb6a2f0618` (priority 80).
RESULT: PARTIAL_REVIEW — reproducible inventory and provisional top 10 delivered; exhaustive placement-path classification and measured affected-trade ranking remain open. No EA source changes or factory work items were made for this task.

## Evidence and scope

The canonical active identity registry is intersected with work_items having a Q02-or-later PASS/PASS_SOFT/PASS_LOWFREQ, Q14, or optimization-census lineage. Source filename and active slug must match. Strategy time inputs and hour comparisons trigger inclusion; the shared qm_friday_close_hour_broker and timeframe-only inputs do not. Duration-only inputs remain explicit N-A rows. Historical PASS depth is an observation, not current qualification or permission to promote.

Inventory: **804 EAs**. Automated classifications: MATCH=93, MISMATCH=0, UNSTATED-IN-CARD=554, N-A=157. MATCH is a static screening label, not a proof that the upstream source uses that clock. Missing local cards are distinguished from alternate SPEC.md evidence.

- `2026-09-09_fleet_clock_inventory.csv`: one row per EA, SHA-256, input defaults, source/card file:line citations, PASS work-item/report, reference Q02 trade count and report, pending-order evidence.
- `2026-09-09_fleet_clock_scope.json`: database URI, timestamp and excluded source rows.
- `2026-09-09_fleet_clock_audit.py`: read-only query and reproducible extraction.

## Provisional top 10

Requested score = PASS depth × shift hours × trades affected. Actual trades affected are unknown until a controlled counterfactual is measured. The following **triage proxy**, not that measured score, uses the latest cached Q02 report trade count and a conditional shift (1h for fixed +3 vs broker or European/US transition mismatch; 3h for an unconfirmed raw-broker vs UTC source). Runs differ in symbol and duration, and family members are correlated. These numbers cannot rank expected economic improvement.

| Rank | EA | Historical depth | Reference trades | Conditional shift | Proxy score | Hypothesis / next evidence |
|---:|---|---|---:|---:|---:|---|
| 1 | QM5_20075 | Q02 | 3416 | 3h | 20496 | Recover the source clock; same-number UTC hours would shift raw broker window by 2h winter / 3h summer. |
| 2 | QM5_20070 | Q02 | 2138 | 3h | 12828 | Recover the source clock; same-number UTC hours would shift raw broker window by 2h winter / 3h summer. |
| 3 | QM5_10692 | Q10 | 427 | 3h | 12810 | Recover the source clock; same-number UTC hours would shift raw broker window by 2h winter / 3h summer. |
| 4 | QM5_13213 | Q11 | 888 | 1h | 9768 | Fixed +3 agrees with some lineage specs; test a broker-following source only after confirming it (winter 1h difference). |
| 5 | QM5_21501 | Q11 | 888 | 1h | 9768 | Fixed +3 agrees with some lineage specs; test a broker-following source only after confirming it (winter 1h difference). |
| 6 | QM5_38002 | Q02 | 1388 | 3h | 8328 | Recover the source clock; same-number UTC hours would shift raw broker window by 2h winter / 3h summer. |
| 7 | QM5_9403 | Q09 | 223 | 3h | 6021 | Recover the source clock; same-number UTC hours would shift raw broker window by 2h winter / 3h summer. |
| 8 | QM5_10376 | Q02 | 920 | 3h | 5520 | Recover the source clock; same-number UTC hours would shift raw broker window by 2h winter / 3h summer. |
| 9 | QM5_20007 | Q02 | 2746 | 1h | 5492 | A constant broker-to-German-time offset may miss the March/October US/EU DST gap weeks by 1h. |
| 10 | QM5_11481 | Q04 | 456 | 3h | 5472 | Recover the source clock; same-number UTC hours would shift raw broker window by 2h winter / 3h summer. |

Every table row joins by ea_id to exact code/card/report citations in the inventory. These are candidates for source-clock confirmation first. A governed remeasurement is warranted for the confirmed Balke lineage clock alternative and the European session candidates if the intended local clock is confirmed; no measurement was started.

## Manually checked control-flow findings

- QM5_41398 source:303-339 builds two stops without an outside-range price check. Lines 622-637 send each permitted leg independently, ignore both return values, then mark the day complete from permission intent. Thus both failures can still consume the day; one accepted leg can remain. This contradicts the outcome-based wording in the shared straddle header. The shared helper itself only returns permission decisions (`QM_PatternPermissionStraddle.mqh`:75-103).
- QM5_33005 source:178-179 explicitly skips both entries if either trigger is already crossed or within one point. Its raw-clock defaults at :38-40 assume a constant one-hour relation between broker and German local time; that assumption needs separate treatment in US/EU DST transition weeks.
- QM5_13036 is a useful negative control: card :70-74 and :90 explicitly identify broker GMT+2/+3 on US DST, and source :54-57 reads raw broker time. GMT wording alone is not a mismatch.
- QM5_13213 has no local docs/strategy_card.md; SPEC.md:14-21 explicitly describes fixed +3 reprojection. This is a missing-card evidence gap, not proof that the code violates the spec.

## Acceptance still open

93 pending-stop candidates need function-by-function review, including included strategy modules, to distinguish skip, market entry, one-leg placement and a truly undefined strategy rule. The CSV deliberately does not equate absence of a simple regex match with absence of a guard. Helper clock classifications also need call-site tracing before any correction. Actual affected trades, precise shifts where the source clock is absent, and an economic ranking cannot be inferred from static code or borrowed from another EA.

Reports are under canonical docs/ops/evidence per the scheduled-task instruction, rather than the payload suggested docs/research path. This artifact is for REVIEW; it does not close the remaining acceptance items.
