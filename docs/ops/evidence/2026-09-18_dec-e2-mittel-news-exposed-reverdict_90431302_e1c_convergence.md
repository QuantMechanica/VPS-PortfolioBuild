# DEC E2-Mittel — task 90431302, E1-C convergence check + Q08 follow-on mint (2026-09-18)

Task: "DEC E2-Mittel: re-adjudicate news-exposed verdicts append-only after the calendar
repair (63 exposed phase-pairs per `72e5884d`; 10706/GBPUSD included)". Routed to claude;
this is the third recorded execution cycle after 2026-09-12 (initial) and the 2026-09-12
reverification addendum. Read first:
`docs/ops/evidence/2026-09-12_dec-e2-mittel-news-exposed-reverdict_90431302_execution.md`.

## New fact this cycle: a broader program has absorbed this task's mandate

Between the last check and today, a separate initiative — **E1-C** (Kimi, interim OWNER
delegation, task `e1c-optionb`/`e1c-followup`, 2026-09-16, `agents/board-advisor`) — ran a
full live census of every `NEWS_CALENDAR_TAINTED` hold (99 rows; this task's own `blast_radius.csv`
is a July-vintage 63-row subset of the same hold class, computed against the legacy single-stage
`Q10` contract). E1-C is strictly broader and more current than this task's own scope:

- `docs/ops/evidence/2026-09-16_e1c_optionb/` — delta-revalidated 91/99 rows `UNCHANGED_EQUIVALENT`
  (old vs. new calendar bytes identical over every held row's evidence window) and released them
  via a governed per-row marker (`release_e1c_item`, hash-bound, re-verified every sweep — not a
  bare hold-table UPDATE, which the code proves gets re-applied). 8 rows stayed held
  (`EVIDENCE_INCOMPLETE`, route to `FULL_Q09_REMEASUREMENT_REQUIRED`).
- `docs/ops/evidence/2026-09-16_e1c_optiona_enqueue/` — for the 8 `EVIDENCE_INCOMPLETE` rows,
  proved (code-verified) that a direct `Q10_NEWS --append-only-rerun-of` is refused for all of
  them (same `No done Q09 PASS` / `q08_evidence_missing_or_unreadable` class this task's
  2026-09-12 cycle hit), and that the correct entry point is a fresh **Q08-lineage** append-only
  rerun so the pump auto-spawns the `Q09_NEWS`/`Q10_NEWS` successors. Enqueued 3 of 8; documented
  exact follow-ons for the other 5.

Live verification today (`work_item_holds`, `hold_code='NEWS_CALENDAR_TAINTED' AND active=1`):
exactly **8** active rows, matching the E1-C `EVIDENCE_INCOMPLETE` set byte-for-byte
(`49a059da`,`aa80274f`,`1cff016c`,`57d8bacd`,`2604a1f0`,`84c6e9e9`,`7bbeef66`,`9639a773`).
`blast_radius.csv` unchanged (`sha256=85ce60dc0ef6fd3b3a3cd4668af709b3d7e7f46c27971ee475f8314edf6c65cd`).

## Overlap with this task's own 12 Q10/Q14-relevant pairs

Of this task's 12 `blast_radius.csv` `Q10`-phase `EXPOSED` pairs (see the 2026-09-12 evidence
for the full list), **3 are among the 8 still-held rows**:

| ea/symbol | held work_item_id (Q10_NEWS) | E1-C Option A disposition |
|---|---|---|
| QM5_1567/EURUSD.DWX H4 | `2604a1f0` | Q07 append-only rerun `ceebbe72` enqueued 2026-09-16; **done PASS 2026-09-17T06:22:37Z** |
| QM5_10939/GBPUSD.DWX H4 | `9639a773` | refused (`append_only_rerun_already_exists`, prior 2026-08-24 rerun `8234812d` ended `INFRA_FAIL`) — needs governed disposition of the failed rerun first |
| QM5_13128/NDX.DWX H1 | `aa80274f` | not re-enqueued: existing rerun `d2d76958` (CEO 2026-09-02, done `FAIL_SOFT`, itself an append-only replacement) is expected to auto-respawn its `Q10_NEWS` child once selectable; no action needed unless respawn is observed to fail |

