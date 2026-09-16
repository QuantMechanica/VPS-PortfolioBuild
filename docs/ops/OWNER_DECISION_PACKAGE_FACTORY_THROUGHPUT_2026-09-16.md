# OWNER DECISION PACKAGE — Factory Throughput Unblocks (2026-09-16)

**Prepared by:** Kimi (interim operator). **Authority basis:** interim directive outcome-B requirement — "prepare the smallest decision package possible."
**State:** Factory RUNNING (2× Q08 XAUUSD live since 05:52Z, receipt `4aeffbbd06`). These three decisions unlock the remaining legitimate backlog — nothing here bypasses gates; every path is canonical tooling + append-only evidence.

---

## DECISION 1 — Q08 DSR single-configuration card amendments (16 cards, 19 rows)

**What:** Extend `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914` (or issue a new decision) to the NDX/GDAXI cohort so the governed amend tool (`session_tools/q08_single_config_amend_0914.py`) can apply the **pre-staged, offline-validated** declaration blocks.

- **Staged:** `docs/ops/evidence/2026-09-16_q08_dsr_unblock/staged_card_amendment/` — 16 per-card diffs + amended copies + `manifest.json` (all sha-verified) + `COMMANDS.md` (exact dry-run → apply → verify → release-hold sequence).
- **Needed from OWNER:** the decision ID text; the tool's `DECISION_ID`/`RECEIPT_ID` constants updated to cite it (mechanical, shown in COMMANDS.md).
- **Per-row classification** (full table in the verification doc): 16 single-config-amendable · 1 censused EA (QM5_10145 — sealed DL-089 ledger exists; a false single-config declaration would be refused at claim time; needs grouped-cohort-per-symbol or retire decision) · 3 missing SPEC.md (12361, 1551, 12484 — need SPEC first) · 1 multi-symbol card disposition (12350) · 2 already running (11121/13137 — released today under the 09-14 authority).
- **Payoff:** up to 19 Q08 rows become claimable → crisis-gate evidence resumes on NDX/GDAXI (portfolio-relevant symbols).

## DECISION 2 — Requeue-exclusion lift for QM5_11561 + QM5_11731

**What:** Remove two EA ids from `D:\QM\strategy_farm\state\requeue_excluded_eas.txt` (flat ops guard, no per-EA reasons recorded) — or confirm the exclusion stands.

- **Why they qualify:** both are G0 APPROVE_FOR_BACKTEST, Q01 smoke **passed** (durable build records), artifacts clean, not superseded, zero Q02 work items ever (their 2026-07 enqueue died with `no_work_items_created` — an infra failure, not an economic one).
- **Why excluded in May:** the bulk exclusion targeted M1/M5 EAs without DWX history in the default 2017–2022 window. M5 custom history now exists (95540 done M5 work items fleet-wide; EURUSD.DWX history 2017–2025 on disk). The original reason is verifiably obsolete for 11731 (M5); 11561 is USDJPY **D1** (data never in question — exclusion likely collateral of the bulk sweep).
- **Payoff:** two fully-admissible Q02 enqueues via canonical `farmctl enqueue-backtest` (review APPROVE_FOR_BACKTEST + smoke-passed verified today) — immediate additional backtests.
- **If declined:** they stay parked; no harm done.

## DECISION 3 — Q12 `_opt` sibling seals for the 3 frontier pairs

**What:** Seal three DRAFT sibling cards (OWNER g0 act, ~5 min each following the staged recipes):

1. **QM5_41478** grimes-complex-pb-opt GDAXI — fully staged + gate-verified: `docs/ops/evidence/2026-09-16_opt_sibling_10911/` (setfile/pattern-readiness/guardrails all PASS; only the seal is missing). Then: allocator → promote → COMPILE_EA (codex lane, 09-19) → `service-dl089-matrix --apply` on rows 96239586 et al.
2. **11294/GDAXI** — same pattern, sibling = QM5_41347 card amendment (add GDAXI.DWX target).
3. **20086/NDX** — same pattern, sibling = QM5_41343 card amendment (add NDX.DWX target) **plus** OWNER release of `RAM_WINDOW_44GB` hold 1165f546.

- **Payoff:** the only pairs "3 short of Q14" — new qualified-pool candidates (index intraday is the FTMO white space).
- **Distinct from NEWS_CALENDAR_TAINTED:** these are Q12 frontier declarations, unrelated to the Q09 evidence-repin question (kept separate per mandate — see the prepared news-calendar repair for that).

---

**Not requested (already handled or out of scope):** Wave-1/2 second-chance commissions (done, routing) · H-CW/H-MR/H-FXMR critic staging (checklist agent in flight) · news-calendar receipt-chain repair (separately staged, `2026-09-15_news_calendar_repin_repair/`, needs its own human apply per kein-AI-Commit) · Q09 E1-C taint disposition (separate OWNER question, unchanged).
