# H-PY L3-reach root-cause analysis — ANALYSIS_NOT_PREREGISTERED

**Date:** 2026-09-16 · **Author:** Kimi (research role) under the interim OWNER
delegation (OWNER_DIRECT_SESSION_DELEGATION 2026-09-15/16) · **Store:**
QM-RESEARCH-2026-0007 (H-PY, QM5_41479) · **Status:** analysis only.
The preregistration of QM-RESEARCH-2026-0007 is untouched and stays sealed
(record_sha256 `f601ba6a…cfcb`); the frozen 2021-2024 holdout was not read at
any point. Nothing in this file re-selects parameters against the holdout, and
no kill/success decision is taken here.

**Artifacts:** `h_py_l3_analysis.py` (instrumented replay of the exact
preregistered rules + single-rule counterfactuals), `h_py_l3_analysis.json`
(per-basket records + aggregates). Both are labelled
`ANALYSIS_NOT_PREREGISTERED` and are **not** cited by the 0007 source manifest;
they are post-pilot diagnostics, not computed outputs of the frozen
preregistration.

## 1. Deterministic reproduction

Re-ran the frozen pilot runner (`h_py_pilot.py`, 2018-2020 in-sample,
zero-cost mids) before instrumenting it: the fresh output is **byte-identical**
to the committed `h_py_pilot.json` (sha256 `12b3eec3a15fc8b5421b8f59aade9a4aaed5858c5e7c8a7419570671f1f5639d`,
matching the 0007 source manifest). All analysis below is therefore against the
same deterministic 185-basket path the preregistration cites. The instrumented
base replay reproduces the preregistered totals exactly (185 baskets /
22 L2 fills / 0 L3 fills; exit mix 73 stop / 37 giveback / 75 flatten).

## 2. Root cause (one paragraph)

L3 was never reached — and at the preregistered session defaults *can never
be reached* — not because cash-session trends on this feed fail to run
+2.0 ATR (21 of 185 baskets closed ≥ +2.0 ATR from base entry, and 13 of the
22 L2-filled baskets printed such a close) but because of a structural clock
in the add-fill mechanics: signals fire on closes of the 16:00-17:00 bars and
fill at the next bar's open, so every base entry lands on the 17:00 or 18:00
bar (134 at 17:00, 51 at 18:00); a new favourable extreme is measured against
every bar *including the entry bar*, so the entry bar can never trigger an
add, the earliest L2 trigger is therefore the bar-after-entry close, the
earliest L2 fill is the 19:00 bar open, and adds are forbidden from filling
into the flatten-hour bar (20:00) while an L3 may only trigger on a bar
*strictly after* the L2 fill bar — so the only bar that could ever host an L3
trigger is the flatten bar itself, which force-flattens the basket at its
open. All 22 L2 fills occurred at the 19:00 bar (all from 17:00 entries; the
51 18:00 entries can never fill L2 at all — their earliest fill would land on
the flatten bar), and on 10 of those 22 the 19:00 close met the +2.0 ATR
condition (3 more met +2.0 ATR on the L2 trigger bar) — the level-3 trigger's
price condition was satisfied 13 times and the fill was mechanically barred
every single time. Single-rule counterfactual replays that disable the
giveback stop, the trail ratchet, the time stop, or the flatten *exit* still
produce **zero** L3 fills, exonerating all of them; the binding constraint is
the conjunction of "no add fills into the flatten-hour bar" with "L3 may only
trigger after the L2 fill bar" inside a session whose entry clock leaves at
most one bar between the earliest L2 fill and flatten.

## 3. Evidence

Entry/fill clock (base replay, 185 baskets):

| fact | value |
|---|---|
| base entry hours (next-bar fills of 16:00-17:00 signals) | 17:00 ×134, 18:00 ×51 |
| L2 fill bar, all 22 fills | 19:00 (bars_to_flatten_after_l2 = 1 for 22/22) |
| L2 fills from 18:00 entries | 0 of 51 (structurally impossible) |
| L2 baskets whose post-L2 CLOSE met +2.0 ATR | 10 of 22 (all on the 19:00 fill bar) |
| L2 baskets with a ≥ +2.0 ATR close anywhere (incl. trigger bar) | 13 of 22 |
| all-basket share closing ≥ +1.0 / +1.5 / +2.0 ATR | 23.2% / 16.8% / 11.4% |
| all-basket share printing an extreme ≥ +2.0 ATR | 17.3% |

Counterfactual L3 fills (each = the base spec with ONE rule disabled;
COUNTERFACTUAL, not proposals):

| replay | L3 fills | reading |
|---|---|---|
| BASE_PREREGISTERED | 0 | — |
| no_giveback (50% giveback stop disabled) | 0 | giveback stop exonerated as the binder |
| no_trail (1.0×ATR ratchet disabled; BE+buf only) | 0 | trail ratchet exonerated |
| no_time_stop | 0 | time stop is dead code here (6 bars > 3-4 bar holding cap) |
| no_flatten (flatten exit disabled; no-fill-into-flatten still on) | 0 | flatten *exit* exonerated; the fill-into-flatten rule does the excluding |
| shock_off (shock-skipped days tradable) | 0 | shock filter not the binder (see §5) |

