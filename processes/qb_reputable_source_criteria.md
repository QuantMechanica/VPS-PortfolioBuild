---
title: QB Reputable Source Criteria — G0 Strategy-Card primary-citation policy
authored_by: Quality-Business
authored_on: 2026-04-28
revised_on: 2026-04-29
revision: 2
parent_issue: QUA-432
status: BINDING (effective 2026-04-29)
binding_signoff:
  ceo: 2026-04-28T13:20:37Z (comment 0d9a3e3c, Q2 resolved)
  owner: 2026-04-29T20:21:39Z (board-UI ACCEPT on confirmation 125b4079, Q1 + Q3 silent-accept of v1 draft)
binds:
  - All G0 Strategy-Card review verdicts from 2026-04-29 forward
  - QB G0 verdict comment line "Author claim: <verifiable | author-claimed | flagged>"
non_retroactive_for:
  - SRC01 Davey 5 cards (CEO interim-APPROVED at QUA-276)
  - Any card already at status APPROVED, IN_BUILD, IN_PIPELINE, or DEPLOYED on 2026-04-29
related:
  - strategy-seeds/sources/SOURCE_QUEUE.md
  - strategy-seeds/cards/_TEMPLATE.md (§ 1 source_citations)
  - paperclip-prompts/quality-business.md (§ G0 review checklist)
---

# QB Reputable Source Criteria

## 1. Purpose

Codify what counts as a **reputable source** for a Strategy Card's primary citation so QB G0 review verdicts are deterministic. Today the G0 checklist line "Source is reputable (not a random forum post)" is judgment-calibrated; this doc converts it to a rule with case-by-case override gates.

This policy is the QB criterion only. CEO retains final approval; QB never unilaterally rejects a card. A REJECTED-on-source verdict from QB is a *proposal* per the QB charter.

## 2. Reputable-source criteria (the rule)

A primary citation (`role: primary` per `_TEMPLATE.md` § 1) is **REPUTABLE** if **all four** of the following hold:

- **R1 — Identifiable author.** A real human / institution is named. "Unknown", "Unbekannt", "Owner", "Telekom", generic forum handles, and bare domain names fail R1.
- **R2 — Verifiable identity.** The author's publishing identity is independently checkable: a named publisher imprint (Wiley, McGraw-Hill, Pearson, Springer, Packt, MIT Press, etc.), a peer-reviewed venue (journal, working paper series, conference proceedings, arXiv, SSRN), an institutional affiliation (university, registered firm, central bank), or a long-running attributed practitioner blog with a real-name author and traceable bibliography.
- **R3 — Mechanical specificity.** The cited section contains crisp, mechanical entry / exit / position-sizing rules — not vibes, not "use your judgment", not "when the trend is strong." Pseudocode-translatable.
- **R4 — Edge-mechanism stated.** The source names *why* the inefficiency exists (microstructure, behavioral, regime, carry, calendar). "It works because the chart says so" fails R4.

A primary citation is **NON-REPUTABLE** if **any one** of R1–R4 fails.

A primary citation is **CONDITIONAL** if R1+R2 hold but R3 or R4 are partially met — e.g., the source has a verifiable author and venue but the rules are loosely specified, or the edge mechanism is implied but not explicitly named. CONDITIONAL cards may proceed if Research adds a `role: supplement` citation that closes the missing gap (a paper that names the mechanism, or an OWNER-confirmed mechanical translation).

### 2a. Concrete examples

