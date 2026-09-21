# OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921 — FTMO is a portfolio / book problem, not a hero-EA search

- **Date:** 2026-09-21 (~11:0xZ, Fable orchestration session)
- **Authority:** OWNER (sole human authority); recorded by Fable under OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917
- **Verbatim:** `docs/ops/evidence/2026-09-21_ftmo_book_portfolio_directive/owner_directive_verbatim.md`
- **Status:** BINDING. Supersedes any implicit hero-EA interpretation of the FTMO programme. Does not change HR14, evidence
  immutability, §68A gate versioning, or the single mandatory OWNER approval (paid FTMO Challenge purchase).

## Decision (condensed)

1. **The FTMO_BOOK is the product.** Unit of commercial success = the account-level portfolio. EAs are sleeves
   (`EA × symbol × timeframe × configuration × risk allocation`); an EA may own several sleeves; a symbol may host many
   sleeves. No arbitrary per-symbol / family / symbol-count caps — actual dependence and account-level risk decide.
2. **No hero-EA search.** No sleeve must make +10 % alone, carry the Challenge, or have the highest standalone R/day.
3. **Primary research question per candidate = marginal contribution to FTMO_BOOK**, measured at minimum as
   ΔP_FIRST_NET_FTMO_PAYOUT_LCB, ΔP_CHALLENGE_PASS, ΔP_VERIFICATION_PASS, ΔP_DAILY_LOSS_BREACH, ΔP_MAX_LOSS_BREACH,
   ΔEXPECTED_TIME_TO_TARGET, ΔMAX_DRAWDOWN, ΔRECOVERY_TIME, ΔTRADE_DENSITY, ΔTAIL_DEPENDENCE, ΔCOST_DRAG.
4. **Velocity is a portfolio property.** R/day is evidence, not the KPI; the quantity is FTMO_BOOK_EXPECTED_PROGRESS_PER_DAY
   under Daily/Max-Loss safety, realistic cost, dependence and tail risk. **H-V4 / QM5_41485 = VELOCITY_SLEEVE candidate,
   not FTMO_SOLUTION**; continue its process (build, USDJPY Q02 canary, validation), then measure its marginal book value.
5. **Same-symbol multi-strategy explicitly allowed** — prove genuine difference (entry-time / position / direction /
   trade-day overlap, daily-P/L and downside correlation, worst-day overlap, stop clustering, news / vol-regime overlap,
   tail co-exceedance, gap exposure, simultaneous margin).
6. **Maintain FTMO_BOOK_DEPENDENCE_MATRIX** (not Pearson alone; central question: do these sleeves fail together?).
7. **Simulate at account level** from real chronological trades (balance, equity, open P/L, costs, simultaneous positions,
   Daily/Max Loss, target/Verification passage, payout survival). Never add standalone Sharpe/returns.
8. **Sleeve selection + risk weights are jointly the strategy.**
9. **Account-level FTMO Governor is the final risk authority** (may reduce entries, block correlated entries, freeze a
   cluster, disable a sleeve, flatten). Portfolio safety overrides EA signals.
10. Diversity must be economic, not cosmetic; research targets **missing portfolio behaviours** ("a sleeve that behaves like
    X when the book behaves like Y") recorded in `docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md`.
11. **Candidate table** with standalone edge / density / tail / dependence / marginal payout probability / book action.
12. **Portfolio construction loop** (CBE applied to FTMO): current book → strongest failure mode → missing behaviour → fewest
    hypotheses → cheap prescreen → build survivors → MT5 validation → marginal contribution → add only if the book
    improves → conservative re-weighting → repeat.
13. The M1/.hcc Velocity harness stays a valued pre-Factory tool, always with pre-registration, SEL/VAL separation,
    costs, null/bootstrap tests and anti-data-mining controls.
14. **Representative Demo tests the BOOK** (frozen sleeves, hashes, sets, weights, account-level risk / news / session
    policy); a material book change restarts or extends the evidence period.
15. **First-passage runs on the book**; sleeve-level first-passage is diagnostic only.
16. KPI hierarchy: North Star FTMO_NET_CASH_REALIZED; control P_FIRST_NET_FTMO_PAYOUT_LCB **computed for FTMO_BOOK**;
    supporting BOOK_* metrics (expectancy, R/day, trades/day, active days, max DD, breach probabilities, expected time to
    Challenge / Verification target, tail dependence, cost drag, concentration).
17. Research prioritisation = expected marginal book improvement ÷ (research + engineering + factory cost).
18. **Required artifacts:** `docs/ftmo/FTMO_BOOK_CURRENT.md`, `D:\QM\reports\state\ftmo_book_current.json`, Mission Control
    "FTMO BOOK" panel (sleeves, candidates, expected progress, density, DD, rule headroom, dependence risk, first-passage,
    strongest missing behaviour).
19. No strategy-count target. Evidence decides.

## Implementation (Fable, 2026-09-21)

- Verbatim + this record committed; CLAUDE.md section added; memory updated.
- Immediate report (§26) delivered in-session; `docs/ftmo/FTMO_BOOK_CURRENT.md` v1 and `ftmo_book_current.json` v1 written
  from the frozen 2026-09-18 evidence (D2g6) with measured / NOT_YET_MEASURABLE fields.
- Commissioned: account-level book simulator + dependence matrix + state writer (Codex), Mission Control FTMO BOOK panel
  (Codex); H-V4 continues as VELOCITY_SLEEVE candidate.
