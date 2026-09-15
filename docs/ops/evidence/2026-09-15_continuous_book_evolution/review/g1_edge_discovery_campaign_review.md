# Adversarial review — slice `g1_edge_discovery_campaign`

**Reviewer:** Claude/Fable (adversarial reviewer seat), 2026-09-15. **Read-only** except this file.
**Patch:** `scratchpad/patches_defg/g1_edge_discovery_campaign.patch` (3891 lines, 29 files).
**Base HEAD:** `4ad7ab7016` (branch `agents/board-advisor`). **Verdict: ACCEPT_WITH_FIXES.**
No blocking issues; no RED boundary crossed. Two major follow-ups (artifact/card coherence),
several minors.

## What I verified with my own commands

| Check | Result |
|---|---|
| `git apply --check` against HEAD `4ad7ab70` | **clean, exit 0** |
| Slice tests (`test_research_observe_projector.py`, `test_research_campaign.py`, `test_research_ledgers.py`) run in the implementer worktree | **27 passed in 2.57s** |
| `research_source.verify('QM-RESEARCH-2026-0001')` | **ok=True, reasons=[], sha256 `e2c72cf9…`** — matches the committed `campaign_finalize.json`; the seal is genuine and reproducible |
| `mechanization_check.check_spec` on the 3 committed cards | H1/H2/H3 all **PASS**, `codex_implementable=True` |
| Runtime read-model `D:/QM/reports/state/research_state.json` | present, schema `qm.research-state/v1`, contract-compliant, **honest** (real Kimi quota folded: `usage_source=managed_usage_endpoint`, plan Allegro, rolling ratios 0.0) |
| Committed `kimi_answer.md` vs live `D:/QM/research/campaigns/.../kimi_answer.md` | **identical** — the committed answer is the real Kimi output, not fabricated |
| OBSERVE DB open path (`work_item_clean_view.open_clean_view_connection`) | **read-only** (`?mode=ro` URI + `PRAGMA query_only=ON`, fail-closed assertion) — the projection cannot write the farm DB |
| RED-touch grep on added lines | none (see below) |

## Task coverage (all four parts delivered)

1. **Charter** `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` — covers the loop (§43), OBSERVE with
   INFRA/economic separation (§44), failure mining (§45), white-space (§46), FTMO gap (§47/§48),
   valid origins (§39), anti-random-indicator (§40), ML policy (§41/§42), mechanization gate (§51),
   cross-vendor attack (§52), preregistration/data-snooping (§53), experiment memory (§54),
   external-vs-internal ROI with the harvest-funnel numbers (§49, honestly flagged as a measured GAP),
   provider roles, campaign lifecycle and receipt locations. Solid.
2. **First campaign ran for real** — CAMP-2026-0001-ftmo-gap: a live 932 s Kimi call (cli 0.43.1) on
   the farm's own OBSERVE projection (149,166 gate rows), preregistration before the call, deterministic
   numeric provenance, cross-vendor critique (creator Kimi / critic Claude), sealed (REVISE≠REJECT),
   experiment memory + search-history recorded, receipt written. Honest negative finding produced.
3. **`research_state_readmodel.py`** — deterministic generator; contract-compliant; tolerates all inputs
   absent (EVIDENCE_MISSING/UNKNOWN/None); folds real Kimi quota. Verified on disk.
4. **Tests** — new projector fields; read-model from fixtures; runtime-ML card fails mechanization while
   an ML-provenance card passes; creator/critic separation on receipt data. All present and green.

## RED / safety (no crossing)

- **No farm-DB write.** OBSERVE opens `mode=ro`+`query_only`. The only `INSERT INTO` in the patch is in
  the test fixture `_research_fixtures.py` (a throwaway tmp DB). Drivers write only under
  `D:/QM/research/`, `D:/QM/reports/state/`, and the repo source store.
- **No gate/threshold/verdict change.** The charter and code repeatedly state "the pipeline Q00–Q17 is
  the judge"; no gate manifest, qualification predicate, or verdict path is touched.
- **No T_Live / AutoTrading / FTMO purchase / live deployment.** The many `T_Live`/`AutoTrading` strings
  in the patch are (a) prose disclaimers of what was NOT touched, and (b) the Kimi guard's
  `changed_paths` false-positive list (live-factory state files churning concurrently — reads, not writes;
  none in the campaign out_dir). Documented honestly as a known guard false-positive under a running factory.
- **No secrets.** The OAuth-token refresh is a side-effect of the Kimi call (documented, never logged);
  no credential is committed. `_CRYPTO_TOKENS` is a symbol-classification tuple, not a secret.
- **Shared read-model schemas respected** — `research_state.json` matches `qm.research-state/v1` exactly
  (extra `schema`/`counts` keys are additive). New contracts (`qm.research-campaign/v1`,
  `qm.observe-summary/v1`, extended `qm.research-dataset/v1`) are back-compatible.
