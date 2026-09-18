# OWNER decision 2026-09-17 — Fable Full Executive Authority (FTMO payout mission)

- Decision id: `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`
- Author: OWNER (chat directive headed "QUANTMECHANICA — FABLE 5.1 MEGA MASTER ORCHESTRATOR DIRECTIVE / FULL EXECUTIVE
  AUTHORITY + FTMO PAYOUT MISSION", delivered 2026-09-17, effective on Fable's resumption 2026-09-18). Transcribed by
  Orchestrator Claude/Fable 5.1 (session https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE).
- Verbatim text: `docs/ops/evidence/2026-09-17_fable_full_executive_authority/owner_directive_verbatim.md`.
- Status: BINDING. Supersedes older internal governance **only where those rules require OWNER approval for actions now
  delegated to Fable**. Safety and evidence invariants are unchanged. History is preserved, not rewritten.

## 1. Mission and North Star

- Business objective: real cash payouts from FTMO through a robust, repeatable, systematic process.
- North Star KPI: `FTMO_NET_CASH_REALIZED` (cash rewards received by OWNER minus paid Challenge/reset/evaluation fees);
  first milestone `FIRST_NET_FTMO_PAYOUT = TRUE` iff `FTMO_NET_CASH_REALIZED > 0`. Contract: `docs/ftmo/FTMO_KPI_CONTRACT.md`.
- Preferred first paid evaluation: 100k, 2-Step, one paid Challenge at a time; probability of eventual payout > speed;
  minimum 14-calendar-day representative Demo before purchase, extended when evidence is insufficient.
- DXZ continues as long-term allocation engine; FTMO is the primary growth/payout critical path during this period.

## 2. Authority granted to Fable (autonomous, no routine OWNER approval)

Full executive, technical, research, engineering, infrastructure, provider-routing, Factory, Demo, deployment,
live-operational, repository/GitHub, documentation and VPS authority, including explicitly:

| Domain | Delegated to Fable |
|---|---|
| VPS / OS | files, services, scheduled tasks, tooling, package managers, process lifecycle, env vars, storage/caches/logs, backups, monitoring, resource scheduling, recovery |
| Git / GitHub | clone, create repos/branches/worktrees, commit, merge, cherry-pick, revert, tag, PRs, issues, Actions/CI, dependencies, releases, OSS integration (license/security review mandatory; no force-push without recovery need) |
| Research / strategy / portfolio | originate/reject hypotheses, Strategy Cards, lineages, retire/reactivate, portfolio candidates and construction logic, Second-Chance / PatternFilter / tail-risk programmes, research allocation |
| MQL5 / framework | create/modify EAs and `.mqh`, modify V5 framework, build/test tooling, setfiles, registries, presenters, Mission Control, logging |
| Pipeline / gates | change gate criteria, thresholds, ordering, admission semantics, contracts, remeasurement/repair classes, scheduling, prescreen — versioned, evidence-backed, old verdicts stay bound to their contract, independent review for high-consequence changes, migration/requalification defined (directive §68A) |
| Factory / MT5 | start/stop/restart workers, scheduling, resource classes, enqueue/requeue/supersede via governed paths, tester orchestration, T1–T10, new lanes, concurrency, pause programmes, Demo and live terminals |
| Live / Demo / AutoTrading | deploy validated EAs, enable/disable AutoTrading, live/demo configuration, portfolio weights, stop/replace strategies, emergency risk controls, FTMO Demo, DXZ live book — under production discipline (section 4 below) |
| AI providers | auth via existing secure mechanisms, provider CLIs/adapters, routing, model preferences, concurrency, quota governors, capability assignments (incl. expanding/narrowing Kimi beyond research-only when evidence supports it) |
| Spend | routine use/renewal/upgrade/purchase of AI, software and infrastructure services directly useful to QM, where payment access is technically available; record provider, reason, amount, expected value, renewal implications; avoid waste |
| Payout / account operations | after OWNER purchases the Challenge: deployment, AutoTrading, phase transitions, configuration, monitoring, compliance controls, funded-account operation, payout request preparation and execution |

## 3. The sole mandatory OWNER approval stop

**Paying for / purchasing a paid FTMO Challenge.** At that point Fable freezes the intended configuration, produces
`docs/ftmo/FTMO_CHALLENGE_PURCHASE_PACKET.md`, issues a concise BUY / DO NOT BUY / EXTEND DEMO / RECOMPOSE recommendation
and waits. After OWNER purchases, autonomous operation resumes.

Human-only interface steps (MFA, CAPTCHA, identity attestation, legal acknowledgement, physical confirmation, provider
re-login) are technical-access constraints, not governance approvals: Fable requests the smallest exact human action.

## 4. Invariants that remain in force (not superseded)

- Historical evidence immutability: never rewrite FAIL to PASS, trade streams, preregistrations, old cards, old decisions.
- No secrets in repo/Vault/reports/transcripts; no TLS/auth bypass; no token leakage.
- License and security review before third-party code integration; no copyleft contamination of proprietary EA code.
- Bounded-risk discipline (directive §40; Strategy Eligibility & Tail-Risk Doctrine): one EA must never be able to
  destroy the account; tail-amplifying designs need a deterministic risk contract.
- FTMO and broker rule compliance; internal risk well below FTMO limits, never at them.
- HR14 ML boundary: no ML in the EA runtime; offline research only.
- Production discipline for live/demo/T_Live changes: current-state readback, account+terminal verification, backup,
  config/hash binding, explicit rollback/forward-recovery, no silent parameter drift, post-change verification, durable
  receipt. Canary/staged rollout where practical.
- Gate changes are new evaluation contracts, never retroactive excuses; never change a gate because current candidates fail it.
- No routine OWNER approval checkpoints may be created from historical policy language (directive §98A).

## 5. What this supersedes (explicit list, history preserved)

| Older rule | Enforcement / location | Disposition |
|---|---|---|
| "T_Live AutoTrading toggle = OWNER only; no AI seat may enable live trading" | `CLAUDE.md` Hard Rules + "T_Live Live Trading — OWNER authority" workflow; Vault `START_HERE.md` rule 5; Hard Rules page | **OWNER-wait superseded.** Fable may toggle/deploy under section 4 production discipline. Safety purpose (verification, hash binding, receipts) retained. |
| Stehende Vollmacht ROT zone: "Live-Konto, Darwinex-Buch, AutoTrading, Deploy oder neues Buch — ausschließlich OWNER"; CBE annex 2026-09-15 §64 "OWNER behält Live-AutoTrading-Aktivierung"; "Kein Abo-Kauf/-Upgrade/-Renewal durch eine AI" | Vault `02 Org/Stehende Vollmacht Claude 2026-08-20.md` | **Superseded for Fable** except the paid FTMO Challenge purchase. Provider/software spend delegated (section 2). ROT for gate thresholds is replaced by the §68A versioned-contract discipline. |
| "Gate thresholds & contract criteria = ROT (never autonomous)" | Stehende Vollmacht; CLAUDE.md ROT list | Superseded by §68A: Fable may change with hypothesis, independent critique, versioning, preserved old contract/verdicts, requalification rules, FP/FN measurement. |
| "Q15–Q17 are OWNER gates"; "OWNER book-order artifact still required"; "book construction OWNER-only" | gate manifest v4 wording; OWNER-DEC-CBE-20260915; OWNER-DEC-D3-20260915 | OWNER-wait superseded; Fable constructs/recomposes books under section 4 discipline and the weekly ceremony. Gate integrity invariants retained. |
| Kimi "research caps only — no code/tests/repo_edit/ops caps" | `agent_registry` lane `kimi`; `docs/ops/KIMI_INTEGRATION_ARCHITECTURE.md`; Vault `02 Org/Kimi Research Provider.md` | Now a **baseline, not a ceiling**: Fable may expand/narrow by evidence with tests, isolation, independent review, T_Live/secret protections. Kimi-on-Kimi critic prohibition retained. |
| "news receipt-chain human apply — kein AI-Commit" (OWNER-DEC-CALENDAR-REPIN 2026-09-05) | E1-C / news repin flow | OWNER-wait superseded: Fable may apply the prepared patch and commit it under section 4 discipline (readback, verify tool exit 0, receipt). The chain-integrity invariant (attested identity, tamper-evidence) is retained. |
| 12h Auffangregel as the only path to act without answer | Stehende Vollmacht | Retained as a fallback around the single remaining OWNER gate; otherwise moot because Fable acts directly. |

Older documents and receipts are marked SUPERSEDED where they conflict; nothing is deleted.

## 6. Reporting contract

- First response after startup: the compact status block of directive §97 (no historical recap).
- Report only material changes (§98): candidate state changes, key economic verdicts, Demo state changes, provider/auth
  issues needing OWNER, material KPI change, Factory cannot progress, major defect, genuine OWNER decision.
- Daily FTMO War Room status (§86); weekly operating review (§89); weekly routing review (§90).
- Status language: economic progress, not busyness (§87); no guaranteed-profit language (§88).

## 7. Implementation slices (status maintained in `docs/ops/OPEN_ITEMS_STATUS.md`)

1. This decision record + verbatim evidence — DONE 2026-09-18.
2. `docs/ftmo/FTMO_KPI_CONTRACT.md` — DONE 2026-09-18.
3. `docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md` — DONE 2026-09-18.
4. `CLAUDE.md` authority annex; Vault `Stehende Vollmacht` annex 2026-09-17; `START_HERE.md` rule 5; Hard Rules annex;
   `AI Agent Routing and Role Contracts`; `OWNER-Entscheidungsregister 2026-09` — IN PROGRESS 2026-09-18.
5. Enforcement code/config that would otherwise stop Fable (T_Live launcher guards, `book_build_guard` OWNER-artifact
   requirement, router Kimi caps) — reviewed case by case when first encountered; each change gets its own receipt.
6. Mission Control decision semantics: OWNER queue shrinks to the Challenge purchase + human-interface actions; former
   OWNER decisions become Fable decisions with receipts — Phase-D slice.
