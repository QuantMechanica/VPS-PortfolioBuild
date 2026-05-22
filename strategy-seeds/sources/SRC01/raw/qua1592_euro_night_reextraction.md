# [CORROBORATION EVIDENCE — not the canonical card]

> This file is PDF-Intake-Agent's independent re-extraction of Davey's Euro Night strategy from the
> source PDF, produced under QUA-1592 (2026-05-15) and accepted into the SRC01 raw archive under
> QUA-1596. It exists to **corroborate** the canonical card at
> `strategy-seeds/cards/davey-eu-night_card.md` (drafted 2026-04-27 by Research, ea_id 1002,
> built as QM5_1002_davey-eu-night.ex5).
>
> The canonical card is authoritative. This re-extraction is preserved verbatim as evidence that
> an independent agent reading the same PDF identified the same entry/exit rules, parameter
> ranges, and author claims — supporting reproducibility of the G0 extraction step.
>
> Strategy match confirmed: SAME strategy. 105-min bars, 18:00–23:59 ET overnight session, ATR-offset
> mean-reversion limit entry from Avg(High/Low, Nb), TR-fraction profit target, fixed-tick stop
> 275–425, SetExitOnClose. All match canonical SRC01_S01.

---

# Strategy Card: Euro Night (Davey 2014)

**Source:** Building Winning Algorithmic Trading Systems — Kevin J. Davey (Wiley, 2014)
**Pages cited:** [255, 256, 257, 258, 171, 172]
**Extracted by:** PDF-Analyst QUA-1592

## Hypothesis

Low-liquidity overnight euro session (18:00–24:00 ET) produces short-term mean-reversion excursions. Price stretches away from the N-bar average high/low by a multiple of ATR; once filled at the limit, the rubber-band reverts before session close, yielding a small positive expectancy per trade.

## Rules

**Symbol:** Euro currency futures continuous contract (@EC / 6E) — futures only, not spot forex.

**Timeframe:** 105-minute bars. Session window: 18:00–23:59 ET. All positions closed by 07:00 ET (SetExitOnClose). [p. 171, Appendix B p. 255]

**Entry — long:**
- LongPrice = Average(High, Nb) − ATRmult × AvgTrueRange(NATR)
- If |close − LongPrice| ≤ |close − ShortPrice|: place Buy limit at LongPrice next bar
- Conditions: MarketPosition = 0, EntriesToday < 1, Time ≥ 18:00 and Time < 24:00 [p. 255–258]

**Entry — short:**
- ShortPrice = Average(Low, Nb) + ATRmult × AvgTrueRange(NATR)
- If |close − ShortPrice| < |close − LongPrice|: place SellShort limit at ShortPrice next bar
- Conditions: same as long [p. 255–258]

**Exit — profit target:**
- Long: Sell limit at EntryPrice + TRmult × TrueRange [p. 258]
- Short: BuyToCover limit at EntryPrice − TRmult × TrueRange [p. 258]

**Exit — stop loss:** Fixed tick stop (Stoplo), applied via SetStopLoss per position. Range 275–425 ticks across walk-forward periods. [p. 255–258]

**Exit — session end:** SetExitOnClose forces flat at 07:00 ET. [p. 258]

**Filters:**
- Session time filter: entries only 18:00–23:59 ET
- Max 1 entry per session (EntriesToday < 1)
- Must be flat at entry (MarketPosition = 0)
- Walk-forward parameter windows applied per rolling period (see below)

**Parameters (walk-forward optimized, not fixed):**
- Nb (High/Low average lookback): 9–19
- NATR (ATR lookback): 73–93
- ATRmult (entry distance multiplier): 2.55–3.15
- TRmult (profit target as fraction of TrueRange): 0.51–0.71
- Stoplo (stop loss in ticks): 275–425

**Walk-forward test period:** 2009–2013, rolling optimization windows on continuous @EC. [p. 171, 178]

## Risk

**Backtest results (Monte Carlo, $6,250 starting equity):** [p. 164, 178]
- Median annual return: 52%
- Median maximum drawdown: 25%
- Return/drawdown ratio: 2.0
- Risk of ruin (equity < $3,000): < 10%
- Probability of positive year: ~91%

**Known limitations:**
- Only ~4 years of intraday data used (2009–2013); pre-2009 pit data excluded. [p. 157]
- Walk-forward parameters change per period — implementation requires rolling optimizer or fixed representative set.
- Continuous contract back-adjustment; ratio-based indicators excluded by author. [p. 97–98]
- Limit order fills: forex/futures distinction matters. Book uses futures @EC; limit fill assumptions valid for exchange-traded instrument. [p. 100–101]
- Strategy was live-traded by author starting August 2013 with reported underperformance vs. WF history at time of writing. [p. 244]
- No ML. No neural networks. Pure indicator arithmetic.
