# CAMP-2026-0001 follow-up receipt — QM-RESEARCH-2026-0002 (H-CW)

Generated 2026-09-15T15:20:04+00:00 by `tools/strategy_farm/research/finalize_ftmo_gap_campaign_v2.py`.
Authority: OWNER-DEC-CBE-20260915 (G1 review MAJOR-1+2). Slice `x2_wave2_followups`.

## Why a successor (not an edit)
The sealed parent `QM-RESEARCH-2026-0001` carried boilerplate mechanized H1/H2/H3 cards and NO
card for the campaign's actual surviving candidate H-CW. A sealed QM-RESEARCH artifact
is immutable; a correction is a NEW version with lineage, never an in-place edit. This
mints `QM-RESEARCH-2026-0002` with `parent_version_id=QM-RESEARCH-2026-0001`.

## What the successor contains
- **H-CW** — the real mechanizable candidate (cash-window index continuation, session-
  flat, NDX/GDAXI/SP500 H1) with full long/short entry, no-trade, exit, stop, take-
  profit, session rules, filters, bounded parameter ranges, timeframe, symbols, expected
  frequency, invalidation and kill criteria — authored from the campaign kimi_answer +
  critique.
- **H1/H2/H3** — rewritten truthfully as FINDINGS (H1 inconclusive, H2 analytical/non-
  mechanizable, H3 not established), not boilerplate mechanized cards.

## Mechanization check per card
- `H-CW`: **PASS** (codex_implementable=True).
- `H1`: **RETURN_TO_RESEARCH** (codex_implementable=False).
- `H2`: **RETURN_TO_RESEARCH** (codex_implementable=False).
- `H3`: **RETURN_TO_RESEARCH** (codex_implementable=False).

H-CW PASS (a real mechanizable candidate); the three findings RETURN_TO_RESEARCH — the
honest outcome for a finding rather than a candidate.

## Cross-vendor critique
- Attempt status: `gated` (reason `no critic seat available for creator vendor 'kimi': [{'seat': 'claude:sonnet', 'skipped': 'claude_disabled_flag', 'routing_reason': 'claude_disabled_flag'}, {'seat': 'codex:terra/medium', 'skipped': 'codex_low_tokens_flag', 'routing_reason': 'codex_low_tokens_flag'}, {'seat': 'agy:default', 'skipped': 'agy_low_quota_flag', 'routing_reason': 'agy_low_quota_flag'}]`).
- Critic: `claude` · verdict `REVISE` · cross_vendor `True`.
- When the automated agent_chain lanes are quota-gated, Fable (a non-Kimi vendor)
  performs the read-only inline critique; because Fable co-authored the mechanization,
  this is partial corroboration and a spawned independent non-Kimi seat remains a next-
  experiment item (recorded honestly in critic_receipt.json).

## Seal + verify
- Sealed: `True` ({'status': 'reviewed', 'sha256': 'f6d39a23d5b45edbc32442c02ad30dce482ba4ce64ed0bc3781d93a0c491a864'}).
- `research_source.verify` -> ok=`True` reasons=`[]` sha256=`f6d39a23d5b45edbc32442c02ad30dce482ba4ce64ed0bc3781d93a0c491a864`.

## Ledgers + read-model
- experiment_memory: H-CW/H1/H2/H3 + a durable negative finding appended.
- search_history: one entry for the `cash-window-index-continuation` family.
- research_state read-model refreshed: `D:\QM\reports\state\research_state.json`.
- campaign.json updated to the successor artifact (`QM-RESEARCH-2026-0002`).

## Boundaries
The parent 0001 artifact was NOT edited. No farm-DB / gate / verdict write; no T_Live /
AutoTrading / FTMO purchase; the .gitattributes seal rule (`QM-RESEARCH-*/** -text`) is
unchanged and covers 0002. The pipeline (Q00-Q17) remains the judge of the candidate.