| Example | Verdict | Rationale |
|---|---|---|
| Chan, *Quantitative Trading*, Wiley 2008, ch. 4 (pairs) | REPUTABLE | R1 named, R2 Wiley, R3 explicit z-score rules, R4 cointegration / mean-reversion mechanism |
| Davey, *Building Winning Algo Trading Systems*, Wiley 2014, the 3-bar setup | REPUTABLE | R1+R2+R3+R4 all hold |
| Lien, *Day Trading and Swing Trading the Currency Market*, Wiley 2008, "Picking Tops & Bottoms with DBB" | REPUTABLE | R1+R2+R3 hold; R4 thinner — Lien names volatility-band reversion as the mechanism, just briefly |
| Adam Grimes blog, single attributed post with backtest CSV | REPUTABLE | R1 named, R2 verifiable (Wiley 2012 author, real-name blog), R3 specific, R4 stated |
| Galen Woods, *Day Trading with the Anti-Climax Pattern* | REPUTABLE | R1+R2+R3 hold; R4 stated (failed-breakout exhaustion) |
| `pdfcoffee.com forex-momentum-st - UMTB.pdf` | NON-REPUTABLE | R1 fails ("UMTB" non-attributable), R2 fails (pdfcoffee re-host) |
| `Sure-Fire Hedging Strategy - Owner.pdf` | NON-REPUTABLE | R1 fails ("Owner" generic) — even though the strategy is famous; see § 4 famous-but-undocumented |
| Anonymous Forex Factory thread, no author claim, no backtest | NON-REPUTABLE | R1+R2+R4 all fail |
| MQL5 Trading-Systems article by named MetaQuotes author with backtest | CONDITIONAL → REPUTABLE if mechanical rules + mechanism are explicit; CONDITIONAL otherwise |
| arXiv q-fin paper by tenured-faculty author, backtest in paper | REPUTABLE |
| YouTube video, named channel, no transcript-equivalent rules doc | NON-REPUTABLE | R3 fails — video alone is not a deterministic specification |

## 3. Mapping to SOURCE_QUEUE tiers

The SOURCE_QUEUE T-tiers (T1 / T1.5 / T2 / T3) describe *workflow order*, not reputability. The card-template A/B/C/D tiers (`_TEMPLATE.md` § 1) describe *quality* but informally. This section binds a default reputability band to each combination, overrideable case-by-case at QB G0 review.

| Workflow tier | Default reputability band | Override path |
|---|---|---|
| **T1 — Curated OWNER PDFs, card-tier A** (peer-reviewed / known-author primary work) | REPUTABLE by default | Override DOWN to NON-REPUTABLE only if R3 or R4 fails on the cited section (rare; possible for Aldridge / Jansen / Chan-Machine where most chapters are HFT/ML and only fragments are mechanical). |
| **T1 — card-tier B** (credible practitioner with clear authorship) | CONDITIONAL by default | Override UP to REPUTABLE when R1+R2+R3+R4 all hold on the cited section. Override DOWN if R1 or R2 turns out weaker on inspection (e.g., self-published with no traceable bibliography). |
| **T1 — card-tier C** (uncertain authorship / generic / re-hosts) | NON-REPUTABLE by default | Override UP only via § 4 famous-but-undocumented exception path or if Research successfully attributes the source on inspection. |
| **T1.5 — Drive QM V4 archive** | NEVER REPUTABLE as primary (binding rule from SOURCE_QUEUE.md § T1.5 rule 1–2) | The V4 doc is at most `role: supplement`. The upstream book / paper / blog the V4 doc cited is the primary source and is judged on R1–R4. Uncited V4 docs stay `BLOCKED_NO_PRIMARY_SOURCE` per SOURCE_QUEUE. |
| **T2 — Named public containers (MQL5, Adam Grimes, Robot Wealth, MESA, arXiv, SSRN, Forex Factory, Babypips)** | Per-thread / per-post / per-paper, not per-container | Apply R1–R4 to the specific thread / post / paper. Adam Grimes blog defaults REPUTABLE; arXiv / SSRN papers default REPUTABLE; MQL5 articles default CONDITIONAL; Forex Factory / Babypips threads default NON-REPUTABLE unless R1–R4 all clearly hold for that specific thread. |
| **T3 — Open-internet autonomous discovery** | Per-source, applied at survey-pass | Same R1–R4 test on the specific URL. T3 default is NON-REPUTABLE until proven otherwise; Research's tier proposal at survey-pass becomes the QB band. |

**Override discipline.** When QB overrides a band, the verdict comment must cite which Rs hold or fail on the specific cited section, not on the source as a whole. A book that is REPUTABLE on its mean-reversion chapter may be NON-REPUTABLE for the discretionary chapter.

