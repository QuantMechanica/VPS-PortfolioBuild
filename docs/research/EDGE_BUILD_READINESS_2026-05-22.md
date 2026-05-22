# Edge Lab — Cross-Cutting Build-Readiness Findings

Date: 2026-05-22
Author: Claude (orchestration cycle, router task dbddc2ab)
Status: SCREEN — structural findings feeding G0 / Codex build planning
Companion: `docs/research/EDGE_CARD_SCREEN_2026-05-22.md` (per-card verdicts)
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`

This artifact answers a different question from the per-card screen: not "which
card", but "what blocks a whole *class* of these cards before MT5 time is spent."
Four cross-cutting findings, each verified against the repo / runbook state.

---

## Finding 1 — The cross-sectional build pattern already exists. Use it; do not re-invent it.

Eight of the 27 cards (QM5_10717, 10718, 10719, 10720, 10721, 10722, 10889,
10894) are cross-sectional / basket strategies. Several explicitly say *"the
per-symbol Q02 fanout must be adapted — **Flag for G0 / build design**"*, which
reads as an open architecture question.

**It is not open. Verified in `framework/EAs/`:**

- `QM5_1057_asness-xsmom-rank` is a built V5 EA that does exactly this: one EA on
  one host chart, a hardcoded `g_universe_symbols[11]` basket, per-symbol magic
  slots (`g_universe_slots`), `SymbolSelect()` on each basket member, and a
  cross-sectional momentum rank with top/bottom-N slot selection. It even
  carries the relevant inputs (`strategy_lookback_d1_bars`,
  `strategy_rank_slots_each_side`, `strategy_spread_median_days`).
- `framework/include/QM/QM_BasketOrder.mqh` exists as a basket-order helper.
- Prior basket EAs: `QM5_2012_nnfx-v2-fx-basket-top3-trend`,
  `QM5_1095_qp-dollar-carry-basket`.

**Implication:** the cross-sectional cards should be built on the QM5_1057
pattern — single host symbol, hardcoded basket, per-slot magics — **not** as a
new per-symbol Q02 fanout and **not** behind a new framework subsystem. The
"Flag for G0" notes can be closed with: *"build on the QM5_1057
asness-xsmom-rank pattern."* This removes the perceived blocker for ~8 cards.

**Correction to the card text:** QM5_10889 frontmatter/notes claim it *"uses the
`xsec_rank_logic` from the V5 framework."* Verified false — `xsec_rank`,
`cross_sectional`, `MultiSymbol` return **no matches** anywhere under
`framework/`. There is no shared module; QM5_1057's ranking logic is inline.
Codex should copy the QM5_1057 pattern, and the card should not assert a module
that does not exist.

---

## Finding 2 — Data-availability is overclaimed on several cards (`r3` is wrong).

The Edge Lab requires R3 (data available) to be real, not aspirational. Audit of
the non-price inputs the cards depend on:

| Card | Non-price input required | Available on the farm? | Action |
|---|---|---|---|
| QM5_10722, 10718 | broker swap rates (`SYMBOL_SWAP_LONG/SHORT`) | **Yes** — deterministic, applied inside the MT5 tester | OK |
| QM5_10741, 10742, 10865 | "swap proxy / bill rates / VIX" | swap: yes; **VIX: not a confirmed DWX feed** | Re-express filters on price-derived realized vol; drop VIX |
| QM5_10889 | 10Y–2Y govt yield-curve slope | **No** — not a price feed | R3 = FAIL or re-spec on a price macro-proxy |
| QM5_10894 | oil, copper, **iron ore** prices | oil/gold yes; **iron ore not a DWX symbol** | Constrain to commodities actually present, or R3 FAIL |
| QM5_10767 | AAPL/MSFT/NVDA earnings calendar | **No** — not in the `news_calendar` seed | R3 FAIL until a calendar is sourced + checked in |
| QM5_10764 | multi-exchange index holiday calendars | partial | confirm coverage at G0 before build |
| QM5_10349, 10350 | US CPI / employment release calendar | needs a checked-in CSV (cards specify building one) | OK if the CSV is authored as the cards state |

Cards QM5_10889 and QM5_10767 currently carry `r3_data_available: true`/`PASS`
while depending on data the farm does not have. G0 should correct those before
they consume a build slot — a zero-trade or `INIT_FAILED` run on missing data is
wasted MT5 time and pollutes the queue.

---

## Finding 3 — News-blackout vs. announcement-trading is a real charter conflict. Needs an OWNER/G0 ruling.

The charter (lines 28–32) mandates a news blackout and states it **overrides
`allow_fomc_hold`** — "the QM5_10260 setting that holds across FOMC is now
non-compliant and must be removed / inverted."

But the charter also defines Direction 2 as event-conditioned and says *"we
trade the drift, not the release spike"* (line 53).

Two cards sit on the wrong side of the literal blackout rule:

- **QM5_10349** explicitly *"intentionally holds through scheduled high-impact
  U.S. macro releases"* (CPI / employment).
- **QM5_10350** does the same with a paired NDX/WS30 leg.
- QM5_10768 enters 2h after the FOMC statement.

These are not careless — the whole Savor-Wilson thesis *is* the
announcement-day risk premium; you cannot test it from fully outside the
window. But as written they contradict the blackout-overrides-hold rule.

**This is a decision, not a code fix.** G0 / OWNER must rule explicitly whether
"enter before the announcement-day close, exit at announcement-day close,
holding *over* a scheduled CPI/employment print" counts as the charter's
sanctioned "trade the drift" carve-out, or whether it is the prohibited
"hold across the event." Until that ruling exists, QM5_10349 and QM5_10350
**cannot pass the FTMO-compliance check** and should not enter the build queue.
The same ruling decides QM5_10768.

---

## Finding 4 — The FOMC family is fragmenting away from the active lead QM5_10260.

`PROFITABILITY_TRACK_2026-05-21.md` makes `QM5_10260_cieslak-fomc-cycle-idx` the
primary route to a profitable EA, with a defined variant queue that already
includes:

- variant 2: "decay-aware pre-FOMC drift"
- variant 3: "post-FOMC continuation window"

Two cards_review drafts duplicate exactly those:

- **QM5_10891** `el-d2-t10-fomc-drift` == pre-FOMC drift == variant 2.
- **QM5_10768** `fomc-post-mom` == post-FOMC continuation == variant 3.

Building them as independent Edge Lab `ea_id`s does two harmful things: it
fragments the FOMC family across unrelated ids (harder to compare, harder to
promote), and it risks the G0 dedupe gate firing against the active lead. The
profitability track is also explicit that QM5_10260 variants are created **only
after the flagship P2 result is known** — carding them now is premature.

**Recommendation:** route QM5_10891 and QM5_10768 into the QM5_10260 variant
queue rather than the Edge Lab build queue. The Savor-Wilson cards (QM5_10349/
10350) correctly already exclude FOMC dates and carry dedupe notes — they are
the right model for how event cards should stay clear of the QM5_10260 lead.

---

## Summary — what to settle before the next build batch

1. **Close the "Flag for G0" architecture question** with one sentence: build
   cross-sectional cards on the `QM5_1057_asness-xsmom-rank` pattern. Removes the
   perceived blocker for ~8 cards. (Finding 1)
2. **Correct three `r3_data_available` claims** (QM5_10889, 10894, 10767) before
   they reach a build slot. (Finding 2)
3. **Get an OWNER/G0 ruling** on announcement-day holds vs. the blackout rule —
   it gates QM5_10349, QM5_10350, QM5_10768. (Finding 3)
4. **Reroute QM5_10891 + QM5_10768** to the QM5_10260 variant queue. (Finding 4)

None of these four needs MT5 time. All four, left unaddressed, cause wasted
backtests, dedupe-gate rejections, or FTMO-compliance failures downstream.
Resolving them on paper is the cheap falsification the charter asks for.