- Dated supersession markers and English-only comments: clean.

## MAJOR (follow-ups, not apply-blockers)

**MAJOR-1 — the three "mechanized Strategy Cards" share one boilerplate body.**
`campaign_lib.build_hypothesis_card` renders identical z-score intraday mean-reversion mechanics
(Price signature / Long+Short entry / Exit / Filters / Structural-cause tail sentence) into all three
cards, substituting only title, claim and parameter ranges. Consequences:
- `H2_card.md` is titled "Trade density, not per-trade edge, is the binding FTMO constraint" yet carries
  mean-reversion entry/exit rules unrelated to density — and H2 is itself declared `mechanizable=False`
  / "analytical (non-tradeable) diagnostic", so a full mechanical card should arguably not be emitted for it.
- `H3_card.md` ("no-trade filter for a daily-loss cluster") likewise contains z-score entry logic rather
  than a filter overlay.
- Every card's `## Structural cause` ends with the hardcoded "…a session/liquidity effect (mean reversion
  inside a bounded trading window)…", which is false for H2 and H3.
`mechanization_check` passes them because it verifies section presence + absence of ML terms, not semantic
coherence. Not RED and the pipeline is the judge, but a reader/OWNER opening `H2_card.md` would be misled.
*Fix:* distinct mechanics per hypothesis, or don't emit a mechanical card for the analytical H2.

**MAJOR-2 — the campaign's actual headline candidate (H-CW) has no card in the sealed artifact.**
The receipt, `kimi_answer.md` and `critique_claude.md` all center on **H-CW** ("cash-window index
continuation, session-flat", NDX/GDAXI/SP500, H1) as the one mechanizable, evidence-grounded FTMO edge
that "survived → progress". But the sealed artifact's mechanized cards are the preregistered priors H1/H3,
whose mechanics (FX/gold z-score mean reversion, M15, symbols EURUSD/XAUUSD/GBPUSD/USDJPY) are a
*different strategy* from H-CW (index breakout continuation). So the durable mechanical spec does not match
the deliverable's own conclusion. The §(2)/§47 requirement ("at least one mechanizable hypothesis for a
high-density/short-holding/low-swap FTMO edge grounded in OBSERVE") is met in *prose* (H-CW) but the
hash-sealed cards advertise the wrong candidate. *Fix:* mint an H-CW card (index CFDs, session window,
ATR breakout, −1%/day breaker) and preregister it before its validation, per the critique's own disposition.

## MINOR

- **MINOR-1** `research.json` `candidate_edge` / `proposed_mechanism` describe H1 (intraday mean-reversion),
  not H-CW — the machine-readable artifact advertises the wrong candidate to downstream consumers (ties to MAJOR-2).
- **MINOR-2** H1/H3 card `## Symbols` = FX majors + gold, exactly the profile the campaign's own negative
  finding says is wrong; the mechanizable direction (H-CW) is index CFDs. The card symbol set contradicts
  the conclusion.
- **MINOR-3** `lineage.json` in the sealed artifact is a stub (`discovery_sample.dataset_ids=[]`,
  `instruments=[]`, `period=""`, `preregistration:null`, `mechanization.codex_implementable:false`,
  `spec_section:""`) even though preregistration records, a dataset id, and passing mechanization all exist.
  `verify` passes because it hashes files, not lineage completeness — so the §53 anti-data-snooping
  provenance backbone the charter emphasizes is present as a placeholder, not populated. Populate it.
- **MINOR-4** The cross-vendor critic was the orchestrator (Claude/Fable) inline, not a spawned headless
  seat (all three non-Kimi lanes were quota-gated). Directive §52 (critic vendor ≠ creator vendor) is
  satisfied and the fallback is disclosed honestly (`critic_fallback_used=true`, `cross_vendor=true`), and
  the slice lists re-running through a spawned seat as a next-experiment. Weaker independence than a spawned
  seat; already flagged — leaving as a note.
- **MINOR-5** `campaign_lib.assemble_campaign_manifest` always enumerates `FTMO_GAP_HYPOTHESES` for the
  manifest `hypotheses` list; the name is generic but the body is FTMO-gap-specific. Harmless for this
  single campaign; refactor before a second programme reuses it.

## Bottom line

A genuinely complete, honest slice: it stood up the edge-discovery programme, ran the first Kimi campaign
end-to-end for real, produced a durable hash-verified + sealed artifact, a real cross-vendor critique, and
a substantive negative finding, all deterministic and read-only against the farm DB, with real Kimi quota
telemetry now flowing. The gaps are coherence between the campaign's headline candidate (H-CW) and the
mechanical cards/`research.json` actually sealed (MAJOR-1/2, MINOR-1/2), plus an unpopulated lineage stub
(MINOR-3). None blocks apply; all are card/artifact-content follow-ups the pipeline gate would catch before
any EA is built. **ACCEPT_WITH_FIXES.**
