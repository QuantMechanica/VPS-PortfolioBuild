---
title: QB Monthly Business Review — Template
owner: Quality-Business
last-updated: 2026-04-28
authored-by: QUA-433 (Quality-Business 2)
parent-directive: QUA-429 (CEO hire dispatch); paperclip-prompts/quality-business.md § "First Issues on Spawn" #3
status: DRAFT — pending CEO + OWNER signoff
---

# QB Monthly Business Review — Template

The Quality-Business agent posts one of these on the **first Monday of every calendar month** to OWNER + Board, under a parent issue tagged `qb-monthly-YYYY-MM`. Cadence is set in `paperclip-prompts/quality-business.md` (system prompt) and the QB charter (`AGENTS.md` § "Monthly business review").

The review is a **portfolio-fit and pipeline-health snapshot**, not a P&L report. It exists so that OWNER and Board can see, in one read, whether the V5 portfolio is on a defensible trajectory and where the company's strategic risks sit this month. P&L belongs to Controlling; technical / pipeline depth belongs to Quality-Tech and Pipeline-Operator. QB's lens is **business angle and portfolio shape**.

> **First scheduled review:** 2026-05-04 (Mon, first Monday of May 2026). On 2026-05-04 V5 has zero live EAs, so § 1 (DarwinexZero) and any "live portfolio" section will explicitly read **N/A — pre-deploy**; the funnel and archive-growth sections carry the report.

---

## Cadence and posting protocol

- **When:** First Monday of each calendar month, posted before EOD local time.
- **Where:** New issue under `goal-project: Quality-Business / Monthly Review`, titled `QB Monthly Business Review — YYYY-MM`, tagged `qb-monthly-YYYY-MM`.
- **Audience:** OWNER (primary), Board (CEO + CTO + heads of Research, Quality-Tech, Pipeline-Operator). Post comment links to OWNER's Notion mirror via Documentation-KM if the mirror is live.
- **Length budget:** 600–1200 words of body + tables. Anything longer should be split into a child issue with the headline number kept in the parent.
- **Tone:** Strategic, portfolio-minded, business-literate. Cite numbers. English only.
- **Final action of every review:** Post the next month's parent issue stub (`qb-monthly-YYYY-MM` for the following month) so the cadence is self-perpetuating.

---

## Required sections

The review **must** contain the six numbered sections below in order. Sections may be marked `N/A — <reason>` when the underlying data does not yet exist (e.g., pre-deploy DZ section in 2026-05), but the heading and rationale must remain so the reader sees explicitly that QB checked.

### 1. DarwinexZero signal quality (live portfolio)

| Field | Value | Source |
|---|---|---|
| Live EAs on DZ | `<n>` | `framework/registry/ea_id_registry.csv` filtered `status=deployed`, cross-checked against the DZ public profile snapshot |
| Aggregate D-Score | `<value>` | DarwinexZero public profile (latest export) |
| 6-month equity-curve correlation matrix (worst pair) | `<pair, value>` | Pipeline-Operator monthly correlation export |
| New strategies onboarded this month | `<n>` | `framework/registry/ea_id_registry.csv` filtered `created_at` within month |
| Investor-DD red flags | bullets, or "none flagged this month" | QB judgment + DZ comments / messages export |

**Verdict line:** one sentence — `DZ track record this month was <healthy / mixed / degraded> because <one reason>. Investor-DD risk: <low / medium / high>.`

> **Pre-deploy clause:** Until the first EA passes P9 to live, this section reads `N/A — V5 pre-deploy. First live candidate ETA: <issue ref>` and links the highest-priority P9-bound EA's parent issue.

### 2. Portfolio shape — timeframe / market / style distribution

For every EA in the *active candidate pool* (status `IN_PIPELINE`, `IN_BUILD`, or `DEPLOYED` per the strategy card), tabulate:

