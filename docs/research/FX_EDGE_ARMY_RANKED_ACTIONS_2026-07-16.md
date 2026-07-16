# FX Edge Army — ranked action list (wf_28fc3bf4, 2026-07-16)

17 agents, 8 strands (4 build/design + 4 discovery), each adversarially verified, then synthesized.
~1.06M subagent tokens. Book anchors already: Gotobi 12969, AUDUSD~NZDUSD coint, Balke index breakout —
so new *families* must be non-coint-FX / non-JPY-calendar to add orthogonal value.

## (A) BUILD NOW
- **A1 — Promote 13117 to the book (S, OWNER-gated).** Already-verified Q09 survivor (EURGBP/AUDJPY
  cointegration): **net PF 1.52, Sharpe 2.82, corr-to-book 0.036** — cleanest diversifier available, zero
  build risk. **Highest-EV *action* in the set: free alpha, one admission decision.** → propose to OWNER.
- **A2 — Requeue 10260's Q07-passing NDX sibling to Q08 (S).** Cieslak FOMC even-week equity premium
  (non-discretionary Fed liquidity cycle); index cost trivial vs ~183 tr @ PF 1.178. Admit if Q08 clears.
- **A3 — Turn-of-month index LONG-ONLY overlay, DE40 primary / NDX secondary (M).** Non-discretionary
  pension/401(k) inflows + calendar rebalancing (Xu–McConnell). ~10× cost cushion, HIGH mechanizability,
  no new infra, orthogonal new family. **Card drafted: CARD_DRAFT_TURN_OF_MONTH_INDEX_LONG_2026-07-16.md.**
  **Highest-EV genuinely-new build.** Mandatory 2015–2025 OOS drift-not-reversal falsification gate.
- **A4 — FX Value/PPP G10 REER long-short basket, spot-only (M).** PPP convergence premium; quarterly,
  **returns in spot → no swap injector, no new infra**; free BIS REER table + existing 10717 basket-EA
  architecture. The book's missing slow risk-premium anchor. Admit only on net-of-cost DSR ≥ 0.95.

## (B) INVESTIGATE
- **B1 — Dollar-carry EA — BLOCKED on swap provenance (L).** #1 latent EV (LRV crash-tail premium) but a
  hand-maintained rate injector would MANUFACTURE the edge (carry pays through rollover; our stack defers
  swap to $0) = hard-rule breach. Prereq: source + certify real broker swap (`swap_broker_rate_certified
  0→1`) BEFORE any build; then let the N_eff-DSR/PBO gate judge.
- **B2 — Fix + validate the N_eff-DSR/PBO gate (M).** 3 confirmed defects: SE bug `(kurt+2)/4`; weekly
  Sharpe annualizer (√52, drop n<30 guard); KMeans N_eff≤10 cap under-deflating 659-trial families
  (10023/10042). Validate on those two families before wiring to Q09.
- **B3 — AUDNZD-direct residual benchmark into WI-10717 (S/M).** 2-leg (β≠1) residual + entry-z freq
  sweep; decide if it clears the 5-tr/yr floor without mining, else formally retire the standalone.
- **B4 — Month-end FX sign-corrected probe (S, low prior).** Flip to Melvin–Prins direction, lock sign,
  cost-free D1 EURUSD 2015–2025; build only if gross clears ~2× cost, else close.

## (C) PARK / KILL
- **month-end FX card AS SPECIFIED — KILLED.** Direction inverted (shorts the edge) + D1 never trades the
  4pm fix + dies on FX cost. Salvage only via B4. (Card marked KILLED_AS_SPECIFIED.)
- AUDNZD-direct standalone (13020/12532) — PARK (failed Q03 MIN_TRADES, OOS PF 0.19); benchmark leg only.
- Cieslak even-week standalone — TEST-ONLY (OOS fails; leak broke post-2004). Overlay only.
- Carry via policy-rate swap injector — KILL that path (no-invented-swap). Carry survives via B1's real-swap route.
- 12532 / 1058 re-parametrization — KILL (p-hacking; below floor / degenerate sample).
- **12969 cost dashboard — CORRECT (not a build).** Display swap-zeroed cushion **~4.6× net / 5.62× gross**,
  NOT the carry-inflated **7.37×** (over-credits ~$3,061 deferred JPY swap); add live-vs-backtest USDJPY
  Tokyo-AM spread check to burn-in (only ~3-pip net headroom).

## Single highest-EV next steps
- **Action:** promote **13117** now (verified, corr 0.036, zero build risk) → OWNER admission decision.
- **New build:** **A3 turn-of-month DE40/NDX long-only** (card drafted) with its OOS falsification gate.

## Notable corrections the army delivered
1. My month-end FX card was **direction-inverted** → would have been negative-EV. Caught + killed.
2. 12969's live cost cushion is **inflated ~7.37× vs ~4.6× net** by deferred JPY swap → dashboard fix needed.
3. Carry (framework's #1) is **not cleanly buildable** without certified broker swap — the honest blocker.
4. Found a ready-to-admit orthogonal survivor (13117) sitting unadmitted.
