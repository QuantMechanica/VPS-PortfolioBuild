# Adversarial review — d1_strategy_eligibility_v2

**Reviewer:** Claude (adversarial, read-only)
**Date:** 2026-09-15
**Slice:** `d1_strategy_eligibility_v2`
**Patch:** `<scratchpad>/patches_d3/d1_strategy_eligibility_v2.patch` (1763 lines, read in full)
**Target base:** `agents/board-advisor` HEAD `1617cb22be`
**Authority:** OWNER-DEC-D3-20260915 (directive 3 §14–§22/§37/§43D/§44), verbatim at
`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`

**Verdict: ACCEPT_WITH_FIXES** — no RED boundary crossed; patch applies clean; tests
independently reproduced. Two follow-ups (one authority-record, one build-path completeness)
should be tracked but are cross-slice/disclosed, not defects in this patch.

---

## Verification performed

| Check | Result |
| --- | --- |
| `git apply --check --binary` vs HEAD `1617cb22be` | **clean, exit 0** |
| Slice tests (`test_strategy_risk_contract` + `test_card_intake_prescreen` + `test_strategy_card_v3`) re-run in the implementer worktree | **59 passed** (independently reproduced, not trusted from summary) |
| Regression sweep (`test_card_r1_internal_source`, `test_dl089_prescreen`, `_retro`, `_derived_prescreen_lanes`, `test_terminal_worker_prescreen_verdict`, `test_p2_prescreen_policy`) | **48 passed, 10 subtests** |
| Vault files exist and are real | doctrine page (5202 B) + Hard Rules annex (22776 B) present on G: |
| Portfolio-layer code references in research doc | all 17 cited files/config exist (no invented references) |
| Quoted risk numbers (`per_sleeve_worst_fraction 0.05`, `venue_daily_loss_limit_pct 5.0`, `maximum_fraction_of_daily_limit 0.8`) | verified against `concentration_tail_limits.v1.json` — **not invented** |
| `EVIDENCE_MISSING` / `NOT_EVALUATED` usage | correct — §19 diversification held as `EVIDENCE_MISSING`; wave-2 engine not claimed built |

## RED-boundary grep — all clear

- **Integrity gates / verdict semantics:** unchanged. Verdict mapping stays `REJECT if reasons else KEEP` (`card_intake_prescreen.py:651`). Only the *reason set* changes (remove style, add contract) — an admission-policy change directly ordered by directive §14/§18/§37, source-of-truth #1. Prescreen is card intake, not a Qxx evidence gate.
- **Economic thresholds without §30 counterfactual:** none. No numeric economic threshold (PF/activity/Sharpe) changed. Removing *style exclusions* is directly mandated by §14, not a numeric-threshold challenge requiring the §30 procedure.
- **T_Live / FTMO / AutoTrading / purchase / live deployment:** untouched; doctrine explicitly excludes them.
- **Sealed artifacts / dated decisions edited in place:** `strategy_card_v3.schema.json` correctly **NOT** edited (its content hash is bound into every sealed card's `contract_bindings.strategy_card_schema_sha256`; editing would invalidate all sealed cards — RED avoided). `EDGE_LAB_CHARTER_2026-05-22.md` and `qb_reputable_source_criteria.md` receive append-only SUPERSEDED/annex banners with historical text retained; neither is an immutable `decisions/DL-*.md` file. No `decisions/` file edited.
- **Farm DB writes:** none.
- **Secrets in docs/vault:** none.
- **Provider grants beyond §5 list:** N/A — slice grants no provider capabilities.
- **Unbounded recovery allowed without a contract:** NO — fail-closed. Tail-amplifying flag without a valid contract → `RISK_CONTRACT_MISSING`; infinite levels / no equity stop → `UNBOUNDED_RECOVERY`. Both verified by tests. `is_unbounded` enforces bounds even if a card mis-declares `tail_amplifying:false`.
- **Scheduler starvation / double-claim:** none — no scheduler touched.

## Correctness notes (confirmed sound)

- `_risk_contract_reasons` logic is correct: unloadable/absent contract → `RISK_CONTRACT_MISSING` (fail-closed); valid-but-unbounded → `UNBOUNDED_RECOVERY`; valid+bounded → no reason. `validate_contract` returning a non-empty error list is truthy → treated as missing (fail-closed), matching the docstring.
- `CardDocument.path` and `_split_scalar_list` (used by the new code) exist in the module.
- Additive card fields are backward-compatible: cards omitting `mechanism_flags`/`risk_contract` validate and hash identically (`_keys_with_optionals` + present-key-only hashing; `test_card_without_optional_fields_still_validates`). `build_card` canonicalizes flag order so authorship order is not load-bearing.
- JSON schema is loaded only to compute its hash (`load_contract_bindings`); it is **not** applied to card instances by any in-repo consumer (the `jsonschema.validate` in `mission_control_v2_data.py` targets an unrelated CONTRACT_SCHEMA). So the deferred schema edit does not break new cards in the live path.
- Positive vs negative pyramiding are distinct tokens; only `negative_pyramiding` is tail-amplifying (§21 honoured). Direction-less "pyramiding" in prose is deliberately not auto-flagged.
- Risk-contract JSON schema carries all twelve §18 fields plus `tail_amplifying`.

## Findings

### Blocking
None.

### Major
1. **Dangling authority record.** `decisions/2026-09-15_owner_max_factory_utilization_eligibility_v2.md` (`OWNER-DEC-D3-20260915`) **does not exist**, yet it is cited as the authority in every new file, the config schema, the vault doctrine page, and the Hard Rules annex. The verbatim directive file exists (so the OWNER instruction is real and evidenced), but the canonical decision record is missing. Mint it (or confirm sibling slice a1 did) and reconcile the id before/at commit so the authority chain is not dangling. Disclosed by the implementer.
2. **Doctrine not yet operational end-to-end for grid/martingale (disclosed, out-of-scope).** Intake now passes a grid/martingale card with a valid contract, but `governed_magic_allocator.py:374` still rejects `prohibited_technique:grid` at build-time magic allocation. Net effect post-merge: such a card passes intake then fails closed downstream at build. This is *safe* (fails closed, no wrong verdict) but means the new eligibility is not fully live until the risk-contract-aware build path is wired (sibling slice). Track as an explicit follow-up so newly-eligible aggressive cards are not silently killed later with a stale style reason.

### Minor
1. **Residual schema gap (disclosed).** `strategy_card_v3.schema.json` (`additionalProperties:false`) is not applied to instances in-repo, so new cards carrying the additive fields validate via the authoritative Python validator; an *external* strict jsonschema pass would reject them. Correctly deferred to a future card-schema version bump (editing the hash-bound schema now is a RED boundary). Low risk.
2. **Stale comment.** `tools/strategy_farm/research/mechanization_check.py:62` says its ML pattern is "kept in sync with `card_intake_prescreen._affirmative_prohibited_mechanics`" — that function was renamed/removed this slice (now `_ml_runtime_reason`). Cosmetic only (mechanization_check owns its own broader ML pattern); not touched by this slice; worth a one-line fix later.

## Conclusion

The patch is clean, deterministic, idempotent (additive/append-only; rollback restores prior
behaviour exactly), honest (no invented numbers, `EVIDENCE_MISSING` where evidence is missing),
and RED-safe (sealed schema untouched, no verdict/integrity/economic-threshold change, no
DB/scheduler/T_Live touch, fail-closed on unbounded risk). Tests reproduced independently.
Accept with the two follow-ups above (mint the decision record; wire the build-path guard in a
sibling slice) tracked.