## 4. The "famous-author-but-undocumented-claim" edge case

Some strategies are widely known in retail-trading folklore (Sure-Fire Hedging, "London Breakout", Holy Grail thread strategies, ICT concepts) but the original primary source is anonymous, lost, or non-attributable. Research will inevitably surface these. Two failure modes to avoid:

- **Cargo-cult acceptance** — "everyone trades it, so it must work" → admit a non-falsifiable claim into the build queue.
- **Reflex rejection** — kill the strategy outright and lose what may be a real microstructure edge worth a baseline test.

**QB ruling:** A famous-but-undocumented strategy can enter the pipeline ONLY through one of three paths:

- **Path A — Attributed restatement.** Research finds a *named, verifiable* author who has restated the strategy in a primary work that meets R1–R4 (e.g., Kathy Lien restating the London Breakout with explicit rules in *Day Trading the Currency Market*). Card cites the Lien restatement as primary, the folkloric origin as `role: supplement` with a `quality_tier: C` and a `note: folklore-origin-uncited` field.
- **Path B — OWNER waiver, mechanical specification supplied.** OWNER explicitly waives the reputability requirement for one named card. Card carries `owner_waiver: <issue-id>` in its source block. Research must still supply a deterministic mechanical specification (R3) and a stated edge mechanism (R4) — the waiver only covers R1+R2. The card is automatically tagged `RESEARCH_BASELINE_ONLY` until P1 results justify continuing.
- **Path C — Risk-survey only, NEVER built.** The card is admitted to the archive purely as a *negative-case study* (e.g., "Sure-Fire Hedging — well-known retail martingale-grid; document its sales pitch and structural failure modes for the QM5 risk team"). Status `KILLED_AT_G0_RISK_SURVEY`. Never reaches Development. SOURCE_QUEUE.md § T1 row 35 flags this case explicitly.

Anything outside Paths A / B / C is REJECTED at G0 with reason `unfalsifiable-claim` per the QB verdict format.

## 5. Coupling to the QB G0 verdict format

The QB charter verdict format includes the line:

```
Author claim: <verifiable | author-claimed | flagged>
```

Bind those values to this policy:

- **`verifiable`** — REPUTABLE per § 2 AND the source contains an out-of-sample test, a published backtest with parameter sweep, or independent third-party validation. The strongest claim.
- **`author-claimed`** — REPUTABLE per § 2 but performance numbers are author-self-reported with no out-of-sample evidence cited. Most practitioner books land here. Acceptable; QB notes the band.
- **`flagged`** — CONDITIONAL or NON-REPUTABLE per § 2, OR the author claim itself appears curve-fit (single in-sample window, no robustness test mentioned) regardless of R1–R4. QB recommends REJECTED unless a § 4 path applies.

A `flagged` verdict by itself is not a rejection — CEO retains the call. But a `flagged` line MUST be paired with a recommended verdict (REJECTED or NEEDS_CLARIFICATION); a `flagged` line paired with APPROVED is malformed and QB will not post it.

## 6. Reject reasons cross-reference

The QB charter REJECTED reasons map onto this policy as follows:

| QB REJECTED reason | Triggered by |
|---|---|
| `thin-thesis` | R4 fails — no edge mechanism stated |
| `unfalsifiable-claim` | R3 fails (no mechanical spec) OR famous-but-undocumented outside Paths A/B/C |
| `source-non-reputable` | R1 or R2 fails AND no § 4 path applies |
| `duplicate-archetype` | Independent of source reputability — handled by portfolio-fit step |
| `over-concentration` | Independent of source reputability — handled by portfolio-fit step |

## 7. Boundary statements (what this policy is NOT)

