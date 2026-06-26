# Portfolio Candidate Watchlist — NDX recovery + Q09 re-run (2026-06-26)

Context: main `dba239060` (portfolio admission recovery stack: Q09 monthly-corr fallback +
admission dedupe + 20-trade floor). OWNER task: redump the two missing NDX Q08 streams from the
canonical EA source, re-run Q09 with main-code (`min_portfolio_trades=20`), check Q12_READY vs
clean NEED_MORE_DATA/FAIL_PORTFOLIO, and audit `portfolio_candidates` dedupe.

Constraints honored: no portfolio-gate code changes; no merge/push.

## 1. Stream redump (canonical, EA-emitted)

Full-history real-tick backtests via `run_smoke.ps1` on idle terminals (session 1, like the
factory). The EA writes `QM\q08_trades\{ea}_{symbol}.jsonl` unconditionally on shutdown
(`QM_Common.mqh` L447–448), so this regenerates the stream from the canonical worker/EA source.

| EA:symbol | terminal | window | period/model | result | TRADE_CLOSED | stream mtime |
|---|---|---|---|---|---|---|
| 10692:NDX.DWX | T8 | 2017.01.01→2025.12.31 | H1 / Model 4 | PASS | **443** | 2026-06-26 08:53:32 |
| 10440:NDX.DWX | T9 | 2017.01.01→2025.12.31 | H1 / Model 4 | PASS | **441** | 2026-06-26 08:54:48 |

Stream path: `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades\`
(`10692_NDX_DWX.jsonl`, `10440_NDX_DWX.jsonl`). Trade counts differ slightly from the historical
457 (10692) because the EA was recompiled 2026-06-26 00:31; both ≥ the 20 floor.

## 2. Q09 re-run (main-code, `min_portfolio_trades=20`)

Gate = `portfolio_q08_contribution.evaluate_q08_soft_rescue` against the live candidate book
(Q12_READY = 10513:XAU, 10940:XAU, 11132:SP500). Fresh `aggregate.json` written to a separate
rerun root (canonical pipeline artifacts untouched).

| EA:symbol | Q09 work_item_id | Q08 FAIL_SOFT work_item_id | trade_count | corr_basis | max_corr_to_book | diversifies | **verdict** | reason |
|---|---|---|---|---|---|---|---|---|
| 10692:NDX.DWX | `607f7b0c-ecd8-4f72-a3e7-ca84bbd0b0ca` | `f63a313c-9181-4fd7-b0d0-155dc41f61f5` | 443 | **monthly** | −0.0205 | False | **FAIL_PORTFOLIO** | no_diversification |
| 10440:NDX.DWX | `9799d0aa-4a75-4925-b58c-fdaa62f823ca` | `9b6c3259-82e7-4de6-b558-5194a7fbb619` | 441 | **monthly** | +0.0586 | False | **FAIL_PORTFOLIO** | no_diversification |

Evidence (fresh, main-code):
- `D:\QM\reports\portfolio\ndx_q09_rerun_2026-06-26\QM5_10692\Q09_PORTFOLIO\NDX_DWX\aggregate.json`
- `D:\QM\reports\portfolio\ndx_q09_rerun_2026-06-26\QM5_10440\Q09_PORTFOLIO\NDX_DWX\aggregate.json`
- summary: `D:\QM\reports\portfolio\ndx_q09_rerun_2026-06-26\summary.json`

**Outcome: neither NDX candidate is Q12_READY — both clean FAIL_PORTFOLIO.** Both now clear the
trade floor AND the correlation cap (the monthly fallback engaged — `corr_basis=monthly`, real
correlations instead of the pre-fix `insufficient_overlap → NEED_MORE_DATA`). They fail the next
check, `diversifies`:

- 10692:NDX — adding it to the book drops daily Sharpe **2.23 → 1.54** and leaves DD ~25.5→25.8%.
- The `diversifies` test runs on **daily equal-weight** metrics. NDX trades 443× (dense) vs the
  book's sparse low-freq sleeves; equal-weight lets NDX dominate daily variance, so it looks
  non-diversifying on a daily basis even though it is monthly-uncorrelated (−0.02). This is the
  **second low-freq throttle** flagged in `docs/research/PORTFOLIO_PATH_TO_PROFITABLE_2026-06-26.md`
  §3.2 (move `diversifies` to the monthly/risk-parity basis — a separate review-gated PR).

## 3. portfolio_candidates dedupe audit (step 5)

**Distinct Q12_REVIEW_READY = 3. Duplicate ready rows = 0.** Dedupe (`83179f310`) holding.

| ea_id | symbol | state | q11_work_item_id |
|---|---|---|---|
| QM5_10513 | XAUUSD.DWX | **Q12_REVIEW_READY** | dd06ad11-3e9e-4d2b-b850-308253539768 |
| QM5_10940 | XAUUSD.DWX | **Q12_REVIEW_READY** | e25da444-2e84-402c-9ff1-a4f7493731a6 |
| QM5_11132 | SP500.DWX | **Q12_REVIEW_READY** | 1ea996fd-ef55-48ce-93d8-2b0a13c4f19a |
| QM5_11132 | SP500.DWX | DUPLICATE_SUPERSEDED | b258fc3b-… |
| QM5_11132 | SP500.DWX | DUPLICATE_SUPERSEDED | cfea221d-… |
| QM5_10692 | NDX.DWX | EVIDENCE_STALE | 607f7b0c-… |

## 4. Open item — stale DB Q09 verdicts (recommend, NOT mutated)

The DB Q09 work_items still carry **pre-main-code** verdicts from 2026-06-03:
- 10692:NDX `607f7b0c` = `PASS_PORTFOLIO` (evaluated as empty-book `first_sleeve`, before the book
  had 3 sleeves) — **contradicts** the fresh main-code `FAIL_PORTFOLIO`.
- 10440:NDX `9799d0aa` = `NEED_MORE_DATA`.

Currently harmless: the pump's promotion query is blocked for 10692 by its `EVIDENCE_STALE`
`portfolio_candidates` row (`NOT EXISTS pc.q11_work_item_id = w.id`). **Latent risk:** if that stale
row is cleared without re-running Q09, the pump would mis-promote 10692 on the stale `PASS_PORTFOLIO`.

Recommended reconciliation (OWNER/Codex, canonical): re-enqueue the Q09 work_items for both NDX
candidates so the worker overwrites the 2026-06-03 verdicts with the main-code `FAIL_PORTFOLIO`
(no clean farmctl re-enqueue CLI exists for Q09 today — it is pump-cascade-created). Not done here
to avoid unilateral DB mutation.

## 5. Net

- Streams recovered from the canonical EA source (443 / 441 trades). ✔
- Q09 re-run with main-code: both NDX = clean FAIL_PORTFOLIO (no_diversification). ✔
- Q12_READY unchanged at **3 distinct**, dedupe clean. ✔
- The monthly-corr fix is proven on recovered real data (both reached a real diversification
  decision). The remaining blocker for NDX admission is the daily-equal-weight `diversifies`
  metric — the next review-gated PR.
