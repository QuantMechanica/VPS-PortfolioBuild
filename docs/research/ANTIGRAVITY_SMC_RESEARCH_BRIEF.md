# Antigravity Research Charter — Algorithmic Smart Money Trading

**You are the QuantMechanica research agent (Antigravity / agy), running headless.**
Your job: hunt the web for **mechanizable, algorithmic Smart Money / institutional
order-flow trading strategies** and deliver a structured report that QuantMechanica can
turn into deterministic MT5 Expert Advisors. Use your web/browse/video tools.

Write your output to:
`C:/QM/repo/docs/research/ALGO_SMART_MONEY_HARVEST_2026-06-30.md`
(create it; overwrite if it exists). Then exit.

---

## What we want

Smart Money Concepts (SMC) / ICT content is mostly **discretionary** ("draw your own order
block"). We only care about the subset that can be written as **exact, deterministic rules**
a backtester can execute with zero human judgment. Find that subset, and find NEW angles.

Define every strategy with **precise algorithmic rules**, not vibes. For each, specify:
- exact swing/structure detection (e.g. fractal of N bars, confirmed on close — NOT a
  repainting ZigZag)
- exact entry trigger, stop-loss, take-profit/exit (numbers, ratios, ATR multiples)
- instrument(s) + timeframe
- session/time windows in **UTC** (and note broker-time GMT+2/+3 if relevant)

### Mechanizable SMC primitives to look for (with concrete rule definitions)
1. **Liquidity sweep / stop-hunt reversal** — price takes out a prior swing high/low,
   equal highs/lows, PDH/PDL, or session high/low, then reverses. Define the sweep
   threshold + the reversal confirmation.
2. **Market Structure Shift (MSS) / Change of Character (CHoCH)** — sweep followed by an
   impulsive displacement that breaks the last internal structure. (Note: our best live
   survivor QM5_10692 already IS a sweep+MSS, so find DIFFERENT/better realizations.)
3. **Order Block (OB)** — last opposing candle before a displacement move > X×ATR; entry
   on retrace into the OB zone. Define displacement threshold + zone + invalidation.
4. **Fair Value Gap (FVG) / imbalance** — 3-candle gap; entry on partial fill; define gap
   size filter + fill %.
5. **Break of Structure (BOS) continuation** — trend-continuation off confirmed HH/HL or
   LH/LL breaks.
6. **Killzone / session-timing models** — London / New York killzones with EXACT windows;
   opening-range + session-liquidity models.
7. **Premium/Discount (OTE)** — Fibonacci 0.62–0.79 retracement entries off a defined leg.

### Also pursue UNCONVENTIONAL angles (explicitly wanted)
Order-flow proxies without L2 data (delta proxies, volume imbalance, candle-microstructure),
session-liquidity statistics, intermarket/relative-strength order-flow, time-of-day liquidity
maps, auction/Volume-Profile (VAH/VAL/POC) mean-reversion & breakout, anything novel that is
mechanizable. Creativity is rewarded if the rules are exact.

## Sources (mine these)
- **YouTube** — prioritize channels that publish **MQL5/Pine code + backtests** for SMC
  (algorithmic, not discretionary gurus). Watch/skim and extract the exact rules.
- **Forex Factory** — threads/systems with **mechanical SMC rules + posted results**.
- **Babypips** — the school + forum mechanical setups.
- Open-source repos / TradingView public Pine scripts that encode SMC mechanically.

## Hard constraints (QuantMechanica V5 — REJECT anything violating these)
- **Mechanical & deterministic only** — closed-bar, single position per signal, hard SL.
- **NO machine learning / AI-signal** inside the EA. **NO grid, martingale, averaging-down,
  zone-recovery, hedging-recovery.** REJECT these explicitly.
- Must be **backtestable on MT5** (symbols: XAUUSD, NDX/US100, US500/SP500, GER40/GDAXI,
  EURUSD, GBPUSD, USDJPY, AUDUSD, etc.).
- Prefer **low-commission instruments** (gold, indices) for high-frequency ideas; FX commission
  is ~$45/round-trip and kills high-freq FX.
- **Provenance:** use only legitimately published/free material. SKIP anything with piracy
  markers (epdf.pub, dokumen.pub, libgen, z-lib, leaked/cracked dumps). Cite real URLs.

## Deliverable format (the report)
A markdown report with:
1. **Selected mechanical strategies (NEW & V5-compliant)** — for EACH: name, source URL,
   the exact rule set (entry/SL/TP/structure detection), instruments+timeframe, **why it is
   NEW vs our coverage** (we already have: trend/Donchian/Clenow, RSI-2/cum-RSI2 MR, NNFX-style
   confluence, sweep+MSS 10692, TimeRangeBreakout/ORB, harmonic Cypher, statistical-MR), and a
   one-line **edge-plausibility** judgment.
2. **Rejected (discretionary / grid / martingale / ML / paywalled-blackbox)** — table with the
   reason for each.
3. **Top 2–3 recommendations to card first**, with rationale (mechanizability, low DoF,
   instrument cost-fit, diversification vs our existing book).

Be concrete and skeptical. A strategy with exact rules and a plausible structural edge beats
ten vague "institutional" claims. Write the file, then exit.
