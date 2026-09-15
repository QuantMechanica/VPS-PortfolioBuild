# Cross-vendor ATTACK critique — CAMP-2026-0001-ftmo-gap

**Creator:** Kimi (kimi-code/kimi-for-coding), research role, offline.
**Critic:** Claude / Fable (Opus 4.8, this orchestrator session), read-only.
**Cross-vendor:** TRUE (critic vendor `claude` ≠ creator vendor `kimi`; directive §52 "for a Kimi
creator the critic must not be Kimi" is satisfied).
**Why not the automated chain:** `agent_chain.run_chain` was attempted; its critic lanes
(codex terra / claude sonnet / agy) were all quota-gated (CLAUDE_DISABLED.flag,
CODEX_LOW_TOKENS.flag, AGY_LOW_QUOTA.flag present on 2026-09-15). Per the slice fallback, the
orchestrator's own reasoning — a different vendor than the Kimi creator — performed the
read-only critique. No file/verdict/gate was written by this critique.

**Verdict: REVISE** (0 blocking, 3 major, 3 minor). The research is sound and honest; the
candidate H-CW is worth preregistering and progressing, but promotion to a card / Q00 is
conditional on the findings below. Not REJECT — nothing here is fatal or fabricated; these are
the standard pre-Q00 conditions.

## What is strong (kept)
- Kimi **recomputed** figures directly from the projection CSVs and cross-checked them against
  the deterministic summary (spot-checks within ~2%). No invented numbers.
- It correctly refused to answer the preregistered refutation tests it could not run: the OBSERVE
  projection has **no worst-day-loss, wdd_p90, per-trade equity, or FTMO first-passage field**, so
  H1/H3's refutation criteria are untestable on this dataset. Stating this rather than faking a
  result is exactly right (directive §26 determinism, §53 honesty).
- The negative findings are substantive and business-relevant: density/scalp is NOT the edge
  (scalp worst class 0.399; higher trade count → lower pass rate); naive session tagging is NOT
  edge (`session=open` passes 44.4% < population); the current quality pocket (XAUUSD D1 position)
  is the very swap/overnight shape that breached the demo.

## Findings

### MAJOR-1 — post-selection on a tiny sample (n≈10)
H-CW's structural justification rests on "index intraday passed 9 of 10 Q10 rows". Ten rows across
two symbols (NDX, GDAXI) is a **tiny, post-selected** sample; Q10 is also **DXZ-scoped**, not FTMO
first-passage evidence. SP500.DWX is added to the H-CW symbol set with **no** Q10 evidence at all.
*Required before promotion:* treat the 9/10 as a hypothesis-generating prior only; the candidate must
earn its own Q02→Q10 evidence per symbol, and the FTMO claim must be shown on an FTMO-cost,
first-passage simulation — not on DXZ gate PASS.

### MAJOR-2 — simpler null: index intraday continuation ≈ the 2015–2024 index up-trend
A trend-continuation long/short breakout on NDX/GDAXI/SP500 over a period when those indices trended
strongly up has an obvious **simpler null explanation** (long-side beta to a secular bull), which
Kimi's own data hints at (metal/index highest pass rates are the most-trended classes). *Required:*
a regime-split OOS (explicit bear/range sub-periods), and a long/short symmetry check — if the edge
is long-only in a bull tape, it is beta, not an intraday-continuation edge.

### MAJOR-3 — cost/spread sensitivity is asserted, not evidenced
The whole FTMO thesis (low swap, bounded daily loss) lives or dies on **index-CFD spread +
commission at H1 intraday**, and the OBSERVE projection carries no cost fidelity. Kimi added a spread
filter (good) but the edge's survival under realistic index spreads is unmeasured. *Required:* a
cost-fidelity pass (the sprint's v2 cost snapshot covers only 5/10 symbols) before any FTMO
recommendation, per directive §63 / audit F6.

### MINOR-1 — parameter multiplicity
The H-CW grid is ≤432 combinations × 3 symbols. It is finite and bounded (good, mechanizable), but
the **effective trial count** must be declared and folded into the data-snooping accounting
(`search_history_ledger`), and the ±1-step neighbourhood fragility kill-criterion (Kimi's #4) must be
enforced, not just stated.

### MINOR-2 — `session=unspecified` conflation
Kimi correctly flags that 96.5% of rows are `session=unspecified` (a registry default, not measured
absence). The white-space "session blindness" conclusion is therefore about **tagging**, not about
measured exposure. This is a data-provenance limit to carry forward (observe_projector should derive
session from execution time-of-day, not only the slug), not a claim about the market.

### MINOR-3 — H2 expectancy gradient is partly endogenous
Kimi itself notes PF is plausibly baked into the farm's PASS criteria, inflating expectancy's measured
importance. The honest H2 conclusion is the weaker one it draws (activity has near-zero gradient), not
"expectancy is the true driver" — the expectancy gradient cannot be cleanly attributed on gate data.

## Infrastructure lesson (feeds the programme, not this card)
The campaign's most important structural finding is that **the OBSERVE projection cannot test
FTMO-specific hypotheses**: it lacks worst-day-loss, wdd_p90, per-trade streams and first-passage
outputs. Two of the three preregistered hypotheses were untestable for this reason. Future FTMO-gap
campaigns need an OBSERVE extension that joins the sleeve-stream / first-passage engines, or the
hypotheses must be framed against fields the projection actually carries.

## Disposition
- H1: INCONCLUSIVE (refutation criterion untestable on this projection) — agree.
- H2: REFUTED-in-proxy (activity is not the binding constraint; expectancy/quality is) — agree, with
  MINOR-3 caveat on attribution.
- H3: NOT ESTABLISHED (no session/time-of-day data to mine) — agree.
- H-CW: **preregister and progress as a candidate**, conditional on MAJOR-1..3. It is a genuinely new,
  mechanical, finite-parameter direction for the FTMO book, grounded in the farm's own evidence — not
  indicator soup. The pipeline (Q00–Q17) remains the judge.
