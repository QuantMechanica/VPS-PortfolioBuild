# Campaign receipt — CAMP-2026-0001-ftmo-gap (first Kimi research campaign)

**Directive:** OWNER-DEC-CBE-20260915 §47 (FTMO gap = major Kimi mission), §68 PHASE G, §69
(`first Kimi research campaign receipt`); follow-up §16 (Kimi must actually run). **Date:**
2026-09-15. **Slice:** `g1_edge_discovery_campaign`.

**Status: COMPLETE — a real campaign ran end-to-end.** Kimi executed a live 15.5-minute research
call on QuantMechanica's own OBSERVE evidence, produced a durable hash-verified artifact, was
criticised cross-provider, and was sealed. It created one mechanizable hypothesis **and** durable
negative findings.

## Durable artifacts
| Artifact | Path |
|---|---|
| QM-RESEARCH source (sealed, author Kimi) | `strategy-seeds/sources/QM-RESEARCH-2026-0001/` (repo) |
| Kimi full answer | this dir `CAMP-2026-0001/kimi_answer.md` (+ `D:/QM/research/campaigns/CAMP-2026-0001-ftmo-gap/kimi_answer.md`) |
| Cross-vendor critique | `CAMP-2026-0001/critique_claude.md` |
| OBSERVE dataset (read-only, content-addressed) | `D:/QM/research/campaigns/CAMP-2026-0001-ftmo-gap/observe/2026-09-15T14-12-39Z/` (manifest `dataset_id 4deb0c21…`) |
| Deterministic OBSERVE summary | `CAMP-2026-0001/observe_summary.json` |
| Preregistration (H1–H3, immutable) | `D:/QM/research/campaigns/CAMP-2026-0001-ftmo-gap/preregistration/` |
| Campaign manifest (Mission-Control / read-model) | `CAMP-2026-0001/campaign.json` |
| Phase-1 / phase-2 run records | `CAMP-2026-0001/campaign_run.json`, `campaign_finalize.json` |
| Research-state read-model | `D:/QM/reports/state/research_state.json` |
| Experiment memory (LEARN) | `D:/QM/reports/state/experiment_memory_ledger.jsonl` (4 rows: H1/H2/H3 + negative finding) |
| Search-history ledger (data-snooping) | `D:/QM/reports/state/search_history_ledger.jsonl` (3 preregistered families) |

## What was asked (directive §47)
"What type of mechanical edge is our FTMO book missing?" Kimi received a deterministic OBSERVE
projection of the farm's own evidence (149,166 gate rows / 53,722 strategy-classified;
INFRA/setup/NO_REPORT kept separate from economic failures) + a computed summary, and was asked
for: (1) evidence-backed verdicts on the three preregistered hypotheses H1–H3
(`audit/ftmo_fitness_candidates.md`), (2) at least one mechanizable high-density / short-holding /
low-swap FTMO edge grounded in the data (not indicator soup, §40), (3) explicit negative findings.

## What Kimi answered (summary — full text in `kimi_answer.md`)
- **H1** (intraday session-flat beats swing for FTMO): **INCONCLUSIVE.** The preregistered
  refutation test (worst-day / wdd_p90 / first-passage) is **not runnable** on this projection
  (no such fields). The testable proxy shows intraday beats swing by only +0.85 pp (0.516 vs
  0.508) while multi-day *position* beats both (0.557) and *scalp* is worst (0.399) — no monotone
  "shorter ⇒ better".
- **H2** (density, not edge, binds FTMO): **REFUTED-in-proxy.** Only 9.5 % of scored rows are
  below the activity floor (mean 373 trades/yr); higher trade count is associated with *lower*
  pass (50.6 % vs 54.2 %), while expectancy dominates (PF≥1 → 68.8 % vs PF<1 → 27.7 %).
- **H3** (a bounded no-trade filter on a shared loser regime): **NOT ESTABLISHED.** 96.5 % of
  rows are `session=unspecified`, so the posited time-of-day condition cannot be mined here; naive
  session tagging is not edge (`session=open` passes 44.4 % < population).
- **Mechanizable candidate H-CW** ("cash-window index continuation, session-flat"): NDX/GDAXI/SP500
  index CFDs, H1 signal, entries only 13:30–16:30 UTC, hard flat by 20:30, no weekend carry, ATR
  stop, −1 %/day and −2 %/week circuit breakers, finite ≤432-combo parameter grid, 5 preregistered
  kill criteria. Grounded in the farm's own 9-of-10 Q10 index-intraday pass record and in the
  mechanical removal of the overnight/swap tail that breached the demo.

## Mechanization (directive §51)
H1, H2, H3 hypothesis cards all PASS `mechanization_check` (0 findings; H1 & H3 are the mechanizable
mechanical specs, H2 is an analytical diagnostic). Codex-implementable = true.

