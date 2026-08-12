# CODEX G0 REVIEW + HOOK IMPLEMENTATION — harvest build run 2026-07-24

Two sequential jobs in one session. Claude drafted the cards and the final specs;
per the reciprocal G0 rule the counter-approval is YOURS (never the card author's,
no OWNER needed). Be a real reviewer: reject is an acceptable outcome.

## Job 1 — G0 review of three draft cards

Cards (D:\QM\strategy_farm\artifacts\cards_review\):
- QM5_20096_ha-stoch-h4-swing_card.md
- QM5_20097_three-little-pigs-mtf-sma_card.md
- QM5_20098_weekly-open-liquidity-sweep_card.md

For EACH card: check R1-R4 (reputable-source citation with year+URL in running
text; mechanical determinism; .DWX data availability; no ML) AND cross-check the
card against YOUR OWN independent specs
(`D:\QM\reports\source_harvest_build\02_spec_codex_STR-{097,103,021}.md`) — the
cards implement the reconciliations in
`C:\QM\repo\docs\ops\source_harvest\strategies\STR-*/03_reconciliation.md`
(read-only). If a card misstates the source or hides an interpretation as a
source claim → REJECT with reason (farmctl reject-card if available, else record
in your output and skip its hooks).
Approve via:
`set QM_AGENT_ID=codex && python C:\QM\repo\tools\strategy_farm\farmctl.py approve-card --card "<path>" --reasoning "<one-line R1-R4 rationale>" --expected-pf <pf> --expected-dd-pct <dd>`
(run from C:\QM\repo; the tool validates and moves the card to cards_approved).

## Job 2 — implement the 5 hook bodies for each APPROVED card

Authoritative specs: `C:\QM\repo\docs\ops\source_harvest\strategies\STR-097-ha-stoch-h4-swing\04_spec_final.md`,
`...\STR-103-three-little-pigs-mtf-sma\04_spec_final.md`,
`...\STR-021-weekly-open-liquidity-sweep\04_spec_final.md` (follow EXACTLY —
divergence from the final spec is a review-fail; ambiguity → note, do not invent).
Template context (read-only): `C:\QM\repo\framework\templates\EA_Skeleton.mq5`
(hook signatures + framework contract), `C:\QM\repo\framework\include\QM\*.mqh`
(QM_LogEvent, pip/stops helpers — REUSE framework helpers, do not reinvent
risk/news/killswitch/Friday logic).

Output ONE file per strategy to `D:\QM\reports\source_harvest_build\`:
`hooks_QM5_20096.mq5.txt`, `hooks_QM5_20097.mq5.txt`, `hooks_QM5_20098.mq5.txt`
containing: (a) the complete input block, (b) file-scope state/handles + helper
functions, (c) the five hook function bodies — pure MQL5, compilable in the
skeleton context, closed-bar discipline, QM_LogEvent evidence on every action
path. NO edits to any repo file (Claude integrates via Edit and compiles —
build+commit stays atomic on his side). No git, no MT5, no builds, no registry
edits, no T_Live/factory/flags.

When done:
`python C:\QM\repo\tools\strategy_farm\agent_router.py update-task <task_id> --state REVIEW --artifact-path "D:\QM\reports\source_harvest_build" --verdict "G0: <approved/rejected per card>; hooks delivered for approved cards"`
Then exit.