- **NOT retroactive.** SRC01 Davey 5 cards (CEO interim-APPROVED at QUA-276) are out of scope. Any card already APPROVED, IN_BUILD, IN_PIPELINE, or DEPLOYED is out of scope.
- **NOT a content judgment.** A REPUTABLE source can still produce a strategy that fails P0–P9 on its merits. Reputability is a G0 admission gate, not a quality predictor.
- **NOT a Research workflow change.** Research's T1 / T1.5 / T2 / T3 ordering (per SOURCE_QUEUE.md) is unchanged. This policy applies at G0 review, after Research has drafted the card.
- **NOT a CEO-approval substitute.** QB's verdict is one of two required for G0 pass. CEO retains final approval; OWNER overrides both.
- **NOT a prompt edit.** This is a process doc. Updates to `paperclip-prompts/quality-business.md` to reference this doc are a CEO + OWNER decision per the QB charter "Boundaries (NEVER do)" line.

## 8. Acceptance criteria

- [x] CEO posted ACCEPT on QUA-432 confirmation interaction (2026-04-28, comment 0d9a3e3c).
- [x] OWNER posted ACCEPT on QUA-432 confirmation interaction (2026-04-29 board-UI accept on `125b4079`).
- [x] On dual-acceptance: this doc moved from PROPOSED to BINDING; QB applies it on every G0 verdict from 2026-04-29 forward.
- [ ] Any future amendment requires re-confirmation via the same dual-signoff path against the new revision id.

## 9. Decisions log (resolved at binding)

The three open questions parked at v1 are resolved as follows:

- **Q1 (OWNER, silent-accept of v1 draft).** T1.5 V4-archive docs remain `NEVER REPUTABLE as primary` per the SOURCE_QUEUE rule. No "fully-traceable upstream" carve-out. The original book / paper / blog the V4 doc cited is the primary; the V4 doc is at most `role: supplement`. Uncited V4 docs stay `BLOCKED_NO_PRIMARY_SOURCE` per SOURCE_QUEUE.md § T1.5 rule 3.
- **Q2 (CEO, comment 0d9a3e3c).** QB at G0 stays at `verifiable | author-claimed | flagged` granularity. QB does not compute, replicate, or audit pipeline-side statistics at G0 — that is strictly QT's lane at P7. Reasoning: (1) lane discipline (G0 is source-admission, P7 is empirical adjudication; double-coverage produces duplicate verdicts and slow back-and-forth); (2) latency (G0 must run in minutes per card); (3) information asymmetry (catching curve-fit in *our* backtest needs *our* data and *our* P-stack — QT's lane). The § 5 "curve-fit on the face of the source itself" provision is the only stat-shaped sniff QB does at G0 — visible red flags (single-pair, no out-of-sample, no parameter sweep, no trade-count). A `flagged` author-claim line is not a rejection on its own; CEO retains the call when a clean P7 result later rebuts it.
- **Q3 (OWNER, silent-accept of v1 draft).** Path B "OWNER waiver" stays at **per-card** scope. Each waived card carries its own `owner_waiver: <issue-id>` field in the source block; one waiver does not extend to other cards from the same folklore origin. The `RESEARCH_BASELINE_ONLY` tag attaches automatically to any waived card until P1 results justify continuing.

## 10. Amendment process

Any change to §§ 2–6 of this policy requires a fresh dual-signoff cycle:

1. QB drafts the proposed revision in this file with revision number bumped.
2. PUT the revision to the QUA-432 issue document (or the supersessor issue if QUA-432 is closed); capture the new `revisionId`.
3. Open a fresh `request_confirmation` interaction with `idempotencyKey: confirmation:<issueId>:qb_reputable_source_criteria:<newRevisionId>` and `target.revisionId` pointing at the new revision.
4. CEO (comment) + OWNER (board-UI accept) both required. Until both accept, the *previous* binding revision stays in force; QB does not pre-apply the proposed change.
5. On dual-accept, append a new entry to § 9 Decisions log with the resolution and the new effective date.

§ 7 boundary statements and § 9 historical entries are append-only — they record signoff facts, not negotiable text.

---

*Source: QB charter § "Strategy Card review checklist" + § "G0 review verdict format"; QUA-432 dispatch; SOURCE_QUEUE.md tier system; `_TEMPLATE.md` § 1 source-citation block.*
