## Research synthesis for OWNER — Phase 3 closure path 1/2/3 evidence

**Wake reason:** CEO honest readout 2026-05-07T10:10Z asked OWNER for direction on path 1 (wait for 1004+US500), path 2 (revise 1003 card), path 3 (revise Phase-3 closure criterion). Research has card-spec standing on all four active EAs. Synthesis below; final call is OWNER.

---

### Per-EA card-spec lens on the current evidence

#### QM5_1003 davey-baseline-3bar — **negative edge is EXPECTED per card**

Card § 1 + § 16 (`davey-baseline-3bar_card.md`) verbatim:

> "**Davey does not present Strategy 1 as a personally-traded strategy** — it is a methodology demonstration. Per OWNER Rule 1, Research nonetheless extracts it as a card; the V5 pipeline gates G0/P2 will rule on whether it has a real edge worth keeping."

> Davey's own framing (Ch 12 p. 109): "With any strategy I create, the strategy's performance better be significantly improved over what any monkey could do by just throwing darts. If it is not, then I have no desire to trade such a strategy."

The 1003 P2 cohort outcome (2/72 PASS with PF=0.65/0.35, DD=68%) is the V5 P2 gate **doing its job**: ruling that Davey's monkey-baseline does not have a real edge worth keeping. This is **not** a Phase-3-closure blocker. It is the gate's correct verdict on a card that was **explicitly extracted as a baseline** for the gate to rule on.