| Bucket | Count | % of pool | QB cap | Status |
|---|---|---|---|---|
| Timeframe — M15 | | | ≤ 30 % | OK / WARN / BREACH |
| Timeframe — H1 | | | ≤ 30 % | |
| Timeframe — H4 | | | ≤ 30 % | |
| Timeframe — D1 | | | ≤ 30 % | |
| Market — forex | | | ≤ 40 % | |
| Market — indices | | | ≤ 40 % | |
| Market — commodities | | | ≤ 40 % | |
| Market — crypto | | | ≤ 40 % | |
| Style — trend-following | | | ≤ 50 % | |
| Style — mean-revert | | | ≤ 50 % | |
| Style — breakout | | | ≤ 50 % | |
| Style — news / event | | | ≤ 50 % | |

Caps come from `paperclip-prompts/quality-business.md` § "Portfolio Fit Metrics" and the QB charter. Map each card's `strategy_type_flags` (per `strategy-seeds/strategy_type_flags.md`) into the four headline styles using a stable rubric maintained alongside this template (proposed: `qb_style_rollup.md`, child of the first OWNER-signed-off review). A flag-to-style mapping that is ambiguous on first encounter is flagged as a **strategic risk** in § 5 and routed back to Research for clarification on the card.

**Verdict line:** `<n> caps in OK, <n> in WARN (≥ 80 % of cap), <n> in BREACH. Action: <none / re-balance research queue / pause new builds in <bucket>>.`

### 3. Candidate funnel — top 5 EAs not yet live

Single table, ordered by **closest-to-live first**.

| Rank | EA / slug | strategy_id | Current phase | Next gate owner | Days in current phase | Readiness (R/A/G) | Blocker (if any) |
|---|---|---|---|---|---|---|---|
| 1 | | | P? | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |
| 5 | | | | | | | |

- **Phase reference:** `processes/01-ea-lifecycle.md` (P0–P9 / T-tiers).
- **Readiness rubric:**
  - **G** (green) — at next gate, no open evidence asks, owner claimed.
  - **A** (amber) — at next gate, ≥ 1 open evidence ask **or** in same phase ≥ 14 days.
  - **R** (red) — blocked, evidence ask unanswered ≥ 7 days, or phase aged ≥ 30 days.
- **Sources:** `framework/registry/ea_id_registry.csv` for slug → strategy_id; the EA's parent / phase issues for current phase + phase-age; QB's own G0 / P2 / P9 verdict comments for evidence-ask state.

**Verdict line:** `Funnel health: <healthy / thin / clogged>. Bottleneck: <phase | none>. Recommended OWNER ask: <e.g., authorise extra Pipeline-Operator capacity, kill stalled card, none>.`

### 4. Strategy Archive growth

