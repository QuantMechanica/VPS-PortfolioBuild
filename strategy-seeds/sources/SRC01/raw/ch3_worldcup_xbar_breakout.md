---
source_id: SRC01
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Building Winning Algorithmic Tr - Kevin J. Davey.pdf"
extracted_section: Chapter 3 — World Cup Championship of Futures Trading® Triumph, pp. 23-31
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-27
---

# Chapter 3 — World Cup Trading System (X-bar Close Breakout, RSI-filtered, Trend-Following)

This is the strategy Davey personally traded in the **World Cup Championship of Futures Trading®** in 2005, 2006, and 2007 — finishing 2nd, 1st, 2nd respectively, with annual returns of **148%, 107%, 112%**. Found during Pass-2 main-text sweep per OWNER Rule 1 (CEO comment [`85b9ec8e`](/QUA/issues/QUA-191#comment-85b9ec8e-8461-4579-8110-2fb2621b0470)). Description in Ch 3 is in PROSE (no EasyLanguage code is provided in this chapter, unlike App B/C); the strategy is fully specified for entry but the exit-side parameters Y and Z (ATR multipliers) are not numerical-valued in the source.

## Strategy specification (verbatim, Ch 3 pp. 24-25)

> "I was ready for 2005 with the following system:
>
> Entry
> Buy next bar after 48 bar high close (vice versa for short), as long as the 30-bar RSI was greater than 50 (less than 50 for short trades).
>
> Exit
> Calculate stop based on:
>    Fixed dollar value ($1,000)
>    Y * average true range from entry
>    Z * average true range from entry (profit target)
>
> Other Rules (based on my psychology, I felt I needed these)
>    If last trade was a loser, wait 5 bars before entering next trade (minimizes whipsaws).
>    If last trade was a winner, wait 20 bars before entering next trade (be patient after wins)."

> "The system utilized daily bars for all trading signals, which was perfect for someone with a full-time job, like me."

## Markets traded (verbatim, Ch 3 p. 24)

> "For markets to trade, I had a basket of nine futures that I looked at:
>    Corn
>    Cotton
>    Copper
>    Gold
>    Sugar
>    5- or 10-year Treasury notes
>    Coffee
>    Japanese yen
>    Nikkei Index"

## Davey's own self-critique of selection process (verbatim, Ch 3 p. 25)

> "Looking back on this, though, I realize I made two pretty big rookie mistakes. First, when I tested my system, I tested over 20 to 25 different instruments. Then, upon seeing the actual performance, I simply selected the best performers. In other words, I optimized based on market! That is a big no-no for good strategy development. For my second mistake, I did not run any detailed correlation studies when selecting the portfolio."

→ V5 deployment must NOT repeat these mistakes. CTO at G0 should select Darwinex instruments via either (a) all-instruments-tested-equally or (b) explicitly correlation-driven basket selection, NOT cherry-picked-by-historical-performance.

## Capital sizing (verbatim, Ch 3 p. 25)

> "Since my capital was limited (I started each year with a $15,000 account), I could only trade one contract of each instrument. Occasionally, I had to skip a signal here and there, if I did not have enough available margin."

## Performance — full author claims (verbatim, Ch 3 pp. 26-30)

```text
2005 Results (Davey's Figure 3.1, p. 26):
Contest position    Second place
Return              148%
Max Drawdown         42%
Return/Drawdown       3.5

2006 Results (Davey's Figure 3.2, p. 28):
Contest position    First place
Return              107%
Max Drawdown         40%
Return/Drawdown       2.7

2007 Results (Davey's Figure 3.4, p. 30):
Contest position    Second place
Return              112%
Max Drawdown         50%
Return/Drawdown       2.2
```

Across all three years, 100%+ annual return (Davey's stated target: *"To achieve 100 percent return over the course of a year, I knew I had to accept a very large maximum drawdown. I decided I would allow around 75 percent maximum drawdown"* — Ch 3 p. 24). Three-year average ≈ 122% return, ≈ 44% max DD, ≈ R/D 2.8.

**Important caveat (verbatim, Ch 3 p. 31, Davey relaying mentor Dr. Van Tharp):**

> "And although Kevin has been trading and learning for 15 years, most people [who] win in trading contests are doing some very dangerous things with position sizing. So notice your reactions. Are you impressed with the people [who] win competitions? Or is your gut reaction to learn more about how to trade effectively in any market — and just stay in the game!"

Davey himself acknowledges the contest-context risk profile: *"For a trading contest where the only success criterion was return on account, allowing a large drawdown makes sense. If, however, the contest were based on return and risk (say the winning contestant would have the highest Calmar ratio), I would have approached the contest completely differently."* (Ch 3 p. 24)

→ **V5 deployment must NOT replicate Davey's contest-grade position sizing.** The 75% max DD allowance is NOT a V5-acceptable risk profile. CTO + Pipeline-Operator must size positions for V5's normal risk-mode-percent or risk-mode-fixed conventions, NOT for "let's win a contest" leverage.

## Research's reading notes (NOT verbatim — interpretation flagged)

- **Strategy character:** **trend-following** breakout (long on 48-bar high close, short on 48-bar low close), gated by a 30-bar RSI momentum filter (RSI > 50 for longs, < 50 for shorts).
- **Distinct from S04 davey-es-breakout:** S04 is COUNTERTREND on close-vs-N-day-extreme; this strategy is TREND-FOLLOWING on the same trigger shape. The two are mechanically opposite trade directions on a similar trigger. Both deserve cards under Rule 1.
- **Specifically "48-bar high close" + "30-bar RSI":** parameters X=48, RSI period=30, RSI threshold=50 are all numerical-valued in the source. Stop $1,000 is also numerical-valued.
- **Y and Z ATR multipliers:** NOT numerical-valued in the source. The card defines them as TBD with sensible-default sweep ranges; P1 Build Validation will need a specific choice OR will run with both =0 (effectively disabling them) and rely on the $1,000 stop.
- **Wait rules (5 bars after loser, 20 bars after winner):** clean mechanical rules, no ambiguity.
- **Daily bars:** explicit.
- **Markets:** 9 specific futures named. V5 Darwinex re-mapping at CTO sanity-check (most have approximate Darwinex CFD/spot equivalents; Nikkei → JP225.DWX; Yen → USDJPY.DWX; T-notes → USTNOTE proxy; corn/cotton/copper/gold/sugar/coffee → various commodity CFDs).
- **Davey's contest-context warnings:** TWO independent flags in the source — Davey's own self-critique (no instrument-cherry-picking, no correlation neglect) and Van Tharp's quoted critique (contest-grade position sizing is "dangerous"). Both must be honored when re-deploying on V5.
