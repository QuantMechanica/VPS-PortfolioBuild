# Q09_PORTFOLIO re-run assessment — 13036/GDAXI & 13301/GDAXI

**Date:** 2026-07-27
**Trigger:** Codex review C flagged that 13036/GDAXI and 13301/GDAXI both now hold
Q08 = PASS while their latest `Q09_PORTFOLIO` verdict is `FAIL_PORTFOLIO` from an
"earlier, weaker Q08 state", and therefore merit a fresh Q09 run.
**DB read mode:** `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`
**Decision:** enqueue a fresh Q09_PORTFOLIO for **13301 only**; **13036 does not
qualify** and was left untouched.

---

## Step 1 — Does the Q08 PASS post-date the Q09_PORTFOLIO FAIL?

work_items timestamps (`updated_at`, UTC):

### QM5_13036 / GDAXI.DWX — NO (premise false, stop)

| phase | verdict | updated_at | work_item id |
|---|---|---|---|
| Q08 | **PASS** | 2026-07-26T17:20:56Z | `85aadb10-6860-43df-bfb4-8c164246efc2` |
| Q10 | PASS | 2026-07-26T19:56:11Z | `788d2371-4a37-42c3-b9b1-18d9fb09bd3f` |
| **Q09_PORTFOLIO** | **FAIL_PORTFOLIO** | 2026-07-26T19:56:28Z | `6655a7d3-ac3c-458e-b374-a06ef5e5d01f` |

There is exactly **one** Q08 row for 13036 and it is PASS. The Q09_PORTFOLIO FAIL
was produced **~2.5 h AFTER** the Q08 PASS, not before it. The Q09 row's payload
confirms it was promoted directly from that PASS run:
`promoted_from_work_item = 85aadb10` (the PASS Q08), `promotion_source =
pump_q08_soft_portfolio_rescue`, `q08_trade_count = 1352`, and the aggregate reports
`lineage_basis = sha256` with `authoritative_q08_trade_count = 1352 = trade_count`
— i.e. it was graded on the cryptographically-bound bytes of the current PASS Q08.

