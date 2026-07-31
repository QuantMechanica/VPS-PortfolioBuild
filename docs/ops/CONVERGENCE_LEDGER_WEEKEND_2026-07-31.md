# Weekend Programme Convergence Ledger — 2026-07-31

OWNER directive (2026-07-31): work the following topics in order, delegate across
Codex (Sol Ultra/Max), Opus and Sonnet at Claude's discretion, **cross-review**
(Claude reviews Codex work, Codex reviews Claude work), implementation only at
**>= 90% joint agreement**, and every implementation is re-reviewed afterwards.
The Obsidian vault may be used as an exchange document.

## Protocol

1. One side authors (spec / plan / design). The other side reviews adversarially
   and states an explicit **agreement percentage** plus itemized findings.
2. `agreement >= 90%` -> implementation may start (implementer = the reviewer of
   the artifact where practical, so builder != approver is preserved end-to-end).
3. `agreement < 90%` -> author revises, next round. Rounds are logged here.
4. After implementation: the counter-party re-reviews the implementation
   (evidence: test runs, renders, hashes — never narrative), then the topic closes.
5. All routing via `agent_router.py` tickets (Rule 9: no manual codex exec while
   the factory runs). Evidence lives under `docs/ops/evidence/` or
   `docs/research/`; this ledger only records rounds and scores.

## Topics

| # | Topic | Author (R1) | Reviewer (R1) | State | Rounds / agreement |
|---|---|---|---|---|---|
| A | Gate-taxonomy single-source: cockpit -> phase_ids, add Q00, purge stale Q14 (farmctl + state_name_adapter), wire `gate_manifest.v1.json` as validated single source | Claude (spec: `CODEX_BRIEF_2026-07-31_gate_taxonomy_singlesource.md`) | Codex | R1 dispatched | — |
| B | Live-book kill-switch baselines 10/24 (pulse ALARM): mechanism, gap plan, safe window, apply | Claude (plan after recon) | Codex | recon running (read-only workflow) | — |
| C | FTMO Book3 selection-sealed OOS + event-complete shared-equity trace (`FTMO_BOOK3_SEALED_VALIDATION_DESIGN_2026-07-31.md`) | Claude (design) | Codex | R1 dispatched | — |
| D | Q08 frontier queue steering: 10582 (setfile strategy_*), 20039 Q06 INFRA_FAIL, 20007 Q02 GDAXI/NDX | Claude (steering plan after recon) | Codex | recon running | — |
| E | New motors 20183 / 20184 / 11592 (Q02) | — | — | watch only | — |

## Round log

- 2026-07-31: Ledger opened. Topics A and C authored by Claude and dispatched to
  Codex for adversarial R1 review. Topics B and D awaiting read-only recon
  results (workflow: KS mechanism + frontier blocking causes) before the plan
  artifacts are authored.

## Standing constraints (bind every topic)

- Factory keeps running; no Factory_OFF/ON as part of any topic; never T5, never
  T_Live process/AutoTrading mutation. T_Live file-side deploys (topic B) only
  SHA-verified per the standing go-live procedure, in the agreed safe window.
- Staged recovery requeues only (one stage per action, never bulk).
- Gate criteria are hard-bounded: no topic may silently redefine
  `challenge_ready`, Q08 semantics, or promotion rules. Where a design needs a
  gate-adjacent decision, it is surfaced as an explicit OWNER question.
- Display surfaces show Qxx only; stored legacy `P*` compatibility keys
  (public-data contracts) are never rewritten.
