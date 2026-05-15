# [CORROBORATION EVIDENCE — not the canonical card]

> This file is PDF-Intake-Agent's independent re-extraction of Davey's Euro Day strategy from the
> source PDF, produced under QUA-1592 (2026-05-15) and accepted into the SRC01 raw archive under
> QUA-1596. It exists to **corroborate** the canonical card at
> `strategy-seeds/cards/davey-eu-day_card.md` (drafted 2026-04-27 by Research, ea_id 1006
> reserved 2026-05-15, P0 build dispatched via QUA-1596 child issue).
>
> The canonical card is authoritative. This re-extraction is preserved verbatim as evidence that
> an independent agent reading the same PDF identified the same entry/exit rules, parameter
> ranges, and author claims — supporting reproducibility of the G0 extraction step.
>
> Strategy match confirmed: SAME strategy. 60-min bars, 07:00–15:00 ET day session, fade-breakout
> with xb2-bar momentum filter, $5000 hard-cap profit target, fixed-tick stop 225–425,
> SetExitOnClose. All match canonical SRC01_S02.

---

# Strategy Card: Euro Day (Davey 2014)

**Source:** Building Winning Algorithmic Trading Systems — Kevin J. Davey (Wiley, 2014)
**Pages cited:** [259, 260, 261, 171, 172, 163, 164]
**Extracted by:** PDF-Analyst QUA-1592

## Hypothesis

During the US day session, the euro makes short-lived breakouts to N-bar highs/lows while momentum (measured over xb2 bars) is opposing. These counter-trend breakouts are fading setups: price overshoots the breakout level, triggers a limit fill slightly beyond it, then reverts. The xb2-bar momentum filter screens for cases where the breakout direction contradicts the medium-term trend, increasing mean-reversion probability.

## Rules

**Symbol:** Euro currency futures continuous contract (@EC / 6E) — futures only. [p. 171]

**Timeframe:** 60-minute bars. Session window: 07:00–15:00 ET. All positions closed by 15:00 ET (SetExitOnClose). [p. 172, Appendix C p. 259]

**Entry — short (fade breakout high):**
- Condition: High ≥ Highest(High, xb) AND Close < Close[xb2]
- Order: SellShort limit at (High + pipadd/10000) next bar [p. 260, 274]

**Entry — long (fade breakout low):**
- Condition: Low ≤ Lowest(Low, xb) AND Close > Close[xb2]
- Order: Buy limit at (Low − pipadd/10000) next bar [p. 260, 274]

**Filter — session and frequency:**
- tradestoday = 0 (max 1 trade per session) [p. 260, 274]
- Time < 15:00 (no new entries in final session hour) [p. 260]
- New session resets tradestoday counter [p. 260]

**Exit — stop loss:** Fixed tick stop (Stopl), applied via SetStopLoss per position. Range 225–425 ticks across walk-forward periods. [p. 261, 275]

**Exit — profit target:** $5,000 per contract fixed. Effectively a hold-to-close target (author: "there has never been a $5,000 intraday move in euro" — target is intentionally not expected to hit). [p. 157, 275]

**Exit — session end:** SetExitOnClose at 15:00 ET. [p. 275]

**Parameters (walk-forward optimized, not fixed):**
- xb (breakout lookback bars): 2–5
- xb2 (momentum filter lookback bars): 50–80
- pipadd (limit entry offset beyond breakout in pips): 1–11
- Stopl (stop loss in ticks): 225–425

**Walk-forward test period:** 2009–2013, rolling optimization windows on continuous @EC. [p. 171, 175]

## Risk

**Backtest results (Monte Carlo, $6,250 starting equity):** [p. 164]
- Median annual return: 129%
- Median maximum drawdown: 23.7%
- Return/drawdown ratio: 5.45
- Risk of ruin (equity < $3,000): 4%
- Probability of positive year: 94%

**Known limitations:**
- Only ~4 years of intraday data used (2009–2013). Author acknowledges shortcut vs. preferred 10-year standard. [p. 157]
- Walk-forward parameters change per period — implementation requires rolling optimizer or fixed representative set.
- $5,000 profit target is a proxy for "hold to close" — the true exit is SetExitOnClose; this must be reproduced accurately in MQL5 (exit on session close, not on $5,000 target).
- "tradestoday" logic requires session-boundary detection; must align with broker session definition (DarwinexZero NY-close convention applies).
- Author reported live underperformance vs. WF expectations at time of writing (2013). [p. 244]
- No ML. No neural networks. Pure indicator arithmetic.
