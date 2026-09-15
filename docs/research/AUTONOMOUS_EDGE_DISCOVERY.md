# Autonomous Edge Discovery — Programme Charter

**Authority:** OWNER master directive 2026-09-15 (OWNER-DEC-CBE-20260915), §37–§54, §68 PHASE G,
§69, §70; follow-up completeness directive §16. Decision record:
`decisions/2026-09-15_owner_continuous_book_evolution.md`. Companion specs:
`docs/ops/KIMI_EDGE_DISCOVERY_DESIGN.md`, `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`,
`docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md`.

**Status:** ACTIVE since 2026-09-15. This charter defines *how* QuantMechanica discovers new
mechanical trading edges from its own evidence and from original hypotheses — not only from
external sources — and how each discovery is falsified, mechanized, and validated before it can
reach a book. It is a business process whose product is **validated mechanical Strategy Cards**,
not research volume (directive §0, §73).

---

## 1. Why this programme exists (directive §38)

QuantMechanica's external harvest has examined an enormous number of sources and has not
produced enough high-quality strategies to fill the two books. External sources are therefore
**no longer the boundary** of the strategy universe. Fable and Kimi are expected to ask:

> *What market behaviour could constitute an exploitable mechanical edge that QuantMechanica has
> never tested?*

and to design experiments that answer it. Negative knowledge — thousands of failed backtests —
is treated as a first-class asset (§45).

The measured harvest funnel that motivates the shift (audit
`research_universe_whitespace.md`, `harvest_funnel.csv`, live DB `mode=ro`, 2026-09-15):

| Stage | reached (ea×symbol pairs) | PASS |
|---|---|---|
| Q02 | 14,935 | 7,272 |
| Q04 | 7,242 | 836 · **first economic wall** |
| Q08 | 314 | **54** · **second economic wall** |
| DXZ book | **55** | — |

End-to-end yield ≈ **0.37 %** (55 book pairs / 14,935 Q02 pairs). The tracked `sources` table
holds only **118 rows (96 done)** plus **664 seed folders**, and there is **no per-EA origin
field**, so `EXTERNAL HARVEST ROI` vs `INTERNAL DISCOVERY ROI` (§49) is currently a measured
**GAP** — see §9 below. The economic-failure population available to mine is **~12,850 distinct
family×symbol×gate pairs**, concentrated at Q04 (6,396) and Q02 (5,322).

---

## 2. The autonomous research loop (directive §43)

```
OBSERVE → ASK → HYPOTHESIZE → DESIGN EXPERIMENT → DISCOVER → MECHANIZE → ATTACK
        → PREREGISTER → TEST → LEARN
```

**Where practical, the hypothesis must exist before decisive validation data is examined.** A
hypothesis is not silently modified after seeing holdout results and re-sold as the same
strategy: a material change mints a **new lineage version with a parent link**
(`preregister.py`, `research_source.remint`). This is the anti-data-snooping backbone (§53).

### 2.1 OBSERVE (§44) — the evidence inventory, with INFRA kept apart

OBSERVE is produced deterministically and read-only from `farm_state.sqlite`
(`tools/strategy_farm/research/observe_projector.py`, schema `qm.research-dataset/v1`). Its
inputs: PASSes, economic FAILs, trade streams, symbol outcomes, sessions, holding periods,
parameter sweeps, walk-forward, stress, seeds, news tests, pattern-filter tests, portfolio
rejections, live/demo behaviour, correlations, Lessons Learned.

**Hard separation (never negotiable).** Every OBSERVE row carries a `verdict_taxonomy`; the
manifest's `verdict_taxonomy_split` enumerates *every* taxonomy → disposition so the split is
provably complete. **INFRA failures, setup failures, NO_REPORT and symbol/data failures are
never mixed into economic answers.** An infrastructure crash never teaches that a trading idea
is bad. The projector emits the white-space axes the FTMO mission values most — `timeframe`,
`holding_class`, `symbol_class`, `session` (per gate-outcome row) and `parameter_sensitivity`
(only where an OPT_CENSUS `runs` list makes the objective-spread genuinely derivable; never
invented).

### 2.2 ASK / HYPOTHESIZE (§39, §40)

A strategy may originate from a book, paper, video, trader, commercial-EA reconstruction, QM
test results, failed Strategy Cards, live/demo data, trade streams, parameter landscapes,
statistical analysis, ML-supported discovery, market-microstructure or economic reasoning, an
original Kimi hypothesis, an original Fable hypothesis, or multi-agent synthesis. **No external
human source is required for a genuine internal discovery — its internal research artifact is the
source** (`QM-RESEARCH://<id>`).

**Anti-random-indicator rule (§40).** Autonomous discovery is *not* "combine RSI + MA + ATR
until something backtests well". Preferred hypotheses rest on meaningful market behaviour:
session transitions, opens/closes, liquidity changes, volatility compression/expansion, trend
persistence/exhaustion, breakout continuation/failure, false breakouts, structural mean
reversion, overnight/intraday-inventory effects, opening-auction behaviour, prior-day structure,
range expansion/contraction, cross-timeframe structure, gap behaviour, recurring regime
transitions. Pure empirical discoveries with no prior mechanism are still allowed **but require
stronger data-mining scrutiny** (larger declared trial count, tighter holdout discipline).

