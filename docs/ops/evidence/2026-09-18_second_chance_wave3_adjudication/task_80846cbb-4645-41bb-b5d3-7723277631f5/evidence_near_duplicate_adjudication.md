# Evidence: Second-Chance Near-Duplicate Adjudication — Task `80846cbb-4645-41bb-b5d3-7723277631f5`

- **Task ID:** `80846cbb-4645-41bb-b5d3-7723277631f5`
- **Agent:** `claude`
- **Task Type:** `ops_issue`
- **Predecessor tasks:** `b0ef5d66` (11563), `8eaa5bf9` (11855), `f05399de` (11211), `27ae17d6` (11373) — all `research_strategy`, all `RECYCLE`d 2026-09-18 by the prescreen (`docs/ops/evidence/2026-09-15_second_chance_wave1/`, `docs/ops/evidence/2026-09-16_second_chance_wave2/`).
- **Mode:** Read-only adjudication with evidence for 11563 / 11855 / 11211 (no card edits — see §1–§3). Concrete content fix applied for 11373 (§4; no adjudication was in dispute for that card).
- **Verdict:** `REVIEW_READY`

---

## 0. Method

For each of the three disputed pairs, evidence was gathered from three independent sources so the call does not rest on prose alone:

1. **Mechanics diff** — full entry/exit/SL/TP/session/symbol comparison between the second-chance draft (`D:/QM/strategy_farm/artifacts/cards_review/PENDING_*`) and the approved twin (`D:/QM/strategy_farm/artifacts/cards_approved/*`) the prescreen matched against.
2. **`work_items` history of the approved twin** — `farm_state.sqlite` `work_items` table, grouped by `(phase, status, verdict)`, to establish whether the twin was ever built and, if so, on what grounds it stopped.
3. **`lineage_map.json` BEHAVIOUR-edge check** (`D:/QM/reports/state/lineage_map.json`) — the programme's trade-stream-based clone detector (Strategy Second-Chance Programme §1.4). Result: **no edge exists for any of the three pairs** (0 of 778 edges touch `QM5_11563`↔`QM5_11365`, `QM5_11855`↔`QM5_11277`, or `QM5_11211`↔`QM5_10026`). This is *not* exculpatory — the BEHAVIOUR detector requires overlapping realized trade streams on both sides, and two of the three twins have zero or terminal-early work items (see §1–§3), so it has no data to compare. The only usable evidence for these three pairs is the mechanics diff plus the twin's own pipeline history.
4. Cross-checked the `second_chance_register.json` record for each candidate: all four show `suppressed_clone_of: ""` and `independence/novelty: 1.0` — because the register's own clone-suppression pass (§1.4) only compares within the REJECTED/RETIRED/DRAFT population it enumerates, **never against already-APPROVED cards**. This is a structural blind spot: the register that *commissioned* these four retest tasks cannot itself see a conflict with an approved twin. Only the downstream `card_intake_prescreen.py` NEAR_DUPLICATE check (lexical + mechanism-term index) catches this class of conflict — and, as shown in §3, that same check has a real false-positive mode. **Recommendation:** the second-chance register generator (`tools/strategy_farm/research/second_chance_register.py`) should also index the `cards_approved` population for its clone-suppression pass, not just its own REJECTED/RETIRED/DRAFT population — otherwise every future second-chance wave can independently rediscover an already-approved strategy and only get caught at intake, one card at a time. Filed as a recommendation, not executed (touches shared programme code, outside this task's read-only scope).

---

## 1. `QM5_11563` (draft `PENDING_B0EF5D66`) vs. `QM5_11365` — **GENUINE near-duplicate. Recommend RETIRE the draft.**

Both are the same Connors & Alvarez RSI(2)/SMA(200) D1 mean-reversion rule, ported to the same FX majors:

