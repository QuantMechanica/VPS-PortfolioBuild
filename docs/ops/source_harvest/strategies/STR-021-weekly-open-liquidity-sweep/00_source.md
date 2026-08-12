# STR-021 — Source extract

**Source:** Sol72, "Algorithm for Entering a Trade", in ForexFactory thread
#1328051 "Trading system based on monthly, weekly and daily [levels]" (2025),
https://www.forexfactory.com/thread/1328051 — PDF pages 14–15 (the algorithm),
context pages 11/16 (tick-vs-real volume caveat), 17 (weekly-level rationale).
PDF: `Web-Sources/ff_1328051_trading-system-based-on-monthly-weekly-and-daily.pdf`
(32 pages). Full extract: scratchpad `str021_src_full.txt`.

## Stated rules (verbatim anchors, p.14–15)

- Level: "Identify the weekly opening level (the price level at the start of the
  trading week)."
- BUY: (1) "price must break the level **downwards**"; (2) order block below the
  level = "a bearish candle with **extreme volume**"; (3) confirmation = "price
  **close above the high** of the bearish candle"; (4) "**buy limit order** at the
  **high** of the bearish candle"; (5) SL "below the **low** of the bearish candle".
- SELL: full mirror (break upwards, bullish extreme-volume candle above the level,
  close below its low, sell limit at its low, SL above its high).
- Exit options (p.15): next weekly/daily level; next order block; midpoint of the
  imbalance (FVG); **or 1:2 risk-reward**. (Multiple options; only 1:2 RR is fully
  deterministic.)
- Author context: traded ETH/USDT (crypto); himself flags that FX tick volume ≠
  real volume (p.16: "tick volumes differ from actual volumes… difficult to apply
  to currency pairs. If anyone knows, please advise where to find volumes for oil
  or gold") — i.e. he targets oil/gold as the transferable market. Weekly level
  primacy rationale p.17 (smart-money at weekly/monthly levels).

## Source ambiguities (for reconciliation)

1. Execution timeframe of the order-block candle is never stated (charts suggest
   intraday; ledger assumed M15).
2. "Extreme volume" is not quantified; on .DWX we only have tick volume (the
   author himself de-emphasizes volume later in the thread).
3. Limit-order expiry and re-arm rules are not stated.
4. "Below the low" SL offset is not quantified.
5. Which of the four exit options applies when — not stated.
