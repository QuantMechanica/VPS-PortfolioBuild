# R-064-6 — Portfolio demo burn-in — Spec (OWNER-gated infra)

**Date:** 2026-06-01 · **Authority:** DL-064 R-064-6 · **Status:** Superseded by DXZ/T_Live read-only evaluation.

## 2026-06-01 OWNER repurpose note
OWNER decision 2026-06-01: Darwinex Zero uses virtual funds, so the DXZ/T_Live
account is already the forward test. R-064-6 is repurposed from the separate
demo-terminal burn-in described below into a **post-go-live read-only evaluation
gate on DXZ/T_Live**. The OWNER+Claude T_Live flip is the go-live; after that,
R-064-6 only reads the assembled book's live `TRADE_CLOSED` streams for the first
configured evidence window and produces advisory PASS/HOLD evidence for OWNER.

There is no demo terminal and no automated terminal operation in the repurposed
design. Tier-0 remains unchanged: the evaluation never toggles AutoTrading, never
starts MT5, never deploys, and never writes into T_Live.

The original demo-terminal design below is historical context only.

## Why
Per DL-064 R-064-6 and the Kaspareit blueprint (demo Beta-Phase 1/2): the
*assembled book* — not the individual sleeves — must prove itself on unseen
forward data on a **demo account** before T_Live. Q13 is per-EA live burn-in; this
adds a **portfolio-level** burn-in.

## Why this is a spec, not code today
It needs infrastructure that doesn't exist yet and is OWNER-gated:
1. A dedicated **demo MT5 account/terminal** (separate from the T1–T10 factory and
   from T_Live) to run the assembled book live-forward.
2. A deploy harness that pushes the R-064-4 portfolio manifest (the DRAFT one) to
   that demo terminal — same SHA256 / set-file (ENV=demo, RISK_PERCENT) discipline
   as the T_Live workflow, but to demo.
3. A forward-equity collector + a portfolio burn-in report (combined equity,
   realised portfolio max-DD vs the backtest expectation, per-sleeve live-vs-backtest
   drift) over a defined window (e.g. 4–8 weeks, mirroring Beta-Phase 1/2).

## Proposed shape (when OWNER greenlights infra)
- `portfolio_burnin.py`: given the demo terminal's live results + the manifest,
  produce a burn-in verdict: PASS if realised portfolio max-DD ≤ the Monte-Carlo p95
  (from `portfolio_montecarlo`) AND realised Sharpe within tolerance of backtest.
  FAIL/HOLD otherwise. Advisory → OWNER+Claude decide T_Live promotion.
- Gate position: between R-064-4 manifest (DRAFT) and the T_Live flip. The T_Live
  AutoTrading toggle stays OWNER+Claude manual (Tier-0); burn-in only produces
  evidence for that decision.

## OWNER decisions needed before build
1. Which demo account/terminal hosts the portfolio burn-in (Darwinex Zero demo?).
2. Burn-in window length + PASS tolerances (DD vs MC-p95, Sharpe band).
3. Whether burn-in is mandatory before every T_Live portfolio change or only the
   first deployment.

## Out of scope until then
No code now — this records the design so it's ready when the demo infra exists.
The rest of the DL-064 machinery (correlation, KPI, Monte-Carlo, admission gate,
manifest, re-fit) does not depend on it.
