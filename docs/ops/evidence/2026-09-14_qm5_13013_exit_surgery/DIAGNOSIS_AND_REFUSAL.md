# QM5_13013/NDX.DWX exit-surgery diagnosis — written refusal

Ticket `70a31d19-343d-456d-a4f1-1fce14fac7ea`. Read-only against T_Live and the live
inventory throughout; `framework/EAs/QM5_13013_*` was read but never modified or
recompiled.

## Diagnosis

**Source data**: raw Q08 trade stream
`D:/QM/reports/portfolio/dxz_v2_20260913/streams_v2b/QM/q08_trades/13013_NDX_DWX.jsonl`
(70 trades) cross-referenced chronologically (index-aligned, counts match — the same
method `EXIT_SURGERY_SCAN_V2_2026-09-13.md` itself uses) against the MT5 Deals table in
`D:\QM\reports\pipeline\QM5_13013\Q08\_baseline\QM5_13013\20260902_150740\raw\run_01\report.htm`
(resolved via `bundle_manifest.json` → `q08_work_item_id` → `farm_state.sqlite` →
`aggregate.json`; report sha256 verified against the manifest).

**Bucket numbers confirmed directly from `docs/research/exit_surgery_v2/hold_buckets.csv`**
(not just restated from the ticket):

| bucket | n | WR | net |
|---|---:|---:|---:|
| `<1h` | 26 | 0.0% | -7,135.53 |
| `1-4h` | 15 | 26.7% | -1,569.86 |
| `4-12h` | 21 | 95.2% | +10,531.14 |
| `12-48h` | 6 | 50.0% | +1,245.95 |
| `>48h` | 2 | 100.0% | +1,941.42 |