| Rule component | Draft `PENDING_B0EF5D66` | Approved `QM5_11365` | Same edge? |
|---|---|---|---|
| Trend filter | `Close[1] > SMA(200,D1)` | `Close > SMA(200,D1)` | Identical |
| Entry trigger | `RSI(2,D1) < 10` (long) / `> 90` (short) | `RSI(2,D1) < 10` (long); short not separately specified but mirror-symmetric by construction | Identical |
| Exit trigger | `RSI(2,D1) > 65` (long) / `< 35` (short) | `RSI(2,D1) > 65` (Connors' own exit threshold, cited verbatim) | Identical |
| Stop loss | `2.0 × ATR(14,D1)`, capped 150 pips | `1.5 × ATR(14,D1)`, or fixed 40-pip P2 SL | Same mechanism, different multiplier |
| Take profit | None (pure RSI-cross exit) | 30-pip fixed TP or `0.8 × ATR` TP option | Minor variant |
| Symbols | EURUSD, GBPUSD, USDJPY | EURUSD, GBPUSD, USDJPY, **AUDUSD** | Draft is a strict subset |
| Extra filter | No-Friday-entry | (none stated) | Cosmetic addition |

None of these deltas (ATR multiplier, presence/absence of a fixed TP, one fewer symbol, a day-of-week filter) changes the causal claim: both cards are the identical "extreme short-term RSI(2) pullback inside an SMA(200) macro trend" bet on the same instruments. The prescreen's `NEAR_DUPLICATE score=1.0000` is a **true positive**.

**Twin pipeline history (`work_items` for `QM5_11365`): zero rows.** `QM5_11365` is `g0_status: APPROVED` (2026-05-23) but has **never been built or run** — no Q02+ evidence exists for it at all. This changes the recommendation from a simple "retire the copy" into an efficiency point: admitting `PENDING_B0EF5D66` as a new identity would spend fresh Q02–Q08 infra time proving a rule that an already-approved, zero-cost-so-far card (`QM5_11365`) is sitting in the queue to prove for free.

**Recommendation:** retire `PENDING_B0EF5D66` (do not mint a new EA identity for it). Separately — as a queue-priority note, not part of this card's own disposition — flag `QM5_11365` for build prioritization: it carries the same edge claim, has burned zero pipeline budget, and `QM5_11563`'s own prior run (Q06 `GBPUSD.DWX`, PF 1.57, 94 trades, work item `4ece110d-6033-48c3-89cc-96db30741d8a`) is corroborating (not substituting) evidence that the family is worth running to completion under `QM5_11365`'s own identity. Queue-priority reordering is a GRÜN action (Stehende Vollmacht); retiring a draft that never reached intake is not a gate-threshold or verdict change, so this is actionable without a new OWNER decision.

---

## 2. `QM5_11855` (draft `PENDING_8EAA5BF9`) vs. `QM5_11277` — **GENUINE near-duplicate, reinforced by real economic-failure evidence. Recommend RETIRE the draft.**

Both are the "Blade" M5 EMA(10)/EMA(21)/EMA(50) zone-retracement scalp on EURUSD, same source PDF (`219755537-Blade-Forex-Strategies.pdf`):

| Rule component | Draft `PENDING_8EAA5BF9` | Approved `QM5_11277` | Same edge? |
|---|---|---|---|
| Trend filter | 3-EMA alignment `EMA10>EMA21>EMA50` | `EMA(50)` slope | Different *test*, same directional-momentum claim |
| Zone | `mid = (EMA10+EMA21)/2`, retrace into zone | Zone = between EMA10/EMA21, enter at/below midpoint | Identical |
| Take profit | Fixed 10 pips | Fixed 10 pips (5 in weak trend) | Identical core number |
| Stop loss | Fixed 5 pips + spread | 5 pips + spread, placed behind EMA(21) | Same magnitude, minor placement difference |
| Break-even | +5 pips → move to entry | +5 pips → move to entry | Identical |
| Session | London 07-12 GMT, NY 13-17 GMT | London 08-17 GMT, NY 13-22 GMT, ±30min buffer | Draft is a narrower sub-window of the approved window |
| Symbols | EURUSD only | EURUSD, GBPUSD, USDJPY | Draft is a strict subset |

The core numbers that actually define this system's edge — 10-pip TP, 5-pip+spread SL, +5-pip breakeven, EMA(10)/(21) zone entry — are identical between the two cards. The only change is *how the trend precondition is tested* (3-EMA stack vs. EMA(50) slope) and a narrower session/symbol scope. That is a parameter tweak, not a different causal mechanism.

**Twin pipeline history (`work_items` for `QM5_11277`): 22 rows, terminal at Q04 FAIL** (2 Q04 attempts, both FAIL, most recent 2026-07-14; it did pass Q02 twice before that). Unlike `QM5_11365` (§1), this twin was **actually built and actually failed on economic grounds** (Q04 is the return/drawdown economics gate), not on infra or a G0 technicality. That is materially stronger evidence than a lexical match alone: the same core zone/TP/SL/BE numbers were tested end-to-end and did not clear the economics bar.

**Recommendation:** retire `PENDING_8EAA5BF9`. Re-admitting a narrower, single-symbol variant of a rule that already failed Q04 under its wider, multi-symbol form is not a genuine second chance — the origin's own G0 rejection reason (missing cadence estimate) was a paperwork gap, not the thing that actually killed this edge; the real verdict is `QM5_11277`'s Q04 FAIL. If this style is to be pursued further, it needs an actually different trend/entry mechanism with its own falsifiable edge claim, not a resubmission of the same zone-scalp numbers.

---

## 3. `QM5_11211` (draft `PENDING_F05399DE`) vs. `QM5_10026` — **FALSE POSITIVE. Recommend DIFFERENTIATE + RE-QUEUE — but a separate hard blocker (M1 timeframe) must be fixed first.**

These are not the same strategy:

| Rule component | Draft `PENDING_F05399DE` (BinHV45) | Approved `QM5_10026` (RW FX Squeeze MR) |
|---|---|---|
| Timeframe | **M1** | **H1** |
| Core signal | Band **pierce**: `Close[1] < lower_band[1]` plus band-expansion + bar-velocity + tail filters (capitulation) | Band-width **squeeze** (BB width below its own 20th percentile over a 120-bar lookback), then price closing back inside the band |
| Confirmation | None beyond the Bollinger geometry | `RSI(14) < 30` (long) / `> 70` (short) |
| Direction | **Long-only** (source has no sell signal) | Symmetric long **and** short |
| Exit | Fixed ROI target (+1.25% / 1.5×ATR) or hard stop; no signal-based exit | Bollinger-midline touch, 24-bar time stop, or early exit on band-width expansion above 80th percentile |
| Source | `freqtrade-strategies` GitHub, `BinHV45.py` | Robot Wealth blog index |

Timeframe, entry geometry (pierce-then-reverse vs. squeeze-then-breakout), confirmation indicator, direction scope, and exit model are all different. The only thing genuinely shared is generic Bollinger-Band/ATR/"mean reversion" vocabulary.

**Root cause confirmed in code:** `tools/strategy_farm/card_intake_prescreen.py::_duplicate_match` (lines 330–382) computes `mechanism_overlap` from a small controlled vocabulary (`_MECHANISM_PHRASES`, line 125). `"bollinger band"` is explicitly *excluded* from `_DISTINCTIVE_MECHANISMS` (line 138–142) — i.e. the code's own authors already knew "bollinger band" alone should not prove a duplicate — but the second escape clause (`len(shared_mechanism) >= 3 and mechanism_overlap >= 0.8`, line 374) still fires whenever three or more *generic* shared terms (here: `"bollinger band"`, `"mean reversion"`, and an `atr(14`-style indicator/number token) happen to be a superset of the reference card's small mechanism-term set. `QM5_10026`'s card body is short and its mechanism-term set is essentially just those three tokens, so any candidate that is a superset scores a perfect `1.0000` regardless of what the entry/exit rules actually say. This is a **known false-positive mode of the ≥3-generic-terms branch**, not a defect specific to this card pair — any two Bollinger-based mean-reversion cards with a short reference body are at risk of the same false match.

**Twin pipeline history (`work_items` for `QM5_10026`): 1,173 rows, currently active** (Q02→Q04 iteration ongoing through 2026-09-05, predominantly Q04 FAIL on recent runs but still being worked — not retired). This is an unrelated, independently-live candidate; there is no economic verdict here that bears on `QM5_11211` one way or the other.

**Recommendation:** differentiate + re-queue via `reconcile-task-exits`, with the card body carrying an explicit, deliberate mechanics-comparison paragraph against `QM5_10026` (timeframe, pierce-vs-squeeze, direction scope, exit model — as tabulated above), not an incidental phrase match. **However**, this card has a second, independent blocker that the differentiation does not fix: `tools/strategy_farm/card_intake_prescreen.py::_timeframe_allowed` (line 511–520) only permits `M5`–`M15` or `H1`–`H24` or `D1`; **`M1` is categorically outside the box** (`TIMEFRAME_OUTSIDE_BOX:M1`, confirmed by direct prescreen run, see §5). Retiming BinHV45 from M1 to M5 is not a field edit — the Bollinger(40) lookback spans ~40 minutes at M1 vs. ~3h20m at M5, so the `bbdelta`/`closedelta`/`tail` thresholds and the cadence estimate (currently 30–80 trades/yr/symbol, calibrated for M1 volatility) all need to be re-derived for the new bar size before this card can be resubmitted. This is a research task, not a mechanical retime, and should be scoped as such before `PENDING_F05399DE` goes back into the queue.

---

## 4. `QM5_11373` (draft `PENDING_27AE17D6`) — no near-duplicate was in dispute; concrete fix applied

Unlike the three cards above, the RECYCLE note for `27ae17d6` did **not** raise a duplicate concern — only `RISK_CONTRACT_MISSING`, missing `FALSIFICATION`/`Q08_Q11_RISK` sections, and a request to pin `MAGIC_BASE` explicitly. Since there was no adjudication call to make, this was fixed directly (`card.draft` + `repo.write` are both granted to `claude` in `framework/registry/agent_capabilities.json`).

**Root cause of `RISK_CONTRACT_MISSING`:** the card's Risk Management section read *"Zero opposite-side hedging. Zero martingale, zero grid, zero pyramiding."* `tools/strategy_farm/strategy_risk_contract.py::_NEGATION_RE` (line 108–112) recognizes `no|not|never|without|forbid(s/den)|prohibit(s/ed)|avoid(s/ed)|does not|do not|disallow(s/ed)` as negation tokens — **`"zero"` is not among them**. `detect_flags_in_text` therefore read "zero martingale, zero grid" as an *affirmative, non-negated* mention of `martingale` and `grid` (both `TAIL_AMPLIFYING_FLAGS`), which forced the fail-closed `RISK_CONTRACT_MISSING` reject even though the strategy has neither mechanism. Verified directly:

```
detect_flags_in_text("...Zero martingale, zero grid, zero pyramiding...")  -> ['grid', 'martingale']
detect_flags_in_text("...No martingale, no grid, no pyramiding, no averaging into losers...") -> []
```

**Fix applied** (not a workaround — the strategy genuinely has no tail-amplifying mechanism, so no risk-contract JSON should exist; fabricating one would violate the evidence-over-claims / no-invented-values hard rule):
- Reworded the two "zero …" sentences to explicit "no …" phrasing that the negation scanner recognizes (verified clean — see §5).
- Pinned `MAGIC_BASE = ea_id * 10000` explicitly in the Multi-Slot Magic Allocation section (the literal integer cannot be pinned pre-intake since `ea_id` is minted at `farmctl reserve-ea-ids` time; the formula itself, matching the framework standard in `CLAUDE.md`, is now stated in the card rather than left as prose-only `g_qm_fw_magic`).
- Added `## Falsification / Kill Criteria` (5 concrete, checkable falsifiers: no-edge PF≤1.0, timeout-dominated fills, tier cannibalization, news-blackout bypass rate, and an explicit requalification rule).
- Added `## Q08 / Q11 Crisis & News Risk` (DSR/MC/FDR framing — the 3 tiered slots are one correlated directional bet, not 3 independent trials; sealed-calendar/context-validity note referencing the exact defect classes that hit `QM5_11563`'s own second-chance rerun; a real, currently-unmitigated pending-order gap-risk-on-entry note; news-blackout scope across all 6 pending legs).
- While adding this prose, a **second** false-positive `NEAR_DUPLICATE` match appeared against `QM5_10001_ff-static-fib-open` (score 1.0000) — triggered by the new sections' generic breakout/pending-order/range vocabulary, not present before the edit. Investigated and confirmed false: `QM5_10001` is a trend-filtered (SMA70/RSI21/Stochastic), single-sided, open-price-anchored static pip ladder on M15 with a distance-to-open stop; `PENDING_27AE17D6` is an unconditional, bidirectional, prior-24h-range-anchored 3-tier bracket on H1 with fixed-pip stops. Documented this explicitly and deliberately in the card (not an incidental phrase match) rather than relying on an accidental "distinct from" string that first appeared in an unrelated sentence and happened to suppress the warning.

---

## 5. Verification

Direct, focused re-run of `tools/strategy_farm/card_intake_prescreen.py` against each single card (dry-run, no `--apply`, no side effects on any other card):

```
PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md
  verdict=REJECT reasons=[NEAR_DUPLICATE:QM5_11365...score=1.0000, CHARTER_SECTIONS_MISSING:FALSIFICATION,Q08_Q11_RISK]
  (unchanged by this task — read-only adjudication, recommend RETIRE)

PENDING_8EAA5BF9_blade-m5-ema-zone-scalp.md
  verdict=REJECT reasons=[NEAR_DUPLICATE:QM5_11277...score=1.0000, CHARTER_SECTIONS_MISSING:FALSIFICATION,Q08_Q11_RISK]
  (unchanged by this task — read-only adjudication, recommend RETIRE)

PENDING_F05399DE_ft-binhv45.md
  verdict=REJECT reasons=[NEAR_DUPLICATE:QM5_10026...score=1.0000, CHARTER_SECTIONS_MISSING:FALSIFICATION,Q08_Q11_RISK,FTMO_FIT, TIMEFRAME_OUTSIDE_BOX:M1]
  (unchanged by this task — read-only adjudication, recommend DIFFERENTIATE + RE-QUEUE after M1->M5+ redesign)

PENDING_27AE17D6_100pips-daily-range-bracket-usdjpy.md  (EDITED this task)
  before: verdict=REJECT reasons=[RISK_CONTRACT_MISSING]  (no CHARTER_SECTIONS_MISSING at intake time — sections were the commissioned ask, not yet a reject reason in the last recorded run)
  after:  verdict=KEEP   reasons=[]   warnings=[NEAR_DUPLICATE:QM5_10001_ff-static-fib-open.md:score=1.0000]  (adjudicated false positive, documented in-card)
  missing_charter_sections() == ()
  _risk_contract_reasons() == []
  timeframe H1, allowed=True; expected_dd_pct=5.0 (in range)
```

`lineage_map.json` (778 edges total): 0 edges touch any of `QM5_11563`, `QM5_11855`, `QM5_11211`, `QM5_11365`, `QM5_11277`, `QM5_10026` in either direction (data-starved, see §0).

`second_chance_register.json`: all four candidates (`11563`, `11855`, `11211`, `11373`) carry `suppressed_clone_of: ""` — the register's own clone pass never compares against the `cards_approved` population (see §0 recommendation).

---

## 6. Summary of proposed dispositions

| EA | Draft | Verdict | Disposition proposed |
|---|---|---|---|
| `QM5_11563` | `PENDING_B0EF5D66` | Genuine near-duplicate of `QM5_11365` (never built) | **RETIRE draft**; prioritize building `QM5_11365` instead |
| `QM5_11855` | `PENDING_8EAA5BF9` | Genuine near-duplicate of `QM5_11277` (Q04 FAIL, real economic evidence) | **RETIRE draft** |
| `QM5_11211` | `PENDING_F05399DE` | False-positive lexical match vs. `QM5_10026` (different TF/signal/direction/exit) | **DIFFERENTIATE + RE-QUEUE**, but only after M1→M5+ timeframe redesign (separate hard blocker, not fixed by differentiation prose alone) |
| `QM5_11373` | `PENDING_27AE17D6` | No duplicate in dispute; missing sections + false-positive risk-contract reject | **Fixed directly this task** — card now clears prescreen KEEP |

No card was moved out of `cards_review/`, no EA identity was minted, no `farm_state.sqlite` row was written, and no verdict was overwritten. `PENDING_27AE17D6_100pips-daily-range-bracket-usdjpy.md` is the only file edited (content-completion, not an adjudication call). This evidence document and the task update are the full deliverable; execution of the RETIRE / DIFFERENTIATE+RE-QUEUE dispositions for the other three cards is left to the commissioning/intake step (`reconcile-task-exits`) per the task's read-only-adjudication scope.