### 2.3 FAILURE MINING (§45) — a first-class programme

Most research studies winners; QuantMechanica has a large *failed* population and mines it for:
recurring losing conditions, regime dependence, shared hidden factors, filters that repeatedly
destroy edge, conditions where failed edges temporarily work, families that fail identically,
symbol-specific asymmetries, time-of-day effects, parameters that do not matter, and failure
clusters. The densest current seam (audit `economic_failures_family_symbol_gate.csv`):
trend/momentum & "other" × {EURUSD, GBPUSD, XAUUSD, USDJPY} × Q04.

### 2.4 WHITE-SPACE RESEARCH (§46)

Continuously measure the universe: which mechanisms dominate / are missing, which sessions and
symbols are underexplored, which holding durations are absent, which portfolio risks stay
concentrated, which FTMO needs are poorly served, which families are overrepresented. The
sharpest measured white space today: **95.3 % of tested pairs carry no session tag** and
**scalp (M1–M5) is only ~10 %** — exactly the FTMO-fit directions (§47/§48). *Do not endlessly
create cousins of the same breakout strategy.*

### 2.5 MECHANIZE (§51) — the gate before validation

No ML or abstract discovery proceeds as a trading candidate until it is written as **exact
mechanical logic**: long/short entry, no-trade conditions, stop/exit/trailing logic, session
rules, filters, parameter ranges, timeframe, symbol assumptions, risk rules, expected frequency,
invalidation. The deterministic test (`tools/strategy_farm/research/mechanization_check.py`):

> *Could Codex implement this EA correctly from the Strategy Card without access to the original
> ML model or the Kimi conversation?* If NO → research is incomplete (`RETURN_TO_RESEARCH`).

### 2.6 ATTACK — cross-vendor falsification (§52)

Before an internally discovered candidate is promoted, **another provider attempts to falsify
it**. Creator and Critic differ whenever possible; **for a Kimi creator the critic must not be
Kimi**; for a Fable/Claude creator an independent eligible provider is used. The critic is
**read-only** and asks: data leakage? look-ahead? post-selection? multiple testing? tiny sample?
one-symbol / one-period artifact? parameter explosion? cost sensitivity? duplicate edge? hidden
regime dependency? a simpler null explanation? The chain runs through
`tools/strategy_farm/agent_chain.py` (`run_chain` with the delivered artifact as the reused
creator output); `agent_chain.open_critic_seats` refuses a Kimi critic for a Kimi creator in
code. **The pipeline (Q00–Q17) remains the final judge.**

### 2.7 PREREGISTER & data-snooping defence (§53)

`preregister.py` freezes the hypothesis (hash of the mechanical spec) with its parameter ranges,
discovery sample, validation sample, holdout logic, expected behaviour, success/failure criteria
and known risks **before** decisive validation. `search_history_ledger.py` counts every
DISCOVER search (hypothesis family, dataset id, symbols/timeframes/feature families searched,
parameter-space size, holdout id, whether the holdout was touched) so the winner-only report
pattern is structurally impossible. A holdout re-mined repeatedly is marked contaminated and the
candidate down-weighted. **These trial counts are evidence for a card's declared
`research_trial_count`; they are never folded into a sealed Q08 DSR cohort** (that is a separate
ROT decision).

### 2.8 LEARN — experiment memory (§54)

`experiment_memory.py` extends the existing ledger/report architecture additively (no new
database). It makes it queryable what was tried, why, what failed, what succeeded, what was
duplicate, what depended on a regime, what worked only on one symbol, what was overfit, which
filters added/removed value, and which hypotheses were already falsified. **Every material
research conclusion resolves back to `work_item_id` evidence.**

---

## 3. Machine learning policy (directive §41, §42 — HR14 annex 2026-09-15)

**Allowed in offline research:** clustering, classification, regression, tree models, feature
importance, interaction analysis, dimensionality reduction, anomaly detection, regime
identification, unsupervised discovery, statistical learning. Purpose: discover robust candidate
*relationships* ("under A+B+C the outcome distribution changes materially"), then formulate
mechanical rules, define parameters, preregister, implement a deterministic EA, validate
normally.

**Forbidden in EA runtime (unchanged):** runtime inference, remote inference API, online
learning, runtime retraining, any opaque adaptive-model dependency. The EA must be executable
from its mechanical specification alone. `mechanization_check.py` fails closed on any ML term in
the mechanics sections (the `## Research provenance` narrative is the only exempt heading).

---

## 4. Provider roles