| Metric | Value | Source |
|---|---|---|
| Strategy cards total | `<n>` | `ls strategy-seeds/cards/*_card.md \| wc -l` |
| Cards added this month | `<n>` | `git log --since=<first day of month> --diff-filter=A --name-only -- strategy-seeds/cards/` |
| Sources (SRC0N) processed total | `<n>` | `ls strategy-seeds/sources/SRC*` |
| Sources opened this month | `<n>` | `git log --since=<first day of month> --diff-filter=A --name-only -- strategy-seeds/sources/SRC*/source.md` |
| G0 verdicts posted this month (APPROVED / REJECTED / NEEDS_CLARIFICATION) | `<a> / <r> / <c>` | QB G0 verdict comments (search by `APPROVED|REJECTED|NEEDS_CLARIFICATION` template lines on cards' G0 issues) |
| Public archive entries | `<n>` | `public-data/strategy-archive.json` `.total` |

**Verdict line:** `Archive grew by <n> cards (<delta>) from <k> sources this month. G0 throughput: <fast / steady / slow>.`

### 5. Strategic risks flagged

A short, prioritised bullet list of **portfolio-level** risks the company should watch this month. Each bullet must follow the shape:

> **<risk name>** — *<one-line description>*. **Severity:** low / medium / high. **Evidence:** <metric or count from §§ 1–4 or a card / issue ref>. **Recommendation:** <one concrete action and owner>.

Recurring risk archetypes QB checks for every month (do not omit a heading even if `N/A this month` — silence is itself a signal):

1. **Over-concentration** — any single timeframe / market / style exceeding its cap (or trending toward it: ≥ 80 % of cap).
2. **Source-author dependency** — > 30 % of approved cards trace to a single author/book/source. Mitigation: prioritise unrelated source extraction in next month's Research queue.
3. **Archetype saturation** — ≥ 3 approved cards converging on a single `strategy_type_flags` cluster (e.g., five donchian-breakout cards). Risks pairwise-correlation > 0.7 cap on equity curves.
4. **Source-quality drift** — share of `quality_tier: C` (forum / unknown) source citations on approved cards > 20 %.
5. **Funnel stagnation** — > 50 % of candidate EAs aged in the same pipeline phase ≥ 30 days, or zero new IN_BUILD cards this month.
6. **DZ investor-DD risk** — only meaningful post-deploy: any live EA with a public-explanation gap (e.g., unexplained drawdown, parameter change without rationale).

### 6. Calls for OWNER / Board

Maximum three asks. Each ask names the requester (always QB), the decision needed, the due-by date, and the cost of inaction.

| Ask | Decision needed | Due by | Cost of inaction |
|---|---|---|---|
| | | | |

If QB has no asks this month, write: `No OWNER / Board decisions requested this month.`

---

## Data sources — index

Every monthly review pulls from the following authoritative locations. If a source moves, this index is updated with the review.

| Section | Primary source | Secondary / cross-check |
|---|---|---|
| § 1 DZ | DarwinexZero public profile export (manual snapshot link) | `framework/registry/ea_id_registry.csv` (status=deployed); Pipeline-Operator monthly correlation export |
| § 2 Portfolio shape | Each card's YAML header (`markets`, `timeframes`, `strategy_type_flags`) under `strategy-seeds/cards/*_card.md` | `framework/registry/ea_id_registry.csv` for active set |
| § 3 Candidate funnel | EA parent issue + current phase issue (Paperclip API) | `framework/registry/ea_id_registry.csv`; QB's own G0 / P2 / P9 verdict comments |
| § 4 Strategy Archive | `strategy-seeds/cards/`, `strategy-seeds/sources/`, `public-data/strategy-archive.json` | `git log` over the calendar month |
| § 5 Strategic risks | Aggregated across §§ 1–4 + QB's own monthly G0 review log | Research's open-card backlog; CEO's PASS / REJECT log |
| § 6 OWNER asks | QB judgment | — |

> **Dedup index.** Until a formal `dedup_index` artifact exists, near-duplicate detection is performed by QB at G0 against `strategy-seeds/cards/*_card.md` headers (`strategy_type_flags` + `markets` + `timeframes` overlap). When Research delivers the dedup index promised in `processes/13-strategy-research.md`, this row is updated to point at it.

---

## Recurring routine proposal

QB will not auto-fire this review without OWNER signoff. Once the template is accepted, QB proposes a Paperclip routine of the following shape:

```yaml
routine:
  name: qb-monthly-business-review
  owner: Quality-Business
  schedule: cron "0 9 1-7 * MON"  # 09:00 local on the first Monday of each month
  action: open issue "QB Monthly Business Review — {{YYYY-MM}}" tagged "qb-monthly-{{YYYY-MM}}"
            assigned to Quality-Business, status: in_progress, parent: project Quality-Business / Monthly Review
  on-firing: wake Quality-Business with the issue id; QB fills the template and posts; on completion, marks issue done and opens next-month stub
```

First firing target: **2026-05-04 09:00 local**. Routine creation is gated on CEO accept of this template (see request_confirmation interaction on QUA-433). T6 boundary: this routine never touches live deploy or `.DWX` artifacts; it is read-only on the registry and on cards.

---

## Out of scope (so the review stays QB-shaped)

- **P&L, drawdown, equity curve numbers** — Controlling. QB cites these only when they signal an investor-DD or portfolio-shape risk.
- **Statistical depth (PBO, OOS, parameter robustness)** — Quality-Tech at P7. QB cites only the verdict, not the methodology.
- **Pipeline operations (queue depth, .DWX runs, MT5 health)** — Pipeline-Operator. QB cites only the candidate-funnel age signal.
- **Hire / fire / prompt edits** — CEO + OWNER. QB never proposes org changes inside the review.
- **T6 anything** — OFF LIMITS. The review is read-only on live deploy state.

---

## Change log

- 2026-04-28 — DRAFT v1 — QB2 initial draft under QUA-433. Awaiting CEO + OWNER signoff via `request_confirmation` interaction on QUA-433.
