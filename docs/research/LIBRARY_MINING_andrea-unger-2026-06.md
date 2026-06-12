# Library Mining — Andrea Unger (two PDFs)

**Mined:** 2026-06-12  
**Task:** 7143e208-5a5c-4c0a-a142-e168b25bedf7  
**Source files:**
- `C:/Users/Administrator/Downloads/484404695-forex-strategies-by-andrea-unger.pdf` (7 pages, 12,408 bytes extracted)
- `C:/Users/Administrator/Downloads/347678472-BetterSystemTrader-Episode45-AndreaUnger.pdf` (10 pages, 32,417 bytes extracted)

---

## Source Assessment (R1–R4)

**R1 — Track record:** Andrea Unger is the only four-time World Cup Trading Championships winner (2008, 2009, 2010, Q4-2012). Strong R1.

**R2 — Mechanical:** Neither PDF discloses specific mechanical rules. SOFTPATH is described as a 6-system portfolio using "breakout of important levels" on M5/H1/M15 bars for EURUSD — zero parameter disclosure. ACHIEVER is the same architecture at higher risk. The BST interview covers methodology philosophy only.

**Result: R2 FAIL on both PDFs — no mechanical rules extractable.**

---

## PDF 1: Forex Strategies by Andrea Unger (Axiory Marketing Brochure)

The 7-page PDF is an Axiory investment platform brochure promoting "UngerTrading SOFTPATH" and "UngerTrading ACHIEVER" as copy-trading products.

**What is disclosed:**
- SOFTPATH: 6 different automatic systems; mix of trend and reversal; breakout of "important levels"; M5 (2 systems), H1 (1 system), M15 (3 systems); traded EURUSD only
- Position sizing: percent-volatility model (0.01–0.2 lots per 10,000 USD)
- Exits: fixed-pip SL, time exits, trailing exits; 8% drawdown on closed positions stops the system
- ACHIEVER: same principles as SOFTPATH with higher size limits (0.05–0.3 lots/10k) and 30% max DD on closed

**What is NOT disclosed:** Any indicator, threshold, lookback, entry signal, or parameter. No rules to extract.

---

## PDF 2: Better System Trader Episode 45 — Andrea Unger Interview Transcript

The 10-page PDF is a transcript of a podcast interview (BetterSystemTrader.com). Covers methodology philosophy, not specific rules.

**Notable fragments (not mechanically complete):**

**Fragment 1 — Indecision Day Filter:**
> "If the daily bar has a body smaller than 50% of the total range, I call it an indecision day. On indecision days, trend-following entries are more effective than reversal entries."

*Assessment: This is a named pre-filter based on a day's body-to-range ratio. Could be implemented as:*
- `Indecision = (|Close - Open| / (High - Low)) < 0.50`
- *On indecision days: bias toward continuation entries, reduce or skip mean-reversion entries*

This fragment is mechanically expressible as a filter, but Unger does not disclose the full strategy it conditions. As a standalone entry trigger it lacks an exit, timeframe, and symbol. **Not enough for a full card.**

**Fragment 2 — Entry timing:**
> "I mostly look for a breakout of a level that was established in the previous session or previous day."

Generic daily-level breakout — already represented in existing cards.

**Fragment 3 — Portfolio philosophy:**
> "The method is not the key. Position sizing is. A good method with bad position sizing loses money. A poor method with good position sizing survives."

Not mechanical — methodology commentary.

---

## Existing Coverage Check

Searching `cards_approved/` for unger-named cards:

| Pattern | Count |
|---------|-------|
| `*unger*` | 36 |

The 36 existing Unger-named cards originate from public sources (course materials, live trading recordings, BetterSystemTrader episode summaries from other public sources). They cover the known Unger system families: range breakout (overnight range, weekly range), time-of-day exits, and volatility filters.

---

## Dedup Verdicts

| Item | Verdict | Notes |
|------|---------|-------|
| SOFTPATH/ACHIEVER portfolio | SKIP | Zero parameters disclosed |
| Indecision Day Filter (body < 50% range) | POTENTIAL FILTER | Not a standalone strategy; attach to a future mean-reversion card as a confirmation guard |
| Daily/session level breakout | DUPLICATE | Fully covered across existing cards |

---

## Card Proposals

**None.** Neither PDF contains a mechanically complete rule set that could generate a card.

The Indecision Day Filter fragment is worth noting for future use as an optional filter on mean-reversion strategies, but it is not a standalone card candidate.

---

## Recommendation

No follow-up actions required for these two PDFs. Existing 36 unger-named cards provide adequate coverage. If Unger's primary book ("The Successful Trader's Guide to Money Management") becomes available in a machine-readable edition, a dedicated extraction would be warranted (that source discloses the position-sizing mathematics in detail).