**Implication for OWNER decision:** path 2 (revise 1003 card to widen entry filter) is the **wrong path on process grounds**. The card is correct as-authored — Davey's baseline is supposed to be marginal. If V5 wants a positive-edge Davey strategy, it should extract one of Davey's other Strategies (App A Strategy 2/3/4, all of which Davey designed AS positive-edge variants vs Strategy 1's baseline). That would be a new Research card extraction (QUA-664-class scoping by OWNER), not a card revision.

#### QM5_1004 davey-es-breakout — **strongest path-1 candidate; needs OWNER on US500.DWX**

Card § 2: "Instrument family: ES proxy (Darwinex US500 symbols)" — Davey's published example uses E-mini S&P 500 futures. Davey's CTA-style break-and-reverse with 20-bar lookback was tuned on the exact instrument the card targets.

Currently blocked on QUA-770 ASK (Darwinex US500/NAS100 source data acquisition). DevOps has the import infrastructure ready (`infra/scripts/Test-CustomSymbolPresence.ps1` + `Sync-CustomSymbolData.ps1`); the gap is "Provide Darwinex export/source for `US500.DWX` and `NAS100.DWX`, or approve terminal-interactive acquisition session on this host" (QUA-770 16:32:13Z DevOps comment).

**Implication for OWNER decision:** this is the **strongest path-1 candidate** on technical merit. Davey-on-ES is the closest match to source-author intent across the 4 active EAs. If OWNER unblocks broker activation, Pipeline-Op already has the cohort design (US500.DWX × {H1, H4, D1} × 6-month 2024).

#### QM5_1009 lien-fade-double-zeros — **post-revert zero-trades is EA bug beyond card**

CEO honest readout: "CTO QM-00082 EA revert WORKED (reverted Variant flags) but **strategy still doesn't trigger any trades** on M15 forex 2024 even with card-aligned defaults."

I inspected commit `58c23125` ("QM-00082: revert 1009 variants to card defaults"). The revert reverted the **defaults** to false but **left the variant LOGIC paths in place** in `Strategy_EntrySignal()`:

```mq5
const double trigger_offset_pips = relaxed_entry_logic
                                   ? MathMax(2.0, entry_offset_pips * trigger_offset_scale)
                                   : entry_offset_pips;
const double long_round = directional_round_selection ? RoundAbove(close1) : round_mid;
const double entry_buy = entry_at_round_mode ? long_round : (long_round + (trigger_offset_pips * pip));
```

With all variant flags = false, these ternaries evaluate to the original card-aligned branches. Functionally equivalent to the pre-variant code. So zero-trades-post-revert is **not** explained by leftover variant logic.

**Three implementation hypotheses for CTO/Dev:**

1. **`.ex5` not actually recompiled / not deployed to T1-T5.** Pipeline-Op may have run the old binary. Smallest-verification check: compare `.ex5` mtime to `.mq5` mtime + verify `.ex5` byte-identical across T1-T5 `MQL5/Experts/QM/`.

2. **Pending-order persistence bug.** `HasOurPendingOrder()` may return `true` after the first staged order, blocking all subsequent staging (line 200ish: `if(HasOurPendingOrder()) return false;`). On M15 with `order_expiration_minutes=60`, expired pendings should clear in 4 bars, but if magic-slot management has a bug, stale pendings persist forever.

3. **Friday-close cancels staged stop orders.** `qm_friday_close_enabled = true` default. If the friday-close logic cancels pending stop orders alongside open positions, it may be wiping the staged buy/sell stops every Friday and the next staging window doesn't re-fire until far from a round number.

Minimal-verification test for OWNER/CTO: single USDJPY M15 backtest 2026-04-01 to 2026-04-30 with `qm_friday_close_enabled=false` + verbose tester logging. Should see ≥1 entry attempt per round-number visit (USDJPY visited 154, 155, 156 multiple times in April 2024). If still 0 trades, the bug is hypothesis 1 or 2.

**Implication for OWNER decision:** 1009 is **not Phase-3-closure-blocking** (CTO debug + rerun is non-blocking parallel work; doesn't need OWNER input). Defer until 1004/1017 settle.

#### QM5_1017 chan-pairs-stat-arb — **queued but not run; cleanest pair-trade path**

CEO readout: "P2 done (PASS=0/FAIL=36) before card-aligned redeploy. QM-00080 redeploy (curated cadf-eligible D1 pairs) queued but Pipeline-Op never ran it."

The QM-00080 redeploy is fully specified: ~4-5 set files for {AUDUSD×NZDUSD, EURUSD×GBPUSD, XAUUSD×XAGUSD, AUDCAD spot-proxy} × D1. **No broker-data dependency** (these are all native DXZ symbols). Pipeline-Op-only task.

**Implication for OWNER decision:** if OWNER picks path 1, this is the **second strongest candidate** alongside 1004. Doesn't depend on US500 unblock. Could ship Phase-3-acceptable evidence INDEPENDENTLY of 1004.

---

### Research recommendation for OWNER path-1/2/3 decision

**Path 2 is wrong on process grounds.** Revising the 1003 card to widen entry filter would create a different strategy under the same card name — that's "design a strategy", not "extract a strategy." V5's BASIS rule says Research extracts only what the source actually claims; we don't redesign authored strategies inside cards. If OWNER wants a positive-edge Davey strategy, scope a new Research extraction for one of Davey's App A Strategy 2/3/4 (all designed AS positive-edge variants of the baseline).

**Path 1 is the right primary call** with two parallel tracks:

- **Track 1a (OWNER-blocked):** Unblock Darwinex US500.DWX/NAS100.DWX broker activation per QUA-770 ASK. Critical-path evidence is 1004 davey-es-breakout on its source-author-intended instrument. Highest-confidence path to positive-edge Phase-3-closure evidence.

- **Track 1b (Pipeline-Op-only, no OWNER unblock needed):** Run the queued QM-00080 (1017 curated cadf D1 pairs). No broker dependency; Pipeline-Op can dispatch directly. Independent path to a different positive-edge candidate.

In parallel: **CTO/Dev debug 1009** (hypotheses 1/2/3 above) — non-blocking, runs on its own track.

**Path 3 is the right fallback** if both Track 1a and Track 1b fail to produce positive-edge evidence within ~7 days. The structural achievement (toolchain-proven across 1003+1004+1009 cohorts; first-EA-through-pipeline demonstrated) IS a real Phase-3 deliverable; the strategy edge question is genuinely Phase-4. Decoupling Phase-3-closure from "PASS rate" to "cohort EXISTS with valid DL-054 verdicts" is a CEO/OWNER-class criterion revision but it is not a process violation — the V5 pipeline phase spec was written before the toolchain was operational, and adjusting the gate criterion based on first-pass operational evidence is appropriate.

**Research note on 1003 negative-edge:** even if path 3 is taken, the 1003 P2 result (PF=0.65/0.35) should be recorded as a **POSITIVE pipeline outcome**: the V5 G0/P2 gate correctly identified Davey's monkey-baseline as not-edge-bearing, exactly as Davey himself framed it. This is the gate doing its job, not the gate failing.

---

### Out of scope for this comment

- Card edits — none needed; cards are correct as-authored on all 4 active EAs.
- New issue filing — OWNER decision is the gate; CEO will route the chosen path.
- 1009 EA debug — CTO/Dev lane.
- 1017 redeploy dispatch — Pipeline-Op lane (already queued QM-00080).
- US500 broker activation — DevOps + OWNER lane.

---

### References

- 1003 card: `strategy-seeds/cards/davey-baseline-3bar_card.md` § 1 (concept: monkey-baseline framing) + § 16 (Davey verbatim quote)
- 1004 card: `strategy-seeds/cards/davey-es-breakout_card.md` § 2 (instrument family: Darwinex US500 symbols)
- 1009 card: `strategy-seeds/cards/lien-fade-double-zeros_card.md` § 4 (canonical card-aligned defaults)
- 1009 EA post-revert: commit `58c23125` "QM-00082: revert 1009 variants to card defaults" — variant logic paths still present, defaults reverted to false
- 1017 card: `strategy-seeds/cards/chan-pairs-stat-arb_card.md` § 3 (D1 cadf-cointegration pair candidates)
- CEO honest readout: this issue 2026-05-07T10:08:50Z
- Prior Research input chain: comments 7b387fbc + 54f79913 + 57cc35c2 (all CEO-accepted)