Corridor arithmetic (why the giveback *would* have bound before the trail if
the clock had allowed the path to continue): for a 2-leg basket
(1.0 + 0.75, L2 ≈ +1.0 ATR), basket R = 1.75·move − 0.75, so the giveback
level (0.5·peak R) sits above the 1.0×ATR trail whenever the peak close is
below +2.43 ATR — i.e. over the entire approach to the +2.0 ATR trigger. The
recorded corridor votes agree (giveback tighter on 12 of 22 L2 baskets vs
trail 10), and pre-L2 giveback exits realize a median 0.70 ATR retrace
(p25 0.51 / p75 1.00) — a tight monetizing stop, working as designed, but not
what killed L3. Median post-L2 peak close across the 22 L2 baskets was
+1.86 ATR (margin to add3 median −0.14) — the mechanism was one bar short of
the trigger when the clock, not the stop, ended the basket.

## 4. Classification: **(a) — the 3-level contract degenerates to 2 levels**

Not (b): L3 reach is not rare, it is structurally 0 — the trigger's price
condition was met 13 times and the fill was barred 13 times; no length of
validation window can observe a positive rate (a power analysis for ≥20 L3
events at a true 0% structural rate is moot; even a hypothetical ~2% reach at
6.4 baskets/month would need ~940 months). Not (c): the trail ratchet is
exonerated by the no_trail replay and by the corridor arithmetic (the
giveback, if anything, is the tighter bound below +2.43 ATR). The honest
reading is (a): under the FTMO session-flat envelope the Family A 3-level
contract degenerates to 2 levels — the third level is dead code, the claimed
"level-3 rare" behaviour in the card is in fact "level-3 unreachable", and the
card may tighten its bounds within the family contract.

## 5. Secondary observations

* **Time stop is dead code at defaults.** Entries at 17:00-18:00 flatten at
  20:00 → max 3-4 bars held vs `time_stop_bars=6`. Exits_time_stop = 0 in the
  pilot and every replay; the parameter consumes range budget and does no
  work at the session defaults.
* **Shock-filter days are not the missing L3 substrate.** The 154 shock-skipped
  days produced 46 would-be signals; their no-exit excursion potential is not
  extraordinary (median +0.44 ATR, p90 +1.31, exactly 1 signal reaching
  +2.0 ATR) and they trade the same session clock, so un-skipping them could
  not create an L3 fill either. The 3.0 shock floor stays a vol filter, not an
  L3 gate.
* **The economics are carried by the base leg + L2.** The pilot's +0.12R/
  basket and PF(R) 1.26 were realized with L2 reach 11.9% and L3 reach 0 —
  i.e. entirely by the 2-level path. Tightening to 2 levels changes no realized
  pilot number; it aligns the contract with the mechanism that actually ran.

## 6. Recommendation (executed in QM-RESEARCH-2026-0008)

Mint a variant lineage **QM-RESEARCH-2026-0008 (parent 0007)** with the
Family A bounds tightened, never widened: `max_levels` 3 → 2, sizing
progression 1.0/0.75/0.5 → 1.0/0.75 (aggregate cap 2.25 → 1.75 legs), level-3
machinery (`add3_trigger_atr`, `level3_size_mult`) removed; every other rule
identical to the frozen 0007 card. This is exactly the family-sanctioned
tightening contemplated by the classification. The 0008 pilot re-runs the
2-level rules on the same read-only in-sample feed with the same honest
labeling; because the 3-level pilot never filled L3, the 2-level realized path
is identical by construction (a stated consistency check, not a new result).
The time-stop dead-code finding is documented but the parameter stays (it is
part of the family envelope and may bind at other session settings; removing
it is a widening of the range surface, not a tightening).

## 7. Joint-tail data note (for the wave-2 engine, §8 of the programme)

Candidate sealed streams for a future H-PY vs H-CW/H-MR overlap test, read
from `D:/QM/reports/state/book_evolution_dxz.json` (2026-W38):

* **Index-class sleeves of the passive book (same symbol factor as H-PY):**
  incumbent `live_24` — ea 13128 (NDX.DWX), 10440 (NDX.DWX), 13301 (GDAXI.DWX),
  10911 (GDAXI.DWX), 11132 (SP500.DWX); challengers with Q14 streams — ea
  11660 (NDX.DWX), 13013 (NDX.DWX).
* **The three FTMO candidates' planned streams (do not exist yet — G0-approved
  cards, build lane pending):** QM5_41475 (H-CW, cash-window continuation,
  QM-RESEARCH-2026-0002), QM5_41476 (H-MR, cash-open mean reversion,
  QM-RESEARCH-2026-0006), QM5_41479 (H-PY 3-level, QM-RESEARCH-2026-0007) and,
  if minted, the 0008 two-level successor (QM5_41480). The joint-tail protocol
  requires their farm .DWX Q08/Q14 streams once built; until then H-PY overlap
  vs H-CW/H-MR is EVIDENCE_MISSING.
* **Full passive-book reference set:** all 24 incumbent sleeves + 20
  challengers in the DXZ read-model (worst-day overlap baseline, per
  PORTFOLIO_TAIL_RISK_RESEARCH.md §4 part 2).

## 8. Method notes

* Same data root, window, cost model, and execution model as the pilot
  (zero-cost mids — declared confounder; results overstate any net edge).
* Counterfactuals each disable exactly one rule; no parameter was searched,
  no threshold was tuned, nothing was fit to the holdout (which remains
  sealed). The corridor arithmetic is a closed-form check on the recorded
  basket states, not a new simulation.
* The analysis script and its JSON are deterministic (re-run reproduces
  byte-identical output; the base replay inside matches the sealed pilot).