Both ticket-cited headline figures (`<1h`: 26/0%/-7,136; `4-12h`: 21/95%/+10,531) match
exactly. **Note on provenance**: the scan's own machine-scored HIGH-verdict gradient
(50pp) compares `<1h` against `12-48h` (the last bucket with n≥5 by the scan's own rule),
not against `4-12h` — the "0%→95%" narrative is real and directly in the CSV, but it
spans the full bucket table, not the specific two buckets the scan's verdict math used.
Stated here so the number isn't later misattributed to the wrong comparison.

**Per-trade CSV**: `early_exit_per_trade.csv` (this directory), all 26 `<1h` trades,
columns `entry_utc, exit_utc, hold_h, net, report_comment, exit_class, session_close_exit`.

**The load-bearing finding — what actually fires**: `TIME_MGMT` in the scan classifier
means the exit comment contains `qm_tm` or `time_stop`. Read directly,
`framework/include/QM/QM_TradeManagement.mqh:314`:
```
request.comment = partial ? "qm_tm_partial_close" : "qm_tm_close";
```
This literal is stamped on **every** close that routes through `QM_TM_ClosePosition`,
**regardless of which `QM_ExitReason` was passed in** — it is the generic
trade-management close-path label, not a distinct time-stop rule's signature. The scan
document's own methodology note already flags this risk ("covers both fixed time stops
and signal/MA crossover closes that the framework labels uniformly") — for 13013 that
caveat is exactly what is happening.

`framework/EAs/QM5_13013_grimes-trendday-v2/QM5_13013_grimes-trendday-v2.mq5:512-532`,
`Strategy_ExitSignal()`, read and verified directly — **exactly two branches, both routed
through `QM_TM_ClosePosition`**:

```mql5
// Trade Close. Card exit: close at session close or when a closed M15 bar
// returns inside the first-hour opening range after entry.
bool Strategy_ExitSignal()
  {
   if(MinuteOfDay(TimeCurrent()) >= SessionCloseMinute())
     { ... }                    // session close (22:45 broker)

   if(g_close_inside_range)
     { ... }                    // failed-breakout invalidation

   return false;
  }
```

There is **no** separate fixed-bars/fixed-hours time-stop or "no-progress" counter
anywhere in this EA — no `PositionGetInteger(POSITION_TIME)` check exists in
`Strategy_ExitSignal()`. The only time-related input, `strategy_min_session_hold_h`, gates
**placing a new pending order** (a prior, already-shipped exit-surgery fix for a *different*
problem — late-filled pendings force-closed at session end, from the parent EA
`QM5_10943`'s own history), not position duration.

**Split of the 26, computed directly from the aligned report data** (full table in the
CSV):
- **24/26 (92.31%)** — exact match to `sleeve_summary.csv`'s `time_mgmt_share_early=0.9231`
  — exit comment `qm_tm_close`, **zero of them** near session close (all entries
  17:45–18:30, all exits 15–75 minutes later, well before 22:45). By elimination against
  `Strategy_ExitSignal()`'s only two branches, **all 24 are `g_close_inside_range`**: the
  strategy's own failed-breakout invalidation — price closed back inside the opening
  range after a breakout entry.
- **2/26 (7.69%)** — literal broker stop-loss hits (`sl 6729.8`, `sl 19718.5`), and
  notably larger losses (-998.79, -1,045.66) than any of the 24 signal-cut losses (-49 to
  -404).

**Zero of the 26 are session-close exits.** The one genuinely separable time-based lever
this sleeve ever had (late-placed-pending force-close at session end) was already
identified and fixed in 13013 itself, relative to its parent QM5_10943 — and the data
confirms it worked (0/26 current early exits are session-close-driven).

## Refusal

Per the ticket's own escape hatch ("a written refusal if the exit rule is structurally
the strategy exit"): **refused.**

`g_close_inside_range` is not a bolt-on trade-management timer — it is computed entirely
inside `Strategy_EntrySignal()`'s opening-range state machine and is the strategy's own
definition of "this breakout failed." It is the mirror image of the entry signal, not a
separable risk-management layer that can be lengthened, disabled, or delayed without
redefining what a breakout entry *is* for this EA.

This is the exact tautology class the house already rejected in
`docs/research/EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md`: a hold-time WR gradient
(0%→95%) is not by itself evidence of a removable lever when the early-bucket exits are a
fast invalidation check (signal or SL) rather than a mechanical timer — losers separate
from winners immediately *by construction* of the strategy, and lengthening or removing
that check does not make the early trades *become* the late trades; it exposes them to a
different distribution of outcomes entirely (most likely: riding failed breakouts toward
full stop-loss size, which the numbers argue against — the 24 signal-cut losses are
already smaller than the 2 real SL losses on this same sleeve).

**No Q14 lever card is filed** — filing one over a hypothesis this diagnosis already
contradicts would misrepresent the evidence. **No variant EA is built.**

One narrower, honestly-different candidate exists and is explicitly out of scope for this
ticket rather than silently substituted: a confirmation-bars parameter on
`g_close_inside_range` (require N consecutive M15 closes back inside the range instead of
1). That is signal engineering — redefining what "failed breakout" means — not exit
surgery, and would need its own walk-forward pre-registration against the Q08 baseline
(PF ≈1.36–1.48), separately from this ticket.

## Incidental finding, not part of this ticket's scope

`bundle_manifest.json` records a prior Q14 work item on this sleeve,
`q14_work_item_id=28dc651f-046b-542f-b766-cc28ac3d79b6`, verdict `KEEP_INCUMBENT`,
`reason_code=NO_CHALLENGER_BOTH_UPSTREAM_STAGES_NO_CHANGE`. This is from the unrelated
DL-089 Pattern Filter WF Census v3 programme (entry-pattern-filter search), not a prior
rejection of an exit lever — flagged here only so it isn't confused with this ticket's
own (different) conclusion.

## RESULT line for `docs/ops/OPEN_ITEMS_STATUS.md` (draft)

> **QM5_13013/NDX exit-surgery (70a31d19)**: REFUSED, evidence-based. The `<1h` bucket's
> 92.31% "TIME_MGMT" exits are the generic `qm_tm_close` trade-management comment, not a
> time-stop signature (verified: `QM_TradeManagement.mqh:314` stamps it on every close
> regardless of reason). Per-trade reconstruction (24/26 exits) shows the actual firing
> rule is `g_close_inside_range` — the strategy's own failed-breakout invalidation, woven
> into `Strategy_EntrySignal()`'s opening-range state, not a separable lever; 0/26 are
> session-close exits (the one real prior time-based lever, already shipped in 13013 vs
> parent QM5_10943, verified working). Same tautology class the house rejected
> 2026-07-06 (Tier B). No lever card filed, no variant built. Evidence:
> `docs/ops/evidence/2026-09-14_qm5_13013_exit_surgery/`.