The other 9 of the 12 pairs are **not** in the held set — they were part of the 91 already
released by E1-C Option B (calendar-equivalence release, no remeasurement needed) or were never
held under the current live gate (some blast_radius.csv rows are old sealed Q10 evidence with no
corresponding live-held successor).

## Action taken this cycle (GRÜN, append-only, reversible)

QM5_1567's Q07 rerun (`ceebbe72`) had landed **done PASS** since the E1-C report was written, but
its documented Q08 follow-on (explicitly named in `2026-09-16_e1c_optiona_enqueue/ENQUEUE_REPORT.md`:
*"Follow-on for QM5_1567 after the Q07 rerun completes done PASS: enqueue the Q08 rerun"*) had not
been minted. Verified current ex5 unchanged (`aee0eb60798ef7ada09e49df6e9a339dd8199f810de56dab8a25957cb26fba31`,
matches the E1-C report's citation) and ran the exact documented command:

```
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_1567 --phase Q08 \
  --from-work-item-id ceebbe72-4556-4fdb-8f4e-bb623ae22b41 \
  --append-only-rerun-of e8c1e63a-e06c-4988-9ae7-54771bc1fe8c \
  --expected-current-ex5-sha256 aee0eb60798ef7ada09e49df6e9a339dd8199f810de56dab8a25957cb26fba31 \
  --rerun-reason "TASK-90431302: OWNER-E1C-OPTIONB-20260916 follow-on, ..."
```

Result: new pending row `0c063694-2f89-4304-80c5-79a9d190f06a` (Q08, `rerun_of_work_item_id=e8c1e63a`),
0 skipped, 0 superseded. The original `e8c1e63a` row and the held `2604a1f0` `NEWS_CALENDAR_TAINTED`
row are untouched (append-only; verified via a follow-up `work_items`/`work_item_holds` read after
the enqueue — both rows' `updated_at`/hold status unchanged from before this command). Once the
pump dispatches `0c063694` to a `PASS`, the documented pump auto-spawn (`_spawn_q09_replacements_for_regenerated_q08`)
mints a fresh `Q10_NEWS` child under the tainted pin, which then measures on the clean calendar
per the E1-C marker semantics — that is the actual re-adjudication this task originally asked for.

Not attempted this cycle: QM5_10939 and QM5_13128 (own-scope follow-ons need a governed disposition
of prior failed reruns / observation of an existing respawn — both are Codex/infra-repair-shaped
work, not a plain re-enqueue, and were already correctly deferred by the E1-C report itself).
QM5_10815 (`74718ef2`) and QM5_13301 (`f3132f22`) — the other two E1-C Option A enqueues outside
this task's 12-pair list — remain `pending`, blocked by an unrelated, already-tracked
`RAM_RESERVATION_44GB_NOT_WINNABLE_20260914` hold (2026-09-14 Index-RAM-Tabelle initiative; not in
this task's `allowed_actions`, not touched).

## Disposition

This task's original framing (63-row `blast_radius.csv`, hand-picked "12 Q10/Q14-relevant" +
"51 remaining") is now superseded in mechanism and in scope by the E1-C 99-row live census, which
correctly generalized the same problem and has already released 91/99 holds plus proven and begun
executing the Q08-lineage remeasurement path for the rest. This task's remaining unique value is
narrow: track the 3 overlapping pairs (QM5_1567, QM5_10939, QM5_13128) through to a genuine
`Q10_NEWS` verdict and write the before/after table the acceptance criterion asks for once they
land. One of those three (QM5_1567) now has its next concrete step minted (`0c063694`, this
cycle); the other two have documented but not-yet-executed follow-ons owned by adjacent infra/
disposition work, not by this task directly.

No holds released this cycle (none were this task's own live-releasable target — the 3 overlap
rows all require remeasurement, not a calendar release). No calendar, gate criterion, or verdict
was changed. `blast_radius.csv` and the tainted-calendar config are byte-identical to the last
check.
