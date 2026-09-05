# Astra FTMO analysis (e544e3b8) — commissioning status as of 03:31Z 2026-09-05

Rule (Orchestrator mandate): an open item without an `agent_tasks` row is noted, not commissioned.
Source: `docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md` sections 5–7.

## Action plan (section 5)

| # | Action | Status | Task / evidence |
|---|---|---|---|
| A | OOS campaign window/runner binding | **In progress, blocked by OWNER decision E4** | 1721f3a1: repair committed 1ac9f653d8 (fail-closed window contract, `repair-oos-window`); `--apply` deferred because the 2026 window lies in the calendar coverage hole and the calendar carries the −17 h defect (Vorlage 2026-09-05 E1/E4). |
| B | FUND_SCORE bound to the current census population | **Done** | a32a064e APPROVED (a774e850dc): 8/8 sealed streams re-scored input-explicitly, all < 1.0 → NO-BUY unchanged. |
| C | Shared FTMO evaluation semantics / schema adapters | **Done** | bc7e3b81 APPROVED (50939becd6 + 397fd2e21e): four-opening-day rule, rulepack-bound contract, legacy replays delta 0. Policy unification stays OWNER (§7). |
| D | Current-pool costs and calibration | **Commissioned now** | Codex Sol f16785de (cost snapshot 8/8 with official citations) + b8a0676b (spread/execution inventory). |
| E | Candidate supply + incremental diversification certification | **Supply running / certification commissioned now** | Counter 8/25 driven by the factory (census K=8, Q08 reruns, Q14); V4/Q08 8.3 tail certification: Codex Sol 9c7a1878. Fire-counter pruning authority = OWNER D1 (ROT). |
| F | Live identity, governor enforcement, exact-profile shadow/trial | **Preparation commissioned now (read-only)** | Claude 8c561172 (attribution + margin/tradability) and 7dceadd0 (freeze/pointer closure pack, trial design, stage runbook). Deployment actions remain OWNER. |
| G | Money dossier review and purchase | **OWNER** | NO-BUY stays (receipt row 6); acceptance test Vorlage: Claude 1e0fbad5. |

## Gap list (section 6) — 22 rows

Closed or in progress: OOS execution (A), FUND_SCORE (B), evaluator fidelity (C), fire-counter tool (Astra 1ff3fa26, decoder/export parity + pruning = D1 ROT), vault sync (done via OWNER/Claude boards).
Commissioned now: costs/contract mapping, spread pairing inventory, joint interval equity export (0af640f6), V4/tail certification, positive-evidence acceptance test, live attribution + margin/tradability, freeze/pointer closure + trial design + stage runbook.
OWNER-blocked (ROT / decision): finished confirmation cohort (E4), held-out selection contract seal, unified probability/correlation policy, runtime risk budget authorization, FTMO-target news binding (now inside the calendar Vorlage E1), book order/manifest, fee/data purchases.
Not yet commissioned (deliberately deferred): sealed holdout contract drafting waits for the calendar repair decision (its admissible data depends on E1).

## Decision list (section 7) — all with the OWNER

Evidence-first sequence (being executed), probability/correlation policy (ROT), census shortening (D1, ROT), venue/account profile, freeze/pointer, challenge purchase (deferred), terminal/payout operation — see `decisions/2026-09-02_owner_receipts_ceo_asks.md` rows 6–8 and the Vorlagen of 2026-09-04/05.
