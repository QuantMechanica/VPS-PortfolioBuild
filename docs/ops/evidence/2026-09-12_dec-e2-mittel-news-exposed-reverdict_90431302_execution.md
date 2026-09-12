# DEC E2-Mittel execution — task 90431302 (2026-09-12, real UTC)

Task: "DEC E2-Mittel: re-adjudicate news-exposed verdicts append-only after the calendar
repair (63 exposed phase-pairs per `72e5884d`; 10706/GBPUSD included)". Routed to claude
2026-09-12T08:33:10Z under OWNER blanket authorization (2026-09-05 ~03:55Z: "Alles, bis
auf den Kauf, freigegeben, das uns dem Ziel näher bringt!").

## Done this cycle (GRÜN, reversible, backed up)

Ran `tools/strategy_farm/news_calendar_scoped_activation.py` fresh (dry-run, produces the
binding marker only, changes nothing) against the 28 currently-pending Q10_NEWS rows:
`binding_sha256=069b467f8db31ebb398ac173783ada3a2dd3de5af21f9943475631c72ed259f5`
(byte-identical to the binding used for the 2026-09-07/08 B-prime row-by-row releases —
no candidate drift). Result: 11 ADMISSIBLE / 17 EXCLUDED (15 `NON_USD_EXPOSURE`, 6
`SEALED_Q10_WINDOW_UNAVAILABLE`).

Cross-referenced the 11 ADMISSIBLE work-item IDs against their *currently active* holds
(not just the calendar-taint hold in isolation, since several rows carry an unrelated
second hold that the calendar release would not clear):

| work_item_id | ea/symbol | active hold today |
|---|---|---|
| `0f7f63e4` | QM5_1567/XAGUSD.DWX H4 | `NEWS_CALENDAR_TAINTED` -> released this cycle |
| `2641d5cf` | QM5_10569/XAUUSD.DWX H4 | `NEWS_CALENDAR_TAINTED` -> released this cycle |
| `f15ac955` | QM5_10145/SP500.DWX D1 | none (already unblocked) |
| 7 rows (`745671a4`,`c18cf1fa`,`ca96d7bf`,`136b0e0f`,`450fb9f6`,`abea4df5`,`6d528b09`,`b6e02932`) | mixed | `NEWS_RUNNER_SPAWN_SILENT_ABORT` (unrelated infra defect, calendar release would not unblock them) |

Released exactly the 2 rows where `NEWS_CALENDAR_TAINTED` was the actual live blocker,
via the governed row-by-row path (`farmctl.py release-hold`, dry-run then apply, same
convention as the 2026-09-07/08 batch):

- `0f7f63e4-9244-4c60-8610-ea068c5fc64e` (QM5_1567/XAGUSD.DWX H4), released
  2026-09-12T08:41:41Z, `assessment_sha256=8e511d64943713ffabcbc2fc5292a40ccf0b52ac12ef317f8e755b94ed83402c`,
  backup `D:\QM\strategy_farm\state\backups\farm_state_before_news_calendar_taint_20260912T074317Z_d11be4eb.sqlite`.
- `2641d5cf-6e1c-43d1-92b2-05c9d6f54d82` (QM5_10569/XAUUSD.DWX H4), released
  2026-09-12T08:41:42Z, `assessment_sha256=80fef4da493c8110540c5f9ccd7a0985529ffcd4e0a4d409c68bfcb7c74d4c19`,
  same backup file. Ledger seq 3234/3235, `factory_mutation_lock_release=released` both
  times, `work_items_untouched=true` (no verdict/evidence row touched — hold table only).

No other row's holds were touched. No calendar, gate criterion, or verdict changed.

## Blocked this cycle: the "mint 63 append-only reruns" step is gated one layer deeper than expected

Extracted the 12 Q10/Q14-relevant exposed pairs from
`docs/ops/evidence/2026-09-05_news_defect_blast_radius/blast_radius.csv` (`classification
== EXPOSED and phase == "Q10"`, 11 PASS + 1 FAIL — this is what "12 Q10/Q14-relevant"
means; the FAIL row's Q14 downstream conclusion also depends on it). Tried
`farmctl.py enqueue-backtest --phase Q10_NEWS --append-only-rerun-of <id> --ea <ea>
--from-work-item-id <predecessor>` for the first row (QM5_10440/NDX.DWX H1,
`bdfdd179-3801-492c-b3c0-2a5a163d16a4`, a legacy `Q10`-phase row,
`gate_contract_version=legacy`).

The tool refused: `"No done Q09 PASS work_items found for QM5_10440 matching predecessor
bdfdd179..."`. Checked all 12 pairs' current `Q09_NEWS` predecessor state directly —
**none has a PASS-verdict `Q09_NEWS` row**:

| ea/symbol | Q09_NEWS predecessor status |
|---|---|
| QM5_10440/NDX H1 | pending |
| QM5_10692/NDX H1 | done, verdict=`PENDING_RUNNER` |
| QM5_10706/GBPUSD H1 | done, verdict=`REVIEW_REQUIRED` |
| QM5_10919/XTIUSD H4 | done, verdict=`REVIEW_REQUIRED` |
| QM5_10939/GBPUSD H4 | pending |
| QM5_11165/EURUSD H1 | done, verdict=`REVIEW_REQUIRED` |
| QM5_12969/USDJPY M30 | done, verdict=`REVIEW_REQUIRED` |
| QM5_12989/XAUUSD H4 | pending |
| QM5_13013/NDX M15 | pending |
| QM5_13128/NDX H1 | pending |
| QM5_13213/USDJPY H1 | pending |
| QM5_1567/EURUSD H4 | done, verdict=`REVIEW_REQUIRED` |

**Root cause:** the `blast_radius.csv` rows were computed in July against the legacy
single-stage `Q10` gate contract. The live gate has since moved to a two-stage
`Q09_NEWS` -> `Q10_NEWS` contract, and `enqueue-backtest --phase Q10_NEWS` fail-closes
without a `done`/`PASS` `Q09_NEWS` predecessor for the exact pair. `REVIEW_REQUIRED` is
not a terminal PASS — it is the same stuck class that the just-resolved `bb814520`/
`dfc60103`/`3032534e` incident (2026-09-09 to 2026-09-12, see
`docs/ops/OPEN_ITEMS_STATUS.md` "2026-09-12T11:45Z" entry) spent three days unblocking
for `QM5_11167`/`QM5_11196` via a Codex-built new-identity rebuild path (`fda6370f`).
None of these 12 pairs is that specific rebuild target, so re-adjudicating them append-only
is **not currently possible without first landing a real `Q09_NEWS` PASS** for each pair —
that is a Q09_NEWS-pipeline-throughput problem, not something this task's own
`allowed_actions` (calendar hold release + rerun minting) can shortcut. Minting a
Q10_NEWS append-only rerun against a `REVIEW_REQUIRED` or `pending` predecessor would
either be refused (as observed) or, if forced some other way, would not be a valid
adjudication — not attempted.

## Recommendation / next step

Do not force further reruns this cycle. The remaining path is: either (a) wait for the
ordinary Q09_NEWS pipeline to carry these 12 pairs to a genuine PASS (some may benefit
from whatever unblocks the broader `REVIEW_REQUIRED` backlog, which is already an active
initiative per the just-closed incident), or (b) if OWNER wants these 12 specifically
prioritized, that is a queue-order decision (GRÜN under the standing authorization) worth
raising explicitly rather than assumed. The remaining 51 exposed `Q09`-phase rows (39 PASS
+ 9 FAIL + 2 Q14 `OPT_ELIGIBLE`) were not attempted this cycle — they were always meant to
be paced after the 12 Q10/Q14-relevant ones per the task's own ordering instruction, and
that ordering is now confirmed to depend on the same upstream gate, not just queue pacing.

Task `90431302` stays `IN_PROGRESS`: 2 of ~3 currently-releasable calendar holds cleared,
but the top-level acceptance ("rerun list with ids and order; holds released with ledger;
evidence doc with before/after verdict table") is not yet met — no reruns could be minted
yet, and 15 of the 17 excluded holds remain correctly held (14 `NON_USD_EXPOSURE`, being
outside the OWNER-approved B-prime USD-only boundary; the 6 `SEALED_Q10_WINDOW_UNAVAILABLE`
plus the 7 `NEWS_RUNNER_SPAWN_SILENT_ABORT`-blocked rows need their own separate fixes,
not a calendar action). No `update-task` call made.