**The Q08 PASS does NOT post-date the Q09 FAIL.** Per the step-1 instruction ("if it
does not, stop and say so"), 13036 is disqualified. Codex review C's premise is wrong
for this EA: its Q09 FAIL already reflects the current PASS Q08 state.

### QM5_13301 / GDAXI.DWX — YES (proceed)

| phase | verdict | updated_at | work_item id |
|---|---|---|---|
| Q08 | INFRA_FAIL | 2026-07-16T22:51:37Z | `8d71dda3-…` |
| Q08 | INFRA_FAIL | 2026-07-16T23:59:23Z | `1a61efe5-…` |
| Q08 | **FAIL_SOFT** | 2026-07-17T02:17:40Z | `8993bdac-3938-4db3-9aea-51935525be2f` |
| **Q09_PORTFOLIO** | **FAIL_PORTFOLIO** | 2026-07-21T04:38:03Z | `db5027ee-9326-40bc-b87f-dcfdf346d3fa` |
| Q10 | PASS | 2026-07-25T19:45:35Z | `ed116e37-…` |
| Q08 | **PASS** | 2026-07-26T21:45:34Z | `923b11b9-2e7d-4f70-bd67-37e0bb834123` |
| Q10 | PASS | 2026-07-26T22:57:38Z | `90c6f8d4-…` |

The Q08 PASS (`923b11b9`, 2026-07-26T21:45:34Z) **post-dates** the Q09_PORTFOLIO FAIL
(`db5027ee`, 2026-07-21T04:38:03Z) by ~5.7 days. **Step 1 satisfied.**

The FAIL was graded against a now-superseded, weaker Q08 state and no fresh Q09 has
run since (the pump's auto-promotion is blocked by its `NOT EXISTS Q09_PORTFOLIO`
guard once any Q09 row exists — hence the manual enqueue is required).

---

## Step 2 — What does Q09_PORTFOLIO test, and can a Q08 improvement change the verdict?

**Runner:** `framework/scripts/q09_portfolio.py` →
`tools/strategy_farm/portfolio/portfolio_q08_contribution.py::evaluate_q08_soft_rescue`
→ `portfolio_admission.evaluate_candidate`.

Q09_PORTFOLIO grades the sleeve's **own realized trade stream** (the durable
admission stream under `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\`) for
its **marginal contribution to the current book**. Admission zones (DL-083,
`classify_admission`), on `corr_eff = max(corr_full, corr_regime)`:

- `corr_eff >= 0.40` → REJECT `correlation_above_max_corr`
- `corr_eff < 0.15` AND positive marginal contribution → ADMIT
- gray zone (0.15–0.40): `delta_sharpe >= 0.020` → ADMIT, else REJECT `no_diversification`

Every non-admit reason then runs a **challenger-swap** check; if the candidate would
improve the book by REPLACING an incumbent, the verdict is stamped
`CHALLENGER_SUPERIOR` (admit still False — OWNER decides any swap at Q12; never
auto-swap).

Crucially, `corr_full`, `corr_regime`, `delta_sharpe`, and the swap comparison are all
**functions of the candidate's own return series**. A different Q08 backtest produces a
different stream, which moves these numbers. So the verdict is *not* a pure
book-structure property — a genuinely different (improved) Q08 stream can move it.

### 13036 — a Q08 re-run CANNOT change it (and Q08 hasn't changed)

Aggregate `…\6655a7d3\…\Q09_PORTFOLIO\GDAXI_DWX\aggregate.json`:
`reason = correlation_above_max_corr:corr_full`, `corr_full = corr_eff = 0.5448`
(`corr_regime = 0.1847`), `admit = false`, graded on the **current** PASS Q08 stream
(sha256-bound, 1352 = authoritative 1352). `0.5448` is far above the 0.40 reject line,
and — decisively — the graded input **is already the current PASS Q08**. A re-run would
grade the identical bytes and return the identical hard-correlation reject. No change
possible. (Its FAIL is genuine crowd-correlation with an existing book member, not a
stale-input artifact.)

### 13301 — a Q08 re-run CAN plausibly change it

Aggregate `…\db5027ee\…\Q09_PORTFOLIO\GDAXI_DWX\aggregate.json`:
`reason = CHALLENGER_SUPERIOR`, `max_corr_to_book = 0.4984`, `admit = false`,
`sharpe_with 2.5281 vs sharpe_without 2.5501`, `maxdd_with 0.2422 vs without 0.2511`,
`trade_count = 742`. The base reject was correlation-bound at **0.4984 — only 0.098
above the 0.40 reject line** — escalated to CHALLENGER_SUPERIOR (it already beats an
incumbent on a swap basis).

The Q08 backtest genuinely changed between the FAIL and now (same setfile, EA rebuilt
in the 07-24/25 gate-repair wave): the FAIL_SOFT run (`8993bdac`, 07-17) carried
**742 trades**; the PASS run (`923b11b9`, 07-26) carries **551 trades** — a materially
different return series, not a mere reclassification. A different series can plausibly
move `corr_eff` below 0.40 (strong/gray-zone admit) and/or change the swap comparison.
**Worth queue capacity.**

---

## Step 3 — Enqueue (13301 only)

Command (canonical repo, `C:\QM\repo`):

```
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_13301 --phase Q09_PORTFOLIO
```

Result: **requeued** the existing Q09_PORTFOLIO row to `pending`
(all three 13301 rows share one setfile, so the cascade reuses the row id rather than
creating a duplicate):

- **work_item id:** `db5027ee-9326-40bc-b87f-dcfdf346d3fa`
- ea_id `QM5_13301`, symbol `GDAXI.DWX`, phase `Q09_PORTFOLIO`
- status `pending`, verdict `NULL`, evidence_path `NULL`, `updated_at 2026-07-27T04:28:10Z`
- prior report archived → `…\db5027ee-9326-… .requeued_20260727T0428100000`

Post-enqueue verification (mode=ro): exactly **one** pending Q09_PORTFOLIO across the
farm (this one); the 13036 Q09 row is untouched (`done / FAIL_PORTFOLIO`); no Q02 or
other items were created. Only one gate for one (EA, symbol) was enqueued.

### Grading-source provenance note (important)

The cascade `enqueue-backtest --ea` path sources lineage from the **FAIL_SOFT** Q08
row (`8993bdac`) and does **not** thread `q08_evidence_path` / `q08_trade_count` into
the payload, so the fresh Q09 will grade on a `count_only` lineage basis against
whatever durable admission stream is on disk. That on-disk stream was verified to be
the **PASS** Q08 stream, so the outcome is correct:

```
D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\13301_GDAXI_DWX.jsonl
  TRADE_CLOSED rows = 551
  sha256 = 0a090ebb6ee67236948489a9486f419ba0ba41eb93d2ffa3e040a6a1b2a5a3a3
PASS Q08 (923b11b9) aggregate portfolio_stream.content_sha256
         = 0a090ebb6ee67236948489a9486f419ba0ba41eb93d2ffa3e040a6a1b2a5a3a3   (exact match)
```

The re-run therefore grades the improved 551-trade PASS sleeve. (The volatile
`Common\Files\QM\q08_trades\13301_GDAXI_DWX.jsonl` still holds the old 742-trade
FAIL_SOFT copy — sha `0b6a7530…` — but that path is diagnostic-only and is never a
grading/repair source, so it is harmless.)

---

## Status / risks / next step

- **Status:** 13301 Q09_PORTFOLIO requeued (pending); 13036 disqualified and untouched.
- **Risk:** if a new Q08 run for 13301 overwrites the admission stream before dispatch,
  the re-run would grade the newer stream (still current, so acceptable). Low.
- **Next step:** let the pump/dispatch-tick claim the pending item; read the resulting
  `db5027ee/QM5_13301/Q09_PORTFOLIO/GDAXI_DWX/aggregate.json` verdict. A
  `CHALLENGER_SUPERIOR` or `PASS_PORTFOLIO` outcome is an OWNER Q12 swap/admission
  decision, not an auto-admit. No Factory_OFF/ON was run.
