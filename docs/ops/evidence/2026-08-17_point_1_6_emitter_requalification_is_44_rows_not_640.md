# Point 1.6 — the emitter requalification set is 44 rows, not 640

The brief asks for the cut to be fixed **at the emitter commit, not estimated from the build date**,
and for the requalification set to be quantified. Done — and the proxy overcounted by 14.5×.

---

## The commit is confirmed

`QM_FrameworkQ08EmitFromHistory` first appears in exactly one commit:

```
234860d6e  fix(framework): q08 stream captures SL/TP closes (magic-0 deal bug)
           2026-07-10
```

Root cause in its own words: per-trade-stream ownership was decided on the **closing** deal's magic,
but MT5 gives SL/TP-triggered closing deals `DEAL_MAGIC = 0`, so the ownership filter rejected them.
The candidate in the brief is the right one.

## Fixing the cut at the mechanism: two attempts, one honest failure

**Attempt 1 — binary marker. Failed its controls, and I am reporting that rather than the result.**

The emitter carries distinctive literals (`.full_lifecycle.tmp`,
`ENTRY_COMMISSION_ALLOCATION_INCOMPLETE`, `DEAL_ENTRY_KIND_UNSUPPORTED`). If `.ex5` retained them,
presence/absence would date each binary by content. It does not: the marker was absent even in
**QM5_1118 and QM5_10295**, which are built 2026-07-14 and demonstrably wrote complete streams today
(491/1310/389 and 41/44/46 trades, matching `report_trades` exactly). EX5 is not zlib-packed either
— header `EX5\x02`, zero inflatable streams — so the literals are not recoverable cheaply.

**The census was suppressed by its own positive control.** Without that control I would have reported
"3,274 of 3,274 binaries lack the emitter", which is false and would have been catastrophic. This is
the no-silent-null-result rule paying for itself.

**Attempt 2 — observed emission behaviour. Controls pass, and it contains no date at all.**

Per Q04 fold:

| observation | conclusion |
|---|---|
| `report_trades > 0` and stream `trades == report_trades` | the binary **emitted** |
| `report_trades > 0` and stream `trades == 0` | the binary **failed to emit** |

Both directions decidable, so this is a mechanism test, not a proxy. Controls, all five passing —
including the demanding one:

| EA | classified | expected | folds |
|---|---|---|---|
| QM5_1118 | EMITS | EMITS | 3 emit / 0 broken |
| QM5_10295 | EMITS | EMITS | 3 / 0 |
| QM5_1119 | BROKEN | BROKEN | 0 / 3 |
| QM5_1100 | BROKEN | BROKEN | 0 / 3 |
| **QM5_1588** | **MIXED** | **MIXED** | **1 / 2** |

QM5_1588 is the one that matters: the *same binary* emitted on F1 and not on F2/F3. A per-EA
date rule cannot express that; the behavioural rule can, and MIXED is exactly what the magic-0
mechanism predicts, since folds differ in how many exits are SL/TP.

---

## The result

725 EAs hold queued work, 1,249 queued rows:

| class | EAs | queued rows |
|---|---:|---:|
| EMITS | 112 | 171 |
| MIXED | 8 | 9 |
| **BROKEN** | **8** | **35** |
| NO_EVIDENCE | 597 | 1,034 |

**Requalification set on proven emission failure: 16 EAs / 44 rows** (BROKEN + MIXED).

| EA | class | queued | emit folds | broken folds |
|---|---|---:|---:|---:|
| QM5_1119 | BROKEN | 20 | 0 | 3 |
| QM5_1100 | BROKEN | 8 | 0 | 3 |
| QM5_1208 | MIXED | 2 | 10 | 5 |
| QM5_1102 | BROKEN | 2 | 0 | 3 |
| QM5_12479 | BROKEN | 1 | 0 | 6 |
| QM5_11056 | BROKEN | 1 | 0 | 6 |
| …10 more at 1 row each | | | | |

### Against the number I published this morning

**640 pending rows on June binaries → 44 rows on binaries with proven emission failure.** The
build-date proxy overcounted by **14.5×**, for the same reason it undercounted by 11× when I keyed
on binary size this morning: **a proxy was standing in for a mechanism that was measurable all
along.** That is now twice in one day on the same finding, from opposite directions.

The gradient itself was never wrong — June binaries do fail more often (25.5 % vs 10.7 %). It is
just not a classifier: most June binaries emit perfectly well.

---

## The honest limitation, which is larger than the finding

**1,034 of 1,249 queued rows (83 %) are `NO_EVIDENCE`** — 597 EAs that have never produced a Q04
fold with trades, so nothing can be concluded about them in either direction. This is *not* "they
are fine". It is "never measured", and the distinction is the whole point of the absence rule.

So the practical position:

- **44 rows** are queued on binaries that provably failed to emit → requalify, and rebuild before
  re-running, or they will fail again exactly as QM5_1119's XAGUSD row did today.
- **171 rows** are queued on binaries that provably emit → leave alone. A rebuild here would be a
  hold on healthy work, which the brief counts as the same damage as a requeue on broken work.
- **1,034 rows** are undecidable today. Their build date is a **risk hint, not a verdict**; the
  first Q04 fold each produces will classify it for free. No action, but no clean bill either.

## What this changes for the catch-up list

The 1.6 contribution to Phase 2.1 is **44 rows, not 640**. The catch-up therefore stays roughly the
size it was (116 runs / 10.8 h) rather than growing sixfold, and the emitter issue is a small,
named, already-ticketed repair (`dc283f34`) rather than a queue-wide event.

## Deliberately not done

No rebuilds triggered, no rows requeued or held. The MIXED EAs in particular need a decision I did
not take: QM5_1208 emits on 10 folds and fails on 5, so "rebuild the EA" is the wrong unit — the
question is whether its already-earned verdicts rest on emitting folds or broken ones, and that is
per-verdict work belonging to the requalification, not to a census.

## Evidence

- `git log -S QM_FrameworkQ08EmitFromHistory -- framework/include/QM/QM_Common.mqh` → `234860d6e`
- failed binary probe with its controls (QM5_1118/10295 expected present, found absent) — recorded
  because the failure is the reason the census is trustworthy
- `artifacts/emitter_behaviour_census_20260817.json` — full classification and requalification list
- supersedes the 640-row figure in
  `2026-08-17_a_stale_ex5_voids_healthy_backtests_and_20_more_are_queued.md`
