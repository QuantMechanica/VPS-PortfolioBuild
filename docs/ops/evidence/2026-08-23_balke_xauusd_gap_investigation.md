# Balke range breakout: XAUUSD gap investigation (QM-TODO-20260823-504)

- Task: agent_tasks `051eb0bf-1978-42ac-9ae3-bf207529ea8c` (ops_issue)
- OWNER observation (2026-08-23): "there are settings for Balke on XAUUSD that work, we
  either never tested them or used the wrong parameters (Q02 already FAIL); Balke is
  successful on other symbols."

## Step 1 — was the QM5_13213 XAUUSD RETIRE row a genuine no-signal or an artifact?

Queried `farm_state.sqlite work_items` for `ea_id='QM5_13213' AND symbol='XAUUSD.DWX'`:
exactly one row (`2cdf1846-1513-4863-b797-5448fb7a283a`), `phase=Q02`, `status=done`,
`verdict=RETIRE`, `updated_at=2026-07-29T12:18:03Z`. `payload_json.invalidated_reason`:
"XAU excluded by OWNER-approved USDJPY-only admission: walkforward OOS PF 1.03 gross =
documented negative (docs/research/BALKE_RANGE_BREAKOUT_WALKFORWARD_2026-07-14.md);
setfile removed from canonical (7f9ae6e3d)."

That walkforward doc (`docs/research/BALKE_RANGE_BREAKOUT_WALKFORWARD_2026-07-14.md`,
Claude/Opus, 2026-07-14) directly answers the OWNER's 2026-07-13 question ("Balke is
profitable for him on XAUUSD and USDJPY — where does it fail for us? Was the time window
wrong?"). Method: video-derived exact Balke parameters (03:00-06:00 broker time,
GMT+2/+3 DST-aware, buy-stop/sell-stop, 18:00 close) — the same window fix that made
USDJPY work. Results (gross, RISK_FIXED, DEV 2017-2021 / OOS 2021-2025):

| Symbol | OOS Trades | OOS Net | OOS PF | OOS MaxDD |
|---|---|---|---|---|
| USDJPY | 795 | +$68,235 | 1.20 | -$19,853 |
| XAU | 970 | +$13,342 | **1.03** | **-$40,645** |

XAU OOS PF 1.03 gross is ≈ breakeven before any commission/swap; after venue-truth costs
USDJPY stays PF ~1.17-1.19, XAU was not even carried past gross (further degradation
implied). The doc's own verdict: "XAU: documented negative; do not pursue (consistent
with Balke's own experience ['gold has drawdown phases'])."

**Finding: this is NOT an artifact.** It is a genuine, evidenced no-signal, produced using
Balke's own author-confirmed parameters (the exact "settings that work" OWNER is recalling
were already tried) — reproducing Balke's own stated caveat about gold. Confirmed by the
sets directory: `framework/EAs/QM5_13213_balke-gmt3-range-breakout/sets/` contains only
`USDJPY.DWX` set files; no XAUUSD setfile exists (consistent with "setfile removed from
canonical," card scoped to USDJPY.DWX only). There is no wrong-window or wrong-parameter
artifact to correct.

## Step 2 — append-only rerun?

**Not warranted.** Rerunning 13213/XAUUSD would reuse the same correct, author-derived
parameters against the same history and reproduce the same breakeven-before-costs result.
Per the task's own hard constraint ("no parameter tuning outside Q14-Q16 optimization
branch — selection rule changes are ROT"), and since the RETIRE verdict already correctly
reflects the walkforward evidence, no rerun was dispatched. The RETIRE row is left as-is
(append-only discipline honored by not touching it at all).

## Step 3 — dispatch QM5_13036 (GDAXI survivor) to XAUUSD.DWX?

QM5_13036 (`balke-go-long-regime`) is a **different variant** from 13213
(`balke-gmt3-range-breakout`) — the WF verdict above only evaluated 13213's exact
time-window logic, not 13036's regime-filter logic, so 13036-on-XAU is genuinely
untested territory, not a re-litigation of a closed decision.

However, checked before dispatching:
- `framework/registry/magic_numbers.csv`: 13036 has exactly 2 active slots —
  `NDX.DWX` (slot 0, 130360000) and `GDAXI.DWX` (slot 1, 130360001). No XAUUSD slot.
- `artifacts/cards_approved/QM5_13036_balke-go-long-regime.md`:
  `target_symbols: [NDX.DWX, GDAXI.DWX]` — XAUUSD is not in the card's declared universe.
- `framework/EAs/QM5_13036_balke-go-long-regime/sets/`: no XAUUSD setfile exists.

Porting 13036 to XAUUSD would require registering a new magic slot, generating a new
setfile, and amending the card's `target_symbols` — i.e. a governed universe-expansion
decision for this EA, not a routine backtest dispatch of an existing pair. The framework's
own `QM_SymbolGuard` convention treats "no implicit universe expansion at runtime" as a
hard boundary; the same should hold for what this ops task unilaterally enqueues.
**Not dispatched this cycle** — flagged below as a recommendation instead of actioned,
since it exceeds routine ops_issue scope and the hard constraint against selection-rule
changes argues for a deliberate decision, not an ad-hoc symbol add mid-cycle.

## Step 4 — is XAUUSD a genuine no-signal or an untested hole?

Both, depending on which Balke variant:
- **QM5_13213 (time-range-breakout, Balke's exact window):** genuine, evidenced no-signal
  on XAUUSD. Correctly RETIRE'd. Not an untested hole, not a parameter artifact.
- **QM5_13036 (go-long-regime variant):** genuinely untested on XAUUSD (zero rows) — a
  real hole, but one whose closure requires a card/magic-registry scope decision, not a
  same-cycle dispatch.

## Recommendation to OWNER

1. No further action needed on 13213/XAUUSD — the exclusion is sound and already the
   answer to the original "was the window wrong" question.
2. If OWNER wants QM5_13036's regime-filter logic tested on XAUUSD, that should go through
   a normal card-scope amendment (add XAUUSD.DWX to `target_symbols`, register a magic
   slot, generate a setfile) rather than an ad-hoc ops dispatch — routing this to
   research/strategy as a scoped follow-up rather than executing it here.