## Cross-vendor critique (directive §52) — critic verdict **REVISE**
- **Creator = Kimi**; **critic = Claude / Fable** (Opus 4.8, this orchestrator session), read-only.
  `cross_vendor = true` (kimi ≠ claude → §52 "Kimi creator's critic must not be Kimi" satisfied).
- The automated `agent_chain.run_chain` was **attempted and gated**: all three non-Kimi critic
  seats were quota-blocked (`claude_disabled_flag`, `codex_low_tokens_flag`, `agy_low_quota_flag`
  present 2026-09-15). Per the slice fallback, the orchestrator (a different vendor than the Kimi
  creator) performed the read-only critique inline. `critic_fallback_used = true`; this is recorded
  honestly in `critic_receipt.json` and `campaign.json`. No verdict/gate/repo write was made by the
  critique.
- Verdict **REVISE** (0 blocking / 3 major / 3 minor): MAJOR-1 post-selection on n≈10 Q10 index rows
  (DXZ-scoped, not FTMO first-passage; SP500 has no Q10 evidence); MAJOR-2 simpler null (index
  intraday continuation ≈ 2015–2024 index up-trend — needs regime-split OOS + long/short symmetry);
  MAJOR-3 cost/spread sensitivity asserted not evidenced. Full text: `critique_claude.md`.

## Sealed? YES
Verdict REVISE ≠ REJECT → the artifact was **sealed** (`status: reviewed`,
`sha256 e2c72cf9…`). `research_source.verify` returns **ok=true, reasons=[]** — the artifact passes
the fail-closed internal-source intake contract (author authorized, manifest + numeric provenance
verified, cross-vendor non-Kimi critic present). It is a valid R1 source for a future card, subject
to the REVISE conditions before Q00.

## Hypotheses that survived / were refuted / were falsified
- **Survived → progress:** H-CW (mechanizable, preregistered, conditional on MAJOR-1..3).
- **Refuted-in-proxy:** H2 (activity is not the binding FTMO constraint; expectancy/quality is).
- **Inconclusive (untestable on this projection):** H1, H3.

## What the failures taught (durable negative finding)
The proven inventory's swing profile (D1/H1/H4, low density, overnight/swap tail) is structurally
the **opposite** of the FTMO-fit profile; **adding more swing cousins cannot close the FTMO gap.**
An FTMO edge must come from a higher-density, session-flat, low-swap intraday direction with hard
exits and a bounded daily-loss breaker — not from more trades on the same edge (density is not the
scarce resource) and not from naive session tagging. Recorded in `experiment_memory_ledger.jsonl`
as a `NEGATIVE_FINDING`.

## Infrastructure lesson (feeds the programme, not this card)
Two of three preregistered hypotheses were **untestable** because the OBSERVE projection lacks
worst-day-loss, wdd_p90, per-trade streams and FTMO first-passage outputs, and 96.5 % of rows are
`session=unspecified` (a registry default, not measured exposure). Next FTMO-gap campaigns need an
OBSERVE extension joining the sleeve-stream / first-passage engines and a session field derived from
execution time-of-day, or hypotheses framed against fields the projection actually carries.

## Next experiment
1. Progress H-CW to a Strategy Card conditional on MAJOR-1..3: earn its own per-symbol Q02→Q10
   evidence; regime-split OOS (bear/range) + long/short symmetry; a cost-fidelity pass on index
   spreads before any FTMO recommendation.
2. Extend `observe_projector` with FTMO-specific fields (worst-day, wdd_p90, per-trade, first-
   passage join) so H1/H3 become testable.
3. Re-run the cross-vendor critique through a *spawned* non-Kimi seat once a critic lane is off
   quota-hold, to corroborate the inline REVISE.

## Quota consumed (directive §72 KIMI block)
- Kimi governor state: **NORMAL**, `usage_source = managed_usage_endpoint`,
  `quota_fetch_status = ok` (the campaign's live call refreshed the OAuth token so real telemetry
  now works — before the call the fetch returned `auth_error → local_ledger_fallback`).
- Ledger call count before: day 2 / week 2. After: the campaign added 1 real research call (932 s)
  + preflight; governor `status` after: NORMAL (well under the 120/day, 600/week runaway guard).
- Real subscription (Allegro plan): 5h and 7d used-ratios ~0.0 at fetch time — ample headroom, no
  reason to conserve.

## Provenance / integrity
`sha256(source.md) = e2c72cf9fd430a8639531199e15758897f9e4dd5aace0a77c12cd417d28950cf`; every
quantitative claim resolves to a computed-output file (`h1_result.json` / `h2_result.json` /
`h3_result.json`) hashed in the artifact's `qm-source-manifest` block and derived deterministically
from the OBSERVE dataset — no figure is LLM-computed (directive §26). The pipeline (Q00–Q17) remains
the final judge.