| Role | Provider(s) | Rule |
|---|---|---|
| Originate + orchestrate | **Fable (Claude, this orchestrator)** | Owns the whole board; formulates hypotheses, commissions analysis, decides preregistration, mints internal sources, chooses which provider researches each task. |
| Research (deep quant / ML / large-context) | **Kimi** | Research-only capability provider (no code/ops/verdict/gate authority). Authors hypotheses and analyses; every Kimi-authored artifact gets a non-Kimi critic. `research`/`research_ml` roles via `kimi_adapter.run_kimi`. |
| Cross-vendor critic (read-only) | **Codex / Claude / agy — never the creator's own vendor** | Attempts falsification; writes nothing; never a verdict. |
| Broad external harvest | **Antigravity (agy)** | Source discovery / mechanization of published ideas (external programme, §50). |
| Final judge | **The Q00–Q17 pipeline** | Research never bypasses qualification. |

Internal-source authorship (§37) is generalized: an artifact may record author `Kimi`, `Fable`,
`Claude`, `Codex`, `Antigravity`, or a documented `multi-agent:<list>` collaboration
(`config/research_source.v1.json`). The same provenance/hash/lineage requirements apply to all
(`research_source.verify`, fail-closed).

---

## 5. External vs internal ROI (directive §49, §50)

Two complementary programmes run in parallel — **EXTERNAL EDGE HARVEST** (books, papers, videos,
commercial systems, traders) and **INTERNAL EDGE DISCOVERY** (QM's own evidence + autonomous
hypotheses). Both produce mechanical Strategy Cards; both face full validation. Research capacity
is allocated by comparing their ROI along: sources processed, mechanical strategies extracted,
candidates reaching Q02 / Q08 / Q14, candidates entering books, and resulting economic
contribution.

**Current measurement gap.** The per-EA origin field needed to split the two ROIs does not yet
exist (`ea_id_registry.csv:owner` is a mission/agent label, not an origin class). Until an
`origin ∈ {external_source, internal_discovery, owner_mission}` field is backfilled, the §49
comparison is reported as **GAP**, not guessed. This is an engineering task, not an OWNER
decision (audit `research_universe_whitespace.md` §6).

---

## 6. Campaign lifecycle and where receipts live

A **campaign** is one bounded run of the loop against one high-value question. Identifier:
`CAMP-YYYY-NNNN-<slug>`.

1. **OBSERVE** dataset built read-only → `D:/QM/research/campaigns/<id>/observe/` (content-
   addressed manifest, per-file sha256).
2. **PREREGISTER** the hypotheses (`preregistration*.json`, immutable, lineage-linked) + append
   the search-history ledger (discovery vs holdout recorded).
3. **DISCOVER** — Kimi runs on the dataset (`kimi_adapter.run_kimi`, role `research` /
   `research_ml`); the call refreshes the OAuth token so `kimi_governor evaluate` telemetry works
   afterwards.
4. **Artifact** minted as `QM-RESEARCH://<id>` (`research_source.mint`, author = the researcher):
   `source.md` + `research.json` + `lineage.json` + `critic_receipt.json` + computed-output
   JSONs (numeric provenance) + hypothesis cards + `observe_manifest.json`, bound by the fenced
   `qm-source-manifest` block (`sha256(source.md)`).
5. **MECHANIZE** each hypothesis card (`mechanization_check.py`).
6. **ATTACK** — cross-vendor critique (`agent_chain.run_chain`, critic ≠ creator vendor).
7. **SEAL** the artifact only if the critic verdict is not REJECT (else it stays unsealed with
   the verdict attached).
8. **LEARN** — record `experiment_memory` + `search_history`; refresh the research-state
   read-model (`research_state_readmodel.py` → `D:/QM/reports/state/research_state.json`).
9. **RECEIPT** — a human-readable campaign receipt at
   `docs/ops/evidence/2026-09-15_continuous_book_evolution/research/CAMP-<id>_receipt.md` and the
   machine manifest `D:/QM/research/campaigns/<id>/campaign.json` (schema
   `qm.research-campaign/v1`, consumed by Mission Control's Research view and the weekly
   briefing). A campaign that cannot complete a step records the exact blocker and still delivers
   **at least a durable negative finding** — an integrated research provider that never researches
   creates no business value (follow-up §16).

The first campaign is **`CAMP-2026-0001-ftmo-gap`** (FTMO gap research, §47), commissioned
because FTMO is the larger current strategic gap and no candidate has FTMO fitness today (audit
`ftmo_fitness_candidates.md`: Q10 admits 0/42, best FUND_SCORE 0.41 vs floor 1.0, the only real
FTMO evidence is a −9.95 % demo that breached the 10 % total-loss limit). Its receipt is the
first entry under the research evidence directory above.

---

## 7. What this programme never does

No gate-threshold or verdict change; no T_Live / AutoTrading / deployment / live-book change; no
FTMO purchase; no verdict write; no evidence/trade-stream deletion; no second SQLite database; no
ML in an EA runtime; no unbounded holdout mining; no LLM-computed metric (all numbers are
deterministic, directive §26); no Strategy Card without a resolvable, sha-verified source. The
pipeline exists to prevent self-deception; research exists to discover edge; the portfolio engine
turns validated edge into money (directive §73).
