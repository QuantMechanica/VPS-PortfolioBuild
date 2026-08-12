# FTMO Challenge Campaign — win Phase-1 in ≤30 days, 80% probability (2026-07-21)

**Authority:** OWNER 2026-07-21 — "Strategien für eine FTMO Challenge, sodass wir diese
innerhalb von 30 Tagen gewinnen (mit 80% Wahrscheinlichkeit); Codex headless, höchster
Effort (Sol/gpt-5.6-sol, model_reasoning_effort=max), richtig burnen; Claude orchestriert."

## The target (be precise)

FTMO Phase-1 pass = reach **+10%** on a 100k demo within **≤30 calendar days**, without
breaching **5% daily loss** or **10% total loss**. We want **P(pass within 30d) ≥ 0.80**.

## The decisive prior finding (from our own MC — do NOT re-derive, build on it)

`docs/ops/evidence/2026-07-20_ftmo_p1_mc_design.md` + `D:\QM\reports\portfolio\ftmo_p1_mc_20260720\`:
**No current book composition passes the ≤50-day gate** (best admissible tilt ~30.6% P(pass),
conditional median 52 days). The bottleneck is **DENSITY / CARRY, NOT risk** — the book
earns ~$4.2k per 90 trading days vs the ~$10k (+10%) target, while total-DD death ≤3.6% and
daily-DD death 0%. **So the entire campaign is about adding high-frequency, high-net-carry,
low-DD sleeves that compound +10% fast** — not about safety.

## Hard economic constraints (FTMO venue)

- FTMO cost model = `framework/registry/venue_cost_model.json` (commission per lot RT;
  **index swap kills overnight index holders**). **Strongly prefer INTRADAY-FLAT
  (swap-free) sleeves for FTMO** — they carry zero overnight financing.
- Every candidate must show **positive expectancy NET of FTMO commission + (for overnight
  holds) swap**. Backtests are .DWX (spread-inclusive, $0 commission) → inject FTMO
  commission per the venue model at validation.
- Q02 frequency floor 5/yr is the pipeline minimum; for FTMO we want FAR higher density
  (the whole point) — target sleeves with tens-to-hundreds of trades/yr.

## Reusable assets (build ON these)

- **MC harness `tools/strategy_farm/portfolio/ftmo_p1_mc.py`** — THE go/no-go gate. Any
  proposed book must be run through it (trade-level bootstrap, 10k paths, +10%/−5%d/−10%t
  absorbing barriers, 30-day horizon) and clear P(pass) ≥ 0.80.
- **Density motor: QM5_12969 gotobi (usdjpy-nakane-fix)** — Q09 PASS_PORTFOLIO, 331 trades,
  Sharpe 2.63, structural payment-flow edge. The proven high-density core.
- In-flight density EAs: **20023 idx-macro-announce-day** (SSRN Savor-Wilson, ~40/yr/symbol,
  **intraday-flat = swap-free = FTMO-ideal**), **20026 Etula TOM**, **20004 TOM**, Mulham
  13209/13212, **13013 grimes-trendday-v2** (Q08+Q10 PASS), **13301 TT-DAX** (742 trades).
- **SSRN candidates** `docs/research/SSRN_MINING_2026-07-20.md` — rank 8 (announcement-day,
  swap-free), rank 9 (intraday-momentum filtered), rank 7 (Tokyo-fix), etc.
- **ICT holdout thread (RESUME + reuse):** the interrupted codex session (ended 2026-07-21)
  was preregistering a 2025 holdout for ICT dual-EAs — QM5_12535 (ict-killzone-sweep-idx),
  QM5_10629/USDJPY (sweep→BOS→OB-retest), 10628/SP500 correctly on HOLD_BEFORE_TEST. Holdout
  UNCONTAMINATED (no 2025 run opened). Its documented resume plan: 12535 audit → index-source
  causal repair → 10629 finish → independent review → strict compile → explicit commit + hash
  → then the 2025 holdouts. HEAD de0fe8c9b. The 10629 .ex5 is stale (do not test as-is).

## ★★ HARD RULES for every Codex dispatch (violating any = stop)

1. **NEVER run Factory_OFF / TestWindow_OFF / any factory-isolation.** (A prior ICT codex
   session did exactly this and stranded the factory in an OFF loop for hours — the whole
   reason this campaign exists is that lesson.) The factory is RUNNING and must stay up.
   Route ALL backtests through the NORMAL pipeline (`farmctl build-ea` / enqueue → the live
   factory tests them) or hand the test off to Claude. Do NOT isolate.
2. Sol / gpt-5.6-sol, effort max. agents/codex-lane worktree OR canonical with STRICT
   explicit-pathspec commits. Serial builds only (magic-resolver race). No credentials.
   T_Live / FTMO terminals untouched. Evidence path per claim.
3. Cards need year+DOI/URL in the prose body + real ea_id in flat frontmatter + target_symbols
   (validator rules). SP500.DWX is backtest-only (FTMO route requalifies on US500).
4. The MC harness verdict (P(pass) ≥ 0.80 over 30 days) is the acceptance gate — not PF alone.

## Orchestration (Claude drives)

- Wave 1 (now, parallel Codex, DESIGN/SOURCE only — no builds, conflict-free): (A) FTMO Book
  Architect — MC-driven book design + gap + prioritized build list; (B) Strategy Sourcing +
  ICT-resume — build-ready specs/cards for the highest-density swap-free candidates + the ICT
  thread.
- Wave 2 (Claude coordinates): serial build wave on the prioritized list → pipeline tests.
- Wave 3: assemble → MC-validate the book ≥ 0.80 → OWNER admission (money gate).
